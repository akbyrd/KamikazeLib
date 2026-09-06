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
