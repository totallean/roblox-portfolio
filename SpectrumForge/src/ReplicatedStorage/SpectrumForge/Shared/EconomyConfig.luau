--!strict

local EconomyConfig = {}

EconomyConfig.RING_COST_BASE = 15
EconomyConfig.RING_COST_GROWTH = 1.15
EconomyConfig.RING_WPS_BASE = 1
EconomyConfig.RING_WPS_GROWTH = 1.135
EconomyConfig.TAP_WPS_FRACTION = 0.5

function EconomyConfig.ringCost(level: number): number
	return EconomyConfig.RING_COST_BASE * EconomyConfig.RING_COST_GROWTH ^ (level - 1)
end

function EconomyConfig.ringWPS(level: number): number
	return EconomyConfig.RING_WPS_BASE * EconomyConfig.RING_WPS_GROWTH ^ (level - 1)
end

function EconomyConfig.ringCostBulk(fromLevel: number, count: number): number
	local g = EconomyConfig.RING_COST_GROWTH
	return EconomyConfig.ringCost(fromLevel) * (g ^ count - 1) / (g - 1)
end

EconomyConfig.RING_MAX_BULK = 1000

function EconomyConfig.maxAffordableLevels(will: number, level: number): number
	local g = EconomyConfig.RING_COST_GROWTH
	local first = EconomyConfig.ringCost(level)
	if will < first then
		return 0
	end
	local n = math.floor(math.log(will * (g - 1) / first + 1, g))
	return math.clamp(n, 0, EconomyConfig.RING_MAX_BULK)
end

EconomyConfig.COLORS = {
	{ id = "will",       name = "Воля",        en = "WILLPOWER",  wpsMult = 1.0,  color = Color3.fromRGB( 40, 220,  90) },
	{ id = "fear",       name = "Страх",       en = "FEAR",       wpsMult = 1.6,  color = Color3.fromRGB(240, 210,  40) },
	{ id = "rage",       name = "Ярость",      en = "RAGE",       wpsMult = 2.5,  color = Color3.fromRGB(230,  45,  45) },
	{ id = "hope",       name = "Надежда",     en = "HOPE",       wpsMult = 4.0,  color = Color3.fromRGB( 60, 165, 255) },
	{ id = "love",       name = "Любовь",      en = "LOVE",       wpsMult = 6.5,  color = Color3.fromRGB(225,  75, 185) },
	{ id = "greed",      name = "Алчность",    en = "GREED",      wpsMult = 10.0, color = Color3.fromRGB(255, 140,  20) },
	{ id = "compassion", name = "Сострадание", en = "COMPASSION", wpsMult = 16.0, color = Color3.fromRGB( 95,  70, 225) },
	{ id = "death",      name = "Смерть",      en = "DEATH",      wpsMult = 26.0, color = Color3.fromRGB( 60,  60,  72) },
	{ id = "life",       name = "Жизнь",       en = "LIFE",       wpsMult = 42.0, color = Color3.fromRGB(245, 245, 255) },
}

EconomyConfig.MATCH_MULT = { 1.0, 1.15, 1.40, 1.80, 2.50 }

EconomyConfig.REBIRTH_FOR_COLOR = { 0, 3, 7, 12, 18, 26, 36, 50, 70 }

EconomyConfig.CHARGE_PER_MULT = 0.2

EconomyConfig.REBIRTH_REQ = { 70, 80, 95, 112, 132 }
EconomyConfig.REBIRTH_CHARGE = { 10, 4, 5, 6, 7 }
EconomyConfig.REBIRTH_REQ_GROWTH = 1.20

function EconomyConfig.rebirthRequirement(n: number): number
	local manual = EconomyConfig.REBIRTH_REQ[n]
	if manual then
		return manual
	end
	local tail = #EconomyConfig.REBIRTH_REQ
	return math.floor(EconomyConfig.REBIRTH_REQ[tail] * EconomyConfig.REBIRTH_REQ_GROWTH ^ (n - tail))
end

function EconomyConfig.rebirthCharge(n: number, ringLevel: number): number
	local manual = EconomyConfig.REBIRTH_CHARGE[n]
	if manual then
		return manual
	end
	return math.floor(3 * (ringLevel / 70) ^ 1.5)
end

function EconomyConfig.rebirthMultiplier(totalCharge: number): number
	return 1 + EconomyConfig.CHARGE_PER_MULT * totalCharge
end

EconomyConfig.PART_STAT_GROWTH = 1.18
EconomyConfig.SLOTS = { "core", "emitter", "frame", "focus", "sigil" }

function EconomyConfig.partQuality(partLevel: number, tier: number): number
	return partLevel + 3 * (tier - 1)
end

function EconomyConfig.coreDamage(q: number): number
	return 10 * EconomyConfig.PART_STAT_GROWTH ^ q
end

function EconomyConfig.frameHP(q: number): number
	return 100 * EconomyConfig.PART_STAT_GROWTH ^ q
end

function EconomyConfig.frameArmor(q: number): number
	return 20 * EconomyConfig.PART_STAT_GROWTH ^ q
end

function EconomyConfig.focusPierce(q: number): number
	return 20 * EconomyConfig.PART_STAT_GROWTH ^ q
end

function EconomyConfig.emitterSpeed(q: number): number
	return math.min(3.0, 0.8 + 0.04 * q)
end

function EconomyConfig.focusCrit(q: number): (number, number)
	return math.min(60, 5 + 1.5 * q), 1.5 + 0.05 * q
end

EconomyConfig.PART_UPGRADE_BASE = 25
EconomyConfig.PART_UPGRADE_GROWTH = 1.35

function EconomyConfig.partUpgradeCost(level: number, tier: number): number
	return math.ceil(
		EconomyConfig.PART_UPGRADE_BASE
			* EconomyConfig.PART_UPGRADE_GROWTH ^ (level - 1)
			* tier
	)
end

function EconomyConfig.sigilBonus(tier: number): number
	return 0.05 * tier
end

function EconomyConfig.computeDPS(damage: number, speed: number, critPct: number, critMult: number): number
	return damage * speed * (1 + (critPct / 100) * (critMult - 1))
end

EconomyConfig.ARCHETYPES = {
	[1] = { id = "balance",  desc = "Ровный: средняя броня и пробитие" },
	[2] = { id = "fear",     desc = "Урон врага -18%, сильное пробитие, мало брони" },
	[3] = { id = "rage",     desc = "Урон +60%, прочность -32%, брони почти нет" },
	[4] = { id = "solace",   desc = "Прочность +45%, стена брони, слабое пробитие" },
	[5] = { id = "leech",    desc = "Прочность растёт от превосходства в уроне" },
	[6] = { id = "greed",    desc = "+12% ко всему и кража Осколков при победе" },
	[7] = { id = "mercy",    desc = "Отменяет эффект противника, себе +15%" },
	[8] = { id = "void",     desc = "Статы врага -22%, много брони, слабое пробитие" },
	[9] = { id = "life",     desc = "+30% ко всему" },
}

EconomyConfig.ARMOR_FRACTION = 0.35
EconomyConfig.PIERCE_FRACTION = 0.30
EconomyConfig.DAMAGE_FLOOR = 0.15

export type BattleSide = {
	dps: number,
	hp: number,
	tier: number?,
	armor: number?,
	pierce: number?,
}

local function applySelf(tier: number, dps: number, hp: number): (number, number)
	if tier == 3 then
		dps *= 1.60
		hp *= 0.68
	elseif tier == 4 then
		hp *= 1.45
	elseif tier == 6 then
		dps *= 1.12
		hp *= 1.12
	elseif tier == 7 then
		dps *= 1.15
		hp *= 1.15
	elseif tier == 9 then
		dps *= 1.30
		hp *= 1.30
	end
	return dps, hp
end

local ARMOR_MULT = {
	[1] = 1.0,
	[2] = 0.5,
	[3] = 0.3,
	[4] = 2.2,
	[5] = 0.8,
	[6] = 1.0,
	[7] = 1.2,
	[8] = 1.6,
	[9] = 1.4,
}

local PIERCE_MULT = {
	[1] = 1.0,
	[2] = 2.4,
	[3] = 1.8,
	[4] = 0.4,
	[5] = 1.0,
	[6] = 1.1,
	[7] = 1.3,
	[8] = 0.7,
	[9] = 1.2,
}

local function statsOf(side: BattleSide, tier: number): (number, number, number, number)
	local d, h = applySelf(tier, side.dps, side.hp)
	local armor = (side.armor or 0) * (ARMOR_MULT[tier] or 1)
	local pierce = (side.pierce or 0) * (PIERCE_MULT[tier] or 1)
	return d, h, armor, pierce
end

function EconomyConfig.resolveBattle(a: BattleSide, b: BattleSide): boolean
	local aTier = a.tier or 0
	local bTier = b.tier or 0

	local aActive = if bTier == 7 then 0 else aTier
	local bActive = if aTier == 7 then 0 else bTier

	if aActive == 0 and bActive == 0 then
		local plainA = b.hp / math.max(a.dps, 1e-9)
		local plainB = a.hp / math.max(b.dps, 1e-9)
		if plainA ~= plainB then
			return plainA < plainB
		end
		return a.hp >= b.hp
	end

	local aDps, aHp, aArmor, aPierce = statsOf(a, aActive)
	local bDps, bHp, bArmor, bPierce = statsOf(b, bActive)

	if aActive == 2 then bDps *= 0.82 end
	if bActive == 2 then aDps *= 0.82 end
	if aActive == 8 then bDps *= 0.78; bHp *= 0.78 end
	if bActive == 8 then aDps *= 0.78; aHp *= 0.78 end

	local aEff = math.max(aDps - math.max(0, bArmor - aPierce), aDps * EconomyConfig.DAMAGE_FLOOR)
	local bEff = math.max(bDps - math.max(0, aArmor - bPierce), bDps * EconomyConfig.DAMAGE_FLOOR)

	if aActive == 5 then
		aHp *= 1 + 0.45 * math.min(1.5, aEff / math.max(bEff, 1e-9))
	end
	if bActive == 5 then
		bHp *= 1 + 0.45 * math.min(1.5, bEff / math.max(aEff, 1e-9))
	end

	local ttkA = bHp / math.max(aEff, 1e-9)
	local ttkB = aHp / math.max(bEff, 1e-9)

	if ttkA ~= ttkB then
		return ttkA < ttkB
	end
	return aHp >= bHp
end

function EconomyConfig.stealsOnWin(tier: number?): boolean
	return tier == 6
end

EconomyConfig.GREED_STEAL_FRACTION = 0.10

EconomyConfig.OFFLINE_CAP_FREE = 4 * 3600
EconomyConfig.OFFLINE_CAP_PASS = 12 * 3600
EconomyConfig.OFFLINE_RATE_FREE = 0.5
EconomyConfig.OFFLINE_RATE_PASS = 1.0

function EconomyConfig.offlineEarnings(wps: number, lastSeen: number, now: number, hasPass: boolean): number
	local cap = if hasPass then EconomyConfig.OFFLINE_CAP_PASS else EconomyConfig.OFFLINE_CAP_FREE
	local rate = if hasPass then EconomyConfig.OFFLINE_RATE_PASS else EconomyConfig.OFFLINE_RATE_FREE
	return wps * math.clamp(now - lastSeen, 0, cap) * rate
end

EconomyConfig.BATTLE_COOLDOWN = 45

EconomyConfig.RANK_REWARD_CAP = 25

EconomyConfig.SHARDS_WIN = 10
EconomyConfig.SHARDS_LOSS = 3
EconomyConfig.SHARDS_GHOST_WIN = 5
EconomyConfig.GHOST_WINS_CAP = 25

EconomyConfig.CRATE_ODDS = { 35, 25, 22, 10, 5, 2, 0.7, 0.25, 0.05 }
EconomyConfig.PITY_COUNT = 40
EconomyConfig.PITY_MIN_TIER = 5

EconomyConfig.CRATE_COST = 100
EconomyConfig.CRATE_BULK_COUNT = 10
EconomyConfig.CRATE_BULK_PRICE = 9

function EconomyConfig.crateCost(count: number): number
	if count == EconomyConfig.CRATE_BULK_COUNT then
		return EconomyConfig.CRATE_COST * EconomyConfig.CRATE_BULK_PRICE
	end
	return EconomyConfig.CRATE_COST * count
end

function EconomyConfig.maxUnlockedTier(rebirths: number): number
	local best = 1
	for tier, required in EconomyConfig.REBIRTH_FOR_COLOR do
		if rebirths >= required and tier > best then
			best = tier
		end
	end
	return best
end

function EconomyConfig.nextColorUnlock(rebirths: number): (number?, number?)
	for tier, required in EconomyConfig.REBIRTH_FOR_COLOR do
		if required > rebirths then
			return tier, required
		end
	end
	return nil, nil
end

function EconomyConfig.rollTier(rng: Random, maxTier: number): number
	maxTier = math.clamp(maxTier, 1, #EconomyConfig.CRATE_ODDS)

	local total = 0
	for tier = 1, maxTier do
		total += EconomyConfig.CRATE_ODDS[tier]
	end

	local roll = rng:NextNumber() * total
	local acc = 0
	for tier = 1, maxTier do
		acc += EconomyConfig.CRATE_ODDS[tier]
		if roll <= acc then
			return tier
		end
	end

	return maxTier
end

EconomyConfig.GAMEPASS_DOUBLE_WILL = 2.0
EconomyConfig.VIP_MULT = 1.5
EconomyConfig.FRIEND_BONUS = 0.15
EconomyConfig.FRIEND_BONUS_CAP = 0.75

export type WPSState = {
	ringLevel: number,
	colorTier: number,
	matchCount: number,
	totalCharge: number,
	hasDoubleWill: boolean,
	hasVIP: boolean,
	friendCount: number,
}

function EconomyConfig.totalWPS(state: WPSState): number
	local tier = EconomyConfig.COLORS[state.colorTier]

	local base = EconomyConfig.ringWPS(state.ringLevel)
	local tierMult = if tier then tier.wpsMult else 1
	local matchMult = EconomyConfig.MATCH_MULT[math.clamp(state.matchCount, 1, 5)]
	local rebirthMult = EconomyConfig.rebirthMultiplier(state.totalCharge)
	local passMult = if state.hasDoubleWill then EconomyConfig.GAMEPASS_DOUBLE_WILL else 1
	local vipMult = if state.hasVIP then EconomyConfig.VIP_MULT else 1
	local friendMult = 1 + math.min(
		state.friendCount * EconomyConfig.FRIEND_BONUS,
		EconomyConfig.FRIEND_BONUS_CAP
	)

	return base * tierMult * matchMult * rebirthMult * passMult * vipMult * friendMult
end

return EconomyConfig
