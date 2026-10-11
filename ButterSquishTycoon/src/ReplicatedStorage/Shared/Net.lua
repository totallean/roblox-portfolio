local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Net = {}

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local cache = {}
local folder: Folder? = nil

function Net.Folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	if IS_SERVER then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = FOLDER_NAME
			existing.Parent = ReplicatedStorage
		end
		folder = existing
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	return folder
end

function Net.Build(): Folder
	assert(IS_SERVER, "Net.Build можно вызывать только на сервере")
	local target = Net.Folder()

	local function ensure(name: string, className: string)
		local existing = target:FindFirstChild(name)
		if existing then

			if existing.ClassName ~= className then
				warn(("[Net] %s был %s, пересоздаю как %s"):format(name, existing.ClassName, className))
				existing:Destroy()
			else
				return
			end
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = target
	end

	for _, name in ipairs(Config.RemoteNames) do
		ensure(name, "RemoteEvent")
	end
	for _, name in ipairs(Config.RemoteFunctionNames) do
		ensure(name, "RemoteFunction")
	end
	for _, name in ipairs(Config.ClientFunctionNames) do
		ensure(name, "RemoteFunction")
	end

	return target
end

local function lookup(name: string, className: string)
	local cached = cache[name]
	if cached and cached.Parent then
		return cached
	end
	local target = Net.Folder()
	local remote = IS_SERVER and target:FindFirstChild(name) or target:WaitForChild(name, 20)
	if not remote then
		error(("[Net] Remote %q не найден — добавь его в Config"):format(name), 2)
	end
	if remote.ClassName ~= className then
		error(("[Net] %q — это %s, а запрошен %s"):format(name, remote.ClassName, className), 2)
	end
	cache[name] = remote
	return remote
end

function Net.Event(name: string): RemoteEvent
	return lookup(name, "RemoteEvent")
end

function Net.Func(name: string): RemoteFunction
	return lookup(name, "RemoteFunction")
end

function Net.Fire(player: Player, name: string, ...)
	Net.Event(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...)
	Net.Event(name):FireAllClients(...)
end

return Net
