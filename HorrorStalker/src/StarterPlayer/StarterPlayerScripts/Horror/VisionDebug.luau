-- Press G to visualise what the stalker sees: a fan of rays clipped by walls, coloured by AI state,
-- plus a label with the state and your awareness. Purely local; useful for demoing the AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Horror"):WaitForChild("Config"))

local S = Config.Stalker
local RAYS = 19

local STATE_COLORS = {
	Patrol = Color3.fromRGB(90, 220, 120),
	Investigate = Color3.fromRGB(255, 200, 60),
	Search = Color3.fromRGB(255, 140, 40),
	Chase = Color3.fromRGB(255, 50, 40),
	Extract = Color3.fromRGB(255, 50, 40),
	Attack = Color3.fromRGB(200, 0, 200),
}

local VisionDebug = {}

local enabled = false
local origin: Attachment
local ends: { Attachment } = {}
local beams: { Beam } = {}
local label: BillboardGui
local labelText: TextLabel
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

function VisionDebug.init()
	origin = Instance.new("Attachment")
	origin.Name = "StalkerVisionOrigin"
	origin.Parent = Workspace.Terrain
	for i = 1, RAYS do
		local target = Instance.new("Attachment")
		target.Name = "StalkerVision" .. i
		target.Parent = Workspace.Terrain
		local beam = Instance.new("Beam")
		beam.Attachment0 = origin
		beam.Attachment1 = target
		beam.Width0 = 0.05
		beam.Width1 = 0.35
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0.35, 0.8)
		beam.Enabled = false
		beam.Parent = Workspace.Terrain
		ends[i] = target
		beams[i] = beam
	end

	label = Instance.new("BillboardGui")
	label.Name = "StalkerDebugLabel"
	label.Size = UDim2.fromOffset(220, 40)
	label.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	label.AlwaysOnTop = true
	label.LightInfluence = 0
	label.Enabled = false
	labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.fromScale(1, 1)
	labelText.BackgroundTransparency = 0.4
	labelText.BackgroundColor3 = Color3.new(0, 0, 0)
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.Font = Enum.Font.Code
	labelText.TextSize = 16
	labelText.Parent = label
	label.Parent = Workspace.Terrain
end

function VisionDebug.toggle()
	enabled = not enabled
	label.Enabled = enabled
	for _, beam in beams do
		beam.Enabled = enabled
	end
end

function VisionDebug.update(stalker: Model?, awareness: number, state: string)
	if not enabled or not stalker then
		return
	end
	local head = stalker:FindFirstChild("Head") :: BasePart?
	local root = stalker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return
	end
	params.FilterDescendantsInstances = { stalker }
	origin.WorldPosition = head.Position
	label.Adornee = head
	labelText.Text = string.format("%s  •  awareness %.2f", state, awareness)

	local color = STATE_COLORS[state] or Color3.new(1, 1, 1)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z).Unit
	local half = math.rad(S.FieldOfView / 2)
	for i = 1, RAYS do
		local angle = -half + (i - 1) / (RAYS - 1) * half * 2
		local direction = CFrame.Angles(0, angle, 0):VectorToWorldSpace(flat) * S.ViewDistance
		local hit = Workspace:Raycast(head.Position, direction, params)
		ends[i].WorldPosition = if hit then hit.Position else head.Position + direction
		beams[i].Color = ColorSequence.new(color)
	end
end

return VisionDebug
