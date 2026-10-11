local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Schema = require(Shared:WaitForChild("Schema"))
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local NetService = require(script.Parent.NetService)

local MonetizationService = {}

local passCache = {}
local boosts = {}
local remotes

MonetizationService.OnSkipRebirth = nil

MonetizationService.PassesChanged = Instance.new("BindableEvent")

local function log(fmt, ...)
	if Config.Debug.Verbose then
		print(("[Monetization] " .. fmt):format(...))
	end
end

local function retry(label: string, fn)
	for attempt = 1, Config.Data.MaxRetries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[Monetization] %s: попытка %d — %s"):format(label, attempt, tostring(result)))
		task.wait(Config.Data.RetryBaseDelay * (2 ^ (attempt - 1)))
	end
	return false, nil
end

function MonetizationService.OwnsPass(player: Player, passKey: string): boolean
	local cache = passCache[player]
	return cache ~= nil and cache[passKey] == true
end

local function refreshPasses(player: Player)
	passCache[player] = passCache[player] or {}
	for key, pass in pairs(Config.Monetization.GamePasses) do
		if pass.Id and pass.Id > 0 then
			local ok, owns = retry("UserOwnsGamePassAsync " .. key, function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			passCache[player][key] = ok and owns == true
		else

			passCache[player][key] = false
		end
	end
end

function MonetizationService.GetOwnedPasses(player: Player)
	local owned = {}
	for key in pairs(Config.Monetization.GamePasses) do
		if MonetizationService.OwnsPass(player, key) then
			owned[key] = true
		end
	end
	return owned
end

function MonetizationService.GrantBoost(player: Player, multiplier: number, duration: number)
	local now = os.time()
	local current = boosts[player]

	local base = (current and current.ExpiresAt > now) and current.ExpiresAt or now
	boosts[player] = { Multiplier = multiplier, ExpiresAt = base + duration }
	CurrencyService.Push(player)
	remotes.Notify:FireClient(player, (Config.Text.BoostActive):format(multiplier), Config.Palette.CyberCyan)
end

function MonetizationService.GetBoostRemaining(player: Player): number
	local boost = boosts[player]
	if not boost then
		return 0
	end
	return math.max(0, boost.ExpiresAt - os.time())
end

local function multiplierProvider(player: Player): number
	local mult = 1
	local pass = Config.Monetization.GamePasses.DoubleButter
	if MonetizationService.OwnsPass(player, "DoubleButter") then
		mult *= (pass.Multiplier or 2)
	end

	for key, other in pairs(Config.Monetization.GamePasses) do
		if key ~= "DoubleButter" and other.Multiplier and MonetizationService.OwnsPass(player, key) then
			mult *= other.Multiplier
		end
	end
	local boost = boosts[player]
	if boost and boost.ExpiresAt > os.time() then
		mult *= boost.Multiplier
	end
	return mult
end

local function grantProduct(player: Player, productKey: string): boolean
	local product = Config.Monetization.Products[productKey]
	if not product then
		return false
	end

	if product.Boost then
		MonetizationService.GrantBoost(player, product.Boost.Multiplier, product.Boost.Duration)
		return true
	end

	if product.Cash then
		local perMinute = CurrencyService.EstimateIncomePerMinute(player)
		local amount = math.max(product.Cash.MinAmount, perMinute * product.Cash.IncomeMinutes)
		CurrencyService.Add(player, amount, "devproduct:" .. productKey)
		remotes.Notify:FireClient(player, (Config.Text.GainPopup):format(Config.FormatNumber(amount), Config.Currency.Icon), Config.Palette.Butter)
		return true
	end

	if product.SkipRebirth then
		if MonetizationService.OnSkipRebirth then
			return MonetizationService.OnSkipRebirth(player) == true
		end
		return false
	end

	return false
end

local function productKeyById(productId: number): string?
	for key, product in pairs(Config.Monetization.Products) do
		if product.Id == productId and product.Id > 0 then
			return key
		end
	end
	return nil
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Receipts = data.Receipts or {}
	if data.Receipts[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = productKeyById(receiptInfo.ProductId)
	if not key then
		warn(("[Monetization] неизвестный ProductId %d — проставь Id в Config.Monetization"):format(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local granted = grantProduct(player, key)
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Receipts[receiptInfo.PurchaseId] = true

	local saved = DataService.SaveAsync(player, false)
	if not saved then
		data.Receipts[receiptInfo.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	log("выдан %s игроку %s", key, player.Name)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function applyCosmetic(character: Model, cosmetic)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	if cosmetic.Highlight then
		local glow = character:FindFirstChild("VipGlow") or Instance.new("Highlight")
		glow.Name = "VipGlow"
		glow.FillColor = cosmetic.Highlight.FillColor
		glow.FillTransparency = cosmetic.Highlight.FillTransparency
		glow.OutlineColor = cosmetic.Highlight.OutlineColor
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = character
	end

	local aura = cosmetic.Aura
	if aura then
		local emitter = root:FindFirstChild("VipAura") or Instance.new("ParticleEmitter")
		emitter.Name = "VipAura"
		emitter.Texture = aura.Texture
		emitter.Rate = aura.Rate
		emitter.Lifetime = NumberRange.new(aura.Lifetime * 0.7, aura.Lifetime)
		emitter.Speed = NumberRange.new(aura.Speed * 0.5, aura.Speed)
		emitter.SpreadAngle = Vector2.new(aura.Spread, aura.Spread)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, aura.Size),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(aura.Transparency)
		emitter.Color = ColorSequence.new(aura.ColorA, aura.ColorB)
		emitter.LightEmission = 0.6
		emitter.Parent = root
	end
end

function MonetizationService.ApplyCosmetics(player: Player, character: Model)
	for key, pass in pairs(Config.Monetization.GamePasses) do
		if pass.Cosmetic and MonetizationService.OwnsPass(player, key) then
			applyCosmetic(character, pass.Cosmetic)
		end
	end
end

function MonetizationService.SendStarterOffer(player: Player)
	local cfg = Config.Monetization.StarterOffer
	if not cfg or not cfg.Enabled then
		return
	end

	task.delay(cfg.DelayOnJoin, function()
		if not player.Parent then
			return
		end

		if cfg.Kind == "pass" and MonetizationService.OwnsPass(player, cfg.Key) then
			return
		end

		local source = (cfg.Kind == "pass")
			and Config.Monetization.GamePasses[cfg.Key]
			or Config.Monetization.Products[cfg.Key]
		if not source then
			warn(("[Monetization] стартовый набор ссылается на несуществующий ключ %s"):format(tostring(cfg.Key)))
			return
		end

		remotes.StarterOffer:FireClient(player, {
			Kind    = cfg.Kind,
			Key     = cfg.Key,
			Title   = cfg.Title or source.Name,
			Name    = source.Name,
			Desc    = source.Desc,
			Icon    = source.Icon,
			Perks   = cfg.Perks,
			Seconds = cfg.Duration,
		})
	end)
end

local function hasAutoCollect(player: Player): boolean
	if MonetizationService.OwnsPass(player, "AutoCollect") then
		return true
	end
	for key, pass in pairs(Config.Monetization.GamePasses) do
		if pass.GrantsAutoCollect and MonetizationService.OwnsPass(player, key) then
			return true
		end
	end
	return false
end

function MonetizationService.HandleExpiredProduct(plot: Model, product: BasePart, sellFn): boolean
	local owner = PlotService.GetOwner(plot)
	if not owner or not hasAutoCollect(owner) then
		return false
	end
	sellFn(plot, product)
	return true
end

function MonetizationService.OnPlayerAdded(player: Player)
	task.spawn(function()
		refreshPasses(player)
		CurrencyService.Push(player)

		MonetizationService.PassesChanged:Fire(player)
		MonetizationService.SendStarterOffer(player)
		if player.Character then
			MonetizationService.ApplyCosmetics(player, player.Character)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		MonetizationService.ApplyCosmetics(player, character)
	end)

end

function MonetizationService.OnPlayerRemoving(player: Player)
	passCache[player] = nil
	boosts[player] = nil
end

function MonetizationService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	CurrencyService.RegisterMultiplierProvider(multiplierProvider)
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		for key, pass in pairs(Config.Monetization.GamePasses) do
			if pass.Id == gamePassId and pass.Id > 0 then
				passCache[player] = passCache[player] or {}
				passCache[player][key] = true

				if pass.GrantCash then
					local data = DataService.Get(player)
					if data then
						data.PassGrants = data.PassGrants or {}
						if not data.PassGrants[key] then
							data.PassGrants[key] = true
							CurrencyService.Add(player, pass.GrantCash, "pass:" .. key, false)
							task.spawn(DataService.SaveAsync, player, false)
						end
					end
				end

				if pass.Cosmetic and player.Character then
					MonetizationService.ApplyCosmetics(player, player.Character)
				end

				CurrencyService.Push(player)
				MonetizationService.PassesChanged:Fire(player)
				remotes.Notify:FireClient(player, (Config.Text.PassActivated):format(pass.Name), Config.Palette.Butter)
			end
		end
	end)

	local knownKeys = {}
	for key in pairs(Config.Monetization.GamePasses) do
		knownKeys[key] = true
	end
	for key in pairs(Config.Monetization.Products) do
		knownKeys[key] = true
	end

	NetService.OnEvent("RequestPurchase", {
		Schema.String{ OneOf = { "pass", "product" } },
		Schema.Key(knownKeys),
	}, function(player, kind, key)
		if kind == "product" then
			local product = Config.Monetization.Products[key]
			if product and product.Id > 0 then
				MarketplaceService:PromptProductPurchase(player, product.Id)
			else
				remotes.Notify:FireClient(player, Config.Text.MissingProductId, Config.Palette.CyberCyan)
			end
		elseif kind == "pass" then
			local pass = Config.Monetization.GamePasses[key]
			if pass and pass.Id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			else
				remotes.Notify:FireClient(player, Config.Text.MissingPassId, Config.Palette.CyberCyan)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MonetizationService.OnPlayerRemoving(player)
	end)
end

return MonetizationService
