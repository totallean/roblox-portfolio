--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eco = require(ReplicatedStorage.SpectrumForge.Shared.EconomyConfig)

local WorldController = {}

local State, Locale

local DIM_TRANSPARENCY = 0.82
local DIM_LIGHT = 0.15

local monoliths: Folder?
local lastRebirths: number = 0
local batteryCore: BasePart?
local batteryLight: PointLight?

local function applyUnlocked(rebirths: number?)
	lastRebirths = rebirths or lastRebirths
	if not monoliths then
		return
	end

	local maxTier = Eco.maxUnlockedTier(lastRebirths)

	for _, model in (monoliths :: Folder):GetChildren() do
		local tier = model:GetAttribute("Tier")
		local vein = model:FindFirstChild("Vein") :: BasePart?
		if not tier or not vein then
			continue
		end

		local open = tier <= maxTier
		local light = vein:FindFirstChildOfClass("PointLight")
		local tag = vein:FindFirstChild("Tag")

		TweenService:Create(vein, TweenInfo.new(0.6), {
			Transparency = if open then 0 else DIM_TRANSPARENCY,
		}):Play()

		if light then
			TweenService:Create(light, TweenInfo.new(0.6), {
				Brightness = if open then 2 else DIM_LIGHT,
			}):Play()
		end

		if tag then
			local label = tag:FindFirstChildOfClass("TextLabel")
			if label then
				label.TextTransparency = if open then 0 else 0.62
			end
		end
	end
end

local function applyColor(tier: number?)
	local entry = Eco.COLORS[tier or 1]
	if not entry or not batteryCore then
		return
	end

	TweenService:Create(batteryCore, TweenInfo.new(0.5), { Color = entry.color }):Play()
	if batteryLight then
		TweenService:Create(batteryLight, TweenInfo.new(0.5), { Color = entry.color }):Play()
	end
end

local function label(holder: Instance?): TextLabel?
	local tag = holder and holder:FindFirstChild("Tag")
	return tag and tag:FindFirstChildOfClass("TextLabel") or nil
end

local function relabelWorld()
	if not Locale then
		return
	end

	local hub = workspace:FindFirstChild("Hub")
	local islands = workspace:FindFirstChild("Lanterns")

	if islands then
		for _, island in islands:GetChildren() do
			local tier = island:GetAttribute("Tier")
			local sign = label(island:FindFirstChild("SignPost"))
			if sign and tier then
				sign.Text = Locale:ColorName(tier)
			end
			local back = label(island:FindFirstChild("ReturnPad"))
			if back then
				back.Text = Locale:Get("world.toHub")
			end
		end
	end

	if not hub then
		return
	end

	local monoliths = hub:FindFirstChild("Monoliths")
	if monoliths then
		for _, m in monoliths:GetChildren() do
			local tier = m:GetAttribute("Tier")
			local gate = label(m:FindFirstChild("TeleportPad"))
			if gate and tier then
				gate.Text = Locale:ColorName(tier)
			end
		end
	end

	local arena = hub:FindFirstChild("Arena")
	if arena then
		local exitLabel = label(arena:FindFirstChild("ExitPad"))
		if exitLabel then
			exitLabel.Text = Locale:Get("arena.exit")
		end

		local console = arena:FindFirstChild("EntryConsole")
		local panel = console and console:FindFirstChild("Panel")
		local prompt = panel and panel:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ActionText = Locale:Get("arena.enter")
			prompt.ObjectText = Locale:Get("arena.object")
		end
	end

	local board = hub:FindFirstChild("Leaderboard")
	local screen = board and board:FindFirstChild("Panel")
	local gui = screen and screen:FindFirstChild("Screen")
	local title = gui and gui.Root:FindFirstChild("Title")
	if title then
		title.Text = Locale:Get("world.leaderboard")
	end
end

local refreshPending = false
local function scheduleRefresh()
	if refreshPending then
		return
	end
	refreshPending = true
	task.defer(function()
		refreshPending = false
		relabelWorld()
		applyUnlocked()
	end)
end

local function attachHub()
	local hub = workspace:WaitForChild("Hub", math.huge)
	hub.DescendantAdded:Connect(scheduleRefresh)

	monoliths = hub:WaitForChild("Monoliths", math.huge) :: Folder

	local arena = hub:WaitForChild("Arena", math.huge)
	batteryCore = arena:WaitForChild("ArenaRim", math.huge) :: BasePart
	local fightAnchor = arena:FindFirstChild("FightAnchor")
	batteryLight = fightAnchor and fightAnchor:FindFirstChildOfClass("PointLight")

	local tier = State:Get("colorTier")
	if tier then
		applyColor(tier)
	end
	scheduleRefresh()
end

local function attachIslands()
	local islands = workspace:WaitForChild("Lanterns", math.huge)
	islands.DescendantAdded:Connect(scheduleRefresh)
	scheduleRefresh()
end

function WorldController:Init() end

function WorldController:Start()
	State = self.GetController("StateController")
	Locale = self.GetController("LocaleController")

	Locale:Observe(relabelWorld)

	State:Observe("rebirths", applyUnlocked)
	State:Observe("colorTier", applyColor)

	task.spawn(attachHub)
	task.spawn(attachIslands)
end

return WorldController
