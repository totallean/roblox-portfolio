local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WebSwing"):WaitForChild("Config"))
local Net = require(script.Parent:WaitForChild("Net"))

type Bucket = { tokens: number, updated: number }

local buckets: { [Player]: Bucket } = {}
local attached: { [Player]: boolean } = {}

-- Token bucket: a client may send RemoteRateLimit messages per second on average, with a small burst.
local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = Config.RemoteRateLimit, updated = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(Config.RemoteRateLimit, bucket.tokens + (now - bucket.updated) * Config.RemoteRateLimit)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function isFinite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function broadcast(sender: Player, ...: any)
	for _, other in Players:GetPlayers() do
		if other ~= sender then
			Net.Web:FireClient(other, ...)
		end
	end
end

Net.Web.OnServerEvent:Connect(function(player: Player, action: unknown, target: unknown)
	if not allow(player) then
		return
	end
	if action == "Attach" then
		if typeof(target) ~= "Vector3" or not isFinite(target) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		if (root.Position - target).Magnitude > Config.MaxWebDistance + Config.RemoteRangeSlack then
			return
		end
		attached[player] = true
		broadcast(player, "Attach", player, target)
	elseif action == "Release" then
		if attached[player] then
			attached[player] = nil
			broadcast(player, "Release", player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	if attached[player] then
		attached[player] = nil
		broadcast(player, "Release", player)
	end
end)
