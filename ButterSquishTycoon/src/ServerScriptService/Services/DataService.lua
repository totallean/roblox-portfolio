local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

DataService.ProfileLoaded = Instance.new("BindableEvent")

local store = nil
local storeUnavailable = false

local function getStore()
	if store or storeUnavailable then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok and result then
		store = result
	else
		storeUnavailable = true
		warn("[DataService] DataStore недоступен: " .. tostring(result))
	end
	return store
end

local SESSION_ID = (game.JobId ~= "" and game.JobId)
	or ("studio-" .. tostring(game.PlaceId))

local profiles = {}

local function log(fmt, ...)
	if Config.Debug.Verbose then
		print(("[DataService] " .. fmt):format(...))
	end
end

local function keyFor(userId: number): string
	return Config.Data.KeyPrefix .. tostring(userId)
end

local function retry(label: string, fn)
	local attempts = Config.Data.MaxRetries
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] %s: попытка %d/%d провалилась — %s"):format(label, i, attempts, tostring(result)))
		if i < attempts then

			task.wait(Config.Data.RetryBaseDelay * (2 ^ (i - 1)) + math.random() * 0.25)
		end
	end
	return false, nil
end

local function reconcile(data)
	local template = Config.DefaultProfile()
	if type(data) ~= "table" then
		return template
	end
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
		end
	end
	return data
end

function DataService.LoadAsync(player: Player): boolean
	if profiles[player] then
		return profiles[player].Loaded
	end

	local userId = player.UserId
	local key = keyFor(userId)
	local deadline = os.clock() + Config.Data.LockWaitTimeout
	local acquired, data = false, nil
	local memoryOnly = false

	local function attempt(force: boolean)
		local activeStore = getStore()
		if not activeStore then
			return nil, false
		end
		local ok, record = retry("load " .. key, function()
			return activeStore:UpdateAsync(key, function(old)
				local rec = old or { Data = Config.DefaultProfile(), Lock = nil, LockTime = 0 }

				local lockedByOther = rec.Lock ~= nil and rec.Lock ~= SESSION_ID
				local lockFresh = (os.time() - (rec.LockTime or 0)) < Config.Data.SessionLockTTL
				if lockedByOther and lockFresh and not force then
					return nil
				end

				rec.Lock = SESSION_ID
				rec.LockTime = os.time()
				rec.Data = reconcile(rec.Data)
				return rec
			end)
		end)
		return record, ok
	end

	local attempts = 0
	repeat
		attempts += 1
		local force = os.clock() > deadline
		local record, storeOk = attempt(force)

		if record ~= nil then
			acquired = true
			data = record.Data
			if force then
				warn(("[DataService] лок по ключу %s перехвачен по таймауту"):format(key))
			end
		elseif storeOk then

			log("ключ %s занят другой сессией, ждём…", key)
			task.wait(2)
		else

			warn("[DataService] DataStore недоступен — сессия в памяти, прогресс НЕ сохранится")
			data = Config.DefaultProfile()
			memoryOnly = true
			acquired = true
		end
	until acquired or player.Parent == nil or attempts > 40

	if not acquired then
		return false
	end

	profiles[player] = {
		Data = data,
		Loaded = true,
		Saving = false,
		MemoryOnly = memoryOnly,
		UserId = userId,
		JoinClock = os.clock(),
	}

	log("профиль %s загружен: currency=%d rebirths=%d", player.Name, data.Currency, data.Rebirths)
	DataService.ProfileLoaded:Fire(player, data)
	return true
end

function DataService.Get(player: Player)
	local entry = profiles[player]
	if entry and entry.Loaded then
		return entry.Data
	end
	return nil
end

function DataService.IsLoaded(player: Player): boolean
	local entry = profiles[player]
	return entry ~= nil and entry.Loaded
end

function DataService.SaveAsync(player: Player, release: boolean?): boolean
	local entry = profiles[player]
	if not entry or not entry.Loaded then
		return false
	end
	if entry.Saving then
		return false
	end
	if entry.MemoryOnly then
		return false
	end
	entry.Saving = true

	entry.Data.Playtime = (entry.Data.Playtime or 0) + math.floor(os.clock() - (entry.JoinClock or os.clock()))
	entry.JoinClock = os.clock()

	local key = keyFor(entry.UserId)
	local snapshot = entry.Data

	local activeStore = getStore()
	if not activeStore then
		entry.Saving = false
		return false
	end

	local ok = retry("save " .. key, function()
		return activeStore:UpdateAsync(key, function(old)
			local rec = old or {}

			if rec.Lock ~= nil and rec.Lock ~= SESSION_ID then
				return nil
			end
			rec.Data = snapshot
			rec.Lock = release and nil or SESSION_ID
			rec.LockTime = release and 0 or os.time()
			return rec
		end)
	end)

	entry.Saving = false
	if ok then
		log("сохранён %s (release=%s)", tostring(entry.UserId), tostring(release))
	else
		warn(("[DataService] НЕ УДАЛОСЬ сохранить %s"):format(tostring(entry.UserId)))
	end
	return ok
end

function DataService.ReleaseAsync(player: Player)
	if not profiles[player] then
		return
	end
	DataService.SaveAsync(player, true)
	profiles[player] = nil
end

function DataService.SaveAll(release: boolean?)
	for player in pairs(profiles) do
		task.spawn(DataService.SaveAsync, player, release)
	end
end

function DataService.Init()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.Data.AutosaveInterval then
			return
		end
		accumulator = 0
		for player in pairs(profiles) do
			task.spawn(DataService.SaveAsync, player, false)
		end
	end)

	game:BindToClose(function()
		log("BindToClose: сохраняем %d профилей", (function()
			local n = 0
			for _ in pairs(profiles) do n += 1 end
			return n
		end)())

		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.SaveAsync(player, true)
				pending -= 1
			end)
		end

		local started = os.clock()
		while pending > 0 and (os.clock() - started) < Config.Data.BindToCloseWait do
			task.wait(0.1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			if profiles[player] then
				DataService.ReleaseAsync(player)
			end
		end)
	end)

	task.spawn(function()
		local activeStore = getStore()
		if not activeStore then
			warn("[DataService] DataStore НЕДОСТУПЕН — прогресс не сохраняется. " ..
				"Опубликуй место и включи Game Settings → Security → Enable Studio Access to API Services")
			return
		end
		local ok, err = pcall(function()
			activeStore:GetAsync("__healthcheck")
		end)
		if ok then
			print("[DataService] DataStore доступен, сохранение работает")
		else
			warn("[DataService] DataStore отвечает ошибкой: " .. tostring(err))
		end
	end)

	log("инициализирован, session=%s", SESSION_ID)
end

return DataService
