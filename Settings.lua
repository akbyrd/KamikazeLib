local Kami = select(2, ...)
local Settings = {}
Kami.Settings = Settings

local Util = Kami.Util

function Settings.Load()
	local rootSize   = 700
	local className  = select(2, UnitClass("player"))
	local classColor = C_ClassColor.GetClassColor(className)
	--local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	local pixelsToUI = 0.59259256904508 -- TODO: Handle this properly

	local function UISize(base, exponent)
		local x = base * 1.618^exponent
		x = x + 1
		return Round(x - (x % 2)) -- DEBUG: Round down to even
	end

	--local PADDING       = Scale(PANEL_WIDTH, -7)
	--local CONTENT_WIDTH = PANEL_WIDTH - 2 * PADDING
	--local CONTROL_WIDTH = Scale(CONTENT_WIDTH, -1)
	--local ROW_HEIGHT    = Scale(CONTENT_WIDTH, -6)
	--local GUTTER        = Scale(ROW_HEIGHT, -4)
	--local WIDGET_HEIGHT = ROW_HEIGHT - 2 * GUTTER
	--local INSET         = Scale(GUTTER, -2)

	local cfg = {
		xSize             = UISize(rootSize, 0),
		ySize             = UISize(rootSize, 1),
		borderSize        = 1,
		borderColor       = CreateColorFromHexString("0FFFFFFF"),
		backgroundTexture = "Interface\\Buttons\\WHITE8x8",
		iconFont          = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf",
		iconSize          = UISize(rootSize, -7),
		backgroundColor   = CreateColorFromHexString("FA1C1C1C"),
		paddingSize       = UISize(rootSize, -7),
		closeSize         = UISize(rootSize, -6),
		closeColor        = CreateColorFromHexString("80E64D4D"),
		iconOffsetY       = -0.073,
		buttonColor       = CreateColorFromHexString("08FFFFFF"),
	}

	local IconFont = CreateFont("KL_ICON_FONT")
	--IconFont:SetFont(cfg.iconFont, cfg.iconSize, "")
	IconFont:SetFont(cfg.iconFont, cfg.closeSize, "MONOCHROME")
	IconFont:SetTextColor(1, 1, 1, 0.35)

	local IconFontHover = CreateFont("KL_ICON_FONT_HOVER")
	IconFontHover:CopyFontObject(IconFont)
	IconFontHover:SetTextColor(1, 1, 1, 1)

	local Root = CreateFrame("Frame", "KL_SETTINGS", UIParent, "BackdropTemplate")
	Root:SetSize(cfg.xSize, cfg.ySize)
	Root:SetScale(pixelsToUI)
	Root:SetPoint("CENTER")
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
	Root:SetBackdrop({
		bgFile   = cfg.backgroundTexture,
		edgeFile = cfg.backgroundTexture,
		edgeSize = cfg.borderSize })
	Root:SetBackdropColor(cfg.backgroundColor:GetRGBA())
	Root:SetBackdropBorderColor(cfg.borderColor:GetRGBA())
	Root:Hide()

	local Close = CreateFrame("Button", nil, Root)
	Close:SetParentKey("Close")
	Close:SetSize(cfg.closeSize, cfg.closeSize)
	Close:SetPoint("TOPRIGHT", -cfg.paddingSize, -cfg.paddingSize)
	Close:SetNormalTexture(cfg.backgroundTexture)
	Close:GetNormalTexture():SetVertexColor(cfg.buttonColor:GetRGBA())
	Close:SetHighlightTexture(cfg.backgroundTexture, "BLEND")
	Close:GetHighlightTexture():SetVertexColor(cfg.closeColor:GetRGBA())
	Close:SetNormalFontObject(IconFont)
	Close:SetHighlightFontObject(IconFontHover)
	Close:SetText(Util.Utf8(0xE5CD))
	Close:GetFontString():SetSize(cfg.closeSize, cfg.closeSize)
	Close:GetFontString():SetPoint("CENTER", 0, cfg.iconOffsetY * cfg.closeSize)
	Close:GetFontString():SetJustifyH("LEFT")
	Close:GetFontString():SetJustifyV("MIDDLE")
	Close:SetPushedTextOffset(0, 0)
	--Close:GetFontString():SetPoint("CENTER", -1, -1.5)
	Close:RegisterForClicks("LeftButtonDown")
	Close:SetScript("OnClick", function() Root:Hide() end)

	Settings.Root = Root
	Settings.Close = Close
end

function Settings.Toggle()
	Settings.Root:SetShown(not Settings.Root:IsShown())
end

Settings.Load()
Settings.Toggle()

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	C_Timer.After(0, function()
		DandersFrames:ToggleGUI()
		SlashCmdList.SOURCERY("")
	end)
end)
