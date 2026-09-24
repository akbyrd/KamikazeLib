local Kami = select(2, ...)
local PixelAnts = {}
Kami.PixelAnts = PixelAnts

local edgeWalk = {
	{ x = 1, y = 0, u = { 0, 0, 1, 1 }, points = { "TOPLEFT",    "TOPRIGHT"    } },
	{ x = 0, y = 1, u = { 0, 1, 0, 1 }, points = { "TOPRIGHT",   "BOTTOMRIGHT" } },
	{ x = 1, y = 0, u = { 1, 1, 0, 0 }, points = { "BOTTOMLEFT", "BOTTOMRIGHT" } },
	{ x = 0, y = 1, u = { 1, 0, 1, 0 }, points = { "TOPLEFT",    "BOTTOMLEFT"  } },
}

function PixelAnts.Create(parent)
	local f = CreateFrame("Frame", nil, parent)

	f.edges = {}
	for iEdge, w in ipairs(edgeWalk) do
		local tex = f:CreateTexture(nil, "OVERLAY")
		tex:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\PixelAnts.tga", "REPEAT", "REPEAT", "NEAREST")

		local group = tex:CreateAnimationGroup()
		group:SetLooping("REPEAT")
		tex.Anim   = group:CreateAnimation("TextureCoord")
		tex.Scroll = group
		f.edges[iEdge] = tex
	end

	f.SetConfig   = PixelAnts.SetConfig
	f.RefreshSize = PixelAnts.RefreshSize
	return f
end

-- thickness - strip size on the cross axis, in parent units
-- inset     - distance in from the parent's edges, in parent units
-- color     - ColorMixin
-- speed     - revolutions per second, positive is clockwise
-- segments  - segment count along the top edge, approximate
-- duty      - lit fraction of each segment cycle, in 1/64 steps
function PixelAnts.SetConfig(f, thickness, inset, color, speed, segments, duty)
	-- NOTE: This pattern needs to change if we ever accept booleans
	f.thickness = thickness or f.thickness
	f.inset     = inset     or f.inset
	f.speed     = speed     or f.speed
	f.segments  = segments  or f.segments
	f.duty      = duty      or f.duty
	f.v         = (Clamp(Round(f.duty * 64), 1, 64) - 0.5) / 64

	if color then
		for iEdge, tex in ipairs(f.edges) do
			tex:SetVertexColor(color:GetRGBA())
		end
	end
end

-- TODO: Hoist the size getters and check to the caller?
function PixelAnts.RefreshSize(f, xSize, ySize)
	f:SetPoint("TOPLEFT",      f.inset, -f.inset)
	f:SetPoint("BOTTOMRIGHT", -f.inset,  f.inset)

	for iEdge, tex in ipairs(f.edges) do
		-- Anchors take precedence over explicit size
		local w       = edgeWalk[iEdge]
		local yOffset = w.y * f.thickness
		tex:SetPoint(w.points[1], 0, -yOffset)
		tex:SetPoint(w.points[2], 0,  yOffset)
		tex:SetSize(f.thickness, f.thickness)
	end

	xSize = xSize and (xSize - 2*f.inset) or f:GetWidth()
	ySize = ySize and (ySize - 2*f.inset) or f:GetHeight()
	if not (xSize > 0 and ySize > 0) then return end

	local perim = 2 * (xSize + ySize)
	local tiles = max(1, Round(f.segments * perim / xSize))
	local tile  = perim / tiles

	local total = 0
	for iEdge, w in ipairs(edgeWalk) do
		local tex = f.edges[iEdge]

		local x = w.x * xSize       / tile
		local y = w.y * ySize       / tile
		local t = w.y * f.thickness / tile

		local start  = total + t
		local length = x + y - 2*t
		total = total + x + y

		local ulX, ulY = start + length * w.u[1], f.v
		local llX, llY = start + length * w.u[2], f.v
		local urX, urY = start + length * w.u[3], f.v
		local lrX, lrY = start + length * w.u[4], f.v
		tex:SetTexCoord(ulX, ulY, llX, llY, urX, urY, lrX, lrY)
	end

	for iEdge, tex in ipairs(f.edges) do
		tex.Scroll:Stop()
		if f.speed ~= 0 then
			tex.Anim:SetOffset(f.speed > 0 and -1 or 1, 0)
			tex.Anim:SetDuration(1 / (abs(f.speed) * tiles))
			tex.Scroll:Play()
		end
	end
end
