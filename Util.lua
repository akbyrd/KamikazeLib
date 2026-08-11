local Kami = select(2, ...)
local Util = {}
Kami.Util = Util

function Util.RectIcon(frame, texture, size, zoom, aspect)
	local xFactor = 1 * min(1, aspect)
	local yFactor = 1 / max(1, aspect)
	local texXMin = 0.5 - (0.5 - zoom) * xFactor
	local texYMin = 0.5 - (0.5 - zoom) * yFactor
	frame:SetSize(size * xFactor, size * yFactor)
	texture:SetTexCoord(texXMin, 1 - texXMin, texYMin, 1 - texYMin)
end
