--!strict

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end

	local sign = n < 0 and "-" or ""
	n = math.abs(n)

	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end

	local tier = math.floor(math.log(n, 1000))
	local scaled = n / 1000 ^ tier

	if scaled >= 999.5 then
		tier += 1
		scaled /= 1000
	end

	local suffix = SUFFIXES[tier + 1]
	if not suffix then
		return sign .. string.format("%.2e", n)
	end

	local fmt = if scaled < 10 then "%.2f" elseif scaled < 100 then "%.1f" else "%.0f"
	return sign .. string.format(fmt, scaled) .. suffix
end

function Format.multiplier(x: number): string
	local fmt = if x < 10 then "%.2f" else "%.1f"
	return "x" .. (string.format(fmt, x):gsub("%.?0+$", ""))
end

return Format
