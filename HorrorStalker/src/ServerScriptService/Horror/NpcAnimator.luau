-- Server-side locomotion animation for an NPC humanoid (players get this from the Animate LocalScript).
local DEFAULT_IDS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
}

export type NpcAnimator = {
	update: (self: NpcAnimator) -> (),
	destroy: (self: NpcAnimator) -> (),
}

local NpcAnimator = {}
NpcAnimator.__index = NpcAnimator

local function animationId(model: Model, folderName: string, fallback: string): string
	local animate = model:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(folderName)
	local animation = folder and folder:FindFirstChildOfClass("Animation")
	return if animation and animation.AnimationId ~= "" then animation.AnimationId else fallback
end

function NpcAnimator.new(model: Model, humanoid: Humanoid, root: BasePart): NpcAnimator
	local self = setmetatable({}, NpcAnimator)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	self._root = root
	self._tracks = {}
	for name, fallback in DEFAULT_IDS do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId(model, name, fallback)
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Core
		self._tracks[name] = track
	end
	self._current = nil
	return (self :: any) :: NpcAnimator
end

function NpcAnimator:update()
	local velocity = self._root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local name = if speed < 0.6 then "idle" elseif speed < 15 then "walk" else "run"
	local track = self._tracks[name]
	if self._current ~= track then
		if self._current then
			self._current:Stop(0.25)
		end
		track:Play(0.25)
		self._current = track
	end
	if name == "walk" then
		track:AdjustSpeed(math.max(0.5, speed / 12))
	elseif name == "run" then
		track:AdjustSpeed(math.max(0.8, speed / 20))
	end
end

function NpcAnimator:destroy()
	for _, track in self._tracks do
		track:Stop(0)
		track:Destroy()
	end
end

return NpcAnimator
