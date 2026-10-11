--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)
local Catalog = require(Shared.PartCatalog)

local CrateService = {}

local Data, Net, Currency, Build

local rng = Random.new()

function CrateService:Init() end

function CrateService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")
	Build = self.GetService("BuildService")

	Net:On("OpenCrate", function(player: Player, count: number)
		if count ~= 1 and count ~= Eco.CRATE_BULK_COUNT then
			return
		end

		local profile = Data:Get(player)
		if not profile then
			return
		end

		local cost = Eco.crateCost(count)
		if not Currency:TrySpend(player, "shards", cost) then
			Net:Notify(player, "Error", {
				reason = "not_enough_shards",
				need = cost,
				have = profile.shards,
			})
			return
		end

		local maxTier = Eco.maxUnlockedTier(profile.rebirths)
		local drops = {}

		for _ = 1, count do
			profile.pityCounter += 1

			local tier
			local forced = false
			if profile.pityCounter >= Eco.PITY_COUNT then
				tier = math.min(Eco.PITY_MIN_TIER, maxTier)
				profile.pityCounter = 0
				forced = true
			else
				tier = Eco.rollTier(rng, maxTier)
			end

			local slot = Eco.SLOTS[rng:NextInteger(1, #Eco.SLOTS)]
			local def = Catalog.randomForSlot(slot, rng)
			local uid = Build:GrantPart(player, def.id, tier)

			table.insert(drops, {
				uid = uid,
				defId = def.id,
				name = def.name,
				slot = slot,
				tier = tier,
				forced = forced,
			})
		end

		Net:Sync(player, {
			parts = profile.parts,
			shards = profile.shards,
			pityCounter = profile.pityCounter,
		})

		Net:Notify(player, "CrateResult", {
			drops = drops,
			pityCounter = profile.pityCounter,
			pityAt = Eco.PITY_COUNT,
		})
	end)
end

return CrateService
