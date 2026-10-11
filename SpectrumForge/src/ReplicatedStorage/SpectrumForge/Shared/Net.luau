--!strict

local Net = {}

Net.FOLDER = "Remotes"
Net.ACTION = "Action"
Net.SYNC = "Sync"
Net.NOTIFY = "Notify"

Net.MAX_STRING_LENGTH = 64

export type ActionSpec = { rate: number, args: { string } }

local Actions: { [string]: ActionSpec } = {
	Ready = { rate = 2, args = {} },

	TutorialStep = { rate = 5, args = { "number" } },

	SetLanguage = { rate = 3, args = { "string" } },

	Tap = { rate = 12, args = {} },
	BuyRing = { rate = 20, args = { "number" } },

	SetBuildSlot = { rate = 10, args = { "string", "string?" } },
	SelectBuild = { rate = 5, args = { "number" } },
	UpgradePart = { rate = 20, args = { "string" } },

	OpenCrate = { rate = 5, args = { "number" } },

	Rebirth = { rate = 1, args = {} },

	ChallengeGhost = { rate = 2, args = {} },
	ClaimGhostWins = { rate = 2, args = {} },

	Debug = { rate = 20, args = { "string", "number" } },
}

Net.Actions = Actions

Net.Notices = {
	OfflineEarnings = "OfflineEarnings",
	CrateResult = "CrateResult",
	BattleResult = "BattleResult",
	BattleShow = "BattleShow",
	Leaderboard = "Leaderboard",
	RebirthResult = "RebirthResult",
	GhostWins = "GhostWins",
	PurchaseResult = "PurchaseResult",
	Error = "Error",
}

function Net.waitForRemotes(): Folder
	local rs = game:GetService("ReplicatedStorage")
	return rs:WaitForChild(Net.FOLDER) :: Folder
end

return Net
