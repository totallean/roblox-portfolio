--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Release = require(Shared.Release)
local Shop = require(Shared.Shop)

local DebugService = {}

local Data, Net, Currency, Build

function DebugService:Init() end

function DebugService:Start()
	if Release.MODE or not RunService:IsStudio() then
		return
	end

	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")
	Build = self.GetService("BuildService")

	warn("[Debug] отладочные команды включены (только Studio)")

	Net:On("Debug", function(player: Player, what: string, amount: number)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		if what == "shards" then
			profile.shards += amount
		elseif what == "will" then
			profile.will += amount
		elseif what == "ringLevel" then
			profile.ringLevel = math.max(1, math.floor(amount))
		elseif what == "rebirths" then
			profile.rebirths = math.max(0, math.floor(amount))
		elseif what == "pityCounter" then
			profile.pityCounter = math.max(0, math.floor(amount))

		elseif what == "seedGhosts" then
			local Battle = self.GetService("BattleService")
			local snapshot = Build:GetSnapshot(player)
			local base = snapshot and snapshot.power or 1000

			for index = 1, math.floor(amount) do
				local factor = 0.3 + (index / math.max(1, amount)) * 4
				local power = math.floor(base * factor)
				Battle._seed({
					userId = -index,
					name = "Prizrak_" .. index,
					power = power,
					dps = math.sqrt(power) * 1.2,
					hp = math.sqrt(power) * 0.8,
					spec = "core_prism:1|emit_lance:1|frame_plate:1|focus_lens:1|sigil_mark:1",
					rank = index,
					pendingWins = 0,
				})
			end
			return

		elseif string.sub(what, 1, 5) == "pass_" then
			local Mon = self.GetService("MonetizationService")
			Mon._setPass(player, string.sub(what, 6), amount > 0)
			return

		elseif string.sub(what, 1, 7) == "shopid_" then
			local key = string.sub(what, 8)
			if Shop.Products[key] then
				Shop.Products[key].id = math.floor(amount)
			end
			return

		elseif string.sub(what, 1, 8) == "receipt_" then
			local Mon = self.GetService("MonetizationService")
			local key = string.sub(what, 9)
			local info = Shop.Products[key]
			if not info or info.id == 0 then
				return
			end

			local decision = Mon._processReceipt({
				PlayerId = player.UserId,
				PurchaseId = math.floor(amount),
				ProductId = info.id,
				CurrencySpent = info.price,
			})

			Net:Sync(player, {
				debugReceipt = tostring(decision),
				will = profile.will,
				shards = profile.shards,
			})
			return

		elseif what == "ghostWins" then
			local Battle = self.GetService("BattleService")
			for _ = 1, math.floor(amount) do
				Battle._addWinTo(player.UserId)
			end
			return
		else
			return
		end

		Currency:Invalidate(player)
		Build:Invalidate(player)

		local tier, match = Build:GetColor(player)
		Net:Sync(player, {
			will = profile.will,
			shards = profile.shards,
			ringLevel = profile.ringLevel,
			rebirths = profile.rebirths,
			colorTier = tier,
			matchCount = match,
			wps = Currency:GetWPS(player),
		})
	end)
end

return DebugService
