--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)

local RebirthService = {}

local Data, Net, Currency, Build

function RebirthService:Init() end

function RebirthService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")
	Build = self.GetService("BuildService")

	Net:On("Rebirth", function(player: Player)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		local nextRebirth = profile.rebirths + 1
		local required = Eco.rebirthRequirement(nextRebirth)

		if profile.ringLevel < required then
			Net:Notify(player, "Error", {
				reason = "rebirth_locked",
				need = required,
				have = profile.ringLevel,
			})
			return
		end

		local charge = Eco.rebirthCharge(nextRebirth, profile.ringLevel)

		profile.rebirths = nextRebirth
		profile.totalCharge += charge
		profile.ringLevel = 1
		Currency:ResetWill(player)

		local unlocked = {}
		for tier, threshold in Eco.REBIRTH_FOR_COLOR do
			if nextRebirth >= threshold and not table.find(profile.unlockedColors, tier) then
				table.insert(profile.unlockedColors, tier)
				table.insert(unlocked, tier)
			end
		end

		Currency:Invalidate(player)
		Build:Invalidate(player)

		local tier, match = Build:GetColor(player)
		Net:Sync(player, {
			will = profile.will,
			ringLevel = profile.ringLevel,
			rebirths = profile.rebirths,
			totalCharge = profile.totalCharge,
			unlockedColors = profile.unlockedColors,
			colorTier = tier,
			matchCount = match,
			wps = Currency:GetWPS(player),
		})

		Net:Notify(player, "RebirthResult", {
			rebirths = nextRebirth,
			charge = charge,
			multiplier = Eco.rebirthMultiplier(profile.totalCharge),
			unlockedColors = unlocked,
			nextRequirement = Eco.rebirthRequirement(nextRebirth + 1),
		})

		task.spawn(function()
			Data:Save(player)
		end)
	end)
end

return RebirthService
