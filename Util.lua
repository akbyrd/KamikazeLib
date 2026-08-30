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

function Util.SetSliceScale(texture, scale)
	-- NOTE: Changing the scale doesn't work without some coercion. The Hide/Show cycle works, but it
	-- causes all borders using the same texture to change if the scale is set beforehand. A
	-- SetTexture cycle breaks the shared state somehow. Various other things that don't work at all:
	-- SetAllPoints, SetTexture(nil), ClearTextureSlice. It also matter whether you call these things
	-- on the frame or the texture. Putting the SetScale last seems to work.
	local frame = texture:GetParent()
	if frame:IsShown() then
		frame:Hide()
		texture:SetScale(scale)
		frame:Show()
	else
		texture:SetScale(scale)
	end
end

function Util.Inset(frame, amount)
	frame:SetPoint("TOPLEFT",      amount, -amount)
	frame:SetPoint("BOTTOMRIGHT", -amount,  amount)
end

function Util.RoundToPixel(size, pixelsToUI)
	return Round(size / pixelsToUI) * pixelsToUI
end
