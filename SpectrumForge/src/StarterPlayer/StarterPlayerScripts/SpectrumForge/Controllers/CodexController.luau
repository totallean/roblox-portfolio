--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)
local Catalog = require(Shared.PartCatalog)
local Format = require(Shared.Format)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local CodexController = {}

local State, UI, Locale

local SLOT_KEYS = {
	core = { "slot.short.core", "slot.core" },
	emitter = { "slot.short.emitter", "slot.emitter" },
	frame = { "slot.short.frame", "slot.frame" },
	focus = { "slot.short.focus", "slot.focus" },
	sigil = { "slot.short.sigil", "slot.sigil" },
}

local ghost = {}
local rows: { [string]: any } = {}
local codexBar
local titles: { [string]: TextLabel } = {}

local function buildGhost(parent: Instance)
	local panel = Widgets.panel({
		Name = "Ghost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Pad.M, 0, 56),
		Size = UDim2.fromOffset(250, 112),
		Parent = parent,
	}, { Widgets.padding(Theme.Pad.S) })

	titles["ghost.title"] = Widgets.label({
		Size = UDim2.new(1, 0, 0, 17),
		Name = "GhostTitle",
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 13,
		Parent = panel,
	})

	ghost.rank = Widgets.label({
		Position = UDim2.fromOffset(0, 19),
		Size = UDim2.new(1, 0, 0, 15),
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Color.TextDim,
		Parent = panel,
	})

	ghost.record = Widgets.label({
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 15),
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Color.TextDim,
		Parent = panel,
	})

	ghost.power = Widgets.label({
		Position = UDim2.fromOffset(0, 49),
		Size = UDim2.new(1, 0, 0, 15),
		Text = "",
		TextSize = 12,
		Font = Theme.Font.Bold,
		Parent = panel,
	})

	local claim = Widgets.button({
		Name = "Claim",
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextSize = 12,
		BackgroundColor3 = Theme.Color.Shard:Lerp(Theme.Color.Panel, 0.55),
		Parent = panel,
	})
	claim.MouseButton1Click:Connect(function()
		State:Send("ClaimGhostWins")
	end)
	ghost.claim = claim
end

local function buildCodex(parent: Instance)
	local panel = Widgets.panel({
		Name = "Codex",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Pad.M, 0, 176),
		Size = UDim2.fromOffset(250, 214),
		Parent = parent,
	}, { Widgets.padding(Theme.Pad.S) })

	titles["codex.title"] = Widgets.label({
		Name = "CodexTitle",
		Size = UDim2.new(1, -46, 0, 17),
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 13,
		Parent = panel,
	})

	rows.count = Widgets.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(46, 17),
		Text = "0/5",
		Font = Theme.Font.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	codexBar = Widgets.bar({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 8) }, Theme.Color.Will)
	codexBar.frame.Parent = panel

	local listFrame = create("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = panel,
	}, { Widgets.list({ Padding = UDim.new(0, 4) }) })

	for index, slot in Eco.SLOTS do
		local keys = SLOT_KEYS[slot]

		local row = Widgets.slot({
			Name = slot,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = listFrame,
		})

		local key = Widgets.slot({
			Name = "Key",
			Position = UDim2.fromOffset(4, 5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Theme.Color.Panel,
			Parent = row,
		})
		Widgets.label({
			Size = UDim2.fromScale(1, 1),
			Name = "KeyLabel",
			Text = "",
			TextSize = 12,
			Font = Theme.Font.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = key,
		})

		local name = Widgets.label({
			Name = "PartName",
			Position = UDim2.fromOffset(32, 2),
			Size = UDim2.new(1, -100, 0, 15),
			Text = "",
			TextSize = 12,
			Font = Theme.Font.Bold,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})

		local sub = Widgets.label({
			Name = "SubName",
			Position = UDim2.fromOffset(32, 16),
			Size = UDim2.new(1, -100, 0, 13),
			Text = "",
			TextSize = 10,
			TextColor3 = Theme.Color.TextMuted,
			Parent = row,
		})

		local status = Widgets.label({
			Name = "Status",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(62, 20),
			Text = "",
			TextSize = 11,
			Font = Theme.Font.Bold,
			TextColor3 = Theme.Color.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})

		rows[slot] = { row = row, name = name, sub = sub, status = status,
			keyLabel = key:FindFirstChild("KeyLabel"), keys = keys }
	end
end

local function refreshCodex()
	local builds = State:Get("builds")
	local parts = State:Get("parts") or {}
	local build = builds and builds[State:Get("activeBuild") or 1]

	local filled = 0
	for _, slot in Eco.SLOTS do
		local view = rows[slot]
		if not view then continue end

		if view.keyLabel then
			view.keyLabel.Text = Locale:Get(view.keys[1])
		end

		local uid = build and (build :: any)[slot]
		local part = uid and parts[uid]

		if part then
			filled += 1
			view.name.Text = Locale:PartName(part.defId)
			view.name.TextColor3 = Theme.spectrum(part.tier)
			view.sub.Text = Locale:Get(view.keys[2])
			view.status.Text = Locale:Get("codex.part", Locale:ColorName(part.tier), part.level)
			view.status.TextColor3 = Theme.spectrum(part.tier)
		else
			view.name.Text = Locale:Get(view.keys[2])
			view.name.TextColor3 = Theme.Color.TextDim
			view.sub.Text = Locale:Get("codex.unused")
			view.status.Text = Locale:Get("codex.empty")
			view.status.TextColor3 = Theme.Color.TextMuted
		end
	end

	rows.count.Text = ("%d/5"):format(filled)
	codexBar.fill.Size = UDim2.fromScale(filled / 5, 1)
end

local function refreshGhost()
	local rank = State:Get("arenaRank") or 1
	local wins = State:Get("arenaWins") or 0
	local losses = State:Get("arenaLosses") or 0
	local pending = State:Get("ghostWinsPending") or 0
	local tier = State:Get("colorTier") or 1
	local match = State:Get("matchCount") or 0

	ghost.rank.Text = Locale:Get("ghost.rank", rank)
	ghost.record.Text = Locale:Get("ghost.record", wins, losses)

	local mult = (Eco.COLORS[tier] and Eco.COLORS[tier].wpsMult or 1)
		* Eco.MATCH_MULT[math.clamp(match, 1, 5)]
	ghost.power.Text = Locale:Get("ghost.income",
		Format.short(State:Get("wps") or 0), Format.multiplier(mult))
	ghost.power.TextColor3 = Theme.spectrum(tier)

	ghost.claim.Visible = pending > 0
	if pending > 0 then
		ghost.claim.Text = Locale:Get("ghost.claim", pending)
	end
end

function CodexController:Init() end

function CodexController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")

	local root = UI:GetScreen()
	buildGhost(root)
	buildCodex(root)

	State:ObserveAll({ "parts", "builds", "activeBuild" }, refreshCodex)
	State:ObserveAll(
		{ "arenaRank", "arenaWins", "arenaLosses", "ghostWinsPending", "colorTier", "matchCount", "wps" },
		refreshGhost
	)

	for key, label in titles do
		Locale:Bind(label, key)
	end

	Locale:Observe(function()
		refreshCodex()
		refreshGhost()
	end)
end

return CodexController
