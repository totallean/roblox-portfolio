--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Shop = require(Shared.Shop)
local Assets = require(Shared.Assets)

local MonetizationService = {}

local Data, Net, Currency

local passCache: { [Player]: { [string]: boolean } } = {}

local passWaiters: { [Player]: { () -> () } } = {}

local EXTRA_SLOTS_TOTAL = 3

local VIP_ATTRIBUTE = "VIP"
local AURA_NAME = "VipAura"
local AURA_COLOR = Color3.fromRGB(255, 196, 72)

local vipWatchers: { [Player]: RBXScriptConnection } = {}

function MonetizationService:HasPass(player: Player, key: string): boolean
	local cache = passCache[player]
	return (cache and cache[key]) == true
end

function MonetizationService:OnPassesLoaded(player: Player, fn: () -> ())
	local queue = passWaiters[player]
	if queue then
		table.insert(queue, fn)
	elseif passCache[player] then
		task.spawn(fn)
	else
		passWaiters[player] = { fn }
	end
end

local function addAura(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild(AURA_NAME) then
		return
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = AURA_NAME
	emitter.Texture = Assets.Particles.Sparkle
	emitter.Color = ColorSequence.new(AURA_COLOR)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 14
	emitter.Speed = NumberRange.new(0.5, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = root
end

local function applyVip(player: Player)
	if not MonetizationService:HasPass(player, "VIP") or vipWatchers[player] then
		return
	end

	player:SetAttribute(VIP_ATTRIBUTE, true)
	if player.Character then
		task.spawn(addAura, player.Character)
	end
	vipWatchers[player] = player.CharacterAdded:Connect(addAura)
end

local function applyPassEffects(player: Player, profile: any)
	if MonetizationService:HasPass(player, "ExtraSlots") and #profile.builds < EXTRA_SLOTS_TOTAL then
		while #profile.builds < EXTRA_SLOTS_TOTAL do
			table.insert(profile.builds, { name = ("Сборка %d"):format(#profile.builds + 1) })
		end
		Net:Sync(player, { builds = profile.builds })
	end

	applyVip(player)
end

local function loadPasses(player: Player)
	local cache = {}

	for key, info in Shop.Passes do
		if not Shop.isConfigured(info) then
			cache[key] = false
			continue
		end

		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.id)
		end)

		if not ok then
			warn(("[Shop] не удалось проверить геймпасс %s: %s"):format(key, tostring(owns)))
			cache[key] = false
		else
			cache[key] = owns == true
		end
	end

	if not player.Parent then
		return
	end

	passCache[player] = cache
	local queued = passWaiters[player]
	passWaiters[player] = nil

	Currency:Invalidate(player)

	local profile = Data:Get(player)
	if profile then
		applyPassEffects(player, profile)
	end

	Net:Sync(player, { passes = cache })

	if queued then
		for _, fn in queued do
			task.spawn(fn)
		end
	end
end

local function grantProduct(player: Player, profile: any, info: any)
	if info.shards then
		Currency:Award(player, "shards", info.shards)
	end

	if info.willHours then
		Currency:Award(player, "will", Currency:GetWPS(player) * 3600 * info.willHours)
	end

	Net:Sync(player, {
		will = profile.will,
		shards = profile.shards,
	})
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = Data:Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseKey = "receipt_" .. tostring(receipt.PurchaseId)

	if profile.purchaseHistory[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key, info = Shop.productByAssetId(receipt.ProductId)
	if not info then
		warn(("[Shop] неизвестный продукт %d"):format(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local onceKey = "once_" .. (key :: string)
	if info.once and profile.purchaseHistory[onceKey] then
		profile.purchaseHistory[purchaseKey] = true
		Data:Save(player)
		Net:Notify(player, "PurchaseResult", { key = key, duplicate = true })
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, err = pcall(grantProduct, player, profile, info)
	if not ok then
		warn(("[Shop] выдача %s упала: %s"):format(tostring(key), tostring(err)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.purchaseHistory[purchaseKey] = true
	if info.once then
		profile.purchaseHistory[onceKey] = true
	end

	if not Data:Save(player) then
		warn("[Shop] покупка выдана, но профиль не сохранён — просим повтор")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Net:Notify(player, "PurchaseResult", { key = key, name = info.name })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:Init()
	Shop.validate()
end

function MonetizationService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")

	Data:ObserveProfiles(loadPasses)

	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
		passWaiters[player] = nil
		local watcher = vipWatchers[player]
		if watcher then
			watcher:Disconnect()
			vipWatchers[player] = nil
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end

		local key = Shop.passByAssetId(passId)
		if not key then
			return
		end

		local cache = passCache[player]
		if cache then
			cache[key] = true
		end

		Currency:Invalidate(player)

		local profile = Data:Get(player)
		if profile then
			applyPassEffects(player, profile)
		end

		Net:Sync(player, { passes = cache, wps = Currency:GetWPS(player) })
		Net:Notify(player, "PurchaseResult", { key = key, name = Shop.Passes[key].name })
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	MonetizationService._processReceipt = processReceipt
	MonetizationService._setPass = function(player: Player, key: string, owns: boolean)
		local cache = passCache[player]
		if cache then
			cache[key] = owns
			Currency:Invalidate(player)
			local profile = Data:Get(player)
			if profile then
				applyPassEffects(player, profile)
			end
			Net:Sync(player, { passes = cache, wps = Currency:GetWPS(player) })
		end
	end
end

return MonetizationService
