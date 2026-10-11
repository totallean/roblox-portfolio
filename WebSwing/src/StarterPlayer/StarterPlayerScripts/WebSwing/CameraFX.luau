local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("WebSwing"):WaitForChild("Config"))
local SwingController = require(script.Parent:WaitForChild("SwingController"))

local CameraFX = {}

local shake = 0
local windVolume: Part
local wind: ParticleEmitter

local function buildWind()
	windVolume = Instance.new("Part")
	windVolume.Name = "WindVolume"
	windVolume.Anchored = true
	windVolume.CanCollide = false
	windVolume.CanQuery = false
	windVolume.CanTouch = false
	windVolume.Transparency = 1
	windVolume.Size = Vector3.new(28, 18, 6)

	wind = Instance.new("ParticleEmitter")
	wind.Shape = Enum.ParticleEmitterShape.Box
	wind.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	wind.EmissionDirection = Enum.NormalId.Back
	wind.Orientation = Enum.ParticleOrientation.VelocityParallel
	wind.Speed = NumberRange.new(20, 30)
	wind.Lifetime = NumberRange.new(0.25, 0.4)
	wind.Size = NumberSequence.new(0.06)
	wind.Squash = NumberSequence.new(-2.5)
	wind.LightEmission = 1
	wind.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	wind.Rate = 0
	wind.Parent = windVolume
	windVolume.Parent = Workspace.CurrentCamera
end

function CameraFX.init()
	buildWind()
	SwingController.WebAttached:Connect(function(kind: string)
		shake = if kind == "Zip" then 0.5 else 0.3
	end)
end

function CameraFX.update(dt: number)
	local camera = Workspace.CurrentCamera
	local root = SwingController.getRoot()
	local humanoid = SwingController.getHumanoid()
	if not camera or not root or not humanoid then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local airborne = SwingController.getMode() ~= "Ground"

	local t = math.clamp((speed - Config.FovSpeedStart) / (Config.FovSpeedFull - Config.FovSpeedStart), 0, 1)
	local targetFov = if airborne then Config.BaseFov + (Config.MaxFov - Config.BaseFov) * t else Config.BaseFov
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 5)

	shake = math.max(0, shake - dt * 1.6)
	if shake > 0 then
		local r = Random.new()
		humanoid.CameraOffset = Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-1, 1), 0) * shake
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
	end

	if airborne and speed > Config.WindSpeedThreshold then
		local direction = velocity.Unit
		local center = root.Position + direction * 22
		windVolume.CFrame = CFrame.lookAt(center, center + direction)
		wind.Speed = NumberRange.new(speed * 0.25, speed * 0.35)
		wind.Rate = (speed - Config.WindSpeedThreshold) * 1.5
	else
		wind.Rate = 0
	end
end

return CameraFX
