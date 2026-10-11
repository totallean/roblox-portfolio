--[[
	Config.lua — ЕДИНСТВЕННЫЙ источник настроек контента.
	Принцип: логика не знает про конкретные станции, она читает эту таблицу.
	Чтобы добавить новый слой воска — допиши ОДНУ запись в Config.Stations.
	Путь: ReplicatedStorage/Shared/Config (ModuleScript)
]]

local Config = {}

-- ═══════════════════════════════════════════════════════════════
-- ПАЛИТРА (retro-slop / AI-slop). Меняется одним местом.
-- ═══════════════════════════════════════════════════════════════
Config.Palette = {
	Butter     = Color3.fromRGB(255, 214, 64),   -- ядовито-жёлтый «масляный»
	ButterDeep = Color3.fromRGB(255, 156, 20),
	ToxicPink  = Color3.fromRGB(255, 45, 160),   -- токсично-розовый
	CyberCyan  = Color3.fromRGB(120, 255, 240),  -- кибер-циан
	AcidGreen  = Color3.fromRGB(70, 255, 130),   -- «можно купить»
	HotRed     = Color3.fromRGB(255, 60, 80),    -- «не хватает денег»
	Grape      = Color3.fromRGB(120, 50, 220),
	ButterBlue = Color3.fromRGB(24, 82, 214),    -- синяя надпись BUTTER, как на реальном бруске
	SteelDark  = Color3.fromRGB(48, 54, 72),     -- фабричный пол, тёмная плитка
	SteelLight = Color3.fromRGB(72, 80, 104),    -- фабричный пол, светлая плитка
	Concrete   = Color3.fromRGB(58, 60, 74),
	HazardYell = Color3.fromRGB(255, 196, 0),    -- жёлто-чёрная разметка
	HazardDark = Color3.fromRGB(26, 26, 30),
	Void       = Color3.fromRGB(16, 10, 30),
	White      = Color3.fromRGB(255, 255, 255),
	Black      = Color3.fromRGB(0, 0, 0),
}

-- Общий стиль SurfaceGui/BillboardGui-подписей
-- Иконка робуксов для ценников магазина
Config.RobuxIcon = "rbxassetid://84729279213852"

Config.Style = {
	Font          = Enum.Font.LuckiestGuy,   -- жирный гротеск-плейсхолдер
	StrokeColor   = Color3.fromRGB(0, 0, 0),

	-- Обводка ТЕКСТА В ИНТЕРФЕЙСЕ выключена: у жирного гротеска она
	-- съедала внутренние просветы букв, особенно в магазине
	StrokeThickness = 0,

	-- Надписи В МИРЕ (ценники, таблички) висят на фоне сцены,
	-- им тонкий контур всё-таки нужен
	WorldStroke   = 0.8,

	-- Обводка РАМОК (Frame/Button) — это акцент, её оставляем
	FrameStroke   = 3,

	-- Обводка штампа на бруске масла
	StampStroke   = 0.9,

	TextColor     = Color3.fromRGB(255, 255, 255),
}

Config.Debug = { Verbose = true }

-- ═══════════════════════════════════════════════════════════════
-- ВАЛЮТА
-- ═══════════════════════════════════════════════════════════════
Config.Currency = {
	Name  = "Butter",
	-- Иконка ставится ТОЛЬКО в счётчике баланса и на кнопке ребёрна.
	-- Во всех остальных надписях (ценники, цели, уведомления) её нет:
	-- со смайликами жирный гротеск читается заметно хуже.
	Icon  = "🧈",
	Short = "B",
}

-- ═══════════════════════════════════════════════════════════════
-- ПЛОТЫ
-- Плот строится клонированием ServerStorage.PlotTemplate.
-- Все офсеты станций считаются от ВЕРХНЕЙ ПЛОСКОСТИ базы плота (локально).
-- ═══════════════════════════════════════════════════════════════
Config.Plot = {
	Count       = 6,                          -- сколько плотов создать на сервере
	Size        = Vector3.new(64, 2, 128),
	Spacing     = 84,                         -- расстояние между плотами по X
	Origin      = Vector3.new(0, 1, 0),       -- база лежит прямо на серой плите-земле
	BaseColor   = Color3.fromRGB(34, 36, 46),
	BaseMaterial= Enum.Material.SmoothPlastic,
	SignOffset  = Vector3.new(0, 12, -60),    -- табличка «свободно / ник игрока»

	-- Как игрок получает плот:
	--   "Manual" — сам выбирает: встаёт на зелёную площадку у входа
	--   "Auto"   — свободный плот выдаётся сразу при входе
	-- Требование курса «плот сразу при входе» закрывается переключением
	-- этой одной строки на "Auto", логика на обе ветки уже написана.
	ClaimMode = "Manual",

	-- Площадка «занять плот»: стоит в проёме забора, чтобы игрок
	-- наступил на неё, просто зайдя внутрь
	Claim = {
		Offset      = Vector3.new(16, 0, -60),
		Size        = Vector3.new(11, 0.7, 11),
		TriggerSize = Vector3.new(11, 9, 11),
		Color       = Color3.fromRGB(70, 255, 130),
		Material    = Enum.Material.Neon,
		Label       = "CLAIM PLOT",
		Cooldown    = 1,
		HiddenDrop  = 24,   -- насколько уводим площадку вниз, когда плот занят
	},
}

-- ═══════════════════════════════════════════════════════════════
-- ПОЛ ЦЕХА
-- Тот же приём, что в «садовых» тайкунах: сетка плиток с зазором даёт
-- «выдавленный» рисунок без единой текстуры. Здесь — стальная шахматка
-- плюс жёлто-чёрная разметка вдоль конвейерной линии.
-- ═══════════════════════════════════════════════════════════════
Config.Floor = {
	Enabled       = true,

	-- Плитка с лего-шипами уехала на общую плиту-землю (Config.Ground):
	-- на плотах она забивала линию и мешала читать конвейер.
	-- Ставь true, если захочешь вернуть её на плоты.
	TilesEnabled  = false,

	TileSize      = 8,      -- сторона плитки
	Gap           = 0.8,    -- зазор между плитками — он и рисует сетку
	Thickness     = 0.3,
	ColorA        = Color3.fromRGB(126, 138, 168),   -- светлая плитка
	ColorB        = Color3.fromRGB(78, 88, 116),     -- тёмная плитка
	Material      = Enum.Material.DiamondPlate,
	Reflectance   = 0.05,

	StudEnabled   = true,
	StudInset     = 2.2,    -- насколько шип меньше плитки (по каждой стороне)
	StudHeight    = 0.35,   -- высота выступа
	StudLighten   = 26,     -- на сколько шип светлее своей плитки (0..255)
	StudMaterial  = Enum.Material.SmoothPlastic,

	-- Жёлто-чёрная разметка вдоль линии остаётся всегда: она размечает
	-- конвейер, а не украшает пол
	HazardEnabled = true,
	LaneHalfWidth = 8,      -- коридор линии: сюда плитку не кладём
	HazardCenter  = 6.25,   -- ось жёлто-чёрной разметки по краям коридора
	HazardWidth   = 3.5,
	HazardSegment = 8,      -- длина одного жёлтого/чёрного куска
}

-- ═══════════════════════════════════════════════════════════════
-- ЗЕМЛЯ — большая серая лего-плита, на которой стоят все плоты
--
-- Ретро-слоп делает такой пол не сеткой из деталей, а ОДНОЙ деталью
-- со старой поверхностью TopSurface = Studs: движок сам рисует
-- классические лего-шипы. Стоит это ноль лишних деталей и выглядит
-- ровно как на бейсплейте из старых плейсов.
-- ═══════════════════════════════════════════════════════════════
Config.Ground = {
	Enabled     = true,
	Name        = "Baseplate",
	Color       = Color3.fromRGB(146, 148, 154),   -- классический серый
	Material    = Enum.Material.Plastic,
	Reflectance = 0,
	Thickness   = 16,
	Overhang    = 90,        -- насколько плита шире забора завода
	Surface     = Enum.SurfaceType.Studs,
	KeepGridTexture = false, -- тёмная сетка поверх шипов только рябит
}

-- ═══════════════════════════════════════════════════════════════
-- ОГРАЖДЕНИЕ ПЛОТА
-- Визуал — энергетические панели (Slot_Fence_*), их можно заменить
-- моделью из Toolbox. Столкновение держит отдельный невидимый
-- Barrier_*, поэтому замена визуала не уронит игрока с плота.
-- ═══════════════════════════════════════════════════════════════
Config.Fence = {
	Enabled      = true,
	Height       = 6,     -- по пояс: ограждает, но не закрывает обзор на линию

	-- Столбы
	PostEvery    = 8,
	PostWidth    = 1.4,
	PostColor    = Color3.fromRGB(52, 58, 76),
	PostMaterial = Enum.Material.Metal,

	-- Поручни (доли от высоты)
	RailHeights   = { 0.32, 0.68, 0.98 },
	RailThickness = 0.5,
	RailColor     = Color3.fromRGB(120, 255, 240),
	RailMaterial  = Enum.Material.Neon,

	-- Сетчатая панель между столбами: сквозь неё видно цех
	MeshThickness    = 0.35,
	MeshColor        = Color3.fromRGB(96, 108, 138),
	MeshMaterial     = Enum.Material.Metal,
	MeshTransparency = 0.72,

	-- Проём для входа
	GapWidth     = 18,
	GapCenterX   = 16,   -- проём смещён вбок, чтобы вход не был на самой ленте

	-- Невидимый коллайдер: он и держит игрока, а не декоративные столбы
	BarrierExtra     = 10,
	BarrierThickness = 1.2,
}

-- ═══════════════════════════════════════════════════════════════
-- ФАБРИЧНЫЙ ДЕКОР
-- Тоже слоты: Model + Placeholder + PrimaryPart, меняются на Toolbox.
-- Логика их не трогает вообще — это чистая обстановка цеха.
-- ═══════════════════════════════════════════════════════════════
Config.Decor = {
	{
		Id = "CreamTank_1", Label = "CREAM TANK",
		Offset = Vector3.new(-24, 7, -42), Size = Vector3.new(14, 10, 10),  -- ось цилиндра = X
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(196, 204, 220), Material = Enum.Material.Metal,
		CanCollide = true,
	},
	{
		Id = "CreamTank_2", Label = "CREAM TANK",
		Offset = Vector3.new(-24, 7, -22), Size = Vector3.new(14, 10, 10),
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(255, 214, 64), Material = Enum.Material.Metal,
		CanCollide = true,
	},
	{
		Id = "Pipe_Over_1", Label = "",
		Offset = Vector3.new(0, 17, -36), Size = Vector3.new(56, 2.2, 2.2),
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 0),
		-- Спуски до пола. Форму, диаметр, цвет и материал берут у самой
		-- трубы, поэтому вниз уходит такая же труба, а не колонна.
		Legs = { Inset = 4 },
		Color = Color3.fromRGB(255, 156, 20), Material = Enum.Material.Metal,
		CanCollide = false,
	},
	{
		Id = "Pipe_Over_2", Label = "",
		Offset = Vector3.new(0, 17, 12), Size = Vector3.new(56, 2.2, 2.2),
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 0),
		-- Спуски до пола. Форму, диаметр, цвет и материал берут у самой
		-- трубы, поэтому вниз уходит такая же труба, а не колонна.
		Legs = { Inset = 4 },
		Color = Color3.fromRGB(120, 255, 240), Material = Enum.Material.Metal,
		CanCollide = false,
	},
	{
		-- Бочка вместо бывшего «пульта»: тот выглядел как интерактивный
		-- объект, хотя функционала за ним не было
		Id = "Barrel", Label = "",
		Offset = Vector3.new(24, 3.5, 46), Size = Vector3.new(7, 5.5, 5.5),
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(150, 96, 48), Material = Enum.Material.WoodPlanks,
		CanCollide = true,
		-- Обручи: два тёмных кольца чуть шире корпуса
		Bands = { Heights = { 0.28, 0.72 }, Thickness = 0.7, Overhang = 0.5,
			Color = Color3.fromRGB(58, 64, 84) },
	},
	{
		Id = "ExhaustFan", Label = "EXHAUST",
		Offset = Vector3.new(-25, 10, 34), Size = Vector3.new(2, 12, 12),
		Color = Color3.fromRGB(90, 96, 112), Material = Enum.Material.Metal,
		CanCollide = true,
	},
}

-- ═══════════════════════════════════════════════════════════════
-- ГРАНИЦЫ КАРТЫ — чтобы игрок физически не мог улететь за пределы
-- ═══════════════════════════════════════════════════════════════
Config.WorldBounds = {
	Enabled          = true,
	Padding          = 44,    -- запас от крайних плотов
	ExtraFront       = 60,    -- со стороны спавна карта шире
	BarrierHeight    = 120,   -- невидимая стена: перелететь нельзя
	BarrierThickness = 4,
	GroundY          = 0,     -- уровень земли, от него растут стены

	-- Стены цеха по периметру. Не забор, а полноценная стена с деталями:
	-- цоколь, разметочная полоса, колонны, ленточное остекление,
	-- карниз и техническая труба под потолком.
	Wall = {
		Height        = 50,
		Thickness     = 3,
		PanelColor    = Color3.fromRGB(104, 112, 136),
		PanelMaterial = Enum.Material.Metal,

		-- Цоколь + жёлтая разметочная полоса над ним
		PlinthHeight  = 7,
		PlinthColor   = Color3.fromRGB(48, 54, 72),
		StripeHeight  = 1.5,
		StripeColor   = Color3.fromRGB(255, 196, 0),

		-- Карниз сверху
		CapHeight     = 3,
		CapColor      = Color3.fromRGB(40, 44, 58),

		-- Колонны внутрь цеха
		PillarEvery    = 26,
		PillarWidth    = 4,
		PillarDepth    = 5,
		PillarColor    = Color3.fromRGB(56, 62, 82),
		PillarMaterial = Enum.Material.Metal,

		-- Ленточное остекление между колоннами
		WindowEnabled      = true,
		WindowHeight       = 12,
		WindowFraction     = 0.62,   -- доля высоты стены
		WindowInset        = 3,      -- отступ от колонн
		WindowColor        = Color3.fromRGB(150, 235, 255),
		WindowMaterial     = Enum.Material.Neon,
		WindowTransparency = 0.45,

		-- Техническая труба вдоль стены
		PipeEnabled  = true,
		PipeRadius   = 2.4,
		PipeFraction = 0.86,
		PipeOffset   = 4,        -- насколько отнесена от стены внутрь
		PipeColor    = Color3.fromRGB(255, 156, 20),
		PipeMaterial = Enum.Material.Metal,

		-- Вывеска переехала на отдельный щит по центру цеха
		-- (Config.FactorySign): на стене её перекрывали колонны
		SignText  = nil,
	},
}

-- ═══════════════════════════════════════════════════════════════
-- ЩИТ С НАЗВАНИЕМ ЗАВОДА
-- Отдельная конструкция на столбах в проходе перед плотами.
-- На стене надпись перекрывали колонны, здесь её ничто не закрывает,
-- и читается она с обеих сторон.
-- ═══════════════════════════════════════════════════════════════
Config.FactorySign = {
	Enabled     = true,
	Text        = "BUTTER SQUISH FACTORY",
	Z           = -78,                          -- проход между спавном и плотами
	BoardSize   = Vector3.new(78, 11, 2),
	BoardHeight = 22,                           -- высота центра щита
	BoardColor  = Color3.fromRGB(28, 32, 44),
	BoardMaterial = Enum.Material.SmoothPlastic,
	FrameColor  = Color3.fromRGB(255, 196, 0),  -- жёлтая рамка по краю щита
	FrameDepth  = 1.6,
	PostWidth   = 3.5,
	PostSpacing = 56,                           -- расстояние между столбами
	PostColor   = Color3.fromRGB(52, 58, 76),
	PostMaterial = Enum.Material.Metal,
	TextColor   = Color3.fromRGB(255, 214, 64),
}

-- ═══════════════════════════════════════════════════════════════
-- КОНВЕЙЕР
-- Лента = N сегментов вдоль локальной оси +Z. Скорость задаётся
-- через AssemblyLinearVelocity, направление берётся из ориентации детали.
-- ═══════════════════════════════════════════════════════════════
Config.Conveyor = {
	Speed        = 16,
	SegmentCount = 12,
	SegmentSize  = Vector3.new(9, 1, 10),
	StartZ       = -52,                       -- центр первого сегмента
	Color        = Color3.fromRGB(28, 18, 48),
	Material     = Enum.Material.SmoothPlastic,
	RailHeight   = 2.5,                       -- невидимые бортики, чтобы брусок не падал
}

-- ═══════════════════════════════════════════════════════════════
-- ПРОДУКТ (брусок масла)
-- ═══════════════════════════════════════════════════════════════
Config.Product = {
	BaseSize     = Vector3.new(2, 1, 3),
	MaxActive    = 30,      -- жёсткий лимит активных продуктов на плот
	PoolSize     = 120,     -- предсоздаваемый пул на весь сервер
	PoolHardCap  = 400,     -- предохранитель: больше этого не создаём никогда
	Lifetime     = 45,      -- сек, после которых «застрявший» брусок утилизируется
	SquishTime   = 0.12,    -- длительность твина «сдавливания» на станции
	DropHeight   = 5,       -- на сколько studs выше ленты появляется брусок
}

-- ═══════════════════════════════════════════════════════════════
-- СТАНЦИИ / ТРИГГЕРЫ / КНОПКИ
-- ═══════════════════════════════════════════════════════════════
Config.Station = {
	TriggerSize   = Vector3.new(11, 9, 3),   -- невидимый Part поперёк ленты
	TouchCooldown = 0.25,                    -- анти-дюп на Touched
	SlotY         = 4,                       -- высота центра слота модели
}

Config.Buttons = {
	PadSize        = Vector3.new(6, 0.6, 6),
	TriggerSize    = Vector3.new(6, 6, 6),
	TouchCooldown  = 0.6,                    -- анти-дюп на покупке
	BounceStuds    = 1.5,                    -- подпрыгивание при появлении
	BounceTime     = 0.35,
	HiddenY        = -6,                     -- куда прячется невидимая кнопка
}

-- ═══════════════════════════════════════════════════════════════
-- ЛИНИЯ ПРОИЗВОДСТВА (главная декларация)
--
--   Type = "Producer"  — единственный, кто создаёт продукт.
--   Type = "Processor" — ловит проезжающий брусок и апгрейдит его.
--   Type = "Collector" — принимает брусок и начисляет валюту.
--
--   RequiredStage    — обрабатываем только продукт с таким Stage.
--                      Не совпало — брусок проезжает мимо без изменений.
--   Requires         — Id предыдущей станции в цепочке появления кнопок.
--   RequiredRebirths — кнопка появится только после N ребёрнов.
--
--   Кривая цен экспоненциальная (~x4), но первые 3–4 покупки
--   укладываются примерно в 6–8 минут.
-- ═══════════════════════════════════════════════════════════════
Config.Stations = {
	{
		Id            = "Extruder",
		Label         = "BUTTER EXTRUDER",
		Type          = "Producer",
		Price         = 0,                       -- выдаётся сразу при входе
		DropInterval  = 2.0,
		BaseValue     = 15,
		ProductSize   = Vector3.new(2, 1, 3),
		ProductColor  = Config.Palette.Butter,
		ProductMaterial = Enum.Material.SmoothPlastic,
		Offset        = Vector3.new(-11, 4, -54),
		ButtonOffset  = Vector3.new(11, 0, -54),
		SlotSize      = Vector3.new(10, 10, 10),
		FacingDirection = Vector3.new(1, 0, 0),  -- «лицом» к ленте
		SlotColor     = Config.Palette.ButterDeep,
	},
	{
		Id            = "Stamp",
		Label         = "STAMP PRESS",
		Type          = "Processor",
		RequiredStage = 0,
		Requires      = "Extruder",
		Price         = 100,
		Multiplier    = 2,
		-- Синяя надпись с белой обводкой — ровно как на упаковке масла
		Decal         = { Text = "BUTTER", Color = Config.Palette.ButterBlue, StrokeColor = Config.Palette.White },
		Offset        = Vector3.new(-11, 4, -38),
		ButtonOffset  = Vector3.new(11, 0, -38),
		SlotSize      = Vector3.new(10, 12, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.ButterBlue,
	},
	{
		Id            = "Wax_1",
		Label         = "WAX COAT 1",
		Type          = "Processor",
		RequiredStage = 1,
		Requires      = "Stamp",
		Price         = 300,
		Multiplier    = 2.5,
		SizeAdd       = Vector3.new(0.25, 0.15, 0.25),
		Color         = Config.Palette.CyberCyan,
		Material      = Enum.Material.Glass,
		Offset        = Vector3.new(-11, 4, -22),
		ButtonOffset  = Vector3.new(11, 0, -22),
		SlotSize      = Vector3.new(10, 12, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.CyberCyan,
	},
	{
		-- Кнопка ускорения. PlaceModel = false — модель на плот НЕ ставится.
		-- ButtonOffset совпадает с предыдущей станцией: купил слой воска —
		-- на ТОЙ ЖЕ кнопке появляется ускорение. Так между машинами
		-- не остаётся пустых мест, шаг линии везде ровно 16 studs.
		Id            = "Belt_1",
		Label         = "BELT BOOST 1",
		Type          = "Speed",
		Requires      = "Wax_1",
		Price         = 1000,
		PlaceModel    = false,
		DropIntervalMultiplier  = 0.7,   -- дроппер роняет на 30% чаще
		ConveyorSpeedMultiplier = 1.35,  -- масло едет заметно быстрее
		ButtonOffset  = Vector3.new(11, 0, -22),
		Offset        = Vector3.new(-11, 4, -22),
		SlotSize      = Vector3.new(10, 10, 8),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.AcidGreen,
	},
	{
		Id            = "Wax_2",
		Label         = "WAX COAT 2",
		Type          = "Processor",
		RequiredStage = 2,
		Requires      = "Belt_1",
		Price         = 3000,
		Multiplier    = 2.5,
		SizeAdd       = Vector3.new(0.25, 0.15, 0.25),
		Color         = Config.Palette.AcidGreen,
		Material      = Enum.Material.Neon,
		Offset        = Vector3.new(-11, 4, -6),
		ButtonOffset  = Vector3.new(11, 0, -6),
		SlotSize      = Vector3.new(10, 12, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.AcidGreen,
	},
	{
		-- Кнопка ускорения. PlaceModel = false — модель на плот НЕ ставится.
		-- ButtonOffset совпадает с предыдущей станцией: купил слой воска —
		-- на ТОЙ ЖЕ кнопке появляется ускорение. Так между машинами
		-- не остаётся пустых мест, шаг линии везде ровно 16 studs.
		Id            = "Belt_2",
		Label         = "BELT BOOST 2",
		Type          = "Speed",
		Requires      = "Wax_2",
		Price         = 10000,
		PlaceModel    = false,
		DropIntervalMultiplier  = 0.7,   -- дроппер роняет на 30% чаще
		ConveyorSpeedMultiplier = 1.35,  -- масло едет заметно быстрее
		ButtonOffset  = Vector3.new(11, 0, -6),
		Offset        = Vector3.new(-11, 4, -6),
		SlotSize      = Vector3.new(10, 10, 8),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.AcidGreen,
	},
	{
		Id            = "Wax_3",
		Label         = "WAX COAT 3",
		Type          = "Processor",
		RequiredStage = 3,
		Requires      = "Belt_2",
		Price         = 30000,
		Multiplier    = 2.5,
		SizeAdd       = Vector3.new(0.3, 0.2, 0.3),
		Color         = Config.Palette.Grape,
		Material      = Enum.Material.Glass,
		Offset        = Vector3.new(-11, 4, 10),
		ButtonOffset  = Vector3.new(11, 0, 10),
		SlotSize      = Vector3.new(10, 12, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.Grape,
	},
	{
		Id            = "Wax_4",
		Label         = "WAX COAT 4",
		Type          = "Processor",
		RequiredStage = 4,
		Requires      = "Wax_3",
		RequiredRebirths = 1,
		Price         = 90000,
		Multiplier    = 3,
		SizeAdd       = Vector3.new(0.35, 0.25, 0.35),
		Color         = Config.Palette.ToxicPink,
		Material      = Enum.Material.Neon,
		Offset        = Vector3.new(-11, 4, 26),
		ButtonOffset  = Vector3.new(11, 0, 26),
		SlotSize      = Vector3.new(10, 12, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.ToxicPink,
	},
	{
		Id            = "Wax_5",
		Label         = "WAX COAT 5",
		Type          = "Processor",
		RequiredStage = 5,
		Requires      = "Wax_4",
		RequiredRebirths = 2,
		Price         = 400000,
		Multiplier    = 3,
		SizeAdd       = Vector3.new(0.4, 0.3, 0.4),
		Color         = Config.Palette.Butter,
		Material      = Enum.Material.Neon,
		Offset        = Vector3.new(-11, 4, 42),
		ButtonOffset  = Vector3.new(11, 0, 42),
		SlotSize      = Vector3.new(10, 12, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.Butter,
	},
}

-- Коллектор описывается отдельно: он всегда есть и ничего не стоит.
Config.Collector = {
	Id       = "Collector",
	Label    = "SELL",
	Offset   = Vector3.new(0, 4, 58),
	SlotSize = Vector3.new(12, 10, 8),
	Color    = Config.Palette.AcidGreen,
	Material = Enum.Material.Neon,
	FlashColor = Config.Palette.White,
	FlashTime  = 0.18,
	TouchCooldown = 0.2,
}

-- ═══════════════════════════════════════════════════════════════
-- РЕБЁРН
-- ═══════════════════════════════════════════════════════════════
Config.Rebirth = {
	BaseCost          = 60000,    -- порог первого ребёрна
	Growth            = 3,        -- cost(n) = BaseCost * Growth^n
	BonusPerRebirth   = 0.5,      -- +50% к доходу за каждый ребёрн
	Max               = 25,
	Cooldown          = 3,        -- анти-спам на Remote/Touched
	ButtonOffset      = Vector3.new(11, 0, 58),
	Label             = "🔁 REBIRTH 🔁",
	Color             = Config.Palette.Grape,
}

function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.Growth ^ math.max(0, rebirths)))
end

-- ═══════════════════════════════════════════════════════════════
-- ДОСТИЖЕНИЯ
-- Условие задаётся ОДНИМ полем, логика читает их по очереди:
--   Claimed     — занять плот
--   Station     — купить станцию с таким Id
--   Rebirths    — набрать N ребёрнов
--   TotalEarned — заработать N всего за сессии
--   Collection  — открыть все остальные достижения
-- Награда: Cash (разовая выплата) или Multiplier (перманентный бонус).
-- Добавить достижение = дописать строку сюда.
-- ═══════════════════════════════════════════════════════════════
Config.Achievements = {
	List = {
		{ Id = "OwnPlot",    Name = "OWN FACTORY",     Desc = "Claim a plot",              Claimed = true,        Reward = { Cash = 60 } },
		{ Id = "FirstSale",  Name = "FIRST STICK",     Desc = "Sell your first butter",    SoldCount = 1,         Reward = { Cash = 90 } },
		{ Id = "GotStamp",   Name = "STAMPED",         Desc = "Buy STAMP PRESS",           Station = "Stamp",     Reward = { Cash = 200 } },
		{ Id = "GotWax1",    Name = "FIRST COAT",      Desc = "Buy WAX COAT 1",            Station = "Wax_1",     Reward = { Cash = 600 } },
		{ Id = "GotBelt1",   Name = "SPEED UP",        Desc = "Buy BELT BOOST 1",          Station = "Belt_1",    Reward = { Cash = 2000 } },
		{ Id = "GotWax2",    Name = "SECOND COAT",     Desc = "Buy WAX COAT 2",            Station = "Wax_2",     Reward = { Cash = 6000 } },
		{ Id = "GotBelt2",   Name = "FULL THROTTLE",   Desc = "Buy BELT BOOST 2",          Station = "Belt_2",    Reward = { Cash = 20000 } },
		{ Id = "GotWax3",    Name = "GLOSSY",          Desc = "Buy WAX COAT 3",            Station = "Wax_3",     Reward = { Cash = 60000 } },
		{ Id = "Rebirth1",   Name = "RESTART",         Desc = "Do your first rebirth",     Rebirths = 1,          Reward = { Cash = 80000 } },
		{ Id = "Millionar",  Name = "MILLIONAIRE",     Desc = "Earn 1 000 000 in total",   TotalEarned = 1000000, Reward = { Cash = 150000 } },
		-- Достижения за покупки.
		--   Hidden   — не показываются в списке, пока не выполнены.
		--              F2P-игрок видит только бесплатные и может закрыть 100%.
		--   Premium  — открытые подсвечиваются золотом, а не зелёным.
		--   ExcludeFromCollection — не блокируют «полную коллекцию».
		{ Id = "GotVip",    Name = "VIP",       Desc = "Own the VIP AURA pass", Pass = "VipAura", Hidden = true, Premium = true, ExcludeFromCollection = true, Reward = { Cash = 250000 } },
		{ Id = "Supporter", Name = "SUPPORTER", Desc = "Own any game pass",     AnyPass = true,   Hidden = true, Premium = true, ExcludeFromCollection = true, Reward = { Cash = 50000 } },

		{ Id = "Collection", Name = "FULL COLLECTION", Desc = "Unlock every free reward",  Collection = true,     Reward = { Multiplier = 0.5 } },
	},

	-- Как часто сервер пересматривает условия по накопленным числам
	SweepInterval = 5,
}

-- ═══════════════════════════════════════════════════════════════
-- МОНЕТИЗАЦИЯ (заглушки — проставь реальные Id вместо 0)
-- Лестница из трёх уровней: entry → core → premium.
-- ═══════════════════════════════════════════════════════════════
Config.Monetization = {
	GamePasses = {
		DoubleButter = {
			Id = 1948228545,                       -- GamePassId
			Name = "x2 BUTTER VALUE",
			Desc = "Permanent",
			Price = 99,
			Icon = "rbxassetid://102226574302074",
			StoreDesc = "Every butter stick your line produces sells for twice as much. Works forever, stacks with rebirth bonuses.",
			Multiplier = 2,
		},
		StarterPack = {
			Id = 1951090392,                       -- GamePassId
			Name = "STARTER PACK",
			Desc = "Best deal for a new factory",
			Icon = "rbxassetid://117082672632962",

			Price    = 149,   -- цена в робуксах, показывается крупно
			OldPrice = 447,   -- перечёркнутая старая цена: витрина скидки
			StoreDesc = "The best way to start: x2 butter value forever, 5 000 butter right away, and auto-collect so nothing is ever wasted. Three perks for less than the price of one.",
			Featured = true,  -- рисуется большим ярким блоком наверху магазина

			-- Что даёт набор
			Multiplier        = 2,
			GrantCash         = 5000,
			GrantsAutoCollect = true,

			-- Плитки бонусов в витрине: иконка + короткая подпись
			Perks = {
				{ Icon = "rbxassetid://102226574302074", Label = "x2 VALUE" },
				{ Icon = "rbxassetid://93035481294343",  Label = "5 000 BUTTER" },
				{ Icon = "rbxassetid://132187391277861", Label = "AUTO-COLLECT" },
			},
		},
		AutoCollect = {
			Id = 1951521060,                       -- GamePassId
			Name = "AUTO-COLLECT",
			Desc = "No lost sticks",
			Price = 149,
			Icon = "rbxassetid://132187391277861",
			StoreDesc = "Butter sticks that get stuck on the line sell themselves instead of being thrown away. Nothing is ever lost again.",
		},

		-- Косметика: подсветка персонажа, аура из искр и бонус к доходу.
		-- Эффект вешается при каждом появлении персонажа, см.
		-- MonetizationService.ApplyCosmetics.
		VipAura = {
			Id = 1947712491,                       -- GamePassId
			Name = "VIP AURA",
			Desc = "Glow + aura + bonus",
			Price = 499,
			Icon = "rbxassetid://108087274957555",
			StoreDesc = "Stand out on the factory floor: a golden glow around your character, a trail of sparkles that follows you everywhere, and a permanent +25% to all butter income.",

			Multiplier = 1.25,   -- те самые «ништяки» сверху косметики

			Cosmetic = {
				Highlight = {
					FillColor        = Color3.fromRGB(255, 214, 64),
					FillTransparency = 0.72,
					OutlineColor     = Color3.fromRGB(255, 156, 20),
				},
				Aura = {
					Texture      = "rbxassetid://115860331202944",
					Rate         = 14,
					Lifetime     = 1.4,
					Speed        = 3,
					Size         = 1.6,
					Transparency = 0.35,
					Spread       = 22,
					ColorA       = Color3.fromRGB(255, 214, 64),
					ColorB       = Color3.fromRGB(255, 45, 160),
				},
			},
		},
	},

	Products = {
		Boost2x10 = {
			Id = 3709035375,                       -- DeveloperProductId
			Tier = "entry",
			Name = "x2 INCOME FOR 10 MIN",
			Desc = "10 minutes",
			Icon = "rbxassetid://130081545560707",
			Price = 25,
			StoreDesc = "Doubles all butter income for 10 minutes. Buy it again at any time to extend the timer.",
			Boost = { Multiplier = 2, Duration = 600 },
		},
		InstantCash = {
			Id = 3709035458,                       -- DeveloperProductId
			Tier = "core",
			Name = "BUTTER BUNDLE",
			Desc = "Instant payout",
			Icon = "rbxassetid://93035481294343",
			Price = 99,
			StoreDesc = "An instant bag of butter scaled to your current income: six minutes of production paid out at once, never less than 2 500.",
			Cash = { MinAmount = 2500, IncomeMinutes = 6 },  -- max(Min, доход_в_минуту * N)
		},
		SkipRebirth = {
			Id = 3709035512,                       -- DeveloperProductId
			Tier = "premium",
			Name = "SKIP REBIRTH",
			Desc = "No grinding",
			Icon = "rbxassetid://83496441208213",
			Price = 399,
			StoreDesc = "Rebirth instantly without saving up the threshold. Keeps the permanent income multiplier and unlocks the next rebirth-locked stations.",
			SkipRebirth = true,
		},
	},

	-- Порядок показа в UI-лесенке
	Ladder = { "Boost2x10", "InstantCash", "SkipRebirth" },

	-- Стартовый набор. Всплывает КАЖДЫЙ раз, когда игрок заходит в игру,
	-- но только если он ещё не куплен. Это не автоматический платёжный
	-- диалог Roblox, а обычное окно с кнопкой: диалог открывается уже
	-- по нажатию игрока.
	StarterOffer = {
		Enabled     = true,
		Kind        = "pass",        -- "pass" | "product"
		Key         = "StarterPack",
		DelayOnJoin = 4,             -- сек после входа, чтобы не бить в лицо на загрузке
		Duration    = 600,           -- сколько висит окно с таймером
		Title       = "STARTER PACK",
		Perks = {
			"x2 butter value",
			"5 000 butter instantly",
			"Best value for a fresh start",
		},
	},
}

-- ═══════════════════════════════════════════════════════════════
-- FTUE — три шага, ведущие нового игрока
-- ═══════════════════════════════════════════════════════════════
Config.FTUE = {
	-- Каждый шаг: крупный текст по центру, курсор-рука на цели и
	-- затемнение фона на «шагах действия». На шаге ожидания экран
	-- не затемняется — там просто подсказка, как в референсе.
	Steps = {
		[1] = { Text = "Claim your factory!",            Target = "Claim",        Dim = true },
		[2] = { Text = "Wait for the butter to reach the sell zone…", Target = "Collector", Dim = false },
		[3] = { Text = "Buy your first station!",        Target = "NextButton",   Dim = true },
		[4] = { Text = "Check REWARDS for bonuses",      Target = "Achievements", Dim = true },
	},
	Done = 5,   -- номер, при котором обучение считается пройденным

	-- Курсор-рука. Символ проверен: этот шрифт его рисует,
	-- в отличие от стрелок с селектором эмодзи (U+FE0F).
	Cursor = {
		Glyph      = "\u{1F447}",
		Color      = Color3.fromRGB(255, 214, 64),
		Size       = 120,
		Bob        = 14,      -- амплитуда покачивания в пикселях
		Speed      = 4,
		RingPad    = 14,      -- насколько рамка-подсветка больше цели
		RingColor  = Color3.fromRGB(255, 214, 64),
	},

	-- Затемнение фона
	Overlay = {
		Color        = Color3.fromRGB(0, 0, 0),
		Transparency = 0.5,
		FadeTime     = 0.25,
	},

	-- Крупный текст-инструкция
	Banner = {
		PositionScale = 0.24,
		Height        = 78,
		Color         = Color3.fromRGB(255, 255, 255),
	},

	-- Постоянная стрелка над текущей целью: живёт всю игру, а не
	-- только во время шагов обучения.
	-- Постоянная стрелка над очередной покупкой. Выключена: над каждой
	-- появляющейся кнопкой висел ярлык GOAL, а на самой кнопке и так
	-- написано название и цена. Включается одной строкой.
	GoalArrow = {
		Enabled   = false,
		Clearance = 11,   -- запас над верхом цели, чтобы не перекрыть ценник
		Bob       = 0.8,
		Speed     = 2.2,
		Color     = Color3.fromRGB(70, 255, 130),
	},
}

-- ═══════════════════════════════════════════════════════════════
-- ТЕКСТЫ ИНТЕРФЕЙСА
-- Все формулировки, которые раньше были разбросаны по коду, лежат
-- здесь. Сменить язык всей игры = поправить эту таблицу плюс поля
-- Label/Name/Desc выше. В самом коде строк с текстом больше нет.
-- ═══════════════════════════════════════════════════════════════
Config.Text = {
	-- Кнопки и панели
	ShopButton      = "SHOP",
	ShopTitle       = "SHOP",
	ShopBadge       = "ONE TIME OFFER!",
	ShopWas         = "was",
	ShopBuy         = "GET",
	ShopOwned       = "OWNED",
	RewardsButton   = "REWARDS",
	RewardsTitle    = "REWARDS %d/%d",
	RebirthButton   = "🔁 REBIRTH",
	RebirthButtonFull = "🔁 REBIRTH #%d\n<font size=\"14\">%s %s</font>",

	-- Верхняя плашка
	IncomeShort     = "Income x%.2f",
	IncomeFull      = "Income x%.2f · %s/min",
	GoalLoading     = "Loading goal…",
	GoalNeedPlot    = "Claim a free plot to begin",
	GoalRemaining   = "%s — %s to go",
	GoalAffordable  = "%s — you can buy it!",
	GoalAllBought   = "All bought! Rebirth in %s %s",

	-- Всплывашки
	Purchased       = "PURCHASED!\n%s",
	GainPopup       = "+%s %s",
	RewardCash      = "Reward: %s",
	RewardBonus     = "Bonus: +%d%% income",
	CollectionBonus = "Collection bonus: +%d%% income",
	CollectionHint  = "Collect them all for an income bonus",

	-- Указатели обучения
	GoalArrow       = "GOAL",
	StepCounter     = "Step %d/%d",

	-- Уведомления сервера
	NotOwnPlot      = "That's not your plot",
	NeedMore        = "Need %s more",
	FreePrice       = "FREE",
	PlotVacant      = "VACANT",
	NoFreePlots     = "No free plots",
	PickPlot        = "Pick a plot: step on the green pad",
	PlotClaimed     = "Plot claimed. Line is running",
	DataLoading     = "Data is still loading",
	RebirthMaxed    = "Max rebirths reached",
	RebirthBlocked  = "Not yet",
	RebirthDone     = "🔁 REBIRTH #%d! Income x%.1f",
	BoostActive     = "Boost x%d active!",
	PassActivated   = "%s activated",
	MissingProductId = "TODO: set ProductId in Config",
	MissingPassId   = "TODO: set GamePassId in Config",
	KickNoData      = "Couldn't load your progress. Rejoin in a minute",
}

-- ═══════════════════════════════════════════════════════════════
-- ДАННЫЕ
-- ═══════════════════════════════════════════════════════════════
Config.Data = {
	StoreName        = "ButterSquish_Player_v1",
	KeyPrefix        = "P_",
	AutosaveInterval = 60,     -- автосейв раз в 60 секунд
	SessionLockTTL   = 900,    -- через сколько чужой лок считается протухшим
	LockWaitTimeout  = 12,     -- сколько ждём чужую сессию, потом перехватываем лок
	MaxRetries       = 5,
	RetryBaseDelay   = 0.5,    -- экспоненциальная задержка: 0.5, 1, 2, 4, 8
	BindToCloseWait  = 25,
}

-- Схема профиля. Меняешь ProfileStore — меняешь только DataService,
-- структура данных остаётся ровно этой.
function Config.DefaultProfile(): { [string]: any }
	return {
		Version     = 1,
		Currency    = 0,
		Stations    = {},   -- [StationId] = true
		Rebirths    = 0,
		TotalEarned = 0,
		SoldCount   = 0,    -- сколько брусков реально продано
		Tutorial    = 0,    -- пройденный шаг FTUE
		Achievements = {},  -- [AchievementId] = true
		BonusMultiplier = 0,-- перманентный бонус за коллекцию достижений
		HasClaimed  = false,-- игрок хоть раз занимал плот
		Receipts    = {},   -- [PurchaseId] = true, защита от двойной выдачи
		PassGrants  = {},   -- [PassKey] = true, разовые выплаты за геймпассы
		Playtime    = 0,
	}
end

-- ═══════════════════════════════════════════════════════════════
-- ТЕГИ CollectionService (никакого поиска по именам в логике)
-- ═══════════════════════════════════════════════════════════════
Config.Tags = {
	Product      = "Product",
	Station      = "Station",
	Collector    = "Collector",
	BuyButton    = "BuyButton",
	Conveyor     = "Conveyor",
	StationSlot  = "StationSlot",
	Plot         = "Plot",
	Trigger      = "Trigger",
}

-- ═══════════════════════════════════════════════════════════════
-- REMOTE-СОБЫТИЯ (создаются кодом в Main.server.lua)
-- Remote используются ТОЛЬКО для UI и уведомлений.
-- ═══════════════════════════════════════════════════════════════
Config.RemoteNames = {
	"CurrencyChanged",   -- S→C: баланс
	"StateSync",         -- S→C: полное состояние (станции, ребёрны, цель)
	"Notify",            -- S→C: тост-уведомление
	"ProductSold",       -- S→C: всплывашка «+N» и вспышка
	"StationPurchased",  -- S→C: всплывашка «Куплено!»
	"FTUEStep",          -- S→C: текущий шаг обучения
	"StarterOffer",      -- S→C: показать окно стартового набора
	"AchievementSync",   -- S→C: полный список достижений и их состояние
	"AchievementUnlock", -- S→C: всплывашка «достижение открыто»
	"RequestState",      -- C→S: клиент просит пересинхронизацию
	"RequestRebirth",    -- C→S: запрос ребёрна (валидируется на сервере)
	"RequestPurchase",   -- C→S: запрос промпта GamePass/DevProduct
	"RequestAchievements", -- C→S: клиент просит список достижений
}

Config.RemoteCooldown = 0.5  -- rate-limit на каждый C→S Remote (sanity check)

-- ═══════════════════════════════════════════════════════════════
-- ХЕЛПЕРЫ
-- ═══════════════════════════════════════════════════════════════
local byId = {}
for index, def in ipairs(Config.Stations) do
	def.Index = index
	byId[def.Id] = def
end

function Config.GetStation(id: string)
	return byId[id]
end

-- Кто идёт следующим в цепочке после station Id (nil, если конец цепочки)
function Config.GetNext(id: string)
	for _, def in ipairs(Config.Stations) do
		if def.Requires == id then
			return def
		end
	end
	return nil
end

-- Первая станция, которую игрок ещё не купил и которая ему доступна
function Config.GetNextGoal(owned: { [string]: boolean }, rebirths: number)
	for _, def in ipairs(Config.Stations) do
		if not owned[def.Id] then
			local reqOk = (def.Requires == nil) or (owned[def.Requires] == true)
			local rbOk = rebirths >= (def.RequiredRebirths or 0)
			if reqOk and rbOk then
				return def
			end
		end
	end
	return nil
end

-- Короткая запись больших чисел для UI: 12.4K, 3.1M …
function Config.FormatNumber(n: number): string
	n = math.floor(n)
	local suffixes = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, pair in ipairs(suffixes) do
		if n >= pair[1] then
			return string.format("%.1f%s", n / pair[1], pair[2])
		end
	end
	return tostring(n)
end

return Config
