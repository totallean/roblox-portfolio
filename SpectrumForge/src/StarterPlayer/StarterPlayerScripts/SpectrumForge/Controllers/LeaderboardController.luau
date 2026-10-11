--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local ConstructBuilder = require(Shared.ConstructBuilder)
local Format = require(Shared.Format)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)

local LeaderboardController = {}

local State, Locale

local listFrame: Frame?
local anchors: { [number]: BasePart } = {}
local shown: { [number]: { model: Model, spec: string, phase: number } } = {}
local rowPool: { TextLabel } = {}

local lastRows: { any } = {}

local function makeRow(index: number): TextLabel
	local existing = rowPool[index]
	if existing then
		return existing
	end

	local row = Instance.new("TextLabel")
	row.Name = "Row" .. index
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.GothamBold
	row.TextSize = 24
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = Color3.fromRGB(230, 236, 248)
	row.Text = ""
	row.Parent = listFrame
	rowPool[index] = row
	return row
end

local function renderList(rows: { any })
	if not listFrame then
		return
	end

	for index = 1, math.max(#rows, #rowPool) do
		local row = makeRow(index)
		local data = rows[index]

		if not data then
			row.Text = ""
			row.Visible = false
			continue
		end

		row.Visible = true
		row.TextColor3 = if index <= 3
			then Theme.spectrum(ConstructBuilder.topTier(data.spec))
			else Color3.fromRGB(168, 178, 202)
		row.Text = Locale:Get("world.boardRow", data.place, data.name, Format.short(data.power), data.rank)
	end
end

local function renderPodium(rows: { any })
	for place = 1, 3 do
		local anchor = anchors[place]
		local data = rows[place]
		if not anchor then
			continue
		end

		if not data or data.spec == "" then
			local old = shown[place]
			if old then
				old.model:Destroy()
				shown[place] = nil
			end
			continue
		end

		local current = shown[place]
		if current and current.spec == data.spec then
			continue
		end

		if current then
			current.model:Destroy()
		end

		local model = ConstructBuilder.buildFromString(data.spec)
		if not model.PrimaryPart then
			model:Destroy()
			continue
		end
		model.Parent = anchor

		shown[place] = {
			model = model,
			spec = data.spec,
			phase = place * 1.7,
		}
	end
end

local function render()
	renderList(lastRows)
	renderPodium(lastRows)
end

local function attachBoard()
	local hub = workspace:WaitForChild("Hub", math.huge)
	local board = hub:WaitForChild("Leaderboard", math.huge)
	local screen = board:WaitForChild("Panel", math.huge):WaitForChild("Screen", math.huge)
	listFrame = screen:WaitForChild("Root", math.huge):WaitForChild("List", math.huge) :: Frame

	for place = 1, 3 do
		local anchor = board:WaitForChild("Anchor" .. place, 10)
		if anchor and anchor:IsA("BasePart") then
			anchors[place] = anchor
		end
	end

	render()
end

function LeaderboardController:Init() end

function LeaderboardController:Start()
	State = self.GetController("StateController")
	Locale = self.GetController("LocaleController")

	task.spawn(attachBoard)

	State.Notified:Connect(function(kind, payload)
		if kind ~= "Leaderboard" or type(payload) ~= "table" then
			return
		end
		lastRows = payload.rows or {}
		render()
	end)

	Locale.Changed:Connect(function()
		renderList(lastRows)
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for place, entry in shown do
			local anchor = anchors[place]
			if anchor and entry.model.PrimaryPart then
				local bob = math.sin(now * 1.3 + entry.phase) * 0.25
				entry.model.PrimaryPart.CFrame =
					CFrame.new(anchor.Position + Vector3.new(0, bob, 0))
					* CFrame.Angles(0, now * 0.5 + entry.phase, 0)
			end
		end
	end)
end

return LeaderboardController
