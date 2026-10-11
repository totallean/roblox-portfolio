--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Format = require(Shared.Format)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local BattleController = {}

local State, UI, Locale
local view = {}

local function fighterRow(order: number, parent: Instance): TextLabel
	return Widgets.label({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 14,
		Text = "",
		Parent = parent,
	})
end

local function buildPanel()
	local body = UI:CreatePanel("Arena", "arena.title")
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})
	Widgets.list({ Padding = UDim.new(0, Theme.Pad.S) }).Parent = body

	view.blurb = Widgets.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Name = "ArenaBlurb",
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		TextWrapped = true,
		Parent = body,
	})

	view.rank = Widgets.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.Font.Bold,
		TextSize = 17,
		Text = "",
		Parent = body,
	})

	view.record = Widgets.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.Color.TextDim,
		TextSize = 14,
		Text = "",
		Parent = body,
	})

	view.power = Widgets.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 14,
		Text = "",
		Parent = body,
	})

	view.challenge = Widgets.button({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Name = "Challenge",
		Text = "",
		BackgroundColor3 = Theme.Color.Negative:Lerp(Theme.Color.Panel, 0.55),
		Parent = body,
	})
	view.challenge.MouseButton1Click:Connect(function()
		State:Send("ChallengeGhost")
	end)

	view.result = Widgets.panel({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 132),
		BackgroundColor3 = Theme.Color.PanelSoft,
		Visible = false,
		Parent = body,
	}, {
		Widgets.padding(Theme.Pad.S),
		Widgets.list({ Padding = UDim.new(0, Theme.Pad.XS) }),
	})

	view.verdict = Widgets.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.Font.Bold,
		TextSize = 16,
		Text = "",
		Parent = view.result,
	})
	view.mine = fighterRow(2, view.result)
	view.theirs = fighterRow(3, view.result)
	view.reward = fighterRow(4, view.result)
end

local function refresh()
	local rank = State:Get("arenaRank") or 1
	local wins = State:Get("arenaWins") or 0
	local losses = State:Get("arenaLosses") or 0

	view.rank.Text = Locale:Get("ghost.rank", rank)
	view.record.Text = Locale:Get("ghost.record", wins, losses)
end

local function showResult(payload)
	view.result.Visible = true

	view.verdict.Text = if payload.won then Locale:Get("arena.victory") else Locale:Get("arena.defeat")
	view.verdict.TextColor3 = if payload.won then Theme.Color.Positive else Theme.Color.Negative

	view.mine.Text = Locale:Get("arena.you",
		Format.short(payload.self.dps), Format.short(payload.self.hp))
	view.theirs.Text = Locale:Get("arena.foe", payload.opponent.name,
		Format.short(payload.opponent.dps), Format.short(payload.opponent.hp))
	view.reward.Text = Locale:Get("arena.reward", payload.reward, payload.rank)
	view.reward.TextColor3 = Theme.Color.Shard
end

function BattleController:Init() end

function BattleController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")

	buildPanel()
	UI:AddNavButton("menu.arena", 5, function()
		UI:TogglePanel("Arena")
	end)

	UI:AddHotbarSlot(2, "hotbar.fight", Theme.Color.Negative, function()
		State:Send("ChallengeGhost")
	end)

	State:ObserveAll({ "arenaRank", "arenaWins", "arenaLosses" }, refresh)

	Locale:Bind(view.blurb, "arena.blurb")
	Locale:Bind(view.challenge, "arena.challenge")
	Locale:Observe(refresh)

	State.Notified:Connect(function(kind, payload)
		if kind == "BattleResult" then
			showResult(payload)
			UI:Toast(
				if payload.won then Locale:Get("arena.wonToast", payload.opponent.name)
				else Locale:Get("arena.lostToast", payload.opponent.name),
				if payload.won then Theme.Color.Positive else Theme.Color.Negative
			)

		elseif kind == "GhostWins" then
			UI:Toast(Locale:Get("arena.ghostWins", payload.wins, payload.reward), Theme.Color.Shard)

		elseif kind == "Error" and payload.reason == "no_opponent" then
			UI:Toast(Locale:Get("err.noOpponent"), Theme.Color.TextDim)
		end
	end)
end

return BattleController
