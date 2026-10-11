--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)
local Catalog = require(Shared.PartCatalog)
local Types = require(Shared.Types)
local ConstructBuilder = require(Shared.ConstructBuilder)

local BuildService = {}

local Data, Net, Currency

local colorCache: { [Player]: { tier: number, match: number } } = {}
local snapshotCache: { [Player]: Types.CombatSnapshot } = {}

local grantSeq = 0

local VALID_SLOT: { [string]: boolean } = {}
for _, slot in Eco.SLOTS do
	VALID_SLOT[slot] = true
end

local function activeBuild(profile: Types.Profile): Types.Build?
	return profile.builds[profile.activeBuild]
end

local function equippedPart(profile: Types.Profile, build: Types.Build, slot: string): Types.PartInstance?
	local uid = (build :: any)[slot]
	return if uid then profile.parts[uid] else nil
end

local function computeColor(profile: Types.Profile): (number, number)
	local build = activeBuild(profile)
	if not build then
		return 1, 0
	end

	local counts: { [number]: number } = {}
	for _, slot in Eco.SLOTS do
		local part = equippedPart(profile, build, slot)
		if part then
			counts[part.tier] = (counts[part.tier] or 0) + 1
		end
	end

	local bestTier, bestCount = 1, 0
	for tier, count in counts do
		if count > bestCount or (count == bestCount and tier > bestTier) then
			bestTier, bestCount = tier, count
		end
	end
	return bestTier, bestCount
end

local function computeSnapshot(profile: Types.Profile): Types.CombatSnapshot
	local build = activeBuild(profile)

	local damage, hp, speed = 1, 10, 0.8
	local critPct, critMult = 5, 1.5
	local armor, pierce = 0, 0
	local bonus = 0

	if build then
		local core = equippedPart(profile, build, "core")
		if core then
			local q = Eco.partQuality(core.level, core.tier)
			damage = Eco.coreDamage(q) * Catalog.weight(core.defId, "dmg")
		end

		local frame = equippedPart(profile, build, "frame")
		if frame then
			local q = Eco.partQuality(frame.level, frame.tier)
			hp = Eco.frameHP(q) * Catalog.weight(frame.defId, "hp")
			armor = Eco.frameArmor(q) * Catalog.weight(frame.defId, "armor")
		end

		local emitter = equippedPart(profile, build, "emitter")
		if emitter then
			local q = Eco.partQuality(emitter.level, emitter.tier)
			speed = Eco.emitterSpeed(q) * Catalog.weight(emitter.defId, "spd")
			damage *= Catalog.weight(emitter.defId, "dmg")
		end

		local focus = equippedPart(profile, build, "focus")
		if focus then
			local q = Eco.partQuality(focus.level, focus.tier)
			local c, cm = Eco.focusCrit(q)
			local w = Catalog.weight(focus.defId, "crit")
			critPct, critMult = c * w, cm
			pierce = Eco.focusPierce(q) * Catalog.weight(focus.defId, "pierce")
		end

		local sigil = equippedPart(profile, build, "sigil")
		if sigil then
			bonus = Eco.sigilBonus(sigil.tier)
		end
	end

	local mult = 1 + bonus
	local tier = computeColor(profile)
	local dps = Eco.computeDPS(damage * mult, speed, critPct, critMult)
	local finalHP = hp * mult

	return {
		dps = dps,
		hp = finalHP,
		armor = armor * mult,
		pierce = pierce * mult,
		colorTier = tier,
		power = dps * finalHP,
	}
end

function BuildService:Invalidate(player: Player)
	colorCache[player] = nil
	snapshotCache[player] = nil
	if Currency then
		Currency:Invalidate(player)
	end
end

function BuildService:GetColor(player: Player): (number, number)
	local cached = colorCache[player]
	if cached then
		return cached.tier, cached.match
	end

	local profile = Data:Get(player)
	if not profile then
		return 1, 0
	end

	local tier, match = computeColor(profile)
	colorCache[player] = { tier = tier, match = match }
	return tier, match
end

function BuildService:GetSnapshot(player: Player): Types.CombatSnapshot?
	local cached = snapshotCache[player]
	if cached then
		return cached
	end

	local profile = Data:Get(player)
	if not profile then
		return nil
	end

	local snapshot = computeSnapshot(profile)
	snapshotCache[player] = snapshot
	return snapshot
end

local function newPartUid(profile: Types.Profile, defId: string, tier: number): string
	local uid
	repeat
		grantSeq += 1
		uid = ("%s_%d_%d_%d"):format(defId, tier, os.time(), grantSeq)
	until profile.parts[uid] == nil
	return uid
end

function BuildService:GrantPart(player: Player, defId: string, tier: number): string?
	local profile = Data:Get(player)
	if not profile or not Catalog.ById[defId] then
		return nil
	end

	local uid = newPartUid(profile, defId, tier)
	profile.parts[uid] = { defId = defId, tier = tier, level = 1 }
	return uid
end

local function publishConstruct(player: Player, profile: Types.Profile)
	local build = activeBuild(profile)
	player:SetAttribute("Construct", ConstructBuilder.encode(build, profile.parts))
end

local function pushBuild(player: Player, profile: Types.Profile)
	publishConstruct(player, profile)
	local tier, match = BuildService:GetColor(player)
	Net:Sync(player, {
		builds = profile.builds,
		activeBuild = profile.activeBuild,
		colorTier = tier,
		matchCount = match,
	})
end

function BuildService:Init() end

function BuildService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")

	Net:On("SetBuildSlot", function(player: Player, slot: string, uid: string?)
		if not VALID_SLOT[slot] then
			return
		end

		local profile = Data:Get(player)
		if not profile then
			return
		end

		local build = activeBuild(profile)
		if not build then
			return
		end

		if uid ~= nil then
			local part = profile.parts[uid]
			if not part then
				return
			end
			local def = Catalog.ById[part.defId]
			if not def or def.slot ~= slot then
				return
			end
		end

		(build :: any)[slot] = uid
		self:Invalidate(player)
		pushBuild(player, profile)
	end)

	Net:On("SelectBuild", function(player: Player, index: number)
		local profile = Data:Get(player)
		if not profile then
			return
		end
		if index ~= math.floor(index) or not profile.builds[index] then
			return
		end

		profile.activeBuild = index
		self:Invalidate(player)
		pushBuild(player, profile)
	end)

	Net:On("UpgradePart", function(player: Player, uid: string)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		local part = profile.parts[uid]
		if not part then
			return
		end

		local cost = Eco.partUpgradeCost(part.level, part.tier)
		if not Currency:TrySpend(player, "shards", cost) then
			return
		end

		part.level += 1
		self:Invalidate(player)
		Net:Sync(player, { parts = profile.parts })
	end)

	Data:ObserveProfiles(publishConstruct)

	Players.PlayerRemoving:Connect(function(player)
		colorCache[player] = nil
		snapshotCache[player] = nil
	end)
end

return BuildService
