--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.SpectrumForge.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local StateController = {}

local state: { [string]: any } = {}
local signals: { [string]: Signal.Class } = {}
local lastSyncClock = 0
local actionRemote: RemoteEvent? = nil

StateController.Ready = Signal.new()
StateController.Notified = Signal.new()

local ready = false

local function signalFor(key: string): Signal.Class
	local existing = signals[key]
	if existing then
		return existing
	end
	local created = Signal.new()
	signals[key] = created
	return created
end

function StateController:Get(key: string): any
	return state[key]
end

function StateController:IsReady(): boolean
	return ready
end

function StateController:GetWill(): number
	local will = state.will or 0
	local wps = state.wps or 0
	if lastSyncClock == 0 then
		return will
	end
	return will + wps * (os.clock() - lastSyncClock)
end

function StateController:Observe(key: string, fn: (any) -> ()): Signal.Connection
	local connection = signalFor(key):Connect(fn)
	if state[key] ~= nil then
		task.spawn(fn, state[key])
	end
	return connection
end

function StateController:ObserveAll(keys: { string }, fn: () -> ()): Signal.Connection
	local scheduled = false
	local function schedule()
		if scheduled then
			return
		end
		scheduled = true
		task.defer(function()
			scheduled = false
			fn()
		end)
	end

	local connections: { Signal.Connection } = {}
	for _, key in keys do
		table.insert(connections, signalFor(key):Connect(schedule))
	end

	for _, key in keys do
		if state[key] ~= nil then
			schedule()
			break
		end
	end

	local group = {}
	function group.Disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	return group :: any
end

function StateController:Init()
	local remotes = Net.waitForRemotes()

	remotes[Net.SYNC].OnClientEvent:Connect(function(patch)
		if type(patch) ~= "table" then
			return
		end

		local changed = {}
		for key, value in patch do
			state[key] = value
			table.insert(changed, key)
		end

		if patch.will ~= nil or patch.wps ~= nil then
			lastSyncClock = os.clock()
		end

		for _, key in changed do
			local signal = signals[key]
			if signal then
				signal:Fire(state[key])
			end
		end

		if not ready and state.ringLevel ~= nil then
			ready = true
			StateController.Ready:Fire(state)
		end
	end)

	remotes[Net.NOTIFY].OnClientEvent:Connect(function(kind, payload)
		StateController.Notified:Fire(kind, payload)
	end)
end

function StateController:Start()
	self:Send("Ready")
end

function StateController:Send(action: string, ...: any)
	local remote = actionRemote
	if not remote then
		remote = Net.waitForRemotes():WaitForChild(Net.ACTION) :: RemoteEvent
		actionRemote = remote
	end
	(remote :: RemoteEvent):FireServer(action, ...)
end

return StateController
