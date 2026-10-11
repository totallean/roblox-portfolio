-- Cosmetic, client-only flicker. Lamps near the stalker stutter violently, which doubles as a warning.
local Workspace = game:GetService("Workspace")

local Lamps = {}

type Lamp = { part: BasePart, light: PointLight, brightness: number, flicker: boolean, color: Color3 }

local lamps: { Lamp } = {}
local rng = Random.new()
local accumulator = 0

function Lamps.init()
	local mansion = Workspace:WaitForChild("Mansion")
	for _, part in mansion:WaitForChild("Lamps"):GetDescendants() do
		local light = part:FindFirstChildOfClass("PointLight")
		if part:IsA("BasePart") and light then
			table.insert(lamps, {
				part = part,
				light = light,
				brightness = light.Brightness,
				flicker = part:GetAttribute("Flicker") == true,
				color = part.Color,
			})
		end
	end
end

local function set(lamp: Lamp, level: number)
	lamp.light.Brightness = lamp.brightness * level
	lamp.part.Color = lamp.color:Lerp(Color3.new(0.1, 0.08, 0.06), 1 - level)
end

function Lamps.update(dt: number, stalkerPosition: Vector3?)
	accumulator += dt
	if accumulator < 1 / 15 then
		return
	end
	accumulator = 0
	for _, lamp in lamps do
		local near = stalkerPosition and (lamp.part.Position - stalkerPosition).Magnitude < 18
		if near then
			set(lamp, if rng:NextNumber() < 0.45 then 0 else rng:NextNumber(0.3, 1))
		elseif lamp.flicker and rng:NextNumber() < 0.08 then
			set(lamp, rng:NextNumber(0, 0.5))
		else
			set(lamp, 1)
		end
	end
end

return Lamps
