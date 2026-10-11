local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("WebSwing")
local Config = require(Shared:WaitForChild("Config"))
local WebRope = require(Shared:WaitForChild("WebRope"))

local RemoteWebs = {}

local folder = Instance.new("Folder")
folder.Name = "RemoteWebs"
folder.Parent = Workspace

local active: { [Player]: WebRope.WebRope } = {}

local function handOf(player: Player): Attachment?
	local character = player.Character
	if not character then
		return nil
	end
	local handPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local attachment = handPart and handPart:FindFirstChild("RightGripAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	return nil
end

local function release(player: Player, animated: boolean)
	local rope = active[player]
	if rope then
		active[player] = nil
		if animated then
			rope:Release()
		else
			rope:Destroy()
		end
	end
end

local function attach(player: Player, target: Vector3)
	release(player, false)
	local hand = handOf(player)
	if not hand then
		return
	end
	local rope = WebRope.new(hand, folder)
	active[player] = rope
	rope:ShootTo(target, Config.WebTravelSpeed)
end

function RemoteWebs.init()
	local remote = Shared:WaitForChild("Remotes"):WaitForChild("Web") :: RemoteEvent
	remote.OnClientEvent:Connect(function(action: string, player: Player, target: Vector3?)
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player == Players.LocalPlayer then
			return
		end
		if action == "Attach" and typeof(target) == "Vector3" then
			attach(player, target)
		elseif action == "Release" then
			release(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		release(player, false)
	end)
end

return RemoteWebs
