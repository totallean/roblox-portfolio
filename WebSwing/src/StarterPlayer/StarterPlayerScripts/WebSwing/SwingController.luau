local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("WebSwing")
local Config = require(Shared:WaitForChild("Config"))
local WebRope = require(Shared:WaitForChild("WebRope"))
local Targeting = require(script.Parent:WaitForChild("Targeting"))

export type Mode = "Ground" | "Swing" | "Zip" | "Air"
type RopeKind = "Swing" | "Zip"

local player = Players.LocalPlayer
local webRemote = Shared:WaitForChild("Remotes"):WaitForChild("Web") :: RemoteEvent

local SwingController = {}

local modeChanged = Instance.new("BindableEvent")
local webAttached = Instance.new("BindableEvent")
SwingController.ModeChanged = modeChanged.Event
SwingController.WebAttached = webAttached.Event

local webFolder = Instance.new("Folder")
webFolder.Name = "LocalWebs"
webFolder.Parent = Workspace

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.IgnoreWater = true

local mode: Mode = "Ground"
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local hand: Attachment? = nil
local align: AlignOrientation? = nil
local shoulder: Motor6D? = nil
local shoulderC0 = CFrame.identity
local armAimed = false
local fallTrack: AnimationTrack? = nil
local connections: { RBXScriptConnection } = {}
local bodyParts: { [BasePart]: PhysicalProperties? } = {}
local SLIPPERY = PhysicalProperties.new(0.7, 0, 0, 100, 1)

local rope: WebRope.WebRope? = nil
local ropeKind: RopeKind? = nil
local announced = false
local anchor: Vector3? = nil
local ropeLength = 0
local zipStarted = 0
local stillSince = 0

local swingHeld = false
local reelHeld = false

local function horizontal(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	if v.Magnitude > 1e-3 then
		return v.Unit
	end
	return fallback
end

local function clampSpeed(v: Vector3): Vector3
	local speed = v.Magnitude
	if speed > Config.MaxSpeed then
		return v * (Config.MaxSpeed / speed)
	end
	return v
end

-- Rotation-only CFrame whose LookVector follows `forward` and whose UpVector leans toward `up`.
local function basis(forward: Vector3, up: Vector3, fallbackForward: Vector3): CFrame
	local f = unitOr(forward, fallbackForward)
	local right = f:Cross(up)
	if right.Magnitude < 1e-3 then
		right = f:Cross(Vector3.zAxis)
	end
	right = right.Unit
	return CFrame.fromMatrix(Vector3.zero, right, right:Cross(f))
end

-- Zero friction while airborne: brushing a facade should deflect the swing, not stop it dead.
local function setSlippery(enabled: boolean)
	for part, original in bodyParts do
		part.CustomPhysicalProperties = if enabled then SLIPPERY else original
	end
end

local function setMode(newMode: Mode)
	if mode == newMode then
		return
	end
	local wasPhysics = mode ~= "Ground"
	local isPhysics = newMode ~= "Ground"
	mode = newMode
	stillSince = os.clock()
	if humanoid and align and wasPhysics ~= isPhysics then
		humanoid.PlatformStand = isPhysics
		align.Enabled = isPhysics
		setSlippery(isPhysics)
		if isPhysics then
			if fallTrack then
				fallTrack:Play(0.15)
			end
		else
			if fallTrack then
				fallTrack:Stop(0.25)
			end
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
	modeChanged:Fire(newMode)
end

local function restoreArm()
	if shoulder and armAimed then
		shoulder.C0 = shoulderC0
		armAimed = false
	end
end

-- Points the right arm at the end of the web by rotating the shoulder joint around its pivot.
local function aimArm()
	if not shoulder or not rope then
		restoreArm()
		return
	end
	local torso = shoulder.Part0
	if not torso then
		return
	end
	local pivot = torso.CFrame * shoulderC0
	local direction = torso.CFrame:VectorToObjectSpace(rope:GetEndPosition() - pivot.Position)
	if direction.Magnitude < 1e-3 then
		return
	end
	direction = direction.Unit
	local down = -Vector3.yAxis
	local axis = down:Cross(direction)
	local angle = math.acos(math.clamp(down:Dot(direction), -1, 1))
	local rotation = if axis.Magnitude > 1e-4 then CFrame.fromAxisAngle(axis.Unit, angle) else CFrame.identity
	shoulder.C0 = CFrame.new(shoulderC0.Position) * rotation * shoulderC0.Rotation
	shoulder.Transform = CFrame.identity
	armAimed = true
end

local function dropRope(animated: boolean)
	local current = rope
	if current then
		rope = nil
		ropeKind = nil
		anchor = nil
		if animated then
			current:Release()
		else
			current:Destroy()
		end
		if announced then
			announced = false
			webRemote:FireServer("Release")
		end
	end
	if mode == "Swing" or mode == "Zip" then
		setMode("Air")
	end
	restoreArm()
end

local function whiff()
	if not hand then
		return
	end
	local miss = WebRope.new(hand, webFolder)
	local target = hand.WorldPosition + Targeting.aimDirection() * (Config.MaxWebDistance * 0.3)
	miss:ShootTo(target, Config.WebTravelSpeed, function()
		miss:Release()
	end, false)
end

local function beginSwing(target: Vector3)
	local body = root :: BasePart
	local position = body.Position
	local n = (target - position).Unit
	ropeLength = math.max(Config.MinRopeLength, (target - position).Magnitude * Config.InitialRopeFactor)

	-- Attach assist: a slow player gets an initial push along the swing arc, so a web shot
	-- from a standstill still turns into a proper swing instead of a dangle.
	local velocity = body.AssemblyLinearVelocity
	local tangentVelocity = velocity - n * velocity:Dot(n)
	local tangentSpeed = tangentVelocity.Magnitude
	if tangentSpeed < Config.AttachAssistSpeed then
		local camera = Workspace.CurrentCamera
		local flat = unitOr(horizontal(camera.CFrame.LookVector), body.CFrame.LookVector)
		local tangent = flat - n * flat:Dot(n)
		if tangent.Magnitude > 1e-3 then
			velocity += tangent.Unit * (Config.AttachAssistSpeed - tangentSpeed)
		end
	end
	if mode == "Ground" then
		velocity += Vector3.yAxis * 18
	end
	setMode("Swing")
	body.AssemblyLinearVelocity = clampSpeed(velocity)
	webAttached:Fire("Swing")
end

local function beginZip()
	zipStarted = os.clock()
	setMode("Zip")
	webAttached:Fire("Zip")
end

local function shoot(kind: RopeKind)
	if not root or not hand or not humanoid or humanoid.Health <= 0 then
		return
	end
	local target = Targeting.get(kind)
	if rope then
		dropRope(true)
	end
	if not target then
		whiff()
		return
	end
	local newRope = WebRope.new(hand, webFolder)
	rope = newRope
	ropeKind = kind
	newRope:ShootTo(target.point, Config.WebTravelSpeed, function()
		if rope ~= newRope then
			return
		end
		if kind == "Swing" and not swingHeld then
			dropRope(true)
			return
		end
		anchor = target.pivot
		announced = true
		webRemote:FireServer("Attach", target.point)
		if kind == "Swing" then
			beginSwing(target.pivot)
		else
			beginZip()
		end
	end)
end

local function release(jumpOff: boolean)
	if mode == "Swing" and root then
		local velocity = root.AssemblyLinearVelocity
		local forward = unitOr(horizontal(velocity), root.CFrame.LookVector)
		local boostForward = if jumpOff then Config.JumpOffBoostForward else Config.ReleaseBoostForward
		local boostUp = if jumpOff then Config.JumpOffBoostUp else Config.ReleaseBoostUp
		velocity += forward * boostForward + Vector3.yAxis * boostUp
		root.AssemblyLinearVelocity = clampSpeed(velocity)
		dropRope(true)
	elseif ropeKind == "Swing" then
		dropRope(true)
	end
end

local function stepSwing(body: BasePart, target: Vector3, velocity: Vector3, dt: number): Vector3
	local toAnchor = target - body.Position
	local distance = toAnchor.Magnitude
	local n = toAnchor / distance

	if reelHeld then
		ropeLength = math.max(Config.MinRopeLength, ropeLength - Config.ReelSpeed * dt)
	end

	-- Ground clearance: the lowest point of the arc (anchor.Y - ropeLength) is kept above the street,
	-- so a low web lifts the player instead of dragging them along the asphalt.
	local floor = Workspace:Raycast(body.Position, Vector3.new(0, -400, 0), probeParams)
	local groundY = if floor then floor.Position.Y else body.Position.Y - 400
	local maxLength = target.Y - groundY - Config.GroundClearance
	if ropeLength > maxLength and maxLength > Config.MinRopeLength then
		ropeLength = math.max(maxLength, ropeLength - Config.ReelSpeed * 2 * dt)
	end

	-- Pumping: input only acts along the swing arc, never along the rope.
	local move = (humanoid :: Humanoid).MoveDirection
	if move.Magnitude > 0 then
		velocity += (move - n * move:Dot(n)) * Config.PumpAcceleration * dt
	end

	-- Rope constraint: when the rope is taut, the body may not move away from the anchor.
	-- The outward component is replaced by an inward one proportional to the stretch,
	-- which keeps the radius stable without teleporting the character.
	if distance > ropeLength then
		local inward = velocity:Dot(n)
		local wanted = math.min((distance - ropeLength) * Config.RopeCorrection, 80)
		if inward < wanted then
			velocity += n * (wanted - inward)
		end
	end

	velocity *= 1 - Config.SwingAirDrag * dt
	if rope then
		rope:SetSlack(1 - distance / ropeLength)
	end
	(align :: AlignOrientation).CFrame = basis(velocity, n, body.CFrame.LookVector)
	return velocity
end

local function stepZip(body: BasePart, target: Vector3, velocity: Vector3): Vector3
	local toAnchor = target - body.Position
	if toAnchor.Magnitude < Config.ZipArriveDistance or os.clock() - zipStarted > Config.ZipMaxTime then
		local forward = unitOr(horizontal(toAnchor), body.CFrame.LookVector)
		dropRope(true)
		return forward * Config.ZipExitForward + Vector3.yAxis * Config.ZipExitUp
	end
	(align :: AlignOrientation).CFrame = basis(toAnchor, Vector3.yAxis, body.CFrame.LookVector)
	return toAnchor.Unit * Config.ZipSpeed
end

local function stepAir(body: BasePart, velocity: Vector3, dt: number): (Vector3, boolean)
	local move = (humanoid :: Humanoid).MoveDirection
	if move.Magnitude > 0 and horizontal(velocity):Dot(move) < Config.AirControlMaxSpeed then
		velocity += move * Config.AirControlAcceleration * dt
	end
	velocity *= 1 - Config.AirDrag * dt

	local forward = unitOr(horizontal(velocity), horizontal(body.CFrame.LookVector))
	local lean = math.clamp(-velocity.Y / 160, -0.35, 0.55)
	;(align :: AlignOrientation).CFrame = basis(forward, Vector3.yAxis, body.CFrame.LookVector)
		* CFrame.Angles(-lean, 0, 0)

	if velocity.Magnitude > 3 then
		stillSince = os.clock()
	end
	if velocity.Y <= 2 then
		local probe = Config.LandProbeLength + math.max(0, -velocity.Y) * dt * 3
		if Workspace:Raycast(body.Position, Vector3.new(0, -probe, 0), probeParams)
			or os.clock() - stillSince > 0.6 then
			return velocity, true
		end
	end
	return velocity, false
end

local function step(dt: number)
	local body = root
	if not body or not humanoid or humanoid.Health <= 0 then
		return
	end
	if mode ~= "Ground" then
		local velocity = body.AssemblyLinearVelocity
		local target = anchor
		local gravityScale = if mode == "Swing" then Config.SwingGravityScale else Config.AirGravityScale
		velocity += Vector3.yAxis * Workspace.Gravity * (1 - gravityScale) * dt
		if mode == "Swing" and target then
			velocity = stepSwing(body, target, velocity, dt)
		elseif mode == "Zip" and target then
			velocity = stepZip(body, target, velocity)
		else
			local landed
			velocity, landed = stepAir(body, velocity, dt)
			if landed then
				setMode("Ground")
			end
		end
		body.AssemblyLinearVelocity = clampSpeed(velocity)
	end
	aimArm()
end

local function cleanup()
	dropRope(false)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if align then
		align:Destroy()
	end
	setSlippery(false)
	table.clear(bodyParts)
	mode = "Ground"
	character, humanoid, root, hand, align, shoulder, fallTrack = nil, nil, nil, nil, nil, nil, nil
	armAimed = false
end

local function bindCharacter(newCharacter: Model)
	cleanup()
	local newHumanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	local newRoot = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	local handPart = newCharacter:WaitForChild("RightHand", 5) or newCharacter:WaitForChild("Right Arm", 5)
	if not handPart then
		return
	end
	character, humanoid, root = newCharacter, newHumanoid, newRoot
	hand = handPart:WaitForChild("RightGripAttachment") :: Attachment

	local rootAttachment = newRoot:FindFirstChild("RootAttachment") :: Attachment?
	if not rootAttachment then
		rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = "RootAttachment"
		rootAttachment.Parent = newRoot
	end
	local newAlign = Instance.new("AlignOrientation")
	newAlign.Name = "SwingAlign"
	newAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
	newAlign.Attachment0 = rootAttachment
	newAlign.MaxTorque = 1e7
	newAlign.Responsiveness = 28
	newAlign.Enabled = false
	newAlign.Parent = newRoot
	align = newAlign

	newHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local upperArm = newCharacter:FindFirstChild("RightUpperArm")
	local joint = upperArm and upperArm:FindFirstChild("RightShoulder")
	if joint and joint:IsA("Motor6D") then
		shoulder = joint
		shoulderC0 = joint.C0
	end

	local animate = newCharacter:WaitForChild("Animate", 3)
	local fallFolder = animate and animate:FindFirstChild("fall")
	local fallAnimation = fallFolder and fallFolder:FindFirstChildOfClass("Animation")
	local animator = newHumanoid:FindFirstChildOfClass("Animator")
	if fallAnimation and animator then
		local track = animator:LoadAnimation(fallAnimation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		fallTrack = track
	end

	for _, descendant in newCharacter:GetDescendants() do
		if descendant:IsA("BasePart") then
			bodyParts[descendant] = descendant.CustomPhysicalProperties
		end
	end

	probeParams.FilterDescendantsInstances = { newCharacter, webFolder }
	Targeting.setIgnore({ newCharacter, webFolder })

	table.insert(connections, newHumanoid.Died:Connect(function()
		dropRope(false)
		mode = "Ground"
		newAlign.Enabled = false
		if fallTrack then
			fallTrack:Stop(0)
		end
	end))
end

function SwingController.init()
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(cleanup)
end

function SwingController.step(dt: number)
	step(dt)
end

function SwingController.setSwingHeld(held: boolean)
	swingHeld = held
	if held then
		shoot("Swing")
	else
		release(false)
	end
end

function SwingController.zip()
	shoot("Zip")
end

function SwingController.setReel(held: boolean)
	reelHeld = held
end

function SwingController.jumpOff()
	if mode == "Swing" then
		release(true)
	end
end

function SwingController.getMode(): Mode
	return mode
end

function SwingController.getRoot(): BasePart?
	return root
end

function SwingController.getHumanoid(): Humanoid?
	return humanoid
end

function SwingController.getCharacter(): Model?
	return character
end

return SwingController
