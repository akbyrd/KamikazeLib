local Kami = select(2, ...)
local CDM = {}
Kami.CDM.Resources = CDM

local Config = Kami.Config
local Util   = Kami.Util
local LSM    = LibStub("LibSharedMedia-3.0")

function CDM.Load()
	CDM.cfgTree = Config.Create()

	Config.AddNode(CDM.cfgTree, nil, "Default",
		{
			xPos  = Config.Size("0px"),
			yPos  = Config.Size("-365px"),
			xSize = Config.Size("514px"),
			ySize = Config.Size("26px"),

			barTexture      = Config.Texture("statusbar", "ElvUI Norm", "Solid"),
			backgroundColor = Config.Color("80000000"),
			borderColor     = Config.Color("FF000000"),
			borderSize      = Config.Size("1ui"),

			textEnabled = Config.Bool(false),
			textColor   = Config.Color("FFFFFFFF"),
			textSize    = Config.Size("78%"),
			textYOffset = Config.Size("1px"),

			markerValue = Config.Number(70),
			markerColor = Config.Color("FF000000"),
			markerSize  = Config.Size("1px"),

			powerColors = Config.Table({
				MANA           = "FF0000FF",
				RAGE           = "FFFF0000",
				FOCUS          = "FFFF8040",
				ENERGY         = "FFFFFF00",
				COMBO_POINTS   = "FFFFF569",
				RUNES          = "FF808080",
				RUNIC_POWER    = "FF00D1FF",
				SOUL_SHARDS    = "FF80528C",
				LUNAR_POWER    = "FF4D85E6",
				HOLY_POWER     = "FFF2E699",
				MAELSTROM      = "FF0080FF",
				INSANITY       = "FF6600CC",
				CHI            = "FFB5FFEB",
				ARCANE_CHARGES = "FF1A1AFA",
				FURY           = "FFC942FD",
				PAIN           = "FFFF9C00",
				ESSENCE        = "FF5AF3FC",
			}),

			elvUIPowerColors = Config.Table({
				MANA           = "FF4F73A1",
				RAGE           = "FFC74040",
				ENERGY         = "FFFFF569",
				COMBO_POINTS   = "FFCFCF4F",
				RUNES          = "FFCC66FF",
				SOUL_SHARDS    = "FF8040CC",
				HOLY_POWER     = "FFE3E00F",
				CHI            = "FF94BA5C",
				ARCANE_CHARGES = "FF0066FF",
				ESSENCE        = "FF2BF0D6",
				ALT_POWER      = "FF3366CC",
			}),

			elvUIPointColors = Config.Table({
				COMBO_POINTS = { "FFBF4F4F", "FFC78F4F", "FFCFCF4F", "FF8FC74F", "FF6EC24F", "FF4FBF4F", "FF5CCF8A" },
				RUNES        = { "FFFF4040", "FF40FFFF", "FF40FF40", "FFCC66FF" },
				CHI          = { "FFB5C252", "FF94BA5C", "FF7DB563", "FF63B06B", "FF45A875", "FF24A180" },
				ESSENCE      = { "FF1AEBFF", "FF2BF0D6", "FF3DF5B0", "FF4FFA87", "FF57FC73", "FF61FF61" },
			}),
		})

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Resources.Event")
	CDM.eventFrame:SetScript("OnEvent",                    CDM.DispatchEvent)
	CDM.RegisterEvent("PLAYER_ENTERING_WORLD",             CDM.Init)
end

function CDM.Init()
	CDM.RegisterEvent("PLAYER_ENTERING_WORLD",             CDM.PLAYER_ENTERING_WORLD)
	CDM.RegisterEvent("UI_SCALE_CHANGED",                  CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",              CDM.OnScaleChanged)
	CDM.RegisterUnitEvent("UNIT_DISPLAYPOWER",   "player", CDM.UNIT_DISPLAYPOWER)
	CDM.RegisterUnitEvent("UNIT_MAXPOWER",       "player", CDM.UNIT_MAXPOWER)
	CDM.RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", CDM.UNIT_POWER_FREQUENT)
	hooksecurefunc(UIParent, "SetScale",                   CDM.OnScaleChanged)

	CDM.cfg  = Config.GetBranch(CDM.cfgTree, "Default")
	CDM.Root = CreateFrame("Frame", nil, UIParent)
	CDM.Root:SetParentKey("Kami.CDM.Resources.Root")

	CDM.Bar = CreateFrame("StatusBar", nil, CDM.Root)
	CDM.Bar:SetParentKey("Bar")

	CDM.Marker = CDM.Bar:CreateTexture(nil, "OVERLAY")
	CDM.Marker:SetParentKey("Marker")

	local typeface = LSM:Fetch("font", "Homespun")
	CDM.PowerFont = CreateFont("Kami.CDM.Resources.PowerFont")
	CDM.PowerFont:SetFont(typeface, 18, "OUTLINE, MONOCHROME")

	CDM.Text = CDM.Bar:CreateFontString(nil, "OVERLAY")
	CDM.Text:SetParentKey("Text")
	CDM.Text:SetFontObject(CDM.PowerFont)
	CDM.textConfig = {
		config = CreateAbbreviateConfig({
			{ breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 1e3, abbreviation = "K", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
		})
	}

	CDM.Background = CDM.Root:CreateTexture(nil, "BACKGROUND")
	CDM.Background:SetParentKey("Background")
	CDM.Background:SetAllPoints()

	CDM.Border = CDM.Root:CreateTexture(nil, "OVERLAY")
	CDM.Border:SetParentKey("Border")
	CDM.Border:SetAllPoints()
	CDM.Border:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	CDM.Border:SetTextureSliceMargins(1, 1, 1, 1)

	CDM.Rebuild()
end

function CDM.Rebuild()
	CDM.RefreshScale()
	CDM.RefreshConfig()
	CDM.RefreshLayout()
	CDM.RefreshPowerType()
	CDM.RefreshMaxPower()
	CDM.RefreshMarker()
	CDM.RefreshCurrentPower()
end

function CDM.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	CDM.Root:SetScale(pixelsToUI)

	Config.RefreshValues(CDM.cfgTree, pixelsToUI)
end

function CDM.RefreshConfig()
	CDM.Bar:SetStatusBarTexture(CDM.cfg.barTexture)
	CDM.Background:SetColorTexture(CDM.cfg.backgroundColor:GetRGBA())
	CDM.Border:SetVertexColor(CDM.cfg.borderColor:GetRGBA())
	CDM.Text:SetTextColor(CDM.cfg.textColor:GetRGBA())
	CDM.Text:SetShown(CDM.cfg.textEnabled)
	CDM.Marker:SetColorTexture(CDM.cfg.markerColor:GetRGBA())
end

function CDM.RefreshLayout()
	local pxSize, pySize = GetPhysicalScreenSize()

	-- TODO: Handle relative sizes
	local cfg         = CDM.cfg
	local xPos        = Round(cfg.xPos        + cfg.xPosRel        * 0)
	local yPos        = Round(cfg.yPos        + cfg.yPosRel        * 0)
	local xSize       = Round(cfg.xSize       + cfg.xSizeRel       * 0)
	local ySize       = Round(cfg.ySize       + cfg.ySizeRel       * 0)
	local borderSize  = Round(cfg.borderSize  + cfg.borderSizeRel  * 0)
	local textSize    = Round(cfg.textSize    + cfg.textSizeRel    * ySize)
	local textYOffset = Round(cfg.textYOffset + cfg.textYOffsetRel * ySize)
	local markerSize  = Round(cfg.markerSize  + cfg.markerSizeRel  * 0)

	local vxPos = xPos + Round((pxSize - xSize) / 2)
	local vyPos = yPos - Round(pySize / 2) + ySize
	CDM.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
	CDM.Root:SetSize(xSize, ySize)

	CDM.Bar:SetPoint("TOPLEFT",      borderSize, -borderSize)
	CDM.Bar:SetPoint("BOTTOMRIGHT", -borderSize,  borderSize)
	Util.SetSliceScale(CDM.Border, borderSize)

	local yFillSize = ySize - 2*borderSize
	CDM.Marker:SetSize(markerSize, yFillSize)

	-- NOTE: Since we can't the know the width of the power text we can't guarantee pixel perfect
	-- text. If the parity of the bar and the text is not the same the text will be on a half pixel
	-- boundary.
	CDM.PowerFont:SetFontHeight(textSize)
	CDM.Text:SetPoint("CENTER", 0.25, textYOffset + 0.25)
end

function CDM.RefreshMaxPower()
	local maxPower = UnitPowerMax("player", CDM.powerType)
	CDM.maxPower = maxPower
	CDM.Bar:SetMinMaxValues(0, maxPower)
	CDM.formatPower = maxPower >= 1000 and CDM.AbbreviatePower or C_StringUtil.TruncateWhenZero
end

function CDM.RefreshMarker()
	local cfg   = CDM.cfg
	local xSize = CDM.Bar:GetWidth()
	local xPos  = Round(cfg.markerValue / CDM.maxPower * xSize)
	CDM.Marker:SetPoint("TOPLEFT", xPos, 0)
	CDM.Marker:SetShown(cfg.markerValue <= CDM.maxPower)
end

function CDM.RefreshCurrentPower()
	local power = UnitPower("player", CDM.powerType)
	CDM.Bar:SetValue(power)

	local powerText = CDM.formatPower(power)
	CDM.Text:SetText(powerText)
end

function CDM.RefreshPowerType()
	local type, token = UnitPowerType("player")
	CDM.powerType  = type
	CDM.powerToken = token

	-- TODO: Simplify this when Config supports nested values
	local powerColor = CDM.cfg.elvUIPowerColors[token] or CDM.cfg.powerColors[token]
	CDM.Bar:SetStatusBarColor(CreateColorFromHexString(powerColor):GetRGBA())
end

function CDM.AbbreviatePower(power)
	return AbbreviateNumbers(power, CDM.textConfig)
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.RegisterUnitEvent(event, unit, func)
	CDM.eventFrame:RegisterUnitEvent(event, unit)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

function CDM.OnScaleChanged()
	CDM.RefreshScale()
	CDM.RefreshLayout()
	CDM.RefreshMarker()
end

function CDM.PLAYER_ENTERING_WORLD()
	CDM.Rebuild()
end

function CDM.UNIT_DISPLAYPOWER(unit)
	CDM.Rebuild()
end

function CDM.UNIT_MAXPOWER(unit, powerToken)
	if powerToken == CDM.powerToken then
		CDM.RefreshMaxPower()
		CDM.RefreshMarker()
	end
end

function CDM.UNIT_POWER_FREQUENT(unit, powerToken)
	if powerToken == CDM.powerToken then
		CDM.RefreshCurrentPower()
	end
end

----------------------------------------------------------------------------------------------------
-- File Load

CDM.Load()

-- TODO:
-- Cost prediction
-- Test possession / vehicles
