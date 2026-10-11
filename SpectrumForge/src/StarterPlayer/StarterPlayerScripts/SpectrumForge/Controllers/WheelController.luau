--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Eco = require(Shared.EconomyConfig)

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Widgets = require(Root.UI.Widgets)

local create = Widgets.create

local WheelController = {}

local State, UI, Locale, Sound

local GEMS = 16
local SPOKES = 8
local SPIN_TIME = 2.6
local STAGGER = 0.12
local TURNS = 4
local AUTO_CLOSE = 6
local RARE_TIER = 5

local SINGLE_SIZE = 230
local MULTI_SIZE = 104
local MULTI_COLUMNS = 5
local CELL_GAP = 10
local CAPTION_HEIGHT = 40
local TITLE_HEIGHT = 34
local HINT_HEIGHT = 24

type Wheel = {
	spin: Frame,
	hub: Frame,
	gem: Frame,
	label: TextLabel,
	sub: TextLabel,
	rotation: number,
	tween: Tween?,
	drop: any,
	done: boolean,
}

local overlay: TextButton? = nil
local hint: TextLabel? = nil
local wheels: { Wheel } = {}
local spinning = 0
local bestTier = 0
local closeTask: thread? = nil
local rng = Random.new()

local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function allocate(maxTier: number): { number }
	local counts: { number } = {}
	local total = 0
	for tier = 1, maxTier do
		counts[tier] = 1
		total += Eco.CRATE_ODDS[tier]
	end

	local free = GEMS - maxTier
	local remainders: { { tier: number, rest: number } } = {}
	local used = 0
	for tier = 1, maxTier do
		local exact = Eco.CRATE_ODDS[tier] / total * free
		local whole = math.floor(exact)
		counts[tier] += whole
		used += whole
		table.insert(remainders, { tier = tier, rest = exact - whole })
	end
	table.sort(remainders, function(a, b)
		return a.rest > b.rest
	end)
	for index = 1, free - used do
		local entry = remainders[(index - 1) % #remainders + 1]
		counts[entry.tier] += 1
	end

	local sequence: { number } = {}
	local left = table.clone(counts)
	while #sequence < GEMS do
		for tier = 1, maxTier do
			if left[tier] > 0 then
				table.insert(sequence, tier)
				left[tier] -= 1
			end
		end
	end
	return sequence
end

local function circle(): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end

local function polar(angle: number, distance: number): UDim2
	local radians = math.rad(angle)
	return UDim2.new(0.5, math.sin(radians) * distance, 0.5, -math.cos(radians) * distance)
end

local function buildWheel(parent: Instance, order: number, size: number, sequence: { number }): (Wheel, { Frame })
	local holder = create("Frame", {
		Name = "Wheel" .. order,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local disc = create("Frame", {
		Name = "Disc",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Parent = holder,
	}, { circle(), Widgets.accentStroke(math.max(1.5, size / 70)) })

	local spin = create("Frame", {
		Name = "Spin",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = disc,
	}) :: Frame

	local radius = size / 2
	for index = 0, SPOKES - 1 do
		local angle = (index + 0.5) * 360 / SPOKES
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = polar(angle, radius * 0.36),
			Size = UDim2.fromOffset(math.max(1, size / 90), radius * 0.72),
			Rotation = angle,
			BackgroundColor3 = Theme.Color.Bevel,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Parent = spin,
		})
	end

	local gemSize = math.floor(size * 0.12)
	local gemRadius = radius - gemSize * 0.5 - size * 0.05
	local gems: { Frame } = {}
	for index, tier in sequence do
		local angle = (index - 1) * 360 / #sequence
		gems[index] = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = polar(angle, gemRadius),
			Size = UDim2.fromOffset(gemSize, gemSize),
			BackgroundColor3 = Theme.spectrum(tier),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = spin,
		}, {
			circle(),
			create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.55, Thickness = 1 }),
			create("UIScale"),
		}) :: Frame
	end

	local hub = create("Frame", {
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Theme.Color.PanelSoft,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = disc,
	}, { circle(), create("UIStroke", { Color = Theme.Color.Bevel, Thickness = math.max(1, size / 80) }) }) :: Frame

	local pointer = math.max(10, math.floor(size * 0.1))
	create("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, size * 0.02),
		Size = UDim2.fromOffset(pointer, pointer),
		Rotation = 45,
		BackgroundColor3 = Theme.Color.Xp,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = disc,
	}, { create("UIStroke", { Color = Theme.Color.Panel, Thickness = 2 }) })

	local label = Widgets.label({
		Position = UDim2.fromOffset(0, size + 4),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = if size > MULTI_SIZE then 18 else 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		Parent = holder,
	})

	local sub = Widgets.label({
		Position = UDim2.fromOffset(0, size + 22),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = if size > MULTI_SIZE then 14 else 11,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		Parent = holder,
	})

	local wheel: Wheel = {
		spin = spin,
		hub = hub,
		gem = gems[1],
		label = label,
		sub = sub,
		rotation = 0,
		tween = nil,
		drop = nil,
		done = false,
	}
	return wheel, gems
end

local function close()
	if closeTask then
		task.cancel(closeTask)
		closeTask = nil
	end
	for _, wheel in wheels do
		wheel.done = true
		if wheel.tween then
			wheel.tween:Cancel()
		end
	end
	table.clear(wheels)
	spinning = 0
	if overlay then
		overlay:Destroy()
		overlay = nil
		hint = nil
	end
end

local function finishAll()
	if hint then
		hint.Text = Locale:Get("wheel.close")
	end
	if bestTier >= RARE_TIER then
		Sound:Play("RareDrop")
		UI:Toast(Locale:Get("crate.dropped", Locale:ColorName(bestTier)), Theme.spectrum(bestTier))
	end
	closeTask = task.delay(AUTO_CLOSE, function()
		closeTask = nil
		close()
	end)
end

local function reveal(wheel: Wheel)
	if wheel.done then
		return
	end
	wheel.done = true

	if wheel.tween then
		wheel.tween:Cancel()
	end
	wheel.spin.Rotation = wheel.rotation

	local drop = wheel.drop
	local color = Theme.spectrum(drop.tier)
	wheel.hub.BackgroundColor3 = color

	local scale = wheel.gem:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, POP, { Scale = 1.6 }):Play()
	end

	wheel.label.Text = Locale:PartName(drop.defId)
	wheel.label.TextColor3 = color
	wheel.sub.Text = if drop.forced then Locale:Get("wheel.forced") else Locale:ColorName(drop.tier)
	wheel.sub.TextColor3 = if drop.forced then Theme.Color.Xp else Theme.Color.TextDim
	TweenService:Create(wheel.label, FADE, { TextTransparency = 0 }):Play()
	TweenService:Create(wheel.sub, FADE, { TextTransparency = 0 }):Play()

	spinning -= 1
	if spinning == 0 then
		finishAll()
	end
end

local function spinTo(wheel: Wheel, gems: { Frame }, sequence: { number }, delay: number)
	local candidates = {}
	for index, tier in sequence do
		if tier == wheel.drop.tier then
			table.insert(candidates, index)
		end
	end
	local index = if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else 1
	local step = 360 / #sequence
	local landing = (index - 1) * step + rng:NextNumber(-0.3, 0.3) * step

	wheel.gem = gems[index]
	wheel.rotation = (TURNS + rng:NextInteger(0, 1)) * 360 - landing

	local tween = TweenService:Create(
		wheel.spin,
		TweenInfo.new(SPIN_TIME + delay, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Rotation = wheel.rotation }
	)
	wheel.tween = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			reveal(wheel)
		end
	end)
	tween:Play()

	task.delay(SPIN_TIME + delay + 0.5, reveal, wheel)
end

local function onTap()
	if spinning > 0 then
		for _, wheel in table.clone(wheels) do
			reveal(wheel)
		end
	else
		close()
	end
end

local function show(payload: any)
	close()

	local drops = payload.drops
	if type(drops) ~= "table" or #drops == 0 then
		return
	end

	local maxTier = Eco.maxUnlockedTier(State:Get("rebirths") or 0)
	bestTier = 0
	for _, drop in drops do
		maxTier = math.max(maxTier, drop.tier)
		bestTier = math.max(bestTier, drop.tier)
	end
	maxTier = math.min(maxTier, #Eco.CRATE_ODDS)
	local sequence = allocate(maxTier)

	local many = #drops > 1
	local size = if many then MULTI_SIZE else SINGLE_SIZE
	local columns = if many then math.min(MULTI_COLUMNS, #drops) else 1
	local rows = math.ceil(#drops / columns)
	local cell = Vector2.new(size + 16, size + CAPTION_HEIGHT)
	local gridSize = Vector2.new(
		columns * cell.X + (columns - 1) * CELL_GAP,
		rows * cell.Y + (rows - 1) * CELL_GAP
	)
	local contentSize = Vector2.new(gridSize.X, TITLE_HEIGHT + gridSize.Y + HINT_HEIGHT)

	local screen = UI:GetScreen()
	local button = create("TextButton", {
		Name = "CrateWheel",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 5, 9),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 40,
		Parent = screen,
	}) :: TextButton
	button.MouseButton1Click:Connect(onTap)
	overlay = button

	local content = create("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(contentSize.X, contentSize.Y),
		BackgroundTransparency = 1,
		Parent = button,
	})

	local guiScale = screen:FindFirstChildOfClass("UIScale")
	local factor = if guiScale then guiScale.Scale else 1
	local available = button.AbsoluteSize
	local fit = 1
	if available.X > 0 and available.Y > 0 then
		fit = math.min(
			1,
			available.X * 0.96 / (contentSize.X * factor),
			available.Y * 0.92 / (contentSize.Y * factor)
		)
	end
	create("UIScale", { Scale = fit, Parent = content })

	Widgets.label({
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		Text = Locale:Get("wheel.title"),
		Font = Theme.Font.Bold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})

	local grid = create("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, TITLE_HEIGHT),
		Size = UDim2.fromOffset(gridSize.X, gridSize.Y),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
			FillDirectionMaxCells = columns,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	hint = Widgets.label({
		Position = UDim2.new(0, 0, 1, -HINT_HEIGHT),
		Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
		Text = Locale:Get("wheel.skip"),
		TextSize = 13,
		TextColor3 = Theme.Color.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})

	spinning = #drops
	for index, drop in drops do
		local wheel, gems = buildWheel(grid, index, size, sequence)
		wheel.drop = drop
		table.insert(wheels, wheel)
		spinTo(wheel, gems, sequence, (index - 1) * STAGGER)
	end
end

function WheelController:Init() end

function WheelController:Start()
	State = self.GetController("StateController")
	UI = self.GetController("UIController")
	Locale = self.GetController("LocaleController")
	Sound = self.GetController("SoundController")

	State.Notified:Connect(function(kind, payload)
		if kind == "CrateResult" and type(payload) == "table" then
			show(payload)
		end
	end)
end

return WheelController
