local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local NetService = require(script.Parent.NetService)

local InventoryService = {}

InventoryService.OwnsPass = nil
InventoryService.GetBoostLeft = nil

local function lineSize(): number
	local count = 0
	for _, def in ipairs(Config.Stations) do
		if def.Price > 0 then
			count += 1
		end
	end
	return count
end

function InventoryService.Build(player: Player)
	local data = DataService.Get(player)
	if not data then
		return { Ok = false, Reason = Config.Text.NetNoProfile }
	end

	local owned = data.Stations or {}
	local rebirths = data.Rebirths or 0

	local stations = {}
	local ownedCount = 0
	for _, def in ipairs(Config.Stations) do
		if def.Price > 0 then
			local isOwned = owned[def.Id] == true
			local reqOk = (def.Requires == nil) or (owned[def.Requires] == true)
			local rebirthOk = rebirths >= (def.RequiredRebirths or 0)
			if isOwned then
				ownedCount += 1
			end
			table.insert(stations, {
				Id       = def.Id,
				Label    = def.Label,
				Type     = def.Type,
				Price    = def.Price,
				Owned    = isOwned,

				Available = (not isOwned) and reqOk and rebirthOk,
				LockedBy = (not rebirthOk) and def.RequiredRebirths or nil,
			})
		end
	end

	local passes = {}
	for key, pass in pairs(Config.Monetization.GamePasses) do
		table.insert(passes, {
			Key   = key,
			Name  = pass.Name,
			Icon  = pass.Icon,
			Owned = InventoryService.OwnsPass ~= nil and InventoryService.OwnsPass(player, key) == true,
		})
	end

	table.sort(passes, function(a, b)
		if a.Owned ~= b.Owned then
			return a.Owned
		end
		return a.Name < b.Name
	end)

	return {
		Ok = true,

		Stations   = stations,
		OwnedCount = ownedCount,
		LineSize   = lineSize(),
		Passes     = passes,

		Currency     = data.Currency or 0,
		Rebirths     = rebirths,
		TotalEarned  = data.TotalEarned or 0,
		SoldCount    = data.SoldCount or 0,
		Playtime     = data.Playtime or 0,
		Multiplier   = CurrencyService.GetIncomeMultiplier(player),
		IncomePerMin = CurrencyService.EstimateIncomePerMinute(player),
		BoostLeft    = InventoryService.GetBoostLeft and InventoryService.GetBoostLeft(player) or 0,
		HasPlot      = PlotService.GetPlot(player) ~= nil,
	}
end

function InventoryService.Init()

	NetService.OnFunction("GetInventory", {}, function(player)
		return InventoryService.Build(player)
	end)
end

return InventoryService
