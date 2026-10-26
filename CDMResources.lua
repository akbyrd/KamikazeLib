local Kami = select(2, ...)
local Res = {}
Kami.CDM.Resources = Res

local CDM    = Kami.CDM
local Config = Kami.Config
local Media  = Kami.Media
local Util   = Kami.Util
local LSM    = LibStub("LibSharedMedia-3.0")

function Res.Init()
	Res.cfgTree = Config.Create()

	Config.AddNode(Res.cfgTree, nil, "Default",
		{
			xPos  = Config.Size("0px"),
			yPos  = Config.Size("-365px"),
			xSize = Config.Size("514px"),
			ySize = Config.Size("26px"),

			barTexture      = Config.Texture("statusbar", "ElvUI Norm", "Solid"),
			backgroundColor = Config.Color("80000000"),
			borderColor     = Config.Color("FF000000"),
			borderSize      = Config.Size("1ui"),

			textEnabled = Config.Bool(true),
			textColor   = Config.Color("FFFFFFFF"),
			textSize    = Config.Size("78%"),
			textYOffset = Config.Size("1px"),

			markers     = Config.Table({ RAGE = Config.Number(70) }),
			markerColor = Config.Color("FF000000"),
			markerSize  = Config.Size("1px"),

			predictionColor = Config.Color("80000000"),
		})

	Config.AddNode(Res.cfgTree, nil, "PowerColors",
		{
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
			SKYRIDING      = Config.Color("FF0EAAC2"),
			THRILL         = Config.Color("FFE67E22"),
		})

	Config.AddNode(Res.cfgTree, "PowerColors", "ElvUIPowerColors",
		{
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

			sequences = Config.Table({
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

	Res.handlers = {}
	Res.eventFrame = CreateFrame("Frame")
	Res.eventFrame:SetParentKey("Kami.CDM.Resources.Event")
	Res.eventFrame:SetScript("OnEvent",        Res.DispatchEvent)
	Res.RegisterUnitEvent("UNIT_DISPLAYPOWER",     Res.UNIT_DISPLAYPOWER,     "player", "vehicle", "pet")
	Res.RegisterUnitEvent("UNIT_MAXPOWER",         Res.UNIT_MAXPOWER,         "player", "vehicle", "pet")
	Res.RegisterUnitEvent("UNIT_POWER_FREQUENT",   Res.UNIT_POWER_FREQUENT,   "player", "vehicle", "pet")
	Res.RegisterUnitEvent("UNIT_SPELLCAST_START",  Res.UNIT_SPELLCAST_START,  "player", "vehicle", "pet")
	Res.RegisterUnitEvent("UNIT_SPELLCAST_STOP",   Res.UNIT_SPELLCAST_STOP,   "player", "vehicle", "pet")
	Res.RegisterUnitEvent("UNIT_SPELLCAST_FAILED", Res.UNIT_SPELLCAST_FAILED, "player", "vehicle", "pet")
	Res.RegisterUnitEvent("UNIT_ENTERED_VEHICLE",  Res.UNIT_ENTERED_VEHICLE,  "player")

	Res.cfg             = Config.GetBranch(Res.cfgTree, "Default")
	Res.cfgPowerColors  = Config.GetBranch(Res.cfgTree, "ElvUIPowerColors")
	Res.predictedCost   = 0
	Res.textConfig      = {
		config = CreateAbbreviateConfig({
			{ breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 1e3, abbreviation = "K", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
		})
	}

	-- NOTE: Hack to allow division and rounding of secret numbers
	local function AddBP(t, bp, sd)
		table.insert(t, { breakpoint = bp, abbreviation = "%", significandDivisor = sd, fractionDivisor = 1, abbreviationIsGlobal = false })
	end
	local breakpoints    = {}
	local speedToPercent = BASE_MOVEMENT_SPEED / 100
	local speedPercent   = 210.5
	AddBP(breakpoints, speedPercent * speedToPercent, speedToPercent * (1 - 1e-6))
	while speedPercent > 0.5 do
		speedPercent = speedPercent / 1.05
		AddBP(breakpoints, speedPercent * speedToPercent, speedToPercent / (1 + 0.5 / speedPercent))
	end
	AddBP(breakpoints, 0, speedToPercent)
	Res.speedTextConfig = { breakpointData = breakpoints }

	Res.Root = CreateFrame("Frame", nil, UIParent)
	Res.Root:SetParentKey("Kami.CDM.Resources.Root")

	Res.Bar = CreateFrame("StatusBar", nil, Res.Root)
	Res.Bar:SetParentKey("Bar")
	Res.Bar:SetClipsChildren(true)

	Res.Prediction = Res.Bar:CreateTexture(nil, "ARTWORK", nil, 1)
	Res.Prediction:SetParentKey("Prediction")

	Res.Marker = Res.Bar:CreateTexture(nil, "OVERLAY")
	Res.Marker:SetParentKey("Marker")

	-- TODO: This needs a fallback
	local typeface = LSM:Fetch("font", "Homespun")
	Res.PowerFont = CreateFont("Kami.CDM.Resources.PowerFont")
	Res.PowerFont:SetFont(typeface, 18, "OUTLINE, MONOCHROME")

	Res.Text = Res.Bar:CreateFontString(nil, "OVERLAY")
	Res.Text:SetParentKey("Text")
	Res.Text:SetFontObject(Res.PowerFont)

	Res.Background = Res.Root:CreateTexture(nil, "BACKGROUND")
	Res.Background:SetParentKey("Background")
	Res.Background:SetAllPoints()

	Res.Border = Res.Root:CreateTexture(nil, "OVERLAY")
	Res.Border:SetParentKey("Border")
	Res.Border:SetAllPoints()
	Res.Border:SetTexture(Media.Border.texture, "CLAMP", "CLAMP", "NEAREST")
	Res.Border:SetTextureSliceMargins(1, 1, 1, 1)

	Res.Rebuild()
end

function Res.Update()
	-- NOTE: Only enabled when skyriding
	Res.RefreshCurrentPower()
end

function Res.Rebuild()
	Res.RefreshScale()
	Res.RefreshConfig()
	Res.RefreshLayout()
	Res.RefreshUnit()
	Res.RefreshPowerSource()
	Res.RefreshPowerType()
	Res.RefreshPowerColor()
	Res.RefreshMaxPower()
	Res.RefreshMarker()
	Res.RefreshPredictionCost()
	Res.RefreshPrediction()
	Res.RefreshCurrentPower()
end

function Res.RefreshUnit()
	local barIndex, barUnit = CDM.GetActionBarOverride()
	Res.barIndex = barIndex
	Res.unit     = barUnit or "player"
end

function Res.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Res.Root:SetScale(pixelsToUI)

	Config.RefreshValues(Res.cfgTree, pixelsToUI)
end

function Res.RefreshConfig()
	Res.Bar:SetStatusBarTexture(Res.cfg.barTexture)
	Res.Prediction:SetColorTexture(Res.cfg.predictionColor:GetRGBA())
	Res.Prediction:SetPoint("TOPRIGHT",    Res.Bar:GetStatusBarTexture(), "TOPRIGHT")
	Res.Prediction:SetPoint("BOTTOMRIGHT", Res.Bar:GetStatusBarTexture(), "BOTTOMRIGHT")
	Res.Background:SetColorTexture(Res.cfg.backgroundColor:GetRGBA())
	Res.Border:SetVertexColor(Res.cfg.borderColor:GetRGBA())
	Res.Text:SetTextColor(Res.cfg.textColor:GetRGBA())
	Res.Text:SetShown(Res.cfg.textEnabled)
	Res.Marker:SetColorTexture(Res.cfg.markerColor:GetRGBA())
end

function Res.RefreshLayout()
	local pxSize, pySize = GetPhysicalScreenSize()

	-- TODO: Handle relative sizes
	local cfg         = Res.cfg
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
	Res.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
	Res.Root:SetSize(xSize, ySize)

	Res.Bar:SetPoint("TOPLEFT",      borderSize, -borderSize)
	Res.Bar:SetPoint("BOTTOMRIGHT", -borderSize,  borderSize)
	Util.SetSliceScale(Res.Border, borderSize)

	local yFillSize = ySize - 2*borderSize
	Res.Marker:SetSize(markerSize, yFillSize)

	-- NOTE: Since we can't the know the width of the power text we can't guarantee pixel perfect
	-- text. If the parity of the bar and the text is not the same the text will be on a half pixel
	-- boundary.
	Res.PowerFont:SetFontHeight(textSize)
	Res.Text:SetPoint("CENTER", 0.25, textYOffset + 0.25)
end

function Res.RefreshPowerSource()
	if Res.barIndex == CDM.db.Misc.SkyridingBarIndex then
		Res.GetPowerType    = Res.GetPowerType_Skyriding
		Res.GetMaxPower     = Res.GetMaxPower_Skyriding
		Res.GetCurrentPower = Res.GetCurrentPower_Skyriding
		Res.eventFrame:SetScript("OnUpdate", Res.Update)
		Res.RegisterUnitEvent("UNIT_AURA", Res.UNIT_AURA, "player")
	else
		local useAlternate = Res.barIndex ~= nil and Res.unit == "player"
		Res.GetPowerType    = useAlternate and Res.GetPowerType_Alternate or UnitPowerType
		Res.GetMaxPower     = UnitPowerMax
		Res.GetCurrentPower = UnitPower
		Res.eventFrame:SetScript("OnUpdate", nil)
		Res.eventFrame:UnregisterEvent("UNIT_AURA")
	end
end

function Res.RefreshMaxPower()
	local maxPower = Res.GetMaxPower(Res.unit, Res.powerType)
	Res.maxPower = max(maxPower, 1)
	Res.Bar:SetMinMaxValues(0, maxPower)
	Res.Root:SetShown(maxPower > 0)

	if Res.powerToken == "SKYRIDING" then
		Res.formatPower = Res.FormatPower_Skyriding
	else
		Res.formatPower = maxPower >= 1000 and Res.AbbreviatePower or C_StringUtil.TruncateWhenZero
	end
end

function Res.RefreshMarker()
	local cfg         = Res.cfg
	local markerValue = cfg.markers[Res.powerToken]
	local xSize       = Res.Bar:GetWidth()
	local xPos        = Round((markerValue or 0) / Res.maxPower * xSize)
	Res.Marker:SetPoint("TOPLEFT", xPos, 0)
	Res.Marker:SetShown(markerValue ~= nil)
end

function Res.RefreshPredictionCost()
	Res.predictedCost = 0

	local spellID = select(9, UnitCastingInfo(Res.unit))
	if spellID then
		Res.UNIT_SPELLCAST_START(Res.unit, nil, spellID)
	end
end

function Res.RefreshPrediction()
	local xSize = Round(Res.predictedCost / Res.maxPower * Res.Bar:GetWidth())
	Res.Prediction:SetWidth(xSize)
	Res.Prediction:SetShown(xSize > 0)
end

function Res.RefreshCurrentPower()
	local power = Res.GetCurrentPower(Res.unit, Res.powerType)
	Res.Bar:SetValue(power)

	local powerText = Res.formatPower(power)
	Res.Text:SetText(powerText)
end

function Res.RefreshPowerType()
	local type, token, r, g, b = Res.GetPowerType(Res.unit)
	Res.powerType  = type
	Res.powerToken = token
	Res.powerColor = Res.cfgPowerColors[token] or CreateColor(r or 1, g or 1, b or 1)
end

function Res.RefreshPowerColor()
	local color = Res.powerColor
	if Res.powerToken == "SKYRIDING" then
		local thrill = C_UnitAuras.GetPlayerAuraBySpellID(CDM.db.Misc.ThrillOfTheSkies)
		if thrill then color = Res.cfgPowerColors.THRILL end
	end

	Res.Bar:SetStatusBarColor(color:GetRGBA())
end

function Res.AbbreviatePower(power)
	return AbbreviateNumbers(power, Res.textConfig)
end

function Res.GetPowerType_Skyriding(unit)
	local type  = nil
	local token = "SKYRIDING"
	return type, token
end

function Res.GetPowerType_Alternate(unit)
	local type  = Enum.PowerType.Alternate
	local token = "ALTERNATE"
	return type, token
end

function Res.GetMaxPower_Skyriding(unit, powerType)
	return 100 -- yd/s
end

function Res.GetCurrentPower_Skyriding(unit, powerType)
	local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
	if isGliding then
		return forwardSpeed
	else
		local currentSpeed = GetUnitSpeed("player")
		return currentSpeed
	end
end

function Res.FormatPower_Skyriding(power)
	return AbbreviateNumbers(power, Res.speedTextConfig)
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function Res.RegisterEvent(event, func)
	Res.eventFrame:RegisterEvent(event)
	Res.handlers[event] = func
end

function Res.RegisterUnitEvent(event, func, ...)
	Res.eventFrame:RegisterUnitEvent(event, ...)
	Res.handlers[event] = func
end

function Res.DispatchEvent(frame, event, ...)
	local func = Res.handlers[event]
	func(...)
end

function Res.OnScaleChanged()
	Res.RefreshScale()
	Res.RefreshLayout()
	Res.RefreshMarker()
	Res.RefreshPrediction()
end

function Res.OnActionBarChanged()
	local barIndex = CDM.GetActionBarOverride()
	if barIndex ~= Res.barIndex then
		Res.Rebuild()
	end
end

function Res.UNIT_AURA()
	Res.RefreshPowerColor()
end

function Res.UNIT_DISPLAYPOWER(unit)
	if unit == Res.unit then
		Res.Rebuild()
	end
end

function Res.UNIT_ENTERED_VEHICLE(unit, showVehicleFrame)
	Res.Rebuild()
end

function Res.UNIT_MAXPOWER(unit)
	if unit == Res.unit then
		Res.RefreshMaxPower()
		Res.RefreshMarker()
		Res.RefreshPrediction()
	end
end

function Res.UNIT_POWER_FREQUENT(unit)
	if unit == Res.unit then
		Res.RefreshCurrentPower()
	end
end

function Res.UNIT_SPELLCAST_START(unit, castGUID, spellID)
	if unit == Res.unit then
		local costs = C_Spell.GetSpellPowerCost(spellID)
		if costs then
			for iCost, costInfo in ipairs(costs) do
				if costInfo.type == Res.powerType and (costInfo.requiredAuraID == 0 or costInfo.hasRequiredAura) then
					Res.predictedCost = costInfo.cost
					Res.RefreshPrediction()
					break
				end
			end
		end
	end
end

function Res.UNIT_SPELLCAST_STOP(unit)
	if unit == Res.unit then
		Res.predictedCost = 0
		Res.RefreshPrediction()
	end
end

function Res.UNIT_SPELLCAST_FAILED(unit)
	if unit == Res.unit then
		Res.predictedCost = 0
		Res.RefreshPrediction()
	end
end
