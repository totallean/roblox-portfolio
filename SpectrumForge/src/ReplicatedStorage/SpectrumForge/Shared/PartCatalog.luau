--!strict

local Types = require(script.Parent.Types)

local PartCatalog = {}

export type PartDef = {
	id: string,
	slot: Types.Slot,
	name: string,
	mesh: string?,
	w: { [string]: number }?,
}

local Defs: { PartDef } = {
	{ id = "core_prism",   slot = "core", name = "Призма",     w = { dmg = 1.00 } },
	{ id = "core_reactor", slot = "core", name = "Реактор",    w = { dmg = 1.25 } },
	{ id = "core_shard",   slot = "core", name = "Осколок",    w = { dmg = 0.80 } },
	{ id = "core_heart",   slot = "core", name = "Сердцевина", w = { dmg = 1.10 } },

	{ id = "emit_lance",  slot = "emitter", name = "Копьё",   w = { spd = 0.75, dmg = 1.30 } },
	{ id = "emit_spray",  slot = "emitter", name = "Веер",    w = { spd = 1.40, dmg = 0.70 } },
	{ id = "emit_coil",   slot = "emitter", name = "Катушка", w = { spd = 1.15, dmg = 0.90 } },
	{ id = "emit_beam",   slot = "emitter", name = "Луч",     w = { spd = 1.00, dmg = 1.00 } },

	{ id = "frame_plate",   slot = "frame", name = "Панцирь",  w = { hp = 1.00, armor = 1.00 } },
	{ id = "frame_lattice", slot = "frame", name = "Решётка",  w = { hp = 1.35, armor = 0.35 } },
	{ id = "frame_husk",    slot = "frame", name = "Оболочка", w = { hp = 1.15, armor = 0.70 } },
	{ id = "frame_bulwark", slot = "frame", name = "Оплот",    w = { hp = 0.65, armor = 2.10 } },

	{ id = "focus_lens",  slot = "focus", name = "Линза", w = { crit = 1.00, pierce = 1.00 } },
	{ id = "focus_eye",   slot = "focus", name = "Око",   w = { crit = 1.40, pierce = 0.30 } },
	{ id = "focus_facet", slot = "focus", name = "Грань", w = { crit = 1.15, pierce = 0.75 } },
	{ id = "focus_spike", slot = "focus", name = "Игла",  w = { crit = 0.55, pierce = 2.20 } },

	{ id = "sigil_mark",  slot = "sigil", name = "Метка" },
	{ id = "sigil_brand", slot = "sigil", name = "Клеймо" },
	{ id = "sigil_crown", slot = "sigil", name = "Венец" },
	{ id = "sigil_seal",  slot = "sigil", name = "Печать" },
}

PartCatalog.Defs = Defs

PartCatalog.ById = {} :: { [string]: PartDef }
PartCatalog.BySlot = {} :: { [Types.Slot]: { PartDef } }

for _, def in PartCatalog.Defs do
	PartCatalog.ById[def.id] = def
	local bucket = PartCatalog.BySlot[def.slot]
	if not bucket then
		bucket = {}
		PartCatalog.BySlot[def.slot] = bucket
	end
	table.insert(bucket, def)
end

function PartCatalog.weight(defId: string, key: string): number
	local def = PartCatalog.ById[defId]
	if not def or not def.w then
		return 1
	end
	return def.w[key] or 1
end

function PartCatalog.randomForSlot(slot: Types.Slot, rng: Random): PartDef
	local bucket = PartCatalog.BySlot[slot]
	return bucket[rng:NextInteger(1, #bucket)]
end

return PartCatalog
