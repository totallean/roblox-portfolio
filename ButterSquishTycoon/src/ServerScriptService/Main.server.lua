--[[
	Main.server.lua — точка входа сервера.
	Здесь и только здесь задаётся порядок инициализации и связи между сервисами.
	Сервисы не требуют друг друга «крест-накрест» — вместо этого Main
	подставляет хуки, поэтому циклических require нет.

	Путь: ServerScriptService/Main (Script)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- ═══════════════════════════════════════════════════════════════
-- 1. REMOTES создаются кодом, до старта сервисов
-- ═══════════════════════════════════════════════════════════════
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end
for _, name in ipairs(Config.RemoteNames) do
	if not remotesFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
end

-- ═══════════════════════════════════════════════════════════════
-- 2. СЕРВИСЫ
-- ═══════════════════════════════════════════════════════════════
local Services = script.Parent:WaitForChild("Services")

local DataService         = require(Services.DataService)
local CurrencyService     = require(Services.CurrencyService)
local PlotService         = require(Services.PlotService)
local DropperService      = require(Services.DropperService)
local ProcessService      = require(Services.ProcessService)
local CollectorService    = require(Services.CollectorService)
local ButtonService       = require(Services.ButtonService)
local RebirthService      = require(Services.RebirthService)
local MonetizationService = require(Services.MonetizationService)
local AchievementService  = require(Services.AchievementService)

-- ═══════════════════════════════════════════════════════════════
-- 3. ХУКИ (подставляются ДО Init, чтобы никто не стартовал вслепую)
-- ═══════════════════════════════════════════════════════════════

-- Ускорение линии встроено в сами станции: у каждой могут быть поля
-- DropIntervalMultiplier / ConveyorSpeedMultiplier. Отдельных станций
-- «ускоритель» нет. Множитель пересчитываем целиком из профиля,
-- чтобы результат не зависел от порядка покупок.
local function applySpeedUpgrades(player: Player, plot: Model)
	local data = DataService.Get(player)
	if not data or not plot then
		return
	end
	local dropScale, beltScale = 1, 1
	for _, def in ipairs(Config.Stations) do
		if data.Stations and data.Stations[def.Id] then
			dropScale *= (def.DropIntervalMultiplier or 1)
			beltScale *= (def.ConveyorSpeedMultiplier or 1)
		end
	end
	plot:SetAttribute("DropIntervalScale", dropScale)
	plot:SetAttribute("ConveyorScale", beltScale)
	PlotService.RefreshConveyor(plot)
end

-- Купили станцию → включаем нужный тип поведения. Тип берётся из конфига,
-- поэтому новая станция воска или ускорителя не требует правок здесь.
ButtonService.OnStationEnabled = function(player, plot, def)
	if def.Type == "Producer" then
		PlotService.PlaceStation(plot, def)
		DropperService.EnableStation(plot, def)
	elseif def.Type == "Processor" then
		ProcessService.EnableStation(plot, def)
	end
	-- Тип "Speed" ничего не ставит на плот: у него PlaceModel = false,
	-- работает только кнопка и её эффект на скорость линии
	applySpeedUpgrades(player, plot)
end

-- Вход в игру и ребёрн: множители линии считаем заново с нуля
ButtonService.OnStationsRestored = applySpeedUpgrades

-- Dev Product «Skip Rebirth» → бесплатный ребёрн
MonetizationService.OnSkipRebirth = function(player)
	return RebirthService.DoRebirth(player, true)
end

-- Достижения за покупки спрашивают владение пассами через хук,
-- чтобы не тянуть MonetizationService в AchievementService
AchievementService.OwnsPass = function(player, passKey)
	return MonetizationService.OwnsPass(player, passKey)
end

-- Геймпасс Auto-Collect: «застрявший» брусок продаётся, а не утилизируется
DropperService.OnProductExpired = function(plot, product)
	return MonetizationService.HandleExpiredProduct(plot, product, CollectorService.Sell)
end

-- ═══════════════════════════════════════════════════════════════
-- 4. ПОРЯДОК ИНИЦИАЛИЗАЦИИ
-- ═══════════════════════════════════════════════════════════════
DataService.Init()          -- данные первыми: от них зависят все остальные
CurrencyService.Init()
PlotService.Init()          -- строит плоты из PlotTemplate
DropperService.Init()       -- разогревает пул продуктов
ProcessService.Init()       -- вешает Touched на триггеры станций
CollectorService.Init()     -- вешает Touched на SellZone
ButtonService.Init()        -- вешает Touched на кнопки
RebirthService.Init()
MonetizationService.Init()
AchievementService.Init()

-- ═══════════════════════════════════════════════════════════════
-- 5. СИНХРОНИЗАЦИЯ СОСТОЯНИЯ С UI
-- Remote используется только для отображения. Никаких решений на клиенте.
-- ═══════════════════════════════════════════════════════════════
local function buildState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local goal = Config.GetNextGoal(data.Stations or {}, data.Rebirths or 0)
	-- Пока плот не занят, показывать станцию как цель бессмысленно
	local hasPlot = PlotService.GetPlot(player) ~= nil
	return {
		NeedPlot     = not hasPlot,
		Balance      = data.Currency,
		Rebirths     = data.Rebirths,
		RebirthCost  = Config.RebirthCost(data.Rebirths or 0),
		Multiplier   = CurrencyService.GetIncomeMultiplier(player),
		IncomePerMin = CurrencyService.EstimateIncomePerMinute(player),
		Owned        = data.Stations,
		BoostLeft    = MonetizationService.GetBoostRemaining(player),
		OwnedPasses  = MonetizationService.GetOwnedPasses(player),
		Goal         = (hasPlot and goal) and { Id = goal.Id, Label = goal.Label, Price = goal.Price } or nil,
	}
end

local function pushState(player: Player)
	local state = buildState(player)
	if state then
		remotesFolder.StateSync:FireClient(player, state)
	end
end

remotesFolder.RequestState.OnServerEvent:Connect(function(player)
	-- Sanity check: простой rate-limit, клиент не может спамить
	local now = os.clock()
	local last = player:GetAttribute("_LastStateRequest") or 0
	if now - last < Config.RemoteCooldown then
		return
	end
	player:SetAttribute("_LastStateRequest", now)
	pushState(player)
end)

-- Игрок занял плот (сам или автовыдачей) — поднимаем на нём всё,
-- что он успел купить в прошлых сессиях, и обновляем UI
PlotService.PlotClaimed.Event:Connect(function(player, plot)
	ButtonService.RestorePlayer(player)
	CurrencyService.Push(player)
	pushState(player)
	AchievementService.MarkClaimed(player)
	remotesFolder.Notify:FireClient(player, Config.Text.PlotClaimed, Config.Palette.AcidGreen)
end)

-- ═══════════════════════════════════════════════════════════════
-- 6. FTUE: три шага нового игрока
--   1 → встать на плот   2 → дождаться первой продажи   3 → купить станцию
-- Состояние живёт в профиле (data.Tutorial), а не в Workspace.
-- ═══════════════════════════════════════════════════════════════
-- Показать клиенту шаг, НЕ меняя прогресс (вход в игру, ресинк)
local function pushStep(player: Player, step: number)
	local info = Config.FTUE.Steps[step]
	remotesFolder.FTUEStep:FireClient(player, step, info and info.Text or nil)
end

-- Продвинуть обучение. Строго по одному шагу вперёд: без этого первая
-- же продажа перепрыгивала игрока с 1/3 сразу на 3/3, потому что бруски
-- едут по ленте независимо от того, дошёл игрок до плота или нет.
local function setStep(player: Player, step: number)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if step ~= (data.Tutorial or 0) + 1 then
		return false
	end
	data.Tutorial = step
	pushStep(player, step)
	return true
end

CollectorService.Sold.Event:Connect(function(player)
	-- Шаг 2 «дождись первой продажи» закрыт → шаг 3 «купи станцию».
	-- setStep сам откажет, если игрок ещё не дошёл до плота (шаг 1).
	setStep(player, 3)
	pushState(player)
end)

ButtonService.Purchased.Event:Connect(function(player)
	setStep(player, 4)   -- станция куплена → ведём к панели наград
	pushState(player)
	AchievementService.Check(player)
end)

-- Набор пассов изменился: обновляем витрину магазина и достижения
MonetizationService.PassesChanged.Event:Connect(function(player)
	pushState(player)
	AchievementService.Check(player)
end)

-- Последний шаг обучения: игрок сам открыл панель наград
AchievementService.PanelOpened.Event:Connect(function(player)
	if setStep(player, Config.FTUE.Done) then
		pushState(player)
	end
end)

CurrencyService.Changed.Event:Connect(function(player)
	local now = os.clock()
	local last = player:GetAttribute("_LastStatePush") or 0
	if now - last < 0.4 then
		return
	end
	player:SetAttribute("_LastStatePush", now)
	pushState(player)
end)

-- Проверка «игрок стоит на своём плоте» — раз в секунду, не каждый кадр
local ftueAccum = 0
RunService.Heartbeat:Connect(function(dt)
	ftueAccum += dt
	if ftueAccum < 1 then
		return
	end
	ftueAccum = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(player)
		if data and (data.Tutorial or 0) < Config.FTUE.Done then
			local plot = PlotService.GetPlot(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if plot and root then
				local local_ = plot.Base.CFrame:PointToObjectSpace(root.Position)
				local size = Config.Plot.Size
				if math.abs(local_.X) <= size.X * 0.5 and math.abs(local_.Z) <= size.Z * 0.5 then
					-- Шаг 1 «встань на плот» закрыт → шаг 2 «жди первую продажу»
					if setStep(player, 2) then
						pushState(player)
					end
				end
			end
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- 7. ЖИЗНЕННЫЙ ЦИКЛ ИГРОКА
-- ═══════════════════════════════════════════════════════════════
local function onPlayerAdded(player: Player)
	local loaded = DataService.LoadAsync(player)
	if not loaded then
		player:Kick(Config.Text.KickNoData)
		return
	end
	if not player.Parent then
		DataService.ReleaseAsync(player)
		return
	end

	MonetizationService.OnPlayerAdded(player)

	-- Плот: либо игрок выбирает сам, либо выдаём первый свободный.
	-- Режим задаётся одной строкой в Config.Plot.ClaimMode.
	if Config.Plot.ClaimMode == "Auto" then
		local plot = PlotService.AssignPlot(player)
		if not plot then
			remotesFolder.Notify:FireClient(player, Config.Text.NoFreePlots, Config.Palette.HotRed)
		end
	else
		remotesFolder.Notify:FireClient(player, Config.Text.PickPlot, Config.Palette.AcidGreen)
	end

	CurrencyService.Push(player)
	pushState(player)
	AchievementService.Push(player)

	-- Обучение: 0 — ещё не начато, 1..3 — текущий шаг, 4 — пройдено.
	-- При повторном входе показываем ровно тот шаг, на котором остановились.
	local data = DataService.Get(player)
	if data then
		local step = data.Tutorial or 0
		if step == 0 then
			setStep(player, 1)
		else
			pushStep(player, step)   -- показываем шаг, на котором остановились
		end
	end
end

local function onPlayerRemoving(player: Player)
	-- Плот освобождается ПОЛНОСТЬЮ и уходит следующему игроку
	PlotService.ReleasePlot(player)
	MonetizationService.OnPlayerRemoving(player)
	DataService.ReleaseAsync(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Игроки, успевшие зайти до старта скрипта (актуально для Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("🧈 Butter Squish Tycoon: сервер поднят, плотов —", Config.Plot.Count)
