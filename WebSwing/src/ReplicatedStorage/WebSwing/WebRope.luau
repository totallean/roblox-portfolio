local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WEB_COLOR = Color3.fromRGB(245, 248, 255)
local WEB_WIDTH = 0.14

export type WebRope = {
	Anchor: Part,
	Beam: Beam,
	Attached: boolean,
	ShootTo: (self: WebRope, target: Vector3, speed: number, onArrive: (() -> ())?, splat: boolean?) -> (),
	AttachInstant: (self: WebRope, target: Vector3, splat: boolean?) -> (),
	SetSlack: (self: WebRope, slack: number) -> (),
	GetEndPosition: (self: WebRope) -> Vector3,
	Release: (self: WebRope) -> (),
	Destroy: (self: WebRope) -> (),
}

local WebRope = {}
WebRope.__index = WebRope

local function makePoint(name: string, position: Vector3, parent: Instance): (Part, Attachment)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	part.Parent = parent
	return part, attachment
end

local function makeSplat(position: Vector3, parent: Instance)
	local splat = Instance.new("Part")
	splat.Name = "WebSplat"
	splat.Shape = Enum.PartType.Ball
	splat.Material = Enum.Material.Neon
	splat.Color = WEB_COLOR
	splat.Anchored = true
	splat.CanCollide = false
	splat.CanQuery = false
	splat.CanTouch = false
	splat.Size = Vector3.new(0.3, 0.3, 0.3)
	splat.Position = position
	splat.Parent = parent
	TweenService:Create(splat, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.1, 1.1, 1.1),
	}):Play()
	return splat
end

function WebRope.new(hand: Attachment, parent: Instance): WebRope
	local self = setmetatable({}, WebRope)
	self._hand = hand
	self._parent = parent
	self._connection = nil :: RBXScriptConnection?
	self._splat = nil :: Part?
	self.Attached = false

	local anchor, endAttachment = makePoint("WebAnchor", hand.WorldPosition, parent)
	self.Anchor = anchor
	self._end = endAttachment

	local beam = Instance.new("Beam")
	beam.Attachment0 = hand
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(WEB_COLOR)
	beam.LightEmission = 0.4
	beam.LightInfluence = 0.6
	beam.Width0 = WEB_WIDTH
	beam.Width1 = WEB_WIDTH * 0.7
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Transparency = NumberSequence.new(0.05)
	beam.Parent = anchor
	self.Beam = beam

	return (self :: any) :: WebRope
end

function WebRope:ShootTo(target: Vector3, speed: number, onArrive: (() -> ())?, splat: boolean?)
	local startTime = os.clock()
	if self._connection then
		self._connection:Disconnect()
	end
	self._connection = RunService.Heartbeat:Connect(function()
		local from = self._hand.WorldPosition
		local total = (target - from).Magnitude
		local travelled = (os.clock() - startTime) * speed
		if travelled >= total then
			self._connection:Disconnect()
			self._connection = nil
			self:AttachInstant(target, splat)
			if onArrive then
				onArrive()
			end
			return
		end
		self.Anchor.Position = from:Lerp(target, travelled / total)
	end)
end

function WebRope:AttachInstant(target: Vector3, splat: boolean?)
	self.Anchor.Position = target
	self.Attached = true
	if splat ~= false and not self._splat then
		self._splat = makeSplat(target, self._parent)
	end
end

function WebRope:SetSlack(slack: number)
	local sag = math.clamp(slack, 0, 1) * 6
	self.Beam.CurveSize0 = -sag
	self.Beam.CurveSize1 = sag * 0.5
end

function WebRope:GetEndPosition(): Vector3
	return self.Anchor.Position
end

function WebRope:Release()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	local loose, looseAttachment = makePoint("WebLoose", self._hand.WorldPosition, self._parent)
	self.Beam.Attachment0 = looseAttachment
	self.Beam.CurveSize0 = 0
	self.Beam.CurveSize1 = 0
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(loose, info, { Position = self.Anchor.Position }):Play()
	TweenService:Create(self.Beam, info, { Width0 = 0, Width1 = 0 }):Play()
	task.delay(0.2, function()
		loose:Destroy()
		self:Destroy()
	end)
end

function WebRope:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	local splat = self._splat
	if splat then
		self._splat = nil
		TweenService:Create(splat, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		task.delay(0.65, function()
			splat:Destroy()
		end)
	end
	self.Anchor:Destroy()
end

return WebRope
