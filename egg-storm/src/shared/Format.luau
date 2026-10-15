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

-- Corto para números grandes: 999,999 -> "999,999"; 1440000 -> "1.44M"; 2300000000 -> "2.3B"
local SUFFIXES: { { Size: number, Letter: string } } = {
	{ Size = 1e15, Letter = "Qa" },
	{ Size = 1e12, Letter = "T" },
	{ Size = 1e9, Letter = "B" },
	{ Size = 1e6, Letter = "M" },
}
function Format.Compact(n: number): string
	for _, suffix in SUFFIXES do
		if math.abs(n) >= suffix.Size then
			-- 2 decimales sin redondear para arriba (el 1e-6 corrige errores chiquitos de los decimales: 2.3 -> 229.9999)
			local value = math.floor(n / suffix.Size * 100 + 1e-6) / 100
			local text = string.format("%.2f", value)
			text = string.gsub(text, "0+$", "")
			text = string.gsub(text, "%.$", "")
			return text .. suffix.Letter
		end
	end
	return Format.Number(n)
end

return Format
