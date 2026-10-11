--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)
local Release = require(Shared.Release)
local Locale = require(Shared.Locale)

local CurrencyService = {}

CurrencyService.TICK_INTERVAL = 1
CurrencyService.SYNC_INTERVAL = 3

local Data, Net, Build, Monetization

local wpsCache: { [Player]: number } = {}

local function getPasses(player: Player): (boolean, boolean)
	return Monetization:HasPass(player, "DoubleWill"), Monetization:HasPass(player, "VIP")
end

local friends: { [Player]: { [Player]: boolean } } = {}

local function getFriendCount(player: Player): number
	local set = friends[player]
	if not set then
		return 0
	end
	local count = 0
	for _ in set do
		count += 1
	end
	return count
end

local function linkFriends(joined: Player)
	local mine = friends[joined] or {}
	friends[joined] = mine

	for _, other in Players:GetPlayers() do
		if other == joined then
			continue
		end

		local ok, isFriend = pcall(joined.IsFriendsWith, joined, other.UserId)

		local theirs = friends[other]
		if ok and isFriend and theirs and friends[joined] == mine then
			mine[other] = true
			theirs[joined] = true
			CurrencyService:Invalidate(other)
		end
	end

	CurrencyService:Invalidate(joined)
end

local function unlinkFriends(left: Player)
	local mine = friends[left]
	friends[left] = nil
	if not mine then
		return
	end

	for other in mine do
		local theirs = friends[other]
		if theirs then
			theirs[left] = nil
			CurrencyService:Invalidate(other)
		end
	end
end

function CurrencyService:Invalidate(player: Player)
	wpsCache[player] = nil
end

function CurrencyService:GetWPS(player: Player): number
	local cached = wpsCache[player]
	if cached then
		return cached
	end

	local profile = Data:Get(player)
	if not profile then
		return 0
	end

	local tier, match = Build:GetColor(player)
	local hasDouble, hasVIP = getPasses(player)

	local wps = Eco.totalWPS({
		ringLevel = profile.ringLevel,
		colorTier = tier,
		matchCount = match,
		totalCharge = profile.totalCharge,
		hasDoubleWill = hasDouble,
		hasVIP = hasVIP,
		friendCount = getFriendCount(player),
	})

	wpsCache[player] = wps
	return wps
end

function CurrencyService:Award(player: Player, currency: string, amount: number): boolean
	if amount <= 0 or amount ~= amount or amount == math.huge then
		return false
	end

	local profile = Data:Get(player)
	if not profile then
		return false
	end

	if currency == "will" then
		profile.will += amount
		profile.totalWillEarned += amount
	elseif currency == "shards" then
		profile.shards += amount
	else
		return false
	end

	return true
end

function CurrencyService:TrySpend(player: Player, currency: string, amount: number): boolean
	if amount < 0 or amount ~= amount or amount == math.huge then
		return false
	end

	local profile = Data:Get(player)
	if not profile then
		return false
	end

	if currency == "will" then
		if profile.will < amount then
			return false
		end
		profile.will -= amount
	elseif currency == "shards" then
		if profile.shards < amount then
			return false
		end
		profile.shards -= amount
	else
		return false
	end

	Net:Sync(player, { will = profile.will, shards = profile.shards })
	return true
end

function CurrencyService:ResetWill(player: Player)
	local profile = Data:Get(player)
	if profile then
		profile.will = 0
	end
end

local function grantOffline(player: Player, lastSeen: number)
	local profile = Data:Get(player)
	if not profile then
		return
	end

	local hasPass = Monetization:HasPass(player, "OfflinePlus")
	local now = os.time()
	local elapsed = math.clamp(
		now - lastSeen,
		0,
		if hasPass then Eco.OFFLINE_CAP_PASS else Eco.OFFLINE_CAP_FREE
	)

	local amount = Eco.offlineEarnings(CurrencyService:GetWPS(player), lastSeen, now, hasPass)
	if amount <= 0 then
		return
	end

	CurrencyService:Award(player, "will", amount)
	Net:Sync(player, { will = profile.will })
	Net:Notify(player, "OfflineEarnings", { amount = amount, seconds = elapsed })

	if Release.isDev() then
		print(("[Offline] %s: +%.0f Воли за %d сек"):format(player.Name, amount, elapsed))
	end
end

function CurrencyService:SendFullState(player: Player)
	local profile = Data:Get(player)
	if not profile then
		return
	end

	local tier, match = Build:GetColor(player)
	Net:Sync(player, {
		will = profile.will,
		shards = profile.shards,
		ringLevel = profile.ringLevel,
		rebirths = profile.rebirths,
		totalCharge = profile.totalCharge,
		unlockedColors = profile.unlockedColors,
		parts = profile.parts,
		builds = profile.builds,
		activeBuild = profile.activeBuild,
		pityCounter = profile.pityCounter,
		colorTier = tier,
		matchCount = match,
		arenaRank = profile.arenaRank,
		arenaWins = profile.arenaWins,
		arenaLosses = profile.arenaLosses,
		ghostWinsPending = profile.ghostWinsPending,
		tutorialStep = profile.tutorialStep or 0,
		language = profile.language,
		wps = self:GetWPS(player),
	})
end

function CurrencyService:Init() end

function CurrencyService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Build = self.GetService("BuildService")
	Monetization = self.GetService("MonetizationService")

	Net:On("Ready", function(player)
		self:SendFullState(player)
	end)

	Net:On("SetLanguage", function(player, lang)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		if not Locale.isValid(lang) then
			return
		end

		profile.language = lang
		Net:Sync(player, { language = lang })
	end)

	Net:On("TutorialStep", function(player, step)
		local profile = Data:Get(player)
		if not profile then
			return
		end

		local next = math.floor(step)
		if next <= (profile.tutorialStep or 0) then
			return
		end

		profile.tutorialStep = next
		Net:Sync(player, { tutorialStep = next })
	end)

	Data:ObserveProfiles(function(player, profile)
		local lastSeen = profile.lastSeen
		self:SendFullState(player)
		Monetization:OnPassesLoaded(player, function()
			grantOffline(player, lastSeen)
		end)
	end)

	Players.PlayerAdded:Connect(linkFriends)
	for _, player in Players:GetPlayers() do
		task.spawn(linkFriends, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		wpsCache[player] = nil
		unlinkFriends(player)
	end)

	local accumulated = 0
	local sinceSync = 0

	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < self.TICK_INTERVAL then
			return
		end

		local delta = accumulated
		accumulated = 0

		sinceSync += delta
		local shouldSync = sinceSync >= self.SYNC_INTERVAL
		if shouldSync then
			sinceSync = 0
		end

		for _, player in Players:GetPlayers() do
			local profile = Data:Get(player)
			if not profile then
				continue
			end

			local wps = self:GetWPS(player)
			profile.will += wps * delta
			profile.totalWillEarned += wps * delta

			if shouldSync then
				Net:Sync(player, { will = profile.will, wps = wps })
			end
		end
	end)
end

return CurrencyService
