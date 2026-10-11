local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlotService = require(script.Parent.PlotService)

local ProcessService = {}

local connected = {}

local function log(fmt, ...)
	if Config.Debug.Verbose then
		print(("[ProcessService] " .. fmt):format(...))
	end
end

local function applyStamp(product: BasePart, def)
	local stamp = product:FindFirstChild("Stamp")
	if stamp then
		stamp.Text.Text = def.Decal.Text
		stamp.Text.TextColor3 = def.Decal.Color

		local stroke = stamp.Text:FindFirstChildOfClass("UIStroke")
		if stroke and def.Decal.StrokeColor then
			stroke.Color = def.Decal.StrokeColor
		end
		stamp.Enabled = true
	end
end

local function applyWax(product: BasePart, def)
	if def.SizeAdd then
		product.Size += def.SizeAdd
	end
	if def.Color then
		product.Color = def.Color
	end
	if def.Material then
		product.Material = def.Material
	end
	product.Reflectance = math.min(0.6, product.Reflectance + 0.12)
end

local function squish(product: BasePart)
	local target = product.Size
	local squished = Vector3.new(target.X * 1.25, math.max(0.2, target.Y * 0.55), target.Z * 1.25)
	local info = TweenInfo.new(Config.Product.SquishTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local down = TweenService:Create(product, info, { Size = squished })
	down.Completed:Once(function()
		if product.Parent and CollectionService:HasTag(product, Config.Tags.Product) then
			TweenService:Create(product, TweenInfo.new(Config.Product.SquishTime * 1.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = target }):Play()
		end
	end)
	down:Play()
end

local function process(product: BasePart, def)
	local stage = product:GetAttribute("Stage")
	local value = product:GetAttribute("Value")
	if stage == nil or value == nil then
		return
	end

	if def.Type == "Processor" and def.Decal then
		applyStamp(product, def)
	else
		applyWax(product, def)
	end

	product:SetAttribute("Stage", stage + 1)
	product:SetAttribute("Value", math.floor(value * (def.Multiplier or 1)))
	squish(product)
end

local function bindTrigger(trigger: BasePart)
	if connected[trigger] then
		return
	end
	connected[trigger] = true

	trigger.Touched:Connect(function(hit)

		if trigger:GetAttribute("Enabled") ~= true then
			return
		end

		if not CollectionService:HasTag(hit, Config.Tags.Product) then
			return
		end

		local def = Config.GetStation(trigger:GetAttribute("StationId"))
		if not def then
			return
		end

		if hit:GetAttribute("Stage") ~= def.RequiredStage then
			return
		end

		local now = os.clock()
		local lockUntil = hit:GetAttribute("LockUntil")
		if lockUntil and now < lockUntil then
			return
		end
		hit:SetAttribute("LockUntil", now + Config.Station.TouchCooldown)

		process(hit, def)

		local plot = PlotService.GetPlotFrom(trigger)
		if plot then
			PlotService.PlayStationSound(plot, def.Id)
		end
	end)
end

function ProcessService.EnableStation(plot: Model, def)
	if def.Type ~= "Processor" then
		return
	end
	PlotService.PlaceStation(plot, def)
	local trigger = plot.Triggers:FindFirstChild("Trigger_" .. def.Id)
	if trigger then
		trigger:SetAttribute("Enabled", true)
		bindTrigger(trigger)
	end
	log("на %s включена станция %s", plot.Name, def.Id)
end

function ProcessService.DisableAll(plot: Model)
	for _, trigger in ipairs(plot.Triggers:GetChildren()) do
		if trigger:GetAttribute("Kind") == "Station" then
			trigger:SetAttribute("Enabled", false)
		end
	end
	local slots = plot:FindFirstChild("Slots")
	if slots then
		slots:ClearAllChildren()
	end
end

function ProcessService.Init()

	for _, trigger in ipairs(CollectionService:GetTagged(Config.Tags.Trigger)) do
		if trigger:GetAttribute("Kind") == "Station" then
			bindTrigger(trigger)
		end
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Trigger):Connect(function(trigger)
		if trigger:GetAttribute("Kind") == "Station" then
			bindTrigger(trigger)
		end
	end)

	PlotService.RegisterCleanup(function(_, plot)
		ProcessService.DisableAll(plot)
	end)
end

return ProcessService
