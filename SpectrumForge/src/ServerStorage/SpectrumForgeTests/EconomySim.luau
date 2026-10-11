--!strict

local EconomySim = {}

export type Result = {
	rebirthTimes: { number },
	wpsAt: { [number]: number },
	rebirths: number,
	crates: number,
	bestTier: number,
	finalWPS: number,
	totalWill: number,
	battles: number,
}

local function bestSetup(Eco: any, owned: { [number]: { [string]: boolean } }): (number, number)
	local bestTier, bestValue, bestMatch = 1, 0, 0

	for tier, slots in owned do
		local count = 0
		for _ in slots do
			count += 1
		end
		count = math.min(count, 5)

		local value = Eco.COLORS[tier].wpsMult * Eco.MATCH_MULT[math.max(count, 1)]
		if value > bestValue then
			bestTier, bestValue, bestMatch = tier, value, count
		end
	end

	return bestTier, bestMatch
end

function EconomySim.run(Eco: any, options: any?): Result
	local opts = options or {}
	local hours = opts.hours or 24
	local battleEvery = opts.battleEvery or 30
	local winRate = opts.winRate or 0.5
	local rankCap = opts.rankCap or math.huge
	local doubleWill = opts.doubleWill == true

	local rng = Random.new(opts.seed or 20260921)

	local will, shards = 0, 0
	local ringLevel, rebirths, totalCharge = 1, 0, 0
	local arenaRank = 1
	local pity = 0
	local crates, battles = 0, 0
	local totalWill = 0

	local owned: { [number]: { [string]: boolean } } = {
		[1] = { core = true, emitter = true, frame = true, focus = true, sigil = true },
	}

	local result: Result = {
		rebirthTimes = {},
		wpsAt = {},
		rebirths = 0,
		crates = 0,
		bestTier = 1,
		finalWPS = 0,
		totalWill = 0,
		battles = 0,
	}

	local marks = { [3600] = true, [6 * 3600] = true, [12 * 3600] = true, [24 * 3600] = true }
	local seconds = math.floor(hours * 3600)

	for t = 1, seconds do
		local tier, match = bestSetup(Eco, owned)
		local wps = Eco.totalWPS({
			ringLevel = ringLevel,
			colorTier = tier,
			matchCount = match,
			totalCharge = totalCharge,
			hasDoubleWill = doubleWill,
			hasVIP = false,
			friendCount = 0,
		})

		will += wps
		totalWill += wps

		local count = Eco.maxAffordableLevels(will, ringLevel)
		if count > 0 then
			local cost = Eco.ringCostBulk(ringLevel, count)
			if cost > will and count > 1 then
				count -= 1
				cost = Eco.ringCostBulk(ringLevel, count)
			end
			if cost <= will then
				will -= cost
				ringLevel += count
			end
		end

		local required = (Eco.requirementFor and Eco.requirementFor(rebirths + 1, totalCharge))
			or Eco.rebirthRequirement(rebirths + 1)
		if ringLevel >= required then
			totalCharge += Eco.rebirthCharge(rebirths + 1, ringLevel)
			rebirths += 1
			will = 0
			ringLevel = 1
			table.insert(result.rebirthTimes, t)
		end

		if t % battleEvery == 0 then
			battles += 1
			if rng:NextNumber() < winRate then
				shards += Eco.SHARDS_WIN * math.min(arenaRank, rankCap)
				arenaRank += 1
			else
				shards += Eco.SHARDS_LOSS * math.min(arenaRank, rankCap)
				arenaRank = math.max(1, arenaRank - 1)
			end
		end

		local bulkCost = Eco.crateCost(Eco.CRATE_BULK_COUNT)
		while shards >= bulkCost do
			shards -= bulkCost
			local maxTier = Eco.maxUnlockedTier(rebirths)

			for _ = 1, Eco.CRATE_BULK_COUNT do
				crates += 1
				pity += 1

				local dropTier
				if pity >= Eco.PITY_COUNT then
					dropTier = math.min(Eco.PITY_MIN_TIER, maxTier)
					pity = 0
				else
					dropTier = Eco.rollTier(rng, maxTier)
				end

				local slot = Eco.SLOTS[rng:NextInteger(1, #Eco.SLOTS)]
				local bucket = owned[dropTier]
				if not bucket then
					bucket = {}
					owned[dropTier] = bucket
				end
				bucket[slot] = true

				if dropTier > result.bestTier then
					result.bestTier = dropTier
				end
			end
		end

		if marks[t] then
			result.wpsAt[t] = wps
		end
	end

	local tier, match = bestSetup(Eco, owned)
	result.finalWPS = Eco.totalWPS({
		ringLevel = ringLevel,
		colorTier = tier,
		matchCount = match,
		totalCharge = totalCharge,
		hasDoubleWill = doubleWill,
		hasVIP = false,
		friendCount = 0,
	})
	result.rebirths = rebirths
	result.crates = crates
	result.totalWill = totalWill
	result.battles = battles

	return result
end

return EconomySim
