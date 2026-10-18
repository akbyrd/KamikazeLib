local Kami = select(2, ...)
local BorderTrace = {}
Kami.BorderTrace = BorderTrace

local Media = Kami.Media

local edgeWalk = {
	{ x =  1, y =  0, u = { 0, 0, 1, 1 }, points = { "TOPLEFT",     "TOPRIGHT"    } },
	{ x =  0, y = -1, u = { 0, 1, 0, 1 }, points = { "TOPRIGHT",    "BOTTOMRIGHT" } },
	{ x = -1, y =  0, u = { 1, 1, 0, 0 }, points = { "BOTTOMRIGHT", "BOTTOMLEFT"  } },
	{ x =  0, y =  1, u = { 1, 0, 1, 0 }, points = { "BOTTOMLEFT",  "TOPLEFT"     } },
}

function BorderTrace.Create(parent)
	local f = CreateFrame("Frame", nil, parent)

	f.Anim = f:CreateAnimationGroup()
	f.Anim:SetScript("OnFinished", function() f:Hide() end)

	f.edges = {}
	for iEdge, w in ipairs(edgeWalk) do
		local tex = f:CreateTexture(nil, "OVERLAY")
		tex:SetTexture(Media.Staircase.texture, "REPEAT", "CLAMP", "TRILINEAR")
		tex:SetTexCoord(w.u[1], 0, w.u[2], 0, w.u[3], 0, w.u[4], 0)
		tex:SetSnapToPixelGrid(false)
		tex:SetTexelSnappingBias(0)

		tex.Fill = f.Anim:CreateAnimation("TextureCoord")
		tex.Fill:SetTarget(tex)
		tex.Fill:SetOrder(1)
		tex.Fill:SetSmoothing("IN")

		tex.Chase = f.Anim:CreateAnimation("TextureCoord")
		tex.Chase:SetTarget(tex)
		tex.Chase:SetOrder(1)
		tex.Chase:SetSmoothing("OUT")

		tex.Rotate = f.Anim:CreateAnimation("TextureCoord")
		tex.Rotate:SetTarget(tex)
		tex.Rotate:SetOrder(1)
		tex.Rotate:SetSmoothing("IN_OUT")
		f.edges[iEdge] = tex
	end

	f.SetConfig   = BorderTrace.SetConfig
	f.RefreshSize = BorderTrace.RefreshSize
	f.Play        = BorderTrace.Play
	f.Stop        = BorderTrace.Stop
	return f
end

-- thickness - strip size on the cross axis, in parent units
-- inset     - distance in from the parent's edges, in parent units
-- color     - ColorMixin
-- duration  - seconds for the whole animation, split evenly between fill and chase
-- distance  - distance the head travels during the chase, in sides
-- fill      - fraction of each side filled before the chase starts
function BorderTrace.SetConfig(f, thickness, inset, color, duration, distance, fill)
	-- NOTE: This pattern needs to change if we ever accept booleans
	f.thickness = thickness or f.thickness
	f.inset     = inset     or f.inset
	f.duration  = duration  or f.duration
	f.distance  = distance  or f.distance
	f.fill      = fill      or f.fill

	for iEdge, tex in ipairs(f.edges) do
		if color then
			tex:SetVertexColor(color:GetRGBA())
		end

		tex.Fill:SetOffset(0, f.fill)
		tex.Fill:SetDuration(.25 * f.duration)
		tex.Chase:SetOffset(-f.fill, -f.fill)
		tex.Chase:SetDuration(.75 * f.duration)
		tex.Chase:SetStartDelay(.25 * f.duration)
		tex.Rotate:SetOffset(-f.distance, 0)
		tex.Rotate:SetDuration(1 * f.duration)
	end
end

function BorderTrace.RefreshSize(f)
	f:SetPoint("TOPLEFT",      f.inset, -f.inset)
	f:SetPoint("BOTTOMRIGHT", -f.inset,  f.inset)

	for iEdge, tex in ipairs(f.edges) do
		-- Anchors take precedence over explicit size
		local w = edgeWalk[iEdge]
		tex:SetPoint(w.points[1])
		tex:SetPoint(w.points[2], -w.x * f.thickness, -w.y * f.thickness)
		tex:SetSize(f.thickness, f.thickness)
	end
end

function BorderTrace.Play(f)
	f:Show()
	f.Anim:Restart()
end

function BorderTrace.Stop(f)
	f.Anim:Stop()
	f:Hide()
end
