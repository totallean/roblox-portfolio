local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Horror")
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Net = require(script.Parent:WaitForChild("Net"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Perception = require(script.Parent:WaitForChild("Perception"))
local NpcAnimator = require(script.Parent:WaitForChild("NpcAnimator"))
local Hiding = require(script.Parent:WaitForChild("Hiding"))

local S = Config.Stalker
local rng = Random.new()

--[[
	State machine

	Patrol ──(awareness ≥ Suspicious / heard a noise)──► Investigate ──(look around)──► Search ──► Patrol
	   │                                                      │                            ▲
	   └────────────────(awareness reaches 1)─────────────────┴──────────► Chase ──(lost sight)┘
	                                                                         │  └─(saw you hide)─► Extract
	                                                                         └─(in reach)──► Attack ──► Patrol
]]
export type StateName = "Patrol" | "Investigate" | "Search" | "Chase" | "Extract" | "Attack"

type Memory = { position: Vector3, time: number }
type Noise = { player: Player, position: Vector3, distance: number }

local Stalker = {}
Stalker.__index = Stalker

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function livingRoot(player: Player?): (BasePart?, Humanoid?)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

function Stalker.new(model: Model, waypoints: { BasePart })
	local self = setmetatable({}, Stalker)
	self.model = model
	self.humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	self.root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	self.head = model:FindFirstChild("Head") :: BasePart
	self.waypoints = waypoints
	self.animator = NpcAnimator.new(model, self.humanoid, self.root)

	self.state = "Patrol" :: StateName
	self.stateAt = os.clock()
	self.target = nil :: Player?
	self.awareness = {} :: { [Player]: number }
	self.memory = {} :: { [Player]: Memory }
	self.extractLocker = nil :: Model?

	self.goal = nil :: Vector3?
	self.route = nil :: { PathWaypoint }?
	self.routeIndex = 1
	self.pathToken = 0
	self.lastPathAt = 0
	self.waitUntil = 0
	self.lookAt = 0
	self.searchUntil = 0
	self.searchOrigin = self.root.Position
	self.attackUntil = 0
	self.recent = {} :: { BasePart }
	self.lastMovePosition = self.root.Position
	self.lastMoveAt = os.clock()
	self.stuckCount = 0

	self.params = RaycastParams.new()
	self.params.FilterType = Enum.RaycastFilterType.Exclude
	self.params.IgnoreWater = true

	local footsteps = Instance.new("Sound")
	footsteps.Name = "Footsteps"
	footsteps.SoundId = Sounds.Footsteps
	footsteps.Looped = true
	footsteps.Volume = 1.4
	footsteps.RollOffMode = Enum.RollOffMode.InverseTapered
	footsteps.RollOffMinDistance = 8
	footsteps.RollOffMaxDistance = 70
	footsteps.Parent = self.root
	self.footsteps = footsteps

	self.humanoid.WalkSpeed = S.WalkSpeed
	model:SetAttribute("State", self.state)
	return self
end

-- Movement -----------------------------------------------------------------------------------

function Stalker:_computePath(goal: Vector3)
	self.lastPathAt = os.clock()
	self.pathToken += 1
	local token = self.pathToken
	local from = self.root.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 7,
			AgentCanJump = false,
			WaypointSpacing = 5,
		})
		local ok = pcall(path.ComputeAsync, path, from, goal)
		if token ~= self.pathToken then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			self.route = path:GetWaypoints()
			self.routeIndex = math.min(2, #self.route)
		else
			self.route = nil
			-- Unreachable goal: anything but a pursuit just drops it and lets the state pick another.
			if self.state ~= "Chase" and self.state ~= "Extract" then
				self.goal = nil
			end
		end
	end)
end

function Stalker:_moveTo(goal: Vector3, force: boolean?)
	local now = os.clock()
	local previous = self.goal
	self.goal = goal
	local moved = previous == nil or (previous - goal).Magnitude > 3
	local since = now - self.lastPathAt
	if force or (moved and since > S.PathRecompute) or (self.route == nil and since > 0.6) or since > 2 then
		self:_computePath(goal)
	end
end

function Stalker:_stop()
	self.goal = nil
	self.route = nil
	self.pathToken += 1
	self.humanoid:MoveTo(self.root.Position)
end

-- Advances along the current route; returns true once the goal is reached.
function Stalker:_follow(): boolean
	local goal = self.goal
	if not goal then
		return true
	end
	local position = self.root.Position
	if flatDistance(position, goal) < 3.5 and math.abs(position.Y - goal.Y) < 7 then
		self:_stop()
		return true
	end
	local route = self.route
	if route then
		local waypoint = route[self.routeIndex]
		while waypoint and flatDistance(position, waypoint.Position) < 2.5 do
			self.routeIndex += 1
			waypoint = route[self.routeIndex]
		end
		self.humanoid:MoveTo(if waypoint then waypoint.Position else goal)
	else
		self.humanoid:MoveTo(goal)
	end
	return false
end

function Stalker:_unstick(now: number)
	local position = self.root.Position
	if not self.goal or (position - self.lastMovePosition).Magnitude > 1 then
		self.lastMovePosition = position
		self.lastMoveAt = now
		if not self.goal then
			self.stuckCount = 0
		end
	elseif now - self.lastMoveAt > S.StuckTime then
		self.lastMoveAt = now
		self.stuckCount += 1
		if self.stuckCount >= 2 and self.state ~= "Chase" and self.state ~= "Extract" then
			self.stuckCount = 0
			self:_stop()
			return
		end
		if self.route and self.routeIndex < #self.route then
			self.routeIndex += 1
		end
		self:_computePath(self.goal)
	end
end

function Stalker:_lookAround(now: number)
	if now >= self.lookAt then
		self.lookAt = now + rng:NextNumber(0.7, 1.3)
		local angle = rng:NextNumber(0, math.pi * 2)
		self.humanoid:MoveTo(self.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.2)
	end
end

-- Perception ---------------------------------------------------------------------------------

function Stalker:_perceive(dt: number): (Player?, number, Noise?)
	local now = os.clock()
	local headPosition = self.head.Position
	local eye = CFrame.lookAt(headPosition, headPosition + self.root.CFrame.LookVector)

	local exclude: { Instance } = { self.model }
	for player in PlayerState.all() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	self.params.FilterDescendantsInstances = exclude

	local best: Player? = nil
	local bestValue = 0
	local heard: Noise? = nil

	for player, state in PlayerState.all() do
		local root = livingRoot(player)
		local head = root and (root.Parent :: Model):FindFirstChild("Head") :: BasePart?
		if not root or not head then
			self.awareness[player] = nil
			self.memory[player] = nil
			continue
		end

		local value = self.awareness[player] or 0
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local crouched = PlayerState.isEffectivelyCrouched(state, speed)
		local seen = false

		if not state.hiddenIn and not Perception.inSafeZone(root.Position) then
			local visibility = Perception.visibility(root.Position, state.flashlight, crouched)
			local sight = Perception.canSee(eye, head.Position, visibility, self.params)
			if not sight.visible then
				sight = Perception.canSee(eye, root.Position, visibility, self.params)
			end
			if sight.visible then
				seen = true
				local closeness = 1 - sight.distance / sight.maxDistance
				local gain = S.AwarenessGain * math.min(sight.visibility, 1.5) * (0.4 + closeness * 2.6)
				if self.state == "Chase" and self.target == player then
					gain = 10
				end
				value = math.min(1, value + gain * dt)
				self.memory[player] = { position = root.Position, time = now }
			end

			local radius = Perception.noiseRadius(speed, crouched)
			local distance = (root.Position - self.root.Position).Magnitude
			if radius > 0 and distance < radius and (not heard or distance < heard.distance) then
				heard = { player = player, position = root.Position, distance = distance }
			end
		end

		if not seen and not (self.state == "Chase" and self.target == player) then
			value = math.max(0, value - S.AwarenessDecay * dt)
		end
		self.awareness[player] = value
		if value > bestValue then
			best, bestValue = player, value
		end
	end
	return best, bestValue, heard
end

-- Transitions --------------------------------------------------------------------------------

function Stalker:_setState(name: StateName)
	if self.state == name then
		return
	end
	self.state = name
	self.stateAt = os.clock()
	self.waitUntil = 0
	self.humanoid.WalkSpeed = if name == "Chase" or name == "Extract" then S.ChaseSpeed
		elseif name == "Investigate" or name == "Search" then S.InvestigateSpeed
		else S.WalkSpeed
	self.model:SetAttribute("State", name)
end

function Stalker:_startChase(player: Player)
	self.target = player
	self:_setState("Chase")
	self.lastPathAt = 0
end

function Stalker:_investigate(position: Vector3)
	if self.state == "Investigate" and self.goal and (self.goal - position).Magnitude < 4 then
		return
	end
	self:_setState("Investigate")
	self:_moveTo(position)
end

function Stalker:_startSearch(origin: Vector3, duration: number)
	self.target = nil
	self:_setState("Search")
	self.searchOrigin = origin
	self.searchUntil = os.clock() + duration
	self:_moveTo(origin, true)
end

function Stalker:_attack(victim: Player)
	local victimRoot, victimHumanoid = livingRoot(victim)
	if not victimRoot or not victimHumanoid then
		return
	end
	self:_setState("Attack")
	self:_stop()
	self.target = nil
	self.awareness[victim] = 0
	self.memory[victim] = nil
	self.attackUntil = os.clock() + S.AttackCooldown

	local here = self.root.Position
	self.root.CFrame = CFrame.lookAt(here, Vector3.new(victimRoot.Position.X, here.Y, victimRoot.Position.Z))
	victimRoot.Anchored = true
	Net.Stalker:FireClient(victim, "Jumpscare", self.model)
	task.delay(1.15, function()
		if victimHumanoid.Parent then
			victimHumanoid.Health = 0
		end
	end)
end

-- States -------------------------------------------------------------------------------------

function Stalker:_pickPatrolPoint(): Vector3
	local candidates = {}
	for _, waypoint in self.waypoints do
		if not table.find(self.recent, waypoint) then
			table.insert(candidates, waypoint)
		end
	end

	-- A light "director": now and then the patrol drifts toward where players actually are,
	-- so a careful player still feels hunted instead of being left alone.
	local choice: BasePart? = nil
	if rng:NextNumber() < 0.35 then
		local roots = {}
		for player in PlayerState.all() do
			local root = livingRoot(player)
			if root then
				table.insert(roots, root.Position)
			end
		end
		if #roots > 0 then
			local focus = roots[rng:NextInteger(1, #roots)]
			table.sort(candidates, function(a, b)
				return (a.Position - focus).Magnitude < (b.Position - focus).Magnitude
			end)
			choice = candidates[rng:NextInteger(1, math.min(4, #candidates))]
		end
	end
	choice = choice or candidates[rng:NextInteger(1, #candidates)]

	table.insert(self.recent, 1, choice :: BasePart)
	if #self.recent > 5 then
		table.remove(self.recent)
	end
	return (choice :: BasePart).Position
end

function Stalker:_patrol(now: number)
	if self.goal then
		self:_follow()
		return
	end
	if self.waitUntil == 0 then
		self.waitUntil = now + rng:NextNumber(0.6, 1.8)
	elseif now >= self.waitUntil then
		self.waitUntil = 0
		self:_moveTo(self:_pickPatrolPoint(), true)
	end
end

function Stalker:_investigateStep(now: number)
	if self.goal then
		self:_follow()
		return
	end
	if self.waitUntil == 0 then
		self.waitUntil = now + S.InvestigateWait
	end
	self:_lookAround(now)
	if now >= self.waitUntil then
		self:_startSearch(self.root.Position, S.SearchDuration * 0.5)
	end
end

function Stalker:_search(now: number)
	if now > self.searchUntil then
		self:_setState("Patrol")
		self:_stop()
		return
	end
	if self.goal then
		if self:_follow() then
			self.waitUntil = now + rng:NextNumber(0.8, 1.6)
		end
		return
	end
	self:_lookAround(now)
	if now >= self.waitUntil then
		local near = {}
		for _, waypoint in self.waypoints do
			if (waypoint.Position - self.searchOrigin).Magnitude < 45 then
				table.insert(near, waypoint)
			end
		end
		local pick = near[rng:NextInteger(1, math.max(1, #near))] or self.waypoints[rng:NextInteger(1, #self.waypoints)]
		self:_moveTo(pick.Position, true)
	end
end

function Stalker:_chase(now: number)
	local player = self.target
	local state = player and PlayerState.get(player)
	local root = livingRoot(player)
	if not player or not state or not root then
		self.target = nil
		self:_setState("Patrol")
		self:_stop()
		return
	end

	local memory = self.memory[player]
	if Perception.inSafeZone(root.Position) then
		self.awareness[player] = 0
		self:_startSearch(if memory then memory.position else self.root.Position, S.SearchDuration * 0.5)
		return
	end
	if state.hiddenIn then
		if memory and memory.time >= state.hiddenAt - 1 then
			self.extractLocker = state.hiddenIn
			self:_setState("Extract")
		else
			self:_startSearch(if memory then memory.position else root.Position, S.SearchDuration)
		end
		return
	end

	-- Lost sight: the stalker keeps tracking the real position for a few seconds ("it can sense you"),
	-- then falls back to searching around the last place it actually saw you.
	if not memory or now - memory.time > S.LoseSightAfter then
		self:_startSearch(if memory then memory.position else root.Position, S.SearchDuration)
		return
	end

	local distance = (root.Position - self.root.Position).Magnitude
	local inSight = now - memory.time < 0.3
	if inSight and distance <= S.AttackRange then
		self:_attack(player)
		return
	end
	if inSight and distance < S.DirectChaseDistance then
		self.route = nil
		self.goal = root.Position
		self.lastPathAt = 0
		self.humanoid:MoveTo(root.Position)
	else
		self:_moveTo(root.Position)
		self:_follow()
	end
end

function Stalker:_extract(now: number)
	local locker = self.extractLocker
	local stand = locker and Hiding.standPoint(locker)
	if not locker or not stand then
		self:_setState("Patrol")
		return
	end
	if flatDistance(self.root.Position, stand) < 4.5 then
		local victim = Hiding.pullOut(locker)
		self.extractLocker = nil
		if victim then
			self:_attack(victim)
		else
			self:_startSearch(stand, S.SearchDuration * 0.5)
		end
		return
	end
	self:_moveTo(stand)
	self:_follow()
end

function Stalker:_attackStep(now: number)
	if now >= self.attackUntil then
		self:_setState("Patrol")
		self:_stop()
	end
end

local HANDLERS = {
	Patrol = Stalker._patrol,
	Investigate = Stalker._investigateStep,
	Search = Stalker._search,
	Chase = Stalker._chase,
	Extract = Stalker._extract,
	Attack = Stalker._attackStep,
}

-- Tick ---------------------------------------------------------------------------------------

function Stalker:tick(dt: number)
	local now = os.clock()
	local best, bestValue, heard = self:_perceive(dt)

	if self.state ~= "Attack" and self.state ~= "Extract" then
		local chasing = self.state == "Chase" and livingRoot(self.target) ~= nil
		if best and bestValue >= S.ChaseAt and not chasing then
			self:_startChase(best)
		elseif not chasing then
			local memory = best and self.memory[best]
			if best and memory and bestValue >= S.SuspiciousAt and now - memory.time < 0.5 then
				self:_investigate(memory.position)
			elseif heard then
				self.awareness[heard.player] = math.max(self.awareness[heard.player] or 0, S.SuspiciousAt * 0.8)
				self:_investigate(heard.position)
			end
		end
	end

	HANDLERS[self.state](self, now)
	self:_unstick(now)
	self.animator:update()

	local velocity = self.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	self.footsteps.Playing = speed > 1
	self.footsteps.PlaybackSpeed = 0.55 + speed / 40

	for player in PlayerState.all() do
		Net.Stalker:FireClient(player, "Awareness", self.awareness[player] or 0, self.state, self.target == player)
	end
end

function Stalker:reset(spawn: CFrame)
	self:_stop()
	self.target = nil
	self.extractLocker = nil
	table.clear(self.awareness)
	table.clear(self.memory)
	table.clear(self.recent)
	self:_setState("Patrol")
	self.model:PivotTo(spawn)
end

return Stalker
