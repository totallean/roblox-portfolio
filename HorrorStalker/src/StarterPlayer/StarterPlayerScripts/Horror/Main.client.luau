local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Horror")
local Locale = require(Shared:WaitForChild("Locale"))
local Config = require(Shared:WaitForChild("Config"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Feedback = require(script.Parent:WaitForChild("Feedback"))
local Lamps = require(script.Parent:WaitForChild("Lamps"))
local VisionDebug = require(script.Parent:WaitForChild("VisionDebug"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local T = Locale.get
local player = game:GetService("Players").LocalPlayer
local safeZone = workspace:WaitForChild("Mansion"):WaitForChild("SafeZone") :: BasePart

local function inSafeZone(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local p = safeZone.CFrame:PointToObjectSpace(root.Position)
	local half = safeZone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

Hud.init()
Movement.init()
Feedback.init()
Lamps.init()
VisionDebug.init()

ContextActionService:BindAction("HorrorVisionDebug", function(_, state)
	if state == Enum.UserInputState.Begin then
		VisionDebug.toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G)

-- Prompts are created on the server in English; each client swaps in its own language.
local localized: { [ProximityPrompt]: boolean } = {}
local function localize(prompt: ProximityPrompt)
	local textKey = prompt:GetAttribute("TextKey")
	local objectKey = prompt:GetAttribute("ObjectKey")
	if typeof(textKey) == "string" then
		prompt.ActionText = T(textKey)
	end
	if typeof(objectKey) == "string" then
		prompt.ObjectText = T(objectKey)
	end
end
ProximityPromptService.PromptShown:Connect(function(prompt)
	localize(prompt)
	if not localized[prompt] then
		localized[prompt] = true
		prompt:GetAttributeChangedSignal("TextKey"):Connect(function()
			localize(prompt)
		end)
		prompt.Destroying:Connect(function()
			localized[prompt] = nil
		end)
	end
end)

local gameRemote = Shared:WaitForChild("Remotes"):WaitForChild("Game") :: RemoteEvent
gameRemote.OnClientEvent:Connect(function(action: string, a: any, b: any)
	if action == "KeyFound" then
		Hud.notice(string.format(T("keyFound"), tostring(a)), Color3.fromRGB(255, 205, 90))
	elseif action == "ExitOpen" then
		Hud.notice(T("exitOpen"), Color3.fromRGB(140, 255, 160), 5)
	elseif action == "Escaped" then
		Hud.notice(string.format(T("escaped"), tostring(a), Locale.formatTime(b)), Color3.fromRGB(140, 255, 160), 6)
	elseif action == "NewRound" then
		Hud.notice(T("newRound"))
	end
end)

-- Menu flow: title screen on join; after a death the game-over screen asks the server for a respawn.
local input = Shared:WaitForChild("Remotes"):WaitForChild("Input") :: RemoteEvent
local lifeStartedAt = os.clock()
local caughtAt = -math.huge

local function alive(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

Menu.init({
	onPlay = function()
		Menu.close()
		lifeStartedAt = os.clock()
		Hud.notice(T("title") .. "\n" .. string.format(T("goal"), Config.Keys.Required), Color3.fromRGB(230, 220, 205), 6)
	end,
	onRestart = function()
		Menu.close()
		if alive() then
			Hud.fade(1, 0.6)
		else
			-- Stay black until the new character arrives (Feedback fades back in on spawn).
			Hud.fade(0, 0)
			input:FireServer("Respawn", true)
		end
	end,
	onMainMenu = function()
		Menu.showMain()
		input:FireServer("Respawn", true)
	end,
})

Feedback.Caught:Connect(function()
	caughtAt = os.clock()
end)

local function watchCharacter(character: Model)
	lifeStartedAt = os.clock()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local caught = os.clock() - caughtAt < 3
		local survived = os.clock() - lifeStartedAt
		task.delay(if caught then 0.6 else 1.5, function()
			Menu.showGameOver(caught, survived)
		end)
	end)
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

Menu.showMain()

RunService.RenderStepped:Connect(function(dt)
	Movement.update(dt)
	Hud.setStamina(Movement.staminaFraction(), Movement.isExhausted())
	Feedback.update(dt)
	Hud.setSafe(inSafeZone())
	local stalker = Feedback.stalker()
	local root = stalker and stalker:FindFirstChild("HumanoidRootPart") :: BasePart?
	Lamps.update(dt, root and root.Position)
	local awareness, state = Feedback.getState()
	VisionDebug.update(stalker, awareness, state)
end)
