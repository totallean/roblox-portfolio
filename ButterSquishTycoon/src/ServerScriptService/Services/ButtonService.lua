local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Schema = require(Shared:WaitForChild("Schema"))
local PlotService = require(script.Parent.PlotService)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local NetService = require(script.Parent.NetService)

local ButtonService = {}

ButtonService.OnStationEnabled = nil
ButtonService.OnRebirthRequested = nil
ButtonService.OnStationsRestored = nil

ButtonService.Purchased = Instance.new("BindableEvent")

local connected = {}
local touchLock = {}
local refreshAccum = 0
local remotes

local HIDDEN_DROP = Vector3.new(0, -20, 0)

local function describe(id: string, data)
	if id == "Rebirth" then
		local cost = Config.RebirthCost(data.Rebirths or 0)
		return {
			Id = "Rebirth",
			Price = cost,
			Label = Config.Rebirth.Label,
			Offset = Config.Rebirth.ButtonOffset,
			Visible = (data.Rebirths or 0) < Config.Rebirth.Max,
			IsRebirth = true,
		}
	end

	local def = Config.GetStation(id)
	if not def then
		return nil
	end

	local owned = data.Stations or {}
	local reqOk = (def.Requires == nil) or (owned[def.Requires] == true)
	local rebirthOk = (data.Rebirths or 0) >= (def.RequiredRebirths or 0)

	return {
		Id = id,
		Def = def,
		Price = def.Price,
		Label = def.Label,
		Offset = def.ButtonOffset,

		Visible = (owned[id] ~= true) and reqOk and rebirthOk,
	}
end

local function tweenPivot(model: Model, fromCF: CFrame, toCF: CFrame, duration: number)
	local style = Enum.EasingStyle.Back
	local direction = Enum.EasingDirection.Out
	local elapsed = 0
	local token = (model:GetAttribute("TweenToken") or 0) + 1
	model:SetAttribute("TweenToken", token)

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if model:GetAttribute("TweenToken") ~= token or not model.Parent then
			connection:Disconnect()
			return
		end
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local eased = TweenService:GetValue(alpha, style, direction)
		model:PivotTo(fromCF:Lerp(toCF, eased))
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

local function setShown(plot: Model, slot: Model, trigger: BasePart, info, shown: boolean, animate: boolean)
	local wasShown = slot:GetAttribute("Shown") == true
	if wasShown == shown and not animate then
		return
	end
	slot:SetAttribute("Shown", shown)

	local shownCF = PlotService.LocalCF(plot, info.Offset + Vector3.new(0, Config.Buttons.PadSize.Y * 0.5, 0))
	local hiddenCF = shownCF + HIDDEN_DROP

	if shown then
		if not wasShown then

			local overshoot = shownCF + Vector3.new(0, Config.Buttons.BounceStuds, 0)
			slot:PivotTo(hiddenCF)
			tweenPivot(slot, hiddenCF, overshoot, Config.Buttons.BounceTime)
			task.delay(Config.Buttons.BounceTime, function()
				if slot.Parent and slot:GetAttribute("Shown") == true then
					tweenPivot(slot, overshoot, shownCF, Config.Buttons.BounceTime * 0.8)
				end
			end)
		else
			slot:PivotTo(shownCF)
		end
	else
		slot:PivotTo(hiddenCF)
	end

	trigger.CanTouch = shown
	local billboard = trigger:FindFirstChild("Price")
	if billboard then
		billboard.Enabled = shown
	end
	local glow = slot:FindFirstChildOfClass("Highlight")
	if glow then
		glow.Enabled = shown
	end
end

local function paint(slot: Model, trigger: BasePart, info, balance: number)
	local affordable = balance >= info.Price
	local color = affordable and Config.Palette.AcidGreen or Config.Palette.HotRed

	local placeholder = slot:FindFirstChild("Placeholder")
	if placeholder and placeholder:IsA("BasePart") then
		if placeholder.Color ~= color then
			placeholder.Color = color
			placeholder.Material = Enum.Material.Neon
		end
	end

	local glow = slot:FindFirstChildOfClass("Highlight")
	if not glow then
		glow = Instance.new("Highlight")
		glow.Name = "Affordable"
		glow.FillTransparency = 0.75
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = slot
	end
	if glow.FillColor ~= color then
		glow.FillColor = color
		glow.OutlineColor = color
	end

	local billboard = trigger:FindFirstChild("Price")
	if billboard and billboard:FindFirstChild("Text") then

		local priceText = info.Price > 0 and Config.FormatNumber(info.Price) or Config.Text.FreePrice
		billboard.Text.Text = ("%s\n%s"):format(info.Label, priceText)
		billboard.Text.TextColor3 = affordable and Config.Palette.White or Config.Palette.HotRed
	end
end

function ButtonService.Refresh(player: Player, animate: boolean?)
	local plot = PlotService.GetPlot(player)
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end

	local balance = data.Currency or 0
	local buttons = plot:FindFirstChild("Buttons")
	local triggers = plot:FindFirstChild("Triggers")
	if not buttons or not triggers then
		return
	end

	for _, slot in ipairs(buttons:GetChildren()) do
		local id = slot:GetAttribute("StationId")
		local trigger = id and triggers:FindFirstChild("Button_" .. id)
		if id and trigger then
			local info = describe(id, data)
			if info then
				setShown(plot, slot, trigger, info, info.Visible, animate == true)
				if info.Visible then
					paint(slot, trigger, info, balance)
				end
			end
		end
	end
end

function ButtonService.ResetPlot(plot: Model)
	local buttons = plot:FindFirstChild("Buttons")
	local triggers = plot:FindFirstChild("Triggers")
	if not buttons or not triggers then
		return
	end
	for _, slot in ipairs(buttons:GetChildren()) do
		local id = slot:GetAttribute("StationId")
		local trigger = id and triggers:FindFirstChild("Button_" .. id)
		if trigger then
			slot:SetAttribute("Shown", false)
			trigger.CanTouch = false
			local billboard = trigger:FindFirstChild("Price")
			if billboard then billboard.Enabled = false end
			local glow = slot:FindFirstChildOfClass("Highlight")
			if glow then glow.Enabled = false end
			local offset = (id == "Rebirth") and Config.Rebirth.ButtonOffset or (Config.GetStation(id) and Config.GetStation(id).ButtonOffset)
			if offset then
				slot:PivotTo(PlotService.LocalCF(plot, offset + Vector3.new(0, Config.Buttons.PadSize.Y * 0.5, 0)) + HIDDEN_DROP)
			end
		end
	end
end

function ButtonService.GrantStation(player: Player, def, silent: boolean?)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then
		return false
	end

	data.Stations = data.Stations or {}
	data.Stations[def.Id] = true

	if ButtonService.OnStationEnabled then
		ButtonService.OnStationEnabled(player, plot, def)
	end

	if not silent then
		remotes.StationPurchased:FireClient(player, def.Id, def.Label)
		ButtonService.Purchased:Fire(player, def)
	end

	ButtonService.Refresh(player, true)
	return true
end

function ButtonService.TryPurchase(player: Player, stationId: string): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, Config.Text.DataLoading
	end

	local plot = PlotService.GetPlot(player)
	if not plot then
		return false, Config.Text.BuyNoPlot
	end

	local info = describe(stationId, data)

	if not info or info.IsRebirth then
		return false, Config.Text.BuyUnknown
	end

	if (data.Stations or {})[stationId] == true then
		return false, Config.Text.BuyOwned
	end

	if not info.Visible then
		return false, Config.Text.BuyLocked
	end

	if data.Currency < info.Price then
		local need = info.Price - data.Currency
		return false, (Config.Text.NeedMore):format(Config.FormatNumber(need))
	end

	if not CurrencyService.TrySpend(player, info.Price, "buy:" .. stationId) then
		return false, Config.Text.NetError
	end
	ButtonService.GrantStation(player, info.Def)
	return true, nil
end

function ButtonService.RestorePlayer(player: Player)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then
		return
	end
	data.Stations = data.Stations or {}

	for _, def in ipairs(Config.Stations) do

		if def.Price == 0 then
			data.Stations[def.Id] = true
		end
		if data.Stations[def.Id] then
			if ButtonService.OnStationEnabled then
				ButtonService.OnStationEnabled(player, plot, def)
			end
		end
	end

	if ButtonService.OnStationsRestored then
		ButtonService.OnStationsRestored(player, plot)
	end
	ButtonService.Refresh(player, true)
end

local function playerFromHit(hit: BasePart): Player?
	local character = hit.Parent
	if not character then
		return nil
	end
	if not character:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function onButtonTouched(trigger: BasePart, hit: BasePart)
	if trigger.CanTouch == false then
		return
	end
	local player = playerFromHit(hit)
	if not player then
		return
	end

	local now = os.clock()
	if touchLock[player] and now - touchLock[player] < Config.Buttons.TouchCooldown then
		return
	end
	touchLock[player] = now

	local plot = PlotService.GetPlotFrom(trigger)
	local ownPlot = PlotService.GetPlot(player)

	if not plot or plot ~= ownPlot then
		remotes.Notify:FireClient(player, Config.Text.NotOwnPlot, Config.Palette.HotRed)
		return
	end

	local data = DataService.Get(player)
	if not data then
		return
	end

	local id = trigger:GetAttribute("StationId")
	local info = describe(id, data)
	if not info or not info.Visible then
		return
	end

	if info.IsRebirth then
		if data.Currency < info.Price then
			local need = info.Price - data.Currency
			remotes.Notify:FireClient(player, (Config.Text.NeedMore):format(Config.FormatNumber(need)), Config.Palette.HotRed)
			return
		end
		if ButtonService.OnRebirthRequested then
			ButtonService.OnRebirthRequested(player, plot)
		end
		return
	end

	local ok, reason = ButtonService.TryPurchase(player, id)
	if not ok and reason then
		remotes.Notify:FireClient(player, reason, Config.Palette.HotRed)
	end
end

local function bindButton(trigger: BasePart)
	if connected[trigger] then
		return
	end
	connected[trigger] = true
	trigger.Touched:Connect(function(hit)
		onButtonTouched(trigger, hit)
	end)
end

function ButtonService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	local stationIds = {}
	for _, def in ipairs(Config.Stations) do
		stationIds[def.Id] = true
	end

	NetService.OnFunction("BuyStation", { Schema.Key(stationIds) }, function(player, stationId)
		local ok, reason = ButtonService.TryPurchase(player, stationId)
		return { Ok = ok, Reason = reason }
	end)

	for _, trigger in ipairs(CollectionService:GetTagged(Config.Tags.Trigger)) do
		if trigger:GetAttribute("Kind") == "Button" then
			bindButton(trigger)
		end
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Trigger):Connect(function(trigger)
		if trigger:GetAttribute("Kind") == "Button" then
			bindButton(trigger)
		end
	end)

	CurrencyService.Changed.Event:Connect(function(player)
		ButtonService.Refresh(player, false)
	end)

	RunService.Heartbeat:Connect(function(dt)
		refreshAccum += dt
		if refreshAccum < 0.5 then
			return
		end
		refreshAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			ButtonService.Refresh(player, false)
		end
	end)

	PlotService.RegisterCleanup(function(player, plot)
		touchLock[player] = nil
		ButtonService.ResetPlot(plot)
	end)
end

return ButtonService
