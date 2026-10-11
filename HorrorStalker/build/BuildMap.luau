-- Edit-mode generator for the Horror Stalker demo: a small greybox maze, so the focus stays on the AI.
-- Grid maze (recursive backtracker) + extra loops for escape routes, one open hall (stalker spawn),
-- lockers in dead ends, key tables, a lit start cell and an exit door.

local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local rng = Random.new(666)

local W, H = 6, 5
local CELL = 22
local WALL_H = 13
local THICK = 1.2
local DOOR_W = 8
local DOOR_H = 9.5
local LOOP_CHANCE = 0.25
local HALL = { 2, 1 }
local START_CELL = { 0, 0 }
local EXIT_CELL = { W - 1, H - 1 }

local WALL = Color3.fromRGB(120, 116, 112)
local FLOOR = Color3.fromRGB(70, 66, 62)

for _, name in { "Mansion", "Baseplate", "SpawnLocation" } do
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local mansion = Instance.new("Model")
mansion.Name = "Mansion"
mansion.Parent = Workspace

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = mansion
	return f
end
local structure = folder("Structure")
local lampsFolder = folder("Lamps")
local lockersFolder = folder("Lockers")
local keySpawns = folder("KeySpawns")
local waypoints = folder("Waypoints")
local exitFolder = folder("Exit")

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function cellCenter(x: number, y: number): Vector3
	return Vector3.new((x - (W - 1) / 2) * CELL, 0, (y - (H - 1) / 2) * CELL)
end

local function key(x: number, y: number): number
	return y * W + x
end

-- Maze: east[x][y] is the edge to (x+1, y), south[x][y] the edge to (x, y+1). Kinds: wall / door / open.
local east, south = {}, {}
for x = 0, W - 1 do
	east[x], south[x] = {}, {}
	for y = 0, H - 1 do
		east[x][y] = "wall"
		south[x][y] = "wall"
	end
end

local function setEdge(x1: number, y1: number, x2: number, y2: number, kind: string)
	if x1 == x2 then
		south[x1][math.min(y1, y2)] = kind
	else
		east[math.min(x1, x2)][y1] = kind
	end
end

local visited = { [key(0, 0)] = true }
local stack = { { 0, 0 } }
while #stack > 0 do
	local x, y = stack[#stack][1], stack[#stack][2]
	local options = {}
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local nx, ny = x + d[1], y + d[2]
		if nx >= 0 and nx < W and ny >= 0 and ny < H and not visited[key(nx, ny)] then
			table.insert(options, { nx, ny })
		end
	end
	if #options == 0 then
		table.remove(stack)
	else
		local pick = options[rng:NextInteger(1, #options)]
		setEdge(x, y, pick[1], pick[2], "door")
		visited[key(pick[1], pick[2])] = true
		table.insert(stack, pick)
	end
end

for x = 0, W - 1 do
	for y = 0, H - 1 do
		if x < W - 1 and east[x][y] == "wall" and rng:NextNumber() < LOOP_CHANCE then
			east[x][y] = "door"
		end
		if y < H - 1 and south[x][y] == "wall" and rng:NextNumber() < LOOP_CHANCE then
			south[x][y] = "door"
		end
	end
end

local hx, hy = HALL[1], HALL[2]
setEdge(hx, hy, hx + 1, hy, "open")
setEdge(hx, hy + 1, hx + 1, hy + 1, "open")
setEdge(hx, hy, hx, hy + 1, "open")
setEdge(hx + 1, hy, hx + 1, hy + 1, "open")
local inHall = { [key(hx, hy)] = true, [key(hx + 1, hy)] = true, [key(hx, hy + 1)] = true, [key(hx + 1, hy + 1)] = true }

-- Geometry ---------------------------------------------------------------------------------------
part({ Name = "Floor", Size = Vector3.new(W * CELL, 1, H * CELL), Position = Vector3.new(0, -0.5, 0), Color = FLOOR }, structure)
part({ Name = "Ceiling", Size = Vector3.new(W * CELL + 2, 1, H * CELL + 2), Position = Vector3.new(0, WALL_H + 0.5, 0),
	Color = Color3.fromRGB(50, 48, 46) }, structure)

local function wall(center: Vector3, along: Vector3, length: number, height: number, baseY: number)
	local size = if math.abs(along.X) > 0.5 then Vector3.new(length, height, THICK) else Vector3.new(THICK, height, length)
	part({ Name = "Wall", Size = size, Position = Vector3.new(center.X, baseY + height / 2, center.Z), Color = WALL }, structure)
end

local function edge(center: Vector3, along: Vector3, kind: string)
	local length = CELL + THICK
	if kind == "wall" then
		wall(center, along, length, WALL_H, 0)
	elseif kind == "door" then
		local side = (length - DOOR_W) / 2
		local offset = DOOR_W / 2 + side / 2
		wall(center + along * offset, along, side, WALL_H, 0)
		wall(center - along * offset, along, side, WALL_H, 0)
		wall(center, along, DOOR_W, WALL_H - DOOR_H, DOOR_H)
	end
end

for x = 0, W - 1 do
	for y = 0, H - 1 do
		local c = cellCenter(x, y)
		if x < W - 1 then
			edge(c + Vector3.new(CELL / 2, 0, 0), Vector3.zAxis, east[x][y])
		end
		if y < H - 1 then
			edge(c + Vector3.new(0, 0, CELL / 2), Vector3.xAxis, south[x][y])
		end
	end
end
for x = 0, W - 1 do
	edge(cellCenter(x, 0) - Vector3.new(0, 0, CELL / 2), Vector3.xAxis, "wall")
	edge(cellCenter(x, H - 1) + Vector3.new(0, 0, CELL / 2), Vector3.xAxis, "wall")
end
for y = 0, H - 1 do
	edge(cellCenter(0, y) - Vector3.new(CELL / 2, 0, 0), Vector3.zAxis, "wall")
	if y ~= EXIT_CELL[2] then
		edge(cellCenter(W - 1, y) + Vector3.new(CELL / 2, 0, 0), Vector3.zAxis, "wall")
	end
end
local exitEdge = cellCenter(EXIT_CELL[1], EXIT_CELL[2]) + Vector3.new(CELL / 2, 0, 0)
edge(exitEdge, Vector3.zAxis, "door")

local function openings(x: number, y: number): { Vector3 }
	local list = {}
	if x < W - 1 and east[x][y] ~= "wall" then table.insert(list, Vector3.xAxis) end
	if x > 0 and east[x - 1][y] ~= "wall" then table.insert(list, -Vector3.xAxis) end
	if y < H - 1 and south[x][y] ~= "wall" then table.insert(list, Vector3.zAxis) end
	if y > 0 and south[x][y - 1] ~= "wall" then table.insert(list, -Vector3.zAxis) end
	return list
end

local function isWall(x: number, y: number, normal: Vector3): boolean
	if x == EXIT_CELL[1] and y == EXIT_CELL[2] and normal.X > 0.9 then
		return false
	end
	for _, open in openings(x, y) do
		if open:Dot(normal) > 0.9 then
			return false
		end
	end
	return true
end

-- Lockers: a hollow box with slats in front, so the player can peek out.
local function locker(position: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Locker"
	local frame = CFrame.lookAt(position, position + facing)
	local color = Color3.fromRGB(70, 90, 80)
	local function piece(name: string, size: Vector3, offset: Vector3)
		part({ Name = name, Size = size, CFrame = frame * CFrame.new(offset), Color = color }, model)
	end
	piece("Back", Vector3.new(4, 8, 0.3), Vector3.new(0, 0, 1.35))
	piece("Left", Vector3.new(0.3, 8, 3), Vector3.new(-1.85, 0, 0))
	piece("Right", Vector3.new(0.3, 8, 3), Vector3.new(1.85, 0, 0))
	piece("Top", Vector3.new(4, 0.3, 3), Vector3.new(0, 3.85, 0))
	for i = 0, 5 do
		piece("Slat", Vector3.new(3.4, 0.6, 0.15), Vector3.new(0, -3.3 + i * 1.3, -1.4))
	end
	part({ Name = "Front", Size = Vector3.new(3.6, 7.6, 0.2), CFrame = frame * CFrame.new(0, 0, -1.6), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false }, model)
	part({ Name = "HidePoint", Size = Vector3.new(1, 1, 1), CFrame = frame * CFrame.new(0, -1, 0.2), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false }, model)
	model.Parent = lockersFolder
end

local candidates = {}
local lockerCount = 0
for x = 0, W - 1 do
	for y = 0, H - 1 do
		local c = cellCenter(x, y)
		part({ Name = string.format("Cell_%d_%d", x, y), Size = Vector3.one, Position = c + Vector3.new(0, 3, 0), Transparency = 1,
			CanCollide = false, CanQuery = false, CanTouch = false }, waypoints)

		local isStart = x == START_CELL[1] and y == START_CELL[2]
		local isExit = x == EXIT_CELL[1] and y == EXIT_CELL[2]
		if isStart or rng:NextNumber() < 0.35 then
			local lamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2),
				Position = c + Vector3.new(0, WALL_H - 1, 0), Color = Color3.fromRGB(255, 196, 130), Material = Enum.Material.Neon,
				CanCollide = false, CanQuery = false }, lampsFolder)
			local light = Instance.new("PointLight")
			light.Range = 17
			light.Brightness = 0.9
			light.Color = Color3.fromRGB(255, 190, 120)
			light.Shadows = true
			light.Parent = lamp
			lamp:SetAttribute("LampRadius", 14)
			lamp:SetAttribute("Flicker", not isStart and rng:NextNumber() < 0.35)
		end

		if not isStart and not isExit and not inHall[key(x, y)] then
			local open = openings(x, y)
			if #open == 1 and lockerCount < 5 and isWall(x, y, -open[1]) then
				lockerCount += 1
				locker(c - open[1] * (CELL / 2 - THICK / 2 - 1.6) + Vector3.new(0, 4, 0), open[1])
			else
				table.insert(candidates, { x = x, y = y, center = c })
			end
		end
	end
end

-- Small mazes have few dead ends: top up with lockers against solid walls of ordinary rooms.
local NORMALS = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
while lockerCount < 4 and #candidates > 0 do
	local cell = table.remove(candidates, rng:NextInteger(1, #candidates))
	for _, normal in NORMALS do
		if isWall(cell.x, cell.y, normal) then
			lockerCount += 1
			locker(cell.center + normal * (CELL / 2 - THICK / 2 - 1.6) + Vector3.new(0, 4, 0), -normal)
			break
		end
	end
end

for i = 1, math.min(6, #candidates) do
	local c = table.remove(candidates, rng:NextInteger(1, #candidates)).center
	-- Corners only: cell centres are patrol waypoints and must stay walkable.
	local corner = Vector3.new(if rng:NextNumber() < 0.5 then -6.5 else 6.5, 1.4, if rng:NextNumber() < 0.5 then -6.5 else 6.5)
	part({ Name = "KeyTable" .. i, Size = Vector3.new(3, 2.8, 3), Position = c + corner, Color = Color3.fromRGB(96, 72, 52) }, keySpawns)
end

-- Spawn, stalker spawn, exit -----------------------------------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "StartSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 0.2, 8)
spawn.Position = cellCenter(START_CELL[1], START_CELL[2]) + Vector3.new(0, 0.1, 0)
spawn.Color = Color3.fromRGB(90, 30, 30)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = mansion

-- The start cell is a safe room: the stalker never sees, hears or enters it.
part({ Name = "SafeZone", Size = Vector3.new(CELL - THICK, WALL_H, CELL - THICK), Position = cellCenter(START_CELL[1], START_CELL[2])
	+ Vector3.new(0, WALL_H / 2, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, mansion)

local stalkerSpawn = (cellCenter(hx, hy) + cellCenter(hx + 1, hy + 1)) / 2
part({ Name = "StalkerSpawn", Size = Vector3.new(2, 0.2, 2), Position = stalkerSpawn + Vector3.new(0, 0.1, 0), Transparency = 1,
	CanCollide = false, CanQuery = false, CanTouch = false }, mansion)

part({ Name = "Door", Size = Vector3.new(THICK + 0.4, DOOR_H, DOOR_W), Position = exitEdge + Vector3.new(0, DOOR_H / 2, 0),
	Color = Color3.fromRGB(120, 30, 26) }, exitFolder)
part({ Name = "ExitPad", Size = Vector3.new(16, 1, 16), Position = exitEdge + Vector3.new(9, -0.5, 0),
	Color = Color3.fromRGB(60, 160, 80), Material = Enum.Material.Neon }, exitFolder)
part({ Name = "ExitZone", Size = Vector3.new(12, 8, 12), Position = exitEdge + Vector3.new(10, 4, 0), Transparency = 1,
	CanCollide = false, CanQuery = false, CanTouch = false }, exitFolder)

-- Main menu "cover": a short dark corridor away from the maze. The server places a posed stalker on
-- StalkerMark; the menu camera dollies from CameraStart to CameraEnd.
local oldStage = Workspace:FindFirstChild("MenuStage")
if oldStage then
	oldStage:Destroy()
end
local stage = Instance.new("Model")
stage.Name = "MenuStage"
local o = Vector3.new(0, 0, 200)
local function marker(name: string, cframe: CFrame)
	part({ Name = name, Size = Vector3.one, CFrame = cframe, Transparency = 1, CanCollide = false, CanQuery = false,
		CanTouch = false }, stage)
end
part({ Name = "Floor", Size = Vector3.new(12, 1, 46), Position = o + Vector3.new(0, -0.5, 0), Color = FLOOR }, stage)
part({ Name = "Ceiling", Size = Vector3.new(14, 1, 46), Position = o + Vector3.new(0, WALL_H + 0.5, 0), Color = Color3.fromRGB(50, 48, 46) }, stage)
for _, x in { -6.5, 6.5 } do
	part({ Name = "Wall", Size = Vector3.new(1, WALL_H, 46), Position = o + Vector3.new(x, WALL_H / 2, 0), Color = WALL }, stage)
end
for _, z in { -23, 23 } do
	part({ Name = "Wall", Size = Vector3.new(12, WALL_H, 1), Position = o + Vector3.new(0, WALL_H / 2, z), Color = WALL }, stage)
end
-- Poster lighting: a bare bulb right above the figure throws a cone of light down on it, and a red rim
-- light behind separates the black silhouette from the back wall.
local menuLamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Position = o + Vector3.new(0, 11.8, 12.5),
	Color = Color3.fromRGB(255, 205, 150), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, stage)
local cone = Instance.new("SpotLight")
cone.Name = "Cone"
cone.Face = Enum.NormalId.Bottom
cone.Angle = 75
cone.Range = 18
cone.Brightness = 3.2
cone.Color = Color3.fromRGB(255, 196, 140)
cone.Shadows = true
cone.Parent = menuLamp
local fill = Instance.new("PointLight")
fill.Range = 12
fill.Brightness = 0.5
fill.Color = Color3.fromRGB(255, 190, 120)
fill.Parent = menuLamp
local rim = part({ Name = "RimLight", Size = Vector3.one, Position = o + Vector3.new(0, 4.5, 19.5), Transparency = 1, CanCollide = false,
	CanQuery = false, CanTouch = false }, stage)
local rimLight = Instance.new("PointLight")
rimLight.Range = 10
rimLight.Brightness = 2.2
rimLight.Color = Color3.fromRGB(200, 20, 20)
rimLight.Parent = rim
marker("StalkerMark", CFrame.lookAt(o + Vector3.new(0, 0, 14), o))
marker("CameraStart", CFrame.lookAt(o + Vector3.new(1.2, 5.2, -5), o + Vector3.new(0, 5.4, 14)))
marker("CameraEnd", CFrame.lookAt(o + Vector3.new(0.3, 5.8, 5), o + Vector3.new(0, 6.2, 14)))
stage.Parent = Workspace

-- Dark lighting is part of the mechanic: visibility depends on lamps and the flashlight.
Lighting.ClockTime = 0
Lighting.Brightness = 0.3
Lighting.Ambient = Color3.fromRGB(6, 6, 9)
Lighting.OutdoorAmbient = Color3.fromRGB(16, 18, 28)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0.15
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
atmosphere.Density = 0.4
atmosphere.Offset = 0
atmosphere.Color = Color3.fromRGB(20, 22, 30)
atmosphere.Decay = Color3.fromRGB(10, 10, 14)
atmosphere.Glare = 0
atmosphere.Haze = 0.5
for _, effect in Lighting:GetChildren() do
	if effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") then
		effect.Enabled = false
	end
end

StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.CharacterWalkSpeed = 12
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = 0
pcall(function()
	Workspace.StreamingEnabled = false
end)

local parts = 0
for _, d in mansion:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return string.format("Mansion built: %d parts, %d lockers, %d key tables, %d lamps",
	parts, #lockersFolder:GetChildren(), #keySpawns:GetChildren(), #lampsFolder:GetChildren())
