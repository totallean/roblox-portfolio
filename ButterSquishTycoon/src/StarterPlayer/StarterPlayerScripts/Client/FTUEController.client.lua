local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ftueCfg = Config.FTUE
local cursorCfg = ftueCfg.Cursor
local goalCfg = ftueCfg.GoalArrow

local currentStep = 0
local goalId: string? = nil
local stepCount = 0
for index in pairs(ftueCfg.Steps) do
	stepCount = math.max(stepCount, index)
end

local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "FTUEOverlay"
overlayGui.ResetOnSpawn = false
overlayGui.IgnoreGuiInset = true
overlayGui.DisplayOrder = 20
overlayGui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = ftueCfg.Overlay.Color
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Active = false
dim.Visible = false
dim.Parent = overlayGui

local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, ftueCfg.Banner.PositionScale)
banner.Size = UDim2.new(0.72, 0, 0, ftueCfg.Banner.Height)
banner.BackgroundTransparency = 1
banner.Font = Config.Style.Font
banner.TextScaled = true
banner.Text = ""
banner.TextColor3 = ftueCfg.Banner.Color
banner.Visible = false
banner.Parent = overlayGui

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Config.Style.StrokeColor
bannerStroke.Thickness = Config.Style.WorldStroke + 0.6
bannerStroke.Parent = banner

local stepChip = Instance.new("TextLabel")
stepChip.Name = "StepChip"
stepChip.AnchorPoint = Vector2.new(0.5, 0)
stepChip.Position = UDim2.new(0.5, 0, ftueCfg.Banner.PositionScale, ftueCfg.Banner.Height * 0.55)
stepChip.Size = UDim2.new(0, 150, 0, 30)
stepChip.BackgroundTransparency = 1
stepChip.Font = Config.Style.Font
stepChip.TextScaled = true
stepChip.Text = ""
stepChip.TextColor3 = Config.Palette.Butter
stepChip.Visible = false
stepChip.Parent = overlayGui

local chipStroke = Instance.new("UIStroke")
chipStroke.Color = Config.Style.StrokeColor
chipStroke.Thickness = Config.Style.WorldStroke
chipStroke.Parent = stepChip

local pointerGui = Instance.new("ScreenGui")
pointerGui.Name = "FTUEPointer"
pointerGui.ResetOnSpawn = false
pointerGui.IgnoreGuiInset = true
pointerGui.DisplayOrder = 21
pointerGui.Parent = playerGui

local origin = Instance.new("Frame")
origin.Name = "Origin"
origin.Size = UDim2.fromScale(1, 1)
origin.BackgroundTransparency = 1
origin.Active = false
origin.Parent = pointerGui

local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.AnchorPoint = Vector2.new(0.5, 0.5)

ring.BackgroundColor3 = cursorCfg.RingColor
ring.BackgroundTransparency = 0.82
ring.BorderSizePixel = 0
ring.Active = false
ring.Visible = false
ring.Parent = pointerGui

local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(0, 14)
ringCorner.Parent = ring

local ringStroke = Instance.new("UIStroke")
ringStroke.Color = cursorCfg.RingColor
ringStroke.Thickness = 4
ringStroke.Parent = ring

local cursor = Instance.new("TextLabel")
cursor.Name = "Cursor"

cursor.AnchorPoint = Vector2.new(0.5, 1)
cursor.Size = UDim2.fromOffset(cursorCfg.Size, cursorCfg.Size)
cursor.BackgroundTransparency = 1
cursor.Font = Config.Style.Font
cursor.TextScaled = true
cursor.Text = cursorCfg.Glyph
cursor.TextColor3 = cursorCfg.Color
cursor.Active = false
cursor.Visible = false
cursor.Parent = pointerGui

local goalAnchor: Part? = nil
local goalBillboard: BillboardGui? = nil
local goalHighlight: Highlight? = nil

if goalCfg.Enabled then
	goalAnchor = Instance.new("Part")
	goalAnchor.Name = "GoalArrow_Anchor"
	goalAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	goalAnchor.Transparency = 1
	goalAnchor.Anchored = true
	goalAnchor.CanCollide = false
	goalAnchor.CanTouch = false
	goalAnchor.CanQuery = false
	goalAnchor.Locked = true
	goalAnchor.CFrame = CFrame.new(0, -1000, 0)
	goalAnchor.Parent = workspace

	goalBillboard = Instance.new("BillboardGui")
	goalBillboard.Name = "GoalArrow"
	goalBillboard.Adornee = goalAnchor

	goalBillboard.AlwaysOnTop = false
	goalBillboard.Size = UDim2.fromScale(8, 8)
	goalBillboard.MaxDistance = 340
	goalBillboard.Enabled = false
	goalBillboard.Parent = goalAnchor

	local goalHand = Instance.new("TextLabel")
	goalHand.Size = UDim2.fromScale(1, 0.7)
	goalHand.BackgroundTransparency = 1
	goalHand.Font = Config.Style.Font
	goalHand.TextScaled = true
	goalHand.Text = cursorCfg.Glyph
	goalHand.TextColor3 = goalCfg.Color
	goalHand.Parent = goalBillboard

	local goalHandStroke = Instance.new("UIStroke")
	goalHandStroke.Color = Config.Style.StrokeColor
	goalHandStroke.Thickness = Config.Style.WorldStroke
	goalHandStroke.Parent = goalHand

	local goalCaption = Instance.new("TextLabel")
	goalCaption.Name = "Caption"
	goalCaption.Size = UDim2.fromScale(1, 0.3)
	goalCaption.Position = UDim2.fromScale(0, 0.7)
	goalCaption.BackgroundTransparency = 1
	goalCaption.Font = Config.Style.Font
	goalCaption.TextScaled = true
	goalCaption.Text = Config.Text.GoalArrow
	goalCaption.TextColor3 = goalCfg.Color
	goalCaption.Parent = goalBillboard

	local goalCaptionStroke = Instance.new("UIStroke")
	goalCaptionStroke.Color = Config.Style.StrokeColor
	goalCaptionStroke.Thickness = Config.Style.WorldStroke
	goalCaptionStroke.Parent = goalCaption

	goalHighlight = Instance.new("Highlight")
	goalHighlight.Name = "GoalHighlight"
	goalHighlight.FillColor = goalCfg.Color
	goalHighlight.FillTransparency = 0.85
	goalHighlight.OutlineColor = goalCfg.Color
	goalHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	goalHighlight.Enabled = false
	goalHighlight.Parent = playerGui
end

local tutorialHighlight = Instance.new("Highlight")
tutorialHighlight.Name = "FTUEHighlight"
tutorialHighlight.FillColor = Config.Palette.Butter
tutorialHighlight.FillTransparency = 0.72
tutorialHighlight.OutlineColor = Config.Palette.ToxicPink
tutorialHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
tutorialHighlight.Enabled = false
tutorialHighlight.Parent = playerGui

local function findOwnPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function findNearestClaimPad(): (BasePart?, Instance?)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	local bestPad, bestSlot, bestDistance = nil, nil, math.huge
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == 0 then
			local triggers = plot:FindFirstChild("Triggers")
			local visuals = plot:FindFirstChild("Visuals")
			local trigger = triggers and triggers:FindFirstChild("ClaimPad")
			local slot = visuals and visuals:FindFirstChild("Slot_ClaimPad")
			if trigger and trigger.CanTouch and slot then
				local distance = root and (root.Position - trigger.Position).Magnitude or 0
				if distance < bestDistance then
					bestDistance, bestPad, bestSlot = distance, trigger, slot
				end
			end
		end
	end
	return bestPad, bestSlot
end

local function findGoalButton(plot: Model): (BasePart?, Instance?)
	local buttons = plot:FindFirstChild("Buttons")
	if not buttons then
		return nil, nil
	end
	local function pick(id: string)
		local slot = buttons:FindFirstChild("Slot_BuyButton_" .. id)
		if slot and slot:GetAttribute("Shown") == true and slot.PrimaryPart then
			return slot.PrimaryPart, slot
		end
		return nil, nil
	end
	if goalId then
		local part, model = pick(goalId)
		if part then
			return part, model
		end
	end
	for _, def in ipairs(Config.Stations) do
		local part, model = pick(def.Id)
		if part then
			return part, model
		end
	end

	return nil, nil
end

local function findAchievementsButton(): GuiObject?
	local gui = playerGui:FindFirstChild("ButterUI")
	if not gui then
		return nil
	end
	for _, child in ipairs(gui:GetChildren()) do

		if child:IsA("TextButton") and child.Text == Config.Text.RewardsButton then
			return child
		end
	end
	return nil
end

local function resolveTarget(step: number)
	local info = ftueCfg.Steps[step]
	if not info then
		return nil, nil, nil
	end

	if info.Target == "Achievements" then
		return nil, nil, findAchievementsButton()
	end

	local plot = findOwnPlot()
	if info.Target == "Claim" then
		if plot then
			local sign = plot.Visuals:FindFirstChild("OwnerSign")
			return sign, sign, nil
		end
		local pad, slot = findNearestClaimPad()
		return pad, slot, nil
	end
	if not plot then
		return nil, nil, nil
	end
	if info.Target == "Collector" then
		local collector = plot.Visuals:FindFirstChild("Slot_Collector")
		return collector and collector.PrimaryPart, collector, nil
	end
	if info.Target == "NextButton" then
		local part, model = findGoalButton(plot)
		return part, model, nil
	end
	return nil, nil, nil
end

local function applyStep(step: number)
	currentStep = step
	local info = ftueCfg.Steps[step]

	if not info then

		TweenService:Create(dim, TweenInfo.new(ftueCfg.Overlay.FadeTime), { BackgroundTransparency = 1 }):Play()
		task.delay(ftueCfg.Overlay.FadeTime, function()
			if not ftueCfg.Steps[currentStep] then
				dim.Visible = false
			end
		end)
		banner.Visible = false
		stepChip.Visible = false
		ring.Visible = false
		cursor.Visible = false
		tutorialHighlight.Enabled = false
		return
	end

	banner.Text = info.Text
	banner.Visible = true
	stepChip.Text = (Config.Text.StepCounter):format(step, stepCount)
	stepChip.Visible = true
	Sfx.Play("Notify")

	banner.TextTransparency = 1
	TweenService:Create(banner, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

	if info.Dim then
		dim.Visible = true
		TweenService:Create(dim, TweenInfo.new(ftueCfg.Overlay.FadeTime), {
			BackgroundTransparency = ftueCfg.Overlay.Transparency,
		}):Play()
	else
		TweenService:Create(dim, TweenInfo.new(ftueCfg.Overlay.FadeTime), { BackgroundTransparency = 1 }):Play()
		task.delay(ftueCfg.Overlay.FadeTime, function()
			local current = ftueCfg.Steps[currentStep]
			if not current or not current.Dim then
				dim.Visible = false
			end
		end)
	end
end

Remotes.FTUEStep.OnClientEvent:Connect(applyStep)

Remotes.StateSync.OnClientEvent:Connect(function(state)
	goalId = state.Goal and state.Goal.Id or nil
end)

local retargetAccum = 0
local bobTime = 0
local worldTarget: BasePart? = nil
local guiTarget: GuiObject? = nil
local goalTarget: BasePart? = nil
local goalLift = 0

local function liftFor(part: BasePart?, clearance: number): number
	if not part then
		return clearance
	end
	return part.Size.Y * 0.5 + clearance
end

local function placePointer(centre: Vector2, size: Vector2, bob: number)
	ring.Position = UDim2.fromOffset(centre.X, centre.Y)
	ring.Size = UDim2.fromOffset(size.X + cursorCfg.RingPad * 2, size.Y + cursorCfg.RingPad * 2)
	ring.Visible = true

	cursor.Position = UDim2.fromOffset(centre.X, centre.Y - size.Y * 0.5 - cursorCfg.RingPad + bob)
	cursor.Visible = true
end

RunService.RenderStepped:Connect(function(dt)
	bobTime += dt
	retargetAccum += dt

	if retargetAccum >= 0.35 then
		retargetAccum = 0

		if ftueCfg.Steps[currentStep] then
			worldTarget, guiTarget = nil, nil
			local part, highlight, gui = resolveTarget(currentStep)
			worldTarget, guiTarget = part, gui
			tutorialHighlight.Adornee = highlight
			tutorialHighlight.Enabled = highlight ~= nil
		else
			worldTarget, guiTarget = nil, nil
			tutorialHighlight.Enabled = false
		end

		if goalBillboard then
			local goalPart, goalModel = nil, nil
			local info = ftueCfg.Steps[currentStep]
			if not (info and info.Target == "NextButton") then
				local plot = findOwnPlot()
				if plot then
					goalPart, goalModel = findGoalButton(plot)
				end
			end
			goalTarget = goalPart
			goalLift = liftFor(goalPart, goalCfg.Clearance)
			goalBillboard.Enabled = goalPart ~= nil
			goalHighlight.Adornee = goalModel
			goalHighlight.Enabled = goalModel ~= nil
			if not goalPart and goalAnchor then
				goalAnchor.CFrame = CFrame.new(0, -1000, 0)
			end
		end
	end

	local pulse = 0.5 + 0.5 * math.sin(bobTime * cursorCfg.Speed)
	ringStroke.Transparency = 0.15 + pulse * 0.45
	local bob = math.sin(bobTime * cursorCfg.Speed) * cursorCfg.Bob

	if guiTarget and guiTarget.Visible then
		local centre = guiTarget.AbsolutePosition + guiTarget.AbsoluteSize * 0.5 - origin.AbsolutePosition
		placePointer(centre, guiTarget.AbsoluteSize, bob)
	elseif worldTarget and worldTarget.Parent and workspace.CurrentCamera then
		local viewport, onScreen = workspace.CurrentCamera:WorldToViewportPoint(worldTarget.Position)
		if onScreen and viewport.Z > 0 then
			local inset = GuiService:GetGuiInset()
			local centre = Vector2.new(viewport.X, viewport.Y + inset.Y)

			local scale = math.clamp(900 / math.max(viewport.Z, 1), 30, 220)
			placePointer(centre, Vector2.new(scale, scale * 0.6), bob)
		else
			ring.Visible = false
			cursor.Visible = false
		end
	else
		ring.Visible = false
		cursor.Visible = false
	end

	if goalAnchor and goalTarget and goalTarget.Parent then
		local goalBob = math.sin(bobTime * goalCfg.Speed) * goalCfg.Bob
		goalAnchor.CFrame = CFrame.new(goalTarget.Position + Vector3.new(0, goalLift + goalBob, 0))
	end
end)
