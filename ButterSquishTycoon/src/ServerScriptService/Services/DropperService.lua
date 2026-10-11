local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlotService = require(script.Parent.PlotService)

local DropperService = {}

local poolFolder: Folder
local pool = {}
local created = 0
local dropState = {}
local activeByPlot = {}
local lifetimeAccum = 0

local function createProduct(): BasePart
	local part = Instance.new("Part")
	part.Name = "ButterStick"
	part.Size = Config.Product.BaseSize
	part.Color = Config.Palette.Butter
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.1, 1, 1)

	local stamp = Instance.new("SurfaceGui")
	stamp.Name = "Stamp"
	stamp.Face = Enum.NormalId.Top
	stamp.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	stamp.PixelsPerStud = 50
	stamp.LightInfluence = 0
	stamp.Enabled = false
	stamp.Parent = part

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Config.Style.Font
	text.TextScaled = true
	text.Text = ""
	text.Parent = stamp

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Style.StrokeColor
	stroke.Thickness = Config.Style.StampStroke
	stroke.Parent = text

	created += 1
	return part
end

local function acquire(): BasePart?
	local part = table.remove(pool)
	if part then
		return part
	end
	if created >= Config.Product.PoolHardCap then
		return nil
	end
	return createProduct()
end

function DropperService.Release(product: BasePart)
	if not product or not product.Parent then
		return
	end
	CollectionService:RemoveTag(product, Config.Tags.Product)

	local plotsFolder = workspace:FindFirstChild("Plots")
	local plotName = product:GetAttribute("PlotName")
	local plot = (plotsFolder and plotName) and plotsFolder:FindFirstChild(plotName) or nil
	if plot and activeByPlot[plot] then
		local list = activeByPlot[plot]
		local index = table.find(list, product)
		if index then
			table.remove(list, index)
		end
	end

	product.Anchored = true
	product.AssemblyLinearVelocity = Vector3.zero
	product.AssemblyAngularVelocity = Vector3.zero
	product.Size = Config.Product.BaseSize
	product.Color = Config.Palette.Butter
	product.Material = Enum.Material.SmoothPlastic
	product.Transparency = 0
	product.Reflectance = 0
	product.CFrame = CFrame.new(0, -500, 0)

	local stamp = product:FindFirstChild("Stamp")
	if stamp then
		stamp.Enabled = false
		stamp.Text.Text = ""
	end

	for _, name in ipairs({ "Stage", "Value", "OwnerUserId", "PlotName", "BornAt", "LockUntil" }) do
		product:SetAttribute(name, nil)
	end

	product.Parent = poolFolder
	table.insert(pool, product)
end

function DropperService.ClearPlot(plot: Model)
	local list = activeByPlot[plot]
	if list then
		for i = #list, 1, -1 do
			DropperService.Release(list[i])
		end
		activeByPlot[plot] = {}
	end
	if dropState[plot] then
		dropState[plot].Enabled = false
		dropState[plot].Accum = 0
	end
end

local function drop(plot: Model)
	local owner = PlotService.GetOwner(plot)
	if not owner then
		return
	end

	local list = activeByPlot[plot]
	if not list then
		list = {}
		activeByPlot[plot] = list
	end

	while #list >= Config.Product.MaxActive do
		local oldest = table.remove(list, 1)
		if not oldest then
			break
		end
		DropperService.Release(oldest)
	end

	local product = acquire()
	if not product then
		return
	end

	local def = Config.GetStation("Extruder")
	product.Size = def.ProductSize
	product.Color = def.ProductColor
	product.Material = def.ProductMaterial
	product.Transparency = 0
	product.Reflectance = 0

	product:SetAttribute("Stage", 0)
	product:SetAttribute("Value", def.BaseValue)
	product:SetAttribute("OwnerUserId", owner.UserId)
	product:SetAttribute("PlotName", plot.Name)
	product:SetAttribute("BornAt", os.clock())

	local dropPoint = plot.Triggers:FindFirstChild("DropPoint")
	product.CFrame = dropPoint and dropPoint.CFrame or plot:GetPivot()
	product.Parent = plot.Products
	product.Anchored = false
	product.AssemblyLinearVelocity = Vector3.zero

	CollectionService:AddTag(product, Config.Tags.Product)
	table.insert(list, product)

	PlotService.PlayStationSound(plot, def.Id)
end

function DropperService.EnableStation(plot: Model, def)
	if def.Type ~= "Producer" then
		return
	end
	dropState[plot] = dropState[plot] or { Accum = 0, Enabled = false }
	dropState[plot].Enabled = true
end

function DropperService.DisableStation(plot: Model)
	if dropState[plot] then
		dropState[plot].Enabled = false
	end
end

function DropperService.GetActiveCount(plot: Model): number
	local list = activeByPlot[plot]
	return list and #list or 0
end

function DropperService.Init()
	poolFolder = ServerStorage:FindFirstChild("ProductPool")
	if not poolFolder then
		poolFolder = Instance.new("Folder")
		poolFolder.Name = "ProductPool"
		poolFolder.Parent = ServerStorage
	end
	poolFolder:ClearAllChildren()

	for _ = 1, Config.Product.PoolSize do
		local part = createProduct()
		part.CFrame = CFrame.new(0, -500, 0)
		part.Parent = poolFolder
		table.insert(pool, part)
	end

	local producer = Config.GetStation("Extruder")

	RunService.Heartbeat:Connect(function(dt)

		for plot, state in pairs(dropState) do
			if state.Enabled and plot.Parent then
				state.Accum += dt

				local scale = plot:GetAttribute("DropIntervalScale") or 1
				local interval = math.max(0.1, producer.DropInterval * scale)
				local guard = 0
				while state.Accum >= interval and guard < 4 do
					state.Accum -= interval
					guard += 1
					drop(plot)
				end
				if guard >= 4 then
					state.Accum = 0
				end
			end
		end

		lifetimeAccum += dt
		if lifetimeAccum < 1 then
			return
		end
		lifetimeAccum = 0

		local now = os.clock()
		for plot, list in pairs(activeByPlot) do
			for i = #list, 1, -1 do
				local product = list[i]
				local born = product:GetAttribute("BornAt")
				if not product.Parent then
					table.remove(list, i)
				elseif born and (now - born) > Config.Product.Lifetime then

					local handled = false
					if DropperService.OnProductExpired then
						local ok, result = pcall(DropperService.OnProductExpired, plot, product)
						handled = ok and result == true
					end
					if not handled then
						DropperService.Release(product)
					end
				end
			end
		end
	end)

	PlotService.RegisterCleanup(function(_, plot)
		DropperService.ClearPlot(plot)
	end)
end

return DropperService
