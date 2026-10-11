local Players = game:GetService("Players")

local STRINGS = {
	en = {
		controlsTitle = "WEB SWING",
		controlsSwing = "LMB / R2 (hold) — swing",
		controlsZip = "Q / L2 — web zip",
		controlsReel = "Shift / L1 (hold) — reel in",
		controlsJump = "Space — jump off the web",
		speed = "%d st/s",
		raceHint = "Fly through the first ring to start the race",
		raceRing = "Ring %d / %d",
		raceFinished = "Finished in %s",
		raceNewBest = "New personal best!",
		raceBest = "Best: %s",
		leaderboardTitle = "TOP SWINGERS",
		leaderboardEmpty = "No times yet",
		swingButton = "Web",
		zipButton = "Zip",
		reelButton = "Reel",
	},
	ru = {
		controlsTitle = "ПОЛЁТ НА ПАУТИНЕ",
		controlsSwing = "ЛКМ / R2 (держи) — паутина",
		controlsZip = "Q / L2 — рывок к точке",
		controlsReel = "Shift / L1 (держи) — подтянуться",
		controlsJump = "Пробел — прыжок с паутины",
		speed = "%d ст/с",
		raceHint = "Пролети через первое кольцо, чтобы начать гонку",
		raceRing = "Кольцо %d / %d",
		raceFinished = "Финиш за %s",
		raceNewBest = "Новый личный рекорд!",
		raceBest = "Рекорд: %s",
		leaderboardTitle = "ЛУЧШИЕ ПОЛЁТЫ",
		leaderboardEmpty = "Пока нет результатов",
		swingButton = "Сеть",
		zipButton = "Рывок",
		reelButton = "Тяга",
	},
}

local Locale = {}

function Locale.languageFor(player: Player?): string
	local localeId = if player then player.LocaleId else "en-us"
	if string.sub(string.lower(localeId), 1, 2) == "ru" then
		return "ru"
	end
	return "en"
end

function Locale.get(key: string, language: string?): string
	local lang = language or Locale.languageFor(Players.LocalPlayer)
	local value = STRINGS[lang][key] or STRINGS.en[key]
	return value or key
end

function Locale.formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, rest)
end

return Locale
