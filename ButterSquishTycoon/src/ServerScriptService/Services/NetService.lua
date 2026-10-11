local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Schema = require(Shared:WaitForChild("Schema"))

local DataService = require(script.Parent.DataService)

local NetService = {}

local buckets = {}

local strikes = {}

local boundFunctions = {}

local function limitFor(name: string)
	return Config.Net.Limits[name] or Config.Net.Default
end

local function strikeEntry(player: Player)
	local entry = strikes[player]
	if not entry then
		entry = { Count = 0, Last = os.clock(), MutedUntil = 0 }
		strikes[player] = entry
	end
	if os.clock() - entry.Last > Config.Net.StrikeDecay then
		entry.Count = 0
	end
	return entry
end

local function reject(player: Player, name: string, reason: string)
	local entry = strikeEntry(player)
	entry.Count += 1
	entry.Last = os.clock()

	if Config.Net.LogRejects then
		warn(("[Net] отказ %s → %s: %s (нарушений подряд: %d)")
			:format(player.Name, name, reason, entry.Count))
	end

	if entry.Count >= Config.Net.StrikeLimit then
		entry.MutedUntil = os.clock() + Config.Net.MuteSeconds
		entry.Count = 0
		warn(("[Net] %s заглушён на %d сек: слишком много отказов")
			:format(player.Name, Config.Net.MuteSeconds))
	end
end

local function passesRateLimit(player: Player, name: string): boolean
	local entry = strikeEntry(player)
	if os.clock() < (entry.MutedUntil or 0) then
		return false
	end

	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local limit = limitFor(name)
	local now = os.clock()
	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { Tokens = limit.Burst, Last = now }
		playerBuckets[name] = bucket
	end

	bucket.Tokens = math.min(limit.Burst, bucket.Tokens + (now - bucket.Last) * limit.PerSecond)
	bucket.Last = now

	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function inspect(player: Player, name: string, check, requireProfile: boolean, ...): (boolean, string?)
	if not passesRateLimit(player, name) then
		reject(player, name, "превышен rate-limit")
		return false, Config.Text.NetBusy
	end

	local argsOk, argsErr = check(...)
	if not argsOk then
		reject(player, name, argsErr or "аргументы не прошли схему")
		return false, Config.Text.NetError
	end

	if requireProfile and not DataService.IsLoaded(player) then

		return false, Config.Text.NetNoProfile
	end

	return true, nil
end

function NetService.OnEvent(name: string, argSpec, handler, opts)
	opts = opts or {}
	local requireProfile = opts.RequireProfile ~= false
	local check = Schema.Args(argSpec)
	local remote = Net.Event(name)

	remote.OnServerEvent:Connect(function(player, ...)
		local ok = inspect(player, name, check, requireProfile, ...)
		if not ok then
			return
		end

		local success, err = pcall(handler, player, ...)
		if not success then
			warn(("[Net] обработчик %s упал: %s"):format(name, tostring(err)))
		end
	end)
end

function NetService.OnFunction(name: string, argSpec, handler, opts)
	opts = opts or {}
	local requireProfile = opts.RequireProfile ~= false
	local check = Schema.Args(argSpec)
	local remote = Net.Func(name)

	if boundFunctions[name] then
		error(("[Net] RemoteFunction %q уже имеет обработчик"):format(name), 2)
	end
	boundFunctions[name] = true

	remote.OnServerInvoke = function(player, ...)
		local ok, reason = inspect(player, name, check, requireProfile, ...)
		if not ok then
			return { Ok = false, Reason = reason }
		end

		local success, result = pcall(handler, player, ...)
		if not success then
			warn(("[Net] функция %s упала: %s"):format(name, tostring(result)))

			return { Ok = false, Reason = Config.Text.NetError }
		end

		if type(result) ~= "table" then
			return { Ok = true, Value = result }
		end
		if result.Ok == nil then
			result.Ok = true
		end
		return result
	end
end

function NetService.InvokeClientAsync(player: Player, name: string, payload, timeout: number?)
	local remote = Net.Func(name)
	local state = { Done = false, Result = nil }

	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeClient(player, payload)
		end)
		if state.Done then
			return
		end
		state.Done = true
		state.Result = ok and result or nil
	end)

	local deadline = os.clock() + (timeout or Config.Net.InvokeTimeout)
	while not state.Done and os.clock() < deadline and player.Parent ~= nil do
		task.wait(0.05)
	end

	if not state.Done then
		state.Done = true
		return nil, "timeout"
	end
	return state.Result, nil
end

function NetService.Broadcast(text: string, color: Color3?, icon: string?)
	if not Config.Feed.Enabled then
		return
	end
	Net.FireAll("Broadcast", {
		Text  = text,
		Color = color or Config.Palette.CyberCyan,
		Icon  = icon,
	})
end

function NetService.Init()

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		strikes[player] = nil
	end)
end

return NetService
