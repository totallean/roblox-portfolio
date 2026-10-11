--!strict

local Types = {}

Types.SCHEMA_VERSION = 1

export type Slot = "core" | "emitter" | "frame" | "focus" | "sigil"

export type PartInstance = {
	defId: string,
	tier: number,
	level: number,
}

export type Build = {
	name: string,
	core: string?,
	emitter: string?,
	frame: string?,
	focus: string?,
	sigil: string?,
}

export type CombatSnapshot = {
	dps: number,
	hp: number,
	armor: number,
	pierce: number,
	colorTier: number,
	power: number,
}

export type Profile = {
	schemaVersion: number,

	will: number,
	shards: number,

	ringLevel: number,
	rebirths: number,
	totalCharge: number,
	unlockedColors: { number },

	parts: { [string]: PartInstance },
	builds: { Build },
	activeBuild: number,
	pityCounter: number,

	arenaRank: number,
	arenaWins: number,
	arenaLosses: number,
	ghostWinsPending: number,

	language: string?,

	tutorialStep: number,

	lastSeen: number,
	firstJoin: number,
	totalWillEarned: number,
	purchaseHistory: { [string]: boolean },
}

return Types
