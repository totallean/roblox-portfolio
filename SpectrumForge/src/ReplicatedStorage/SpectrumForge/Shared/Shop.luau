--!strict

local RunService = game:GetService("RunService")

local Shop = {}

export type PassInfo = {
	id: number,
	name: string,
	blurb: string,
	price: number,
	order: number,
}

export type ProductInfo = {
	id: number,
	name: string,
	blurb: string,
	price: number,
	order: number,
	shards: number?,
	willHours: number?,
	once: boolean?,
}

local Passes: { [string]: PassInfo } = {
	DoubleWill = {
		id = 2007080790, order = 1, price = 199,
		name = "x2 Воля",
		blurb = "Удваивает доход навсегда.",
	},
	OfflinePlus = {
		id = 2006528740, order = 2, price = 249,
		name = "Офлайн 12 часов",
		blurb = "12 часов вместо 4 и полная ставка вместо половинной.",
	},
	AutoBattle = {
		id = 2005124746, order = 3, price = 299,
		name = "Авто-бой",
		blurb = "Конструкт сам выходит на бой каждые 45 секунд, пока ты в игре.",
	},
	ExtraSlots = {
		id = 2005100736, order = 4, price = 399,
		name = "+2 слота сборки",
		blurb = "Держи три конструкта и переключайся между ними.",
	},
	VIP = {
		id = 2006516771, order = 5, price = 799,
		name = "VIP",
		blurb = "x1.5 к доходу Воли, аура и метка в чате.",
	},
}

Shop.Passes = Passes

local Products: { [string]: ProductInfo } = {
	Keys10 = {
		id = 3716205988, order = 1, price = 99,
		name = "10 ящиков",
		blurb = "1000 Осколков.",
		shards = 1000,
	},
	Keys60 = {
		id = 3716206541, order = 2, price = 499,
		name = "60 ящиков",
		blurb = "6000 Осколков, выгоднее на 16%.",
		shards = 6000,
	},
	StarterPack = {
		id = 3716206796, order = 3, price = 149,
		name = "Стартовый набор",
		blurb = "2500 Осколков и час дохода. Один раз на аккаунт.",
		shards = 2500,
		willHours = 1,
		once = true,
	},
	HourOfWill = {
		id = 3716206943, order = 4, price = 79,
		name = "Час дохода",
		blurb = "Сразу столько Воли, сколько накопилось бы за час.",
		willHours = 1,
	},
}

Shop.Products = Products

function Shop.passByAssetId(assetId: number): (string?, PassInfo?)
	for key, info in Shop.Passes do
		if info.id ~= 0 and info.id == assetId then
			return key, info
		end
	end
	return nil, nil
end

function Shop.productByAssetId(assetId: number): (string?, ProductInfo?)
	for key, info in Shop.Products do
		if info.id ~= 0 and info.id == assetId then
			return key, info
		end
	end
	return nil, nil
end

function Shop.isConfigured(info: { id: number }): boolean
	return info.id ~= 0
end

function Shop.validate()
	if not RunService:IsStudio() then
		return
	end

	local missing = {}
	for key, info in Shop.Passes do
		if info.id == 0 then
			table.insert(missing, "геймпасс " .. key)
		end
	end
	for key, info in Shop.Products do
		if info.id == 0 then
			table.insert(missing, "продукт " .. key)
		end
	end

	if #missing > 0 then
		warn(("[Shop] не настроено товаров: %d. Создай их на странице игры и впиши id в Shared.Shop")
			:format(#missing))
	end
end

return Shop
