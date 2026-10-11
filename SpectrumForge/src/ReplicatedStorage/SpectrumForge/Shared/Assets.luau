--!strict

local RunService = game:GetService("RunService")

local Assets = {}

local UNSET = "rbxassetid://0"

local function id(n: string): string
	return "rbxassetid://" .. n
end

Assets.Currency = {
	Will = id("105300168575798"),
	Shards = id("128511762212540"),
	Charge = id("112199618835872"),
}

Assets.MenuIcons = {
	["menu.ring"] = id("111977708425543"),
	["menu.rebirth"] = id("107794977982643"),
	["menu.build"] = id("94001317361506"),
	["menu.crates"] = id("125907024425133"),
	["menu.arena"] = id("72712419474456"),
	["menu.shop"] = id("71515579128420"),
	["menu.language"] = id("94272687133453"),
}

Assets.HotbarIcons = {
	["hotbar.charge"] = id("102321175672770"),
	["hotbar.fight"] = id("134119181427014"),
	["hotbar.crate"] = id("118554800883386"),
	["hotbar.crate10"] = id("112199618835872"),
}

Assets.Misc = {
	Codex = id("89113974252559"),
	Ghost = id("78666886648909"),
	Settings = id("94272687133453"),
	Calendar = id("71479056537473"),
	Clover = id("72854331493787"),
}

Assets.Images = {}

Assets.Sounds = {
	Tap =        { id = id("88442833509532"),  volume = 0.25 },
	Purchase =   { id = id("140558490176201"), volume = 0.45 },
	CrateOpen =  { id = id("17669541061"),     volume = 0.5 },
	RareDrop =   { id = id("17669542369"),     volume = 0.75 },
	BattleStart ={ id = id("104212131439216"), volume = 0.5 },
	BattleWin =  { id = id("103516326607012"), volume = 0.6 },
	BattleLoss = { id = id("88674181164917"),  volume = 0.45 },
	Rebirth =    { id = id("115571404569228"), volume = 0.7 },
	Error =      { id = id("17669542615"),     volume = 0.35 },
}

Assets.Meshes = {}

Assets.Particles = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

function Assets.menu(caption: string): string?
	return Assets.MenuIcons[caption]
end

function Assets.hotbar(caption: string): string?
	return Assets.HotbarIcons[caption]
end

function Assets.validate(): ()
	if not RunService:IsStudio() then
		return
	end

	for key, sound in Assets.Sounds do
		if sound.id == UNSET then
			warn(("[Assets] Sounds.%s не проставлен"):format(key))
		end
	end
	for key, image in Assets.Images do
		if image == UNSET then
			warn(("[Assets] Images.%s не проставлен"):format(key))
		end
	end
end

return Assets
