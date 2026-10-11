--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local ConstructBuilder = require(Shared.ConstructBuilder)
local Eco = require(Shared.EconomyConfig)

local ArenaController = {}

local State

local QUEUE_LIMIT = 2

local LOSER_SPIN_Y = 21
local LOSER_SPIN_Z = 7.2
local WINNER_RISE = 2.4
local SHRINK_RATE = 1.32

local stage: Folder

local queue: { any } = {}
local playing = false

local function nameTag(parent: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 26)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

local function makeBeam(color: Color3): BasePart
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.3, 0.3, 1)
	beam.Transparency = 1
	beam.Parent = stage
	return beam
end

local function aimBeam(beam: BasePart, from: Vector3, to: Vector3, thickness: number)
	local delta = to - from
	beam.Size = Vector3.new(thickness, thickness, delta.Magnitude)
	beam.CFrame = CFrame.lookAt(from + delta * 0.5, to)
end

local function specColor(spec: string): Color3
	local entry = Eco.COLORS[ConstructBuilder.topTier(spec)]
	return entry and entry.color or Color3.new(1, 1, 1)
end

local function pickArena(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	local best: BasePart?, bestDist = nil, math.huge
	local function consider(arena: Instance?)
		local fa = arena and arena:FindFirstChild("FightAnchor")
		if not fa or not fa:IsA("BasePart") then
			return
		end
		local d = if root then (fa.Position - root.Position).Magnitude else 0
		if d < bestDist then
			best, bestDist = fa, d
		end
	end

	local hub = workspace:FindFirstChild("Hub")
	consider(hub and hub:FindFirstChild("Arena"))

	local islands = workspace:FindFirstChild("Lanterns")
	if islands then
		for _, island in islands:GetChildren() do
			consider(island:FindFirstChild("Arena"))
		end
	end
	return best
end

local playNext: () -> ()

local function play(payload: any)
	local anchor = pickArena()
	if not anchor then
		playNext()
		return
	end
	local arenaLight = anchor:FindFirstChildOfClass("PointLight")

	local base = anchor.Position
	local owner = anchor.Parent
	local radius = (owner and owner:GetAttribute("Radius")) or 13
	local reach = radius - 4

	local a = payload.challenger
	local b = payload.defender

	local modelA = ConstructBuilder.buildFromString(a.spec)
	local modelB = ConstructBuilder.buildFromString(b.spec)
	local rootA, rootB = modelA.PrimaryPart, modelB.PrimaryPart
	if not rootA or not rootB then
		modelA:Destroy()
		modelB:Destroy()
		playNext()
		return
	end

	modelA.Parent = stage
	modelB.Parent = stage

	local colorA, colorB = specColor(a.spec), specColor(b.spec)
	nameTag(rootA, a.name, colorA)
	nameTag(rootB, b.name, colorB)

	local startA = base + Vector3.new(-reach, 0, 0)
	local startB = base + Vector3.new(reach, 0, 0)
	rootA.CFrame = CFrame.new(startA - Vector3.new(0, 6, 0))
	rootB.CFrame = CFrame.new(startB - Vector3.new(0, 6, 0))

	local beamA = makeBeam(colorA)
	local beamB = makeBeam(colorB)

	local ttkA = b.hp / math.max(a.dps, 1e-9)
	local ttkB = a.hp / math.max(b.dps, 1e-9)
	local closeness = math.clamp(math.min(ttkA, ttkB) / math.max(ttkA, ttkB), 0.15, 1)

	local RISE, CLASH = 0.9, 1.6 + 2.2 * closeness
	local FINISH = 1.1
	local total = RISE + CLASH + FINISH

	if arenaLight then
		TweenService:Create(arenaLight, TweenInfo.new(0.4), { Brightness = 4, Range = 46 }):Play()
	end

	local loser = if payload.challengerWon then modelB else modelA
	local loserRoot = if payload.challengerWon then rootB else rootA
	local winnerRoot = if payload.challengerWon then rootA else rootB
	local loserParts: { { part: BasePart, size: Vector3 } } = {}
	for _, p in loser:GetDescendants() do
		if p:IsA("BasePart") and p ~= loserRoot then
			table.insert(loserParts, { part = p, size = p.Size })
		end
	end

	local t0 = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0

		if t < RISE then
			local k = t / RISE
			local ease = 1 - (1 - k) ^ 3
			rootA.CFrame = CFrame.new(startA - Vector3.new(0, 6 * (1 - ease), 0))
				* CFrame.Angles(0, t * 2, 0)
			rootB.CFrame = CFrame.new(startB - Vector3.new(0, 6 * (1 - ease), 0))
				* CFrame.Angles(0, math.pi + t * 2, 0)

		elseif t < RISE + CLASH then
			local k = (t - RISE) / CLASH
			local close = math.sin(k * math.pi) * 0.35
			local posA = startA:Lerp(base, close)
			local posB = startB:Lerp(base, close)

			rootA.CFrame = CFrame.new(posA + Vector3.new(0, math.sin(t * 7) * 0.3, 0))
				* CFrame.Angles(0, t * 2.5, 0)
			rootB.CFrame = CFrame.new(posB + Vector3.new(0, math.sin(t * 7 + 2) * 0.3, 0))
				* CFrame.Angles(0, math.pi + t * 2.5, 0)

			local pulseA = (math.sin(t * 18) + 1) * 0.5
			local pulseB = (math.sin(t * 18 + 1.6) + 1) * 0.5

			local lift = Vector3.new(0, 0.45, 0)
			aimBeam(beamA, posA + lift, posB + lift, 0.25 + pulseA * 0.4)
			aimBeam(beamB, posB - lift, posA - lift, 0.25 + pulseB * 0.4)
			beamA.Transparency = 1 - pulseA * 0.85
			beamB.Transparency = 1 - pulseB * 0.85

		else
			local k = math.clamp((t - RISE - CLASH) / FINISH, 0, 1)
			beamA.Transparency = 1
			beamB.Transparency = 1

			local shrink = math.exp(-SHRINK_RATE * k * k)
			for _, entry in loserParts do
				entry.part.Transparency = k
				entry.part.Size = entry.size * shrink
			end
			loserRoot.CFrame *= CFrame.Angles(0, LOSER_SPIN_Y * dt, LOSER_SPIN_Z * dt)

			winnerRoot.CFrame = CFrame.new(winnerRoot.Position + Vector3.new(0, WINNER_RISE * dt, 0))
				* CFrame.Angles(0, os.clock() * 4, 0)
		end

		if t >= total then
			connection:Disconnect()

			if arenaLight then
				TweenService:Create(arenaLight, TweenInfo.new(0.8), { Brightness = 1.2, Range = 34 }):Play()
			end

			modelA:Destroy()
			modelB:Destroy()
			beamA:Destroy()
			beamB:Destroy()

			playNext()
		end
	end)
end

function playNext()
	local nextOne = table.remove(queue, 1)
	if nextOne then
		task.defer(play, nextOne)
	else
		playing = false
	end
end

local function enqueue(payload: any)
	if playing then
		if #queue >= QUEUE_LIMIT then
			table.remove(queue, 1)
		end
		table.insert(queue, payload)
		return
	end
	playing = true
	play(payload)
end

function ArenaController:Init()
	stage = Instance.new("Folder")
	stage.Name = "ArenaStage"
	stage.Parent = workspace
end

function ArenaController:Start()
	State = self.GetController("StateController")

	State.Notified:Connect(function(kind, payload)
		if kind == "BattleShow" and type(payload) == "table" then
			enqueue(payload)
		end
	end)
end

return ArenaController
