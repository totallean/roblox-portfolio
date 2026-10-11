--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)

local RingService = {}

local Data, Net, Currency

function RingService:Init() end

function RingService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")

	Net:On("Tap", function(player: Player)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		local amount = math.max(1, Currency:GetWPS(player) * Eco.TAP_WPS_FRACTION)
		Currency:Award(player, "will", amount)
	end)

	Net:On("BuyRing", function(player: Player, requested: number)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		if requested ~= math.floor(requested) or requested < 0 then
			return
		end

		local count = if requested == 0
			then Eco.maxAffordableLevels(profile.will, profile.ringLevel)
			else math.min(requested, Eco.RING_MAX_BULK)

		if count <= 0 then
			return
		end

		local cost = Eco.ringCostBulk(profile.ringLevel, count)

		if cost > profile.will and count > 1 then
			count -= 1
			cost = Eco.ringCostBulk(profile.ringLevel, count)
		end

		if not Currency:TrySpend(player, "will", cost) then
			return
		end

		profile.ringLevel += count
		Currency:Invalidate(player)

		Net:Sync(player, {
			ringLevel = profile.ringLevel,
			will = profile.will,
			wps = Currency:GetWPS(player),
		})
	end)
end

return RingService
