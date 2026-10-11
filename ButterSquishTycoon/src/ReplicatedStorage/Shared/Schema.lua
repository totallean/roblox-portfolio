local Schema = {}

local MAX_STRING = 128

function Schema.Number(opts)
	opts = opts or {}
	return {
		Name = "number",
		Check = function(value)
			if type(value) ~= "number" then
				return false, ("ожидалось number, пришло %s"):format(typeof(value))
			end

			if value ~= value then
				return false, "NaN"
			end
			if value == math.huge or value == -math.huge then
				return false, "бесконечность"
			end
			if opts.Integer and math.floor(value) ~= value then
				return false, "ожидалось целое"
			end
			if opts.Min and value < opts.Min then
				return false, ("меньше минимума %s"):format(tostring(opts.Min))
			end
			if opts.Max and value > opts.Max then
				return false, ("больше максимума %s"):format(tostring(opts.Max))
			end
			return true
		end,
	}
end

function Schema.String(opts)
	opts = opts or {}

	local allowed = nil
	if opts.OneOf then
		allowed = {}
		for _, value in ipairs(opts.OneOf) do
			allowed[value] = true
		end
	end

	return {
		Name = "string",
		Check = function(value)
			if type(value) ~= "string" then
				return false, ("ожидалась string, пришло %s"):format(typeof(value))
			end
			if #value > (opts.MaxLength or MAX_STRING) then
				return false, "слишком длинная строка"
			end
			if #value < (opts.MinLength or 1) then
				return false, "слишком короткая строка"
			end
			if allowed and not allowed[value] then
				return false, ("значение %q не из белого списка"):format(value)
			end
			return true
		end,
	}
end

function Schema.Boolean()
	return {
		Name = "boolean",
		Check = function(value)
			if type(value) ~= "boolean" then
				return false, ("ожидался boolean, пришло %s"):format(typeof(value))
			end
			return true
		end,
	}
end

function Schema.Key(source, opts)
	opts = opts or {}
	return {
		Name = "key",
		Check = function(value)
			if type(value) ~= "string" then
				return false, ("ожидался ключ-string, пришло %s"):format(typeof(value))
			end
			if #value > MAX_STRING then
				return false, "слишком длинный ключ"
			end
			local table_ = type(source) == "function" and source() or source
			if type(table_) ~= "table" then
				return false, "источник ключей недоступен"
			end
			if table_[value] == nil then
				return false, ("неизвестный ключ %q"):format(value)
			end
			return true
		end,
	}
end

function Schema.Optional(inner)
	return {
		Name = "optional " .. (inner.Name or "?"),
		Optional = true,
		Check = function(value)
			if value == nil then
				return true
			end
			return inner.Check(value)
		end,
	}
end

function Schema.Args(list)
	list = list or {}
	return function(...)
		local packed = table.pack(...)

		if packed.n > #list then
			return false, ("слишком много аргументов: %d при ожидаемых %d"):format(packed.n, #list)
		end

		for index, checker in ipairs(list) do
			local ok, err = checker.Check(packed[index])
			if not ok then
				return false, ("аргумент #%d: %s"):format(index, err or "не прошёл проверку")
			end
		end
		return true
	end
end

return Schema
