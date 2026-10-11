local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Horror"):WaitForChild("Config"))

export type Lamp = { position: Vector3, radius: number }

export type Sight = {
	visible: boolean,
	distance: number,
	visibility: number,
	maxDistance: number,
}

local S = Config.Stalker

local Perception = {}

local lamps: { Lamp } = {}
local safeZones: { BasePart } = {}

function Perception.registerLamps(folder: Instance)
	table.clear(lamps)
	for _, lamp in folder:GetDescendants() do
		if lamp:IsA("BasePart") and lamp:GetAttribute("LampRadius") then
			table.insert(lamps, { position = lamp.Position, radius = lamp:GetAttribute("LampRadius") :: number })
		end
	end
end

function Perception.registerSafeZone(zone: BasePart)
	table.insert(safeZones, zone)
end

function Perception.inSafeZone(position: Vector3): boolean
	for _, zone in safeZones do
		local p = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- 0..1 light level at a point from the static lamp list; the falloff mirrors PointLight roughly.
function Perception.lightAt(position: Vector3): number
	local best = 0
	for _, lamp in lamps do
		local d = (lamp.position - position).Magnitude
		if d < lamp.radius then
			best = math.max(best, 1 - (d / lamp.radius) ^ 2)
		end
	end
	return best
end

-- How visible a player is, combining ambient light, their flashlight and crouching.
function Perception.visibility(position: Vector3, flashlightOn: boolean, crouched: boolean): number
	local light = Perception.lightAt(position)
	local value = 0.45 + 0.55 * light
	if flashlightOn then
		value = math.max(value, S.FlashlightVisibility)
	end
	if crouched then
		value *= S.CrouchVisibility
	end
	return value
end

-- Noise is derived from the measured speed of the character, not from what the client claims.
function Perception.noiseRadius(horizontalSpeed: number, crouched: boolean): number
	if crouched or horizontalSpeed < 2 then
		return S.HearCrouching
	end
	if horizontalSpeed > Config.Player.WalkSpeed + 3 then
		return S.HearRunning
	end
	return S.HearWalking
end

-- Vision test: distance scaled by visibility, a horizontal view cone with a small "sixth sense"
-- radius behind the head, and a line-of-sight raycast that ignores both characters.
function Perception.canSee(eye: CFrame, target: Vector3, visibility: number, params: RaycastParams): Sight
	local offset = target - eye.Position
	local distance = offset.Magnitude
	local maxDistance = math.clamp(S.ViewDistanceDark + (S.ViewDistance - S.ViewDistanceDark) * (visibility - 0.45) / 0.55,
		S.ViewDistanceDark * S.CrouchVisibility, S.ViewDistance * 1.25)
	local sight: Sight = { visible = false, distance = distance, visibility = visibility, maxDistance = maxDistance }
	if distance > maxDistance then
		return sight
	end
	if distance > S.PeripheralDistance then
		local flatLook = Vector3.new(eye.LookVector.X, 0, eye.LookVector.Z).Unit
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		if flatOffset.Magnitude > 1e-3 then
			local cos = flatLook:Dot(flatOffset.Unit)
			if cos < math.cos(math.rad(S.FieldOfView / 2)) then
				return sight
			end
		end
	end
	local hit = Workspace:Raycast(eye.Position, offset, params)
	sight.visible = hit == nil
	return sight
end

return Perception
