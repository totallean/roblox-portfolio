--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Release = require(ReplicatedStorage.SpectrumForge.Shared.Release)

local Root = ServerScriptService.SpectrumForge
local ServiceFolder = Root.Services

local ORDER = {
	"NetService",
	"DataService",
	"CurrencyService",
	"RingService",
	"BuildService",
	"CrateService",
	"RebirthService",
	"BattleService",
	"MonetizationService",
	"TeleportService",
	"DebugService",
}

type Service = {
	Init: ((Service) -> ())?,
	Start: ((Service) -> ())?,
	[any]: any,
}

local services: { [string]: Service } = {}
local loaded = 0

local function get(name: string): Service
	local svc = services[name]
	assert(svc, ("[Bootstrap] сервис %q не найден"):format(name))
	return svc
end

local function runPhase(phase: string)
	for _, name in ORDER do
		local svc = services[name]
		local fn = svc and (svc :: any)[phase]
		if type(fn) ~= "function" then
			continue
		end

		local ok, err = xpcall(fn, debug.traceback, svc)
		if not ok then
			warn(("[Bootstrap] %s:%s() упал: %s"):format(name, phase, tostring(err)))
		end
	end
end

local startedAt = os.clock()

for _, name in ORDER do
	if Release.MODE and name == "DebugService" then
		continue
	end

	local module = ServiceFolder:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(("[Bootstrap] модуль %q отсутствует"):format(name))
		continue
	end

	local ok, result = pcall(require, module)
	if not ok then
		warn(("[Bootstrap] require(%s) упал: %s"):format(name, tostring(result)))
		continue
	end

	result.GetService = get
	services[name] = result
	loaded += 1
end

runPhase("Init")
runPhase("Start")

print(("[SpectrumForge] сервер поднят за %.0f мс, сервисов: %d из %d")
	:format((os.clock() - startedAt) * 1000, loaded, #ORDER))
