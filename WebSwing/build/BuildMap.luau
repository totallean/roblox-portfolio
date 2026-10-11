-- Edit-mode generator for the Web Swing demo: a minimal greybox loop, so the focus stays on the code.
-- One central block and a ring of towers form a 50-stud lane that loops around; race rings follow it.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

for _, name in { "WebSwingArena", "WebSwingCity", "Baseplate", "SpawnLocation" } do
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local arena = Instance.new("Model")
arena.Name = "WebSwingArena"
arena.Parent = Workspace
local geometry = Instance.new("Folder")
geometry.Name = "Geometry"
geometry.Parent = arena
local ringsFolder = Instance.new("Folder")
ringsFolder.Name = "RaceRings"
ringsFolder.Parent = arena

local LIGHT = Color3.fromRGB(163, 162, 165)
local DARK = Color3.fromRGB(99, 95, 98)
local ACCENT = Color3.fromRGB(196, 40, 28)

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p :: BasePart
end

local BLOCK = 140
local BLOCK_HEIGHT = 150
local TOWER = 24
local TOWER_OFFSET = 132
local TOWER_STEP = 44

part({ Name = "Ground", Size = Vector3.new(600, 2, 600), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(91, 93, 105) }, geometry)
part({ Name = "CentralBlock", Size = Vector3.new(BLOCK, BLOCK_HEIGHT, BLOCK), Position = Vector3.new(0, BLOCK_HEIGHT / 2, 0),
	Color = LIGHT }, geometry)

local index = 0
local placed: { [string]: boolean } = {}
for t = -TOWER_OFFSET, TOWER_OFFSET, TOWER_STEP do
	for _, position in { Vector3.new(TOWER_OFFSET, 0, t), Vector3.new(-TOWER_OFFSET, 0, t), Vector3.new(t, 0, TOWER_OFFSET), Vector3.new(t, 0, -TOWER_OFFSET) } do
		local key = position.X .. "," .. position.Z
		if not placed[key] then
			placed[key] = true
			index += 1
			local height = if index % 2 == 0 then 170 else 120
			part({ Name = "Tower", Size = Vector3.new(TOWER, height, TOWER), Position = position + Vector3.new(0, height / 2, 0),
				Color = if index % 2 == 0 then LIGHT else DARK }, geometry)
		end
	end
end

-- Invisible walls far outside the loop; NoWeb so they never become swing anchors.
for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
	local wall = part({ Name = "Boundary", Size = Vector3.new(if side.X ~= 0 then 4 else 600, 600, if side.Z ~= 0 then 4 else 600),
		Position = side * 290 + Vector3.new(0, 300, 0), Transparency = 1, CastShadow = false }, geometry)
	wall:SetAttribute("NoWeb", true)
end

-- Spawn and leaderboard on the roof of the central block.
local roof = BLOCK_HEIGHT
local spawn = Instance.new("SpawnLocation")
spawn.Name = "RoofSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(0, roof + 0.5, -55)
spawn.Color = ACCENT
spawn.Material = Enum.Material.SmoothPlastic
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = geometry

local board = part({ Name = "Leaderboard", Size = Vector3.new(22, 14, 1),
	CFrame = CFrame.lookAt(Vector3.new(0, roof + 8, -30), Vector3.new(0, roof + 8, -60)), Color = Color3.fromRGB(27, 42, 53) }, arena)
board:SetAttribute("NoWeb", true)

-- Race course: rings around the lane, each facing the next one (the server tests crossings in ring space).
local ROUTE = {
	Vector3.new(-40, 70, -95),
	Vector3.new(50, 60, -95),
	Vector3.new(95, 85, -40),
	Vector3.new(95, 60, 50),
	Vector3.new(40, 85, 95),
	Vector3.new(-50, 60, 95),
	Vector3.new(-95, 85, 40),
	Vector3.new(-95, 65, -50),
}
local RADIUS = 13
local SEGMENTS = 16
for ringIndex, point in ROUTE do
	local nextPoint = ROUTE[ringIndex + 1] or ROUTE[1]
	local frame = CFrame.lookAt(point, nextPoint)
	local ring = Instance.new("Model")
	ring.Name = string.format("Ring%02d", ringIndex)
	ring:SetAttribute("Index", ringIndex)
	ring:SetAttribute("Radius", RADIUS)
	local core = part({ Name = "Core", Size = Vector3.new(RADIUS * 2, RADIUS * 2, 1), CFrame = frame, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false }, ring)
	ring.PrimaryPart = core
	local length = 2 * RADIUS * math.sin(math.pi / SEGMENTS) * 1.12
	for k = 0, SEGMENTS - 1 do
		part({ Name = "Segment", Size = Vector3.new(1.2, length, 1.2),
			CFrame = frame * CFrame.Angles(0, 0, k / SEGMENTS * math.pi * 2) * CFrame.new(RADIUS, 0, 0),
			Color = Color3.fromRGB(90, 120, 200), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false,
			CanTouch = false, CastShadow = false }, ring)
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(50, 26)
	tag.StudsOffsetWorldSpace = Vector3.new(0, RADIUS + 4, 0)
	tag.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = tostring(ringIndex)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Parent = tag
	tag.Parent = core
	ring.Parent = ringsFolder
end

-- Neutral default-like lighting.
local grade = Lighting:FindFirstChild("CityGrade")
if grade then
	grade:Destroy()
end
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(70, 70, 70)
Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 199, 199)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
end
pcall(function()
	Workspace.StreamingEnabled = false
end)

local parts = 0
for _, d in arena:GetDescendants() do
	if d:IsA("BasePart") and d.Parent ~= nil and d.Name ~= "Segment" and d.Name ~= "Core" then
		parts += 1
	end
end
return string.format("WebSwingArena built: %d geometry parts (+%d race rings)", parts, #ROUTE)
