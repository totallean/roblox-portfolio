--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)

local BattleService = {}

BattleService.POOL_NAME = "SpectrumForge_Ghosts_v1"
BattleService.GHOST_TTL = 7 * 24 * 3600
BattleService.PUBLISH_INTERVAL = 45

BattleService.BAND = 2.5

local Data, Net, Currency, Build, Monetization

local lastBattle: { [Player]: number } = {}
local rng = Random.new()

local CLAIM_DELAY = 1

local AUTO_BATTLE_CHECK = 5

export type Ghost = {
	userId: number,
	name: string,
	power: number,
	dps: number,
	hp: number,
	armor: number?,
	pierce: number?,
	tier: number?,
	spec: string,
	rank: number,
	pendingWins: number,
}

local sortedMap = nil
local memoryPool: { [number]: Ghost } = {}

local function probePool()
	local ok, map = pcall(function()
		local m = MemoryStoreService:GetSortedMap(BattleService.POOL_NAME)
		m:GetRangeAsync(Enum.SortDirection.Descending, 1)
		return m
	end)

	if ok then
		return map
	end

	warn("[Battle] MemoryStore недоступен, пул Призраков живёт в памяти этого сервера.")
	return nil
end

local Pool = {}

function Pool.put(ghost: Ghost)
	if not sortedMap then
		memoryPool[ghost.userId] = ghost
		return
	end

	pcall(function()
		sortedMap:SetAsync(tostring(ghost.userId), ghost, BattleService.GHOST_TTL, ghost.power)
	end)
end

function Pool.sample(power: number, excludeUserId: number): { Ghost }
	local candidates: { Ghost } = {}

	if not sortedMap then
		for userId, ghost in memoryPool do
			if userId ~= excludeUserId then
				table.insert(candidates, ghost)
			end
		end
	else
		local ok, items = pcall(function()
			return sortedMap:GetRangeAsync(Enum.SortDirection.Descending, 100)
		end)
		if ok and items then
			for _, item in items do
				local ghost = item.value
				if type(ghost) == "table" and ghost.userId ~= excludeUserId then
					table.insert(candidates, ghost)
				end
			end
		end
	end

	local band = BattleService.BAND
	local near: { Ghost } = {}
	for _, ghost in candidates do
		if ghost.power <= power * band and ghost.power >= power / band then
			table.insert(near, ghost)
		end
	end

	return if #near > 0 then near else candidates
end

function Pool.addWin(userId: number)
	if not sortedMap then
		local ghost = memoryPool[userId]
		if ghost then
			ghost.pendingWins += 1
		end
		return
	end

	pcall(function()
		sortedMap:UpdateAsync(tostring(userId), function(ghost)
			if type(ghost) ~= "table" then
				return nil
			end
			ghost.pendingWins = (ghost.pendingWins or 0) + 1
			return ghost
		end, BattleService.GHOST_TTL)
	end)
end

function Pool.takeWins(userId: number): number
	if not sortedMap then
		local ghost = memoryPool[userId]
		if not ghost then
			return 0
		end
		local wins = ghost.pendingWins
		ghost.pendingWins = 0
		return wins
	end

	local claimed = 0
	local ok = pcall(function()
		sortedMap:UpdateAsync(tostring(userId), function(ghost)
			if type(ghost) ~= "table" then
				return nil
			end
			claimed = ghost.pendingWins or 0
			ghost.pendingWins = 0
			return ghost
		end, BattleService.GHOST_TTL)
	end)

	return if ok then claimed else 0
end

function Pool.top(count: number): { Ghost }
	local ghosts: { Ghost } = {}

	if sortedMap then
		local ok, items = pcall(function()
			return sortedMap:GetRangeAsync(Enum.SortDirection.Descending, count)
		end)
		if ok and items then
			for _, item in items do
				if type(item.value) == "table" then
					table.insert(ghosts, item.value)
				end
			end
		end
		return ghosts
	end

	for _, ghost in memoryPool do
		table.insert(ghosts, ghost)
	end
	table.sort(ghosts, function(a, b)
		return a.power > b.power
	end)
	for index = #ghosts, count + 1, -1 do
		ghosts[index] = nil
	end
	return ghosts
end

local function publish(player: Player)
	local profile = Data:Get(player)
	local snapshot = Build:GetSnapshot(player)
	if not profile or not snapshot then
		return
	end

	Pool.put({
		userId = player.UserId,
		name = player.DisplayName,
		power = math.floor(snapshot.power),
		dps = snapshot.dps,
		hp = snapshot.hp,
		armor = snapshot.armor,
		pierce = snapshot.pierce,
		tier = snapshot.colorTier,
		spec = player:GetAttribute("Construct") or "",
		rank = profile.arenaRank,
		pendingWins = 0,
	})
end

function BattleService:PublishGhost(player: Player)
	publish(player)
end

local function challenge(player: Player, auto: boolean)
	local profile = Data:Get(player)
	local snapshot = Build:GetSnapshot(player)
	if not profile or not snapshot then
		return
	end

	local now = os.clock()
	local ready = (lastBattle[player] or 0) + Eco.BATTLE_COOLDOWN
	if now < ready then
		if not auto then
			Net:Notify(player, "Error", {
				reason = "battle_cooldown",
				secondsLeft = math.ceil(ready - now),
			})
		end
		return
	end

	local previous = lastBattle[player]
	lastBattle[player] = now

	local pool = Pool.sample(snapshot.power, player.UserId)
	if #pool == 0 then
		lastBattle[player] = previous
		if not auto then
			Net:Notify(player, "Error", { reason = "no_opponent" })
		end
		return
	end

	local opponent = pool[rng:NextInteger(1, #pool)]
	local won = Eco.resolveBattle({
		dps = snapshot.dps,
		hp = snapshot.hp,
		armor = snapshot.armor,
		pierce = snapshot.pierce,
		tier = snapshot.colorTier,
	}, {
		dps = opponent.dps,
		hp = opponent.hp,
		armor = opponent.armor,
		pierce = opponent.pierce,
		tier = opponent.tier,
	})

	local reward
	if won then
		reward = Eco.SHARDS_WIN * math.min(profile.arenaRank, Eco.RANK_REWARD_CAP)
		if Eco.stealsOnWin(snapshot.colorTier) then
			reward += math.max(1, math.floor(reward * Eco.GREED_STEAL_FRACTION))
		end
		profile.arenaWins += 1
		profile.arenaRank += 1
	else
		reward = Eco.SHARDS_LOSS * math.min(profile.arenaRank, Eco.RANK_REWARD_CAP)
		profile.arenaLosses += 1
		profile.arenaRank = math.max(1, profile.arenaRank - 1)

		task.spawn(Pool.addWin, opponent.userId)
	end

	Currency:Award(player, "shards", reward)

	Net:Sync(player, {
		shards = profile.shards,
		arenaRank = profile.arenaRank,
		arenaWins = profile.arenaWins,
		arenaLosses = profile.arenaLosses,
	})

	Net:Broadcast("BattleShow", {
		challenger = {
			name = player.DisplayName,
			spec = player:GetAttribute("Construct") or "",
			dps = snapshot.dps,
			hp = snapshot.hp,
		},
		defender = {
			name = opponent.name,
			spec = opponent.spec or "",
			dps = opponent.dps,
			hp = opponent.hp,
		},
		challengerWon = won,
	})

	Net:Notify(player, "BattleResult", {
		won = won,
		reward = reward,
		rank = profile.arenaRank,
		opponent = {
			name = opponent.name,
			power = opponent.power,
			spec = opponent.spec,
			dps = opponent.dps,
			hp = opponent.hp,
		},
		self = { power = math.floor(snapshot.power), dps = snapshot.dps, hp = snapshot.hp },
	})

	task.spawn(publish, player)
end

local function claimPending(player: Player)
	local profile = Data:Get(player)
	if not profile then
		return
	end

	local claimed = math.min(Pool.takeWins(player.UserId), Eco.GHOST_WINS_CAP)
	if claimed <= 0 then
		return
	end

	local reward = claimed * Eco.SHARDS_GHOST_WIN
	Currency:Award(player, "shards", reward)
	profile.ghostWinsPending = 0

	Net:Sync(player, { shards = profile.shards, ghostWinsPending = 0 })
	Net:Notify(player, "GhostWins", { wins = claimed, reward = reward })
end

BattleService.LEADERBOARD_SIZE = 10
BattleService.LEADERBOARD_INTERVAL = 30

local function broadcastTop()
	local top = BattleService:GetTop(BattleService.LEADERBOARD_SIZE)

	local rows = {}
	for place, ghost in top do
		table.insert(rows, {
			place = place,
			name = ghost.name,
			power = ghost.power,
			rank = ghost.rank,
			spec = ghost.spec,
		})
	end

	Net:Broadcast("Leaderboard", { rows = rows })
end

function BattleService:Init()
	sortedMap = probePool()
end

function BattleService:Start()
	Data = self.GetService("DataService")
	Net = self.GetService("NetService")
	Currency = self.GetService("CurrencyService")
	Build = self.GetService("BuildService")
	Monetization = self.GetService("MonetizationService")

	Net:On("ChallengeGhost", function(player: Player)
		challenge(player, false)
	end)
	Net:On("ClaimGhostWins", claimPending)

	Data:ObserveProfiles(function(player)
		publish(player)
		task.wait(CLAIM_DELAY)
		claimPending(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastBattle[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTO_BATTLE_CHECK)
			for _, player in Players:GetPlayers() do
				if Data:Get(player) and Monetization:HasPass(player, "AutoBattle") then
					task.spawn(challenge, player, true)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(BattleService.LEADERBOARD_INTERVAL)
			local ok, err = pcall(broadcastTop)
			if not ok then
				warn("[Battle] рассылка топа упала: " .. tostring(err))
			end
		end
	end)

	task.defer(function()
		pcall(broadcastTop)
	end)

	task.spawn(function()
		while true do
			task.wait(BattleService.PUBLISH_INTERVAL)
			for _, player in Players:GetPlayers() do
				if Data:Get(player) then
					publish(player)
				end
			end
		end
	end)
end

function BattleService:GetTop(count: number): { Ghost }
	return Pool.top(count)
end

function BattleService._clearCooldown(player: Player)
	lastBattle[player] = nil
end

function BattleService._injectPool(fake: any)
	sortedMap = fake
end

function BattleService._seed(ghost: Ghost)
	Pool.put(ghost)
end

function BattleService._addWinTo(userId: number)
	Pool.addWin(userId)
end

function BattleService._poolSize(): number
	local n = 0
	for _ in memoryPool do
		n += 1
	end
	return n
end

return BattleService
