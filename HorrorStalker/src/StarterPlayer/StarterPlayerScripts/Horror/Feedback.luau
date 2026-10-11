local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Horror")
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Locale = require(Shared:WaitForChild("Locale"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local remotes = Shared:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Feedback = {}

local caughtEvent = Instance.new("BindableEvent")
Feedback.Caught = caughtEvent.Event

local awareness = 0
local stalkerState = "Patrol"
local chased = false
local wasSuspicious = false
local jumpscareConnection: RBXScriptConnection? = nil

local heartbeat: Sound
local ambience: Sound

local function sound(id: string, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.Parent = SoundService
	return s
end

local function playOnce(id: string, volume: number)
	local s = sound(id, volume, false)
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(12, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Feedback.stalker(): Model?
	local model = Workspace:FindFirstChild("Stalker")
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function jumpscare(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not head or not camera then
		return
	end
	caughtEvent:Fire()
	playOnce(Sounds.Jumpscare, 2.5)
	Hud.flash()
	Hud.notice(Locale.get("caught"), Color3.fromRGB(255, 60, 50), 3)
	camera.CameraType = Enum.CameraType.Scriptable
	local started = os.clock()
	local rng = Random.new()
	if jumpscareConnection then
		jumpscareConnection:Disconnect()
	end
	jumpscareConnection = RunService.RenderStepped:Connect(function()
		-- The game-over screen takes the camera over once it opens.
		if player:GetAttribute("InMenu") then
			if jumpscareConnection then
				jumpscareConnection:Disconnect()
				jumpscareConnection = nil
			end
			return
		end
		local t = os.clock() - started
		local face = head.CFrame
		local shake = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * math.max(0, 0.25 - t * 0.15)
		local distance = math.max(1.1, 2.4 - t * 2.5)
		local from = face.Position + face.LookVector * distance + shake
		camera.CFrame = CFrame.lookAt(from, face.Position)
		camera.FieldOfView = 55
	end)
	task.delay(0.95, function()
		Hud.fade(0, 0.25)
	end)
end

local function restoreCamera()
	if jumpscareConnection then
		jumpscareConnection:Disconnect()
		jumpscareConnection = nil
	end
	if not player:GetAttribute("InMenu") then
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
	Hud.fade(1, 1.2)
end

function Feedback.init()
	heartbeat = sound(Sounds.Heartbeat, 0, true)
	heartbeat:Play()
	ambience = sound(Sounds.Ambience, 0.35, true)
	ambience:Play()

	local stalkerRemote = remotes:WaitForChild("Stalker") :: RemoteEvent
	stalkerRemote.OnClientEvent:Connect(function(action: string, a: any, b: any, c: any)
		if action == "Awareness" then
			awareness = a
			stalkerState = b
			local nowChased = c == true
			if nowChased and not chased then
				playOnce(Sounds.Spotted, 1.6)
			end
			chased = nowChased
			local suspicious = awareness >= Config.Stalker.SuspiciousAt
			if suspicious and not wasSuspicious and not chased then
				playOnce(Sounds.Drone, 1.2)
			end
			wasSuspicious = suspicious
			Hud.setAwareness(awareness, chased)
		elseif action == "Jumpscare" and typeof(a) == "Instance" then
			jumpscare(a)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		restoreCamera()
		chased = false
		awareness = 0
		Hud.setAwareness(0, false)
		character:GetAttributeChangedSignal("Hidden"):Connect(function()
			Hud.setHidden(character:GetAttribute("Hidden") == true)
		end)
		Hud.setHidden(false)
	end)
end

function Feedback.update(dt: number)
	local model = Feedback.stalker()
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local proximity = 0
	if root and me then
		proximity = math.clamp(1 - (root.Position - me.Position).Magnitude / 45, 0, 1)
	end
	local danger = math.max(if chased then 1 else 0, awareness * 0.8, proximity)
	heartbeat.Volume += (danger * 1.3 - heartbeat.Volume) * math.min(1, dt * 3)
	heartbeat.PlaybackSpeed = 0.9 + danger * 0.55
	ambience.Volume = 0.35 * (1 - danger * 0.6)
	Hud.setDanger(danger)
end

function Feedback.getState(): (number, string, boolean)
	return awareness, stalkerState, chased
end

return Feedback
