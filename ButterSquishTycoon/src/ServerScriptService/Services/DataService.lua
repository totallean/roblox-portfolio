--[[
	DataService — ЕДИНСТВЕННАЯ точка доступа к данным игрока.
	Ни один другой сервис не трогает DataStoreService напрямую.

	Что внутри:
	  • session-locking (чужая сессия не сможет писать в тот же ключ);
	  • pcall + ретраи с экспоненциальной задержкой;
	  • автосейв раз в Config.Data.AutosaveInterval секунд (RunService, накопление дельты);
	  • game:BindToClose с ожиданием завершения сейвов.

	── ЗАМЕНА НА ProfileStore ────────────────────────────────────────
	Наружу торчат ровно 6 функций: Init, LoadAsync, Get, IsLoaded,
	SaveAsync, ReleaseAsync + сигнал ProfileLoaded. Чтобы перейти на
	ProfileStore, перепиши только их тела: структура профиля
	(Config.DefaultProfile) и остальные сервисы не меняются вообще.
	Соответствие: LoadAsync → :StartSessionAsync, ReleaseAsync → :EndSession,
	Get → profile.Data, Reconcile → :Reconcile.
	──────────────────────────────────────────────────────────────────
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

-- Сигнал: (player, data) — профиль загружен и готов к работе
DataService.ProfileLoaded = Instance.new("BindableEvent")

-- Стор берём лениво и через pcall: в неопубликованном месте и при
-- выключенном «Enable Studio Access to API Services» GetDataStore бросает
-- исключение прямо на require, и без этого падал бы весь сервер.
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

-- Идентификатор сессии. На боевом сервере это JobId, в Studio он пуст.
--
-- ВАЖНО: в Studio идентификатор ПОСТОЯННЫЙ. Раньше он генерировался
-- случайным на каждый запуск, и лок, оставшийся от предыдущей
-- Play-сессии, выглядел «чужим»: следующий запуск ждал таймаут и кикал
-- игрока с «Couldn't load your progress». Теперь Studio переиспользует
-- собственный лок, как и должно быть при перезапуске того же места.
local SESSION_ID = (game.JobId ~= "" and game.JobId)
	or ("studio-" .. tostring(game.PlaceId))

-- [player] = { Data = {}, Loaded = bool, Saving = bool, UserId = number }
local profiles = {}

local function log(fmt, ...)
	if Config.Debug.Verbose then
		print(("[DataService] " .. fmt):format(...))
	end
end

local function keyFor(userId: number): string
	return Config.Data.KeyPrefix .. tostring(userId)
end

-- ─── pcall + экспоненциальный бэкофф ────────────────────────────
local function retry(label: string, fn)
	local attempts = Config.Data.MaxRetries
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] %s: попытка %d/%d провалилась — %s"):format(label, i, attempts, tostring(result)))
		if i < attempts then
			-- 0.5, 1, 2, 4, 8 … + джиттер, чтобы не долбить стор синхронно
			task.wait(Config.Data.RetryBaseDelay * (2 ^ (i - 1)) + math.random() * 0.25)
		end
	end
	return false, nil
end

-- ─── Reconcile: дописываем недостающие поля из схемы ────────────
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

-- ═══════════════════════════════════════════════════════════════
-- ЗАГРУЗКА с захватом session-lock
-- ═══════════════════════════════════════════════════════════════
function DataService.LoadAsync(player: Player): boolean
	if profiles[player] then
		return profiles[player].Loaded
	end

	local userId = player.UserId
	local key = keyFor(userId)
	local deadline = os.clock() + Config.Data.LockWaitTimeout
	local acquired, data = false, nil
	local memoryOnly = false

	-- Одна попытка захвата. force = true → забираем лок, даже если его
	-- держит другая сессия. Так делают все нормальные библиотеки данных:
	-- иначе упавший сервер блокировал бы игрока до истечения TTL.
	local function attempt(force: boolean)
		local activeStore = getStore()
		if not activeStore then
			return nil, false   -- сам стор недоступен
		end
		local ok, record = retry("load " .. key, function()
			return activeStore:UpdateAsync(key, function(old)
				local rec = old or { Data = Config.DefaultProfile(), Lock = nil, LockTime = 0 }

				local lockedByOther = rec.Lock ~= nil and rec.Lock ~= SESSION_ID
				local lockFresh = (os.time() - (rec.LockTime or 0)) < Config.Data.SessionLockTTL
				if lockedByOther and lockFresh and not force then
					return nil   -- ключ занят живой сессией, ждём
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
			-- Ключ держит живая чужая сессия: ждём и пробуем снова,
			-- после таймаута заберём принудительно
			log("ключ %s занят другой сессией, ждём…", key)
			task.wait(2)
		else
			-- Стор недоступен. В Studio это выключённый «Enable Studio
			-- Access to API Services», на бою — авария DataStore.
			-- Игрока не выкидываем: играем на профиле в памяти.
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

-- ═══════════════════════════════════════════════════════════════
-- ДОСТУП
-- ═══════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════
-- СОХРАНЕНИЕ
-- release = true → снимаем session-lock (игрок вышел / сервер тушится)
-- ═══════════════════════════════════════════════════════════════
function DataService.SaveAsync(player: Player, release: boolean?): boolean
	local entry = profiles[player]
	if not entry or not entry.Loaded then
		return false
	end
	if entry.Saving then
		return false -- параллельный сейв уже идёт
	end
	if entry.MemoryOnly then
		return false -- DataStore был недоступен при входе, писать некуда
	end
	entry.Saving = true

	-- Считаем наигранное время прямо в профиль
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
			-- Кто-то перехватил ключ — не затираем чужие данные
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

-- ═══════════════════════════════════════════════════════════════
-- INIT: автосейв + BindToClose
-- ═══════════════════════════════════════════════════════════════
function DataService.Init()
	-- Автосейв: RunService с накоплением дельты, без while true do wait() end
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

	-- Корректное завершение: ждём, пока сейвы отработают
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

	-- Страховка: если игрок ушёл, а Main почему-то не вызвал Release
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			if profiles[player] then
				DataService.ReleaseAsync(player)
			end
		end)
	end)

	-- Самопроверка: сразу видно, работает DataStore или мы в памяти.
	-- В Studio до публикации места и без «Enable Studio Access to API
	-- Services» доступа к стору нет — это нормально и ожидаемо.
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
