local Config = {
	MaxWebDistance = 260,
	MinWebDistance = 8,
	WebTravelSpeed = 1400,

	InitialRopeFactor = 0.94,
	MinRopeLength = 10,
	ReelSpeed = 38,
	RopeCorrection = 12,
	PumpAcceleration = 70,
	AttachAssistSpeed = 55,
	SwingAirDrag = 0.05,
	MaxSpeed = 230,
	SwingGravityScale = 0.6,
	AirGravityScale = 0.7,
	GroundClearance = 7,
	MinSwingAnchorHeight = 10,
	WallOffset = 8,
	SwingAhead = { 60, 42, 80, 30 },
	SwingHeight = { 55, 65, 45, 38 },
	SwingSideReach = 90,

	ReleaseBoostForward = 10,
	ReleaseBoostUp = 16,
	JumpOffBoostForward = 22,
	JumpOffBoostUp = 48,

	ZipSpeed = 170,
	ZipMaxTime = 1.1,
	ZipArriveDistance = 8,
	ZipExitForward = 34,
	ZipExitUp = 58,

	AirControlAcceleration = 45,
	AirControlMaxSpeed = 40,
	AirDrag = 0.02,
	LandProbeLength = 3.4,

	AssistPitches = { 48, 62, 35, 75, 85 },
	AssistYaws = { 0, 20, -20, 40, -40 },

	BaseFov = 70,
	MaxFov = 98,
	FovSpeedStart = 40,
	FovSpeedFull = 190,
	WindSpeedThreshold = 70,

	RemoteRateLimit = 12,
	RemoteRangeSlack = 40,

	RaceTimeout = 240,
	RaceLeaderboardSize = 10,
	RaceLeaderboardRefresh = 60,
}

return table.freeze(Config)
