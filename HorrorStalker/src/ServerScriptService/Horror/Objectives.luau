local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Horror"):WaitForChild("Config"))
local Net = require(script.Parent:WaitForChild("Net"))
local Hiding = require(script.Parent:WaitForChild("Hiding"))

local Objectives = {}

local rng = Random.new()
local mansion: Model
local keysFolder: Folder
local door: BasePart
local doorClosed: CFrame
local exitZone: BasePart
local exitOpen = false
local roundStartedAt = 0
local roundEnding = false
local escaped: { [Player]: boolean } = {}
local onReset: () -> () = function() end

local function makeKey(spawn: BasePart)
	local key = Instance.new("Part")
	key.Name = "Key"
	key.Size = Vector3.new(0.5, 0.25, 1.6)
	key.Material = Enum.Material.Neon
	key.Color = Color3.fromRGB(255, 196, 64)
	key.Anchored = true
	key.CanCollide = false
	key.CFrame = spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + 0.3, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local light = Instance.new("PointLight")
	light.Color = key.Color
	light.Range = 7
	light.Brightness = 0.8
	light.Parent = key

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take key"
	prompt.ObjectText = "Key"
	prompt:SetAttribute("TextKey", "takeKey")
	prompt:SetAttribute("ObjectKey", "object_key")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 7
	prompt.Parent = key
	prompt.Triggered:Connect(function(player: Player)
		if key.Parent ~= keysFolder then
			return
		end
		key:Destroy()
		local found = (Workspace:GetAttribute("KeysFound") :: number) + 1
		Workspace:SetAttribute("KeysFound", found)
		Net.Game:FireAllClients("KeyFound", player.DisplayName)
		if found >= Config.Keys.Required then
			Objectives.openExit()
		end
	end)
	key.Parent = keysFolder
end

local function spawnKeys()
	keysFolder:ClearAllChildren()
	local spawns = mansion:WaitForChild("KeySpawns"):GetChildren()
	for i = #spawns, 2, -1 do
		local j = rng:NextInteger(1, i)
		spawns[i], spawns[j] = spawns[j], spawns[i]
	end
	for i = 1, math.min(Config.Keys.Required, #spawns) do
		makeKey(spawns[i] :: BasePart)
	end
	Workspace:SetAttribute("KeysFound", 0)
	Workspace:SetAttribute("KeysRequired", Config.Keys.Required)
end

function Objectives.openExit()
	if exitOpen then
		return
	end
	exitOpen = true
	TweenService:Create(door, TweenInfo.new(3, Enum.EasingStyle.Quad), { CFrame = doorClosed + Vector3.new(0, door.Size.Y - 1, 0) }):Play()
	Net.Game:FireAllClients("ExitOpen")
end

local function resetRound()
	exitOpen = false
	roundEnding = false
	table.clear(escaped)
	door.CFrame = doorClosed
	Hiding.releaseAll()
	spawnKeys()
	onReset()
	roundStartedAt = os.clock()
	Net.Game:FireAllClients("NewRound")
	for _, player in Players:GetPlayers() do
		task.spawn(player.LoadCharacter, player)
	end
end

function Objectives.restartRound()
	resetRound()
end

local function inside(zone: BasePart, position: Vector3): boolean
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y + 3 and math.abs(localPoint.Z) <= half.Z
end

local function onEscaped(player: Player)
	escaped[player] = true
	Net.Game:FireAllClients("Escaped", player.DisplayName, os.clock() - roundStartedAt)
	if not roundEnding then
		roundEnding = true
		task.delay(8, resetRound)
	end
end

function Objectives.init(map: Model, resetCallback: () -> ())
	mansion = map
	onReset = resetCallback
	local exit = map:WaitForChild("Exit")
	door = exit:WaitForChild("Door") :: BasePart
	doorClosed = door.CFrame
	exitZone = exit:WaitForChild("ExitZone") :: BasePart

	keysFolder = Instance.new("Folder")
	keysFolder.Name = "Keys"
	keysFolder.Parent = map
	spawnKeys()
	roundStartedAt = os.clock()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 or not exitOpen then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and not escaped[player] and inside(exitZone, (root :: BasePart).Position) then
				onEscaped(player)
			end
		end
	end)
end

return Objectives
