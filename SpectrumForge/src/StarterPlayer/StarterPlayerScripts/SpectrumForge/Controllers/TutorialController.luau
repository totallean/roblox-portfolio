--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eco = require(ReplicatedStorage.SpectrumForge.Shared.EconomyConfig)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local TutorialController = {}

local State, UI, Locale

local STEPS = {
	{ target = "hotbar.charge", text = "tut.1", hint = "tut.1.hint" },
	{ target = "menu.ring",     text = "tut.2", hint = "tut.2.hint" },
	{ target = "hotbar.crate",  text = "tut.3", hint = "tut.3.hint" },
	{ target = "menu.build",    text = "tut.4", hint = "tut.4.hint" },
	{ target = "hotbar.fight",  text = "tut.5", hint = "tut.5.hint" },
	{ target = "menu.rebirth",  text = "tut.6", hint = "tut.6.hint" },
}

local TAPS_REQUIRED = 5
local REBIRTH_STEP = 6
local FADE = TweenInfo.new(0.4)

local panel: Frame
local panelStroke: UIStroke?
local textLabel: TextLabel
local hintLabel: TextLabel
local stepLabel: TextLabel

local current = 0
local taps = 0
local shown = false
local highlight: UIStroke? = nil
local pulseConn: RBXScriptConnection? = nil
local watchers: { any } = {}

local watchStep: () -> ()

local function clearHighlight()
	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
end

local function highlightTarget(name: string)
	local button = UI:FindButton(name)
	if highlight and button and highlight.Parent == button then
		return
	end

	clearHighlight()
	if not button then
		return
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "TutorialHighlight"
	stroke.Thickness = 3
	stroke.Color = Theme.Color.Xp
	stroke.Transparency = 0
	stroke.Parent = button
	highlight = stroke

	local t0 = os.clock()
	pulseConn = RunService.RenderStepped:Connect(function()
		local wave = (math.sin((os.clock() - t0) * 5) + 1) * 0.5
		stroke.Transparency = 0.15 + wave * 0.5
		stroke.Thickness = 2.5 + wave * 1.5
	end)
end

local function setShown(visible: boolean)
	if visible == shown then
		return
	end
	shown = visible

	if visible then
		panel.Visible = true
	end
	TweenService:Create(panel, FADE, {
		BackgroundTransparency = if visible then Theme.PanelTransparency else 1,
	}):Play()
	for _, l in { textLabel, hintLabel, stepLabel } do
		TweenService:Create(l, FADE, { TextTransparency = if visible then 0 else 1 }):Play()
	end
	if panelStroke then
		TweenService:Create(panelStroke, FADE, { Transparency = if visible then 0.25 else 1 }):Play()
	end
	if not visible then
		task.delay(0.5, function()
			if not shown then
				panel.Visible = false
			end
		end)
	end
end

local function rebirthReady(): boolean
	local rebirths = State:Get("rebirths") or 0
	return (State:Get("ringLevel") or 1) >= Eco.rebirthRequirement(rebirths + 1)
end

local function finish(quiet: boolean?)
	current = #STEPS + 1
	clearHighlight()
	for _, conn in watchers do
		conn:Disconnect()
	end
	table.clear(watchers)

	UI:SetCaptionsVisible(false)
	setShown(false)

	if not quiet then
		UI:Toast(Locale:Get("tut.done"), Theme.Color.Positive)
	end
end

local function render()
	local info = STEPS[current]
	stepLabel.Text = Locale:Get("tut.step", current, #STEPS)
	textLabel.Text = Locale:Get(info.text)

	if current == 1 then
		hintLabel.Text = Locale:Get(info.hint, math.max(0, TAPS_REQUIRED - taps))
	elseif current == REBIRTH_STEP then
		local tier, at = Eco.nextColorUnlock(State:Get("rebirths") or 0)
		hintLabel.Text = if tier then Locale:Get(info.hint, Locale:ColorName(tier), at) else ""
	else
		hintLabel.Text = Locale:Get(info.hint)
	end
end

local function show(step: number)
	if step > #STEPS then
		finish()
		return
	end

	current = step
	render()

	if step == REBIRTH_STEP and not rebirthReady() then
		clearHighlight()
		setShown(false)
		return
	end

	setShown(true)
	highlightTarget(STEPS[step].target)
end

local function advance()
	local done = current
	taps = 0
	State:Send("TutorialStep", done)
	show(done + 1)
	watchStep()
end

function watchStep()
	for _, conn in watchers do
		conn:Disconnect()
	end
	table.clear(watchers)

	if current == 1 then
		local button = UI:FindButton("hotbar.charge")
		if button and button:IsA("TextButton") then
			table.insert(watchers, button.MouseButton1Click:Connect(function()
				taps += 1
				hintLabel.Text = Locale:Get("tut.1.hint", math.max(0, TAPS_REQUIRED - taps))
				if taps >= TAPS_REQUIRED then
					advance()
				end
			end))
		end

	elseif current == 2 then
		local start = State:Get("ringLevel") or 1
		table.insert(watchers, State:Observe("ringLevel", function(level)
			if level > start and current == 2 then
				advance()
			end
		end))

	elseif current == 4 then
		local panels = UI:GetScreen():FindFirstChild("PanelLayer")
		local build = panels and panels:FindFirstChild("Build")
		if build then
			table.insert(watchers, build:GetPropertyChangedSignal("Visible"):Connect(function()
				if build.Visible and current == 4 then
					advance()
				end
			end))
		end

	elseif current == REBIRTH_STEP then
		table.insert(watchers, State:ObserveAll({ "ringLevel", "rebirths" }, function()
			if current ~= REBIRTH_STEP then
				return
			end
			if (State:Get("rebirths") or 0) > 0 then
				advance()
			else
				show(REBIRTH_STEP)
			end
		end))
	end
end

function TutorialController:Init() end

function TutorialController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")

	local screen = UI:GetScreen()

	panel = Widgets.panel({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(340, 62),
		Position = UDim2.new(0.5, 0, 1, -104),
		Visible = false,
		Parent = screen,
	}, { Widgets.padding(Theme.Pad.S) }) :: Frame
	panelStroke = panel:FindFirstChildOfClass("UIStroke")

	stepLabel = Widgets.label({
		Size = UDim2.fromOffset(46, 14),
		Text = "",
		TextSize = 11,
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Xp,
		Parent = panel,
	})

	textLabel = Widgets.label({
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextSize = 14,
		TextScaled = true,
		Font = Theme.Font.Bold,
		Parent = panel,
	})
	Widgets.create("UITextSizeConstraint", { MaxTextSize = 14, Parent = textLabel })

	hintLabel = Widgets.label({
		Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.Color.TextDim,
		Parent = panel,
	})

	State.Notified:Connect(function(kind)
		if kind == "CrateResult" and current == 3 then
			advance()
		elseif kind == "BattleResult" and current == 5 then
			advance()
		elseif kind == "RebirthResult" and current == REBIRTH_STEP then
			advance()
		end
	end)

	Locale:Observe(function()
		if current >= 1 and current <= #STEPS then
			show(current)
		end
	end)

	State:Observe("tutorialStep", function(step)
		if current > 0 then
			return
		end
		if step == REBIRTH_STEP - 1 and (State:Get("rebirths") or 0) > 0 then
			State:Send("TutorialStep", REBIRTH_STEP)
			step = REBIRTH_STEP
		end
		if step >= #STEPS then
			UI:SetCaptionsVisible(false)
			current = #STEPS + 1
			return
		end
		UI:SetCaptionsVisible(true)
		show(step + 1)
		watchStep()
	end)
end

return TutorialController
