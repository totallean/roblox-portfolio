local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local remotesFolder = Net.Build()

local Services = script.Parent:WaitForChild("Services")

local DataService         = require(Services.DataService)
local NetService          = require(Services.NetService)
local CurrencyService     = require(Services.CurrencyService)
local PlotService         = require(Services.PlotService)
local DropperService      = require(Services.DropperService)
local ProcessService      = require(Services.ProcessService)
local CollectorService    = require(Services.CollectorService)
local ButtonService       = require(Services.ButtonService)
local RebirthService      = require(Services.RebirthService)
local MonetizationService = require(Services.MonetizationService)
local AchievementService  = require(Services.AchievementService)
local InventoryService    = require(Services.InventoryService)
local SocialService       = require(Services.SocialService)

local function applySpeedUpgrades(player: Player, plot: Model)
	local data = DataService.Get(player)
	if not data or not plot then
		return
	end
	local dropScale, beltScale = 1, 1
	for _, def in ipairs(Config.Stations) do
		if data.Stations and data.Stations[def.Id] then
			dropScale *= (def.DropIntervalMultiplier or 1)
			beltScale *= (def.ConveyorSpeedMultiplier or 1)
		end
	end
	plot:SetAttribute("DropIntervalScale", dropScale)
	plot:SetAttribute("ConveyorScale", beltScale)
	PlotService.RefreshConveyor(plot)
end

ButtonService.OnStationEnabled = function(player, plot, def)
	if def.Type == "Producer" then
		PlotService.PlaceStation(plot, def)
		DropperService.EnableStation(plot, def)
	elseif def.Type == "Processor" then
		ProcessService.EnableStation(plot, def)
	end

	applySpeedUpgrades(player, plot)
end

ButtonService.OnStationsRestored = applySpeedUpgrades

MonetizationService.OnSkipRebirth = function(player)
	return RebirthService.DoRebirth(player, true)
end

AchievementService.OwnsPass = function(player, passKey)
	return MonetizationService.OwnsPass(player, passKey)
end

InventoryService.OwnsPass = function(player, passKey)
	return MonetizationService.OwnsPass(player, passKey)
end
InventoryService.GetBoostLeft = function(player)
	return MonetizationService.GetBoostRemaining(player)
end

RebirthService.OnRebirth = function(player, count)
	SocialService.AnnounceRebirth(player, count)
end

DropperService.OnProductExpired = function(plot, product)
	return MonetizationService.HandleExpiredProduct(plot, product, CollectorService.Sell)
end

DataService.Init()
NetService.Init()
CurrencyService.Init()
PlotService.Init()
DropperService.Init()
ProcessService.Init()
CollectorService.Init()
ButtonService.Init()
RebirthService.Init()
MonetizationService.Init()
AchievementService.Init()
InventoryService.Init()
SocialService.Init()

local function buildState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local goal = Config.GetNextGoal(data.Stations or {}, data.Rebirths or 0)

	local hasPlot = PlotService.GetPlot(player) ~= nil
	return {
		NeedPlot     = not hasPlot,
		Balance      = data.Currency,
		Rebirths     = data.Rebirths,
		RebirthCost  = Config.RebirthCost(data.Rebirths or 0),
		Multiplier   = CurrencyService.GetIncomeMultiplier(player),
		IncomePerMin = CurrencyService.EstimateIncomePerMinute(player),
		Owned        = data.Stations,
		BoostLeft    = MonetizationService.GetBoostRemaining(player),
		OwnedPasses  = MonetizationService.GetOwnedPasses(player),
		Goal         = (hasPlot and goal) and { Id = goal.Id, Label = goal.Label, Price = goal.Price } or nil,
	}
end

local function pushState(player: Player)
	local state = buildState(player)
	if state then
		remotesFolder.StateSync:FireClient(player, state)
	end
end

NetService.OnEvent("RequestState", {}, function(player)
	pushState(player)
end)

PlotService.PlotClaimed.Event:Connect(function(player, plot)
	ButtonService.RestorePlayer(player)
	CurrencyService.Push(player)
	pushState(player)
	AchievementService.MarkClaimed(player)
	remotesFolder.Notify:FireClient(player, Config.Text.PlotClaimed, Config.Palette.AcidGreen)
end)

local function pushStep(player: Player, step: number)
	local info = Config.FTUE.Steps[step]
	remotesFolder.FTUEStep:FireClient(player, step, info and info.Text or nil)
end

local function setStep(player: Player, step: number)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if step ~= (data.Tutorial or 0) + 1 then
		return false
	end
	data.Tutorial = step
	pushStep(player, step)
	return true
end

CollectorService.Sold.Event:Connect(function(player)

	setStep(player, 3)
	pushState(player)
end)

ButtonService.Purchased.Event:Connect(function(player, def)
	setStep(player, 4)
	pushState(player)
	AchievementService.Check(player)

	if def then
		SocialService.AnnounceStation(player, def)
	end
end)

MonetizationService.PassesChanged.Event:Connect(function(player)
	pushState(player)
	AchievementService.Check(player)
end)

AchievementService.PanelOpened.Event:Connect(function(player)
	if setStep(player, Config.FTUE.Done) then
		pushState(player)
	end
end)

CurrencyService.Changed.Event:Connect(function(player)
	local now = os.clock()
	local last = player:GetAttribute("_LastStatePush") or 0
	if now - last < 0.4 then
		return
	end
	player:SetAttribute("_LastStatePush", now)
	pushState(player)
end)

local ftueAccum = 0
RunService.Heartbeat:Connect(function(dt)
	ftueAccum += dt
	if ftueAccum < 1 then
		return
	end
	ftueAccum = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(player)
		if data and (data.Tutorial or 0) < Config.FTUE.Done then
			local plot = PlotService.GetPlot(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if plot and root then
				local local_ = plot.Base.CFrame:PointToObjectSpace(root.Position)
				local size = Config.Plot.Size
				if math.abs(local_.X) <= size.X * 0.5 and math.abs(local_.Z) <= size.Z * 0.5 then

					if setStep(player, 2) then
						pushState(player)
					end
				end
			end
		end
	end
end)

local function onPlayerAdded(player: Player)
	local loaded = DataService.LoadAsync(player)
	if not loaded then
		player:Kick(Config.Text.KickNoData)
		return
	end
	if not player.Parent then
		DataService.ReleaseAsync(player)
		return
	end

	MonetizationService.OnPlayerAdded(player)

	remotesFolder.Notify:FireClient(player, Config.Text.PickPlot, Config.Palette.AcidGreen)

	CurrencyService.Push(player)
	pushState(player)
	AchievementService.Push(player)
	SocialService.Sync(player)
	SocialService.AnnounceJoin(player)

	local data = DataService.Get(player)
	if data then
		local step = data.Tutorial or 0
		if step == 0 then
			setStep(player, 1)
		else
			pushStep(player, step)
		end
	end
end

local function onPlayerRemoving(player: Player)
	if DataService.IsLoaded(player) then
		SocialService.AnnounceLeave(player)
	end

	PlotService.ReleasePlot(player)
	MonetizationService.OnPlayerRemoving(player)
	DataService.ReleaseAsync(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("🧈 Butter Squish Tycoon: сервер поднят, плотов —", Config.Plot.Count)
