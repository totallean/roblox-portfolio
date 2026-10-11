--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)
local Format = require(Shared.Format)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local RingController = {}

local State, UI, Locale
local shop = {}
local rebirth = {}

local function popFeedback(parent: Instance, text: string, color: Color3)
	local label = Widgets.label({
		Size = UDim2.fromOffset(120, 24),
		Position = UDim2.new(0.5, -60, 0, 10),
		Text = text,
		TextColor3 = color,
		Font = Theme.Font.Bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})

	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, {
		Position = UDim2.new(0.5, -60, 0, -34),
		TextTransparency = 1,
	}):Play()

	task.delay(0.75, function()
		label:Destroy()
	end)
end

local function buildTapButton()
	local button = UI:AddHotbarSlot(1, "hotbar.charge", Theme.Color.Will, function()
		State:Send("Tap")

		local gain = math.max(1, (State:Get("wps") or 0) * Eco.TAP_WPS_FRACTION)
		popFeedback(UI:GetActionLayer(), "+" .. Format.short(gain), Theme.Color.Will)
	end)

	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 2
		stroke.Transparency = 0.1
		State:Observe("colorTier", function(tier)
			TweenService:Create(stroke, TweenInfo.new(0.3), {
				Color = Theme.spectrum(tier),
			}):Play()
		end)
	end

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.06), { Size = UDim2.fromOffset(78, 78) }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { Size = UDim2.fromOffset(84, 84) }):Play()
	end)
end

local function buildShopPanel()
	local body = UI:CreatePanel("Ring", "ring.title")
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})
	Widgets.list({ Padding = UDim.new(0, Theme.Pad.M) }).Parent = body

	shop.level = Widgets.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 18,
		Parent = body,
	})

	shop.rate = Widgets.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 15,
		Parent = body,
	})

	shop.costOne = Widgets.button({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Name = "BuyOne",
		Text = "",
		Parent = body,
	})
	shop.costOne.MouseButton1Click:Connect(function()
		State:Send("BuyRing", 1)
	end)

	shop.costMax = Widgets.button({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Name = "BuyMax",
		Text = "",
		BackgroundColor3 = Theme.Color.Will:Lerp(Theme.Color.Panel, 0.6),
		Parent = body,
	})
	shop.costMax.MouseButton1Click:Connect(function()
		State:Send("BuyRing", 0)
	end)
end

local function buildRebirthPanel()
	local body = UI:CreatePanel("Rebirth", "rebirth.title")
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})
	Widgets.list({ Padding = UDim.new(0, Theme.Pad.M) }).Parent = body

	rebirth.blurb = Widgets.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Name = "RebirthBlurb",
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 14,
		TextWrapped = true,
		Parent = body,
	})

	rebirth.status = Widgets.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 16,
		Parent = body,
	})

	local track = Widgets.panel({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Theme.Color.PanelSoft,
		Parent = body,
	})
	rebirth.fill = Widgets.panel({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.Charge,
		Parent = track,
	})

	rebirth.multiplier = Widgets.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = Theme.Color.Charge,
		TextSize = 15,
		Parent = body,
	})

	rebirth.nextColor = create("Frame", {
		Name = "NextColor",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	rebirth.swatch = create("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BorderSizePixel = 0,
		Parent = rebirth.nextColor,
	}, {
		Widgets.corner(Theme.Radius.S),
		create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.5, Thickness = 1 }),
	})
	rebirth.nextLabel = Widgets.label({
		Name = "Text",
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Text = "",
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = rebirth.nextColor,
	})

	rebirth.button = Widgets.button({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Text = "",
		BackgroundColor3 = Theme.Color.Charge:Lerp(Theme.Color.Panel, 0.6),
		Parent = body,
	})
	rebirth.button.MouseButton1Click:Connect(function()
		State:Send("Rebirth")
	end)
end

local function refresh()
	local level = State:Get("ringLevel") or 1
	local rebirths = State:Get("rebirths") or 0
	local charge = State:Get("totalCharge") or 0

	shop.level.Text = Locale:Get("ring.level", level)
	shop.rate.Text = Locale:Get("ring.next",
		Format.short(Eco.ringWPS(level + 1) - Eco.ringWPS(level)))
	shop.costOne.Text = Locale:Get("ring.buyOne", Format.short(Eco.ringCost(level)))

	local required = Eco.rebirthRequirement(rebirths + 1)
	local progress = math.clamp(level / required, 0, 1)

	rebirth.status.Text = Locale:Get("rebirth.status", level, required)
	rebirth.fill.Size = UDim2.fromScale(progress, 1)
	rebirth.multiplier.Text = Locale:Get("rebirth.multiplier",
		Format.multiplier(Eco.rebirthMultiplier(charge)),
		Format.multiplier(Eco.rebirthMultiplier(charge + Eco.rebirthCharge(rebirths + 1, required)))
	)

	local tier, at = Eco.nextColorUnlock(rebirths)
	rebirth.nextColor.Visible = tier ~= nil
	if tier and at then
		rebirth.swatch.BackgroundColor3 = Theme.spectrum(tier)
		rebirth.nextLabel.Text = Locale:Get("rebirth.nextColor", Locale:ColorName(tier), at, at - rebirths)
	end

	local ready = level >= required
	rebirth.button.Text = if ready then Locale:Get("rebirth.do")
		else Locale:Get("rebirth.need", required - level)
	rebirth.button.BackgroundTransparency = if ready then 0 else 0.55
end

function RingController:Init() end

function RingController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")

	buildTapButton()
	buildShopPanel()
	buildRebirthPanel()

	UI:AddNavButton("menu.ring", 1, function()
		UI:TogglePanel("Ring")
	end)
	UI:AddNavButton("menu.rebirth", 2, function()
		UI:TogglePanel("Rebirth")
	end)

	State:ObserveAll({ "ringLevel", "rebirths", "totalCharge" }, refresh)

	Locale:Bind(shop.costMax, "ring.buyMax")
	Locale:Bind(rebirth.blurb, "rebirth.blurb")

	Locale:Observe(refresh)
end

return RingController
