--!strict

local Root = script.Parent
local ControllerFolder = Root.Controllers

local ORDER = {
	"StateController",
	"LocaleController",
	"UIController",
	"RingController",
	"BuildController",
	"BattleController",
	"CodexController",
	"ShopController",
	"WheelController",
	"ColorUnlockController",
	"ChatController",
	"ConstructController",
	"ArenaController",
	"LeaderboardController",
	"WorldController",
	"SoundController",
	"TutorialController",
}

local controllers: { [string]: any } = {}

local function get(name: string)
	local ctrl = controllers[name]
	assert(ctrl, ("[Client] контроллер %q не найден"):format(name))
	return ctrl
end

local function runPhase(phase: string)
	for _, name in ORDER do
		local ctrl = controllers[name]
		local fn = ctrl and ctrl[phase]
		if type(fn) ~= "function" then
			continue
		end
		local ok, err = xpcall(fn, debug.traceback, ctrl)
		if not ok then
			warn(("[Client] %s:%s() упал: %s"):format(name, phase, tostring(err)))
		end
	end
end

for _, name in ORDER do
	local module = ControllerFolder:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(("[Client] модуль %q отсутствует"):format(name))
		continue
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn(("[Client] require(%s) упал: %s"):format(name, tostring(result)))
		continue
	end
	result.GetController = get
	controllers[name] = result
end

runPhase("Init")
runPhase("Start")
