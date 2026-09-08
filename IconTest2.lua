local Kami = select(2, ...)
local IconTest2 = {}
Kami.IconTest2 = IconTest2

local Util = Kami.Util

-- Icon centered on its canvas with no per-glyph data. Regular weight puts most bearings on the
-- 24 grid, so the bearing shift is assumed to be zero at multiples of 24 px and one elsewhere.
-- Off by one pixel when that guess is wrong and by the design offset for glyphs whose ink is not
-- centered on the canvas.
local FONT    = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf"
local FLAGS   = ""
local UPM     = 960
local ASCENT  = 1056
local DESCENT = 96

local glyphs = {
	{ name = "close",       code = 0xE5CD },
	{ name = "settings",    code = 0xE8B8 },
	{ name = "add",         code = 0xE145 },
	{ name = "expand_more", code = 0xE5CF },
	{ name = "check_box",   code = 0xE834 },
	{ name = "close_small", code = 0xF508 },
	{ name = "view_kanban", code = 0xEB7F },
	{ name = "arrow_back",  code = 0xE5C4 },
	{ name = "a",           code = 0x41   },
}

local sizes    = { 12, 16, 20, 24, 25, 36, 40, 48, 64 }
local fraction = 1
local pad      = 8
local header   = { title = 76, labels = 18 }

local TITLE = "Approximation: no glyph data, em canvas centered, bearing shift guessed from the size"

function IconTest2.FontSize(buttonSize, fraction)
	local fontSize = Round(buttonSize * fraction)
	if fontSize % 2 ~= buttonSize % 2 then
		fontSize = fontSize + 1
	end
	return fontSize
end

function IconTest2.PlaceIcon(fontString, code, fontSize, width, height, flags)
	local baseline = floor(fontSize * ASCENT / (ASCENT + DESCENT) + 0.5)
	local shift    = fontSize % 24 == 0 and 0 or 1
	local xOffset  = Round(width  / 2 - fontSize / 2 - shift)
	local yOffset  = Round(height / 2 - baseline + fontSize / 2)

	fontString:SetFont(FONT, fontSize, flags or FLAGS)
	fontString:SetJustifyH("LEFT")
	fontString:SetJustifyV("TOP")
	fontString:SetWordWrap(false)
	fontString:SetText(Util.Utf8(code))
	fontString:ClearAllPoints()
	fontString:SetPoint("TOPLEFT", xOffset + 0.5, -yOffset + 0.5)
	return xOffset, yOffset
end

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
	button.fontSize = IconTest2.FontSize(size, fraction)
	button.xOffset, button.yOffset = IconTest2.PlaceIcon(text, glyph.code, button.fontSize, size, size, glyph.flags)

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

function IconTest2.Load()
	local maxSize = 0
	local width   = pad
	for _, size in ipairs(sizes) do
		maxSize = max(maxSize, size)
		width   = width + size + pad
	end
	local pitch  = maxSize + pad
	local top    = pad + header.title + header.labels
	local height = top + #glyphs * pitch

	local Root = CreateFrame("Frame", "KL_ICON_TEST2", UIParent)
	Root:SetSize(width, height)
	Root:SetFrameStrata("DIALOG")

	local bg = Root:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 1)

	CreateLabel(Root, TITLE, 18, pad, pad, width - 2 * pad, "LEFT")
	local x = pad
	for iSize, size in ipairs(sizes) do
		CreateLabel(Root, size, 14, x - pad / 2, pad + header.title, size + pad, "CENTER")
		x = x + size + pad
	end

	IconTest2.buttons = {}
	for iGlyph, glyph in ipairs(glyphs) do
		local rowY = top + (iGlyph - 1) * pitch
		x = pad
		for iSize, size in ipairs(sizes) do
			local y = rowY + floor((maxSize - size) / 2)
			table.insert(IconTest2.buttons, CreateButton(Root, glyph, size, x, y))
			x = x + size + pad
		end
	end

	IconTest2.Root   = Root
	IconTest2.guides = true
	IconTest2.RefreshScale()
end

function IconTest2.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	local Root = IconTest2.Root
	Root:SetScale(pixelsToUI)
	Root:ClearAllPoints()
	Root:SetPoint("TOPLEFT", Kami.IconTest.Root, "TOPRIGHT", pad, 0)
end

function IconTest2.Toggle()
	IconTest2.Root:SetShown(not IconTest2.Root:IsShown())
end

function IconTest2.ToggleGuides()
	IconTest2.guides = not IconTest2.guides
	for _, button in ipairs(IconTest2.buttons) do
		button.GuideX:SetShown(IconTest2.guides)
		button.GuideY:SetShown(IconTest2.guides)
	end
end

IconTest2.Load()

local events = CreateFrame("Frame")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
	IconTest2.RefreshScale()
end)
