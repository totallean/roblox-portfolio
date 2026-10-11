--!strict

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Widgets = {}

function Widgets.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local create = Widgets.create

function Widgets.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius.M) })
end

function Widgets.padding(all: number): UIPadding
	return create("UIPadding", {
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
	})
end

function Widgets.list(props: { [string]: any }?): UIListLayout
	local merged = {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Theme.Pad.S),
		FillDirection = Enum.FillDirection.Vertical,
	}
	if props then for k, v in props do merged[k] = v end end
	return create("UIListLayout", merged)
end

function Widgets.grid(cell: Vector2, gap: number): UIGridLayout
	return create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Widgets.accentStroke(thickness: number?): UIStroke
	local stroke = create("UIStroke", {
		Thickness = thickness or 1.6,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	Theme.trackStroke(stroke)
	return stroke
end

function Widgets.plainStroke(color: Color3?, thickness: number?): UIStroke
	return create("UIStroke", {
		Color = color or Theme.Color.Bevel,
		Thickness = thickness or 1,
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Widgets.panel(props: { [string]: any }?, children: { Instance }?): Frame
	local merged = {
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		BorderSizePixel = 0,
	}
	if props then for k, v in props do merged[k] = v end end

	local kids = {
		Widgets.corner(),
		Widgets.accentStroke(),
		create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 186, 210)),
			Rotation = 90,
		}),
	}
	if children then for _, c in children do table.insert(kids, c) end end
	return create("Frame", merged, kids)
end

function Widgets.slot(props: { [string]: any }?, children: { Instance }?): Frame
	local merged = {
		BackgroundColor3 = Theme.Color.Slot,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}
	if props then for k, v in props do merged[k] = v end end
	local kids = { Widgets.corner(Theme.Radius.S), Widgets.plainStroke() }
	if children then for _, c in children do table.insert(kids, c) end end
	return create("Frame", merged, kids)
end

function Widgets.label(props: { [string]: any }?): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Theme.Font.Regular,
		TextColor3 = Theme.Color.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}
	if props then for k, v in props do merged[k] = v end end
	return create("TextLabel", merged)
end

function Widgets.button(props: { [string]: any }?, children: { Instance }?): TextButton
	local merged = {
		BackgroundColor3 = Theme.Color.Slot,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Text,
		TextSize = 14,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(150, Theme.TouchTarget),
	}
	if props then for k, v in props do merged[k] = v end end

	local kids = { Widgets.corner(Theme.Radius.S), Widgets.plainStroke() }
	if children then for _, c in children do table.insert(kids, c) end end

	local button = create("TextButton", merged, kids) :: TextButton
	local base = button.BackgroundColor3

	local function tint(target: Color3, time: number)
		TweenService:Create(button, TweenInfo.new(time, Enum.EasingStyle.Quad), { BackgroundColor3 = target }):Play()
	end

	button.MouseEnter:Connect(function() tint(base:Lerp(Color3.new(1, 1, 1), 0.14), 0.12) end)
	button.MouseLeave:Connect(function() tint(base, 0.12) end)
	button.MouseButton1Down:Connect(function() tint(base:Lerp(Color3.new(0, 0, 0), 0.3), 0.05) end)
	button.MouseButton1Up:Connect(function() tint(base, 0.1) end)

	return button
end

export type Bar = { frame: Frame, fill: Frame, caption: TextLabel }

function Widgets.bar(props: { [string]: any }, color: Color3, captionInside: boolean?): Bar
	local fill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, {
		Widgets.corner(Theme.Radius.S),
		create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)),
			Rotation = 90,
		}),
	})

	local caption = Widgets.label({
		Name = "Caption",
		Size = UDim2.fromScale(1, 1),
		TextSize = 12,
		Font = Theme.Font.Bold,
		TextXAlignment = if captionInside then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 3,
	})
	if captionInside then
		caption.Size = UDim2.new(1, -8, 1, 0)
		caption.Position = UDim2.fromOffset(4, 0)
	end

	local merged = {
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}
	for k, v in props do merged[k] = v end

	local frame = create("Frame", merged, {
		Widgets.corner(Theme.Radius.S),
		Widgets.plainStroke(),
		fill,
		caption,
	}) :: Frame

	return { frame = frame, fill = fill, caption = caption }
end

function Widgets.icon(image: string, props: { [string]: any }?): ImageLabel
	local merged = {
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
	}
	if props then for k, v in props do merged[k] = v end end
	return create("ImageLabel", merged)
end

export type Tile = { button: TextButton, badge: Frame, image: ImageLabel? }

function Widgets.tile(image: string?, caption: string, order: number): Tile
	local badge = create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = Theme.Color.Badge,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
	}, { Widgets.corner(6) }) :: Frame

	local art: ImageLabel? = nil
	local kids = { badge }

	if image then
		art = Widgets.icon(image, {
			Name = "Art",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.82, 0.82),
			ZIndex = 2,
		})
		table.insert(kids, art :: ImageLabel)
	else
		local diamond = create("Frame", {
			Name = "Diamond",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(34, 34),
			Rotation = 45,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Widgets.corner(Theme.Radius.S),
			Widgets.label({
				Size = UDim2.fromScale(1, 1),
				Rotation = -45,
				Text = string.upper(string.sub(caption, 1, 1)),
				TextSize = 18,
				Font = Theme.Font.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 3,
			}),
		}) :: Frame
		Theme.trackFill(diamond)
		table.insert(kids, diamond)
	end

	local captionStrip = create("Frame", {
		Name = "CaptionStrip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 17),
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
			Text = caption,
			TextSize = 10,
			Font = Theme.Font.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		}),
	}) :: Frame
	table.insert(kids, captionStrip)

	local button = Widgets.button({
		Name = caption,
		LayoutOrder = order,
		Size = UDim2.fromOffset(76, 76),
		Text = "",
	}, kids)

	return { button = button, badge = badge, image = art }
end

export type Counter = {
	label: TextLabel,
	set: (Counter, value: number, instant: boolean?) -> (),
	step: (Counter, dt: number) -> (),
}

function Widgets.counter(label: TextLabel, render: (number) -> string): Counter
	local shown, target = 0, 0
	local counter = {}
	counter.label = label

	function counter:set(value: number, instant: boolean?)
		target = value
		if instant then
			shown = value
			label.Text = render(value)
		end
	end

	function counter:step(dt: number)
		if shown == target then
			return
		end
		local diff = target - shown
		if math.abs(diff) < math.max(1, math.abs(target) * 1e-4) then
			shown = target
		else
			shown += diff * math.min(1, dt * 8)
		end
		label.Text = render(shown)
	end

	return counter
end

return Widgets
