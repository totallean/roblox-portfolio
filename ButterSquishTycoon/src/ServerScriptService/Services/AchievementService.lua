local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Schema = require(Shared:WaitForChild("Schema"))
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local NetService = require(script.Parent.NetService)

local AchievementService = {}

AchievementService.PanelOpened = Instance.new("BindableEvent")

AchievementService.OwnsPass = nil

local remotes
local sweepAccum = 0

local function log(fmt, ...)
	if Config.Debug.Verbose then
		print(("[Achievements] " .. fmt):format(...))
	end
end

local function isMet(player: Player, def, data): boolean
	if def.Claimed then
		return data.HasClaimed == true
	end
	if def.Station then
		return (data.Stations or {})[def.Station] == true
	end
	if def.Rebirths then
		return (data.Rebirths or 0) >= def.Rebirths
	end
	if def.Pass then
		return AchievementService.OwnsPass ~= nil and AchievementService.OwnsPass(player, def.Pass) == true
	end
	if def.AnyPass then
		if not AchievementService.OwnsPass then
			return false
		end
		for key in pairs(Config.Monetization.GamePasses) do
			if AchievementService.OwnsPass(player, key) then
				return true
			end
		end
		return false
	end
	if def.SoldCount then
		return (data.SoldCount or 0) >= def.SoldCount
	end
	if def.TotalEarned then
		return (data.TotalEarned or 0) >= def.TotalEarned
	end
	if def.Collection then

		for _, other in ipairs(Config.Achievements.List) do
			if not other.Collection and not other.ExcludeFromCollection
				and not (data.Achievements or {})[other.Id] then
				return false
			end
		end
		return true
	end
	return false
end

local function grantReward(player: Player, data, def)
	local reward = def.Reward
	if not reward then
		return
	end
	if reward.Cash then

		CurrencyService.Add(player, reward.Cash, "achievement:" .. def.Id, false)
	end
	if reward.Multiplier then
		data.BonusMultiplier = (data.BonusMultiplier or 0) + reward.Multiplier
		CurrencyService.Push(player)
	end
end

function AchievementService.BuildList(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local unlocked = data.Achievements or {}
	local list, done, total = {}, 0, 0

	for _, def in ipairs(Config.Achievements.List) do
		local isUnlocked = unlocked[def.Id] == true

		if not def.Hidden or isUnlocked then
			total += 1
			if isUnlocked then
				done += 1
			end
			table.insert(list, {
				Order = #list + 1,
				Id = def.Id,
				Name = def.Name,
				Desc = def.Desc,
				Unlocked = isUnlocked,
				Premium = def.Premium == true,
				Cash = def.Reward and def.Reward.Cash or nil,
				Multiplier = def.Reward and def.Reward.Multiplier or nil,
			})
		end
	end

	table.sort(list, function(a, b)
		if a.Premium ~= b.Premium then
			return not a.Premium
		end
		return a.Order < b.Order
	end)

	return {
		Items = list,
		Done = done,
		Total = total,
		Bonus = data.BonusMultiplier or 0,
	}
end

function AchievementService.Push(player: Player)
	local payload = AchievementService.BuildList(player)
	if payload then
		remotes.AchievementSync:FireClient(player, payload)
	end
end

function AchievementService.Check(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Achievements = data.Achievements or {}

	local unlockedNow = {}

	for _ = 1, 2 do
		for _, def in ipairs(Config.Achievements.List) do
			if not data.Achievements[def.Id] and isMet(player, def, data) then
				data.Achievements[def.Id] = true
				table.insert(unlockedNow, def)
			end
		end
	end

	if #unlockedNow == 0 then
		return
	end

	for _, def in ipairs(unlockedNow) do
		grantReward(player, data, def)
		remotes.AchievementUnlock:FireClient(player, {
			Name = def.Name,
			Desc = def.Desc,
			Cash = def.Reward and def.Reward.Cash or nil,
			Multiplier = def.Reward and def.Reward.Multiplier or nil,
		})
		log("%s открыл %s", player.Name, def.Id)
	end

	AchievementService.Push(player)

	task.spawn(DataService.SaveAsync, player, false)
end

function AchievementService.MarkClaimed(player: Player)
	local data = DataService.Get(player)
	if data then
		data.HasClaimed = true
	end
	AchievementService.Check(player)
end

function AchievementService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	CurrencyService.RegisterMultiplierProvider(function(player)
		local data = DataService.Get(player)
		return 1 + (data and data.BonusMultiplier or 0)
	end)

	NetService.OnEvent("RequestAchievements", {
		Schema.Optional(Schema.Boolean()),
	}, function(player, openedByUser)
		AchievementService.Push(player)
		if openedByUser == true then
			AchievementService.PanelOpened:Fire(player)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		sweepAccum += dt
		if sweepAccum < Config.Achievements.SweepInterval then
			return
		end
		sweepAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			AchievementService.Check(player)
		end
	end)
end

return AchievementService
