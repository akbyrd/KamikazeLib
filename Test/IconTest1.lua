local Kami = select(2, ...)
local IconTest1 = {}
Kami.IconTest1 = IconTest1

local Util = Kami.Util

-- WoW rasterizes the em square at the font height in pixels with no hinting and puts the baseline
-- round(height * ascent / (ascent + descent)) below the top of the line. The glyph quad starts at
-- ceil(bearing) while the bitmap starts at floor(bearing), or round(bearing) for MONOCHROME, so
-- ink lands right of the outline by the difference. The string is ceil(bearing) + bitmap width
-- wide. The string's position is floored on both axes and float error can land an integer just
-- below itself, so the string is anchored half a pixel right and up. Bounds are outline bounds
-- in font units.
local FONT    = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf"
local FLAGS   = ""
local UPM     = 960
local ASCENT  = 1056
local DESCENT = 96

local glyphs = {
	{ name = "close",       code = 0xE5CD, xMin = 200, xMax = 760, yMin = 200, yMax = 760 },
	{ name = "settings",    code = 0xE8B8, xMin =  78, xMax = 882, yMin =  80, yMax = 880 },
	{ name = "add",         code = 0xE145, xMin = 200, xMax = 760, yMin = 200, yMax = 760 },
	{ name = "expand_more", code = 0xE5CF, xMin = 240, xMax = 720, yMin = 345, yMax = 641 },
	{ name = "check_box",   code = 0xE834, xMin = 120, xMax = 840, yMin = 120, yMax = 840 },
	{ name = "close_small", code = 0xF508, xMin = 280, xMax = 679, yMin = 280, yMax = 679 },
	{ name = "view_kanban", code = 0xEB7F, xMin = 120, xMax = 840, yMin = 120, yMax = 840 },
	{ name = "arrow_back",  code = 0xE5C4, xMin = 160, xMax = 800, yMin = 160, yMax = 800 },
	{ name = "a",           code = 0x41,   xMin =   0, xMax = 957, yMin =   0, yMax = 687 },
}

local sizes    = { 12, 16, 20, 24, 25, 36, 40, 48, 64 }
local fraction = 1
local pad      = 8
local header   = { title = 76, labels = 18 }
local position = { x = 8, y = 8 }

local TITLE = "Exact: ink bounds from the TTF and the engine's placement rules put the ink center on the button center"

-- Font units to pixels in FreeType's 26.6 fixed point
local function Pixels(units, fontSize)
	return floor(units * fontSize * 64 / UPM + 0.5) / 64
end

-- Ink bounds in pixels, relative to the top left of an auto-sized font string
function IconTest1.InkRect(glyph, fontSize, flags)
	local xMin      = Pixels(glyph.xMin, fontSize)
	local xMax      = Pixels(glyph.xMax, fontSize)
	local yMin      = Pixels(glyph.yMin, fontSize)
	local yMax      = Pixels(glyph.yMax, fontSize)
	local baseline  = floor(fontSize * ASCENT / (ASCENT + DESCENT) + 0.5)
	local mono      = flags == "MONOCHROME"
	local bitmapMin = mono and floor(xMin + 0.5) or floor(xMin)
	local bitmapMax = mono and floor(xMax + 0.5) or ceil(xMax)
	local shift     = ceil(xMin) - bitmapMin

	return {
		left         = xMin + shift,
		right        = xMax + shift,
		top          = baseline - yMax,
		bottom       = baseline - yMin,
		stringWidth  = ceil(xMin) + bitmapMax - bitmapMin,
		stringHeight = fontSize,
	}
end

-- Glyphs symmetric about the em square only land on the pixel grid when the font size has the
-- same parity as the button size
function IconTest1.FontSize(buttonSize, fraction)
	local fontSize = Round(buttonSize * fraction)
	if fontSize % 2 ~= buttonSize % 2 then
		fontSize = fontSize + 1
	end
	return fontSize
end

function IconTest1.PlaceIcon(fontString, glyph, fontSize, width, height)
	local flags   = glyph.flags or FLAGS
	local rect    = IconTest1.InkRect(glyph, fontSize, flags)
	local xOffset = Round(width  / 2 - (rect.left + rect.right) / 2)
	local yOffset = Round(height / 2 - (rect.top  + rect.bottom) / 2)

	fontString:SetFont(FONT, fontSize, flags)
	fontString:SetJustifyH("LEFT")
	fontString:SetJustifyV("TOP")
	fontString:SetWordWrap(false)
	fontString:SetText(Util.Utf8(glyph.code))
	fontString:ClearAllPoints()
	fontString:SetPoint("TOPLEFT", xOffset + 0.5, -yOffset + 0.5)
	return rect, xOffset, yOffset
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

local function CreateButton(parent, glyph, size, x, y)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	button:SetPoint("TOPLEFT", x, -y)

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0.45, 1)

	local text = button:CreateFontString(nil, "OVERLAY")
	text:SetTextColor(1, 1, 1, 1)

	button.size     = size
	button.glyph    = glyph
	button.fontSize = IconTest1.FontSize(size, fraction)
	button.rect, button.xOffset, button.yOffset = IconTest1.PlaceIcon(text, glyph, button.fontSize, size, size)

	button.Background = bg
	button.Text       = text
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 1)
	button.GuideX     = CreateGuide(overlay, size, true)
	button.GuideY     = CreateGuide(overlay, size, false)

	button:SetScript("OnEnter", function(self) self.Background:SetColorTexture(0, 0, 0.7,  1) end)
	button:SetScript("OnLeave", function(self) self.Background:SetColorTexture(0, 0, 0.45, 1) end)
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

function IconTest1.Load()
	local maxSize = 0
	local width   = pad
	for _, size in ipairs(sizes) do
		maxSize = max(maxSize, size)
		width   = width + size + pad
	end
	local pitch  = maxSize + pad
	local top    = pad + header.title + header.labels
	local height = top + #glyphs * pitch

	local Root = CreateFrame("Frame", "KL_ICON_TEST1", UIParent)
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

	CreateLabel(Root, TITLE, 18, pad, pad, width - 2 * pad, "LEFT")
	local x = pad
	for iSize, size in ipairs(sizes) do
		CreateLabel(Root, size, 14, x - pad / 2, pad + header.title, size + pad, "CENTER")
		x = x + size + pad
	end

	IconTest1.buttons = {}
	for iGlyph, glyph in ipairs(glyphs) do
		local rowY = top + (iGlyph - 1) * pitch
		x = pad
		for iSize, size in ipairs(sizes) do
			local y = rowY + floor((maxSize - size) / 2)
			table.insert(IconTest1.buttons, CreateButton(Root, glyph, size, x, y))
			x = x + size + pad
		end
	end

	IconTest1.Root   = Root
	IconTest1.guides = true
	IconTest1.RefreshScale()
end

function IconTest1.RefreshScale()
	local Root = IconTest1.Root
	Root:SetScale(PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale())
	Root:ClearAllPoints()
	Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", position.x, -position.y)
end

function IconTest1.Toggle()
	IconTest1.Root:SetShown(not IconTest1.Root:IsShown())
end

function IconTest1.ToggleGuides()
	IconTest1.guides = not IconTest1.guides
	for _, button in ipairs(IconTest1.buttons) do
		button.GuideX:SetShown(IconTest1.guides)
		button.GuideY:SetShown(IconTest1.guides)
	end
end

-- Predicted/measured, in pixels
function IconTest1.Dump()
	for _, button in ipairs(IconTest1.buttons) do
		if button.glyph == glyphs[1] then
			local text = button.Text
			print(format("IconTest1 %s %dpx: font %d, offset %d,%d, width %d/%.2f, height %d/%.2f, font height %.2f, line height %.2f",
				button.glyph.name, button.size, button.fontSize, button.xOffset, button.yOffset,
				button.rect.stringWidth,  text:GetStringWidth(),
				button.rect.stringHeight, text:GetStringHeight(),
				text:GetFontHeight(), text:GetLineHeight()))
		end
	end
end

IconTest1.Load()

local events = CreateFrame("Frame")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(self, event)
	IconTest1.RefreshScale()
end)
