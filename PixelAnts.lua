local Kami = select(2, ...)
local PixelAnts = {}
Kami.PixelAnts = PixelAnts

-- thickness - strip size on the cross axis, in parent units
-- inset     - distance in from the parent's edges
-- color     - ColorMixin
-- speed     - revolutions per second, positive is clockwise
-- segments  - segment count along the top edge, approximate
-- duty      - lit fraction of each segment cycle, in 1/64 steps
function PixelAnts.Create(parent, thickness, inset, color, speed, segments, duty)
	local f = CreateFrame("Frame", nil, parent)
	f:SetPoint("TOPLEFT",      inset, -inset)
	f:SetPoint("BOTTOMRIGHT", -inset,  inset)

	local function CreateStrip(point1, point2, yOffset)
		local tex = f:CreateTexture(nil, "OVERLAY")
		tex:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\PixelAnts.tga", "REPEAT", "REPEAT", "NEAREST")
		tex:SetVertexColor(color:GetRGBA())
		tex:SetPoint(point1, 0, -yOffset)
		tex:SetPoint(point2, 0,  yOffset)
		tex:SetSize(thickness, thickness) -- Anchors take precedence over explicit size

		local group = tex:CreateAnimationGroup()
		group:SetLooping("REPEAT")
		tex.Anim   = group:CreateAnimation("TextureCoord")
		tex.Scroll = group
		return tex
	end

	f.edges = {
		CreateStrip("TOPLEFT",    "TOPRIGHT",    0),
		CreateStrip("TOPRIGHT",   "BOTTOMRIGHT", thickness),
		CreateStrip("BOTTOMLEFT", "BOTTOMRIGHT", 0),
		CreateStrip("TOPLEFT",    "BOTTOMLEFT",  thickness),
	}
	f.thickness   = thickness
	f.speed       = speed
	f.segments    = segments
	f.duty        = duty
	f.RefreshSize = PixelAnts.RefreshSize
	return f
end

local edgeWalk = {
	{ x = 1, y = 0, u = { 0, 0, 1, 1 } },
	{ x = 0, y = 1, u = { 0, 1, 0, 1 } },
	{ x = 1, y = 0, u = { 1, 1, 0, 0 } },
	{ x = 0, y = 1, u = { 1, 0, 1, 0 } },
}

function PixelAnts.RefreshSize(f)
	local xSize = f:GetWidth()
	local ySize = f:GetHeight()
	if not (xSize > 0 and ySize > 0) then return end

	local perim = 2 * (xSize + ySize)
	local tiles = max(1, Round(f.segments * perim / xSize))
	local tile  = perim / tiles
	local v     = (Clamp(Round(f.duty * 64), 1, 64) - 0.5) / 64

	local total = 0
	for iEdge, w in ipairs(edgeWalk) do
		local tex = f.edges[iEdge]

		local x = w.x * xSize       / tile
		local y = w.y * ySize       / tile
		local t = w.y * f.thickness / tile

		local start  = total + t
		local length = x + y - 2*t
		total = total + x + y

		local ulX, ulY = start + length * w.u[1], v
		local llX, llY = start + length * w.u[2], v
		local urX, urY = start + length * w.u[3], v
		local lrX, lrY = start + length * w.u[4], v
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
