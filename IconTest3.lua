local Kami = select(2, ...)
local IconTest3 = {}
Kami.IconTest3 = IconTest3

local Util = Kami.Util

local sizes  = { 12, 16, 20, 24, 25, 36, 40, 48, 64 }
local pad    = 8
local header = { title = 76, labels = 18 }

local TITLES = {
	"Client: string sized to the button, anchored CENTER, justified CENTER, no offset",
	"Client: string sized to the button, anchored CENTER, justified LEFT, offset -0.073 * size",
	"Client: string sized to the button, anchored CENTER, justified LEFT, offset -0.08 * size + 0.5",
}

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

function IconTest3.Load()
	local cfg = {
		backgroundTexture = "Interface\\Buttons\\WHITE8x8",
		iconFont          = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf",
		backgroundColor   = CreateColor(0, 0, 0, 1),
		iconOffsetY       = -0.073,
		buttonColor       = CreateColor(0, 0, 0.45, 1),
	}

	local maxSize    = 0
	local blockWidth = pad
	for _, size in ipairs(sizes) do
		maxSize    = max(maxSize, size)
		blockWidth = blockWidth + size + pad
	end
	local pitch = maxSize + pad
	local top   = pad + header.title + header.labels

	-- Throwaway: every glyph at once, crosshair on each. Per size, three rows:
	-- centred by the client, then left-justified with the em offset, then left-justified with the two-term fit
	local glyphs = { 0xE5CD, 0xE8B8, 0xE145, 0xE5CF, 0xE834, 0xF508, 0xEB7F, 0xE5C4, 0x41 }
	local function Rows(size)
		return {
			{ justify = "CENTER", offset = 0 },
			{ justify = "LEFT",   offset = cfg.iconOffsetY * size },
			{ justify = "LEFT",   offset = (-0.08 * size) + 0.5 },
		}
	end
	local fonts = {}
	local function Font(size)
		local font = fonts[size]
		if not font then
			font = CreateFont("KL_ICON_FONT_TEST_" .. size)
			font:SetFont(cfg.iconFont, size, "")
			font:SetTextColor(1, 1, 1, 1)
			fonts[size] = font
		end
		return font
	end
	local function CreateGlyphButton(parent, size, variant, codepoint, x, y)
		local font   = Font(size)
		local button = CreateFrame("Button", nil, parent)
		button:SetSize(size, size)
		button:SetPoint("TOPLEFT", x, -y)
		button:SetNormalTexture(cfg.backgroundTexture)
		button:GetNormalTexture():SetVertexColor(cfg.buttonColor:GetRGBA())
		button:SetNormalFontObject(font)
		button:SetText(Util.Utf8(codepoint))
		button:GetFontString():SetSize(size, size)
		button:GetFontString():SetPoint("CENTER", 0, variant.offset)
		button:GetFontString():SetJustifyH(variant.justify)
		button:GetFontString():SetJustifyV("MIDDLE")
		local overlay = CreateFrame("Frame", nil, button)
		overlay:SetAllPoints()
		overlay:SetFrameLevel(button:GetFrameLevel() + 1)
		local horizontal = overlay:CreateTexture(nil, "OVERLAY")
		horizontal:SetColorTexture(0, 0.6, 0, 0.5)
		horizontal:SetSize(size, 2)
		horizontal:SetPoint("CENTER")
		local vertical = overlay:CreateTexture(nil, "OVERLAY")
		vertical:SetColorTexture(0, 0.6, 0, 0.5)
		vertical:SetSize(2, size)
		vertical:SetPoint("CENTER")
	end

	IconTest3.Roots = {}
	for iRow = 1, #Rows(maxSize) do
		local Root = CreateFrame("Frame", "KL_ICON_TEST3_" .. iRow, UIParent)
		Root:SetSize(blockWidth, top + #glyphs * pitch)
		Root:SetFrameStrata("DIALOG")

		local bg = Root:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(cfg.backgroundColor:GetRGBA())

		CreateLabel(Root, TITLES[iRow], 18, pad, pad, blockWidth - 2 * pad, "LEFT")
		local x = pad
		for iSize, size in ipairs(sizes) do
			CreateLabel(Root, size, 14, x - pad / 2, pad + header.title, size + pad, "CENTER")
			x = x + size + pad
		end
		for iGlyph, codepoint in ipairs(glyphs) do
			x = pad
			for iSize, size in ipairs(sizes) do
				local y = top + (iGlyph - 1) * pitch + floor((maxSize - size) / 2)
				CreateGlyphButton(Root, size, Rows(size)[iRow], codepoint, x, y)
				x = x + size + pad
			end
		end
		IconTest3.Roots[iRow] = Root
	end

	IconTest3.RefreshScale()
end

-- Chain to the right of test 2, then have test 1 center the whole row
function IconTest3.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	local previous = Kami.IconTest2.Root
	local width    = Kami.IconTest.Root:GetWidth() + pad + previous:GetWidth()
	for _, Root in ipairs(IconTest3.Roots) do
		Root:SetScale(pixelsToUI)
		Root:ClearAllPoints()
		Root:SetPoint("TOPLEFT", previous, "TOPRIGHT", pad, 0)
		previous = Root
		width    = width + pad + Root:GetWidth()
	end
	Kami.IconTest.groupWidth = width
	Kami.IconTest.RefreshScale()
end

function IconTest3.Toggle()
	for _, Root in ipairs(IconTest3.Roots) do
		Root:SetShown(not Root:IsShown())
	end
end

IconTest3.Load()

local events = CreateFrame("Frame")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
	IconTest3.RefreshScale()
end)
