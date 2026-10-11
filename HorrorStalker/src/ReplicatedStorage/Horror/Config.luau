local Config = {
	Stalker = {
		WalkSpeed = 9,
		InvestigateSpeed = 13,
		ChaseSpeed = 22,
		AttackRange = 4.5,
		AttackCooldown = 2.5,
		Damage = 100,

		EyeHeight = 2.4,
		ViewDistance = 70,
		ViewDistanceDark = 32,
		FieldOfView = 110,
		PeripheralDistance = 9,

		-- Awareness grows while the stalker sees you, faster when you are close or lit.
		AwarenessGain = 0.9,
		AwarenessDecay = 0.25,
		SuspiciousAt = 0.35,
		ChaseAt = 1,
		CrouchVisibility = 0.55,
		FlashlightVisibility = 1.8,

		HearRunning = 46,
		HearWalking = 16,
		HearCrouching = 0,

		LoseSightAfter = 3.5,
		SearchDuration = 9,
		SearchLookAround = 4,
		InvestigateWait = 2.5,

		PathRecompute = 0.35,
		DirectChaseDistance = 22,
		StuckTime = 1.8,
	},

	Player = {
		WalkSpeed = 12,
		RunSpeed = 21,
		CrouchSpeed = 6,
		StaminaMax = 100,
		StaminaDrain = 22,
		StaminaRegen = 14,
		StaminaRegenDelay = 1.2,
		CrouchHipOffset = -1.2,
	},

	Keys = {
		Required = 3,
	},

	Remote = {
		RateLimit = 20,
	},
}

return table.freeze(Config)
