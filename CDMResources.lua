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

			markers     = Config.Table({ RAGE = Config.Number(70) }),
			markerColor = Config.Color("FF000000"),
			markerSize  = Config.Size("1px"),

			predictionColor = Config.Color("80000000"),

			powerColors = Config.Table({
				MANA           = Config.Color("FF0000FF"),
				RAGE           = Config.Color("FFFF0000"),
				FOCUS          = Config.Color("FFFF8040"),
				ENERGY         = Config.Color("FFFFFF00"),
				COMBO_POINTS   = Config.Color("FFFFF569"),
				RUNES          = Config.Color("FF808080"),
				RUNIC_POWER    = Config.Color("FF00D1FF"),
				SOUL_SHARDS    = Config.Color("FF80528C"),
				LUNAR_POWER    = Config.Color("FF4D85E6"),
				HOLY_POWER     = Config.Color("FFF2E699"),
				MAELSTROM      = Config.Color("FF0080FF"),
				INSANITY       = Config.Color("FF6600CC"),
				CHI            = Config.Color("FFB5FFEB"),
				ARCANE_CHARGES = Config.Color("FF1A1AFA"),
				FURY           = Config.Color("FFC942FD"),
				PAIN           = Config.Color("FFFF9C00"),
				ESSENCE        = Config.Color("FF5AF3FC"),
			}),

			elvUIPowerColors = Config.Table({
				MANA           = Config.Color("FF4F73A1"),
				RAGE           = Config.Color("FFC74040"),
				ENERGY         = Config.Color("FFFFF569"),
				COMBO_POINTS   = Config.Color("FFCFCF4F"),
				RUNES          = Config.Color("FFCC66FF"),
				SOUL_SHARDS    = Config.Color("FF8040CC"),
				HOLY_POWER     = Config.Color("FFE3E00F"),
				CHI            = Config.Color("FF94BA5C"),
				ARCANE_CHARGES = Config.Color("FF0066FF"),
				ESSENCE        = Config.Color("FF2BF0D6"),
				ALT_POWER      = Config.Color("FF3366CC"),
			}),

			elvUIPointColors = Config.Table({
				COMBO_POINTS = Config.Table({
					Config.Color("FFBF4F4F"),
					Config.Color("FFC78F4F"),
					Config.Color("FFCFCF4F"),
					Config.Color("FF8FC74F"),
					Config.Color("FF6EC24F"),
					Config.Color("FF4FBF4F"),
					Config.Color("FF5CCF8A"),
				}),
				RUNES        = Config.Table({
					Config.Color("FFFF4040"),
					Config.Color("FF40FFFF"),
					Config.Color("FF40FF40"),
					Config.Color("FFCC66FF"),
				}),
				CHI          = Config.Table({
					Config.Color("FFB5C252"),
					Config.Color("FF94BA5C"),
					Config.Color("FF7DB563"),
					Config.Color("FF63B06B"),
					Config.Color("FF45A875"),
					Config.Color("FF24A180"),
				}),
				ESSENCE      = Config.Table({
					Config.Color("FF1AEBFF"),
					Config.Color("FF2BF0D6"),
					Config.Color("FF3DF5B0"),
					Config.Color("FF4FFA87"),
					Config.Color("FF57FC73"),
					Config.Color("FF61FF61"),
				}),
			}),
		})

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Resources.Event")
	CDM.eventFrame:SetScript("OnEvent",        CDM.DispatchEvent)
	CDM.RegisterEvent("PLAYER_ENTERING_WORLD", CDM.Init)
end

function CDM.Init()
	CDM.RegisterEvent("PLAYER_ENTERING_WORLD",     CDM.PLAYER_ENTERING_WORLD)
	CDM.RegisterEvent("UI_SCALE_CHANGED",          CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",      CDM.OnScaleChanged)
	CDM.RegisterUnitEvent("UNIT_DISPLAYPOWER",     CDM.UNIT_DISPLAYPOWER,     "player", "vehicle")
	CDM.RegisterUnitEvent("UNIT_MAXPOWER",         CDM.UNIT_MAXPOWER,         "player", "vehicle")
	CDM.RegisterUnitEvent("UNIT_POWER_FREQUENT",   CDM.UNIT_POWER_FREQUENT,   "player", "vehicle")
	CDM.RegisterUnitEvent("UNIT_SPELLCAST_START",  CDM.UNIT_SPELLCAST_START,  "player", "vehicle")
	CDM.RegisterUnitEvent("UNIT_SPELLCAST_STOP",   CDM.UNIT_SPELLCAST_STOP,   "player", "vehicle")
	CDM.RegisterUnitEvent("UNIT_SPELLCAST_FAILED", CDM.UNIT_SPELLCAST_FAILED, "player", "vehicle")
	CDM.RegisterUnitEvent("UNIT_ENTERED_VEHICLE",  CDM.UNIT_ENTERED_VEHICLE,  "player")
	CDM.RegisterUnitEvent("UNIT_EXITED_VEHICLE",   CDM.UNIT_EXITED_VEHICLE,   "player")
	hooksecurefunc(UIParent, "SetScale",           CDM.OnScaleChanged)

	CDM.cfg           = Config.GetBranch(CDM.cfgTree, "Default")
	CDM.unit          = "player"
	CDM.predictedCost = 0
	CDM.textConfig    = {
		config = CreateAbbreviateConfig({
			{ breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 1e3, abbreviation = "K", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
		})
	}

	CDM.Root = CreateFrame("Frame", nil, UIParent)
	CDM.Root:SetParentKey("Kami.CDM.Resources.Root")

	CDM.Bar = CreateFrame("StatusBar", nil, CDM.Root)
	CDM.Bar:SetParentKey("Bar")
	CDM.Bar:SetClipsChildren(true)

	CDM.Prediction = CDM.Bar:CreateTexture(nil, "ARTWORK", nil, 1)
	CDM.Prediction:SetParentKey("Prediction")

	CDM.Marker = CDM.Bar:CreateTexture(nil, "OVERLAY")
	CDM.Marker:SetParentKey("Marker")

	-- TODO: This needs a fallback
	local typeface = LSM:Fetch("font", "Homespun")
	CDM.PowerFont = CreateFont("Kami.CDM.Resources.PowerFont")
	CDM.PowerFont:SetFont(typeface, 18, "OUTLINE, MONOCHROME")

	CDM.Text = CDM.Bar:CreateFontString(nil, "OVERLAY")
	CDM.Text:SetParentKey("Text")
	CDM.Text:SetFontObject(CDM.PowerFont)

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
	CDM.RefreshPrediction()
	CDM.RefreshCurrentPower()
end

function CDM.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	CDM.Root:SetScale(pixelsToUI)

	Config.RefreshValues(CDM.cfgTree, pixelsToUI)
end

function CDM.RefreshConfig()
	CDM.Bar:SetStatusBarTexture(CDM.cfg.barTexture)
	CDM.Prediction:SetColorTexture(CDM.cfg.predictionColor:GetRGBA())
	CDM.Prediction:SetPoint("TOPRIGHT",    CDM.Bar:GetStatusBarTexture(), "TOPRIGHT")
	CDM.Prediction:SetPoint("BOTTOMRIGHT", CDM.Bar:GetStatusBarTexture(), "BOTTOMRIGHT")
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
	local maxPower = UnitPowerMax(CDM.unit, CDM.powerType)
	CDM.Bar:SetMinMaxValues(0, maxPower)
	CDM.Root:SetShown(maxPower > 0)

	CDM.maxPower = max(maxPower, 1)
	CDM.formatPower = maxPower >= 1000 and CDM.AbbreviatePower or C_StringUtil.TruncateWhenZero
end

function CDM.RefreshMarker()
	local cfg         = CDM.cfg
	local markerValue = cfg.markers[CDM.powerToken]
	local xSize       = CDM.Bar:GetWidth()
	local xPos        = Round((markerValue or 0) / CDM.maxPower * xSize)
	CDM.Marker:SetPoint("TOPLEFT", xPos, 0)
	CDM.Marker:SetShown(markerValue ~= nil)
end

function CDM.RefreshPrediction()
	local xSize = Round(CDM.predictedCost / CDM.maxPower * CDM.Bar:GetWidth())
	CDM.Prediction:SetWidth(xSize)
	CDM.Prediction:SetShown(xSize > 0)
end

function CDM.RefreshCurrentPower()
	local power = UnitPower(CDM.unit, CDM.powerType)
	CDM.Bar:SetValue(power)

	local powerText = CDM.formatPower(power)
	CDM.Text:SetText(powerText)
end

function CDM.RefreshPowerType()
	local type, token, r, g, b = UnitPowerType(CDM.unit)
	CDM.powerType  = type
	CDM.powerToken = token

	-- TODO: Simplify this by having elvUIPowerColors inherit from powerColors
	local powerColor = CDM.cfg.elvUIPowerColors[token] or CDM.cfg.powerColors[token]
	if powerColor then
		CDM.Bar:SetStatusBarColor(powerColor:GetRGBA())
	else
		CDM.Bar:SetStatusBarColor(r, g, b)
	end
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

function CDM.RegisterUnitEvent(event, func, ...)
	CDM.eventFrame:RegisterUnitEvent(event, ...)
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
	CDM.RefreshPrediction()
end

function CDM.PLAYER_ENTERING_WORLD()
	CDM.Rebuild()
end

function CDM.UNIT_DISPLAYPOWER(unit)
	if unit == CDM.unit then
		CDM.Rebuild()
	end
end

function CDM.UNIT_ENTERED_VEHICLE(unit, showVehicleFrame)
	CDM.unit = showVehicleFrame and "vehicle" or "player"
	CDM.Rebuild()
end

function CDM.UNIT_EXITED_VEHICLE()
	CDM.unit = "player"
	CDM.Rebuild()
end

function CDM.UNIT_MAXPOWER(unit)
	if unit == CDM.unit then
		CDM.RefreshMaxPower()
		CDM.RefreshMarker()
		CDM.RefreshPrediction()
	end
end

function CDM.UNIT_POWER_FREQUENT(unit)
	if unit == CDM.unit then
		CDM.RefreshCurrentPower()
	end
end

function CDM.UNIT_SPELLCAST_START(unit, castGUID, spellID)
	if unit == CDM.unit then
		local costs = C_Spell.GetSpellPowerCost(spellID)
		if costs then
			for iCost, costInfo in ipairs(costs) do
				if costInfo.type == CDM.powerType and (costInfo.requiredAuraID == 0 or costInfo.hasRequiredAura) then
					CDM.predictedCost = costInfo.cost
					CDM.RefreshPrediction()
					break
				end
			end
		end
	end
end

function CDM.UNIT_SPELLCAST_STOP(unit)
	if unit == CDM.unit then
		CDM.predictedCost = 0
		CDM.RefreshPrediction()
	end
end

function CDM.UNIT_SPELLCAST_FAILED(unit)
	if unit == CDM.unit then
		CDM.predictedCost = 0
		CDM.RefreshPrediction()
	end
end

----------------------------------------------------------------------------------------------------
-- File Load

CDM.Load()
