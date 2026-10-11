local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("WebSwing")
local Locale = require(Shared:WaitForChild("Locale"))
local SwingController = require(script.Parent:WaitForChild("SwingController"))

local player = Players.LocalPlayer
local T = Locale.get

local Hud = {}

local RING_IDLE = Color3.fromRGB(90, 120, 200)
local RING_NEXT = Color3.fromRGB(255, 214, 64)

local gui: ScreenGui
local speedLabel: TextLabel
local raceLabel: TextLabel
local timerLabel: TextLabel
local banner: TextLabel

local rings: { Model } = {}
local nextRing = 1
local raceStartedAt: number? = nil
local guideBeam: Beam
local guideTarget: Attachment

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "WebSwingHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = Instance.new("Frame")
	panel.Name = "Controls"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 16, 1, -16)
	panel.Size = UDim2.fromOffset(300, 128)
	panel.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
	panel.BackgroundTransparency = 0.35
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = panel

	label(panel, { Text = T("controlsTitle"), TextSize = 16, Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 90, 90) })
	for _, key in { "controlsSwing", "controlsZip", "controlsReel", "controlsJump" } do
		label(panel, { Text = T(key), TextSize = 14, Font = Enum.Font.Gotham, Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left })
	end

	speedLabel = label(gui, { Name = "Speed", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(240, 40), TextSize = 30, Text = "" })

	raceLabel = label(gui, { Name = "Race", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(520, 26), TextSize = 20, Text = T("raceHint") })
	timerLabel = label(gui, { Name = "Timer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(300, 44), TextSize = 38, Text = "", TextColor3 = RING_NEXT })
	banner = label(gui, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(640, 90), TextSize = 40, Text = "", TextTransparency = 1, TextStrokeTransparency = 1 })

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function paintRings()
	for index, ring in rings do
		local isNext = index == nextRing
		for _, part in ring:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Segment" then
				part.Color = if isNext then RING_NEXT else RING_IDLE
				part.Transparency = if isNext then 0 elseif index < nextRing then 0.85 else 0.45
			end
		end
	end
	local target = rings[nextRing]
	local core = target and target:FindFirstChild("Core") :: BasePart?
	if core then
		guideTarget.WorldPosition = core.Position
	end
end

local function showBanner(text: string, color: Color3)
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.4
	banner.Size = UDim2.fromOffset(500, 70)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(640, 90) }):Play()
	task.delay(3, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function buildGuide()
	guideTarget = Instance.new("Attachment")
	guideTarget.Name = "RaceGuide"
	guideTarget.Parent = Workspace.Terrain
	guideBeam = Instance.new("Beam")
	guideBeam.Attachment1 = guideTarget
	guideBeam.Color = ColorSequence.new(RING_NEXT)
	guideBeam.Width0 = 0.25
	guideBeam.Width1 = 0.25
	guideBeam.FaceCamera = true
	guideBeam.LightEmission = 1
	guideBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.75),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	guideBeam.Enabled = false
	guideBeam.Parent = Workspace.Terrain
end

local function collectRings()
	local arena = Workspace:WaitForChild("WebSwingArena")
	local folder = arena:WaitForChild("RaceRings")
	for _, ring in folder:GetChildren() do
		if ring:IsA("Model") then
			rings[ring:GetAttribute("Index") :: number] = ring
		end
	end
end

function Hud.init()
	buildGui()
	buildGuide()
	collectRings()
	paintRings()

	local remote = Shared:WaitForChild("Remotes"):WaitForChild("Race") :: RemoteEvent
	remote.OnClientEvent:Connect(function(action: string, a: any, b: any, c: any)
		if action == "Progress" then
			nextRing = a
			raceStartedAt = b
			raceLabel.Text = string.format(T("raceRing"), math.min(a, #rings), #rings)
			paintRings()
		elseif action == "Finished" then
			nextRing = 1
			raceStartedAt = nil
			paintRings()
			raceLabel.Text = string.format(T("raceBest"), Locale.formatTime(b))
			timerLabel.Text = Locale.formatTime(a)
			local text = string.format(T("raceFinished"), Locale.formatTime(a))
			if c then
				text ..= "\n" .. T("raceNewBest")
			end
			showBanner(text, if c then RING_NEXT else Color3.new(1, 1, 1))
		elseif action == "Reset" then
			nextRing = 1
			raceStartedAt = nil
			timerLabel.Text = ""
			raceLabel.Text = T("raceHint")
			paintRings()
		end
	end)
end

function Hud.update()
	local root = SwingController.getRoot()
	if root then
		local speed = root.AssemblyLinearVelocity.Magnitude
		speedLabel.Text = if speed > 8 then string.format(T("speed"), math.floor(speed)) else ""
		local rootAttachment = root:FindFirstChild("RootAttachment") :: Attachment?
		guideBeam.Attachment0 = rootAttachment
		guideBeam.Enabled = rootAttachment ~= nil and rings[nextRing] ~= nil
	end
	if raceStartedAt then
		timerLabel.Text = Locale.formatTime(Workspace:GetServerTimeNow() - raceStartedAt)
	end
end

return Hud
