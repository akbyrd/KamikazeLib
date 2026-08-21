local Kami = select(2, ...)
local Util = {}
Kami.Util = Util

function Util.RectIcon(frame, texture, zoom, aspect)
	local xScale = 1 * min(1, aspect)
	local yScale = 1 / max(1, aspect)

	local xSize   = frame:GetWidth()
	local ySize   = frame:GetHeight()
	local maxSize = max(xSize, ySize)
	xSize = maxSize * xScale
	ySize = maxSize * yScale
	frame:SetSize(xSize, ySize)

	local texXMin = 0.5 - (0.5 - zoom) * xScale
	local texYMin = 0.5 - (0.5 - zoom) * yScale
	texture:SetTexCoord(texXMin, 1 - texXMin, texYMin, 1 - texYMin)
end

function Util.RoundSize(frame)
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
	local xSize = Round(frame:GetWidth()  / pixelsToUI) * pixelsToUI
	local ySize = Round(frame:GetHeight() / pixelsToUI) * pixelsToUI
	frame:SetSize(xSize, ySize)
end
