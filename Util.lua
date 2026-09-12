local Kami = select(2, ...)
local Util = {}
Kami.Util = Util

function Util.AspectScale(aspect)
	local xScale = 1 * min(1, aspect)
	local yScale = 1 / max(1, aspect)
	return xScale, yScale
end

function Util.TexCoords(zoom, xSize, ySize)
	local mSize  = max(xSize, ySize)
	local xScale = xSize / mSize
	local yScale = ySize / mSize

	local texXMin = 0.5 - (0.5 - zoom) * xScale
	local texYMin = 0.5 - (0.5 - zoom) * yScale
	return texXMin, texYMin
end

function Util.RectIcon(frame, texture, size, zoom, aspect)
	local xScale = 1 * min(1, aspect)
	local yScale = 1 / max(1, aspect)

	local xSize = size * xScale
	local ySize = size * yScale
	frame:SetSize(xSize, ySize)

	local texXMin = 0.5 - (0.5 - zoom) * xScale
	local texYMin = 0.5 - (0.5 - zoom) * yScale
	texture:SetTexCoord(texXMin, 1 - texXMin, texYMin, 1 - texYMin)
end

function Util.ZoomIcon(texture, zoom, xSize, ySize)
	local mSize  = max(xSize, ySize)
	local xScale = xSize / mSize
	local yScale = ySize / mSize

	local texXMin = 0.5 - (0.5 - zoom) * xScale
	local texYMin = 0.5 - (0.5 - zoom) * yScale
	texture:SetTexCoord(texXMin, 1 - texXMin, texYMin, 1 - texYMin)
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

function Util.RoundToPixel(size, pixelsToUI)
	return Round(size / pixelsToUI) * pixelsToUI
end

function Util.TableAssign(table, key, value)
	table[key] = value
	return value
end

function Util.TableReplace(table, key, value)
	local prevValue = table[key]
	table[key] = value
	return prevValue
end

function Util.TableAdd(table, key, add)
	local value = table[key] + add
	table[key] = value
	return value
end

function Util.TableRefAdd(table, key, add)
	local value = (table[key] or 0) + add
	table[key] = value ~= 0 and value or nil
	return value
end

function Util.TableKeys(table)
	local keys = {}
	for k, v in pairs(table) do
		_G.table.insert(keys, k)
	end
	return keys
end

function Util.TableValues(table)
	local values = {}
	for k, v in pairs(table) do
		_G.table.insert(values, v)
	end
	return values
end

function Util.TableShallowCopy(table)
	local copy = {}
	for key, value in pairs(table) do
		copy[key] = value
	end
	return copy
end

function Util.Utf8(codepoint)
	if codepoint < 0x80 then
		return string.char(codepoint)
	elseif codepoint < 0x800 then
		local byte1 = 0xC0 + bit.rshift(codepoint, 6)
		local byte2 = 0x80 + bit.band(codepoint, 0x3F)
		return string.char(byte1, byte2)
	elseif codepoint < 0x10000 then
		local byte1 = 0xE0 + bit.rshift(codepoint, 12)
		local byte2 = 0x80 + bit.band(bit.rshift(codepoint, 6), 0x3F)
		local byte3 = 0x80 + bit.band(codepoint, 0x3F)
		return string.char(byte1, byte2, byte3)
	else
		local byte1 = 0xF0 + bit.rshift(codepoint, 18)
		local byte2 = 0x80 + bit.band(bit.rshift(codepoint, 12), 0x3F)
		local byte3 = 0x80 + bit.band(bit.rshift(codepoint, 6), 0x3F)
		local byte4 = 0x80 + bit.band(codepoint, 0x3F)
		return string.char(byte1, byte2, byte3, byte4)
	end
end

function Util.UISize(base, exponent)
	local x = base * 1.618^exponent
	return tostring(x) .. "ui"
end

-- TODO: Do we need to restrict to integers?
function Util.SameParity(x, y)
	local xParity = x % 2
	local yParity = y % 2
	return y + (xParity - yParity)
end

function Util.CenterIcon(font, frameSize, fontSize)
	-- Center em square on a box, instead of the line box. This is an approximation because it
	-- guesses the rounding value, which requires per-glyph data to calculate accurately. Assumes the
	-- frame is in pixel space.

	assert(fontSize % 1 == 0 and frameSize % 1 == 0, "frame size and font size must be integer values")
	assert(fontSize % 2 == frameSize % 2, "frame size and font size must have the same parity")

	local baseline = floor(fontSize * font.ascent / (font.ascent + font.descent) + 0.5)
	local rounding = fontSize % font.grid == 0 and 0 or 1
	local xOffset  = (frameSize - fontSize) / 2 - rounding
	local yOffset  = (frameSize + fontSize) / 2 - baseline
	xOffset  = 0 + xOffset + 0.5
	yOffset  = 0 - yOffset + 0.5
	return xOffset, yOffset
end
