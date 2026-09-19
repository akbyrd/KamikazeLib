local Kami = select(2, ...)
local IconTest4 = {}
Kami.IconTest4 = IconTest4

local Util = Kami.Util

-- Material Symbols is drawn on a 24 pixel grid at 960 upem, so one grid pixel is 40 font units. A
-- glyph's left bearing lands on a whole pixel only when xMin * size is a multiple of 960. Boxes are
-- tinted red where it doesn't, which is what the rounding term in CenterIcon is compensating for.
-- Across a 48 glyph sample: 24px is clean for 44, 48px for 44, 36px for only 22.
local UPM  = 960
local FONT = {
	path    = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf",
	ascent  = 1056,
	descent = 96,
	grid    = 24,
}

local TITLE = "Fixed icon sizes. Red boxes have a fractional left bearing at that size. /run Kami.IconTest4.SetGrid(12) to drop the rounding term"

local sizes    = { 24, 36, 48 }
local inset    = 8
local gap      = 8
local pad      = 8
local columns  = 6
local header   = { title = 22, labels = 16 }
local position = { x = 1873, y = 8 }

-- xMin is the outline's left bearing in font units, read from the TTF
local glyphs = {
	{ name = "close",        code = 0xE5CD, xMin = 200 },
	{ name = "add",          code = 0xE145, xMin = 200 },
	{ name = "remove",       code = 0xE15B, xMin = 200 },
	{ name = "check",        code = 0xE5CA, xMin = 154 },
	{ name = "done",         code = 0xE876, xMin = 154 },
	{ name = "settings",     code = 0xE8B8, xMin =  78 },
	{ name = "filter_alt",   code = 0xEF4F, xMin = 118 },
	{ name = "expand_more",  code = 0xE5CF, xMin = 240 },
	{ name = "chevron_left", code = 0xE408, xMin = 320 },
	{ name = "arrow_back",   code = 0xE5C4, xMin = 160 },
	{ name = "arrow_upward", code = 0xE5D8, xMin = 280 },
	{ name = "menu",         code = 0xE5D2, xMin = 120 },
	{ name = "more_vert",    code = 0xE5D4, xMin = 400 },
	{ name = "drag_ind",     code = 0xE945, xMin = 280 },
	{ name = "search",       code = 0xE8B6, xMin = 120 },
	{ name = "delete",       code = 0xE872, xMin = 160 },
	{ name = "edit",         code = 0xE3C9, xMin = 120 },
	{ name = "content_copy", code = 0xE14D, xMin = 120 },
	{ name = "refresh",      code = 0xE5D5, xMin = 160 },
	{ name = "sync",         code = 0xE627, xMin = 160 },
	{ name = "undo",         code = 0xE166, xMin = 160 },
	{ name = "redo",         code = 0xE15A, xMin = 160 },
	{ name = "save",         code = 0xE161, xMin = 120 },
	{ name = "visibility",   code = 0xE8F4, xMin =  40 },
	{ name = "lock",         code = 0xE897, xMin = 160 },
	{ name = "info",         code = 0xE88E, xMin =  80 },
	{ name = "help",         code = 0xE887, xMin =  80 },
	{ name = "warning",      code = 0xE002, xMin =  40 },
	{ name = "star",         code = 0xE838, xMin =  80 },
	{ name = "favorite",     code = 0xE87D, xMin =  80 },
	{ name = "home",         code = 0xE88A, xMin = 160 },
	{ name = "folder",       code = 0xE2C7, xMin =  80 },
	{ name = "palette",      code = 0xE3B7, xMin =  80 },
	{ name = "tune",         code = 0xE429, xMin = 120 },
	{ name = "build",        code = 0xE869, xMin = 120 },
	{ name = "timer",        code = 0xE425, xMin = 120 },
	{ name = "bolt",         code = 0xEA0B, xMin = 160 },
	{ name = "layers",       code = 0xE53B, xMin = 120 },
	{ name = "dashboard",    code = 0xE871, xMin = 120 },
	{ name = "grid_view",    code = 0xE9B0, xMin = 120 },
	{ name = "list",         code = 0xE896, xMin = 120 },
	{ name = "view_kanban",  code = 0xEB7F, xMin = 120 },
	{ name = "check_box",    code = 0xE834, xMin = 120 },
	{ name = "radio_on",     code = 0xE837, xMin =  80 },
	{ name = "text_fields",  code = 0xE262, xMin =  80 },
	{ name = "format_size",  code = 0xE245, xMin =  80 },
	{ name = "circle",       code = 0xEF4A, xMin =  80 },
	{ name = "square",       code = 0xEB36, xMin = 120 },
}

local fontObjects, fontCount = {}, 0
local function GetFont(size)
	local font = fontObjects[size]
	if not font then
		fontCount = fontCount + 1
		font = CreateFont("KL_ICON_TEST_FONT_" .. fontCount)
		font:SetFont(FONT.path, size, "")
		font:SetTextColor(1, 1, 1, 1)
		fontObjects[size] = font
	end
	return font
end

local function IsBearingWhole(glyph, size)
	return (glyph.xMin * size) % UPM == 0
end

-- Even sizes get the two pixels straddling the center, odd sizes get the center pixel
local function CreateGuide(parent, size, vertical)
	local tex   = parent:CreateTexture(nil, "OVERLAY")
	local thick = 2 - size % 2
	local start = floor((size - thick) / 2)
	tex:SetColorTexture(0, 0.6, 0, 0.5)
	if vertical then
		tex:SetPoint("TOPLEFT",    start, 0)
		tex:SetPoint("BOTTOMLEFT", start, 0)
		tex:SetWidth(thick)
	else
		tex:SetPoint("TOPLEFT",  0, -start)
		tex:SetPoint("TOPRIGHT", 0, -start)
		tex:SetHeight(thick)
	end
	return tex
end

function IconTest4.PlaceIcon(button)
	local fontSize = Util.SameParity(button.boxSize, button.size)
	local xOffset, yOffset = Util.CenterIcon(FONT, button.boxSize, button.boxSize, fontSize)
	button.fontSize = fontSize

	button:SetNormalFontObject(GetFont(fontSize))
	button:SetText(Util.Utf8(button.glyph.code))

	local fs = button:GetFontString()
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", xOffset, yOffset)
end

local function CreateButton(parent, glyph, size, x, y)
	local boxSize = size + inset

	local button = CreateFrame("Button", nil, parent)
	button:SetSize(boxSize, boxSize)
	button:SetPoint("TOPLEFT", x, -y)
	button.glyph   = glyph
	button.size    = size
	button.boxSize = boxSize
	button.dirty   = not IsBearingWhole(glyph, size)

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	button.Background = bg

	IconTest4.PlaceIcon(button)

	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 1)
	button.GuideX = CreateGuide(overlay, boxSize, true)
	button.GuideY = CreateGuide(overlay, boxSize, false)

	local function SetHover(on)
		local shade = on and 0.7 or 0.4
		if button.dirty then
			bg:SetColorTexture(shade, 0, 0, 1)
		else
			bg:SetColorTexture(0, 0, shade, 1)
		end
	end
	button:SetScript("OnEnter", function() SetHover(true) end)
	button:SetScript("OnLeave", function() SetHover(false) end)
	button:SetScript("OnClick", function(self)
		print(format("IconTest4 %s %dpx: font %d, box %d, bearing %.3f, string %.2f x %.2f",
			self.glyph.name, self.size, self.fontSize, self.boxSize,
			self.glyph.xMin * self.fontSize / UPM,
			self:GetFontString():GetStringWidth(), self:GetFontString():GetStringHeight()))
	end)
	SetHover(false)
	return button
end

local function CreateLabel(parent, text, fontSize, x, y, width, justify)
	local label = parent:CreateFontString(nil, "OVERLAY")
	label:SetFont(GameFontHighlight:GetFont(), fontSize, "")
	label:SetTextColor(1, 1, 1, 0.8)
	label:SetJustifyH(justify)
	label:SetPoint("TOPLEFT", x, -y)
	label:SetWidth(width)
	label:SetText(text)
	return label
end

function IconTest4.Load()
	local maxBox   = 0
	local cellSize = 0
	for _, size in ipairs(sizes) do
		maxBox   = max(maxBox, size + inset)
		cellSize = cellSize + size + inset + gap
	end
	cellSize = cellSize - gap

	local xPitch = cellSize + gap * 2
	local yPitch = maxBox + header.labels + gap
	local rows   = ceil(#glyphs / columns)
	local top    = pad + header.title + header.labels
	local width  = pad * 2 + columns * xPitch
	local height = top + rows * yPitch + pad

	local Root = CreateFrame("Frame", "KL_ICON_TEST4", UIParent)
	Root:SetSize(width, height)
	Root:SetFrameStrata("DIALOG")
	Root:SetClampedToScreen(true)
	Root:SetMovable(true)
	Root:EnableMouse(true)
	Root:RegisterForDrag("LeftButton")
	Root:SetScript("OnDragStart", Root.StartMoving)
	Root:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x = Round(self:GetLeft())
		local y = Round(self:GetBottom())
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	end)

	local bg = Root:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 1)

	CreateLabel(Root, TITLE, 12, pad, pad, width - pad * 2, "LEFT")
	for iColumn = 1, columns do
		local x = pad + (iColumn - 1) * xPitch + gap
		for _, size in ipairs(sizes) do
			CreateLabel(Root, size, 11, x, pad + header.title, size + inset, "CENTER")
			x = x + size + inset + gap
		end
	end

	IconTest4.buttons = {}
	for iGlyph, glyph in ipairs(glyphs) do
		local iColumn = (iGlyph - 1) % columns
		local iRow    = floor((iGlyph - 1) / columns)
		local cellX   = pad + iColumn * xPitch + gap
		local cellY   = top + iRow * yPitch

		local x = cellX
		for _, size in ipairs(sizes) do
			local y = cellY + floor((maxBox - (size + inset)) / 2)
			table.insert(IconTest4.buttons, CreateButton(Root, glyph, size, x, y))
			x = x + size + inset + gap
		end
		CreateLabel(Root, glyph.name, 10, cellX, cellY + maxBox + 2, cellSize, "CENTER")
	end

	IconTest4.Root   = Root
	IconTest4.guides = true
	IconTest4.RefreshScale()
end

-- Root units are physical pixels, so it has to be anchored at a whole pixel offset from a corner
-- that is itself on the grid. Centering on UIParent lands it on a fraction and shifts every child.
function IconTest4.RefreshScale()
	local factor = PixelUtil.GetPixelToUIUnitFactor()
	local Root   = IconTest4.Root

	-- UIParent is still settling during login, so a scale derived from it can land wrong. Correct
	-- against what actually took effect instead of trusting the parent's scale at this instant.
	Root:SetScale(factor / UIParent:GetEffectiveScale())
	local scale = Root:GetEffectiveScale()
	if scale ~= factor then
		Root:SetScale(Root:GetScale() * factor / scale)
	end

	Root:ClearAllPoints()
	Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", position.x, -position.y)
end

-- The harness has to prove it is on the grid before anything it shows means anything. Coordinates
-- are converted to physical pixels first, because a frame's own units are only pixels when its
-- scale came out right, and float error means whole pixels never land exactly on an integer.
local EPSILON = 0.01

function IconTest4.Verify()
	local Root   = IconTest4.Root
	local factor = PixelUtil.GetPixelToUIUnitFactor()
	local scale  = Root:GetEffectiveScale()

	local function Pixels(value) return value * scale / factor end
	local function Error(value)  local f = value % 1 return min(f, 1 - f) end

	print(format("IconTest4 scale %.9f, want %.9f, delta %.3e %s",
		scale, factor, scale - factor, abs(scale - factor) < 1e-6 and "ok" or "WRONG"))

	local worst, worstName = 0, "Root"
	local function Check(name, frame)
		local error = max(Error(Pixels(frame:GetLeft())), Error(Pixels(frame:GetBottom())))
		if error > worst then worst, worstName = error, name end
	end

	Check("Root", Root)
	for _, button in ipairs(IconTest4.buttons) do
		Check(format("%s %dpx", button.glyph.name, button.size), button)
	end

	print(format("IconTest4 worst offset %.4f px (%s) %s",
		worst, worstName, worst < EPSILON and "on grid" or "OFF GRID"))
end

function IconTest4.Toggle()
	IconTest4.Root:SetShown(not IconTest4.Root:IsShown())
end

function IconTest4.ToggleGuides()
	IconTest4.guides = not IconTest4.guides
	for _, button in ipairs(IconTest4.buttons) do
		button.GuideX:SetShown(IconTest4.guides)
		button.GuideY:SetShown(IconTest4.guides)
	end
end

-- grid 24 rounds every size that isn't a multiple of 24, grid 12 leaves 36 alone
function IconTest4.SetGrid(grid)
	FONT.grid = grid
	for _, button in ipairs(IconTest4.buttons) do
		IconTest4.PlaceIcon(button)
	end
end

IconTest4.Load()

local events = CreateFrame("Frame")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
	IconTest4.RefreshScale()
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent(event)
		C_Timer.After(0, IconTest4.Verify)
	end
end)
