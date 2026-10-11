--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Shop = require(Shared.Shop)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local ShopController = {}

local State, UI, Locale
local list: ScrollingFrame
local emptyNote: TextLabel
local rows: { [string]: TextButton } = {}

local function sorted(source: any): { any }
	local items = {}
	for key, info in source do
		if Shop.isConfigured(info) then
			table.insert(items, { key = key, info = info })
		end
	end
	table.sort(items, function(a, b)
		return a.info.order < b.info.order
	end)
	return items
end

local function addRow(entry: any, kind: string, order: number)
	local info = entry.info

	local button = Widgets.button({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 68),
		Text = "",
		BackgroundColor3 = Theme.Color.PanelSoft,
		Parent = list,
	}, {
		Widgets.label({
			Name = "ItemName",
			Size = UDim2.new(1, -90, 0, 22),
			Position = UDim2.fromOffset(10, 8),
			Text = Locale:Get("shop." .. entry.key .. ".name"),
			Font = Theme.Font.Bold,
			TextSize = 15,
		}),
		Widgets.label({
			Name = "ItemBlurb",
			Size = UDim2.new(1, -100, 0, 30),
			Position = UDim2.fromOffset(10, 30),
			Text = Locale:Get("shop." .. entry.key .. ".blurb"),
			TextColor3 = Theme.Color.TextDim,
			TextSize = 12,
			TextWrapped = true,
		}),
		Widgets.label({
			Name = "Price",
			Size = UDim2.fromOffset(80, 68),
			Position = UDim2.new(1, -86, 0, 0),
			Text = ("%d R$"):format(info.price),
			TextColor3 = Theme.Color.Positive,
			Font = Theme.Font.Bold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})

	button.MouseButton1Click:Connect(function()
		local player = Players.LocalPlayer
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, info.id)
		else
			MarketplaceService:PromptProductPurchase(player, info.id)
		end
	end)

	rows[entry.key] = button
end

local function markOwned()
	local passes = State:Get("passes") or {}
	for key, button in rows do
		if passes[key] == true then
			local price = button:FindFirstChild("Price") :: TextLabel?
			if price then
				price.Text = Locale:Get("shop.owned")
				price.TextColor3 = Theme.Color.TextDim
			end
			button.BackgroundTransparency = 0.5
		end
	end
end

local function build()
	local body = UI:CreatePanel("Shop", "shop.title")
	create("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Pad.M),
		PaddingRight = UDim.new(0, Theme.Pad.M),
		Parent = body,
	})

	list = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Bevel,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Widgets.list({ Padding = UDim.new(0, Theme.Pad.S) }),
	}) :: ScrollingFrame

	emptyNote = Widgets.label({
		Name = "EmptyNote",
		Size = UDim2.new(1, 0, 0, 90),
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = body,
	})

	local order = 0
	local passes = sorted(Shop.Passes)
	local products = sorted(Shop.Products)

	for _, entry in passes do
		order += 1
		addRow(entry, "pass", order)
	end
	for _, entry in products do
		order += 1
		addRow(entry, "product", order)
	end

	if order == 0 then
		emptyNote.Visible = true
		list.Visible = false
	else
		list.CanvasSize = UDim2.fromOffset(0, order * 76 + 8)
	end
end

function ShopController:Init() end

function ShopController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")

	build()
	Locale:Bind(emptyNote, "shop.empty")
	UI:AddNavButton("menu.shop", 6, function()
		UI:TogglePanel("Shop")
	end)

	State:Observe("passes", markOwned)

	Locale:Observe(function()
		for key, button in rows do
			local n = button:FindFirstChild("ItemName")
			local b = button:FindFirstChild("ItemBlurb")
			if n then n.Text = Locale:Get("shop." .. key .. ".name") end
			if b then b.Text = Locale:Get("shop." .. key .. ".blurb") end
		end
		markOwned()
	end)

	State.Notified:Connect(function(kind, payload)
		if kind ~= "PurchaseResult" then
			return
		end
		if payload.duplicate then
			UI:Toast(Locale:Get("shop.duplicate"), Theme.Color.TextDim)
		else
			UI:Toast(Locale:Get("shop.bought",
				Locale:Get("shop." .. tostring(payload.key) .. ".name")), Theme.Color.Positive)
		end
		markOwned()
	end)
end

return ShopController
