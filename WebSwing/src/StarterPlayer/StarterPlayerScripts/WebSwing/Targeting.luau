local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("WebSwing"):WaitForChild("Config"))

export type Target = {
	point: Vector3,
	pivot: Vector3,
}

local player = Players.LocalPlayer

local Targeting = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local swingTarget: Target? = nil
local zipTarget: Target? = nil

type Marker = { attachment: Attachment, gui: BillboardGui, scale: UIScale, visible: boolean }
local aimMarker: Marker
local swingMarker: Marker

local function circle(parent: Instance, size: number, color: Color3, filled: boolean)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = if filled then 0 else 1
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
	if not filled then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = color
		stroke.Parent = frame
	end
end

local function makeMarker(name: string, size: number): Marker
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = Workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(size, size)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = attachment
	gui.Enabled = false
	gui.ResetOnSpawn = false

	local scale = Instance.new("UIScale")
	scale.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return { attachment = attachment, gui = gui, scale = scale, visible = false }
end

local function showMarker(marker: Marker, position: Vector3?)
	if position then
		marker.attachment.WorldPosition = position
	end
	local visible = position ~= nil
	if visible ~= marker.visible then
		marker.visible = visible
		marker.gui.Enabled = visible
		if visible then
			marker.scale.Scale = 1.6
			TweenService:Create(marker.scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
end

local function isCharacterPart(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- The physics pivot sits a few studs in front of the surface, so the bottom of the arc does not
-- scrape the wall the web is stuck to. The visual web still ends exactly on the surface.
local function toTarget(result: RaycastResult?, rootPosition: Vector3): Target?
	if not result or result.Instance:GetAttribute("NoWeb") or isCharacterPart(result.Instance) then
		return nil
	end
	local distance = (result.Position - rootPosition).Magnitude
	if distance < Config.MinWebDistance or distance > Config.MaxWebDistance then
		return nil
	end
	return { point = result.Position, pivot = result.Position + result.Normal * Config.WallOffset }
end

local function visible(rootPosition: Vector3, point: Vector3): boolean
	return Workspace:Raycast(rootPosition, (point - rootPosition) * 0.97, params) == nil
end

local function aimRay(camera: Camera): Ray
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled
		and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y * 0.42)
end

local function travelDirection(camera: Camera, velocity: Vector3): Vector3?
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	flat = flat.Unit
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if flatVelocity.Magnitude > 25 and flatVelocity.Unit:Dot(flat) > 0 then
		flat = flat:Lerp(flatVelocity.Unit, 0.35).Unit
	end
	return flat
end

-- Aimed target: where the mouse / screen centre points, with a line-of-sight check from the body.
local function aimedTarget(camera: Camera, rootPosition: Vector3): Target?
	local ray = aimRay(camera)
	local reach = Config.MaxWebDistance + (camera.CFrame.Position - rootPosition).Magnitude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	if not hit then
		return nil
	end
	local fromRoot = Workspace:Raycast(rootPosition, (hit.Position - rootPosition) * 1.02, params)
	return toTarget(fromRoot or hit, rootPosition)
end

-- Swing target: an ideal point ahead of and above the player is projected sideways onto the
-- nearest facade. The web lands on the side of the street and the arc runs along it.
local function sideTarget(rootPosition: Vector3, forward: Vector3): Target?
	local right = forward:Cross(Vector3.yAxis)
	for index, ahead in Config.SwingAhead do
		local ideal = rootPosition + forward * ahead + Vector3.yAxis * Config.SwingHeight[index]
		local best: RaycastResult? = nil
		local bestDistance = math.huge
		for _, side in { right, -right } do
			local hit = Workspace:Raycast(ideal, side * Config.SwingSideReach, params)
			if hit and hit.Normal:Dot(side) < -0.5 then
				local distance = (hit.Position - ideal).Magnitude
				if distance < bestDistance then
					best, bestDistance = hit, distance
				end
			end
		end
		if best and visible(rootPosition, best.Position) then
			local target = toTarget(best, rootPosition)
			if target then
				return target
			end
		end
	end
	return nil
end

-- Fallback: fan of rays forward and upward from the body (open plazas, rooftops, ceilings).
local function coneTarget(rootPosition: Vector3, forward: Vector3, minHeight: number): Target?
	for _, pitch in Config.AssistPitches do
		local p = math.rad(pitch)
		for _, yaw in Config.AssistYaws do
			local yawed = CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(forward)
			local direction = yawed * math.cos(p) + Vector3.yAxis * math.sin(p)
			local target = toTarget(Workspace:Raycast(rootPosition, direction * Config.MaxWebDistance, params), rootPosition)
			if target and target.point.Y >= rootPosition.Y + minHeight then
				return target
			end
		end
	end
	return nil
end

function Targeting.init()
	aimMarker = makeMarker("WebAimReticle", 34)
	circle(aimMarker.gui, 34, Color3.new(1, 1, 1), false)
	circle(aimMarker.gui, 6, Color3.fromRGB(255, 70, 70), true)

	swingMarker = makeMarker("WebSwingPoint", 14)
	circle(swingMarker.gui, 10, Color3.fromRGB(150, 220, 255), true)
end

function Targeting.setIgnore(list: { Instance })
	params.FilterDescendantsInstances = list
end

function Targeting.update(root: BasePart?)
	local camera = Workspace.CurrentCamera
	swingTarget, zipTarget = nil, nil
	if root and camera then
		local position = root.Position
		local forward = travelDirection(camera, root.AssemblyLinearVelocity)
		zipTarget = aimedTarget(camera, position)
		if zipTarget and zipTarget.point.Y < position.Y - 4 then
			zipTarget = nil
		end
		if forward then
			swingTarget = sideTarget(position, forward) or coneTarget(position, forward, Config.MinSwingAnchorHeight)
			zipTarget = zipTarget or coneTarget(position, forward, 0)
		end
	end
	showMarker(aimMarker, zipTarget and zipTarget.point)
	showMarker(swingMarker, swingTarget and swingTarget.point)
end

function Targeting.get(kind: "Swing" | "Zip"): Target?
	if kind == "Zip" then
		return zipTarget
	end
	return swingTarget
end

function Targeting.aimDirection(): Vector3
	return aimRay(Workspace.CurrentCamera).Direction.Unit
end

return Targeting
