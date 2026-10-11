--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Types = require(Shared.Types)
local Locale = require(Shared.Locale)

local DataService = {}

DataService.STORE_NAME = "SpectrumForge_Profiles_v1"
DataService.KEY_PREFIX = "player_"
DataService.AUTOSAVE_INTERVAL = 60

local LOCK_TIMEOUT = 180

local RETRY_ATTEMPTS = 5
local RETRY_BASE_DELAY = 1

local LOCK_ATTEMPTS = 6
local LOCK_RETRY_DELAY = 5

local SHUTDOWN_BUDGET = 25

local function kick(player: Player, key: string, profile: Types.Profile?)
	local lang = if profile and Locale.isValid(profile.language)
		then profile.language :: string
		else Locale.fromLocaleId(player.LocaleId)
	player:Kick(Locale.get(lang, key))
end

local profiles: { [Player]: Types.Profile } = {}
local waiters: { [Player]: { (Types.Profile) -> () } } = {}
local nextSave: { [Player]: number } = {}

local store: DataStore? = nil
local memoryFallback: { [number]: any } = {}

local function probeStore(): DataStore?
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(DataService.STORE_NAME)
		ds:GetAsync("__probe__")
		return ds
	end)

	if ok then
		return result
	end

	warn("[Data] DataStore недоступен, профили живут только в памяти этой сессии.")
	warn("[Data] Studio: File -> Game Settings -> Security -> Enable Studio Access to API Services.")
	return nil
end

local function retry(label: string, fn: () -> any): (boolean, any)
	local delay = RETRY_BASE_DELAY

	for attempt = 1, RETRY_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end

		warn(("[Data] %s — попытка %d/%d: %s"):format(label, attempt, RETRY_ATTEMPTS, tostring(result)))

		if attempt < RETRY_ATTEMPTS then
			task.wait(delay)
			delay *= 2
		end
	end

	return false, nil
end

local queues: { [number]: { thread } } = {}

local function exclusive(userId: number, fn: () -> ...any): ...any
	local queue = queues[userId]
	if queue then
		table.insert(queue, coroutine.running())
		coroutine.yield()
	else
		queues[userId] = {}
	end

	local results = table.pack(pcall(fn))

	local nextInLine = table.remove(queues[userId], 1)
	if nextInLine then
		task.spawn(nextInLine)
	else
		queues[userId] = nil
	end

	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

local function makeLock()
	return { jobId = game.JobId, placeId = game.PlaceId, timestamp = os.time() }
end

local function isForeignAndAlive(lock: any): boolean
	if type(lock) ~= "table" then
		return false
	end
	if lock.jobId == game.JobId then
		return false
	end
	return os.time() - (tonumber(lock.timestamp) or 0) < LOCK_TIMEOUT
end

DataService.Migrations = {} :: { [number]: (any) -> any }

local function migrate(raw: any): Types.Profile?
	if type(raw) ~= "table" or type(raw.schemaVersion) ~= "number" then
		return nil
	end

	local profile = raw
	local version = profile.schemaVersion

	while version < Types.SCHEMA_VERSION do
		local step = DataService.Migrations[version]
		if not step then
			warn(("[Data] нет миграции с версии %d в %d"):format(version, Types.SCHEMA_VERSION))
			return nil
		end
		profile = step(profile)
		version += 1
		profile.schemaVersion = version
	end

	return profile
end

local STARTER = {
	core = "core_prism",
	emitter = "emit_lance",
	frame = "frame_plate",
	focus = "focus_lens",
	sigil = "sigil_mark",
}

function DataService.defaultProfile(): Types.Profile
	local now = os.time()

	local parts = {}
	local build = { name = "Сборка 1" }
	for slot, defId in STARTER do
		local uid = "starter_" .. slot
		parts[uid] = { defId = defId, tier = 1, level = 1 }
		build[slot] = uid
	end

	return {
		schemaVersion = Types.SCHEMA_VERSION,
		will = 0,
		shards = 0,
		ringLevel = 1,
		rebirths = 0,
		totalCharge = 0,
		unlockedColors = { 1 },
		parts = parts,
		builds = { build },
		activeBuild = 1,
		pityCounter = 0,
		arenaRank = 1,
		arenaWins = 0,
		arenaLosses = 0,
		ghostWinsPending = 0,
		language = nil,

		tutorialStep = 0,

		lastSeen = now,
		firstJoin = now,
		totalWillEarned = 0,
		purchaseHistory = {},
	}
end

type AcquireResult = "ok" | "locked" | "error" | "corrupt"

local function acquire(userId: number): (Types.Profile?, AcquireResult)
	if not store then
		local cached = memoryFallback[userId]
		return (cached and migrate(cached)) or DataService.defaultProfile(), "ok"
	end

	local key = DataService.KEY_PREFIX .. userId

	for attempt = 1, LOCK_ATTEMPTS do
		local blocked = false

		local ok, result = retry(("захват %d"):format(userId), function()
			return (store :: DataStore):UpdateAsync(key, function(stored)
				blocked = false

				if stored == nil then
					return { data = nil, lock = makeLock() }
				end

				if isForeignAndAlive(stored.lock) then
					blocked = true
					return nil
				end

				return { data = stored.data, lock = makeLock() }
			end)
		end)

		if not ok then
			return nil, "error"
		end

		if not blocked then
			local raw = result and result.data
			if raw == nil then
				return DataService.defaultProfile(), "ok"
			end

			local migrated = migrate(raw)
			if not migrated then
				return nil, "corrupt"
			end
			return migrated, "ok"
		end

		if attempt < LOCK_ATTEMPTS then
			task.wait(LOCK_RETRY_DELAY)
		end
	end

	return nil, "locked"
end

local function persist(userId: number, profile: Types.Profile, keepLock: boolean): (boolean, string?)
	profile.lastSeen = os.time()

	if not store then
		memoryFallback[userId] = profile
		return true
	end

	local key = DataService.KEY_PREFIX .. userId
	local stolen = false

	local ok = retry(("сохранение %d"):format(userId), function()
		return (store :: DataStore):UpdateAsync(key, function(stored)
			stolen = false

			if stored and type(stored.lock) == "table" and stored.lock.jobId ~= game.JobId then
				stolen = true
				return nil
			end

			return {
				data = profile,
				lock = if keepLock then makeLock() else nil,
			}
		end)
	end)

	if stolen then
		warn(("[Data] замок %d перехвачен другим сервером, запись отменена"):format(userId))
		return false, "stolen"
	end

	return ok
end

local function release(userId: number, profile: Types.Profile): boolean
	return exclusive(userId, function()
		return persist(userId, profile, false)
	end)
end

local function onPlayerAdded(player: Player)
	local userId = player.UserId
	local profile, status = exclusive(userId, function()
		return acquire(userId)
	end)

	if not player.Parent then
		if profile then
			task.spawn(release, userId, profile)
		end
		return
	end

	if not profile then

		warn(("[Data] %s не пущен: %s"):format(player.Name, status))
		kick(player, if status == "locked" then "kick.locked" elseif status == "corrupt" then "kick.corrupt" else "kick.error")
		return
	end

	profiles[player] = profile
	nextSave[player] = os.clock() + DataService.AUTOSAVE_INTERVAL + math.random() * 10

	local queued = waiters[player]
	waiters[player] = nil
	if queued then
		for _, fn in queued do
			task.spawn(fn, profile)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	waiters[player] = nil
	nextSave[player] = nil

	if profile then
		release(player.UserId, profile)
	end
end

function DataService:Get(player: Player): Types.Profile?
	return profiles[player]
end

function DataService:Save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end

	local ok, reason = exclusive(player.UserId, function()
		if profiles[player] ~= profile then
			return false, "released"
		end
		return persist(player.UserId, profile, true)
	end)

	if reason == "stolen" and profiles[player] == profile then
		profiles[player] = nil
		nextSave[player] = nil
		kick(player, "kick.stolen", profile)
	end

	return ok == true
end

function DataService:OnLoaded(player: Player, fn: (Types.Profile) -> ())
	local profile = profiles[player]
	if profile then
		task.spawn(fn, profile)
		return
	end

	local queue = waiters[player]
	if not queue then
		queue = {}
		waiters[player] = queue
	end
	table.insert(queue, fn)
end

function DataService:ObserveProfiles(fn: (Player, Types.Profile) -> ())
	local seen: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function watch(player: Player)
		if seen[player] then
			return
		end
		seen[player] = true
		self:OnLoaded(player, function(profile)
			fn(player, profile)
		end)
	end

	Players.PlayerAdded:Connect(watch)
	task.defer(function()
		for _, player in Players:GetPlayers() do
			watch(player)
		end
	end)
end

function DataService:IsUsingDataStore(): boolean
	return store ~= nil
end

function DataService._injectStore(fake: any, cfg: any?)
	store = fake :: any

	if cfg then
		LOCK_TIMEOUT = cfg.lockTimeout or LOCK_TIMEOUT
		LOCK_ATTEMPTS = cfg.lockAttempts or LOCK_ATTEMPTS
		LOCK_RETRY_DELAY = cfg.lockRetryDelay or LOCK_RETRY_DELAY
		RETRY_ATTEMPTS = cfg.retryAttempts or RETRY_ATTEMPTS
		RETRY_BASE_DELAY = cfg.retryBaseDelay or RETRY_BASE_DELAY
	end
end

DataService._acquire = acquire
DataService._persist = persist
DataService._exclusive = exclusive

function DataService:Init()
	store = probeStore()

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function DataService:Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()

			for player, due in nextSave do
				if now >= due and profiles[player] then
					nextSave[player] = now + DataService.AUTOSAVE_INTERVAL
					task.spawn(function()
						self:Save(player)
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end

		for player, profile in profiles do
			profiles[player] = nil
			nextSave[player] = nil
			task.spawn(release, player.UserId, profile)
		end

		local deadline = os.clock() + SHUTDOWN_BUDGET
		while next(queues) ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end

		local unfinished = 0
		for _ in queues do
			unfinished += 1
		end
		if unfinished > 0 then
			warn(("[Data] не успели сохранить %d профилей до закрытия"):format(unfinished))
		end
	end)
end

return DataService
