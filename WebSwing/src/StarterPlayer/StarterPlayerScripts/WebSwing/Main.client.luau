local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Locale = require(ReplicatedStorage:WaitForChild("WebSwing"):WaitForChild("Locale"))
local Targeting = require(script.Parent:WaitForChild("Targeting"))
local SwingController = require(script.Parent:WaitForChild("SwingController"))
local CameraFX = require(script.Parent:WaitForChild("CameraFX"))
local RemoteWebs = require(script.Parent:WaitForChild("RemoteWebs"))
local Hud = require(script.Parent:WaitForChild("Hud"))

Targeting.init()
SwingController.init()
CameraFX.init()
RemoteWebs.init()
Hud.init()

local function onSwing(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		SwingController.setSwingHeld(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		SwingController.setSwingHeld(false)
	end
	return Enum.ContextActionResult.Pass
end

local function onZip(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		SwingController.zip()
	end
	return Enum.ContextActionResult.Sink
end

local function onReel(_, state: Enum.UserInputState)
	SwingController.setReel(state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change)
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("WebSwing", onSwing, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("WebZip", onZip, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("WebReel", onReel, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1)

ContextActionService:SetTitle("WebSwing", Locale.get("swingButton"))
ContextActionService:SetTitle("WebZip", Locale.get("zipButton"))
ContextActionService:SetTitle("WebReel", Locale.get("reelButton"))
ContextActionService:SetPosition("WebSwing", UDim2.new(1, -150, 1, -150))
ContextActionService:SetPosition("WebZip", UDim2.new(1, -220, 1, -100))
ContextActionService:SetPosition("WebReel", UDim2.new(1, -210, 1, -190))

UserInputService.JumpRequest:Connect(function()
	SwingController.jumpOff()
end)

RunService.PreRender:Connect(function(dt)
	Targeting.update(SwingController.getRoot())
	CameraFX.update(dt)
	Hud.update()
end)

RunService.PreSimulation:Connect(function(dt)
	SwingController.step(dt)
end)
