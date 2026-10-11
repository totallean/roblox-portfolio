-- Main menu and game-over screen. The "cover" is a live 3D shot: the camera slowly dollies down a dark
-- corridor (Workspace.MenuStage) toward a posed stalker under a flickering lamp; UI sits on top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Horror")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))

local T = Locale.get
local player = Players.LocalPlayer

export type Callbacks = {
	onPlay: () -> (),
	onRestart: () -> (),
	onMainMenu: () -> (),
}

local RED = Color3.fromRGB(200, 28, 28)
local PAPER = Color3.fromRGB(225, 212, 192)
local DIM = Color3.fromRGB(150, 140, 128)
local CAMERA_PERIOD = 22

local Menu = {}

local gui: ScreenGui
local mainScreen: CanvasGroup
local howPanel: Frame
local overScreen: CanvasGroup
local overTitle: TextLabel
local overStats: TextLabel
local callbacks: Callbacks
local isOpen = false
local cameraBound = false
local cameraClock = 0
local flickerClock = 0
local savedDensity: number? = nil
local curtain: Frame
local firstShow = true

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- Creepster has no Cyrillic glyphs, so Russian headings use Merriweather instead.
local function headingFont(): Enum.Font
	return if Locale.language() == "ru" then Enum.Font.Merriweather else Enum.Font.Creepster
end

local function menuButton(parent: Instance, name: string, text: string, order: number, align: Enum.TextXAlignment, onClick: () -> ()): TextButton
	local button = make("TextButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 54),
		Font = Enum.Font.SpecialElite,
		Text = text,
		TextSize = 34,
		TextColor3 = PAPER,
		TextXAlignment = align,
		LayoutOrder = order,
		-- Modal frees the mouse while the camera mode is locked first person.
		Modal = true,
	}, parent)
	local underline = make("Frame", {
		AnchorPoint = Vector2.new(if align == Enum.TextXAlignment.Center then 0.5 else 0, 1),
		Position = UDim2.new(if align == Enum.TextXAlignment.Center then 0.5 else 0, 0, 1, -4),
		Size = UDim2.fromOffset(0, 3),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
	}, button)
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, info, { TextColor3 = RED }):Play()
		TweenService:Create(underline, info, { Size = UDim2.fromOffset(130, 3) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, info, { TextColor3 = PAPER }):Play()
		TweenService:Create(underline, info, { Size = UDim2.fromOffset(0, 3) }):Play()
	end)
	button.Activated:Connect(onClick)
	return button
end

local function buildMain()
	mainScreen = make("CanvasGroup", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)

	local shade = make("Frame", { Size = UDim2.fromScale(0.65, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, mainScreen)
	make("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.55, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	}) }, shade)

	make("TextLabel", {
		Name = "Logo", Position = UDim2.fromScale(0.07, 0.18), Size = UDim2.fromScale(0.5, 0.2), BackgroundTransparency = 1,
		Font = Enum.Font.Creepster, Text = "THE STALKER", TextScaled = true, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
	}, mainScreen)
	make("TextLabel", {
		Name = "Tagline", Position = UDim2.fromScale(0.07, 0.39), Size = UDim2.fromScale(0.5, 0.045), BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite, Text = string.format(T("tagline"), Config.Keys.Required), TextScaled = true, TextColor3 = PAPER,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, mainScreen)

	local list = make("Frame", { Name = "Buttons", Position = UDim2.fromScale(0.07, 0.52), Size = UDim2.new(0.3, 0, 0, 130), BackgroundTransparency = 1 }, mainScreen)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	menuButton(list, "Play", T("play"), 1, Enum.TextXAlignment.Left, function()
		callbacks.onPlay()
	end)
	menuButton(list, "HowToPlay", T("howToPlay"), 2, Enum.TextXAlignment.Left, function()
		howPanel.Visible = not howPanel.Visible
	end)

	howPanel = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.95, 0.5), Size = UDim2.new(0.36, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(12, 10, 10), BackgroundTransparency = 0.12, Visible = false,
	}, mainScreen)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, howPanel)
	make("UIStroke", { Color = RED, Thickness = 1, Transparency = 0.3 }, howPanel)
	make("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 14) }, howPanel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, howPanel)
	make("TextLabel", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Font = headingFont(), Text = T("howToPlay"),
		TextSize = 34, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left }, howPanel)
	local order = 1
	for _, key in { "controlsRun", "controlsCrouch", "controlsLight", "controlsHide", "controlsDebug", "", "tipDark", "tipNoise", "tipHide", "tipSafe" } do
		make("TextLabel", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, if key == "" then 8 else 0),
			AutomaticSize = if key == "" then Enum.AutomaticSize.None else Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.SpecialElite, Text = if key == "" then "" else T(key), TextSize = 19, TextWrapped = true,
			TextColor3 = if string.sub(key, 1, 3) == "tip" then DIM else PAPER, TextXAlignment = Enum.TextXAlignment.Left }, howPanel)
		order += 1
	end
	menuButton(howPanel, "Close", T("close"), order, Enum.TextXAlignment.Left, function()
		howPanel.Visible = false
	end)
end

local function buildGameOver()
	overScreen = make("CanvasGroup", { Name = "GameOver", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	local tint = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 0, 0), BorderSizePixel = 0 }, overScreen)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(90, 0, 0), Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new(0.25, 0.05),
	}, tint)

	overTitle = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.8, 0.17), BackgroundTransparency = 1,
		Font = headingFont(), Text = "", TextScaled = true, TextColor3 = RED, TextStrokeTransparency = 0.3,
	}, overScreen)
	overStats = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.49), Size = UDim2.fromScale(0.6, 0.045), BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite, Text = "", TextScaled = true, TextColor3 = PAPER,
	}, overScreen)

	local row = make("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.new(0, 560, 0, 60),
		BackgroundTransparency = 1 }, overScreen)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 40), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local restart = menuButton(row, "Restart", T("restart"), 1, Enum.TextXAlignment.Center, function()
		callbacks.onRestart()
	end)
	local menu = menuButton(row, "MainMenu", T("mainMenu"), 2, Enum.TextXAlignment.Center, function()
		callbacks.onMainMenu()
	end)
	restart.Size = UDim2.new(0, 240, 1, 0)
	menu.Size = UDim2.new(0, 260, 1, 0)
end

-- Camera & input ------------------------------------------------------------------------------

-- Best effort: newer clients don't expose PlayerModule under PlayerScripts (requiring the StarterPlayer
-- template would start a second controller). Movement.luau zeroes WalkSpeed while InMenu is set, so the
-- player can never walk around behind the menu either way.
local function setControls(enabled: boolean)
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module or not module:IsA("ModuleScript") then
		return
	end
	local ok, playerModule = pcall(require, module)
	if ok and typeof(playerModule) == "table" and playerModule.GetControls then
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

local function bindCamera()
	if cameraBound then
		return
	end
	local stage = Workspace:FindFirstChild("MenuStage")
	local startPart = stage and stage:FindFirstChild("CameraStart") :: BasePart?
	local endPart = stage and stage:FindFirstChild("CameraEnd") :: BasePart?
	if not startPart or not endPart then
		return
	end
	local lamp = stage:FindFirstChild("Lamp")
	local light = lamp and lamp:FindFirstChild("Cone") :: SpotLight?
	cameraBound = true
	-- The gameplay fog is tuned for 15-stud visibility; the cover shot needs a little more (client-only).
	local atmosphere = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
	if atmosphere and not savedDensity then
		savedDensity = atmosphere.Density
		atmosphere.Density = 0.18
	end
	RunService:BindToRenderStep("HorrorMenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		cameraClock += dt
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		local alpha = (1 - math.cos(cameraClock / CAMERA_PERIOD * math.pi)) / 2
		local sway = CFrame.Angles(math.sin(cameraClock * 0.6) * 0.008, math.sin(cameraClock * 0.43) * 0.012, math.sin(cameraClock * 0.3) * 0.004)
		camera.CFrame = startPart.CFrame:Lerp(endPart.CFrame, alpha) * sway
		camera.FieldOfView = 48

		flickerClock += dt
		if light and flickerClock > 0.09 then
			flickerClock = 0
			local roll = math.random()
			light.Brightness = if roll < 0.05 then 0 elseif roll < 0.12 then 1.2 else 3.2
		end
	end)
end

local function unbindCamera()
	if not cameraBound then
		return
	end
	cameraBound = false
	RunService:UnbindFromRenderStep("HorrorMenuCamera")
	local atmosphere = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
	if atmosphere and savedDensity then
		atmosphere.Density = savedDensity
		savedDensity = nil
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function setOpen(open: boolean)
	isOpen = open
	player:SetAttribute("InMenu", open)
	setControls(not open)
	local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HorrorHud")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = not open
	end
	if open then
		bindCamera()
	else
		unbindCamera()
	end
end

local function fadeIn(screen: CanvasGroup)
	screen.Visible = true
	screen.GroupTransparency = 1
	TweenService:Create(screen, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
end

-- API ------------------------------------------------------------------------------------------

function Menu.init(handlers: Callbacks)
	callbacks = handlers
	gui = make("ScreenGui", { Name = "HorrorMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
	buildMain()
	buildGameOver()
	-- Local lights take a moment to settle after joining; the first menu fades in from black over it.
	curtain = make("Frame", { Name = "Curtain", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 10, Visible = false }, gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- A respawn behind an open menu must not hand movement back to the player.
	player.CharacterAdded:Connect(function()
		if isOpen then
			task.defer(setControls, false)
		end
	end)
end

function Menu.showMain()
	overScreen.Visible = false
	howPanel.Visible = false
	setOpen(true)
	fadeIn(mainScreen)
	if firstShow then
		firstShow = false
		curtain.Visible = true
		curtain.BackgroundTransparency = 0
		local reveal = TweenService:Create(curtain, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.2),
			{ BackgroundTransparency = 1 })
		reveal.Completed:Once(function()
			curtain.Visible = false
		end)
		reveal:Play()
	end
end

function Menu.showGameOver(caught: boolean, survivedSeconds: number)
	mainScreen.Visible = false
	overTitle.Text = T(if caught then "gameOverCaught" else "gameOverDied")
	overStats.Text = string.format(T("survived"), Locale.formatTime(survivedSeconds),
		Workspace:GetAttribute("KeysFound") or 0, Workspace:GetAttribute("KeysRequired") or Config.Keys.Required)
	setOpen(true)
	fadeIn(overScreen)
end

function Menu.close()
	mainScreen.Visible = false
	overScreen.Visible = false
	setOpen(false)
end

function Menu.isOpen(): boolean
	return isOpen
end

return Menu
