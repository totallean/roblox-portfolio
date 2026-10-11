--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Format = require(Shared.Format)
local Eco = require(Shared.EconomyConfig)
local Assets = require(Shared.Assets)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local UIController = {}

local State, Locale
local gui: ScreenGui
local panels: { [string]: Frame } = {}
local openPanel: string? = nil
local counters: { Widgets.Counter } = {}

local card = {}
local pills = {}
local menuGrid: Frame
local menuTitle: TextLabel
local hotbar: Frame
local toastLayer: Frame
local panelLayer: Frame

local function buildCard(parent: Instance)
	local root = Widgets.panel({
		Name = "Card",
		Position = UDim2.fromOffset(Theme.Pad.M, Theme.Pad.M),
		Size = UDim2.fromOffset(268, 108),
		Parent = parent,
	}, { Widgets.padding(Theme.Pad.S) })

	local player = Players.LocalPlayer

	create("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Theme.Color.Slot,
		BorderSizePixel = 0,
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId),
		Parent = root,
	}, { Widgets.corner(Theme.Radius.S), Widgets.accentStroke(1.2) })

	card.name = Widgets.label({
		Name = "PlayerName",
		Position = UDim2.fromOffset(54, 1),
		Size = UDim2.new(1, -56, 0, 17),
		Text = player.DisplayName,
		Font = Theme.Font.Bold,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	card.rank = Widgets.label({
		Name = "Rank",
		Position = UDim2.fromOffset(54, 18),
		Size = UDim2.new(1, -56, 0, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.Color.TextDim,
		Parent = root,
	})

	card.spectrum = Widgets.label({
		Name = "Spectrum",
		Position = UDim2.fromOffset(54, 32),
		Size = UDim2.new(1, -56, 0, 14),
		Text = "",
		TextSize = 11,
		Font = Theme.Font.Bold,
		Parent = root,
	})

	local bars = create("Frame", {
		Name = "Bars",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 42),
		Parent = root,
	}, { Widgets.list({ Padding = UDim.new(0, 3) }) })

	card.xp = Widgets.bar({ Name = "Xp", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 12) }, Theme.Color.Xp, true)
	card.xp.frame.Parent = bars

	card.rebirth = Widgets.bar({ Name = "Rebirth", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 12) }, Theme.Color.Charge, true)
	card.rebirth.frame.Parent = bars

	card.match = Widgets.bar({ Name = "Match", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 12) }, Theme.Color.Will, true)
	card.match.frame.Parent = bars
end

local function buildMenu(parent: Instance)
	local root = Widgets.panel({
		Name = "Menu",
		Position = UDim2.fromOffset(Theme.Pad.M, 126),
		Size = UDim2.fromOffset(268, 282),
		Parent = parent,
	}, { Widgets.padding(Theme.Pad.S) })

	menuTitle = Widgets.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 12,
		TextColor3 = Theme.Color.TextDim,
		Parent = root,
	})

	menuGrid = create("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 1, -20),
		Parent = root,
	}, { Widgets.grid(Vector2.new(76, 76), Theme.Pad.S) }) :: Frame
end

local function buildPill(order: number, name: string, image: string, onPlus: () -> ()): TextLabel
	local pill = Widgets.panel({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(172, 42),
	}, { Widgets.padding(4) })

	Widgets.icon(image, {
		Name = "Art",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(2, 1),
		Parent = pill,
	})

	local value = Widgets.label({
		Name = "Value",
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -76, 1, 0),
		Text = "0",
		Font = Theme.Font.Number,
		TextSize = 16,
		Parent = pill,
	})

	local plus = Widgets.button({
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(30, 26),
		Text = "+",
		TextSize = 18,
		BackgroundColor3 = Theme.Color.Positive,
		Parent = pill,
	})
	plus.MouseButton1Click:Connect(onPlus)

	return value
end

local function buildCurrencies(parent: Instance)
	local row = create("Frame", {
		Name = "Currencies",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Pad.M, 0, Theme.Pad.M),
		Size = UDim2.fromOffset(356, 42),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Widgets.list({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, Theme.Pad.S),
		}),
	})

	pills.will = buildPill(1, "Will", Assets.Currency.Will, function()
		UIController:OpenPanel("Ring")
	end)
	pills.will.Parent.Parent = row

	pills.shards = buildPill(2, "Shards", Assets.Currency.Shards, function()
		UIController:OpenPanel("Shop")
	end)
	pills.shards.Parent.Parent = row
end

local function buildHotbar(parent: Instance)
	hotbar = create("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Pad.M),
		Size = UDim2.fromOffset(372, 84),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Widgets.list({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.Pad.S),
		}),
	}) :: Frame
end

function UIController:AddHotbarSlot(index: number, key: string, color: Color3, onClick: () -> ()): TextButton
	local art = Assets.hotbar(key)

	local kids = {
		Widgets.label({
			Name = "Index",
			Position = UDim2.fromOffset(5, 3),
			Size = UDim2.fromOffset(14, 14),
			Text = tostring(index),
			TextSize = 11,
			Font = Theme.Font.Bold,
			TextColor3 = Theme.Color.TextMuted,
			ZIndex = 4,
		}),
	}

	if art then
		table.insert(kids, Widgets.icon(art, {
			Name = "Art",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			ZIndex = 2,
		}))
	else
		table.insert(kids, create("Frame", {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(36, 36),
			Rotation = 45,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, { Widgets.corner(Theme.Radius.S) }))
	end

	table.insert(kids, create("Frame", {
		Name = "CaptionStrip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, {
		Widgets.corner(Theme.Radius.S),
		Widgets.label({
			Size = UDim2.new(1, -4, 1, 0),
			Position = UDim2.fromOffset(2, 0),
			Text = "",
			TextSize = 11,
			Font = Theme.Font.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		}),
	}))

	local button = Widgets.button({
		Name = key,
		LayoutOrder = index,
		Size = UDim2.fromOffset(84, 84),
		Text = "",
		Parent = hotbar,
	}, kids)

	button.MouseButton1Click:Connect(onClick)

	local strip = button:FindFirstChild("CaptionStrip")
	local caption = strip and strip:FindFirstChildOfClass("TextLabel")
	if caption and Locale then
		Locale:Bind(caption, key)
	end

	return button
end

function UIController:Toast(text: string, color: Color3?)
	local toast = Widgets.panel({
		Size = UDim2.fromOffset(320, 38),
		BackgroundTransparency = 1,
		Parent = toastLayer,
	}, {
		Widgets.label({
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = color or Theme.Color.Text,
			TextSize = 14,
			Font = Theme.Font.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
		}),
	})

	local label = toast:FindFirstChildOfClass("TextLabel") :: TextLabel
	local stroke = toast:FindFirstChildOfClass("UIStroke") :: UIStroke

	local fadeIn = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(toast, fadeIn, { BackgroundTransparency = Theme.PanelTransparency }):Play()
	TweenService:Create(label, fadeIn, { TextTransparency = 0 }):Play()

	task.delay(2.8, function()
		local fadeOut = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
		TweenService:Create(toast, fadeOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fadeOut, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeOut, { Transparency = 1 }):Play()
		task.delay(0.4, function() toast:Destroy() end)
	end)
end

function UIController:CreatePanel(name: string, titleKey: string): Frame
	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
	})

	local closeButton = Widgets.button({
		Name = "Close",
		Size = UDim2.fromOffset(Theme.TouchTarget, Theme.TouchTarget),
		Position = UDim2.new(1, -Theme.TouchTarget - 6, 0, 4),
		Text = "X",
		TextSize = 16,
	})

	local panel = Widgets.panel({
		Name = name,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.78, 0),
		Parent = panelLayer,
	}, {
		create("UISizeConstraint", { MaxSize = Vector2.new(560, 640) }),
		Widgets.label({
			Name = "Title",
			Size = UDim2.new(1, -Theme.TouchTarget - 16, 0, 44),
			Position = UDim2.fromOffset(Theme.Pad.M, 0),
			Text = "",
			Font = Theme.Font.Bold,
			TextSize = 19,
		}),
		closeButton,
		body,
	})

	closeButton.MouseButton1Click:Connect(function()
		UIController:ClosePanel()
	end)

	local titleLabel = panel:FindFirstChild("Title")
	if titleLabel and Locale then
		Locale:Bind(titleLabel, titleKey)
	end

	panels[name] = panel
	return body
end

function UIController:OpenPanel(name: string)
	for key, panel in panels do
		panel.Visible = key == name
	end
	openPanel = name
end

function UIController:ClosePanel()
	for _, panel in panels do
		panel.Visible = false
	end
	openPanel = nil
end

function UIController:TogglePanel(name: string)
	if openPanel == name then
		self:ClosePanel()
	else
		self:OpenPanel(name)
	end
end

function UIController:AddNavButton(key: string, order: number, onClick: () -> ()): TextButton
	local tile = Widgets.tile(Assets.menu(key), key, order)
	tile.button.Name = key
	tile.button.Parent = menuGrid
	tile.button.MouseButton1Click:Connect(onClick)

	local strip = tile.button:FindFirstChild("CaptionStrip")
	local caption = strip and strip:FindFirstChildOfClass("TextLabel")
	if caption and Locale then
		Locale:Bind(caption, key)
	end

	return tile.button
end

function UIController:SetCaptionsVisible(visible: boolean)
	for _, root in { menuGrid, hotbar } do
		if not root then
			continue
		end
		for _, button in root:GetChildren() do
			local strip = button:FindFirstChild("CaptionStrip")
			if strip then
				strip.Visible = visible
			end
		end
	end
end

function UIController:FindButton(name: string): GuiObject?
	for _, root in { menuGrid, hotbar } do
		if root then
			local found = root:FindFirstChild(name)
			if found then
				return found
			end
		end
	end
	return nil
end

function UIController:GetScreen(): ScreenGui
	return gui
end

function UIController:GetHotbar(): Frame
	return hotbar
end

function UIController:GetActionLayer(): Frame
	return gui:FindFirstChild("ActionLayer") :: Frame
end

function UIController:RegisterCounter(counter: any)
	table.insert(counters, counter)
end

function UIController:Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	gui = create("ScreenGui", {
		Name = "SpectrumForge",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	Theme.attachScale(gui)

	buildCard(gui)
	buildMenu(gui)
	buildCurrencies(gui)
	buildHotbar(gui)

	toastLayer = create("Frame", {
		Name = "ToastLayer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(320, 200),
		Parent = gui,
	}, { Widgets.list({ HorizontalAlignment = Enum.HorizontalAlignment.Center }) }) :: Frame

	create("Frame", {
		Name = "ActionLayer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(220, 200),
		Parent = gui,
	})

	panelLayer = create("Frame", {
		Name = "PanelLayer",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}) :: Frame
end

function UIController:Start()
	State = self.GetController("StateController")
	Locale = self.GetController("LocaleController")

	Locale:Bind(menuTitle, "menu.title")

	for _, root in { menuGrid, hotbar } do
		for _, button in root:GetChildren() do
			local strip = button:FindFirstChild("CaptionStrip")
			local caption = strip and strip:FindFirstChildOfClass("TextLabel")
			if caption then
				Locale:Bind(caption, button.Name)
			end
		end
	end

	local willCounter = Widgets.counter(pills.will, Format.short)
	local shardCounter = Widgets.counter(pills.shards, Format.short)
	self:RegisterCounter(willCounter)
	self:RegisterCounter(shardCounter)

	State:Observe("shards", function(value)
		shardCounter:set(value)
	end)

	local shownXp = -1
	local function updateXp()
		local level = State:Get("ringLevel")
		if not level then
			return
		end
		local xp = math.clamp(State:GetWill() / math.max(Eco.ringCost(level), 1), 0, 1)
		local percent = math.floor(xp * 100)
		if percent == shownXp then
			return
		end
		shownXp = percent
		card.xp.fill.Size = UDim2.fromScale(percent / 100, 1)
		card.xp.caption.Text = Locale:Get("card.xp", percent)
	end

	local function refresh()
		local level = State:Get("ringLevel") or 1
		local rebirths = State:Get("rebirths") or 0
		local tier = State:Get("colorTier") or 1
		local match = State:Get("matchCount") or 0

		card.rank.Text = Locale:Get("card.rank", level)
		card.spectrum.Text = Locale:Get("card.spectrum", Locale:ColorName(tier), rebirths)
		card.spectrum.TextColor3 = Theme.spectrum(tier)

		local required = Eco.rebirthRequirement(rebirths + 1)
		card.rebirth.fill.Size = UDim2.fromScale(math.clamp(level / required, 0, 1), 1)
		card.rebirth.caption.Text = Locale:Get("card.rebirth", level, required)

		card.match.fill.Size = UDim2.fromScale(match / 5, 1)
		card.match.caption.Text = Locale:Get("card.match", match)

		shownXp = -1
		updateXp()

		Theme.setAccent(Theme.spectrum(tier))
	end

	State:ObserveAll({ "ringLevel", "rebirths", "colorTier", "matchCount" }, refresh)

	Locale:Observe(refresh)

	RunService.RenderStepped:Connect(function(dt)
		willCounter:set(State:GetWill())
		for _, counter in counters do
			counter:step(dt)
		end
		updateXp()
	end)

	State.Notified:Connect(function(kind, payload)
		if kind == "Error" then
			local text = if payload.reason == "not_enough_shards"
				then Locale:Get("err.shards", Format.short(payload.need))
				elseif payload.reason == "rebirth_locked" then Locale:Get("err.rebirth", payload.need)
				elseif payload.reason == "battle_cooldown" then Locale:Get("err.cooldown", payload.secondsLeft or 0)
				elseif payload.reason == "no_opponent" then Locale:Get("err.noOpponent")
				else Locale:Get("err.generic")
			self:Toast(text, Theme.Color.Negative)

		elseif kind == "OfflineEarnings" then
			self:Toast(Locale:Get("offline.earned",
				Format.short(payload.amount), Locale:Duration(payload.seconds)), Theme.Color.Will)

		elseif kind == "RebirthResult" then
			self:Toast(Locale:Get("rebirth.result",
				payload.rebirths, payload.charge, Format.multiplier(payload.multiplier)), Theme.Color.Charge)
		end
	end)
end

return UIController
