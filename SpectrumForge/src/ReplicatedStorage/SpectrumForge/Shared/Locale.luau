--!strict

local Eco = require(script.Parent.EconomyConfig)

local Locale = {}

Locale.LANGUAGES = { "ru", "en" }
Locale.DEFAULT = "ru"

Locale.NAMES = {
	ru = "Русский",
	en = "English",
}

local SUPPORTED: { [string]: boolean } = {}
for _, lang in Locale.LANGUAGES do
	SUPPORTED[lang] = true
end

local S = {}

S["lang.title"] = { ru = "ВЫБЕРИ ЯЗЫК", en = "CHOOSE LANGUAGE" }
S["lang.hint"] = { ru = "Поменять можно в меню", en = "You can change it later in the menu" }

S["menu.title"] = { ru = "МЕНЮ", en = "MENU" }
S["menu.ring"] = { ru = "Кольцо", en = "Ring" }
S["menu.rebirth"] = { ru = "Перезарядка", en = "Recharge" }
S["menu.build"] = { ru = "Сборка", en = "Build" }
S["menu.crates"] = { ru = "Ящики", en = "Crates" }
S["menu.arena"] = { ru = "Арена", en = "Arena" }
S["menu.shop"] = { ru = "Магазин", en = "Shop" }
S["menu.language"] = { ru = "Язык", en = "Language" }

S["hotbar.charge"] = { ru = "Заряд", en = "Charge" }
S["hotbar.fight"] = { ru = "Бой", en = "Fight" }
S["hotbar.crate"] = { ru = "Ящик", en = "Crate" }
S["hotbar.crate10"] = { ru = "Ящик x10", en = "Crate x10" }

S["card.rank"] = { ru = "Носитель, уровень %d", en = "Bearer, level %d" }
S["card.spectrum"] = { ru = "%s  ·  Перезарядок: %d", en = "%s  ·  Recharges: %d" }
S["card.xp"] = { ru = "УРОВЕНЬ  %d%%", en = "LEVEL  %d%%" }
S["card.rebirth"] = { ru = "ПЕРЕЗАРЯДКА  %d / %d", en = "RECHARGE  %d / %d" }
S["card.match"] = { ru = "СПЕКТР  %d / 5", en = "SPECTRUM  %d / 5" }

S["codex.title"] = { ru = "КОНСТРУКТ", en = "CONSTRUCT" }
S["slot.core"] = { ru = "Ядро", en = "Core" }
S["slot.emitter"] = { ru = "Излучатель", en = "Emitter" }
S["slot.frame"] = { ru = "Каркас", en = "Frame" }
S["slot.focus"] = { ru = "Фокус", en = "Focus" }
S["slot.sigil"] = { ru = "Знак", en = "Sigil" }
S["slot.short.core"] = { ru = "Я", en = "C" }
S["slot.short.emitter"] = { ru = "И", en = "E" }
S["slot.short.frame"] = { ru = "К", en = "F" }
S["slot.short.focus"] = { ru = "Ф", en = "O" }
S["slot.short.sigil"] = { ru = "З", en = "S" }
S["codex.empty"] = { ru = "пусто", en = "empty" }
S["codex.unused"] = { ru = "не занят", en = "unused" }
S["codex.part"] = { ru = "%s · ур.%d", en = "%s · lv.%d" }

S["ghost.title"] = { ru = "ПРИЗРАК", en = "GHOST" }
S["ghost.rank"] = { ru = "Ранг %d", en = "Rank %d" }
S["ghost.record"] = { ru = "Побед %d  ·  Поражений %d", en = "Wins %d  ·  Losses %d" }
S["ghost.income"] = { ru = "Доход %s  ·  %s", en = "Income %s  ·  %s" }
S["ghost.claim"] = { ru = "Забрать %d побед", en = "Claim %d wins" }
S["ghost.claimAny"] = { ru = "Забрать победы", en = "Claim wins" }

S["arena.title"] = { ru = "Арена Призраков", en = "Ghost Arena" }
S["arena.blurb"] = {
	ru = "Твой лучший билд лежит в общем пуле как Призрак. Он дерётся, пока ты офлайн.",
	en = "Your best build sits in the shared pool as a Ghost. It fights while you are away.",
}
S["arena.challenge"] = { ru = "Вызвать противника", en = "Challenge an opponent" }
S["arena.victory"] = { ru = "ПОБЕДА", en = "VICTORY" }
S["arena.defeat"] = { ru = "ПОРАЖЕНИЕ", en = "DEFEAT" }
S["arena.you"] = { ru = "Ты:  урон %s  ·  прочность %s", en = "You:  damage %s  ·  durability %s" }
S["arena.foe"] = { ru = "%s:  урон %s  ·  прочность %s", en = "%s:  damage %s  ·  durability %s" }
S["arena.reward"] = { ru = "Осколков: +%d  ·  ранг %d", en = "Shards: +%d  ·  rank %d" }
S["arena.wonToast"] = { ru = "Победа над %s", en = "Defeated %s" }
S["arena.lostToast"] = { ru = "Поражение от %s", en = "Lost to %s" }
S["arena.ghostWins"] = { ru = "Твой Призрак выиграл %d боёв: +%d Осколков",
	en = "Your Ghost won %d fights: +%d Shards" }
S["arena.enter"] = { ru = "Выйти на арену", en = "Enter the arena" }
S["arena.object"] = { ru = "Арена Спектра", en = "Spectrum Arena" }
S["arena.sign"] = { ru = "АРЕНА ПРИЗРАКОВ", en = "GHOST ARENA" }
S["arena.exit"] = { ru = "ВЫХОД", en = "EXIT" }

S["ring.title"] = { ru = "Кольцо", en = "Ring" }
S["ring.level"] = { ru = "Уровень %d", en = "Level %d" }
S["ring.next"] = { ru = "Следующий даст +%s к доходу", en = "Next one adds +%s income" }
S["ring.buyOne"] = { ru = "Купить 1  —  %s", en = "Buy 1  —  %s" }
S["ring.buyMax"] = { ru = "Купить максимум", en = "Buy max" }

S["rebirth.title"] = { ru = "Перезарядка Батареи", en = "Battery Recharge" }
S["rebirth.blurb"] = {
	ru = "Сбрасывает Волю и уровень кольца.\nДетали, Осколки и открытые цвета остаются.",
	en = "Resets Will and ring level.\nParts, Shards and unlocked colours stay.",
}
S["rebirth.status"] = { ru = "Уровень %d из %d", en = "Level %d of %d" }
S["rebirth.multiplier"] = { ru = "Сейчас %s  →  станет %s", en = "Now %s  →  becomes %s" }
S["rebirth.do"] = { ru = "Перезарядить", en = "Recharge" }
S["rebirth.need"] = { ru = "Ещё %d уровней", en = "%d more levels" }
S["rebirth.result"] = { ru = "Перезарядка %d. Заряд +%d, итого %s",
	en = "Recharge %d. Charge +%d, total %s" }
S["rebirth.nextColor"] = { ru = "Следующий цвет — %s, на %d-й перезарядке (ещё %d)",
	en = "Next colour — %s, at recharge %d (%d more)" }

S["unlock.title"] = { ru = "Открыт новый цвет: %s!", en = "New colour unlocked: %s!" }
S["unlock.body"] = { ru = "Теперь он выпадает из ящиков", en = "It now drops from crates" }

S["build.title"] = { ru = "Сборка конструкта", en = "Construct build" }
S["build.equipped"] = { ru = "   [надето]", en = "   [equipped]" }
S["crate.title"] = { ru = "Ящики Спектра", en = "Spectrum Crates" }
S["crate.access"] = { ru = "Доступно цветов: %d из %d (до %s)",
	en = "Colours available: %d of %d (up to %s)" }
S["crate.pity"] = { ru = "До гарантии: %d из %d", en = "To guarantee: %d of %d" }
S["crate.open1"] = { ru = "Открыть 1  —  %d Осколков", en = "Open 1  —  %d Shards" }
S["crate.open10"] = { ru = "Открыть 10  —  %d Осколков", en = "Open 10  —  %d Shards" }
S["crate.odds"] = { ru = "Шансы", en = "Odds" }
S["crate.oddsTitle"] = { ru = "Шансы выпадения", en = "Drop chances" }
S["crate.oddsRow"] = { ru = "%s  —  %s%%", en = "%s  —  %s%%" }
S["crate.guarantee"] = {
	ru = "Гарантия: тир %d или выше каждые %d открытий.\nШансы нормируются по открытым цветам.",
	en = "Guarantee: tier %d or higher every %d opens.\nOdds are normalised over unlocked colours.",
}
S["crate.forced"] = { ru = "   ГАРАНТИЯ", en = "   GUARANTEED" }
S["crate.dropped"] = { ru = "Выпал %s", en = "Got %s" }
S["build.tab"] = { ru = "Сборка %d", en = "Build %d" }

S["kick.locked"] = {
	ru = "Твой профиль ещё занят предыдущей сессией. Зайди снова через минуту.",
	en = "Your profile is still open in a previous session. Please rejoin in a minute.",
}
S["kick.corrupt"] = {
	ru = "Данные профиля повреждены. Напиши в поддержку, ничего не потеряно.",
	en = "Your profile data is damaged. Please contact support — nothing is lost.",
}
S["kick.error"] = {
	ru = "Не удалось загрузить прогресс. Зайди снова через минуту.",
	en = "Could not load your progress. Please rejoin in a minute.",
}
S["kick.stolen"] = {
	ru = "Твой профиль открыт в другом сервере. Зайди снова — прогресс на месте.",
	en = "Your profile was opened on another server. Rejoin — your progress is safe.",
}

S["wheel.title"] = { ru = "Колесо Спектра", en = "Spectrum Wheel" }
S["wheel.skip"] = { ru = "Нажми, чтобы пропустить", en = "Tap to skip" }
S["wheel.close"] = { ru = "Нажми, чтобы закрыть", en = "Tap to close" }
S["wheel.forced"] = { ru = "ГАРАНТИЯ", en = "GUARANTEED" }

S["shop.title"] = { ru = "Магазин", en = "Shop" }
S["shop.empty"] = {
	ru = "Товары появятся здесь, когда игра будет опубликована и в Shared.Shop будут вписаны их идентификаторы.",
	en = "Items will appear once the game is published and their ids are filled in Shared.Shop.",
}
S["shop.owned"] = { ru = "КУПЛЕНО", en = "OWNED" }
S["shop.bought"] = { ru = "Куплено: %s", en = "Purchased: %s" }
S["shop.duplicate"] = { ru = "Этот набор уже куплен", en = "You already own this pack" }

S["err.shards"] = { ru = "Нужно %s Осколков", en = "Need %s Shards" }
S["err.rebirth"] = { ru = "Нужен уровень кольца %d", en = "Ring level %d required" }
S["err.cooldown"] = { ru = "Арена остынет через %d с", en = "Arena cools down in %ds" }
S["err.noOpponent"] = { ru = "Противник пока не найден", en = "No opponent found yet" }
S["err.generic"] = { ru = "Не получилось", en = "Did not work" }
S["offline.earned"] = { ru = "Пока тебя не было: +%s за %s",
	en = "While you were away: +%s over %s" }

S["tut.1"] = { ru = "Нажми Заряд — кольцо копит Волю", en = "Tap Charge — the ring gathers Will" }
S["tut.1.hint"] = { ru = "ещё %d", en = "%d more" }
S["tut.2"] = { ru = "Открой Кольцо и купи уровень", en = "Open Ring and buy a level" }
S["tut.2.hint"] = { ru = "доход вырастет", en = "income will grow" }
S["tut.3"] = { ru = "Вскрой ящик — оттуда падают детали", en = "Open a crate — parts drop from it" }
S["tut.3.hint"] = { ru = "стоит Осколки", en = "costs Shards" }
S["tut.4"] = { ru = "Загляни в Сборку — там твой конструкт", en = "Check Build — your construct is there" }
S["tut.4.hint"] = { ru = "пять слотов", en = "five slots" }
S["tut.5"] = { ru = "Вызови чужого Призрака на арене", en = "Challenge a Ghost in the arena" }
S["tut.5.hint"] = { ru = "он дерётся, пока владелец спит", en = "it fights while its owner sleeps" }
S["tut.6"] = { ru = "Перезарядись — откроешь новые цвета в ящиках", en = "Recharge — unlock new colours in crates" }
S["tut.6.hint"] = { ru = "следующий — %s, на %d-й перезарядке", en = "next: %s, at recharge %d" }
S["tut.done"] = { ru = "Обучение пройдено. Дальше сам.", en = "Tutorial complete. You are on your own." }
S["tut.step"] = { ru = "%d / %d", en = "%d / %d" }

S["world.toHub"] = { ru = "В ХАБ", en = "TO HUB" }
S["world.leaderboard"] = { ru = "САМЫЕ СТРАШНЫЕ КОНСТРУКТЫ", en = "MOST FEARED CONSTRUCTS" }
S["world.place"] = { ru = "#%d", en = "#%d" }
S["world.boardRow"] = { ru = "%2d.  %-18s  %s   ранг %d", en = "%2d.  %-18s  %s   rank %d" }

S["time.h"] = { ru = "%dч %dм", en = "%dh %dm" }
S["time.m"] = { ru = "%dм %dс", en = "%dm %ds" }
S["time.s"] = { ru = "%dс", en = "%ds" }

S["color.will"] = { ru = "Воля", en = "Willpower" }
S["color.fear"] = { ru = "Страх", en = "Fear" }
S["color.rage"] = { ru = "Ярость", en = "Rage" }
S["color.hope"] = { ru = "Надежда", en = "Hope" }
S["color.love"] = { ru = "Любовь", en = "Love" }
S["color.greed"] = { ru = "Алчность", en = "Greed" }
S["color.compassion"] = { ru = "Сострадание", en = "Compassion" }
S["color.death"] = { ru = "Смерть", en = "Death" }
S["color.life"] = { ru = "Жизнь", en = "Life" }

S["part.core_prism"] = { ru = "Призма", en = "Prism" }
S["part.core_reactor"] = { ru = "Реактор", en = "Reactor" }
S["part.core_shard"] = { ru = "Осколок", en = "Shard" }
S["part.core_heart"] = { ru = "Сердцевина", en = "Heart" }

S["part.emit_lance"] = { ru = "Копьё", en = "Lance" }
S["part.emit_spray"] = { ru = "Веер", en = "Spray" }
S["part.emit_coil"] = { ru = "Катушка", en = "Coil" }
S["part.emit_beam"] = { ru = "Луч", en = "Beam" }

S["part.frame_plate"] = { ru = "Панцирь", en = "Plate" }
S["part.frame_lattice"] = { ru = "Решётка", en = "Lattice" }
S["part.frame_husk"] = { ru = "Оболочка", en = "Husk" }
S["part.frame_bulwark"] = { ru = "Оплот", en = "Bulwark" }

S["part.focus_lens"] = { ru = "Линза", en = "Lens" }
S["part.focus_eye"] = { ru = "Око", en = "Eye" }
S["part.focus_facet"] = { ru = "Грань", en = "Facet" }
S["part.focus_spike"] = { ru = "Игла", en = "Spike" }

S["part.sigil_mark"] = { ru = "Метка", en = "Mark" }
S["part.sigil_brand"] = { ru = "Клеймо", en = "Brand" }
S["part.sigil_crown"] = { ru = "Венец", en = "Crown" }
S["part.sigil_seal"] = { ru = "Печать", en = "Seal" }

S["shop.DoubleWill.name"] = { ru = "x2 Воля", en = "x2 Will" }
S["shop.DoubleWill.blurb"] = { ru = "Удваивает доход навсегда.", en = "Doubles your income permanently." }

S["shop.OfflinePlus.name"] = { ru = "Офлайн 12 часов", en = "12h Offline" }
S["shop.OfflinePlus.blurb"] = {
	ru = "12 часов вместо 4 и полная ставка вместо половинной.",
	en = "12 hours instead of 4, at full rate instead of half.",
}

S["shop.AutoBattle.name"] = { ru = "Авто-бой", en = "Auto-battle" }
S["shop.AutoBattle.blurb"] = {
	ru = "Конструкт сам выходит на бой каждые 45 секунд, пока ты в игре.",
	en = "Your construct battles a Ghost on its own every 45 seconds while you play.",
}

S["shop.ExtraSlots.name"] = { ru = "+2 слота сборки", en = "+2 build slots" }
S["shop.ExtraSlots.blurb"] = {
	ru = "Держи три конструкта и переключайся между ними.",
	en = "Keep three constructs and switch between them.",
}

S["shop.VIP.name"] = { ru = "VIP", en = "VIP" }
S["shop.VIP.blurb"] = { ru = "x1.5 к доходу Воли, аура и метка в чате.", en = "x1.5 Will income, an aura and a chat tag." }

S["shop.Keys10.name"] = { ru = "10 ящиков", en = "10 crates" }
S["shop.Keys10.blurb"] = { ru = "1000 Осколков.", en = "1000 Shards." }

S["shop.Keys60.name"] = { ru = "60 ящиков", en = "60 crates" }
S["shop.Keys60.blurb"] = { ru = "6000 Осколков, выгоднее на 16%.", en = "6000 Shards, 16% cheaper." }

S["shop.StarterPack.name"] = { ru = "Стартовый набор", en = "Starter pack" }
S["shop.StarterPack.blurb"] = {
	ru = "2500 Осколков и час дохода. Один раз на аккаунт.",
	en = "2500 Shards and an hour of income. Once per account.",
}

S["shop.HourOfWill.name"] = { ru = "Час дохода", en = "Hour of income" }
S["shop.HourOfWill.blurb"] = {
	ru = "Сразу столько Воли, сколько накопилось бы за час.",
	en = "Instantly as much Will as an hour would earn.",
}

Locale.Strings = S

function Locale.get(lang: string, key: string, ...): string
	local entry = S[key]
	if not entry then
		return key
	end

	local text = entry[lang] or entry[Locale.DEFAULT] or key
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		if ok then
			return formatted
		end
		return text
	end
	return text
end

function Locale.colorName(lang: string, tier: number): string
	local entry = Eco.COLORS[tier]
	if not entry then
		return "?"
	end
	return Locale.get(lang, "color." .. entry.id)
end

function Locale.partName(lang: string, defId: string): string
	return Locale.get(lang, "part." .. defId)
end

function Locale.isValid(lang: any): boolean
	return type(lang) == "string" and SUPPORTED[lang] == true
end

function Locale.fromLocaleId(localeId: string?): string
	if type(localeId) == "string" and string.lower(string.sub(localeId, 1, 2)) == "ru" then
		return "ru"
	end
	return "en"
end

function Locale.duration(lang: string, seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60

	if h > 0 then
		return Locale.get(lang, "time.h", h, m)
	elseif m > 0 then
		return Locale.get(lang, "time.m", m, s)
	end
	return Locale.get(lang, "time.s", s)
end

function Locale.count(): (number, number)
	local total, missing = 0, 0
	for _, entry in S do
		total += 1
		for _, lang in Locale.LANGUAGES do
			if not entry[lang] then
				missing += 1
			end
		end
	end
	return total, missing
end

return Locale
