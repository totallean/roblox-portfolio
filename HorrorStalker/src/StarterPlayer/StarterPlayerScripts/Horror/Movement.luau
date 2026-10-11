local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Horror")
local Config = require(Shared:WaitForChild("Config"))
local input = Shared:WaitForChild("Remotes"):WaitForChild("Input") :: RemoteEvent

local P = Config.Player
local player = Players.LocalPlayer

local Movement = {}

local stamina = P.StaminaMax
local exhausted = false
local lastSprintAt = 0
local sprintHeld = false
local crouching = false
local flashlight = false
local bobClock = 0
local cameraOffset = Vector3.zero

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setCrouch(value: boolean)
	if crouching ~= value then
		crouching = value
		input:FireServer("Crouch", value)
	end
end

local function setFlashlight(value: boolean)
	if flashlight ~= value then
		flashlight = value
		input:FireServer("Flashlight", value)
	end
end

function Movement.init()
	ContextActionService:BindAction("HorrorSprint", function(_, state)
		sprintHeld = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("HorrorCrouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			setCrouch(not crouching)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("HorrorFlashlight", function(_, state)
		if state == Enum.UserInputState.Begin then
			setFlashlight(not flashlight)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("HorrorSprint", "Run")
	ContextActionService:SetTitle("HorrorCrouch", "Crouch")
	ContextActionService:SetTitle("HorrorFlashlight", "Light")

	player.CharacterAdded:Connect(function()
		stamina = P.StaminaMax
		exhausted = false
		crouching = false
		flashlight = false
		cameraOffset = Vector3.zero
	end)
end

function Movement.update(dt: number)
	local h = humanoid()
	if not h or h.Health <= 0 then
		return
	end
	local character = h.Parent :: Model
	if player:GetAttribute("InMenu") then
		h.WalkSpeed = 0
		return
	end
	if character:GetAttribute("Hidden") then
		flashlight = false
		h.CameraOffset = Vector3.zero
		return
	end

	local now = os.clock()
	local moving = h.MoveDirection.Magnitude > 0.1
	local sprinting = sprintHeld and moving and not crouching and not exhausted and stamina > 0
	if sprinting then
		stamina = math.max(0, stamina - P.StaminaDrain * dt)
		lastSprintAt = now
		if stamina <= 0 then
			exhausted = true
		end
	elseif now - lastSprintAt > P.StaminaRegenDelay then
		stamina = math.min(P.StaminaMax, stamina + P.StaminaRegen * dt)
	end
	if exhausted and stamina >= P.StaminaMax * 0.3 then
		exhausted = false
	end

	h.WalkSpeed = if sprinting then P.RunSpeed elseif crouching then P.CrouchSpeed else P.WalkSpeed

	-- First-person head bob and crouch height, applied through the humanoid camera offset.
	local bob = 0
	if moving then
		bobClock += dt * (if sprinting then 13 elseif crouching then 6 else 9)
		bob = math.sin(bobClock) * (if sprinting then 0.16 elseif crouching then 0.05 else 0.08)
	end
	local target = Vector3.new(0, (if crouching then P.CrouchHipOffset else 0) + bob, 0)
	cameraOffset = cameraOffset:Lerp(target, math.min(1, dt * 10))
	h.CameraOffset = cameraOffset
end

function Movement.staminaFraction(): number
	return stamina / P.StaminaMax
end

function Movement.isExhausted(): boolean
	return exhausted
end

function Movement.isCrouching(): boolean
	return crouching
end

function Movement.hasFlashlight(): boolean
	return flashlight
end

return Movement
