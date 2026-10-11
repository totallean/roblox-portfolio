--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConstructBuilder = require(ReplicatedStorage.SpectrumForge.Shared.ConstructBuilder)

local ConstructController = {}

local HEIGHT = 4.2
local SPIN = 0.6
local BOB = 0.18

type Entry = { model: Model, root: BasePart, spec: string, phase: number }

local shown: { [Player]: Entry } = {}
local watchers: { [Player]: RBXScriptConnection } = {}
local folder: Folder

local function clear(player: Player)
	local entry = shown[player]
	if entry then
		entry.model:Destroy()
		shown[player] = nil
	end
end

local function rebuild(player: Player)
	local spec = player:GetAttribute("Construct")
	if type(spec) ~= "string" or spec == "" then
		clear(player)
		return
	end

	local existing = shown[player]
	if existing and existing.spec == spec then
		return
	end

	clear(player)

	local model = ConstructBuilder.buildFromString(spec)
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end

	model.Parent = folder
	shown[player] = {
		model = model,
		root = root,
		spec = spec,
		phase = math.random() * math.pi * 2,
	}
end

local function track(player: Player)
	if watchers[player] then
		return
	end
	rebuild(player)
	watchers[player] = player:GetAttributeChangedSignal("Construct"):Connect(function()
		rebuild(player)
	end)
end

local function untrack(player: Player)
	local connection = watchers[player]
	if connection then
		connection:Disconnect()
		watchers[player] = nil
	end
	clear(player)
end

function ConstructController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Constructs"
	folder.Parent = workspace
end

function ConstructController:Start()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()

		for player, entry in shown do
			local character = player.Character
			local head = character and character:FindFirstChild("Head") :: BasePart?

			local parent = if head then folder else nil
			if entry.model.Parent ~= parent then
				entry.model.Parent = parent
			end
			if not head then
				continue
			end

			local bob = math.sin(now * 1.4 + entry.phase) * BOB
			entry.root.CFrame = CFrame.new(head.Position + Vector3.new(0, HEIGHT + bob, 0))
				* CFrame.Angles(0, now * SPIN + entry.phase, 0)
		end
	end)
end

return ConstructController
