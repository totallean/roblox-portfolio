local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlotService = require(script.Parent.PlotService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local DropperService = require(script.Parent.DropperService)

local CollectorService = {}

CollectorService.Sold = Instance.new("BindableEvent")

local connected = {}
local flashing = {}
local remotes

local function flash(plot: Model)
	if flashing[plot] then
		return
	end
	local collector = plot.Visuals:FindFirstChild("Slot_Collector")
	local part = collector and collector.PrimaryPart
	if not part then
		return
	end
	flashing[plot] = true

	local base = Config.Collector.Color
	local info = TweenInfo.new(Config.Collector.FlashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local up = TweenService:Create(part, info, { Color = Config.Collector.FlashColor })
	up.Completed:Once(function()
		local down = TweenService:Create(part, info, { Color = base })
		down.Completed:Once(function()
			flashing[plot] = nil
		end)
		down:Play()
	end)
	up:Play()
end

function CollectorService.Sell(plot: Model, product: BasePart): number

	if not CollectionService:HasTag(product, Config.Tags.Product) then
		return 0
	end

	local owner = PlotService.GetOwner(plot)
	if not owner then
		DropperService.Release(product)
		return 0
	end

	local value = product:GetAttribute("Value") or 0
	local stage = product:GetAttribute("Stage") or 0
	local amount = math.floor(value * CurrencyService.GetIncomeMultiplier(owner))

	DropperService.Release(product)

	if amount > 0 then
		CurrencyService.Add(owner, amount, "sell")

		local data = DataService.Get(owner)
		if data then
			data.SoldCount = (data.SoldCount or 0) + 1
		end
		flash(plot)
		remotes.ProductSold:FireClient(owner, amount, stage)
		CollectorService.Sold:Fire(owner, amount, stage)
	end
	return amount
end

local function bindSellZone(zone: BasePart)
	if connected[zone] then
		return
	end
	connected[zone] = true

	zone.Touched:Connect(function(hit)
		if not CollectionService:HasTag(hit, Config.Tags.Product) then
			return
		end

		local now = os.clock()
		local lockUntil = hit:GetAttribute("LockUntil")
		if lockUntil and now < lockUntil then
			return
		end
		hit:SetAttribute("LockUntil", now + Config.Collector.TouchCooldown)

		local plot = PlotService.GetPlotFrom(zone)
		if not plot then
			return
		end

		if hit:GetAttribute("PlotName") ~= plot.Name then
			return
		end
		CollectorService.Sell(plot, hit)
	end)
end

local function sweep()
	for _, plot in ipairs(PlotService.GetAllPlots()) do
		local products = plot:FindFirstChild("Products")
		local zone = plot:FindFirstChild("Triggers") and plot.Triggers:FindFirstChild("SellZone")
		if products and zone and plot:GetAttribute("OwnerUserId") ~= 0 then
			local halfDepth = zone.Size.Z * 0.5
			local halfWidth = zone.Size.X * 0.5 + 2
			for _, product in ipairs(products:GetChildren()) do
				if CollectionService:HasTag(product, Config.Tags.Product) then
					local rel = zone.CFrame:PointToObjectSpace(product.Position)

					if rel.Z >= -halfDepth and math.abs(rel.X) <= halfWidth and math.abs(rel.Y) <= 8 then
						CollectorService.Sell(plot, product)
					end
				end
			end
		end
	end
end

function CollectorService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		sweep()
	end)

	for _, zone in ipairs(CollectionService:GetTagged(Config.Tags.Trigger)) do
		if zone:GetAttribute("Kind") == "Collector" then
			bindSellZone(zone)
		end
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Trigger):Connect(function(zone)
		if zone:GetAttribute("Kind") == "Collector" then
			bindSellZone(zone)
		end
	end)
end

return CollectorService
