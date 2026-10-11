--[[
	AchievementService — достижения и награды за них.

	Условия целиком описаны в Config.Achievements.List, здесь только
	их проверка. Добавить достижение = дописать строку в конфиг.

	Когда пересчитываем:
	  • купили станцию, заняли плот, сделали ребёрн — сразу по событию;
	  • накопительные условия (всего заработано) — редким проходом
	    раз в Config.Achievements.SweepInterval секунд.

	Награды выдаёт только сервер. Клиент получает готовый список
	через RemoteEvent и просто рисует его.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local AchievementService = {}

-- Сигнал: (player) — игрок сам открыл панель наград.
-- По нему обучение закрывает последний шаг.
AchievementService.PanelOpened = Instance.new("BindableEvent")

-- Хук подставляет Main: (player, passKey) -> boolean.
-- Так достижения за покупки не тянут за собой MonetizationService.
AchievementService.OwnsPass = nil

local remotes
local sweepAccum = 0

local function log(fmt, ...)
	if Config.Debug.Verbose then
		print(("[Achievements] " .. fmt):format(...))
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ПРОВЕРКА УСЛОВИЯ
-- ═══════════════════════════════════════════════════════════════
local function isMet(player: Player, def, data): boolean
	if def.Claimed then
		return data.HasClaimed == true
	end
	if def.Station then
		return (data.Stations or {})[def.Station] == true
	end
	if def.Rebirths then
		return (data.Rebirths or 0) >= def.Rebirths
	end
	if def.Pass then
		return AchievementService.OwnsPass ~= nil and AchievementService.OwnsPass(player, def.Pass) == true
	end
	if def.AnyPass then
		if not AchievementService.OwnsPass then
			return false
		end
		for key in pairs(Config.Monetization.GamePasses) do
			if AchievementService.OwnsPass(player, key) then
				return true
			end
		end
		return false
	end
	if def.SoldCount then
		return (data.SoldCount or 0) >= def.SoldCount
	end
	if def.TotalEarned then
		return (data.TotalEarned or 0) >= def.TotalEarned
	end
	if def.Collection then
		-- Коллекция закрывается, когда открыты все БЕСПЛАТНЫЕ достижения:
		-- покупные помечены ExcludeFromCollection и не блокируют её
		for _, other in ipairs(Config.Achievements.List) do
			if not other.Collection and not other.ExcludeFromCollection
				and not (data.Achievements or {})[other.Id] then
				return false
			end
		end
		return true
	end
	return false
end

local function grantReward(player: Player, data, def)
	local reward = def.Reward
	if not reward then
		return
	end
	if reward.Cash then
		-- false: награда не идёт в «всего заработано», иначе она сама
		-- открывала бы достижения за накопленный заработок
		CurrencyService.Add(player, reward.Cash, "achievement:" .. def.Id, false)
	end
	if reward.Multiplier then
		data.BonusMultiplier = (data.BonusMultiplier or 0) + reward.Multiplier
		CurrencyService.Push(player)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- СИНХРОНИЗАЦИЯ С КЛИЕНТОМ
-- ═══════════════════════════════════════════════════════════════
function AchievementService.BuildList(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local unlocked = data.Achievements or {}
	local list, done, total = {}, 0, 0

	for _, def in ipairs(Config.Achievements.List) do
		local isUnlocked = unlocked[def.Id] == true

		-- Скрытые показываем только после выполнения: пока игрок не купил
		-- пасс, он их не видит и может закрыть список на 100% бесплатно
		if not def.Hidden or isUnlocked then
			total += 1
			if isUnlocked then
				done += 1
			end
			table.insert(list, {
				Order = #list + 1,   -- запоминаем позицию из конфига
				Id = def.Id,
				Name = def.Name,
				Desc = def.Desc,
				Unlocked = isUnlocked,
				Premium = def.Premium == true,
				Cash = def.Reward and def.Reward.Cash or nil,
				Multiplier = def.Reward and def.Reward.Multiplier or nil,
			})
		end
	end

	-- Премиальные идут в конец списка, чтобы не разбивать обычную цепочку.
	-- Внутри группы сохраняем порядок конфига: table.sort нестабильна,
	-- и без явного Order бесплатные награды перемешивались.
	table.sort(list, function(a, b)
		if a.Premium ~= b.Premium then
			return not a.Premium
		end
		return a.Order < b.Order
	end)

	return {
		Items = list,
		Done = done,
		Total = total,
		Bonus = data.BonusMultiplier or 0,
	}
end

function AchievementService.Push(player: Player)
	local payload = AchievementService.BuildList(player)
	if payload then
		remotes.AchievementSync:FireClient(player, payload)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ОСНОВНАЯ ПРОВЕРКА
-- ═══════════════════════════════════════════════════════════════
function AchievementService.Check(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Achievements = data.Achievements or {}

	local unlockedNow = {}
	-- Два прохода: коллекция может закрыться тем же тиком, что и последнее
	-- обычное достижение, поэтому проверяем список ещё раз
	for _ = 1, 2 do
		for _, def in ipairs(Config.Achievements.List) do
			if not data.Achievements[def.Id] and isMet(player, def, data) then
				data.Achievements[def.Id] = true
				table.insert(unlockedNow, def)
			end
		end
	end

	if #unlockedNow == 0 then
		return
	end

	for _, def in ipairs(unlockedNow) do
		grantReward(player, data, def)
		remotes.AchievementUnlock:FireClient(player, {
			Name = def.Name,
			Desc = def.Desc,
			Cash = def.Reward and def.Reward.Cash or nil,
			Multiplier = def.Reward and def.Reward.Multiplier or nil,
		})
		log("%s открыл %s", player.Name, def.Id)
	end

	AchievementService.Push(player)
	-- Награда — это валюта, сохраняем не дожидаясь автосейва
	task.spawn(DataService.SaveAsync, player, false)
end

-- Отметка «игрок занимал плот» живёт в профиле, а не в Workspace
function AchievementService.MarkClaimed(player: Player)
	local data = DataService.Get(player)
	if data then
		data.HasClaimed = true
	end
	AchievementService.Check(player)
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════
function AchievementService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Перманентный бонус за коллекцию идёт общим множителем дохода
	CurrencyService.RegisterMultiplierProvider(function(player)
		local data = DataService.Get(player)
		return 1 + (data and data.BonusMultiplier or 0)
	end)

	local lastRequest = {}
	remotes.RequestAchievements.OnServerEvent:Connect(function(player, openedByUser)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < Config.RemoteCooldown then
			return
		end
		lastRequest[player] = now
		AchievementService.Push(player)

		-- Sanity check: верим только явному булеву, всё остальное игнорируем
		if openedByUser == true then
			AchievementService.PanelOpened:Fire(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)

	-- Накопительные условия: редкий проход, а не проверка на каждую продажу
	RunService.Heartbeat:Connect(function(dt)
		sweepAccum += dt
		if sweepAccum < Config.Achievements.SweepInterval then
			return
		end
		sweepAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			AchievementService.Check(player)
		end
	end)
end

return AchievementService
