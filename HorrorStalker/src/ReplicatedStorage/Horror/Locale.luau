local Players = game:GetService("Players")

local STRINGS = {
	en = {
		title = "THE STALKER",
		goal = "Find %d keys and escape. Don't let it see you.",
		keys = "Keys: %d / %d",
		exitOpen = "All keys found — the exit is open!",
		keyFound = "%s found a key",
		escaped = "%s escaped in %s",
		newRound = "New round",
		caught = "IT CAUGHT YOU",
		seen = "IT SEES YOU",
		suspicious = "Something heard you…",
		hidden = "Hidden. Press E to leave",
		safe = "Safe room: it never comes in here",
		controlsRun = "Shift — run (loud)",
		controlsCrouch = "C — crouch (quiet, harder to see)",
		controlsLight = "F — flashlight (you see more, it sees you)",
		controlsHide = "E — hide in lockers / take keys",
		controlsDebug = "G — show the AI's vision",
		hide = "Hide",
		leave = "Leave",
		takeKey = "Take key",
		exitLocked = "Locked",
		object_locker = "Locker",
		object_key = "Key",
		object_exit = "Exit door",
		play = "PLAY",
		howToPlay = "HOW TO PLAY",
		close = "CLOSE",
		restart = "RESTART",
		mainMenu = "MAIN MENU",
		tagline = "Find %d keys. Hide. Don't let it see you.",
		gameOverCaught = "YOU WERE CAUGHT",
		gameOverDied = "YOU DIED",
		survived = "Survived %s  •  Keys %d / %d",
		tipDark = "Darkness and crouching make you harder to see.",
		tipNoise = "Running is loud: it hears you through walls.",
		tipHide = "If it sees you climb into a locker, it will pull you out.",
		tipSafe = "The room you start in is safe.",
	},
	ru = {
		title = "СТАЛКЕР",
		goal = "Найди %d ключа и сбеги. Не попадайся ему на глаза.",
		keys = "Ключи: %d / %d",
		exitOpen = "Все ключи найдены — выход открыт!",
		keyFound = "%s нашёл ключ",
		escaped = "%s сбежал за %s",
		newRound = "Новый раунд",
		caught = "ОН ТЕБЯ ПОЙМАЛ",
		seen = "ОН ТЕБЯ ВИДИТ",
		suspicious = "Кажется, он что-то услышал…",
		hidden = "Ты спрятался. E — выйти",
		safe = "Безопасная комната: сюда он не заходит",
		controlsRun = "Shift — бег (громко)",
		controlsCrouch = "C — присесть (тихо, тебя хуже видно)",
		controlsLight = "F — фонарик (видно больше, но и тебя тоже)",
		controlsHide = "E — спрятаться в шкаф / взять ключ",
		controlsDebug = "G — показать зрение ИИ",
		hide = "Спрятаться",
		leave = "Выйти",
		takeKey = "Взять ключ",
		exitLocked = "Заперто",
		object_locker = "Шкаф",
		object_key = "Ключ",
		object_exit = "Выход",
		play = "ИГРАТЬ",
		howToPlay = "КАК ИГРАТЬ",
		close = "ЗАКРЫТЬ",
		restart = "ЗАНОВО",
		mainMenu = "ГЛАВНОЕ МЕНЮ",
		tagline = "Найди %d ключа. Прячься. Не попадайся ему на глаза.",
		gameOverCaught = "ОН ТЕБЯ ПОЙМАЛ",
		gameOverDied = "ТЫ ПОГИБ",
		survived = "Продержался %s  •  Ключи %d / %d",
		tipDark = "В темноте и присев тебя хуже видно.",
		tipNoise = "Бег громкий: он слышит тебя сквозь стены.",
		tipHide = "Если он видел, как ты залез в шкаф, он тебя вытащит.",
		tipSafe = "Комната, где ты появляешься, безопасна.",
	},
}

local Locale = {}

function Locale.language(): string
	local player = Players.LocalPlayer
	local id = if player then string.lower(player.LocaleId) else "en"
	return if string.sub(id, 1, 2) == "ru" then "ru" else "en"
end

function Locale.get(key: string): string
	local lang = Locale.language()
	return STRINGS[lang][key] or STRINGS.en[key] or key
end

function Locale.formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%02d", minutes, math.floor(seconds - minutes * 60))
end

return Locale
