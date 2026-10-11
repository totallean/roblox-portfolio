local Config = {}

Config.Palette = {
	Butter     = Color3.fromRGB(255, 214, 64),
	ButterDeep = Color3.fromRGB(255, 156, 20),
	ToxicPink  = Color3.fromRGB(255, 45, 160),
	CyberCyan  = Color3.fromRGB(120, 255, 240),
	AcidGreen  = Color3.fromRGB(70, 255, 130),
	HotRed     = Color3.fromRGB(255, 60, 80),
	Grape      = Color3.fromRGB(120, 50, 220),
	ButterBlue = Color3.fromRGB(24, 82, 214),
	SteelDark  = Color3.fromRGB(48, 54, 72),
	SteelLight = Color3.fromRGB(72, 80, 104),
	Concrete   = Color3.fromRGB(58, 60, 74),
	HazardYell = Color3.fromRGB(255, 196, 0),
	HazardDark = Color3.fromRGB(26, 26, 30),
	Void       = Color3.fromRGB(16, 10, 30),
	White      = Color3.fromRGB(255, 255, 255),
	Black      = Color3.fromRGB(0, 0, 0),
}

Config.RobuxIcon = "rbxassetid://84729279213852"

Config.Style = {
	Font          = Enum.Font.LuckiestGuy,
	StrokeColor   = Color3.fromRGB(0, 0, 0),

	StrokeThickness = 0,

	WorldStroke   = 0.8,

	FrameStroke   = 3,

	StampStroke   = 0.9,

	TextColor     = Color3.fromRGB(255, 255, 255),
}

Config.Debug = { Verbose = true }

Config.Currency = {
	Name  = "Butter",

	Icon  = "🧈",
	Short = "B",
}

Config.Plot = {
	Count       = 6,
	Size        = Vector3.new(64, 2, 128),
	Spacing     = 84,
	Origin      = Vector3.new(0, 1, 0),
	BaseColor   = Color3.fromRGB(34, 36, 46),
	BaseMaterial= Enum.Material.SmoothPlastic,
	SignOffset  = Vector3.new(0, 12, -60),

	Claim = {
		Offset      = Vector3.new(16, 0, -60),
		Size        = Vector3.new(11, 0.7, 11),
		TriggerSize = Vector3.new(11, 9, 11),
		Color       = Color3.fromRGB(70, 255, 130),
		Material    = Enum.Material.Neon,
		Label       = "CLAIM PLOT",
		Cooldown    = 1,
		HiddenDrop  = 24,
	},
}

Config.Floor = {
	Enabled       = true,

	TilesEnabled  = false,

	TileSize      = 8,
	Gap           = 0.8,
	Thickness     = 0.3,
	ColorA        = Color3.fromRGB(126, 138, 168),
	ColorB        = Color3.fromRGB(78, 88, 116),
	Material      = Enum.Material.DiamondPlate,
	Reflectance   = 0.05,

	StudEnabled   = true,
	StudInset     = 2.2,
	StudHeight    = 0.35,
	StudLighten   = 26,
	StudMaterial  = Enum.Material.SmoothPlastic,

	HazardEnabled = true,
	LaneHalfWidth = 8,
	HazardCenter  = 6.25,
	HazardWidth   = 3.5,
	HazardSegment = 8,
}

Config.Ground = {
	Enabled     = true,
	Name        = "Baseplate",
	Color       = Color3.fromRGB(146, 148, 154),
	Material    = Enum.Material.Plastic,
	Reflectance = 0,
	Thickness   = 16,
	Overhang    = 90,
	Surface     = Enum.SurfaceType.Studs,
	KeepGridTexture = false,
}

Config.Fence = {
	Enabled      = true,
	Height       = 6,

	PostEvery    = 8,
	PostWidth    = 1.4,
	PostColor    = Color3.fromRGB(52, 58, 76),
	PostMaterial = Enum.Material.Metal,

	RailHeights   = { 0.32, 0.68, 0.98 },
	RailThickness = 0.5,
	RailColor     = Color3.fromRGB(120, 255, 240),
	RailMaterial  = Enum.Material.Neon,

	MeshThickness    = 0.35,
	MeshColor        = Color3.fromRGB(96, 108, 138),
	MeshMaterial     = Enum.Material.Metal,
	MeshTransparency = 0.72,

	GapWidth     = 18,
	GapCenterX   = 16,

	BarrierExtra     = 10,
	BarrierThickness = 1.2,
}

Config.Decor = {
	{
		Id = "CreamTank_1", Label = "CREAM TANK",
		Offset = Vector3.new(-24, 7, -42), Size = Vector3.new(14, 10, 10),
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

		Legs = { Inset = 4 },
		Color = Color3.fromRGB(255, 156, 20), Material = Enum.Material.Metal,
		CanCollide = false,
	},
	{
		Id = "Pipe_Over_2", Label = "",
		Offset = Vector3.new(0, 17, 12), Size = Vector3.new(56, 2.2, 2.2),
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 0),

		Legs = { Inset = 4 },
		Color = Color3.fromRGB(120, 255, 240), Material = Enum.Material.Metal,
		CanCollide = false,
	},
	{

		Id = "Barrel", Label = "",
		Offset = Vector3.new(24, 3.5, 46), Size = Vector3.new(7, 5.5, 5.5),
		Shape = Enum.PartType.Cylinder, Rotation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(150, 96, 48), Material = Enum.Material.WoodPlanks,
		CanCollide = true,

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

Config.WorldBounds = {
	Enabled          = true,
	Padding          = 44,
	ExtraFront       = 60,
	BarrierHeight    = 120,
	BarrierThickness = 4,
	GroundY          = 0,

	Wall = {
		Height        = 50,
		Thickness     = 3,
		PanelColor    = Color3.fromRGB(104, 112, 136),
		PanelMaterial = Enum.Material.Metal,

		PlinthHeight  = 7,
		PlinthColor   = Color3.fromRGB(48, 54, 72),
		StripeHeight  = 1.5,
		StripeColor   = Color3.fromRGB(255, 196, 0),

		CapHeight     = 3,
		CapColor      = Color3.fromRGB(40, 44, 58),

		PillarEvery    = 26,
		PillarWidth    = 4,
		PillarDepth    = 5,
		PillarColor    = Color3.fromRGB(56, 62, 82),
		PillarMaterial = Enum.Material.Metal,

		WindowEnabled      = true,
		WindowHeight       = 12,
		WindowFraction     = 0.62,
		WindowInset        = 3,
		WindowColor        = Color3.fromRGB(150, 235, 255),
		WindowMaterial     = Enum.Material.Neon,
		WindowTransparency = 0.45,

		PipeEnabled  = true,
		PipeRadius   = 2.4,
		PipeFraction = 0.86,
		PipeOffset   = 4,
		PipeColor    = Color3.fromRGB(255, 156, 20),
		PipeMaterial = Enum.Material.Metal,

		SignText  = nil,
	},
}

Config.FactorySign = {
	Enabled     = true,
	Text        = "BUTTER SQUISH FACTORY",
	Z           = -78,
	BoardSize   = Vector3.new(78, 11, 2),
	BoardHeight = 22,
	BoardColor  = Color3.fromRGB(28, 32, 44),
	BoardMaterial = Enum.Material.SmoothPlastic,
	FrameColor  = Color3.fromRGB(255, 196, 0),
	FrameDepth  = 1.6,
	PostWidth   = 3.5,
	PostSpacing = 56,
	PostColor   = Color3.fromRGB(52, 58, 76),
	PostMaterial = Enum.Material.Metal,
	TextColor   = Color3.fromRGB(255, 214, 64),
}

Config.Conveyor = {
	Speed        = 16,
	SegmentCount = 12,
	SegmentSize  = Vector3.new(9, 1, 10),
	StartZ       = -52,
	Color        = Color3.fromRGB(28, 18, 48),
	Material     = Enum.Material.SmoothPlastic,
	RailHeight   = 2.5,
}

Config.Product = {
	BaseSize     = Vector3.new(2, 1, 3),
	MaxActive    = 30,
	PoolSize     = 120,
	PoolHardCap  = 400,
	Lifetime     = 45,
	SquishTime   = 0.12,
	DropHeight   = 5,
}

Config.Station = {
	TriggerSize   = Vector3.new(11, 9, 3),
	TouchCooldown = 0.25,
	SlotY         = 4,
}

Config.Buttons = {
	PadSize        = Vector3.new(6, 0.6, 6),
	TriggerSize    = Vector3.new(6, 6, 6),
	TouchCooldown  = 0.6,
	BounceStuds    = 1.5,
	BounceTime     = 0.35,
	HiddenY        = -6,
}

Config.Stations = {
	{
		Id            = "Extruder",
		Label         = "BUTTER EXTRUDER",
		Sfx           = "Extruder",
		Type          = "Producer",
		Price         = 0,
		DropInterval  = 2.0,
		BaseValue     = 15,
		ProductSize   = Vector3.new(2, 1, 3),
		ProductColor  = Config.Palette.Butter,
		ProductMaterial = Enum.Material.SmoothPlastic,
		Offset        = Vector3.new(-11, 4, -54),
		ButtonOffset  = Vector3.new(11, 0, -54),
		SlotSize      = Vector3.new(10, 10, 10),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.ButterDeep,
	},
	{
		Id            = "Stamp",
		Label         = "STAMP PRESS",
		Sfx           = "Stamp",
		Type          = "Processor",
		RequiredStage = 0,
		Requires      = "Extruder",
		Price         = 100,
		Multiplier    = 2,

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
		Sfx           = "Wax",
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

		Id            = "Belt_1",
		Label         = "BELT BOOST 1",
		Type          = "Speed",
		Requires      = "Wax_1",
		Price         = 1000,
		PlaceModel    = false,
		DropIntervalMultiplier  = 0.7,
		ConveyorSpeedMultiplier = 1.35,
		ButtonOffset  = Vector3.new(11, 0, -22),
		Offset        = Vector3.new(-11, 4, -22),
		SlotSize      = Vector3.new(10, 10, 8),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.AcidGreen,
	},
	{
		Id            = "Wax_2",
		Label         = "WAX COAT 2",
		Sfx           = "Wax",
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

		Id            = "Belt_2",
		Label         = "BELT BOOST 2",
		Type          = "Speed",
		Requires      = "Wax_2",
		Price         = 10000,
		PlaceModel    = false,
		DropIntervalMultiplier  = 0.7,
		ConveyorSpeedMultiplier = 1.35,
		ButtonOffset  = Vector3.new(11, 0, -6),
		Offset        = Vector3.new(-11, 4, -6),
		SlotSize      = Vector3.new(10, 10, 8),
		FacingDirection = Vector3.new(1, 0, 0),
		SlotColor     = Config.Palette.AcidGreen,
	},
	{
		Id            = "Wax_3",
		Label         = "WAX COAT 3",
		Sfx           = "Wax",
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
		Sfx           = "Wax",
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
		Sfx           = "Wax",
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

Config.Rebirth = {
	BaseCost          = 60000,
	Growth            = 3,
	BonusPerRebirth   = 0.5,
	Max               = 25,
	Cooldown          = 3,
	ButtonOffset      = Vector3.new(11, 0, 58),
	Label             = "🔁 REBIRTH 🔁",
	Color             = Config.Palette.Grape,
}

function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.Growth ^ math.max(0, rebirths)))
end

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

		{ Id = "GotVip",    Name = "VIP",       Desc = "Own the VIP AURA pass", Pass = "VipAura", Hidden = true, Premium = true, ExcludeFromCollection = true, Reward = { Cash = 250000 } },
		{ Id = "Supporter", Name = "SUPPORTER", Desc = "Own any game pass",     AnyPass = true,   Hidden = true, Premium = true, ExcludeFromCollection = true, Reward = { Cash = 50000 } },

		{ Id = "Collection", Name = "FULL COLLECTION", Desc = "Unlock every free reward",  Collection = true,     Reward = { Multiplier = 0.5 } },
	},

	SweepInterval = 5,
}

Config.Monetization = {
	GamePasses = {
		DoubleButter = {
			Id = 1948228545,
			Name = "x2 BUTTER VALUE",
			Desc = "Permanent",
			Price = 99,
			Icon = "rbxassetid://102226574302074",
			StoreDesc = "Every butter stick your line produces sells for twice as much. Works forever, stacks with rebirth bonuses.",
			Multiplier = 2,
		},
		StarterPack = {
			Id = 1951090392,
			Name = "STARTER PACK",
			Desc = "Best deal for a new factory",
			Icon = "rbxassetid://117082672632962",

			Price    = 149,
			OldPrice = 447,
			StoreDesc = "The best way to start: x2 butter value forever, 5 000 butter right away, and auto-collect so nothing is ever wasted. Three perks for less than the price of one.",
			Featured = true,

			Multiplier        = 2,
			GrantCash         = 5000,
			GrantsAutoCollect = true,

			Perks = {
				{ Icon = "rbxassetid://102226574302074", Label = "x2 VALUE" },
				{ Icon = "rbxassetid://93035481294343",  Label = "5 000 BUTTER" },
				{ Icon = "rbxassetid://132187391277861", Label = "AUTO-COLLECT" },
			},
		},
		AutoCollect = {
			Id = 1951521060,
			Name = "AUTO-COLLECT",
			Desc = "No lost sticks",
			Price = 149,
			Icon = "rbxassetid://132187391277861",
			StoreDesc = "Butter sticks that get stuck on the line sell themselves instead of being thrown away. Nothing is ever lost again.",
		},

		VipAura = {
			Id = 1947712491,
			Name = "VIP AURA",
			Desc = "Glow + aura + bonus",
			Price = 499,
			Icon = "rbxassetid://108087274957555",
			StoreDesc = "Stand out on the factory floor: a golden glow around your character, a trail of sparkles that follows you everywhere, and a permanent +25% to all butter income.",

			Multiplier = 1.25,

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
			Id = 3709035375,
			Tier = "entry",
			Name = "x2 INCOME FOR 10 MIN",
			Desc = "10 minutes",
			Icon = "rbxassetid://130081545560707",
			Price = 25,
			StoreDesc = "Doubles all butter income for 10 minutes. Buy it again at any time to extend the timer.",
			Boost = { Multiplier = 2, Duration = 600 },
		},
		InstantCash = {
			Id = 3709035458,
			Tier = "core",
			Name = "BUTTER BUNDLE",
			Desc = "Instant payout",
			Icon = "rbxassetid://93035481294343",
			Price = 99,
			StoreDesc = "An instant bag of butter scaled to your current income: six minutes of production paid out at once, never less than 2 500.",
			Cash = { MinAmount = 2500, IncomeMinutes = 6 },
		},
		SkipRebirth = {
			Id = 3709035512,
			Tier = "premium",
			Name = "SKIP REBIRTH",
			Desc = "No grinding",
			Icon = "rbxassetid://83496441208213",
			Price = 399,
			StoreDesc = "Rebirth instantly without saving up the threshold. Keeps the permanent income multiplier and unlocks the next rebirth-locked stations.",
			SkipRebirth = true,
		},
	},

	Ladder = { "Boost2x10", "InstantCash", "SkipRebirth" },

	StarterOffer = {
		Enabled     = true,
		Kind        = "pass",
		Key         = "StarterPack",
		DelayOnJoin = 4,
		Duration    = 600,
		Title       = "STARTER PACK",
		Perks = {
			"x2 butter value",
			"5 000 butter instantly",
			"Best value for a fresh start",
		},
	},
}

Config.FTUE = {

	Steps = {
		[1] = { Text = "Claim your factory!",            Target = "Claim",        Dim = true },
		[2] = { Text = "Wait for the butter to reach the sell zone…", Target = "Collector", Dim = false },
		[3] = { Text = "Buy your first station!",        Target = "NextButton",   Dim = true },
		[4] = { Text = "Check REWARDS for bonuses",      Target = "Achievements", Dim = true },
	},
	Done = 5,

	Cursor = {
		Glyph      = "\u{1F447}",
		Color      = Color3.fromRGB(255, 214, 64),
		Size       = 120,
		Bob        = 14,
		Speed      = 4,
		RingPad    = 14,
		RingColor  = Color3.fromRGB(255, 214, 64),
	},

	Overlay = {
		Color        = Color3.fromRGB(0, 0, 0),
		Transparency = 0.5,
		FadeTime     = 0.25,
	},

	Banner = {
		PositionScale = 0.24,
		Height        = 78,
		Color         = Color3.fromRGB(255, 255, 255),
	},

	GoalArrow = {
		Enabled   = false,
		Clearance = 11,
		Bob       = 0.8,
		Speed     = 2.2,
		Color     = Color3.fromRGB(70, 255, 130),
	},
}

Config.Sound = {
	Enabled      = true,
	MasterVolume = 0.6,
	Voices       = 3,

	Effects = {

		Click       = { Id = "rbxassetid://88442833509532",  Volume = 0.5,  MinInterval = 0.04 },

		Sell        = { Id = "rbxassetid://131886985",       Volume = 0.45, MinInterval = 0.13, Pitch = { 0.93, 1.09 } },

		Purchase    = { Id = "rbxassetid://128062463831151", Volume = 0.65, MinInterval = 0.25 },
		Achievement = { Id = "rbxassetid://86070307558627",  Volume = 0.75, MinInterval = 0.25 },
		Rebirth     = { Id = "rbxassetid://140231021022259", Volume = 0.85, MinInterval = 0.5 },

		Denied      = { Id = "rbxassetid://100489811839284", Volume = 0.4,  MinInterval = 0.4 },

		Notify      = { Id = "rbxassetid://129485210015224", Volume = 0.35, MinInterval = 0.35 },
		Offer       = { Id = "rbxassetid://90681320250848",  Volume = 0.6,  MinInterval = 0.5 },
	},

	Stations = {
		Extruder = { Id = "rbxassetid://9119054571", Volume = 0.6, MaxDistance = 55, MinDistance = 8, MinInterval = 0.12, Pitch = { 0.92, 1.08 } },
		Stamp    = { Id = "rbxassetid://9116768449", Volume = 0.4, MaxDistance = 55, MinDistance = 8, MinInterval = 0.12, Pitch = { 0.90, 1.06 } },
		Wax      = { Id = "rbxassetid://9119526981", Volume = 0.5, MaxDistance = 50, MinDistance = 8, MinInterval = 0.12, Pitch = { 0.95, 1.12 } },
	},
}

Config.Music = {
	Enabled = true,
	Volume  = 0.18,
	Shuffle = true,
	Gap     = 3,

	Tracks = {
		{ Id = "rbxassetid://96948132613384",  Name = "Starry Night" },
		{ Id = "rbxassetid://125866603219817", Name = "Save Room" },
		{ Id = "rbxassetid://79573084280497",  Name = "Chakra Balancing 432Hz" },
		{ Id = "rbxassetid://99678007903413",  Name = "Somewhere Beyond" },
		{ Id = "rbxassetid://140386536872153", Name = "The Fledgelings Take Wing" },
	},
}

Config.Text = {

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

	IncomeShort     = "Income x%.2f",
	IncomeFull      = "Income x%.2f · %s/min",
	GoalLoading     = "Loading goal…",
	GoalNeedPlot    = "Claim a free plot to begin",
	GoalRemaining   = "%s — %s to go",
	GoalAffordable  = "%s — you can buy it!",
	GoalAllBought   = "All bought! Rebirth in %s %s",

	Purchased       = "PURCHASED!\n%s",
	GainPopup       = "+%s %s",
	RewardCash      = "Reward: %s",
	RewardBonus     = "Bonus: +%d%% income",
	CollectionBonus = "Collection bonus: +%d%% income",
	CollectionHint  = "Collect them all for an income bonus",

	GoalArrow       = "GOAL",
	StepCounter     = "Step %d/%d",

	NotOwnPlot      = "That's not your plot",
	NeedMore        = "Need %s more",
	FreePrice       = "FREE",
	PlotVacant      = "VACANT",
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

	NetBusy         = "Slow down!",
	NetError        = "Something went wrong",
	NetNoProfile    = "Data is still loading",

	BuyButton       = "BUY",
	BuyUnknown      = "Unknown station",
	BuyLocked       = "Not available yet",
	BuyOwned        = "Already owned",
	BuyNoPlot       = "Claim a plot first",

	ConfirmTitle    = "REBIRTH?",
	ConfirmBody     = "You lose every station and all butter.\nYou keep <b>+%d%%</b> income — forever.",
	ConfirmYes      = "DO IT",
	ConfirmNo       = "NOT YET",

	InventoryButton = "FACTORY",
	InventoryTitle  = "MY FACTORY",
	InvLine         = "LINE %d/%d",
	InvPasses       = "PERKS",
	InvStats        = "STATS",
	InvLoading      = "Asking the server…",
	StatEarned      = "Total earned",
	StatSold        = "Sticks sold",
	StatRebirths    = "Rebirths",
	StatIncome      = "Income / min",
	StatPlaytime    = "Playtime",
	StatBoost       = "Boost left",
	StatMultiplier  = "Income multiplier",
	PassOwned       = "OWNED",
	PassLocked      = "LOCKED",

	LeaderButton    = "TOP",
	LeaderTitle     = "TOP FACTORIES",
	LeaderEmpty     = "Nobody here yet",
	LeaderYou       = "you",

	FeedJoined      = "%s joined the factory",
	FeedLeft        = "%s left",
	FeedRebirth     = "%s hit REBIRTH #%d",
	FeedStation     = "%s unlocked %s",
	FeedRich        = "%s earned %s butter in total",
}

Config.Data = {
	StoreName        = "ButterSquish_Player_v1",
	KeyPrefix        = "P_",
	AutosaveInterval = 60,
	SessionLockTTL   = 900,
	LockWaitTimeout  = 12,
	MaxRetries       = 5,
	RetryBaseDelay   = 0.5,
	BindToCloseWait  = 25,
}

function Config.DefaultProfile(): { [string]: any }
	return {
		Version     = 1,
		Currency    = 0,
		Stations    = {},
		Rebirths    = 0,
		TotalEarned = 0,
		SoldCount   = 0,
		Tutorial    = 0,
		Achievements = {},
		BonusMultiplier = 0,
		HasClaimed  = false,
		Receipts    = {},
		PassGrants  = {},
		Playtime    = 0,
	}
end

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

Config.RemoteNames = {
	"CurrencyChanged",
	"StateSync",
	"Notify",
	"ProductSold",
	"StationPurchased",
	"FTUEStep",
	"StarterOffer",
	"AchievementSync",
	"AchievementUnlock",
	"Broadcast",
	"RequestState",
	"RequestRebirth",
	"RequestPurchase",
	"RequestAchievements",
}

Config.RemoteFunctionNames = {
	"GetInventory",
	"BuyStation",
	"GetLeaderboard",
}

Config.ClientFunctionNames = {
	"ConfirmAction",
}

Config.RemoteCooldown = 0.5

Config.Net = {
	Default = { Burst = 5, PerSecond = 2 },

	Limits = {
		RequestState        = { Burst = 4,  PerSecond = 1 },
		RequestRebirth      = { Burst = 2,  PerSecond = 0.5 },
		RequestPurchase     = { Burst = 3,  PerSecond = 1 },
		RequestAchievements = { Burst = 4,  PerSecond = 1 },

		GetInventory        = { Burst = 5,  PerSecond = 1.5 },
		BuyStation          = { Burst = 4,  PerSecond = 2 },
		GetLeaderboard      = { Burst = 3,  PerSecond = 1 },
	},

	InvokeTimeout = 20,
	StrikeLimit   = 25,
	StrikeDecay   = 10,
	MuteSeconds   = 5,
	LogRejects    = true,
}

Config.Feed = {
	Enabled     = true,
	MaxLines    = 4,
	Lifetime    = 7,
	MinStationPrice = 1000,
}

Config.Leaderboard = {
	StatName     = "Butter",
	RebirthStat  = "Rebirths",
	MaxRows      = 10,
	Refresh      = 5,
}

local byId = {}
for index, def in ipairs(Config.Stations) do
	def.Index = index
	byId[def.Id] = def
end

function Config.GetStation(id: string)
	return byId[id]
end

function Config.GetNext(id: string)
	for _, def in ipairs(Config.Stations) do
		if def.Requires == id then
			return def
		end
	end
	return nil
end

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
