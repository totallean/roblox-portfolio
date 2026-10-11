--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Eco = require(ReplicatedStorage.SpectrumForge.Shared.EconomyConfig)

local Theme = {}

Theme.Color = {
	Panel = Color3.fromRGB(10, 12, 18),
	PanelSoft = Color3.fromRGB(18, 21, 30),
	Slot = Color3.fromRGB(26, 30, 42),
	Bevel = Color3.fromRGB(58, 66, 86),

	Text = Color3.fromRGB(240, 244, 252),
	TextDim = Color3.fromRGB(146, 156, 176),
	TextMuted = Color3.fromRGB(96, 104, 124),

	Will = Color3.fromRGB(88, 228, 142),
	Shard = Color3.fromRGB(116, 188, 255),
	Charge = Color3.fromRGB(255, 196, 72),
	Xp = Color3.fromRGB(255, 176, 64),

	Positive = Color3.fromRGB(78, 214, 128),
	Negative = Color3.fromRGB(238, 92, 92),
	Badge = Color3.fromRGB(226, 62, 62),
}

Theme.Font = {
	Bold = Enum.Font.GothamBold,
	Regular = Enum.Font.Gotham,
	Number = Enum.Font.GothamBold,
}

Theme.Pad = { XS = 3, S = 6, M = 10, L = 16, XL = 24 }
Theme.Radius = { S = 4, M = 7, L = 12 }
Theme.TouchTarget = 48

Theme.PanelTransparency = 0.12

local accent = Color3.fromRGB(40, 220, 90)

local strokes: { [UIStroke]: boolean } = {}
local accentBits: { [GuiObject]: boolean } = {}

local function track(registry: { [any]: boolean }, object: Instance)
	registry[object] = true
	object.Destroying:Connect(function()
		registry[object] = nil
	end)
end

function Theme.getAccent(): Color3
	return accent
end

function Theme.trackStroke(stroke: UIStroke)
	track(strokes, stroke)
	stroke.Color = accent
end

function Theme.trackFill(object: GuiObject)
	track(accentBits, object)
	object.BackgroundColor3 = accent
end

function Theme.setAccent(color: Color3)
	if color == accent then
		return
	end
	accent = color

	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
	for stroke in strokes do
		if stroke.Parent then
			TweenService:Create(stroke, info, { Color = color }):Play()
		end
	end
	for bit in accentBits do
		if bit.Parent then
			TweenService:Create(bit, info, { BackgroundColor3 = color }):Play()
		end
	end
end

function Theme.spectrum(tier: number): Color3
	local entry = Eco.COLORS[tier]
	return if entry then entry.color else Theme.Color.Text
end

function Theme.spectrumName(tier: number): string
	local entry = Eco.COLORS[tier]
	return if entry then entry.name else "?"
end

function Theme.spectrumEn(tier: number): string
	local entry = Eco.COLORS[tier]
	return if entry then (entry.en or "") else ""
end

function Theme.attachScale(parent: Instance): UIScale
	local scale = Instance.new("UIScale")

	local function recompute()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local base = math.clamp(camera.ViewportSize.Y / 900, 0.85, 1.3)
		if UserInputService.TouchEnabled then
			base *= 1.15
		end
		scale.Scale = base
	end

	local viewportConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
		end
		recompute()
	end

	bindCamera()
	scale.Parent = parent
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

	return scale
end

return Theme
