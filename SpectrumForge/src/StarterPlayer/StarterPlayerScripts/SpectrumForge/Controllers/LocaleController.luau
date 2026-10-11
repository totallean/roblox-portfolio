--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Locale = require(Shared.Locale)
local Signal = require(Shared.Signal)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local LocaleController = {}

LocaleController.Changed = Signal.new()

local State
local current = Locale.fromLocaleId(Players.LocalPlayer.LocaleId)
local chosen = false

type Binding = { label: TextLabel, key: string }
local bindings: { Binding } = {}
local observers: { () -> () } = {}

function LocaleController:Language(): string
	return current
end

function LocaleController:HasChosen(): boolean
	return chosen
end

function LocaleController:Get(key: string, ...): string
	return Locale.get(current, key, ...)
end

function LocaleController:ColorName(tier: number): string
	return Locale.colorName(current, tier)
end

function LocaleController:PartName(defId: string): string
	return Locale.partName(current, defId)
end

function LocaleController:Duration(seconds: number): string
	return Locale.duration(current, seconds)
end

function LocaleController:Bind(label: TextLabel, key: string)
	table.insert(bindings, { label = label, key = key })
	label.Text = Locale.get(current, key)
end

function LocaleController:Observe(fn: () -> ())
	table.insert(observers, fn)
	fn()
end

local function apply(lang: string)
	if not Locale.isValid(lang) or lang == current then
		return
	end
	current = lang

	for index = #bindings, 1, -1 do
		local b = bindings[index]
		if b.label.Parent then
			b.label.Text = Locale.get(current, b.key)
		else
			table.remove(bindings, index)
		end
	end

	for _, fn in observers do
		local ok, err = pcall(fn)
		if not ok then
			warn("[Locale] перерисовка упала: " .. tostring(err))
		end
	end

	LocaleController.Changed:Fire(current)
end

function LocaleController:Choose(lang: string)
	if not Locale.isValid(lang) then
		return
	end
	chosen = true
	apply(lang)
	State:Send("SetLanguage", lang)
end

local picker: Frame? = nil

local function buildPicker(UI)
	local overlay = Widgets.create("Frame", {
		Name = "LanguagePicker",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 5, 9),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = UI:GetScreen(),
	}) :: Frame

	local card = Widgets.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 190),
		ZIndex = 51,
		Parent = overlay,
	}, { Widgets.padding(Theme.Pad.L) })

	Widgets.label({
		Size = UDim2.new(1, 0, 0, 22),
		Text = "ВЫБЕРИ ЯЗЫК",
		Font = Theme.Font.Bold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 52,
		Parent = card,
	})
	Widgets.label({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "CHOOSE LANGUAGE",
		TextSize = 13,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 52,
		Parent = card,
	})

	local row = Widgets.create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 60),
		ZIndex = 52,
		Parent = card,
	}, {
		Widgets.list({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.Pad.M),
		}),
	})

	for index, lang in Locale.LANGUAGES do
		local button = Widgets.button({
			Name = lang,
			LayoutOrder = index,
			Size = UDim2.fromOffset(130, 58),
			Text = Locale.NAMES[lang],
			TextSize = 17,
			ZIndex = 52,
			Parent = row,
		})
		button.MouseButton1Click:Connect(function()
			LocaleController:Choose(lang)
			overlay:Destroy()
			picker = nil
		end)
	end

	Widgets.label({
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "Поменять можно в меню  ·  Changeable in the menu",
		TextSize = 11,
		TextColor3 = Theme.Color.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 52,
		Parent = card,
	})

	return overlay
end

function LocaleController:Init() end

function LocaleController:Start()
	State = self.GetController("StateController")
	local UI = self.GetController("UIController")

	State:Observe("language", function(lang)
		if Locale.isValid(lang) then
			chosen = true
			apply(lang)
			if picker then
				picker:Destroy()
				picker = nil
			end
		end
	end)

	local body = UI:CreatePanel("Language", "menu.language")

	Widgets.create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})
	Widgets.list({ Padding = UDim.new(0, Theme.Pad.M) }).Parent = body

	for index, lang in Locale.LANGUAGES do
		local button = Widgets.button({
			Name = lang,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
			Text = Locale.NAMES[lang],
			TextSize = 16,
			Parent = body,
		})
		button.MouseButton1Click:Connect(function()
			LocaleController:Choose(lang)
			UI:ClosePanel()
		end)
	end

	UI:AddNavButton("menu.language", 7, function()
		UI:TogglePanel("Language")
	end)

	local waitForState
	waitForState = State:Observe("ringLevel", function()
		if waitForState then
			waitForState:Disconnect()
		end
		if not chosen and not picker then
			picker = buildPicker(UI)
		end
	end)
end

return LocaleController
