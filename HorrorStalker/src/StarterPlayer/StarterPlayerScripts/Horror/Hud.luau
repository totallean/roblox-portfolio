local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Locale = require(ReplicatedStorage:WaitForChild("Horror"):WaitForChild("Locale"))
local T = Locale.get

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local darkEdges: { Frame } = {}
local redEdges: { Frame } = {}
local eye: Frame
local eyeLid: Frame
local pupil: Frame
local status: TextLabel
local keysLabel: TextLabel
local safeLabel: TextLabel
local staminaBack: Frame
local staminaFill: Frame
local notice: TextLabel
local hiddenOverlay: Frame
local fader: Frame
local flashFrame: Frame
local controls: Frame

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function text(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.SpecialElite
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(230, 220, 205)
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.5
	return make("TextLabel", props, parent)
end

-- Screen-edge vignette built from four gradient strips (no image assets needed).
local function edges(color: Color3, thickness: number, list: { Frame })
	local specs = {
		{ UDim2.new(1, 0, thickness, 0), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, thickness, 0), UDim2.new(0, 0, 1 - thickness, 0), -90 },
		{ UDim2.new(thickness * 0.6, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(thickness * 0.6, 0, 1, 0), UDim2.new(1 - thickness * 0.6, 0, 0, 0), 180 },
	}
	for _, spec in specs do
		local frame = make("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = color, BorderSizePixel = 0,
			BackgroundTransparency = 0 }, gui)
		make("UIGradient", {
			Rotation = spec[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		}, frame)
		table.insert(list, frame)
	end
end

function Hud.init()
	gui = make("ScreenGui", { Name = "HorrorHud", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, nil)

	edges(Color3.new(0, 0, 0), 0.32, darkEdges)
	edges(Color3.fromRGB(150, 0, 0), 0.38, redEdges)
	for _, frame in redEdges do
		frame.BackgroundTransparency = 1
	end

	eye = make("Frame", { Name = "Eye", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(84, 40), BackgroundTransparency = 1 }, gui)
	eyeLid = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(235, 225, 210), ClipsDescendants = true }, eye)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, eyeLid)
	pupil = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(20, 0, 0) }, eyeLid)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, pupil)
	status = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(480, 30),
		TextSize = 26, Text = "", TextColor3 = Color3.fromRGB(255, 70, 60) }, gui)

	keysLabel = text({ Position = UDim2.fromOffset(20, 60), Size = UDim2.fromOffset(300, 32), TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, gui)

	safeLabel = text({ Position = UDim2.fromOffset(20, 92), Size = UDim2.fromOffset(460, 26), TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, Text = T("safe"), TextColor3 = Color3.fromRGB(140, 230, 150), Visible = false }, gui)

	staminaBack = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(240, 6), BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.3,
		BorderSizePixel = 0 }, gui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, staminaBack)
	staminaFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 210, 190),
		BorderSizePixel = 0 }, staminaBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, staminaFill)

	notice = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(800, 60),
		TextSize = 34, Text = "", TextTransparency = 1, TextStrokeTransparency = 1 }, gui)

	controls = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20),
		Size = UDim2.fromOffset(420, 132), BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { Padding = UDim.new(0, 2) }, controls)
	for _, key in { "controlsRun", "controlsCrouch", "controlsLight", "controlsHide", "controlsDebug" } do
		text({ Size = UDim2.new(1, 0, 0, 24), TextSize = 19, Text = T(key), TextXAlignment = Enum.TextXAlignment.Left }, controls)
	end

	hiddenOverlay = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, Visible = false }, gui)
	text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.fromOffset(600, 30),
		TextSize = 24, Text = T("hidden") }, hiddenOverlay)

	flashFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(180, 0, 0),
		BackgroundTransparency = 1, ZIndex = 9 }, gui)
	fader = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, ZIndex = 10 }, gui)

	gui.Parent = player:WaitForChild("PlayerGui")

	local function refreshKeys()
		local found = Workspace:GetAttribute("KeysFound") or 0
		local required = Workspace:GetAttribute("KeysRequired") or 0
		keysLabel.Text = string.format(T("keys"), found, required)
	end
	Workspace:GetAttributeChangedSignal("KeysFound"):Connect(refreshKeys)
	Workspace:GetAttributeChangedSignal("KeysRequired"):Connect(refreshKeys)
	refreshKeys()

	task.delay(25, function()
		TweenService:Create(controls, TweenInfo.new(2), { Position = UDim2.new(0, -440, 1, -20) }):Play()
	end)
end

function Hud.setAwareness(value: number, chased: boolean)
	local open = if chased then 1 else value
	eye.Visible = open > 0.02
	eyeLid.Size = UDim2.new(1, 0, 0, 2 + 34 * open)
	local color = if chased then Color3.fromRGB(255, 40, 30)
		else Color3.fromRGB(235, 225, 210):Lerp(Color3.fromRGB(255, 150, 40), value)
	eyeLid.BackgroundColor3 = color
	pupil.Size = UDim2.fromOffset(10 + 10 * open, 10 + 10 * open)
	status.Text = if chased then T("seen") elseif value > 0.35 then T("suspicious") else ""
end

function Hud.setSafe(safe: boolean)
	safeLabel.Visible = safe
end

function Hud.setDanger(danger: number)
	for _, frame in redEdges do
		frame.BackgroundTransparency = 1 - danger * 0.75
	end
end

function Hud.setStamina(fraction: number, exhausted: boolean)
	staminaFill.Size = UDim2.fromScale(fraction, 1)
	staminaFill.BackgroundColor3 = if exhausted then Color3.fromRGB(200, 60, 50) else Color3.fromRGB(220, 210, 190)
	staminaBack.Visible = fraction < 0.999
end

function Hud.setHidden(hidden: boolean)
	hiddenOverlay.Visible = hidden
end

function Hud.notice(message: string, color: Color3?, duration: number?)
	notice.Text = message
	notice.TextColor3 = color or Color3.fromRGB(230, 220, 205)
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.4
	local stamp = message
	task.delay(duration or 3.5, function()
		if notice.Text == stamp then
			TweenService:Create(notice, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Hud.flash()
	flashFrame.BackgroundTransparency = 0.2
	TweenService:Create(flashFrame, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
end

function Hud.fade(transparency: number, duration: number)
	TweenService:Create(fader, TweenInfo.new(duration), { BackgroundTransparency = transparency }):Play()
end

return Hud
