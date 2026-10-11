--[[
	RebirthService — порог, сброс, перманентный множитель.

	Порог берётся из конфига: cost(n) = BaseCost * Growth^n.
	Ребёрн сбрасывает баланс и ВСЕ купленные станции, но навсегда
	добавляет +BonusPerRebirth к множителю дохода
	(множитель считает CurrencyService, здесь только данные).

	Станции с полем RequiredRebirths открываются именно отсюда:
	ButtonService сам перестанет их прятать, когда data.Rebirths вырастет.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CurrencyService = require(script.Parent.CurrencyService)
local ButtonService = require(script.Parent.ButtonService)
local ProcessService = require(script.Parent.ProcessService)
local DropperService = require(script.Parent.DropperService)

local RebirthService = {}

local lastRequest = {}   -- [player] = os.clock(), анти-спам
local remotes

function RebirthService.GetCost(player: Player): number
	local data = DataService.Get(player)
	return Config.RebirthCost(data and data.Rebirths or 0)
end

function RebirthService.CanRebirth(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, Config.Text.DataLoading
	end
	if (data.Rebirths or 0) >= Config.Rebirth.Max then
		return false, Config.Text.RebirthMaxed
	end
	local cost = Config.RebirthCost(data.Rebirths or 0)
	if data.Currency < cost then
		return false, (Config.Text.NeedMore):format(Config.FormatNumber(cost - data.Currency))
	end
	return true, nil
end

-- free = true → ребёрн без списания (Dev Product «Skip Rebirth»)
function RebirthService.DoRebirth(player: Player, free: boolean?): boolean
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then
		return false
	end

	-- Анти-спам на все входы (Touched и Remote)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < Config.Rebirth.Cooldown then
		return false
	end
	lastRequest[player] = now

	if not free then
		local ok, reason = RebirthService.CanRebirth(player)
		if not ok then
			remotes.Notify:FireClient(player, reason or Config.Text.RebirthBlocked, Config.Palette.HotRed)
			return false
		end
	elseif (data.Rebirths or 0) >= Config.Rebirth.Max then
		return false
	end

	-- Сброс
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Currency = 0
	data.Stations = {}

	-- Чистим плот: продукты, станции, дропперы
	DropperService.ClearPlot(plot)
	DropperService.DisableStation(plot)
	ProcessService.DisableAll(plot)

	-- И заново выдаём бесплатные станции + перерисовываем кнопки
	ButtonService.RestorePlayer(player)
	CurrencyService.Push(player)

	remotes.Notify:FireClient(
		player,
		(Config.Text.RebirthDone):format(data.Rebirths, 1 + data.Rebirths * Config.Rebirth.BonusPerRebirth),
		Config.Palette.Grape
	)

	-- Ребёрн — важное событие, сохраняем сразу, не ждём автосейва
	task.spawn(DataService.SaveAsync, player, false)
	return true
end

function RebirthService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Вход №1: физическая кнопка на плоте
	ButtonService.OnRebirthRequested = function(player)
		RebirthService.DoRebirth(player, false)
	end

	-- Вход №2: кнопка в UI. Sanity checks те же самые — клиенту не верим.
	remotes.RequestRebirth.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < Config.RemoteCooldown then
			return
		end
		RebirthService.DoRebirth(player, false)
	end)
end

return RebirthService
