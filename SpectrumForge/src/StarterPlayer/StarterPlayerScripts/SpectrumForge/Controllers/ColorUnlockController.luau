--!strict

local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local ColorUnlockController = {}

local State, UI, Locale, Sound

local CARD = Vector2.new(400, 260)
local GEM = 64
local GEM_Y = 76
local AUTO_CLOSE = 7

local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPIN = TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local queue: { number } = {}
local overlay: TextButton? = nil
local closeTask: thread? = nil

local showNext: () -> ()

local function readable(color: Color3): Color3
	local h, s, v = color:ToHSV()
	if v < 0.6 then
		return Color3.fromHSV(h, s, 0.8)
	end
	return color
end

local function close()
	if closeTask then
		task.cancel(closeTask)
		closeTask = nil
	end
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	if #queue > 0 then
		showNext()
	end
end

function showNext()
	local tier = table.remove(queue, 1)
	if not tier then
		return
	end

	local color = Theme.spectrum(tier)
	local accent = readable(color)
	local screen = UI:GetScreen()

	local button = create("TextButton", {
		Name = "ColorUnlock",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 5, 9),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 45,
		Parent = screen,
	}) :: TextButton
	button.MouseButton1Click:Connect(close)
	overlay = button

	local guiScale = screen:FindFirstChildOfClass("UIScale")
	local factor = if guiScale then guiScale.Scale else 1
	local available = button.AbsoluteSize
	local fit = 1
	if available.X > 0 and available.Y > 0 then
		fit = math.min(1, available.X * 0.94 / (CARD.X * factor), available.Y * 0.9 / (CARD.Y * factor))
	end

	local scale = create("UIScale", { Scale = fit * 0.6 }) :: UIScale
	local card = create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Parent = button,
	}, {
		Widgets.corner(Theme.Radius.L),
		create("UIStroke", { Color = accent, Thickness = 2.5, Transparency = 0.1 }),
		create("UIGradient", {
			Color = ColorSequence.new(color:Lerp(Theme.Color.Panel, 0.55), Theme.Color.Panel),
			Rotation = 90,
		}),
		scale,
	})

	local halo = create("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 22 + GEM / 2),
		Size = UDim2.fromOffset(GEM * 1.35, GEM * 1.35),
		Rotation = 0,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Widgets.corner(Theme.Radius.L),
		create("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.4 }),
	})

	local gemScale = create("UIScale", { Scale = 0 }) :: UIScale
	create("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 22 + GEM / 2),
		Size = UDim2.fromOffset(GEM, GEM),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		Widgets.corner(Theme.Radius.M),
		create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.35 }),
		create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
			Rotation = 90,
		}),
		gemScale,
	})

	local name = Locale:ColorName(tier)
	local title = Widgets.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 150),
		Size = UDim2.new(1, -32, 0, 30),
		Text = Locale:Get("unlock.title", ('<font color="#%s">%s</font>'):format(accent:ToHex(), name)),
		Font = Theme.Font.Bold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		TextTransparency = 1,
		Parent = card,
	})
	create("UITextSizeConstraint", { MaxTextSize = 22, Parent = title })

	local body = Widgets.label({
		Name = "Body",
		Position = UDim2.fromOffset(16, 186),
		Size = UDim2.new(1, -32, 0, 20),
		Text = Locale:Get("unlock.body"),
		TextSize = 16,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = card,
	})

	local hint = Widgets.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -32, 0, 16),
		Text = Locale:Get("wheel.close"),
		TextSize = 12,
		TextColor3 = Theme.Color.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = card,
	})

	TweenService:Create(button, FADE, { BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(scale, POP, { Scale = fit }):Play()
	TweenService:Create(halo, SPIN, { Rotation = 360 }):Play()
	TweenService:Create(halo, PULSE, { BackgroundTransparency = 0.6 }):Play()

	task.delay(0.2, function()
		if overlay ~= button then
			return
		end
		Sound:Play("RareDrop")
		TweenService:Create(gemScale, POP, { Scale = 1 }):Play()
		for _, label in { title, body, hint } do
			TweenService:Create(label, FADE, { TextTransparency = 0 }):Play()
		end
	end)

	closeTask = task.delay(AUTO_CLOSE, function()
		closeTask = nil
		close()
	end)
end

function ColorUnlockController:Init() end

function ColorUnlockController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")
	Sound = self.GetController("SoundController")

	State.Notified:Connect(function(kind, payload)
		if kind ~= "RebirthResult" or type(payload) ~= "table" or type(payload.unlockedColors) ~= "table" then
			return
		end

		local tiers = table.clone(payload.unlockedColors)
		table.sort(tiers)
		for _, tier in tiers do
			if type(tier) == "number" then
				table.insert(queue, tier)
			end
		end

		if not overlay then
			showNext()
		end
	end)
end

return ColorUnlockController
