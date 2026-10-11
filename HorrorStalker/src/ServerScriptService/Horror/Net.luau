local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Horror")

local folder = shared:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = shared
end

local function remote(name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

return {
	-- client -> server: ("Crouch", boolean) | ("Flashlight", boolean)
	Input = remote("Input"),
	-- server -> client: ("Awareness", value, stateName, isTarget) | ("Jumpscare", stalkerModel)
	Stalker = remote("Stalker"),
	-- server -> client: ("KeyFound", name) | ("ExitOpen") | ("Escaped", name, seconds) | ("NewRound")
	Game = remote("Game"),
}
