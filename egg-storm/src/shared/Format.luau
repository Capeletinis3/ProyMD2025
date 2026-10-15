--!strict
-- Format: ayudantes para mostrar números lindos en pantalla.

local Format = {}

-- 1234567 -> "1,234,567"
function Format.Number(n: number): string
	local whole = tostring(math.floor(n))
	local sign = ""
	if string.sub(whole, 1, 1) == "-" then
		sign = "-"
		whole = string.sub(whole, 2)
	end
	local result = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(result, 1, 1) == "," then
		result = string.sub(result, 2)
	end
	return sign .. result
end

return Format
