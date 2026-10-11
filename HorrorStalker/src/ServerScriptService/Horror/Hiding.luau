local Players = game:GetService("Players")

local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

type Entry = {
	model: Model,
	front: BasePart,
	hidePoint: BasePart,
	prompt: ProximityPrompt,
	occupant: Player?,
}

local Hiding = {}

local entries: { [Model]: Entry } = {}

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return root, humanoid
	end
	return nil, nil
end

local function setPromptText(entry: Entry, key: string, text: string)
	entry.prompt.ActionText = text
	entry.prompt:SetAttribute("TextKey", key)
end

local function leave(entry: Entry)
	local player = entry.occupant
	entry.occupant = nil
	setPromptText(entry, "hide", "Hide")
	if not player then
		return
	end
	local state = PlayerState.get(player)
	if state then
		state.hiddenIn = nil
	end
	local root = rootOf(player)
	if player.Character then
		player.Character:SetAttribute("Hidden", nil)
	end
	if root then
		local look = entry.front.CFrame.LookVector
		local out = entry.hidePoint.Position + Vector3.new(look.X, 0, look.Z).Unit * 3.5
		root.CFrame = CFrame.lookAt(out, out + Vector3.new(look.X, 0, look.Z))
		root.Anchored = false
	end
end

local function enter(entry: Entry, player: Player)
	local state = PlayerState.get(player)
	local root, humanoid = rootOf(player)
	if not state or not root or not humanoid or humanoid.Health <= 0 or state.hiddenIn then
		return
	end
	entry.occupant = player
	state.hiddenIn = entry.model
	state.hiddenAt = os.clock()
	PlayerState.setFlashlight(state, false)
	root.Anchored = true
	root.CFrame = entry.hidePoint.CFrame
	;(player.Character :: Model):SetAttribute("Hidden", true)
	setPromptText(entry, "leave", "Leave")
end

function Hiding.init(folder: Instance)
	for _, model in folder:GetChildren() do
		local front = model:FindFirstChild("Front")
		local hidePoint = model:FindFirstChild("HidePoint")
		if not model:IsA("Model") or not front or not hidePoint then
			continue
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Locker"
		prompt:SetAttribute("ObjectKey", "object_locker")
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = front

		local entry: Entry = {
			model = model,
			front = front :: BasePart,
			hidePoint = hidePoint :: BasePart,
			prompt = prompt,
			occupant = nil,
		}
		setPromptText(entry, "hide", "Hide")
		entries[model] = entry

		prompt.Triggered:Connect(function(player: Player)
			if entry.occupant == player then
				leave(entry)
			elseif entry.occupant == nil then
				enter(entry, player)
			end
		end)
	end

	local function release(player: Player)
		for _, entry in entries do
			if entry.occupant == player then
				entry.occupant = nil
				setPromptText(entry, "hide", "Hide")
			end
		end
	end
	Players.PlayerRemoving:Connect(release)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			release(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			release(player)
		end)
	end
end

function Hiding.hide(player: Player, locker: Model)
	local entry = entries[locker]
	if entry and entry.occupant == nil then
		enter(entry, player)
	end
end

-- Used by the stalker when it saw the player climb in: opens the locker and returns the victim.
function Hiding.pullOut(locker: Model): Player?
	local entry = entries[locker]
	if not entry or not entry.occupant then
		return nil
	end
	local victim = entry.occupant
	leave(entry)
	return victim
end

function Hiding.standPoint(locker: Model): Vector3?
	local entry = entries[locker]
	if not entry then
		return nil
	end
	local look = entry.front.CFrame.LookVector
	return entry.hidePoint.Position + Vector3.new(look.X, 0, look.Z).Unit * 4
end

function Hiding.releaseAll()
	for _, entry in entries do
		if entry.occupant then
			leave(entry)
		end
	end
end

return Hiding
