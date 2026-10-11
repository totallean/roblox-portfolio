local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = require(script.Parent.DataService)

local CurrencyService = {}

CurrencyService.Changed = Instance.new("BindableEvent")

local providers = {}
local remotes

local function getRemote(name: string): RemoteEvent
	remotes = remotes or ReplicatedStorage:WaitForChild("Remotes")
	return remotes:WaitForChild(name)
end

function CurrencyService.Init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
end

function CurrencyService.RegisterMultiplierProvider(fn)
	table.insert(providers, fn)
end

function CurrencyService.Get(player: Player): number
	local data = DataService.Get(player)
	return data and data.Currency or 0
end

function CurrencyService.GetIncomeMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local mult = 1 + (data.Rebirths or 0) * Config.Rebirth.BonusPerRebirth
	for _, provider in ipairs(providers) do
		local ok, value = pcall(provider, player)
		if ok and type(value) == "number" and value > 0 then
			mult *= value
		end
	end
	return mult
end

function CurrencyService.Push(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	getRemote("CurrencyChanged"):FireClient(player, data.Currency, CurrencyService.GetIncomeMultiplier(player))
end

function CurrencyService.Add(player: Player, amount: number, reason: string?, countAsEarned: boolean?): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return 0
	end
	data.Currency += amount
	if countAsEarned ~= false then
		data.TotalEarned = (data.TotalEarned or 0) + amount
	end
	CurrencyService.Push(player)
	CurrencyService.Changed:Fire(player, data.Currency)
	return amount
end

function CurrencyService.TrySpend(player: Player, amount: number, reason: string?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	amount = math.floor(amount)
	if amount < 0 then
		return false
	end
	if data.Currency < amount then
		return false
	end
	data.Currency -= amount
	CurrencyService.Push(player)
	CurrencyService.Changed:Fire(player, data.Currency)
	return true
end

function CurrencyService.Set(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Currency = math.max(0, math.floor(amount))
	CurrencyService.Push(player)
	CurrencyService.Changed:Fire(player, data.Currency)
end

function CurrencyService.EstimateIncomePerMinute(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local producer = Config.GetStation("Extruder")
	local value = producer.BaseValue
	local intervalScale = 1
	for _, def in ipairs(Config.Stations) do
		if data.Stations[def.Id] then
			if def.Type == "Processor" then
				value *= (def.Multiplier or 1)
			end

			intervalScale *= (def.DropIntervalMultiplier or 1)
		end
	end
	value *= CurrencyService.GetIncomeMultiplier(player)
	return math.floor(value * (60 / math.max(0.1, producer.DropInterval * intervalScale)))
end

return CurrencyService
