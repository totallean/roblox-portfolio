local Players = game:GetService("Players")

local StalkerRig = {}

local SKIN = Color3.fromRGB(16, 14, 17)
local EYE = Color3.fromRGB(255, 30, 30)

-- Tall, thin, faceless R15 figure with glowing eyes, built from a HumanoidDescription at runtime.
function StalkerRig.build(): Model
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = 1.3
	description.WidthScale = 0.72
	description.DepthScale = 0.8
	description.HeadScale = 0.95
	description.BodyTypeScale = 0.35
	description.ProportionScale = 1
	description.HeadColor = SKIN
	description.TorsoColor = SKIN
	description.LeftArmColor = SKIN
	description.RightArmColor = SKIN
	description.LeftLegColor = SKIN
	description.RightLegColor = SKIN

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Stalker"
	model:SetAttribute("IsStalker", true)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	local head = model:FindFirstChild("Head") :: BasePart
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	for _, x in { -0.2, 0.2 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.16, 0.16, 0.16)
		eye.Material = Enum.Material.Neon
		eye.Color = EYE
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(x * head.Size.X, head.Size.Y * 0.1, -head.Size.Z / 2 + 0.03)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = model
	end
	local glow = Instance.new("PointLight")
	glow.Color = EYE
	glow.Range = 7
	glow.Brightness = 0.9
	glow.Parent = head

	return model
end

return StalkerRig
