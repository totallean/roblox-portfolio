local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Sfx = require(Shared:WaitForChild("Sfx"))

Sfx.Init()
Sfx.StartMusic()

local Remotes = Net.Folder()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function stroke(parent: Instance, thickness: number?, color: Color3?)
	local value = thickness or Config.Style.StrokeThickness
	if value <= 0 then
		return nil
	end
	local s = Instance.new("UIStroke")
	s.Thickness = value
	s.Color = color or Config.Style.StrokeColor
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

local function gradient(parent: Instance, from: Color3, to: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(from, to)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, textColor: Color3?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = Config.Style.Font
	l.TextScaled = true
	l.RichText = true
	l.Text = text
	l.TextColor3 = textColor or Config.Style.TextColor
	l.Parent = parent
	stroke(l)
	return l
end

local function button(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Config.Style.Font
	b.TextScaled = true
	b.RichText = true
	b.Text = text
	b.TextColor3 = Config.Style.TextColor
	b.Parent = parent
	corner(b, 14)

	local border = stroke(b, Config.Style.FrameStroke)
	if border then
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	b.MouseButton1Click:Connect(function()
		Sfx.Play("Click")
	end)
	return b
end

local PANEL_MAX = Vector2.new(486, 548)
local PANEL_MIN = Vector2.new(280, 260)

local function centrePanel(frame: GuiObject)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 20)
	frame.Size = UDim2.new(0.92, 0, 0.82, 0)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = PANEL_MAX
	limit.MinSize = PANEL_MIN
	limit.Parent = frame
	return frame
end

local gui = Instance.new("ScreenGui")
gui.Name = "ButterUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local balanceFrame = Instance.new("Frame")
balanceFrame.Size = UDim2.new(0, 320, 0, 74)
balanceFrame.Position = UDim2.new(0.5, -160, 0, 14)
balanceFrame.BackgroundColor3 = Config.Palette.Void
balanceFrame.Parent = gui
corner(balanceFrame, 18)
stroke(balanceFrame, Config.Style.FrameStroke, Config.Palette.Butter)
gradient(balanceFrame, Config.Palette.Grape, Config.Palette.Void)

local balanceLabel = label(balanceFrame, "🧈 0", UDim2.new(1, -16, 0.62, 0), UDim2.new(0, 8, 0, 4), Config.Palette.Butter)
local multLabel = label(balanceFrame, "x1.0", UDim2.new(1, -16, 0.34, 0), UDim2.new(0, 8, 0.62, 0), Config.Palette.CyberCyan)

local hasPlot = true

local function setIncomeShown(shown: boolean)
	if hasPlot == shown then
		return
	end
	hasPlot = shown
	multLabel.Visible = shown

	if shown then
		balanceLabel.Size = UDim2.new(1, -16, 0.62, 0)
		balanceLabel.Position = UDim2.new(0, 8, 0, 4)
	else
		balanceLabel.Size = UDim2.new(1, -16, 1, -10)
		balanceLabel.Position = UDim2.new(0, 8, 0, 5)
	end
end

setIncomeShown(false)

local goalFrame = Instance.new("Frame")
goalFrame.Size = UDim2.new(0, 340, 0, 46)
goalFrame.Position = UDim2.new(0.5, -170, 0, 94)
goalFrame.BackgroundColor3 = Config.Palette.Void
goalFrame.BackgroundTransparency = 0.15
goalFrame.Parent = gui
corner(goalFrame, 14)
stroke(goalFrame, Config.Style.FrameStroke, Config.Palette.ToxicPink)

local goalLabel = label(goalFrame, Config.Text.GoalLoading, UDim2.new(1, -12, 1, -8), UDim2.new(0, 6, 0, 4), Config.Palette.White)

local toastList = Instance.new("Frame")
toastList.Size = UDim2.new(0, 340, 0, 240)
toastList.Position = UDim2.new(0.5, -170, 0, 150)
toastList.BackgroundTransparency = 1
toastList.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Parent = toastList

local rebirthButton = button(gui, Config.Text.RebirthButton, UDim2.new(0, 200, 0, 62), UDim2.new(1, -216, 1, -220), Config.Palette.Grape)

local shopToggle = button(gui, Config.Text.ShopButton, UDim2.new(0, 200, 0, 62), UDim2.new(1, -216, 1, -80), Config.Palette.ToxicPink)
local achieveToggle = button(gui, Config.Text.RewardsButton, UDim2.new(0, 200, 0, 62), UDim2.new(1, -216, 1, -150), Config.Palette.Butter)

achieveToggle.TextColor3 = Config.Style.TextColor
local achieveTextStroke = Instance.new("UIStroke")
achieveTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
achieveTextStroke.Color = Config.Style.StrokeColor
achieveTextStroke.Thickness = 1.5
achieveTextStroke.Parent = achieveToggle

local achieveFrame: Frame

local shopFrame = Instance.new("Frame")
shopFrame.BackgroundColor3 = Config.Palette.Void
shopFrame.Visible = false
shopFrame.Parent = gui
centrePanel(shopFrame)
corner(shopFrame, 20)
stroke(shopFrame, Config.Style.FrameStroke + 1, Config.Palette.Butter)

local shopHeader = Instance.new("Frame")
shopHeader.Size = UDim2.new(1, 0, 0, 56)
shopHeader.BackgroundColor3 = Config.Palette.Butter
shopHeader.Parent = shopFrame
corner(shopHeader, 20)

local headerFoot = Instance.new("Frame")
headerFoot.Size = UDim2.new(1, 0, 0, 20)
headerFoot.Position = UDim2.new(0, 0, 1, -20)
headerFoot.BackgroundColor3 = Config.Palette.Butter
headerFoot.BorderSizePixel = 0
headerFoot.Parent = shopHeader

local shopTitle = label(shopHeader, Config.Text.ShopTitle, UDim2.new(1, -140, 1, -12), UDim2.new(0, 18, 0, 6), Config.Palette.Void)
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.ZIndex = 2

local shopClose = button(shopHeader, "X", UDim2.fromOffset(52, 40), UDim2.new(1, -66, 0, 8), Config.Palette.HotRed)
shopClose.ZIndex = 2

local shopList = Instance.new("ScrollingFrame")
shopList.Size = UDim2.new(1, -24, 1, -76)
shopList.Position = UDim2.new(0, 12, 0, 66)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.ScrollBarImageColor3 = Config.Palette.Butter
shopList.CanvasSize = UDim2.new()
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.Parent = shopFrame

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 10)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

local function priceTag(parent: Instance, price: number?, size: UDim2, position: UDim2, rainbow: boolean)
	local tag = Instance.new("Frame")
	tag.Size = size
	tag.Position = position
	tag.BackgroundColor3 = rainbow and Config.Palette.White or Config.Palette.AcidGreen
	tag.Parent = parent
	corner(tag, 12)
	stroke(tag, 3, Config.Palette.Void)

	local shimmer = nil
	if rainbow then
		shimmer = Instance.new("UIGradient")
		shimmer.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Palette.ToxicPink),
			ColorSequenceKeypoint.new(0.35, Config.Palette.Butter),
			ColorSequenceKeypoint.new(0.7, Config.Palette.AcidGreen),
			ColorSequenceKeypoint.new(1, Config.Palette.CyberCyan),
		})
		shimmer.Parent = tag
		task.spawn(function()
			while tag.Parent do
				shimmer.Offset = Vector2.new((tick() * 0.35) % 2 - 1, 0)
				task.wait(0.05)
			end
		end)
	end

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.fromOffset(26, 26)
	icon.BackgroundTransparency = 1
	icon.Image = Config.RobuxIcon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = tag

	local text = label(tag, price and tostring(price) or "--",
		UDim2.new(1, -40, 1, -12), UDim2.new(0, 34, 0, 6), Config.Palette.Void)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center

	local function setOwned(owned: boolean)
		icon.Visible = not owned
		if shimmer then
			shimmer.Enabled = not owned
		end
		if owned then
			tag.BackgroundColor3 = Config.Palette.SteelLight
			text.Text = Config.Text.ShopOwned
			text.TextColor3 = Config.Palette.White
			text.Position = UDim2.new(0, 6, 0, 6)
			text.Size = UDim2.new(1, -12, 1, -12)
		else
			tag.BackgroundColor3 = rainbow and Config.Palette.White or Config.Palette.AcidGreen
			text.Text = price and tostring(price) or "--"
			text.TextColor3 = Config.Palette.Void
			text.Position = UDim2.new(0, 34, 0, 6)
			text.Size = UDim2.new(1, -40, 1, -12)
		end
	end

	return tag, setOwned
end

local shopSetters = {}

local function shopRow(passKey: string?, item, color: Color3, layoutOrder: number, onClick)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 84)
	row.BackgroundColor3 = color
	row.BackgroundTransparency = 0.25
	row.LayoutOrder = layoutOrder
	row.Parent = shopList
	corner(row, 14)
	stroke(row, 2, Config.Palette.Void)

	if item.Icon then
		local image = Instance.new("ImageLabel")
		image.AnchorPoint = Vector2.new(0, 0.5)
		image.Position = UDim2.new(0, 12, 0.5, 0)
		image.Size = UDim2.fromOffset(64, 64)
		image.BackgroundTransparency = 1
		image.Image = item.Icon
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = row
	end

	local name = label(row, item.Name, UDim2.new(1, -240, 0, 34), UDim2.new(0, 88, 0.5, -17), Config.Palette.White)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local _, setOwned = priceTag(row, item.Price, UDim2.fromOffset(126, 46), UDim2.new(1, -138, 0.5, -23), false)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Parent = row
	hit.MouseButton1Click:Connect(onClick)

	if passKey then
		shopSetters[passKey] = function(owned)
			setOwned(owned)
			hit.Active = not owned
			hit.AutoButtonColor = not owned
		end
	end
	return row
end

local function featuredRow(passKey: string?, item, layoutOrder: number, onClick)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -6, 0, 216)
	card.BackgroundColor3 = Config.Palette.AcidGreen
	card.LayoutOrder = layoutOrder
	card.Parent = shopList
	corner(card, 16)
	stroke(card, 4, Config.Palette.Butter)
	gradient(card, Config.Palette.AcidGreen, Config.Palette.Butter, 25)

	local title = label(card, item.Name, UDim2.fromOffset(236, 40), UDim2.new(0, 14, 0, 8), Config.Palette.Void)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromOffset(178, 34)
	badge.Position = UDim2.new(1, -192, 0, 11)
	badge.BackgroundColor3 = Config.Palette.HotRed
	badge.Parent = card
	corner(badge, 10)
	stroke(badge, 2, Config.Palette.Void)
	label(badge, Config.Text.ShopBadge, UDim2.new(1, -8, 1, -6), UDim2.new(0, 4, 0, 3), Config.Palette.White)

	for index, perk in ipairs(item.Perks or {}) do
		local tile = Instance.new("Frame")
		tile.Size = UDim2.fromOffset(118, 96)
		tile.Position = UDim2.new(0, 14 + (index - 1) * 126, 0, 58)
		tile.BackgroundColor3 = Config.Palette.Void
		tile.BackgroundTransparency = 0.15
		tile.Parent = card
		corner(tile, 12)
		stroke(tile, 2, Config.Palette.Void)

		local image = Instance.new("ImageLabel")
		image.AnchorPoint = Vector2.new(0.5, 0)
		image.Position = UDim2.new(0.5, 0, 0, 6)
		image.Size = UDim2.fromOffset(56, 56)
		image.BackgroundTransparency = 1
		image.Image = perk.Icon
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = tile

		label(tile, perk.Label, UDim2.new(1, -8, 0, 26), UDim2.new(0, 4, 0, 64), Config.Palette.Butter)
	end

	local wasLabel, strikeLine = nil, nil
	if item.OldPrice then
		wasLabel = label(card, ("%s %d"):format(Config.Text.ShopWas, item.OldPrice),
			UDim2.fromOffset(150, 30), UDim2.new(0, 16, 1, -44), Config.Palette.Void)
		wasLabel.TextXAlignment = Enum.TextXAlignment.Left

		strikeLine = Instance.new("Frame")
		strikeLine.Size = UDim2.new(0, 96, 0, 3)
		strikeLine.Position = UDim2.new(0, 20, 1, -30)
		strikeLine.BackgroundColor3 = Config.Palette.HotRed
		strikeLine.BorderSizePixel = 0
		strikeLine.Parent = card
	end

	local _, setOwned = priceTag(card, item.Price, UDim2.fromOffset(170, 48), UDim2.new(1, -184, 1, -58), true)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Parent = card
	hit.MouseButton1Click:Connect(onClick)

	if passKey then
		shopSetters[passKey] = function(owned)
			setOwned(owned)
			hit.Active = not owned
			hit.AutoButtonColor = not owned

			if wasLabel then wasLabel.Visible = not owned end
			if strikeLine then strikeLine.Visible = not owned end
			badge.Visible = not owned
		end
	end
	return card
end

local tierColors = {
	entry   = Config.Palette.CyberCyan,
	core    = Config.Palette.Butter,
	premium = Config.Palette.ToxicPink,
}

local order = 0
for key, pass in pairs(Config.Monetization.GamePasses) do
	if pass.Featured then
		order += 1
		featuredRow(key, pass, order, function()
			Remotes.RequestPurchase:FireServer("pass", key)
		end)
	end
end

for _, key in ipairs(Config.Monetization.Ladder) do
	local product = Config.Monetization.Products[key]
	if product then
		order += 1
		shopRow(nil, product, tierColors[product.Tier] or Config.Palette.Grape, order, function()
			Remotes.RequestPurchase:FireServer("product", key)
		end)
	end
end

for key, pass in pairs(Config.Monetization.GamePasses) do
	if not pass.Featured then
		order += 1
		shopRow(key, pass, Config.Palette.AcidGreen, 100 + order, function()
			Remotes.RequestPurchase:FireServer("pass", key)
		end)
	end
end

shopClose.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
end)

local function applyOwnedPasses(owned)
	for key, setter in pairs(shopSetters) do
		setter(owned[key] == true)
	end
end

shopToggle.MouseButton1Click:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
	if shopFrame.Visible and achieveFrame then
		achieveFrame.Visible = false
	end
end)

achieveFrame = Instance.new("Frame")
achieveFrame.BackgroundColor3 = Config.Palette.Void
achieveFrame.Visible = false
achieveFrame.Parent = gui
centrePanel(achieveFrame)
corner(achieveFrame, 18)
stroke(achieveFrame, Config.Style.FrameStroke, Config.Palette.Butter)

local achieveTitle = label(achieveFrame, (Config.Text.RewardsTitle):format(0, 0), UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 8), Config.Palette.Butter)
local achieveBonus = label(achieveFrame, "", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 48), Config.Palette.AcidGreen)

local achieveList = Instance.new("ScrollingFrame")
achieveList.Size = UDim2.new(1, -24, 1, -88)
achieveList.Position = UDim2.new(0, 12, 0, 80)
achieveList.BackgroundTransparency = 1
achieveList.BorderSizePixel = 0
achieveList.ScrollBarThickness = 6
achieveList.ScrollBarImageColor3 = Config.Palette.Butter
achieveList.CanvasSize = UDim2.new()
achieveList.AutomaticCanvasSize = Enum.AutomaticSize.Y
achieveList.Parent = achieveFrame

local achieveLayout = Instance.new("UIListLayout")
achieveLayout.Padding = UDim.new(0, 8)
achieveLayout.SortOrder = Enum.SortOrder.LayoutOrder
achieveLayout.Parent = achieveList

achieveToggle.MouseButton1Click:Connect(function()
	achieveFrame.Visible = not achieveFrame.Visible
	if achieveFrame.Visible then
		shopFrame.Visible = false

		Remotes.RequestAchievements:FireServer(true)
	end
end)

local function renderAchievements(payload)
	achieveTitle.Text = (Config.Text.RewardsTitle):format(payload.Done or 0, payload.Total or 0)
	achieveBonus.Text = (payload.Bonus or 0) > 0
		and (Config.Text.CollectionBonus):format(math.floor((payload.Bonus or 0) * 100))
		or Config.Text.CollectionHint

	for _, child in ipairs(achieveList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, item in ipairs(payload.Items or {}) do

		local fill = Config.Palette.Grape
		local edge = Config.Palette.CyberCyan
		if item.Unlocked then
			fill = item.Premium and Config.Palette.Butter or Config.Palette.AcidGreen
			edge = item.Premium and Config.Palette.ButterDeep or Config.Palette.Void
		end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 62)
		row.BackgroundColor3 = fill
		row.BackgroundTransparency = item.Unlocked and 0 or 0.55
		row.LayoutOrder = index
		row.Parent = achieveList
		corner(row, 12)
		stroke(row, item.Premium and 3 or 2, edge)

		local textColor = item.Unlocked and Config.Palette.Void or Config.Palette.White
		local name = label(row, item.Name, UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 4), textColor)
		name.TextXAlignment = Enum.TextXAlignment.Left

		local rewardText = item.Cash and ("+" .. Config.FormatNumber(item.Cash))
			or (item.Multiplier and ("+" .. math.floor(item.Multiplier * 100) .. "%") or "")
		local desc = label(row, ("%s   %s"):format(item.Desc, rewardText),
			UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 32), textColor)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextTransparency = 0.15
	end
end

local starterFrame = Instance.new("Frame")
starterFrame.Name = "StarterOffer"
starterFrame.AnchorPoint = Vector2.new(0.5, 0.5)
starterFrame.Position = UDim2.fromScale(0.5, 0.5)
starterFrame.Size = UDim2.fromOffset(430, 330)
starterFrame.BackgroundColor3 = Config.Palette.Void
starterFrame.Visible = false
starterFrame.ZIndex = 30
starterFrame.Parent = gui
corner(starterFrame, 20)
stroke(starterFrame, Config.Style.FrameStroke + 1, Config.Palette.Butter)
gradient(starterFrame, Config.Palette.Grape, Config.Palette.Void)

local starterTitle = label(starterFrame, "", UDim2.new(1, -24, 0, 46), UDim2.new(0, 12, 0, 12), Config.Palette.Butter)
starterTitle.ZIndex = 31

local starterIcon = Instance.new("ImageLabel")
starterIcon.AnchorPoint = Vector2.new(0.5, 0)
starterIcon.Position = UDim2.new(0.5, 0, 0, 62)
starterIcon.Size = UDim2.fromOffset(96, 96)
starterIcon.BackgroundTransparency = 1
starterIcon.ScaleType = Enum.ScaleType.Fit
starterIcon.ZIndex = 31
starterIcon.Parent = starterFrame

local starterPerks = Instance.new("Frame")
starterPerks.Position = UDim2.new(0, 20, 0, 166)
starterPerks.Size = UDim2.new(1, -40, 0, 74)
starterPerks.BackgroundTransparency = 1
starterPerks.ZIndex = 31
starterPerks.Parent = starterFrame

local perksLayout = Instance.new("UIListLayout")
perksLayout.Padding = UDim.new(0, 2)
perksLayout.SortOrder = Enum.SortOrder.LayoutOrder
perksLayout.Parent = starterPerks

local starterTimer = label(starterFrame, "", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 242), Config.Palette.CyberCyan)
starterTimer.ZIndex = 31

local starterBuy = button(starterFrame, "", UDim2.new(1, -120, 0, 54), UDim2.new(0, 20, 1, -66), Config.Palette.AcidGreen)
starterBuy.TextColor3 = Config.Palette.Void
starterBuy.ZIndex = 31

local starterBuyPad = Instance.new("UIPadding")
starterBuyPad.PaddingTop = UDim.new(0, 12)
starterBuyPad.PaddingBottom = UDim.new(0, 6)
starterBuyPad.Parent = starterBuy

local starterClose = button(starterFrame, "X", UDim2.new(0, 68, 0, 54), UDim2.new(1, -88, 1, -66), Config.Palette.HotRed)
starterClose.ZIndex = 31

local starterOffer = nil
local starterSecondsLeft = 0

local function showStarterOffer(offer)
	starterOffer = offer
	starterTitle.Text = offer.Title or offer.Name or ""
	starterIcon.Image = offer.Icon or ""
	starterIcon.Visible = offer.Icon ~= nil
	starterBuy.Text = Config.Text.ShopBuy
	starterSecondsLeft = offer.Seconds or 0

	for _, child in ipairs(starterPerks:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, perk in ipairs(offer.Perks or {}) do
		local line = label(starterPerks, "+ " .. perk, UDim2.new(1, 0, 0, 22), UDim2.new(), Config.Palette.White)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.LayoutOrder = index
		line.ZIndex = 31
	end

	starterFrame.Visible = true
	starterFrame.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(starterFrame, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(430, 330),
	}):Play()
end

local function hideStarterOffer()
	starterOffer = nil
	local out = TweenService:Create(starterFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(0, 0),
	})
	out.Completed:Once(function()
		starterFrame.Visible = false
	end)
	out:Play()
end

starterClose.MouseButton1Click:Connect(hideStarterOffer)
starterBuy.MouseButton1Click:Connect(function()
	if starterOffer then
		Remotes.RequestPurchase:FireServer(starterOffer.Kind, starterOffer.Key)
	end
end)

Remotes.StarterOffer.OnClientEvent:Connect(function(offer)
	showStarterOffer(offer)
	Sfx.Play("Offer")
end)

task.spawn(function()
	while true do
		task.wait(1)
		if starterOffer and starterFrame.Visible then
			starterSecondsLeft -= 1
			if starterSecondsLeft <= 0 then
				hideStarterOffer()
			else
				starterTimer.Text = ("Offer ends in %02d:%02d"):format(
					math.floor(starterSecondsLeft / 60), starterSecondsLeft % 60)
			end
		end
	end
end)

local displayed = 0
local target = 0

RunService.RenderStepped:Connect(function(dt)
	if math.abs(target - displayed) < 1 then
		displayed = target
	else

		displayed += (target - displayed) * math.clamp(dt * 8, 0, 1)
	end
	balanceLabel.Text = ("%s %s"):format(Config.Currency.Icon, Config.FormatNumber(displayed))
end)

local function pop(element: GuiObject, scale: number)
	local base = element.Size
	local big = UDim2.new(base.X.Scale * scale, base.X.Offset * scale, base.Y.Scale * scale, base.Y.Offset * scale)
	local up = TweenService:Create(element, TweenInfo.new(0.09, Enum.EasingStyle.Quad), { Size = big })
	up.Completed:Once(function()
		TweenService:Create(element, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = base }):Play()
	end)
	up:Play()
end

local toastOrder = 0

local function toast(text: string, color: Color3?, lifetime: number?)
	toastOrder += 1
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.BackgroundColor3 = Config.Palette.Void
	frame.BackgroundTransparency = 0.1
	frame.LayoutOrder = toastOrder
	frame.Parent = toastList
	corner(frame, 12)
	stroke(frame, Config.Style.FrameStroke, color or Config.Palette.CyberCyan)

	local text_ = label(frame, text, UDim2.new(1, -12, 1, -8), UDim2.new(0, 6, 0, 4), color or Config.Palette.White)
	TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 44) }):Play()

	task.delay(lifetime or 2.6, function()
		local out = TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) })
		TweenService:Create(text_, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		out.Completed:Once(function()
			frame:Destroy()
		end)
		out:Play()
	end)
end

local function floatGain(amount: number)
	local l = label(gui, (Config.Text.GainPopup):format(Config.FormatNumber(amount), Config.Currency.Icon),
		UDim2.new(0, 200, 0, 46), UDim2.new(0.5, -100, 0, 92), Config.Palette.AcidGreen)
	l.ZIndex = 5
	TweenService:Create(l, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -100, 0, 40),
		TextTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		l:Destroy()
	end)
end

local function purchasedPopup(text: string)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 0, 0, 0)
	frame.Position = UDim2.new(0.5, -190, 0.5, -60)
	frame.BackgroundColor3 = Config.Palette.AcidGreen
	frame.ZIndex = 8
	frame.Parent = gui
	corner(frame, 18)
	stroke(frame, Config.Style.FrameStroke, Config.Palette.Void)

	local l = label(frame, (Config.Text.Purchased):format(text), UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), Config.Palette.Void)
	l.ZIndex = 9

	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 380, 0, 120),
	}):Play()

	task.delay(1.5, function()
		local out = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 0) })
		out.Completed:Once(function()
			frame:Destroy()
		end)
		out:Play()
	end)
end

Remotes.CurrencyChanged.OnClientEvent:Connect(function(balance, multiplier)
	target = balance

	if multiplier and hasPlot then
		multLabel.Text = (Config.Text.IncomeShort):format(multiplier)
	end
end)

Remotes.ProductSold.OnClientEvent:Connect(function(amount)
	floatGain(amount)
	pop(balanceFrame, 1.06)
	Sfx.Play("Sell")
end)

Remotes.StationPurchased.OnClientEvent:Connect(function(_id, labelText)
	purchasedPopup(labelText or "Station")
	Sfx.Play("Purchase")
end)

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	toast(text, color)
	Sfx.Play(color == Config.Palette.HotRed and "Denied" or "Notify")
end)

Remotes.StateSync.OnClientEvent:Connect(function(state)
	target = state.Balance or target
	if state.OwnedPasses then
		applyOwnedPasses(state.OwnedPasses)
	end

	setIncomeShown(not state.NeedPlot)
	if not state.NeedPlot then
		multLabel.Text = (Config.Text.IncomeFull):format(state.Multiplier or 1, Config.FormatNumber(state.IncomePerMin or 0))
	end

	if state.NeedPlot then
		goalLabel.Text = Config.Text.GoalNeedPlot
		goalLabel.TextColor3 = Config.Palette.AcidGreen
	elseif state.Goal then
		local need = math.max(0, (state.Goal.Price or 0) - (state.Balance or 0))
		if need > 0 then

			goalLabel.Text = (Config.Text.GoalRemaining):format(state.Goal.Label, Config.FormatNumber(need))
			goalLabel.TextColor3 = Config.Palette.White
		else
			goalLabel.Text = (Config.Text.GoalAffordable):format(state.Goal.Label)
			goalLabel.TextColor3 = Config.Palette.AcidGreen
		end
	else
		local rebirthNeed = math.max(0, (state.RebirthCost or 0) - (state.Balance or 0))
		goalLabel.Text = (Config.Text.GoalAllBought):format(Config.FormatNumber(rebirthNeed), Config.Currency.Icon)
		goalLabel.TextColor3 = Config.Palette.Butter
	end

	rebirthButton.Text = (Config.Text.RebirthButtonFull):format(
		(state.Rebirths or 0) + 1, Config.FormatNumber(state.RebirthCost or 0), Config.Currency.Icon)
	rebirthButton.BackgroundColor3 = (state.Balance or 0) >= (state.RebirthCost or math.huge)
		and Config.Palette.AcidGreen or Config.Palette.Grape
end)

Remotes.AchievementSync.OnClientEvent:Connect(renderAchievements)

Remotes.AchievementUnlock.OnClientEvent:Connect(function(item)
	local reward = item.Cash and (Config.Text.RewardCash):format(Config.FormatNumber(item.Cash))
		or (item.Multiplier and (Config.Text.RewardBonus):format(math.floor(item.Multiplier * 100)) or "")
	toast(("%s\n%s"):format(item.Name, reward), Config.Palette.Butter, 3.4)
	pop(achieveToggle, 1.12)
	Sfx.Play("Achievement")
end)

rebirthButton.MouseButton1Click:Connect(function()
	Remotes.RequestRebirth:FireServer()
end)

local GetInventory   = Net.Func("GetInventory")
local BuyStation     = Net.Func("BuyStation")
local GetLeaderboard = Net.Func("GetLeaderboard")
local ConfirmAction  = Net.Func("ConfirmAction")

local function formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function formatPlaytime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	end
	return ("%dm"):format(minutes)
end

local function invoke(remote: RemoteFunction, ...)
	local ok, response = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	if not ok or type(response) ~= "table" then
		return nil
	end
	return response
end

local invToggle = button(gui, Config.Text.InventoryButton,
	UDim2.new(0, 200, 0, 62), UDim2.new(1, -216, 1, -290), Config.Palette.CyberCyan)
invToggle.TextColor3 = Config.Palette.Void

local invFrame = Instance.new("Frame")
invFrame.BackgroundColor3 = Config.Palette.Void
invFrame.Visible = false
invFrame.Parent = gui
centrePanel(invFrame)
corner(invFrame, 18)
stroke(invFrame, Config.Style.FrameStroke, Config.Palette.CyberCyan)

local invTitle = label(invFrame, Config.Text.InventoryTitle,
	UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 8), Config.Palette.CyberCyan)

local invList = Instance.new("ScrollingFrame")
invList.Size = UDim2.new(1, -24, 1, -62)
invList.Position = UDim2.new(0, 12, 0, 54)
invList.BackgroundTransparency = 1
invList.BorderSizePixel = 0
invList.ScrollBarThickness = 6
invList.ScrollBarImageColor3 = Config.Palette.CyberCyan
invList.CanvasSize = UDim2.new()
invList.AutomaticCanvasSize = Enum.AutomaticSize.Y
invList.Parent = invFrame

local invLayout = Instance.new("UIListLayout")
invLayout.Padding = UDim.new(0, 6)
invLayout.SortOrder = Enum.SortOrder.LayoutOrder
invLayout.Parent = invList

local invOrder = 0
local function nextOrder(): number
	invOrder += 1
	return invOrder
end

local function sectionHeader(text: string)
	local header = label(invList, text, UDim2.new(1, -8, 0, 30), UDim2.new(), Config.Palette.Butter)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = nextOrder()
	return header
end

local function statRow(name: string, value: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 34)
	row.BackgroundColor3 = Config.Palette.Grape
	row.BackgroundTransparency = 0.55
	row.LayoutOrder = nextOrder()
	row.Parent = invList
	corner(row, 10)

	local left = label(row, name, UDim2.new(0.58, -10, 1, -8), UDim2.new(0, 10, 0, 4), Config.Palette.White)
	left.TextXAlignment = Enum.TextXAlignment.Left

	local right = label(row, value, UDim2.new(0.42, -10, 1, -8), UDim2.new(0.58, 0, 0, 4), Config.Palette.CyberCyan)
	right.TextXAlignment = Enum.TextXAlignment.Right
	return row
end

local refreshInventory

local function stationRow(item)
	local fill = Config.Palette.Grape
	if item.Owned then
		fill = Config.Palette.AcidGreen
	elseif item.Available then
		fill = Config.Palette.ButterDeep
	end

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 52)
	row.BackgroundColor3 = fill
	row.BackgroundTransparency = item.Owned and 0.05 or 0.45
	row.LayoutOrder = nextOrder()
	row.Parent = invList
	corner(row, 10)

	local textColor = item.Owned and Config.Palette.Void or Config.Palette.White
	local name = label(row, item.Label, UDim2.new(1, -140, 0, 26), UDim2.new(0, 10, 0, 3), textColor)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local note
	if item.Owned then
		note = Config.Text.PassOwned
	elseif item.LockedBy then
		note = ("%s %d"):format(Config.Text.StatRebirths, item.LockedBy)
	else
		note = Config.FormatNumber(item.Price)
	end
	local desc = label(row, note, UDim2.new(1, -140, 0, 20), UDim2.new(0, 10, 0, 28), textColor)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextTransparency = 0.2

	if not item.Owned and item.Available then
		local buy = button(row, Config.Text.BuyButton,
			UDim2.fromOffset(112, 38), UDim2.new(1, -122, 0.5, -19), Config.Palette.AcidGreen)
		buy.TextColor3 = Config.Palette.Void
		buy.MouseButton1Click:Connect(function()
			buy.Active = false
			local response = invoke(BuyStation, item.Id)
			if response and response.Ok then

				refreshInventory()
			else
				buy.Active = true
				toast(response and response.Reason or Config.Text.NetError, Config.Palette.HotRed)
			end
		end)
	end
	return row
end

local function passRow(item)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 46)
	row.BackgroundColor3 = item.Owned and Config.Palette.Butter or Config.Palette.Grape
	row.BackgroundTransparency = item.Owned and 0.05 or 0.6
	row.LayoutOrder = nextOrder()
	row.Parent = invList
	corner(row, 10)

	if item.Icon then
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 8, 0.5, 0)
		icon.Size = UDim2.fromOffset(34, 34)
		icon.BackgroundTransparency = 1
		icon.Image = item.Icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ImageTransparency = item.Owned and 0 or 0.5
		icon.Parent = row
	end

	local textColor = item.Owned and Config.Palette.Void or Config.Palette.White
	local name = label(row, item.Name, UDim2.new(1, -160, 1, -10), UDim2.new(0, 50, 0, 5), textColor)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local state = label(row, item.Owned and Config.Text.PassOwned or Config.Text.PassLocked,
		UDim2.fromOffset(100, 26), UDim2.new(1, -110, 0.5, -13), textColor)
	state.TextXAlignment = Enum.TextXAlignment.Right
	return row
end

local function renderInventory(data)
	for _, child in ipairs(invList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	invOrder = 0

	if not data or not data.Ok then
		local empty = label(invList, (data and data.Reason) or Config.Text.NetError,
			UDim2.new(1, -8, 0, 30), UDim2.new(), Config.Palette.HotRed)
		empty.LayoutOrder = nextOrder()
		return
	end

	invTitle.Text = Config.Text.InventoryTitle

	sectionHeader((Config.Text.InvLine):format(data.OwnedCount or 0, data.LineSize or 0))
	for _, item in ipairs(data.Stations or {}) do
		stationRow(item)
	end

	sectionHeader(Config.Text.InvPasses)
	for _, item in ipairs(data.Passes or {}) do
		passRow(item)
	end

	sectionHeader(Config.Text.InvStats)
	statRow(Config.Text.StatMultiplier, ("x%.2f"):format(data.Multiplier or 1))
	statRow(Config.Text.StatIncome, Config.FormatNumber(data.IncomePerMin or 0))
	statRow(Config.Text.StatEarned, Config.FormatNumber(data.TotalEarned or 0))
	statRow(Config.Text.StatSold, Config.FormatNumber(data.SoldCount or 0))
	statRow(Config.Text.StatRebirths, tostring(data.Rebirths or 0))
	statRow(Config.Text.StatPlaytime, formatPlaytime(data.Playtime or 0))
	if (data.BoostLeft or 0) > 0 then
		statRow(Config.Text.StatBoost, formatClock(data.BoostLeft))
	end
end

local inventoryBusy = false
function refreshInventory()
	if inventoryBusy then
		return
	end
	inventoryBusy = true
	task.spawn(function()
		local response = invoke(GetInventory)
		inventoryBusy = false
		if not invFrame.Visible then
			return
		end

		if response == nil and invOrder > 0 then
			return
		end
		renderInventory(response)
	end)
end

invToggle.MouseButton1Click:Connect(function()
	invFrame.Visible = not invFrame.Visible
	if invFrame.Visible then

		invTitle.Text = Config.Text.InvLoading
		refreshInventory()
	end
end)

task.spawn(function()
	while true do
		task.wait(3)
		if invFrame.Visible then
			refreshInventory()
		end
	end
end)

local topToggle = button(gui, Config.Text.LeaderButton,
	UDim2.new(0, 200, 0, 62), UDim2.new(0, 16, 0, 96), Config.Palette.Grape)

local boardFrame = Instance.new("Frame")
boardFrame.BackgroundColor3 = Config.Palette.Void
boardFrame.Visible = false
boardFrame.Parent = gui
corner(boardFrame, 18)
stroke(boardFrame, Config.Style.FrameStroke, Config.Palette.Grape)
centrePanel(boardFrame)

label(boardFrame, Config.Text.LeaderTitle, UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 8), Config.Palette.Butter)

local boardList = Instance.new("ScrollingFrame")
boardList.Size = UDim2.new(1, -24, 1, -62)
boardList.Position = UDim2.new(0, 12, 0, 54)
boardList.BackgroundTransparency = 1
boardList.BorderSizePixel = 0
boardList.ScrollBarThickness = 6
boardList.ScrollBarImageColor3 = Config.Palette.Grape
boardList.CanvasSize = UDim2.new()
boardList.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardList.Parent = boardFrame

local boardLayout = Instance.new("UIListLayout")
boardLayout.Padding = UDim.new(0, 6)
boardLayout.SortOrder = Enum.SortOrder.LayoutOrder
boardLayout.Parent = boardList

local function leaderRow(index: number, row, isMe: boolean)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 58)
	frame.BackgroundColor3 = isMe and Config.Palette.AcidGreen or Config.Palette.Grape
	frame.BackgroundTransparency = isMe and 0.05 or 0.55
	frame.LayoutOrder = index
	frame.Parent = boardList
	corner(frame, 12)
	if isMe then
		stroke(frame, 3, Config.Palette.Butter)
	end

	local textColor = isMe and Config.Palette.Void or Config.Palette.White

	label(frame, tostring(index), UDim2.fromOffset(42, 32), UDim2.new(0, 10, 0.5, -16),
		(index <= 3 and not isMe) and Config.Palette.Butter or textColor)

	local name = tostring(row.Name or "?")
	if isMe then
		name = ("%s (%s)"):format(name, Config.Text.LeaderYou)
	end
	local nameLabel = label(frame, name, UDim2.new(1, -215, 0, 28), UDim2.new(0, 58, 0, 5), textColor)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local sub = label(frame, ("%s %d"):format(Config.Text.StatRebirths, row.Rebirths or 0),
		UDim2.new(1, -215, 0, 20), UDim2.new(0, 58, 0, 33), textColor)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextTransparency = 0.25

	local value = label(frame, Config.FormatNumber(row.Currency or 0),
		UDim2.fromOffset(140, 32), UDim2.new(1, -150, 0.5, -16),
		isMe and Config.Palette.Void or Config.Palette.CyberCyan)
	value.TextXAlignment = Enum.TextXAlignment.Right
end

local function renderLeaderboard(rows)
	for _, child in ipairs(boardList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	if not rows or #rows == 0 then
		local empty = label(boardList, Config.Text.LeaderEmpty,
			UDim2.new(1, -8, 0, 30), UDim2.new(), Config.Palette.SteelLight)
		empty.LayoutOrder = 1
		return
	end

	for index, row in ipairs(rows) do
		leaderRow(index, row, row.UserId == player.UserId)
	end
end

local boardBusy = false
local function refreshLeaderboard()
	if boardBusy then
		return
	end
	boardBusy = true
	task.spawn(function()
		local response = invoke(GetLeaderboard)
		boardBusy = false
		if not boardFrame.Visible or response == nil then
			return
		end
		renderLeaderboard(response.Ok and response.Rows or nil)
	end)
end

local panels = { shopFrame, achieveFrame, invFrame, boardFrame }

local function closeOthers(keep: GuiObject)
	for _, panel in ipairs(panels) do
		if panel ~= keep then
			panel.Visible = false
		end
	end
end

shopToggle.MouseButton1Click:Connect(function()
	if shopFrame.Visible then
		closeOthers(shopFrame)
	end
end)
achieveToggle.MouseButton1Click:Connect(function()
	if achieveFrame.Visible then
		closeOthers(achieveFrame)
	end
end)
invToggle.MouseButton1Click:Connect(function()
	if invFrame.Visible then
		closeOthers(invFrame)
	end
end)

topToggle.MouseButton1Click:Connect(function()
	boardFrame.Visible = not boardFrame.Visible
	if boardFrame.Visible then
		closeOthers(boardFrame)
		refreshLeaderboard()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.Leaderboard.Refresh)
		if boardFrame.Visible then
			refreshLeaderboard()
		end
	end
end)

local feedList = Instance.new("Frame")
feedList.Size = UDim2.fromOffset(330, 140)
feedList.AnchorPoint = Vector2.new(0, 1)
feedList.Position = UDim2.new(0, 16, 1, -16)
feedList.BackgroundTransparency = 1
feedList.Parent = gui

local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding = UDim.new(0, 4)
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
feedLayout.Parent = feedList

local feedOrder = 0

local function pushFeed(entry)
	if type(entry) ~= "table" or type(entry.Text) ~= "string" then
		return
	end

	local lines = {}
	for _, child in ipairs(feedList:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #lines >= Config.Feed.MaxLines do
		local oldest = table.remove(lines, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	feedOrder += 1
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = Config.Palette.Void
	row.BackgroundTransparency = 0.25
	row.LayoutOrder = feedOrder
	row.Parent = feedList
	corner(row, 8)

	local color = typeof(entry.Color) == "Color3" and entry.Color or Config.Palette.CyberCyan
	stroke(row, 2, color)

	local text = label(row, entry.Text, UDim2.new(1, -12, 1, -6), UDim2.new(0, 6, 0, 3), color)
	text.TextXAlignment = Enum.TextXAlignment.Left

	row.Position = UDim2.new(-1, 0, 0, 0)
	TweenService:Create(row, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	task.delay(Config.Feed.Lifetime, function()
		if not row.Parent then
			return
		end
		local out = TweenService:Create(row, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		TweenService:Create(text, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		out.Completed:Once(function()
			row:Destroy()
		end)
		out:Play()
	end)
end

Net.Event("Broadcast").OnClientEvent:Connect(pushFeed)

local confirmFrame = Instance.new("Frame")
confirmFrame.AnchorPoint = Vector2.new(0.5, 0.5)
confirmFrame.Position = UDim2.fromScale(0.5, 0.5)
confirmFrame.Size = UDim2.fromOffset(430, 250)
confirmFrame.BackgroundColor3 = Config.Palette.Void
confirmFrame.Visible = false
confirmFrame.ZIndex = 40
confirmFrame.Parent = gui
corner(confirmFrame, 20)
stroke(confirmFrame, Config.Style.FrameStroke + 1, Config.Palette.Grape)
gradient(confirmFrame, Config.Palette.Grape, Config.Palette.Void)

local confirmTitle = label(confirmFrame, "", UDim2.new(1, -24, 0, 52), UDim2.new(0, 12, 0, 14), Config.Palette.Butter)
confirmTitle.ZIndex = 41

local confirmBody = label(confirmFrame, "", UDim2.new(1, -40, 0, 80), UDim2.new(0, 20, 0, 72), Config.Palette.White)
confirmBody.ZIndex = 41

local confirmYes = button(confirmFrame, "", UDim2.new(0, 190, 0, 56), UDim2.new(0, 20, 1, -72), Config.Palette.AcidGreen)
confirmYes.TextColor3 = Config.Palette.Void
confirmYes.ZIndex = 41

local confirmNo = button(confirmFrame, "", UDim2.new(0, 190, 0, 56), UDim2.new(1, -210, 1, -72), Config.Palette.HotRed)
confirmNo.ZIndex = 41

local confirmAnswer: boolean? = nil

local function closeConfirm(answer: boolean)
	confirmAnswer = answer
	confirmFrame.Visible = false
end

confirmYes.MouseButton1Click:Connect(function()
	closeConfirm(true)
end)
confirmNo.MouseButton1Click:Connect(function()
	closeConfirm(false)
end)

ConfirmAction.OnClientInvoke = function(payload)
	if type(payload) ~= "table" then
		return false
	end

	confirmTitle.Text = tostring(payload.Title or "")
	confirmBody.Text = tostring(payload.Body or "")
	confirmYes.Text = tostring(payload.Yes or Config.Text.ConfirmYes)
	confirmNo.Text = tostring(payload.No or Config.Text.ConfirmNo)

	confirmAnswer = nil
	confirmFrame.Visible = true
	confirmFrame.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(confirmFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(430, 250),
	}):Play()

	local deadline = os.clock() + Config.Net.InvokeTimeout - 2
	while confirmAnswer == nil and os.clock() < deadline do
		task.wait(0.05)
	end

	if confirmAnswer == nil then
		closeConfirm(false)
	end
	return confirmAnswer == true
end

local goalBuy = button(gui, Config.Text.BuyButton,
	UDim2.fromOffset(96, 46), UDim2.new(0.5, 176, 0, 94), Config.Palette.AcidGreen)
goalBuy.TextColor3 = Config.Palette.Void
goalBuy.Visible = false

local currentGoalId: string? = nil
local lastRebirths: number? = nil

goalBuy.MouseButton1Click:Connect(function()
	local goalId = currentGoalId
	if not goalId then
		return
	end
	goalBuy.Visible = false
	task.spawn(function()
		local response = invoke(BuyStation, goalId)
		if not (response and response.Ok) then
			toast(response and response.Reason or Config.Text.NetError, Config.Palette.HotRed)
		end

	end)
end)

Net.Event("StateSync").OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end
	local rebirths = state.Rebirths or 0
	if lastRebirths and rebirths > lastRebirths then
		Sfx.Play("Rebirth")
	end
	lastRebirths = rebirths

	currentGoalId = state.Goal and state.Goal.Id or nil

	goalBuy.Visible = currentGoalId ~= nil
		and not state.NeedPlot
		and (state.Balance or 0) >= (state.Goal.Price or math.huge)
end)

task.defer(function()
	Remotes.RequestState:FireServer()
	Remotes.RequestAchievements:FireServer()
end)
