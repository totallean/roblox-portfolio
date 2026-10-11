local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Perception = require(script.Parent:WaitForChild("Perception"))
local Hiding = require(script.Parent:WaitForChild("Hiding"))
local Objectives = require(script.Parent:WaitForChild("Objectives"))
local StalkerRig = require(script.Parent:WaitForChild("StalkerRig"))
local StalkerAI = require(script.Parent:WaitForChild("StalkerAI"))

-- Respawns are server-driven: after a death the client shows the game-over screen and asks for a
-- respawn (Restart / Main menu). A fallback respawns anyone left dead for a minute.
Players.CharacterAutoLoads = false
local RESPAWN_FALLBACK = 60

local mansion = Workspace:WaitForChild("Mansion") :: Model
PlayerState.init()
Perception.registerLamps(mansion:WaitForChild("Lamps"))
local safeZone = mansion:FindFirstChild("SafeZone")
if safeZone and safeZone:IsA("BasePart") then
	Perception.registerSafeZone(safeZone)
end
Hiding.init(mansion:WaitForChild("Lockers"))

local waypoints: { BasePart } = {}
for _, waypoint in mansion:WaitForChild("Waypoints"):GetChildren() do
	if waypoint:IsA("BasePart") and not Perception.inSafeZone(waypoint.Position) then
		table.insert(waypoints, waypoint)
	end
end

local spawnPart = mansion:WaitForChild("StalkerSpawn") :: BasePart
local spawnCFrame = spawnPart.CFrame + Vector3.new(0, 5, 0)

local model = StalkerRig.build()
model:PivotTo(spawnCFrame)
model.Parent = Workspace
local root = model:WaitForChild("HumanoidRootPart") :: BasePart
root:SetNetworkOwner(nil)

local stalker = StalkerAI.new(model, waypoints)
Objectives.init(mansion, function()
	stalker:reset(spawnCFrame)
end)

local function isAlive(player: Player): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

PlayerState.onRespawn = function(player: Player)
	if isAlive(player) then
		return
	end
	-- Nobody else is still playing: a restart means a fresh round (new keys, closed exit).
	for _, other in Players:GetPlayers() do
		if other ~= player and isAlive(other) then
			player:LoadCharacter()
			return
		end
	end
	Objectives.restartRound()
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.delay(RESPAWN_FALLBACK, function()
				if player.Parent and player.Character == character then
					player:LoadCharacter()
				end
			end)
		end)
	end)
	player:LoadCharacter()
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

-- Main menu cover: a second, frozen stalker posed under the lamp of the menu corridor.
local stage = Workspace:FindFirstChild("MenuStage")
local mark = stage and stage:FindFirstChild("StalkerMark")
if stage and mark and mark:IsA("BasePart") then
	local statue = StalkerRig.build()
	statue.Name = "MenuStalker"
	local humanoid = statue:FindFirstChildOfClass("Humanoid") :: Humanoid
	local statueRoot = statue:FindFirstChild("HumanoidRootPart") :: BasePart
	statueRoot.Anchored = true
	statue:PivotTo(mark.CFrame + Vector3.new(0, humanoid.HipHeight + statueRoot.Size.Y / 2, 0))
	statue.Parent = stage
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local idle = Instance.new("Animation")
		idle.AnimationId = "rbxassetid://507766666"
		local track = animator:LoadAnimation(idle)
		track.Looped = true
		track:Play()
	end
end

task.spawn(function()
	local last = os.clock()
	while model.Parent do
		task.wait(0.1)
		local now = os.clock()
		local ok, err = pcall(stalker.tick, stalker, now - last)
		if not ok then
			warn("[Stalker] tick failed: " .. tostring(err))
		end
		last = now
	end
end)

-- Studio-only QA / filming hooks: ServerStorage.HorrorDevTools:Invoke("Freeze", true) etc.
-- Never created in live servers, so nothing here is reachable by players.
if RunService:IsStudio() then
	local devTools = Instance.new("BindableFunction")
	devTools.Name = "HorrorDevTools"
	devTools.OnInvoke = function(action: string, ...: any): any
		local args = { ... }
		if action == "Freeze" then
			root.Anchored = args[1] == true
		elseif action == "Hide" then
			Hiding.hide(args[1], args[2])
		elseif action == "State" then
			return stalker.state, stalker.target and stalker.target.Name
		end
		return true
	end
	devTools.Parent = ServerStorage
end
