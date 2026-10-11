--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.SpectrumForge.Shared.Net)

local NetService = {}

local handlers: { [string]: (Player, ...any) -> () } = {}

local warnedMissing: { [string]: boolean } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local actionRemote: RemoteEvent
local syncRemote: RemoteEvent
local notifyRemote: RemoteEvent

local function validate(spec: Net.ActionSpec, args: { n: number, [number]: any }): boolean
	if args.n > #spec.args then
		return false
	end

	for i, expected in spec.args do
		local optional = string.sub(expected, -1) == "?"
		local wanted = if optional then string.sub(expected, 1, -2) else expected
		local value = args[i]

		if value == nil then
			if not optional then
				return false
			end
			continue
		end

		if typeof(value) ~= wanted then
			return false
		end

		if wanted == "number" and (value ~= value or math.abs(value) == math.huge) then
			return false
		end

		if wanted == "string" and #value > Net.MAX_STRING_LENGTH then
			return false
		end
	end

	return true
end

local function allow(player: Player, action: string, rate: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		return false
	end

	local bucket = playerBuckets[action]
	local now = os.clock()

	if not bucket then
		bucket = { tokens = rate, last = now }
		playerBuckets[action] = bucket
	end

	bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end

	bucket.tokens -= 1
	return true
end

function NetService:Init()
	local folder = Instance.new("Folder")
	folder.Name = Net.FOLDER

	actionRemote = Instance.new("RemoteEvent")
	actionRemote.Name = Net.ACTION
	actionRemote.Parent = folder

	syncRemote = Instance.new("RemoteEvent")
	syncRemote.Name = Net.SYNC
	syncRemote.Parent = folder

	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = Net.NOTIFY
	notifyRemote.Parent = folder

	folder.Parent = ReplicatedStorage

	Players.PlayerAdded:Connect(function(player)
		buckets[player] = {}
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		buckets[player] = buckets[player] or {}
	end
end

function NetService:Start()
	actionRemote.OnServerEvent:Connect(function(player, action, ...)
		if typeof(action) ~= "string" then
			return
		end

		local spec = Net.Actions[action]
		if not spec then
			return
		end

		if not allow(player, action, spec.rate) then
			return
		end

		local args = table.pack(...)
		if not validate(spec, args) then
			return
		end

		local handler = handlers[action]
		if not handler then
			if not warnedMissing[action] then
				warnedMissing[action] = true
				warn(("[NetService] нет обработчика для %q"):format(action))
			end
			return
		end

		task.spawn(handler, player, table.unpack(args, 1, args.n))
	end)
end

function NetService:On(action: string, handler: (Player, ...any) -> ())
	assert(Net.Actions[action], ("[NetService] %q нет в Net.Actions"):format(action))
	assert(not handlers[action], ("[NetService] %q уже занято"):format(action))
	handlers[action] = handler
end

function NetService:Sync(player: Player, patch: { [string]: any })
	syncRemote:FireClient(player, patch)
end

function NetService:Broadcast(kind: string, payload: any?)
	notifyRemote:FireAllClients(kind, payload)
end

function NetService:Notify(player: Player, kind: string, payload: any?)
	notifyRemote:FireClient(player, kind, payload)
end

return NetService
