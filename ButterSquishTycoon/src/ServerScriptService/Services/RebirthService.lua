local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local CurrencyService = require(script.Parent.CurrencyService)
local ButtonService = require(script.Parent.ButtonService)
local ProcessService = require(script.Parent.ProcessService)
local DropperService = require(script.Parent.DropperService)

local RebirthService = {}

RebirthService.OnRebirth = nil

local lastRequest = {}
local awaitingConfirm = {}
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

function RebirthService.DoRebirth(player: Player, free: boolean?): boolean
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then
		return false
	end

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

	data.Rebirths = (data.Rebirths or 0) + 1
	data.Currency = 0
	data.Stations = {}

	DropperService.ClearPlot(plot)
	DropperService.DisableStation(plot)
	ProcessService.DisableAll(plot)

	ButtonService.RestorePlayer(player)
	CurrencyService.Push(player)

	remotes.Notify:FireClient(
		player,
		(Config.Text.RebirthDone):format(data.Rebirths, 1 + data.Rebirths * Config.Rebirth.BonusPerRebirth),
		Config.Palette.Grape
	)

	task.spawn(DataService.SaveAsync, player, false)

	if RebirthService.OnRebirth then
		RebirthService.OnRebirth(player, data.Rebirths)
	end
	return true
end

function RebirthService.RequestRebirth(player: Player)

	if awaitingConfirm[player] then
		return false
	end

	local ok, reason = RebirthService.CanRebirth(player)
	if not ok then
		remotes.Notify:FireClient(player, reason or Config.Text.RebirthBlocked, Config.Palette.HotRed)
		return false
	end

	local data = DataService.Get(player)
	local nextBonus = math.floor(((data.Rebirths or 0) + 1) * Config.Rebirth.BonusPerRebirth * 100)

	awaitingConfirm[player] = true
	local answer, err = NetService.InvokeClientAsync(player, "ConfirmAction", {
		Kind  = "Rebirth",
		Title = Config.Text.ConfirmTitle,
		Body  = (Config.Text.ConfirmBody):format(nextBonus),
		Yes   = Config.Text.ConfirmYes,
		No    = Config.Text.ConfirmNo,
	})
	awaitingConfirm[player] = nil

	if err or answer ~= true then

		return false
	end

	if not player.Parent then
		return false
	end

	local stillOk, stillReason = RebirthService.CanRebirth(player)
	if not stillOk then
		remotes.Notify:FireClient(player, stillReason or Config.Text.RebirthBlocked, Config.Palette.HotRed)
		return false
	end

	return RebirthService.DoRebirth(player, false)
end

function RebirthService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	ButtonService.OnRebirthRequested = function(player)
		task.spawn(RebirthService.RequestRebirth, player)
	end

	NetService.OnEvent("RequestRebirth", {}, function(player)
		RebirthService.RequestRebirth(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		awaitingConfirm[player] = nil
	end)
end

return RebirthService
