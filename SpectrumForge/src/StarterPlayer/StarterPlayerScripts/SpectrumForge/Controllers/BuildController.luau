--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)
local Catalog = require(Shared.PartCatalog)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local BuildController = {}

local State, UI, Locale

local SLOT_KEY = {
	core = "slot.core",
	emitter = "slot.emitter",
	frame = "slot.frame",
	focus = "slot.focus",
	sigil = "slot.sigil",
}

local TAB_HEIGHT = 36

local slotButtons: { [string]: TextButton } = {}
local tabButtons: { TextButton } = {}
local selectedSlot = "core"
local buildPanel: GuiObject
local buildTabs: Frame
local slotRow: Frame
local partList: ScrollingFrame
local partListDirty = true
local crate = {}
local oddsBody: Frame? = nil

local function renderOdds()
	if not oddsBody then
		return
	end
	for _, l in oddsBody:GetChildren() do
		if l:IsA("TextLabel") and l.LayoutOrder <= #Eco.CRATE_ODDS then
			l:Destroy()
		end
	end
	for tier, chance in Eco.CRATE_ODDS do
		Widgets.label({
			LayoutOrder = tier,
			Size = UDim2.new(1, 0, 0, 24),
			Text = Locale:Get("crate.oddsRow", Locale:ColorName(tier), tostring(chance)),
			TextColor3 = Theme.spectrum(tier),
			TextSize = 15,
			Parent = oddsBody,
		})
	end
end

local function currentBuild()
	local builds = State:Get("builds")
	local index = State:Get("activeBuild") or 1
	return builds and builds[index]
end

local function describe(part): (string, Color3)
	return Locale:Get("codex.part", Locale:PartName(part.defId), part.level),
		Theme.spectrum(part.tier)
end

local function refreshSlots()
	local build = currentBuild()
	local parts = State:Get("parts") or {}

	for slot, button in slotButtons do
		local uid = build and (build :: any)[slot]
		local part = uid and parts[uid]

		if part then
			local text, color = describe(part)
			button.Text = ("%s\n%s"):format(Locale:Get(SLOT_KEY[slot]), text)
			button.TextColor3 = color
		else
			button.Text = ("%s\n%s"):format(Locale:Get(SLOT_KEY[slot]), Locale:Get("codex.empty"))
			button.TextColor3 = Theme.Color.TextDim
		end

		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if slot == selectedSlot then Theme.Color.Will else Theme.Color.Bevel
			stroke.Thickness = if slot == selectedSlot then 2 else 1
		end
	end
end

local function rebuildPartList()
	partListDirty = false

	for _, child in partList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local parts = State:Get("parts") or {}
	local build = currentBuild()
	local equipped = build and (build :: any)[selectedSlot]

	local matching = {}
	for uid, part in parts do
		local def = Catalog.ById[part.defId]
		if def and def.slot == selectedSlot then
			table.insert(matching, { uid = uid, part = part })
		end
	end

	table.sort(matching, function(a, b)
		if a.part.tier ~= b.part.tier then
			return a.part.tier > b.part.tier
		end
		return a.part.level > b.part.level
	end)

	for index, entry in matching do
		local text, color = describe(entry.part)
		local isOn = entry.uid == equipped

		local row = Widgets.button({
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, Theme.TouchTarget),
			Text = ("%s  %s%s"):format(Locale:ColorName(entry.part.tier), text,
				if isOn then Locale:Get("build.equipped") else ""),
			TextColor3 = color,
			TextSize = 14,
			BackgroundColor3 = if isOn then Theme.Color.Slot else Theme.Color.PanelSoft,
			Parent = partList,
		})

		row.MouseButton1Click:Connect(function()
			State:Send("SetBuildSlot", selectedSlot, if isOn then nil else entry.uid)
		end)
	end

	partList.CanvasSize = UDim2.fromOffset(0, #matching * (Theme.TouchTarget + 8) + 8)
end

local function requestPartList()
	if buildPanel.Visible then
		rebuildPartList()
	else
		partListDirty = true
	end
end

local function buildInventoryPanel()
	local body = UI:CreatePanel("Build", "build.title")
	buildPanel = body.Parent :: GuiObject
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})

	buildTabs = create("Frame", {
		Name = "BuildTabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Visible = false,
		Parent = body,
	}, {
		Widgets.list({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.Pad.XS),
		}),
	}) :: Frame

	slotRow = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Parent = body,
	}, {
		Widgets.list({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.Pad.XS),
		}),
	}) :: Frame

	for index, slot in Eco.SLOTS do
		local button = Widgets.button({
			LayoutOrder = index,
			Size = UDim2.new(0.2, -4, 1, 0),
			Text = Locale:Get(SLOT_KEY[slot]),
			TextSize = 11,
			BackgroundColor3 = Theme.Color.PanelSoft,
			Parent = slotRow,
		})
		button.MouseButton1Click:Connect(function()
			selectedSlot = slot
			refreshSlots()
			rebuildPartList()
		end)
		slotButtons[slot] = button
	end

	partList = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -72),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Bevel,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Widgets.list({ Padding = UDim.new(0, Theme.Pad.S) }),
	}) :: ScrollingFrame
end

local function refreshTabs()
	local builds = State:Get("builds") or {}
	local active = State:Get("activeBuild") or 1
	local multiple = #builds > 1

	buildTabs.Visible = multiple
	local offset = if multiple then TAB_HEIGHT + Theme.Pad.S else 0
	slotRow.Position = UDim2.fromOffset(0, offset)
	partList.Position = UDim2.fromOffset(0, offset + 64)
	partList.Size = UDim2.new(1, 0, 1, -(offset + 72))

	for index = #tabButtons + 1, #builds do
		local button = Widgets.button({
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			TextSize = 13,
			BackgroundColor3 = Theme.Color.PanelSoft,
			Parent = buildTabs,
		})
		button.MouseButton1Click:Connect(function()
			State:Send("SelectBuild", index)
		end)
		tabButtons[index] = button
	end

	for index, button in tabButtons do
		local isActive = index == active
		button.Visible = index <= #builds
		button.Text = Locale:Get("build.tab", index)
		button.TextColor3 = if isActive then Theme.Color.Text else Theme.Color.TextDim
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if isActive then Theme.Color.Will else Theme.Color.Bevel
			stroke.Thickness = if isActive then 2 else 1
		end
	end
end

local function buildOddsPanel()
	local body = UI:CreatePanel("Odds", "crate.oddsTitle")
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})
	Widgets.list({ Padding = UDim.new(0, Theme.Pad.XS) }).Parent = body

	oddsBody = body
	renderOdds()

	crate.guarantee = Widgets.label({
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		TextWrapped = true,
		Parent = body,
	})
end

local function buildCratePanel()
	local body = UI:CreatePanel("Crate", "crate.title")
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})
	Widgets.list({ Padding = UDim.new(0, Theme.Pad.S) }).Parent = body

	crate.access = Widgets.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 14,
		Parent = body,
	})

	crate.pity = Widgets.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 14,
		Parent = body,
	})

	crate.one = Widgets.button({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Text = "",
		Parent = body,
	})
	crate.one.MouseButton1Click:Connect(function()
		State:Send("OpenCrate", 1)
	end)

	crate.ten = Widgets.button({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Text = "",
		BackgroundColor3 = Theme.Color.Shard:Lerp(Theme.Color.Panel, 0.6),
		Parent = body,
	})
	crate.ten.MouseButton1Click:Connect(function()
		State:Send("OpenCrate", Eco.CRATE_BULK_COUNT)
	end)

	local odds = Widgets.button({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		Name = "OddsButton",
		Text = "",
		TextSize = 14,
		BackgroundColor3 = Theme.Color.PanelSoft,
		Parent = body,
	})
	odds.MouseButton1Click:Connect(function()
		UI:OpenPanel("Odds")
	end)
	crate.oddsButton = odds

	crate.results = create("ScrollingFrame", {
		LayoutOrder = 6,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -220),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Bevel,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Widgets.list({ Padding = UDim.new(0, Theme.Pad.XS) }),
	}) :: ScrollingFrame
end

local function showDrops(payload)
	for _, child in crate.results:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for index, drop in payload.drops do
		Widgets.label({
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 22),
			Text = ("%s %s (%s)%s"):format(
				Locale:ColorName(drop.tier), Locale:PartName(drop.defId),
				Locale:Get(SLOT_KEY[drop.slot] or "slot.core"),
				if drop.forced then Locale:Get("crate.forced") else ""),
			TextColor3 = Theme.spectrum(drop.tier),
			TextSize = 14,
			Parent = crate.results,
		})
	end

	crate.results.CanvasSize = UDim2.fromOffset(0, #payload.drops * 24 + 8)
end

local function refreshCrate()
	local rebirths = State:Get("rebirths") or 0
	local maxTier = Eco.maxUnlockedTier(rebirths)
	local pity = State:Get("pityCounter") or 0

	crate.access.Text = Locale:Get("crate.access", maxTier, #Eco.COLORS, Locale:ColorName(maxTier))
	crate.access.TextColor3 = Theme.spectrum(maxTier)
	crate.pity.Text = Locale:Get("crate.pity", pity, Eco.PITY_COUNT)
end

function BuildController:Init() end

function BuildController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")

	buildInventoryPanel()
	buildCratePanel()
	buildOddsPanel()

	UI:AddNavButton("menu.build", 3, function()
		UI:TogglePanel("Build")
	end)
	UI:AddNavButton("menu.crates", 4, function()
		UI:TogglePanel("Crate")
	end)

	UI:AddHotbarSlot(3, "hotbar.crate", Theme.Color.Shard, function()
		State:Send("OpenCrate", 1)
	end)
	UI:AddHotbarSlot(4, "hotbar.crate10", Theme.Color.Charge, function()
		State:Send("OpenCrate", Eco.CRATE_BULK_COUNT)
	end)

	State:ObserveAll({ "parts", "builds", "activeBuild" }, function()
		refreshTabs()
		refreshSlots()
		requestPartList()
	end)
	State:ObserveAll({ "rebirths", "pityCounter" }, refreshCrate)

	buildPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if buildPanel.Visible and partListDirty then
			rebuildPartList()
		end
	end)

	State.Notified:Connect(function(kind, payload)
		if kind == "CrateResult" then
			showDrops(payload)
			refreshCrate()
		end
	end)

	Locale:Bind(crate.oddsButton, "crate.odds")

	Locale:Observe(function()
		crate.one.Text = Locale:Get("crate.open1", Eco.crateCost(1))
		crate.ten.Text = Locale:Get("crate.open10", Eco.crateCost(Eco.CRATE_BULK_COUNT))
		crate.guarantee.Text = Locale:Get("crate.guarantee", Eco.PITY_MIN_TIER, Eco.PITY_COUNT)
		refreshTabs()
		refreshSlots()
		requestPartList()
		refreshCrate()
		renderOdds()
	end)
end

return BuildController
