local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Horror"):WaitForChild("Config"))
local Net = require(script.Parent:WaitForChild("Net"))

export type State = {
	player: Player,
	crouching: boolean,
	flashlight: boolean,
	hiddenIn: Model?,
	hiddenAt: number,
	tokens: number,
	tokensAt: number,
}

local PlayerState = {}

-- Set by Main: called when a dead player presses Restart / Main menu on the game-over screen.
PlayerState.onRespawn = nil :: ((Player) -> ())?

local states: { [Player]: State } = {}

local function rateLimited(state: State): boolean
	local now = os.clock()
	state.tokens = math.min(Config.Remote.RateLimit, state.tokens + (now - state.tokensAt) * Config.Remote.RateLimit)
	state.tokensAt = now
	if state.tokens < 1 then
		return true
	end
	state.tokens -= 1
	return false
end

-- The flashlight lives on the server so every player sees each other's beam, and the stalker's
-- perception reads the same flag that drives the light.
local function flashlightOf(character: Model): SpotLight?
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local existing = head:FindFirstChild("Flashlight")
	if existing and existing:IsA("SpotLight") then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlashlightAttachment"
	attachment.Position = Vector3.new(0, 0, -0.6)
	attachment.Parent = head
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Range = 48
	light.Angle = 55
	light.Brightness = 2.4
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Shadows = true
	light.Enabled = false
	light.Parent = head
	return light
end

function PlayerState.get(player: Player): State?
	return states[player]
end

function PlayerState.all(): { [Player]: State }
	return states
end

-- Crouching only counts while the body actually moves at crouch speed: the client cannot claim to
-- be crouched while sprinting.
function PlayerState.isEffectivelyCrouched(state: State, horizontalSpeed: number): boolean
	return state.crouching and horizontalSpeed <= Config.Player.CrouchSpeed + 2
end

function PlayerState.setFlashlight(state: State, enabled: boolean)
	state.flashlight = enabled
	local character = state.player.Character
	local light = character and flashlightOf(character)
	if light then
		light.Enabled = enabled
	end
end

function PlayerState.init()
	local function onPlayer(player: Player)
		local state: State = {
			player = player,
			crouching = false,
			flashlight = false,
			hiddenIn = nil,
			hiddenAt = 0,
			tokens = Config.Remote.RateLimit,
			tokensAt = os.clock(),
		}
		states[player] = state
		player.CharacterAdded:Connect(function(character)
			state.crouching = false
			state.flashlight = false
			state.hiddenIn = nil
			character:WaitForChild("Head")
			flashlightOf(character)
		end)
		if player.Character then
			flashlightOf(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Net.Input.OnServerEvent:Connect(function(player: Player, action: unknown, value: unknown)
		local state = states[player]
		if not state or rateLimited(state) or typeof(value) ~= "boolean" then
			return
		end
		if action == "Crouch" then
			state.crouching = value
		elseif action == "Flashlight" then
			PlayerState.setFlashlight(state, value)
		elseif action == "Respawn" and PlayerState.onRespawn then
			PlayerState.onRespawn(player)
		end
	end)
end

return PlayerState
