--[[
	PlotService — выдача/освобождение плота и вся геометрия слотов.

	Ключевая идея: ВСЯ сцена плота генерируется из Config.
	EnsureLayout(plot) идемпотентна — можно звать и в Edit-режиме (чтобы
	человек увидел слоты в ServerStorage.PlotTemplate), и в рантайме.
	Добавил станцию одной строкой в Config.Stations — при следующем
	запуске у неё появятся слот, триггер и кнопка. Логику править не нужно.

	Слоты под Toolbox:
	  • визуальный объект = Model с точным именем Slot_* и одним Part
	    внутри с именем Placeholder; у Model проставлен PrimaryPart;
	  • служебные Part'ы (DropPoint, SellZone, Trigger_*) лежат отдельно,
	    Transparency = 1, CanCollide = false, и не двигаются при замене модели;
	  • атрибуты SlotSize / FacingDirection подсказывают габарит модели.
]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlotService = {}

-- Сигнал: (player, plot) — игрок занял плот. Main поднимает по нему
-- станции, баланс и обучение.
PlotService.PlotClaimed = Instance.new("BindableEvent")

local plotsFolder: Folder
local ownedByPlayer = {}   -- [player] = plot Model
local setupHooks = {}      -- вызываются при выдаче плота
local cleanupHooks = {}    -- вызываются при освобождении плота

local TOP_Y = Config.Plot.Size.Y * 0.5   -- смещение от центра базы до её верха

-- ═══════════════════════════════════════════════════════════════
-- ГЕОМЕТРИЧЕСКИЕ ХЕЛПЕРЫ
-- ═══════════════════════════════════════════════════════════════

-- Локальный офсет (от центра ВЕРХНЕЙ плоскости базы) → мировой CFrame
function PlotService.LocalCF(plot: Model, offset: Vector3): CFrame
	return plot:GetPivot() * CFrame.new(offset.X, offset.Y + TOP_Y, offset.Z)
end

local function ensurePart(parent: Instance, name: string, props): BasePart
	local part = parent:FindFirstChild(name)
	if not part or not part:IsA("BasePart") then
		if part then part:Destroy() end
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function ensureFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if not folder or not folder:IsA("Folder") then
		if folder then folder:Destroy() end
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

-- Жирная подпись с обводкой на грани детали (retro-slop)
function PlotService.AddLabel(part: BasePart, text: string, color: Color3, face: Enum.NormalId?, guiName: string?)
	local name = guiName or "SlotLabel"
	local gui = part:FindFirstChild(name)
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.Parent = part
	end
	gui.Face = face or Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0

	local label = gui:FindFirstChild("Text")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Parent = gui
	end
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Config.Style.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Config.Style.TextColor

	local stroke = label:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = label
	end
	stroke.Color = Config.Style.StrokeColor
	stroke.Thickness = Config.Style.WorldStroke
	return gui
end

-- Слот под Toolbox: Model + один Placeholder Part + PrimaryPart
function PlotService.EnsureSlotModel(parent: Instance, slotName: string, opts): Model
	local model = parent:FindFirstChild(slotName)
	if not model or not model:IsA("Model") then
		if model then model:Destroy() end
		model = Instance.new("Model")
		model.Name = slotName
		model.Parent = parent
	end

	-- Если человек уже заменил плейсхолдер моделью из Toolbox — НЕ трогаем геометрию,
	-- только чиним PrimaryPart, чтобы слот оставался переносимым одной операцией.
	local placeholder = model:FindFirstChild("Placeholder")
	local hasCustomGeometry = (placeholder == nil) and (model:FindFirstChildWhichIsA("BasePart", true) ~= nil)

	if hasCustomGeometry then
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
	else
		placeholder = ensurePart(model, "Placeholder", {
			Shape = opts.Shape or Enum.PartType.Block,
			Size = opts.Size,
			Color = opts.Color or Config.Palette.Butter,
			Material = opts.Material or Enum.Material.SmoothPlastic,
			Transparency = opts.Transparency or 0,
			CanCollide = opts.CanCollide ~= false,
			Reflectance = opts.Reflectance or 0.15,
		})
		model.PrimaryPart = placeholder
	end

	-- Подсказки для человека, который будет менять плейсхолдер на модель
	model:SetAttribute("SlotSize", opts.Size)
	model:SetAttribute("FacingDirection", opts.Facing or Vector3.new(0, 0, 1))
	model:SetAttribute("SlotName", slotName)

	if opts.Label and placeholder then
		PlotService.AddLabel(placeholder, opts.Label, opts.LabelColor or Config.Palette.White, opts.LabelFace)
	end
	if opts.Tag then
		CollectionService:AddTag(model, opts.Tag)
	end
	if opts.Attributes then
		for key, value in pairs(opts.Attributes) do
			model:SetAttribute(key, value)
		end
	end
	return model
end

-- Осветлить цвет на N единиц RGB — лего-шип светлее своей плитки
local function lighten(color: Color3, amount: number): Color3
	local add = amount / 255
	return Color3.new(
		math.clamp(color.R + add, 0, 1),
		math.clamp(color.G + add, 0, 1),
		math.clamp(color.B + add, 0, 1))
end

-- ═══════════════════════════════════════════════════════════════
-- ПОЛ ЦЕХА
-- Сетка плиток с зазором: тот же приём, что даёт «выдавленный» рисунок
-- в садовых тайкунах, только сталь вместо газона. Плитки чисто
-- декоративные: CanCollide/CanTouch/CanQuery = false, ходим по Base.
-- ═══════════════════════════════════════════════════════════════
local function buildFloor(plot: Model, place)
	local cfg = Config.Floor
	local folder = ensureFolder(plot, "Floor")
	if not cfg.Enabled then
		folder:ClearAllChildren()
		return
	end

	-- Пересобираем только когда изменились настройки, а не на каждый вызов
	local signature = ("%s|%s|%s|%s|%s|%s|%s"):format(tostring(Config.Plot.Size), cfg.TileSize,
		cfg.Gap, cfg.LaneHalfWidth, cfg.HazardCenter,
		tostring(cfg.TilesEnabled), tostring(cfg.HazardEnabled))
	if folder:GetAttribute("Signature") == signature then
		return
	end
	folder:ClearAllChildren()
	folder:SetAttribute("Signature", signature)

	local function decorPart(name: string, size: Vector3, color: Color3, offset: Vector3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or cfg.Material
		part.Reflectance = cfg.Reflectance
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = place(offset)
		part.Parent = folder
		return part
	end

	local size = Config.Plot.Size
	local tile = cfg.TileSize
	local cols = math.floor(size.X / tile)
	local rows = math.floor(size.Z / tile)
	local startX = -size.X * 0.5 + tile * 0.5
	local startZ = -size.Z * 0.5 + tile * 0.5
	-- Плитка с лего-шипами по умолчанию выключена: этот рельеф живёт
	-- на общей серой плите-земле, а не на каждом плоте
	for cx = 0, (cfg.TilesEnabled and cols - 1 or -1) do
		local x = startX + cx * tile
		-- Коридор линии оставляем без плитки: там лента и разметка
		if math.abs(x) >= cfg.LaneHalfWidth then
			for cz = 0, rows - 1 do
				local z = startZ + cz * tile
				local checker = ((cx + cz) % 2 == 0)
				local tileColor = checker and cfg.ColorA or cfg.ColorB

				decorPart(("Tile_%d_%d"):format(cx, cz),
					Vector3.new(tile - cfg.Gap, cfg.Thickness, tile - cfg.Gap),
					tileColor,
					Vector3.new(x, cfg.Thickness * 0.5, z))

				-- Лего-шип: приподнятый квадрат в центре плитки.
				-- Именно он даёт «выдавленный» рельеф с фотографии.
				if cfg.StudEnabled then
					local studSide = tile - cfg.Gap - cfg.StudInset * 2
					if studSide > 0.5 then
						decorPart(("Stud_%d_%d"):format(cx, cz),
							Vector3.new(studSide, cfg.StudHeight, studSide),
							lighten(tileColor, cfg.StudLighten),
							Vector3.new(x, cfg.Thickness + cfg.StudHeight * 0.5, z),
							cfg.StudMaterial)
					end
				end
			end
		end
	end

	-- Жёлто-чёрная разметка по обе стороны от линии — она размечает
	-- конвейер и остаётся, даже когда плитка выключена
	if not cfg.HazardEnabled then
		return
	end
	local segments = math.floor(size.Z / cfg.HazardSegment)
	local hazardStartZ = -size.Z * 0.5 + cfg.HazardSegment * 0.5
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, segments - 1 do
			local z = hazardStartZ + i * cfg.HazardSegment
			decorPart(("Hazard_%d_%d"):format(side, i),
				Vector3.new(cfg.HazardWidth, cfg.Thickness, cfg.HazardSegment - cfg.Gap),
				(i % 2 == 0) and Config.Palette.HazardYell or Config.Palette.HazardDark,
				Vector3.new(side * cfg.HazardCenter, cfg.Thickness * 0.5, z))
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ЗАБОР
-- Один прямой прогон = столбы + поручни + сетчатая панель между ними.
-- Это настоящая ограда, которую видно, а не светящийся фон.
-- Функция общая: ею строится и забор плота, и периметр всего завода.
--
-- cfFor(position, dir?) -> CFrame — переводит точку в мировую систему.
-- Для плота это place() из EnsureLayout, для карты — мировые координаты.
-- ═══════════════════════════════════════════════════════════════
local function buildFenceRun(parent: Instance, runName: string, cfg, cfFor, fromPoint: Vector3, toPoint: Vector3): Model?
	local delta = toPoint - fromPoint
	local length = delta.Magnitude
	if length < 1 then
		return nil
	end
	local direction = delta.Unit
	local center = fromPoint + delta * 0.5
	local height = cfg.Height

	local model = parent:FindFirstChild("Slot_Fence_" .. runName)
	if not model or not model:IsA("Model") then
		if model then model:Destroy() end
		model = Instance.new("Model")
		model.Name = "Slot_Fence_" .. runName
		model.Parent = parent
	end

	-- Сетчатая панель — она же Placeholder: весь прогон меняется
	-- на модель из Toolbox одной операцией.
	local panel = ensurePart(model, "Placeholder", {
		Size = Vector3.new(cfg.MeshThickness, height * 0.9, length),
		Color = cfg.MeshColor,
		Material = cfg.MeshMaterial,
		Transparency = cfg.MeshTransparency,
		Reflectance = 0,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	panel.CFrame = cfFor(center + Vector3.new(0, height * 0.45, 0), direction)
	model.PrimaryPart = panel

	-- Поручни
	for index, fraction in ipairs(cfg.RailHeights) do
		local rail = ensurePart(model, "Rail_" .. index, {
			Size = Vector3.new(cfg.RailThickness, cfg.RailThickness, length),
			Color = cfg.RailColor,
			Material = cfg.RailMaterial,
			Reflectance = 0,
			Transparency = 0,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		rail.CFrame = cfFor(center + Vector3.new(0, height * fraction, 0), direction)
	end

	-- Столбы через равные промежутки, крайние — точно по концам прогона
	local spans = math.max(1, math.floor(length / cfg.PostEvery + 0.5))
	for i = 0, spans do
		local point = fromPoint + delta * (i / spans)
		local post = ensurePart(model, "Post_" .. i, {
			Size = Vector3.new(cfg.PostWidth, height * 1.06, cfg.PostWidth),
			Color = cfg.PostColor,
			Material = cfg.PostMaterial,
			Reflectance = 0.05,
			Transparency = 0,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		post.CFrame = cfFor(point + Vector3.new(0, height * 0.53, 0))
	end

	model:SetAttribute("SlotSize", Vector3.new(cfg.MeshThickness, height, length))
	model:SetAttribute("SlotName", model.Name)
	model:SetAttribute("FacingDirection", direction)
	return model
end

-- ═══════════════════════════════════════════════════════════════
-- ОГРАЖДЕНИЕ ПЛОТА
-- Видимая ограда — заменяемые слоты Slot_Fence_*. Столкновение держит
-- отдельный невидимый Barrier_*, который выше ограды: игрок не
-- перепрыгнет и не свалится, даже если ограду заменят на модель из Toolbox.
-- ═══════════════════════════════════════════════════════════════
local function buildFence(plot: Model, place)
	local cfg = Config.Fence
	local folder = ensureFolder(plot, "Fence")
	if not cfg.Enabled then
		folder:ClearAllChildren()
		return
	end

	local size = Config.Plot.Size
	local signature = ("%s|%s|%s|%s|%s|%s"):format(tostring(size), cfg.Height, cfg.PostEvery,
		cfg.PostWidth, cfg.GapWidth, cfg.GapCenterX)
	if folder:GetAttribute("Signature") == signature then
		return
	end
	folder:ClearAllChildren()
	folder:SetAttribute("Signature", signature)

	local halfX, halfZ = size.X * 0.5, size.Z * 0.5
	local inset = cfg.PostWidth * 0.5
	local corner = cfg.PostWidth   -- чтобы угловые столбы не наложились друг на друга

	local function run(name: string, fromPoint: Vector3, toPoint: Vector3)
		buildFenceRun(folder, name, cfg, place, fromPoint, toPoint)

		local delta = toPoint - fromPoint
		local length = delta.Magnitude
		local barrierHeight = cfg.Height + cfg.BarrierExtra
		local barrier = ensurePart(folder, "Barrier_" .. name, {
			Size = Vector3.new(cfg.BarrierThickness, barrierHeight, length),
			Transparency = 1,
			CanCollide = true,
			CanTouch = false,
			CanQuery = false,
		})
		barrier.CFrame = place(fromPoint + delta * 0.5 + Vector3.new(0, barrierHeight * 0.5, 0), delta.Unit)
	end

	-- Боковые стороны идут во всю длину, их концы и образуют углы
	run("West", Vector3.new(-halfX + inset, 0, -halfZ + inset), Vector3.new(-halfX + inset, 0, halfZ - inset))
	run("East", Vector3.new(halfX - inset, 0, -halfZ + inset), Vector3.new(halfX - inset, 0, halfZ - inset))
	run("North", Vector3.new(-halfX + inset + corner, 0, halfZ - inset), Vector3.new(halfX - inset - corner, 0, halfZ - inset))

	-- Южная сторона с проёмом: игрок заходит со стороны спавна.
	-- Проём смещён вбок (GapCenterX), чтобы вход не приходился на ленту.
	local gapCenter = math.clamp(cfg.GapCenterX, -halfX + cfg.GapWidth * 0.5, halfX - cfg.GapWidth * 0.5)
	local southZ = -halfZ + inset
	local leftEnd = gapCenter - cfg.GapWidth * 0.5
	local rightStart = gapCenter + cfg.GapWidth * 0.5
	local westEdge = -halfX + inset + corner
	local eastEdge = halfX - inset - corner

	if leftEnd > westEdge + 1 then
		run("South_L", Vector3.new(westEdge, 0, southZ), Vector3.new(leftEnd, 0, southZ))
	end
	if rightStart < eastEdge - 1 then
		run("South_R", Vector3.new(rightStart, 0, southZ), Vector3.new(eastEdge, 0, southZ))
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ФАБРИЧНЫЙ ДЕКОР — цистерны, трубы, ящики, пульт, вытяжка.
-- Логика их не знает: список целиком в Config.Decor.
-- ═══════════════════════════════════════════════════════════════
local function buildDecor(plot: Model, place)
	local folder = ensureFolder(plot, "Decor")
	for _, def in ipairs(Config.Decor) do
		local slot = PlotService.EnsureSlotModel(folder, "Slot_Decor_" .. def.Id, {
			Size = def.Size,
			Shape = def.Shape,
			Color = def.Color,
			Material = def.Material,
			Reflectance = def.Reflectance or 0.1,
			CanCollide = def.CanCollide ~= false,
			Facing = Vector3.new(0, 0, 1),
			Label = (def.Label ~= "" and def.Label) or nil,
			Attributes = { DecorId = def.Id },
		})
		local rotation = def.Rotation or Vector3.zero
		slot:PivotTo(place(def.Offset) * CFrame.Angles(
			math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))

		-- Спуски до пола. Форму, диаметр, цвет и материал берём у самой
		-- трубы: вниз уходит такая же труба, а не отдельная колонна.
		if def.Legs then
			local diameter = def.Size.Y          -- у лежачего цилиндра Y = диаметр
			local halfSpan = def.Size.X * 0.5 - (def.Legs.Inset or 0)
			local height = def.Offset.Y
			for index, side in ipairs({ -1, 1 }) do
				local leg = ensurePart(slot, "Leg_" .. index, {
					Shape = def.Shape or Enum.PartType.Block,
					-- Ось цилиндра — X, поэтому длина идёт в X, а деталь
					-- доворачивается на 90 градусов вокруг Z
					Size = Vector3.new(height, diameter, diameter),
					Color = def.Color,
					Material = def.Material,
					Reflectance = def.Reflectance or 0.1,
					CanCollide = false,
					CanTouch = false,
					CanQuery = false,
				})
				leg.CFrame = place(Vector3.new(side * halfSpan, height * 0.5, def.Offset.Z))
					* CFrame.Angles(0, 0, math.rad(90))
			end
		end

		-- Обручи бочки: кольца чуть шире корпуса, форма и поворот те же
		if def.Bands then
			local barrelHeight = def.Size.X   -- у стоячего цилиндра длина идёт в X
			local diameter = def.Size.Y + def.Bands.Overhang
			for index, fraction in ipairs(def.Bands.Heights) do
				local band = ensurePart(slot, "Band_" .. index, {
					Shape = def.Shape or Enum.PartType.Block,
					Size = Vector3.new(def.Bands.Thickness, diameter, diameter),
					Color = def.Bands.Color,
					Material = Enum.Material.Metal,
					Reflectance = 0.05,
					CanCollide = false,
					CanTouch = false,
					CanQuery = false,
				})
				band.CFrame = place(Vector3.new(def.Offset.X, barrelHeight * fraction, def.Offset.Z))
					* CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
end

-- Ориентация: деталь «смотрит» в сторону dir
local function lookCF(position: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + dir.Unit)
end

-- ═══════════════════════════════════════════════════════════════
-- ПРЕФАБЫ СТАНЦИЙ В ServerStorage/Stations
-- Ставятся на плот при покупке. Человек меняет их один раз здесь —
-- и они применяются ко всем плотам сразу.
-- ═══════════════════════════════════════════════════════════════
function PlotService.EnsureStationPrefabs(): Folder
	local folder = ensureFolder(ServerStorage, "Stations")
	for _, def in ipairs(Config.Stations) do
		-- PlaceModel = false → у станции нет визуала (кнопки ускорения),
		-- префаб ей не нужен
		if def.PlaceModel ~= false then
		PlotService.EnsureSlotModel(folder, "Slot_" .. def.Id, {
			Size = def.SlotSize,
			Color = def.SlotColor,
			Material = Enum.Material.Neon,
			Reflectance = 0.2,
			Facing = def.FacingDirection,
			Label = def.Label,
			LabelColor = Config.Palette.White,
			Attributes = { StationId = def.Id },
		})
		end
	end
	return folder
end

-- ═══════════════════════════════════════════════════════════════
-- РАЗМЕТКА ПЛОТА (идемпотентно)
-- ═══════════════════════════════════════════════════════════════
function PlotService.EnsureLayout(plot: Model)
	-- База
	local base = ensurePart(plot, "Base", {
		Size = Config.Plot.Size,
		Color = Config.Plot.BaseColor,
		Material = Config.Plot.BaseMaterial,
	})
	plot.PrimaryPart = base

	local conveyorFolder = ensureFolder(plot, "Conveyor")
	local visualsFolder  = ensureFolder(plot, "Visuals")
	local buttonsFolder  = ensureFolder(plot, "Buttons")
	local triggersFolder = ensureFolder(plot, "Triggers")
	ensureFolder(plot, "Slots")     -- сюда клонируются купленные станции
	ensureFolder(plot, "Products")  -- активные бруски масла

	local pivot = plot:GetPivot()
	local function place(offset: Vector3, dir: Vector3?): CFrame
		local worldPos = (pivot * CFrame.new(offset.X, offset.Y + TOP_Y, offset.Z)).Position
		return dir and lookCF(worldPos, (pivot:VectorToWorldSpace(dir))) or CFrame.new(worldPos)
	end

	-- ── Табличка владельца ──────────────────────────────────────
	local sign = ensurePart(visualsFolder, "OwnerSign", {
		Size = Vector3.new(20, 6, 1),
		Color = Config.Palette.Void,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	sign.CFrame = place(Config.Plot.SignOffset, Vector3.new(0, 0, -1))
	PlotService.AddLabel(sign, Config.Text.PlotVacant, Config.Palette.Butter)

	-- ── Пол цеха, ограждение и фабричный декор ──────────────────
	buildFloor(plot, place)
	buildFence(plot, place)
	buildDecor(plot, place)

	-- ── Конвейер: N сегментов вдоль локальной +Z ────────────────
	local segSize = Config.Conveyor.SegmentSize
	for i = 1, Config.Conveyor.SegmentCount do
		local z = Config.Conveyor.StartZ + (i - 1) * segSize.Z
		local slot = PlotService.EnsureSlotModel(conveyorFolder, "Slot_Conveyor_" .. i, {
			Size = segSize,
			Color = Config.Conveyor.Color,
			Material = Config.Conveyor.Material,
			Reflectance = 0,
			Facing = Vector3.new(0, 0, 1),
			Tag = Config.Tags.Conveyor,
			Attributes = { SegmentIndex = i },
		})
		-- LookVector сегмента = направление движения ленты
		slot:PivotTo(place(Vector3.new(0, segSize.Y * 0.5, z), Vector3.new(0, 0, 1)))
	end

	-- Невидимые бортики, чтобы брусок не слетал с ленты
	local length = Config.Conveyor.SegmentCount * segSize.Z
	local midZ = Config.Conveyor.StartZ + length * 0.5 - segSize.Z * 0.5
	for _, side in ipairs({ { "Rail_L", -1 }, { "Rail_R", 1 } }) do
		local rail = ensurePart(conveyorFolder, side[1], {
			Size = Vector3.new(0.5, Config.Conveyor.RailHeight, length),
			Transparency = 1,
			CanCollide = true,
		})
		rail.CFrame = place(Vector3.new(side[2] * (segSize.X * 0.5 + 0.25), Config.Conveyor.RailHeight * 0.5, midZ))
	end

	-- ── Служебные Part'ы ────────────────────────────────────────
	local producer = Config.GetStation("Extruder")
	local dropPoint = ensurePart(triggersFolder, "DropPoint", {
		Size = Vector3.new(2, 2, 2),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	dropPoint.CFrame = place(Vector3.new(0, Config.Product.DropHeight, Config.Conveyor.StartZ))

	-- ── Коллектор: неоновый блок + отдельная невидимая зона продажи ─
	local collectorSlot = PlotService.EnsureSlotModel(visualsFolder, "Slot_Collector", {
		Size = Config.Collector.SlotSize,
		Color = Config.Collector.Color,
		Material = Config.Collector.Material,
		Reflectance = 0.1,
		CanCollide = false,   -- блок продажи не должен перегораживать ленту
		Facing = Vector3.new(0, 0, -1),
		Label = Config.Collector.Label,
		Tag = Config.Tags.Collector,
		Attributes = { StationId = "Collector" },
	})
	collectorSlot:PivotTo(place(Config.Collector.Offset, Vector3.new(0, 0, -1)))

	local sellZone = ensurePart(triggersFolder, "SellZone", {
		Size = Vector3.new(Config.Conveyor.SegmentSize.X + 2, 10, 3),
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
	})
	sellZone.CFrame = place(Vector3.new(0, 4, Config.Collector.Offset.Z - Config.Collector.SlotSize.Z * 0.5 - 1.5))
	CollectionService:AddTag(sellZone, Config.Tags.Trigger)
	sellZone:SetAttribute("Kind", "Collector")

	-- ── По одной записи на каждую станцию из конфига ────────────
	for _, def in ipairs(Config.Stations) do
		-- Триггер станции: невидимый Part поперёк ленты, НЕ часть визуала
		if def.Type == "Processor" then
			local trigger = ensurePart(triggersFolder, "Trigger_" .. def.Id, {
				Size = Config.Station.TriggerSize,
				Transparency = 1,
				CanCollide = false,
				CanTouch = true,
			})
			trigger.CFrame = place(Vector3.new(0, Config.Station.TriggerSize.Y * 0.5, def.Offset.Z))
			CollectionService:AddTag(trigger, Config.Tags.Trigger)
			trigger:SetAttribute("Kind", "Station")
			trigger:SetAttribute("StationId", def.Id)
			trigger:SetAttribute("Enabled", false)
		end

		-- Пустой якорь под будущую модель станции: помечаем позицию
		local anchor = ensurePart(triggersFolder, "Anchor_" .. def.Id, {
			Size = Vector3.new(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		anchor.CFrame = place(def.Offset, def.FacingDirection)
		anchor:SetAttribute("StationId", def.Id)

		-- Buy-кнопка: визуальный слот + отдельный невидимый триггер
		PlotService.EnsureButtonSlot(plot, buttonsFolder, triggersFolder, place, {
			Id = def.Id,
			Label = def.Label,
			Offset = def.ButtonOffset,
			Color = def.SlotColor,
		})
	end

	-- ── Площадка «занять плот» ──────────────────────────────────
	-- Визуал — обычный слот, столкновение и надпись — отдельный
	-- невидимый триггер, как у всех остальных кнопок.
	local claimCfg = Config.Plot.Claim
	local claimSlot = PlotService.EnsureSlotModel(visualsFolder, "Slot_ClaimPad", {
		Size = claimCfg.Size,
		Color = claimCfg.Color,
		Material = claimCfg.Material,
		Reflectance = 0,
		CanCollide = false,
		Facing = Vector3.new(0, 1, 0),
	})
	claimSlot:PivotTo(place(claimCfg.Offset + Vector3.new(0, claimCfg.Size.Y * 0.5, 0)))

	local claimTrigger = ensurePart(triggersFolder, "ClaimPad", {
		Size = claimCfg.TriggerSize,
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
	})
	claimTrigger.CFrame = place(claimCfg.Offset + Vector3.new(0, claimCfg.TriggerSize.Y * 0.5, 0))
	CollectionService:AddTag(claimTrigger, Config.Tags.Trigger)
	claimTrigger:SetAttribute("Kind", "Claim")

	local claimGui = claimTrigger:FindFirstChild("ClaimLabel")
	if not claimGui then
		claimGui = Instance.new("BillboardGui")
		claimGui.Name = "ClaimLabel"
		claimGui.Parent = claimTrigger
	end
	claimGui.Size = UDim2.fromScale(12, 4)
	claimGui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)   -- ниже стрелки обучения
	claimGui.MaxDistance = 220
	local claimText = claimGui:FindFirstChild("Text")
	if not claimText then
		claimText = Instance.new("TextLabel")
		claimText.Name = "Text"
		claimText.Parent = claimGui
	end
	claimText.Size = UDim2.fromScale(1, 1)
	claimText.BackgroundTransparency = 1
	claimText.Font = Config.Style.Font
	claimText.TextScaled = true
	claimText.Text = claimCfg.Label
	claimText.TextColor3 = claimCfg.Color
	if not claimText:FindFirstChildOfClass("UIStroke") then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Config.Style.StrokeColor
		stroke.Thickness = Config.Style.WorldStroke
		stroke.Parent = claimText
	end

	-- ── Кнопка ребёрна — та же механика, отдельная ветка ────────
	PlotService.EnsureButtonSlot(plot, buttonsFolder, triggersFolder, place, {
		Id = "Rebirth",
		Label = Config.Rebirth.Label,
		Offset = Config.Rebirth.ButtonOffset,
		Color = Config.Rebirth.Color,
	})

	CollectionService:AddTag(plot, Config.Tags.Plot)
	if plot:GetAttribute("OwnerUserId") == nil then
		plot:SetAttribute("OwnerUserId", 0)
	end
	PlotService.RefreshClaimPad(plot)
end

-- Площадка видна, только пока плот свободен и включён ручной выбор
function PlotService.RefreshClaimPad(plot: Model)
	local cfg = Config.Plot.Claim
	local visuals = plot:FindFirstChild("Visuals")
	local triggers = plot:FindFirstChild("Triggers")
	if not visuals or not triggers then
		return
	end
	local slot = visuals:FindFirstChild("Slot_ClaimPad")
	local trigger = triggers:FindFirstChild("ClaimPad")
	if not slot or not trigger then
		return
	end

	local free = plot:GetAttribute("OwnerUserId") == 0 and Config.Plot.ClaimMode == "Manual"
	local shownCF = PlotService.LocalCF(plot, cfg.Offset + Vector3.new(0, cfg.Size.Y * 0.5, 0))
	slot:PivotTo(free and shownCF or (shownCF - Vector3.new(0, cfg.HiddenDrop, 0)))
	trigger.CanTouch = free
	local gui = trigger:FindFirstChild("ClaimLabel")
	if gui then
		gui.Enabled = free
	end
end

function PlotService.EnsureButtonSlot(plot, buttonsFolder, triggersFolder, place, info)
	local slot = PlotService.EnsureSlotModel(buttonsFolder, "Slot_BuyButton_" .. info.Id, {
		Size = Config.Buttons.PadSize,
		Color = info.Color,
		Material = Enum.Material.Neon,
		Reflectance = 0,
		Facing = Vector3.new(0, 1, 0),
		Tag = Config.Tags.BuyButton,
		Attributes = { StationId = info.Id },
	})
	slot:PivotTo(place(info.Offset + Vector3.new(0, Config.Buttons.PadSize.Y * 0.5, 0)))

	-- Триггер кнопки — отдельный невидимый Part. На нём же висит ценник,
	-- чтобы подпись пережила замену визуальной модели из Toolbox.
	local trigger = ensurePart(triggersFolder, "Button_" .. info.Id, {
		Size = Config.Buttons.TriggerSize,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,   -- включится, когда кнопка станет видимой
	})
	trigger.CFrame = place(info.Offset + Vector3.new(0, Config.Buttons.TriggerSize.Y * 0.5, 0))
	CollectionService:AddTag(trigger, Config.Tags.Trigger)
	trigger:SetAttribute("Kind", "Button")
	trigger:SetAttribute("StationId", info.Id)

	local billboard = trigger:FindFirstChild("Price")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "Price"
		billboard.Parent = trigger
	end
	billboard.Size = UDim2.fromScale(9, 3.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140
	billboard.Enabled = false

	local text = billboard:FindFirstChild("Text")
	if not text then
		text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Parent = billboard
	end
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Config.Style.Font
	text.TextScaled = true
	text.RichText = true
	text.Text = info.Label
	text.TextColor3 = Config.Style.TextColor
	if not text:FindFirstChildOfClass("UIStroke") then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Config.Style.StrokeColor
		stroke.Thickness = Config.Style.WorldStroke
		stroke.Parent = text
	end

	-- Стартовое состояние: кнопка спрятана, ButtonService поднимет нужные
	slot:SetAttribute("Shown", false)
	return slot
end

-- ═══════════════════════════════════════════════════════════════
-- ЩИТ С НАЗВАНИЕМ ЗАВОДА
-- Отдельная конструкция на двух столбах в проходе перед плотами.
-- Надпись нанесена на ОБЕ грани щита: её видно и от спавна, и из цеха.
-- ═══════════════════════════════════════════════════════════════
function PlotService.EnsureFactorySign(): Model?
	local cfg = Config.FactorySign
	local folder = ensureFolder(workspace, "FactorySign")
	if not cfg.Enabled then
		folder:ClearAllChildren()
		return nil
	end

	local groundY = Config.WorldBounds.GroundY
	local centerX = Config.Plot.Origin.X

	local slot = PlotService.EnsureSlotModel(folder, "Slot_FactorySign", {
		Size = cfg.BoardSize,
		Color = cfg.BoardColor,
		Material = cfg.BoardMaterial,
		Reflectance = 0,
		CanCollide = false,
		Facing = Vector3.new(0, 0, -1),
	})
	local board = slot.PrimaryPart
	board.CFrame = CFrame.new(centerX, groundY + cfg.BoardHeight, cfg.Z)

	-- Надпись с двух сторон
	PlotService.AddLabel(board, cfg.Text, cfg.TextColor, Enum.NormalId.Front, "SignFront")
	PlotService.AddLabel(board, cfg.Text, cfg.TextColor, Enum.NormalId.Back, "SignBack")

	-- Жёлтая рамка: чуть больший щит позади основного
	local frame = ensurePart(slot, "Frame", {
		Size = cfg.BoardSize + Vector3.new(cfg.FrameDepth * 2, cfg.FrameDepth * 2, -0.6),
		Color = cfg.FrameColor,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	frame.CFrame = board.CFrame

	-- Столбы до пола
	local postHeight = cfg.BoardHeight - cfg.BoardSize.Y * 0.5
	for index, side in ipairs({ -1, 1 }) do
		local post = ensurePart(slot, "Post_" .. index, {
			Size = Vector3.new(cfg.PostWidth, postHeight, cfg.PostWidth),
			Color = cfg.PostColor,
			Material = cfg.PostMaterial,
			Reflectance = 0.05,
			CanCollide = true,
			CanTouch = false,
			CanQuery = false,
		})
		post.CFrame = CFrame.new(centerX + side * cfg.PostSpacing * 0.5, groundY + postHeight * 0.5, cfg.Z)
	end
	return slot
end

-- ═══════════════════════════════════════════════════════════════
-- ЗЕМЛЯ — одна большая серая лего-плита под всеми плотами
--
-- Рельеф даёт не сетка деталей, а старая поверхность
-- TopSurface = Enum.SurfaceType.Studs: движок рисует классические
-- лего-шипы прямо на грани детали. Ноль лишних Part'ов, и выглядит
-- ровно как пол в ретро-плейсах.
-- ═══════════════════════════════════════════════════════════════
function PlotService.EnsureGround(): BasePart?
	local cfg = Config.Ground
	if not cfg.Enabled then
		return nil
	end

	-- Габарит считаем от границ карты, чтобы плита всегда была шире забора
	local plotSize = Config.Plot.Size
	local bounds = Config.WorldBounds
	local totalWidth = (Config.Plot.Count - 1) * Config.Plot.Spacing
	local halfX = totalWidth * 0.5 + plotSize.X * 0.5 + bounds.Padding + cfg.Overhang
	local backZ = Config.Plot.Origin.Z + plotSize.Z * 0.5 + bounds.Padding + cfg.Overhang
	local frontZ = Config.Plot.Origin.Z - plotSize.Z * 0.5 - bounds.ExtraFront - cfg.Overhang

	local ground = workspace:FindFirstChild(cfg.Name)
	if not ground or not ground:IsA("BasePart") then
		if ground then ground:Destroy() end
		ground = Instance.new("Part")
		ground.Name = cfg.Name
		ground.Parent = workspace
	end

	ground.Anchored = true
	ground.Locked = true
	ground.Size = Vector3.new(halfX * 2, cfg.Thickness, backZ - frontZ)
	ground.CFrame = CFrame.new(
		Config.Plot.Origin.X,
		bounds.GroundY - cfg.Thickness * 0.5,   -- верх плиты ровно на уровне земли
		(backZ + frontZ) * 0.5)
	ground.Color = cfg.Color
	ground.Material = cfg.Material
	ground.Reflectance = cfg.Reflectance
	ground.TopSurface = cfg.Surface
	ground.BottomSurface = Enum.SurfaceType.Smooth

	-- Тёмная сетка-текстура поверх шипов только рябит
	if not cfg.KeepGridTexture then
		for _, child in ipairs(ground:GetChildren()) do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
	return ground
end

-- ═══════════════════════════════════════════════════════════════
-- СТЕНА ЦЕХА — один прямой прогон со всеми деталями
--
-- Панель + цоколь + разметочная полоса + карниз + колонны внутрь +
-- ленточное остекление + техническая труба. Строится тем же способом,
-- что и забор: cfFor(position, dir) переводит точку в мировые координаты.
-- inward — направление «внутрь цеха», туда смотрят колонны и труба.
-- ═══════════════════════════════════════════════════════════════
local function buildWallRun(parent: Instance, runName: string, cfg, cfFor, fromPoint: Vector3, toPoint: Vector3, inward: Vector3): Model?
	local delta = toPoint - fromPoint
	local length = delta.Magnitude
	if length < 1 then
		return nil
	end
	local direction = delta.Unit
	local center = fromPoint + delta * 0.5

	local model = parent:FindFirstChild("Slot_Wall_" .. runName)
	if not model or not model:IsA("Model") then
		if model then model:Destroy() end
		model = Instance.new("Model")
		model.Name = "Slot_Wall_" .. runName
		model.Parent = parent
	end

	-- Полосы вдоль всего прогона: имя, размер, цвет, материал, высота центра
	local function band(name: string, size: Vector3, color: Color3, material: Enum.Material, y: number, transparency: number?)
		local part = ensurePart(model, name, {
			Size = size,
			Color = color,
			Material = material,
			Transparency = transparency or 0,
			Reflectance = 0,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		part.CFrame = cfFor(center + Vector3.new(0, y, 0), direction)
		return part
	end

	-- Основная панель — она же Placeholder, весь прогон меняется
	-- на модель из Toolbox одной операцией
	local panel = band("Placeholder", Vector3.new(cfg.Thickness, cfg.Height, length),
		cfg.PanelColor, cfg.PanelMaterial, cfg.Height * 0.5)
	model.PrimaryPart = panel

	band("Plinth", Vector3.new(cfg.Thickness + 1.2, cfg.PlinthHeight, length),
		cfg.PlinthColor, Enum.Material.Concrete, cfg.PlinthHeight * 0.5)
	band("Stripe", Vector3.new(cfg.Thickness + 1.6, cfg.StripeHeight, length),
		cfg.StripeColor, Enum.Material.SmoothPlastic, cfg.PlinthHeight + cfg.StripeHeight * 0.5)
	band("Cap", Vector3.new(cfg.Thickness + 2.4, cfg.CapHeight, length),
		cfg.CapColor, Enum.Material.Metal, cfg.Height - cfg.CapHeight * 0.5)

	-- Колонны через равные промежутки, выступают внутрь цеха
	local spans = math.max(1, math.floor(length / cfg.PillarEvery + 0.5))
	for i = 0, spans do
		local point = fromPoint + delta * (i / spans) + inward * (cfg.PillarDepth * 0.5)
		local pillar = ensurePart(model, "Pillar_" .. i, {
			Size = Vector3.new(cfg.PillarDepth, cfg.Height * 1.02, cfg.PillarWidth),
			Color = cfg.PillarColor,
			Material = cfg.PillarMaterial,
			Reflectance = 0.05,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		pillar.CFrame = cfFor(point + Vector3.new(0, cfg.Height * 0.51, 0), direction)
	end

	-- Ленточное остекление в пролётах между колоннами
	if cfg.WindowEnabled then
		local spanLength = length / spans
		local glassLength = spanLength - cfg.PillarWidth - cfg.WindowInset * 2
		if glassLength > 2 then
			for i = 0, spans - 1 do
				local point = fromPoint + delta * ((i + 0.5) / spans)
				local glass = ensurePart(model, "Window_" .. i, {
					Size = Vector3.new(cfg.Thickness + 0.6, cfg.WindowHeight, glassLength),
					Color = cfg.WindowColor,
					Material = cfg.WindowMaterial,
					Transparency = cfg.WindowTransparency,
					Reflectance = 0,
					CanCollide = false,
					CanTouch = false,
					CanQuery = false,
				})
				glass.CFrame = cfFor(point + Vector3.new(0, cfg.Height * cfg.WindowFraction, 0), direction)
			end
		end
	end

	-- Техническая труба под карнизом. У цилиндра ось — X, поэтому
	-- доворачиваем прогон на 90 градусов вокруг Y.
	if cfg.PipeEnabled then
		local pipe = ensurePart(model, "Pipe", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length, cfg.PipeRadius * 2, cfg.PipeRadius * 2),
			Color = cfg.PipeColor,
			Material = cfg.PipeMaterial,
			Reflectance = 0.05,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		pipe.CFrame = cfFor(center + inward * cfg.PipeOffset + Vector3.new(0, cfg.Height * cfg.PipeFraction, 0), direction)
			* CFrame.Angles(0, math.rad(90), 0)
	end

	model:SetAttribute("SlotSize", Vector3.new(cfg.Thickness, cfg.Height, length))
	model:SetAttribute("SlotName", model.Name)
	model:SetAttribute("FacingDirection", inward)
	return model
end

-- ═══════════════════════════════════════════════════════════════
-- ГРАНИЦЫ КАРТЫ = стены цеха
-- Видимые стены по периметру плюс невидимая стена на всю высоту,
-- чтобы игрок не улетел за карту.
-- ═══════════════════════════════════════════════════════════════
function PlotService.EnsureWorldBounds(): Folder?
	local cfg = Config.WorldBounds
	local folder = ensureFolder(workspace, "WorldBounds")
	if not cfg.Enabled then
		folder:ClearAllChildren()
		return folder
	end

	local plotSize = Config.Plot.Size
	local totalWidth = (Config.Plot.Count - 1) * Config.Plot.Spacing
	local halfX = totalWidth * 0.5 + plotSize.X * 0.5 + cfg.Padding
	local backZ = Config.Plot.Origin.Z + plotSize.Z * 0.5 + cfg.Padding
	local frontZ = Config.Plot.Origin.Z - plotSize.Z * 0.5 - cfg.ExtraFront
	local centerX = Config.Plot.Origin.X
	local minX, maxX = centerX - halfX, centerX + halfX
	local groundY = cfg.GroundY
	local wall = cfg.Wall

	local signature = ("%s|%s|%s|%s|%s|%s"):format(minX, maxX, frontZ, backZ, wall.Height, cfg.BarrierHeight)
	if folder:GetAttribute("Signature") == signature then
		return folder
	end
	folder:ClearAllChildren()
	folder:SetAttribute("Signature", signature)

	-- Координаты уже мировые, переводить нечего
	local function worldCF(position: Vector3, dir: Vector3?): CFrame
		if dir and dir.Magnitude > 0.01 then
			return CFrame.lookAt(position, position + dir.Unit)
		end
		return CFrame.new(position)
	end

	local walls = ensureFolder(folder, "Walls")
	local corner = wall.PillarWidth
	local inset = wall.Thickness * 0.5

	buildWallRun(walls, "West", wall, worldCF,
		Vector3.new(minX + inset, groundY, frontZ + inset), Vector3.new(minX + inset, groundY, backZ - inset),
		Vector3.new(1, 0, 0))
	buildWallRun(walls, "East", wall, worldCF,
		Vector3.new(maxX - inset, groundY, frontZ + inset), Vector3.new(maxX - inset, groundY, backZ - inset),
		Vector3.new(-1, 0, 0))
	buildWallRun(walls, "North", wall, worldCF,
		Vector3.new(minX + inset + corner, groundY, backZ - inset), Vector3.new(maxX - inset - corner, groundY, backZ - inset),
		Vector3.new(0, 0, -1))
	buildWallRun(walls, "South", wall, worldCF,
		Vector3.new(minX + inset + corner, groundY, frontZ + inset), Vector3.new(maxX - inset - corner, groundY, frontZ + inset),
		Vector3.new(0, 0, 1))

	-- Вывеска цеха на дальней стене. Отдельная деталь без поворота:
	-- её грань Front смотрит вдоль -Z, то есть внутрь зала. Вешать
	-- надпись на саму панель нельзя — та развёрнута вдоль прогона
	-- и надпись уходила бы наружу.
	if wall.SignText then
		local sign = ensurePart(walls, "FactorySign", {
			Size = Vector3.new((maxX - minX) * 0.3, wall.Height * 0.3, 1),
			Color = wall.CapColor,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		sign.CFrame = CFrame.new(centerX, groundY + wall.Height * 0.44, backZ - wall.Thickness - 1)
		PlotService.AddLabel(sign, wall.SignText, wall.SignColor, Enum.NormalId.Front)
	end

	-- Невидимая стена: именно она не выпускает игрока
	local barriers = ensureFolder(folder, "Barriers")
	local barrierY = groundY + cfg.BarrierHeight * 0.5
	local depth = backZ - frontZ
	local width = maxX - minX

	local function barrier(name: string, position: Vector3, size: Vector3)
		local part = ensurePart(barriers, name, {
			Size = size,
			Transparency = 1,
			CanCollide = true,
			CanTouch = false,
			CanQuery = false,
		})
		part.CFrame = CFrame.new(position)
	end

	barrier("Barrier_West", Vector3.new(minX, barrierY, (frontZ + backZ) * 0.5), Vector3.new(cfg.BarrierThickness, cfg.BarrierHeight, depth))
	barrier("Barrier_East", Vector3.new(maxX, barrierY, (frontZ + backZ) * 0.5), Vector3.new(cfg.BarrierThickness, cfg.BarrierHeight, depth))
	barrier("Barrier_North", Vector3.new(centerX, barrierY, backZ), Vector3.new(width + cfg.BarrierThickness, cfg.BarrierHeight, cfg.BarrierThickness))
	barrier("Barrier_South", Vector3.new(centerX, barrierY, frontZ), Vector3.new(width + cfg.BarrierThickness, cfg.BarrierHeight, cfg.BarrierThickness))
	return folder
end
-- ═══════════════════════════════════════════════════════════════
-- КОНВЕЙЕР: скорость через AssemblyLinearVelocity
-- ═══════════════════════════════════════════════════════════════
function PlotService.RefreshConveyor(plot: Model)
	local conveyorFolder = plot:FindFirstChild("Conveyor")
	if not conveyorFolder then
		return
	end
	for _, slot in ipairs(conveyorFolder:GetChildren()) do
		if slot:IsA("Model") and CollectionService:HasTag(slot, Config.Tags.Conveyor) then
			local primary = slot.PrimaryPart
			if primary then
				-- Направление берём из ориентации детали, а не из хардкода,
				-- скорость домножаем на купленные ускорители ленты
				local scale = plot:GetAttribute("ConveyorScale") or 1
				local velocity = primary.CFrame.LookVector * (Config.Conveyor.Speed * scale)
				for _, part in ipairs(slot:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.AssemblyLinearVelocity = velocity
					end
				end
			end
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ЖИЗНЕННЫЙ ЦИКЛ ПЛОТОВ
-- ═══════════════════════════════════════════════════════════════
function PlotService.RegisterSetup(fn)
	table.insert(setupHooks, fn)
end

function PlotService.RegisterCleanup(fn)
	table.insert(cleanupHooks, fn)
end

-- Касание зелёной площадки: игрок сам выбрал, какой плот занять
local claimLock = {}
local function bindClaimPad(trigger: BasePart)
	if trigger:GetAttribute("Bound") then
		return
	end
	trigger:SetAttribute("Bound", true)

	trigger.Touched:Connect(function(hit)
		if trigger.CanTouch == false then
			return
		end
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- Debounce: Touched на площадке срабатывает пачками
		local now = os.clock()
		if claimLock[player] and now - claimLock[player] < Config.Plot.Claim.Cooldown then
			return
		end
		claimLock[player] = now

		local plot = PlotService.GetPlotFrom(trigger)
		if plot then
			PlotService.ClaimPlot(player, plot)
		end
	end)
end

function PlotService.Init()
	PlotService.EnsureStationPrefabs()

	local template = ServerStorage:FindFirstChild("PlotTemplate")
	if not template then
		template = Instance.new("Model")
		template.Name = "PlotTemplate"
		template.Parent = ServerStorage
	end
	PlotService.EnsureLayout(template)

	PlotService.EnsureGround()
	PlotService.EnsureWorldBounds()
	PlotService.EnsureFactorySign()

	plotsFolder = ensureFolder(workspace, "Plots")
	plotsFolder:ClearAllChildren()

	local totalWidth = (Config.Plot.Count - 1) * Config.Plot.Spacing
	for i = 1, Config.Plot.Count do
		local plot = template:Clone()
		plot.Name = "Plot_" .. i
		plot:SetAttribute("Index", i)
		plot:SetAttribute("OwnerUserId", 0)
		plot.Parent = plotsFolder

		local x = Config.Plot.Origin.X - totalWidth * 0.5 + (i - 1) * Config.Plot.Spacing
		plot:PivotTo(CFrame.new(x, Config.Plot.Origin.Y, Config.Plot.Origin.Z))

		-- После переноса пересчитываем всё, что зависит от мировых координат
		PlotService.EnsureLayout(plot)
		PlotService.RefreshConveyor(plot)
	end

	-- Площадки «занять плот» ищем по тегу, как и все остальные триггеры
	for _, trigger in ipairs(CollectionService:GetTagged(Config.Tags.Trigger)) do
		if trigger:GetAttribute("Kind") == "Claim" then
			bindClaimPad(trigger)
		end
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Trigger):Connect(function(trigger)
		if trigger:GetAttribute("Kind") == "Claim" then
			bindClaimPad(trigger)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		claimLock[player] = nil
	end)

	-- Если человек подменил модель конвейера из Toolbox — просто пере-применяем скорость
	CollectionService:GetInstanceAddedSignal(Config.Tags.Conveyor):Connect(function(slot)
		task.defer(function()
			local plot = PlotService.GetPlotFrom(slot)
			if plot then
				PlotService.RefreshConveyor(plot)
			end
		end)
	end)
end

function PlotService.GetFreePlot(): Model?
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == 0 then
			return plot
		end
	end
	return nil
end

-- Занять КОНКРЕТНЫЙ плот. Через неё проходят оба режима: и ручной
-- выбор с площадки, и автовыдача при входе.
function PlotService.ClaimPlot(player: Player, plot: Model): boolean
	if ownedByPlayer[player] then
		return false          -- у игрока уже есть плот
	end
	if not plot or plot.Parent ~= plotsFolder then
		return false
	end
	if plot:GetAttribute("OwnerUserId") ~= 0 then
		return false          -- плот уже занят
	end

	plot:SetAttribute("OwnerUserId", player.UserId)
	ownedByPlayer[player] = plot
	PlotService.SetSign(plot, player.DisplayName)
	PlotService.RefreshClaimPad(plot)

	for _, hook in ipairs(setupHooks) do
		local ok, err = pcall(hook, player, plot)
		if not ok then warn("[PlotService] setup hook: " .. tostring(err)) end
	end

	PlotService.PlotClaimed:Fire(player, plot)
	return true
end

-- Автовыдача: берём первый свободный (Config.Plot.ClaimMode = "Auto")
function PlotService.AssignPlot(player: Player): Model?
	if ownedByPlayer[player] then
		return ownedByPlayer[player]
	end
	local plot = PlotService.GetFreePlot()
	if not plot then
		warn(("[PlotService] нет свободных плотов для %s"):format(player.Name))
		return nil
	end
	return PlotService.ClaimPlot(player, plot) and plot or nil
end


function PlotService.ReleasePlot(player: Player)
	local plot = ownedByPlayer[player]
	if not plot then
		return
	end
	ownedByPlayer[player] = nil

	for _, hook in ipairs(cleanupHooks) do
		local ok, err = pcall(hook, player, plot)
		if not ok then warn("[PlotService] cleanup hook: " .. tostring(err)) end
	end

	-- Полная очистка: снимаем купленные станции и обнуляем владельца
	local slots = plot:FindFirstChild("Slots")
	if slots then slots:ClearAllChildren() end
	local products = plot:FindFirstChild("Products")
	if products then products:ClearAllChildren() end

	for _, trigger in ipairs(plot.Triggers:GetChildren()) do
		if trigger:GetAttribute("Kind") == "Station" then
			trigger:SetAttribute("Enabled", false)
		end
	end

	plot:SetAttribute("OwnerUserId", 0)
	PlotService.SetSign(plot, Config.Text.PlotVacant)
	PlotService.RefreshClaimPad(plot)
end

function PlotService.SetSign(plot: Model, text: string)
	local sign = plot.Visuals:FindFirstChild("OwnerSign")
	if sign then
		local gui = sign:FindFirstChild("SlotLabel")
		if gui and gui:FindFirstChild("Text") then
			gui.Text.Text = text
		end
	end
end

function PlotService.GetPlot(player: Player): Model?
	return ownedByPlayer[player]
end

function PlotService.GetOwner(plot: Model): Player?
	local userId = plot:GetAttribute("OwnerUserId")
	if not userId or userId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

-- Подняться от любой детали до её плота
function PlotService.GetPlotFrom(instance: Instance): Model?
	local current = instance
	while current and current.Parent ~= plotsFolder do
		current = current.Parent
		if current == nil or current == workspace then
			return nil
		end
	end
	return current :: Model?
end

function PlotService.GetAllPlots(): { Model }
	return plotsFolder:GetChildren()
end

-- Ставит модель станции из ServerStorage/Stations в слот плота
function PlotService.PlaceStation(plot: Model, def): Model?
	if def.PlaceModel == false then
		return nil   -- у этой станции нет модели: только кнопка и эффект
	end
	local prefabs = ServerStorage:FindFirstChild("Stations")
	local prefab = prefabs and prefabs:FindFirstChild("Slot_" .. def.Id)
	if not prefab then
		warn(("[PlotService] нет префаба Slot_%s в ServerStorage/Stations"):format(def.Id))
		return nil
	end

	local slots = plot:FindFirstChild("Slots")
	local existing = slots:FindFirstChild("Slot_" .. def.Id)
	if existing then
		return existing
	end

	local model = prefab:Clone()
	model.Parent = slots

	local anchor = plot.Triggers:FindFirstChild("Anchor_" .. def.Id)
	if anchor then
		model:PivotTo(anchor.CFrame)
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false   -- станция не мешает игроку ходить
		end
	end
	CollectionService:AddTag(model, Config.Tags.Station)
	model:SetAttribute("StationId", def.Id)
	return model
end

return PlotService
