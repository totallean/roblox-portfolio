--!strict

local Players = game:GetService("Players")

local TeleportService = {}

TeleportService.COOLDOWN = 2

local lastUse: { [Player]: number } = {}

local function travel(player: Player, arrival: Vector3, lookAt: Vector3?)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastUse[player] or 0) < TeleportService.COOLDOWN then
		return
	end
	lastUse[player] = now

	local target = lookAt or Vector3.new(0, arrival.Y, 0)
	local direction = target - arrival
	if direction.Magnitude < 1 then
		direction = Vector3.new(0, 0, -1)
	end

	character:PivotTo(CFrame.lookAt(arrival, arrival + direction.Unit))
end

local function wire(pad: BasePart)
	local arrival = pad:GetAttribute("Arrival")
	if typeof(arrival) ~= "Vector3" then
		warn(("[Teleport] у площадки %s нет точки прибытия"):format(pad:GetFullName()))
		return
	end

	local look = pad:GetAttribute("ArrivalLook")
	local lookAt = if typeof(look) == "Vector3" then look else nil

	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			travel(player, arrival, lookAt)
		end
	end)
end

local function wirePrompt(panel: BasePart)
	local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
	local inside = panel:GetAttribute("Inside")
	if not prompt or typeof(inside) ~= "Vector3" then
		return
	end

	local look = panel:GetAttribute("InsideLook")
	local lookAt = if typeof(look) == "Vector3" then look else nil

	prompt.Triggered:Connect(function(player)
		travel(player, inside, lookAt)
	end)
end

function TeleportService:Init() end

function TeleportService:Start()
	local wired = 0
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Teleport") then
			wire(descendant)
			wired += 1
		elseif descendant:IsA("BasePart") and descendant:GetAttribute("ArenaEntry") then
			wirePrompt(descendant)
			wired += 1
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)

	print(("[Teleport] врат подключено: %d"):format(wired))
end

return TeleportService
