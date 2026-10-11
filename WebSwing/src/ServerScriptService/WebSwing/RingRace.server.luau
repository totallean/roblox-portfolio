local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("WebSwing")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local Net = require(script.Parent:WaitForChild("Net"))

type Ring = { core: BasePart, radius: number }
type RaceState = { nextRing: number, startedAt: number?, lastPosition: Vector3? }

local arena = Workspace:WaitForChild("WebSwingArena")
local rings: { Ring } = {}
for _, model in arena:WaitForChild("RaceRings"):GetChildren() do
	local core = model:FindFirstChild("Core")
	if model:IsA("Model") and core and core:IsA("BasePart") then
		rings[model:GetAttribute("Index") :: number] = { core = core, radius = model:GetAttribute("Radius") :: number }
	end
end

local states: { [Player]: RaceState } = {}
local sessionBest: { [number]: { name: string, time: number } } = {}

local store: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("WebSwingRace_v1")
	end)
	if ok then
		store = result
	end
end

local function toMs(seconds: number): number
	return math.floor(seconds * 1000 + 0.5)
end

-- Segment-vs-disc test in the ring's local space, so fast swings (several studs per frame)
-- still register even if no single sampled position lands inside the ring.
local function crossed(ring: Ring, from: Vector3, to: Vector3): boolean
	local a = ring.core.CFrame:PointToObjectSpace(from)
	local b = ring.core.CFrame:PointToObjectSpace(to)
	if (a.Z > 0) == (b.Z > 0) then
		return math.abs(b.Z) < 2 and Vector2.new(b.X, b.Y).Magnitude < ring.radius
	end
	local t = a.Z / (a.Z - b.Z)
	local hit = a:Lerp(b, t)
	return Vector2.new(hit.X, hit.Y).Magnitude < ring.radius
end

local function bestValue(player: Player): StringValue?
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Best")
	if value and value:IsA("StringValue") then
		return value
	end
	return nil
end

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = if ok then name else ("#" .. userId)
	nameCache[userId] = resolved
	return resolved
end

local board = arena:FindFirstChild("Leaderboard")
local rows: { TextLabel } = {}
local emptyLabel: TextLabel? = nil

local function buildBoard()
	if not board or not board:IsA("BasePart") then
		return
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Text = Locale.get("leaderboardTitle", "en") .. "  •  " .. Locale.get("leaderboardTitle", "ru")
	title.Parent = surface

	for i = 1, Config.RaceLeaderboardSize do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.04, 0, 0.17 + (i - 1) * 0.082, 0)
		row.Size = UDim2.new(0.92, 0, 0.075, 0)
		row.BackgroundTransparency = 1
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 214, 64) else Color3.new(1, 1, 1)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = surface
		rows[i] = row
	end

	local empty = Instance.new("TextLabel")
	empty.Position = UDim2.fromScale(0, 0.45)
	empty.Size = UDim2.fromScale(1, 0.1)
	empty.BackgroundTransparency = 1
	empty.TextColor3 = Color3.fromRGB(180, 180, 200)
	empty.Font = Enum.Font.Gotham
	empty.TextScaled = true
	empty.Text = Locale.get("leaderboardEmpty", "en")
	empty.Parent = surface
	emptyLabel = empty
end

local function render(entries: { { name: string, time: number } })
	for i, row in rows do
		local entry = entries[i]
		row.Text = if entry then string.format("%d.  %s   %s", i, entry.name, Locale.formatTime(entry.time)) else ""
	end
	if emptyLabel then
		emptyLabel.Visible = #entries == 0
	end
end

local function sessionEntries(): { { name: string, time: number } }
	local list = {}
	for _, entry in sessionBest do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.time < b.time
	end)
	return list
end

local function refreshBoard()
	if store then
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(true, Config.RaceLeaderboardSize)
		end)
		if ok then
			local entries = {}
			for _, item in pages:GetCurrentPage() do
				table.insert(entries, { name = nameOf(tonumber(item.key) :: number), time = item.value / 1000 })
			end
			if #entries > 0 then
				render(entries)
				return
			end
		end
	end
	render(sessionEntries())
end

local function saveBest(player: Player, seconds: number)
	if not store then
		return
	end
	local ms = toMs(seconds)
	task.spawn(function()
		pcall(function()
			(store :: OrderedDataStore):UpdateAsync(tostring(player.UserId), function(old: number?)
				if old and old <= ms then
					return nil
				end
				return ms
			end)
		end)
		refreshBoard()
	end)
end

local function loadBest(player: Player)
	if not store then
		return
	end
	local ok, ms = pcall(function()
		return (store :: OrderedDataStore):GetAsync(tostring(player.UserId))
	end)
	if ok and typeof(ms) == "number" then
		local seconds = ms / 1000
		local current = sessionBest[player.UserId]
		if not current or seconds < current.time then
			sessionBest[player.UserId] = { name = player.Name, time = seconds }
			local value = bestValue(player)
			if value then
				value.Value = Locale.formatTime(seconds)
			end
		end
	end
end

local function reset(player: Player, state: RaceState, notify: boolean)
	state.nextRing = 1
	state.startedAt = nil
	if notify then
		Net.Race:FireClient(player, "Reset")
	end
end

local function finish(player: Player, state: RaceState)
	local elapsed = Workspace:GetServerTimeNow() - (state.startedAt :: number)
	local previous = sessionBest[player.UserId]
	local isBest = previous == nil or elapsed < previous.time
	if isBest then
		sessionBest[player.UserId] = { name = player.Name, time = elapsed }
		local value = bestValue(player)
		if value then
			value.Value = Locale.formatTime(elapsed)
		end
		saveBest(player, elapsed)
		if not store then
			refreshBoard()
		end
	end
	reset(player, state, false)
	Net.Race:FireClient(player, "Finished", elapsed, sessionBest[player.UserId].time, isBest)
end

local function onPassed(player: Player, state: RaceState)
	if state.nextRing == 1 then
		state.startedAt = Workspace:GetServerTimeNow()
	end
	state.nextRing += 1
	if state.nextRing > #rings then
		finish(player, state)
	else
		Net.Race:FireClient(player, "Progress", state.nextRing, state.startedAt)
	end
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Value = "—"
	best.Parent = stats
	stats.Parent = player

	local state: RaceState = { nextRing = 1, startedAt = nil, lastPosition = nil }
	states[player] = state
	player.CharacterAdded:Connect(function()
		state.lastPosition = nil
		if state.startedAt then
			reset(player, state, true)
		end
	end)
	task.spawn(loadBest, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for player, state in states do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		local position = root.Position
		local last = state.lastPosition
		state.lastPosition = position
		if not last or (position - last).Magnitude > 120 then
			continue
		end
		if state.startedAt and now - state.startedAt > Config.RaceTimeout then
			reset(player, state, true)
			continue
		end
		local ring = rings[state.nextRing]
		if ring and crossed(ring, last, position) then
			onPassed(player, state)
		end
	end
end)

buildBoard()
refreshBoard()
task.spawn(function()
	while true do
		task.wait(Config.RaceLeaderboardRefresh)
		refreshBoard()
	end
end)
