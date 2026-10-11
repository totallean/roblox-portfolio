local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local NetService = require(script.Parent.NetService)

local SocialService = {}

local INT_MAX = 2147483647

local function ensureLeaderstats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local butter = stats:FindFirstChild(Config.Leaderboard.StatName)
	if not butter then
		butter = Instance.new("IntValue")
		butter.Name = Config.Leaderboard.StatName
		butter.Parent = stats
	end

	local rebirths = stats:FindFirstChild(Config.Leaderboard.RebirthStat)
	if not rebirths then
		rebirths = Instance.new("IntValue")
		rebirths.Name = Config.Leaderboard.RebirthStat
		rebirths.Parent = stats
	end

	return butter, rebirths
end

function SocialService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local butter, rebirths = ensureLeaderstats(player)
	butter.Value = math.clamp(math.floor(data.Currency or 0), 0, INT_MAX)
	rebirths.Value = math.clamp(math.floor(data.Rebirths or 0), 0, INT_MAX)
end

function SocialService.AnnounceJoin(player: Player)
	NetService.Broadcast((Config.Text.FeedJoined):format(player.DisplayName), Config.Palette.CyberCyan)
end

function SocialService.AnnounceLeave(player: Player)
	NetService.Broadcast((Config.Text.FeedLeft):format(player.DisplayName), Config.Palette.SteelLight)
end

function SocialService.AnnounceRebirth(player: Player, count: number)
	NetService.Broadcast((Config.Text.FeedRebirth):format(player.DisplayName, count), Config.Palette.Grape)
end

function SocialService.AnnounceStation(player: Player, def)
	if (def.Price or 0) < Config.Feed.MinStationPrice then
		return
	end
	NetService.Broadcast((Config.Text.FeedStation):format(player.DisplayName, def.Label), Config.Palette.Butter)
end

function SocialService.BuildLeaderboard()
	local rows = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(other)
		if data then
			table.insert(rows, {
				UserId   = other.UserId,
				Name     = other.DisplayName,
				Currency = data.Currency or 0,
				Rebirths = data.Rebirths or 0,
			})
		end
	end

	table.sort(rows, function(a, b)
		if a.Rebirths ~= b.Rebirths then
			return a.Rebirths > b.Rebirths
		end
		return a.Currency > b.Currency
	end)

	while #rows > Config.Leaderboard.MaxRows do
		table.remove(rows)
	end
	return { Ok = true, Rows = rows }
end

function SocialService.Init()

	DataService.ProfileLoaded.Event:Connect(function(player)
		SocialService.Sync(player)
	end)

	CurrencyService.Changed.Event:Connect(function(player)
		SocialService.Sync(player)
	end)

	NetService.OnFunction("GetLeaderboard", {}, function()
		return SocialService.BuildLeaderboard()
	end)
end

return SocialService
