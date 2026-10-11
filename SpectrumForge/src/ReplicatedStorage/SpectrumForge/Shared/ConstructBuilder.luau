--!strict

local Eco = require(script.Parent.EconomyConfig)
local Catalog = require(script.Parent.PartCatalog)
local Types = require(script.Parent.Types)

local ConstructBuilder = {}

export type SpecEntry = { defId: string, tier: number }
export type Spec = { [string]: SpecEntry }

function ConstructBuilder.encode(build: Types.Build?, parts: { [string]: Types.PartInstance }): string
	local chunks = {}
	for _, slot in Eco.SLOTS do
		local uid = build and (build :: any)[slot]
		local part = uid and parts[uid]
		if part then
			table.insert(chunks, ("%s:%d"):format(part.defId, part.tier))
		else
			table.insert(chunks, "-")
		end
	end
	return table.concat(chunks, "|")
end

function ConstructBuilder.decode(spec: string): Spec
	local result: Spec = {}
	local index = 1

	for chunk in string.gmatch(spec, "([^|]+)") do
		local slot = Eco.SLOTS[index]
		if slot and chunk ~= "-" then
			local defId, tier = string.match(chunk, "^(.-):(%d+)$")
			if defId and Catalog.ById[defId] then
				result[slot] = { defId = defId, tier = tonumber(tier) :: number }
			end
		end
		index += 1
	end

	return result
end

function ConstructBuilder.topTier(spec: string): number
	local best = 1
	for tier in string.gmatch(spec, ":(%d+)") do
		best = math.max(best, tonumber(tier) :: number)
	end
	return best
end

local function place(part: BasePart, model: Model, size: Vector3, offset: CFrame, color: Color3): BasePart
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function piece(model: Model, size: Vector3, offset: CFrame, color: Color3, neon: boolean, shape: Enum.PartType?): BasePart
	local part = Instance.new("Part")
	if shape then
		part.Shape = shape
	end
	return place(part, model, size, offset, if neon then color else color:Lerp(Color3.new(0, 0, 0), 0.6))
end

local function wedge(model: Model, size: Vector3, offset: CFrame, color: Color3): BasePart
	return place(Instance.new("WedgePart"), model, size, offset, color)
end

local FRAME = {
	frame_plate = function(m, c)
		piece(m, Vector3.new(1.3, 0.35, 1.9), CFrame.new(), c, false)
	end,
	frame_lattice = function(m, c)
		piece(m, Vector3.new(0.25, 0.25, 2.4), CFrame.new(0.5, 0, 0), c, false)
		piece(m, Vector3.new(0.25, 0.25, 2.4), CFrame.new(-0.5, 0, 0), c, false)
		piece(m, Vector3.new(1.3, 0.2, 0.2), CFrame.new(0, 0, 0.6), c, false)
	end,
	frame_husk = function(m, c)
		piece(m, Vector3.new(1.4, 0.9, 1.4), CFrame.new(), c, false)
		piece(m, Vector3.new(1.0, 1.1, 1.0), CFrame.new(0, 0, 0), c, true)
	end,
	frame_bulwark = function(m, c)
		piece(m, Vector3.new(1.6, 0.7, 1.6), CFrame.new(), c, false)
		piece(m, Vector3.new(0.4, 1.4, 0.4), CFrame.new(0.9, 0, 0), c, false)
		piece(m, Vector3.new(0.4, 1.4, 0.4), CFrame.new(-0.9, 0, 0), c, false)
	end,
}

local CORE = {
	core_prism = function(m, c, s)
		piece(m, Vector3.new(0.7, 0.7, 0.7) * s, CFrame.new(0, 0.5, 0) * CFrame.Angles(0.6, 0.8, 0), c, true)
	end,
	core_reactor = function(m, c, s)
		piece(m, Vector3.new(0.8, 0.8, 0.8) * s, CFrame.new(0, 0.5, 0), c, true, Enum.PartType.Ball)
		piece(m, Vector3.new(1.1, 0.12, 1.1) * s, CFrame.new(0, 0.5, 0), c, true, Enum.PartType.Cylinder)
	end,
	core_shard = function(m, c, s)
		wedge(m, Vector3.new(0.5, 1.1, 0.5) * s, CFrame.new(0, 0.7, 0), c)
		wedge(m, Vector3.new(0.5, 1.1, 0.5) * s, CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.pi, 0), c)
	end,
	core_heart = function(m, c, s)
		piece(m, Vector3.new(0.6, 0.6, 0.6) * s, CFrame.new(0, 0.55, 0), c, true, Enum.PartType.Ball)
		piece(m, Vector3.new(0.35, 0.35, 0.35) * s, CFrame.new(0, 0.95, 0), c, true, Enum.PartType.Ball)
	end,
}

local EMITTER = {
	emit_lance = function(m, c)
		piece(m, Vector3.new(0.22, 0.22, 2.6), CFrame.new(0, 0.2, -1.6), c, true)
		wedge(m, Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, 0.2, -3.0) * CFrame.Angles(-math.pi / 2, 0, 0), c)
	end,
	emit_spray = function(m, c)
		for _, x in { -0.35, 0, 0.35 } do
			piece(m, Vector3.new(0.16, 0.16, 1.5), CFrame.new(x, 0.2, -1.1) * CFrame.Angles(0, x * 0.25, 0), c, true)
		end
	end,
	emit_coil = function(m, c)
		for index = 0, 3 do
			piece(m, Vector3.new(0.75 - index * 0.12, 0.14, 0.75 - index * 0.12),
				CFrame.new(0, 0.2, -0.7 - index * 0.45) * CFrame.Angles(0, 0, math.pi / 2), c, true, Enum.PartType.Cylinder)
		end
	end,
	emit_beam = function(m, c)
		piece(m, Vector3.new(0.5, 0.5, 2.2), CFrame.new(0, 0.2, -1.4), c, false, Enum.PartType.Cylinder)
		piece(m, Vector3.new(0.3, 0.3, 2.6), CFrame.new(0, 0.2, -1.5), c, true, Enum.PartType.Cylinder)
	end,
}

local FOCUS = {
	focus_lens = function(m, c)
		piece(m, Vector3.new(0.1, 1.2, 1.2), CFrame.new(0, 0.5, -0.5) * CFrame.Angles(0, 0, math.pi / 2), c, true, Enum.PartType.Cylinder)
	end,
	focus_eye = function(m, c)
		piece(m, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.1, -0.3), c, true, Enum.PartType.Ball)
		piece(m, Vector3.new(0.8, 0.1, 0.8), CFrame.new(0, 1.1, -0.3), c, false, Enum.PartType.Cylinder)
	end,
	focus_facet = function(m, c)
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3
			piece(m, Vector3.new(0.18, 0.7, 0.18),
				CFrame.new(math.cos(angle) * 0.6, 0.6, math.sin(angle) * 0.6) * CFrame.Angles(0, -angle, 0.4), c, true)
		end
	end,
	focus_spike = function(m, c)
		wedge(m, Vector3.new(0.25, 1.0, 0.25), CFrame.new(0, 1.1, 0.2), c)
		piece(m, Vector3.new(0.6, 0.12, 0.6), CFrame.new(0, 0.6, 0.2), c, false, Enum.PartType.Cylinder)
	end,
}

local SIGIL = {
	sigil_mark = function(m, c)
		piece(m, Vector3.new(0.5, 0.5, 0.12), CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 4), c, true)
	end,
	sigil_brand = function(m, c)
		piece(m, Vector3.new(0.7, 0.1, 0.7), CFrame.new(0, 1.7, 0), c, true, Enum.PartType.Cylinder)
		piece(m, Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 1.7, 0), c, true, Enum.PartType.Ball)
	end,
	sigil_crown = function(m, c)
		for index = 0, 4 do
			local angle = index * math.pi * 2 / 5
			piece(m, Vector3.new(0.12, 0.45, 0.12),
				CFrame.new(math.cos(angle) * 0.45, 1.8, math.sin(angle) * 0.45), c, true)
		end
	end,
	sigil_seal = function(m, c)
		piece(m, Vector3.new(0.9, 0.08, 0.9), CFrame.new(0, 1.7, 0), c, true, Enum.PartType.Cylinder)
		piece(m, Vector3.new(0.5, 0.14, 0.5), CFrame.new(0, 1.78, 0), c, false, Enum.PartType.Cylinder)
	end,
}

local BUILDERS = {
	frame = FRAME,
	core = CORE,
	emitter = EMITTER,
	focus = FOCUS,
	sigil = SIGIL,
}

local BUILD_ORDER = { "frame", "core", "emitter", "focus", "sigil" }

local WHITE = Color3.new(1, 1, 1)

function ConstructBuilder.build(spec: Spec): Model
	local model = Instance.new("Model")
	model.Name = "Construct"

	local anchor = Instance.new("Part")
	anchor.Name = "Root"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = model
	model.PrimaryPart = anchor

	for _, slot in BUILD_ORDER do
		local entry = spec[slot]
		if not entry then
			continue
		end
		local maker = BUILDERS[slot][entry.defId]
		if not maker then
			continue
		end

		local colorDef = Eco.COLORS[entry.tier]
		local scale = if slot == "core" then 1 + entry.tier * 0.06 else 1
		maker(model, if colorDef then colorDef.color else WHITE, scale)
	end

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= anchor then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = part
			weld.Parent = anchor
			part.Anchored = false
		end
	end

	return model
end

function ConstructBuilder.buildFromString(spec: string): Model
	return ConstructBuilder.build(ConstructBuilder.decode(spec))
end

return ConstructBuilder
