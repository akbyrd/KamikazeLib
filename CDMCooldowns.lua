local Kami = select(2, ...)
local CDM = {}
Kami.CDM.Cooldowns = CDM

local Config    = Kami.Config
local PixelAnts = Kami.PixelAnts
local Util      = Kami.Util
local LSM       = LibStub("LibSharedMedia-3.0")

function CDM.Load()
	CDM.savedVars = KLSavedVars.CDM
	CDM.charVars  = KLCharVars.CDM
	-- TODO: Rename profile?
	CDM.savedVars.profile = CDM.savedVars.profile or {}

	local db = {
		WARRIOR = {
			MortalStrike = 12294,
			Overpower    = 7384,
			Execute      = 163201,
			Cleave       = 845,
			Slam         = 1464,
			HeroicStrike = 1269383,
			Bladestorm   = 227847,

			MasterOfWarfareProc   = 1269391,
			MasterOfWarfareBuff   = 1269394,
			Opportunist           = 456120,
			CollateralDamage      = 334783,
			ImminentDemise        = 445606,
			WindingUp             = 1300670,
			Executioner           = 445584,
			ExecutionersPrecision = 386633,
		}
	}

	CDM.cfgTree = Config.Create()

	Config.AddNode(CDM.cfgTree, nil, "Default",
		{
			xPos = Config.Size("0ui"),
			yPos = Config.Size("0ui"),

			iconSize   = Config.Size("50ui"),
			iconZoom   = Config.Number(0.08),
			iconAspect = Config.Number(1.65),
			iconPad    = Config.Size("1ui"),

			usableColor   = Config.Color("FFFFFFFF"),
			noManaColor   = Config.Color("FF8080FF"),
			noRangeColor  = Config.Color("FFA32626"),
			noUsableColor = Config.Color("FF666666"),

			borderColor = Config.Color("FF000000"),
			borderSize  = Config.Size("1ui"),

			cdShowTime = Config.Bool(true),
			cdFontSize = Config.Size("70%"),

			chargeFontSize = Config.Size("50%"),
			chargeXOffset  = Config.Size("0ui"),
			chargeYOffset  = Config.Size("0.5ui"),

			pressColor  = Config.Color("40FFFFFF"),
			queuedColor = Config.Color("4DE6CC1A"),

			assistColor = Config.Color("FF3399F2"),
			assistSize  = Config.Size("1ui"),

			procSize     = Config.Size("1ui"),
			procInset    = Config.Size("0ui"),
			procColor    = Config.Color("FFFFFF00"),
			procSpeed    = Config.Number(0.30),
			procSegments = Config.Number(2),
			procDuty     = Config.Number(0.6),

			rowLimit  = Config.Number(6),
			rowLimits = Config.Table({}),

			overrideSize   = Config.Size("4px"),
			overrideTimers = Config.Table({
				WARRIOR = {
					--[db.WARRIOR.Slam] = { overrideSpellID = db.WARRIOR.HeroicStrike, duration = 15 },
				},
			}),

			empowerSize       = Config.Size("7px"),
			empowerGapSize    = Config.Size("3px"),
			empowerBorderSize = Config.Size("2px"),
			empowerBuffs      = Config.Table({
				WARRIOR = {
					[db.WARRIOR.Overpower]    = db.WARRIOR.Opportunist,
					[db.WARRIOR.Cleave]       = db.WARRIOR.CollateralDamage,
					[db.WARRIOR.Bladestorm]   = db.WARRIOR.ImminentDemise,
					[db.WARRIOR.Slam]         = db.WARRIOR.WindingUp,
					[db.WARRIOR.Execute]      = db.WARRIOR.Executioner,
					[db.WARRIOR.MortalStrike] = db.WARRIOR.ExecutionersPrecision,
				},
			})
		})

	Config.AddNode(CDM.cfgTree, "Default", "Essential",
		{
			yPos = Config.Size("-248ui"),
		})

	Config.AddNode(CDM.cfgTree, "Default", "Utility",
		{
			yPos      = Config.Size("-310ui"),
			iconSize  = Config.Size("30ui"),
			rowLimits = Config.Table({ 4 }),
		})

	for branch, values in pairs(CDM.savedVars.profile) do
		Config.AddNode(CDM.cfgTree, branch, nil, values)
	end

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Cooldowns.Event")
	CDM.eventFrame:SetScript("OnEvent",                              CDM.DispatchEvent)
	CDM.eventFrame:SetScript("OnUpdate",                             CDM.Update)
	CDM.RegisterEvent("UI_SCALE_CHANGED",                            CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",                        CDM.OnScaleChanged)
	CDM.RegisterEvent("SPELL_UPDATE_USABLE",                         CDM.RefreshAllUsable)
	CDM.RegisterEvent("PLAYER_REGEN_ENABLED",                        CDM.PLAYER_REGEN_ENABLED)
	CDM.RegisterEvent("BAG_UPDATE_COOLDOWN",                         CDM.BAG_UPDATE_COOLDOWN)
	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN",                       CDM.SPELL_UPDATE_COOLDOWN)
	CDM.RegisterEvent("SPELL_RANGE_CHECK_UPDATE",                    CDM.SPELL_RANGE_CHECK_UPDATE)
	CDM.RegisterEvent("GLOBAL_MOUSE_DOWN",                           CDM.GLOBAL_MOUSE_DOWN)
	CDM.RegisterEvent("GLOBAL_MOUSE_UP",                             CDM.GLOBAL_MOUSE_UP)
	CDM.RegisterEvent("CURRENT_SPELL_CAST_CHANGED",                  CDM.CURRENT_SPELL_CAST_CHANGED)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",          CDM.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",          CDM.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
	CDM.RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",      CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED)
	CDM.RegisterEvent("SPELL_UPDATE_ICON",                           CDM.SPELL_UPDATE_ICON)
	CDM.RegisterEvent("SPELL_UPDATE_USES",                           CDM.SPELL_UPDATE_USES)
	hooksecurefunc(UIParent, "SetScale",                             CDM.OnScaleChanged)
	hooksecurefunc("SecureActionButton_OnClick",                     CDM.OnClick)
	CVarCallbackRegistry:RegisterCallback("assistedCombatHighlight", CDM.OnAssistChange, CDM)

	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.OnCDMChanged)

	local categoryToName = EnumUtil.GenerateNameTranslation(Enum.CooldownViewerCategory)
	local cdTypeface = LSM:Fetch("font", "PT Sans Narrow")
	local chargeTypeface = LSM:Fetch("font", "Homespun")

	local categories = {
		Enum.CooldownViewerCategory.Essential,
		Enum.CooldownViewerCategory.Utility,
	}

	CDM.viewers = {}
	for index, category in ipairs(categories) do
		local categoryName = categoryToName(category)

		local Root = CreateFrame("Frame", nil, UIParent)
		Root:SetParentKey(("Kami.CDM.Cooldowns.%s.Root"):format(categoryName))

		local cdFontName = ("Kami.CDM.Cooldowns.CDFont.%s"):format(categoryName)
		local cdFont = CreateFont(cdFontName)
		cdFont:SetFont(cdTypeface, 18, "OUTLINE")

		local chargeFontName = ("Kami.CDM.Cooldowns.ChargeFont.%s"):format(categoryName)
		local chargeFont = CreateFont(chargeFontName)
		chargeFont:SetFont(chargeTypeface, 18, "OUTLINE")

		local vState = {
			name        = categoryName,
			cfg         = Config.GetBranch(CDM.cfgTree, categoryName),
			Root        = Root,
			cdFontName  = cdFontName,
			cdFont      = cdFont,
			chargeFont  = chargeFont,
			pool        = {},
			cdvInfos    = {},
			cdFrames    = {},
			maxRowCount = 0,
			rowCounts   = {},
			xSize       = nil,
			ySize       = nil,
		}
		CDM.viewers[category] = vState
	end

	local units = CreateFromMixins(SecondsFormatterMixin)
	units:SetStripIntervalWhitespace(true)

	local mFmt  = units:GetFormatString(SecondsFormatter.Interval.Minutes, SecondsFormatter.Abbreviation.OneLetter, true)
	local hFmt  = units:GetFormatString(SecondsFormatter.Interval.Hours,   SecondsFormatter.Abbreviation.OneLetter, true)
	local dFmt  = units:GetFormatString(SecondsFormatter.Interval.Days,    SecondsFormatter.Abbreviation.OneLetter, true)
	local round = Enum.NumericRuleFormatRounding.Up

	CDM.cdFormatter = C_StringUtil.CreateNumericRuleFormatter()
	CDM.cdFormatter:SetBreakpoints({
		{ threshold = 0,                     format = "%d",                      components = {{ div = 1,                step = 1,   rounding = round }} },
		{ threshold = 99,                    format = mFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_MIN,  step = 0.1, rounding = round }} },
		{ threshold = 2  * SECONDS_PER_MIN,  format = mFmt,                      components = {{ div = SECONDS_PER_MIN,  step = 1,   rounding = round }} },
		{ threshold = 99 * SECONDS_PER_MIN,  format = hFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_HOUR, step = 0.1, rounding = round }} },
		{ threshold = 2  * SECONDS_PER_HOUR, format = hFmt,                      components = {{ div = SECONDS_PER_HOUR, step = 1,   rounding = round }} },
		{ threshold = 1  * SECONDS_PER_DAY,  format = dFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_DAY,  step = 0.1, rounding = round }} },
		{ threshold = 2  * SECONDS_PER_DAY,  format = dFmt,                      components = {{ div = SECONDS_PER_DAY,  step = 1,   rounding = round }} },
	})

	CDM.classToken     = select(2, UnitClass("player"))
	CDM.classColor     = C_ClassColor.GetClassColor(CDM.classToken)
	CDM.spellLookup    = {}
	CDM.categoryLookup = {}
	CDM.categoryIcons  = {
		[4]    = "Interface/ICONS/INV_POTION_114",       -- Combat Potion
		[30]   = "Interface/ICONS/INV_POTION_54",        -- Health Potion
		[1711] = "Interface/ICONS/Warlock_ Healthstone", -- Healthstone
		[2566] = "Interface/ICONS/Warlock_ Bloodstone",  -- Demonic Healthstone
	}
	CDM.mousePresses        = {}
	CDM.spellPresses        = {}
	CDM.pressCounts         = {}
	CDM.refreshAllCooldowns = false

	CDM.Rebuild()
end

function CDM.Update()
	if CDM.refreshAllCooldowns then
		CDM.refreshAllCooldowns = false
		CDM.RefreshAllCooldowns()
	end

	CDM.RefreshAssist()
end

function CDM.Rebuild()
	-- TODO: Attempt to remove this check. Only a couple of places need to be hardened against secrets:
	-- * C_Spell.GetLastCategoryCooldownSource
	-- * C_Spell.GetSpellMaxCumulativeAuraApplications

	-- NOTE: Keys (and certain other content) are restricted the whole time.
	if C_Secrets.ShouldCooldownsBeSecret() then return end

	Kami.CDM.GatherCDs(CDM.viewers)

	CDM.RefreshScale()
	CDM.AssignFrames()
	CDM.RefreshAllConfig()
	CDM.RefreshAllSizes()
	CDM.RefreshAllPositions()
	CDM.RefreshAllCategories()
	CDM.RefreshAllOverrides()
	CDM.RefreshAllCooldowns()
	CDM.RefreshAllIcons()
	CDM.RefreshAllUsable()
	CDM.RefreshAllPress()
	CDM.RefreshAllQueued()
	CDM.RefreshAllProcs()
	CDM.RefreshAssist()
end

function CDM.ConstructFrame(vState)
	local fState = {}
	fState.cfg = vState.cfg
	fState.itemDuration = C_DurationUtil.CreateDuration()

	-- Frame        | Textures/Text          | Purpose
	-- -------------|------------------------|--------
	-- Root         | Border                 | Size, Position
	--   Content    | Icon                   | Inset
	--     Recharge |                        | Cooldown
	--     Cooldown |                        | Cooldown
	--     Overlay  | Press, Queued, Charges | Draw Order
	--     Bling    |                        | Cooldown
	--   Outline    | Assist                 | Draw Order

	fState.Root = CreateFrame("Frame", nil, vState.Root)
	fState.Root:SetParentKey("Root")

	fState.Border = fState.Root:CreateTexture(nil, "OVERLAY")
	fState.Border:SetParentKey("Border")
	fState.Border:SetAllPoints()
	fState.Border:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	fState.Border:SetTextureSliceMargins(1, 1, 1, 1)

	-- BUG: Edge and bling are broken in 12.1 They aren't scaled properly and they don't
	-- clip. They show up as a rotating rectangle. So we manually rescale and clip them.
	fState.Content = CreateFrame("Frame", nil, fState.Root)
	fState.Content:SetParentKey("Content")
	fState.Content:SetPoint("CENTER")
	fState.Content:SetClipsChildren(true)

	fState.Icon = fState.Content:CreateTexture(nil, "ARTWORK")
	fState.Icon:SetParentKey("Icon")
	fState.Icon:SetAllPoints()

	fState.Empower = CreateFrame("AuraContainer", nil, fState.Content, "CustomAuraContainerTemplate")
	fState.Empower:SetParentKey("Empower")
	fState.Empower:SetPoint("BOTTOMLEFT")
	fState.Empower:SetPoint("BOTTOMRIGHT")
	fState.Empower:SetUnit("player")
	fState.Empower:AddAuraSlot(tostring(fState), "HELPFUL",
		{
			initializeFrame = function(button)
				fState.EmpowerButton = button
				fState.EmpowerButton:SetAllPoints()
				fState.EmpowerButton:EnableMouse(false)

				fState.EmpowerBar = CreateFrame("StatusBar", nil, fState.EmpowerButton)

				fState.EmpowerBorder = fState.EmpowerBar:CreateTexture(nil, "BORDER")
				fState.EmpowerBorder:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\PixelAnts.tga", "REPEAT", "REPEAT", "NEAREST")
				fState.EmpowerBorder:SetHorizTile(true)

				fState.EmpowerFill = fState.EmpowerBar:CreateTexture(nil, "ARTWORK")
				fState.EmpowerFill:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\PixelAnts.tga", "REPEAT", "REPEAT", "NEAREST")
				fState.EmpowerFill:SetHorizTile(true)

				-- BUG: This works around a 1-frame flicker. The bar is shown in OnUpdate, but the
				-- layout happens before and is skipped for hidden frames. The first time the bar is
				-- shown it has its default, full width. Next frame it gets resized to the proper width.
				-- So we force a texture to be created and manually position it outside the clipping
				-- range of the icon. The aura container re-anchors it, so our anchors here will get
				-- undone.
				fState.EmpowerFill:ClearAllPoints()
				fState.EmpowerFill:SetPoint("TOPRIGHT",    fState.EmpowerButton, "TOPLEFT")
				fState.EmpowerFill:SetPoint("BOTTOMRIGHT", fState.EmpowerButton, "BOTTOMLEFT")
				fState.EmpowerFill:SetWidth(1)

				fState.EmpowerBar:SetStatusBarTexture(fState.EmpowerFill)
			end,
		})

	fState.Recharge = CreateFrame("Cooldown", nil, fState.Content)
	fState.Recharge:SetParentKey("Recharge")
	fState.Recharge:SetPoint("CENTER")
	fState.Recharge:SetDrawSwipe(false)
	fState.Recharge:SetDrawEdge(true)
	fState.Recharge:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")
	fState.Recharge:SetEdgeColor(0.6, 1, 0, 1)
	fState.Recharge:SetHideCountdownNumbers(true)

	-- NOTE: Cooldown frames hide themselves when they aren't active (and thus textures & children)
	fState.Cooldown = CreateFrame("Cooldown", nil, fState.Content, "CooldownFrameTemplate")
	fState.Cooldown:SetParentKey("Cooldown")
	fState.Cooldown:SetAllPoints()
	fState.Cooldown:SetDrawEdge(false)
	fState.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
	fState.Cooldown:SetDrawBling(false)
	fState.Cooldown:SetCountdownFormatter(CDM.cdFormatter)
	fState.Cooldown:SetCountdownFont(vState.cdFontName)
	fState.Cooldown:SetScript("OnCooldownDone", function() fState.Icon:SetDesaturated(false) end)

	fState.Overlay = CreateFrame("Frame", nil, fState.Content)
	fState.Overlay:SetParentKey("Overlay")
	fState.Overlay:SetAllPoints()

	fState.Press = fState.Overlay:CreateTexture(nil, "OVERLAY", nil, 0)
	fState.Press:SetParentKey("Press")
	fState.Press:SetAllPoints()
	fState.Press:SetBlendMode("ADD")

	fState.Queued = fState.Overlay:CreateTexture(nil, "OVERLAY", nil, 0)
	fState.Queued:SetParentKey("Queued")
	fState.Queued:SetAllPoints()
	fState.Queued:SetBlendMode("ADD")

	fState.Charges = fState.Overlay:CreateFontString(nil, "OVERLAY")
	fState.Charges:SetParentKey("Charges")
	fState.Charges:SetFontObject(vState.chargeFont)

	-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.
	-- Ideally it would be above the Outline / Assist, but it needs to be clipped by Content

	fState.Bling = CreateFrame("Cooldown", nil, fState.Content, "CooldownFrameTemplate")
	fState.Bling:SetParentKey("Bling")
	fState.Bling:ClearAllPoints() -- Template sets points
	fState.Bling:SetPoint("CENTER")
	fState.Bling:SetDrawSwipe(false)
	fState.Bling:SetDrawEdge(false)
	fState.Bling:SetDrawBling(true)
	fState.Bling:SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
	fState.Bling:SetHideCountdownNumbers(true)
	fState.Bling:SetScript("OnCooldownDone", function() fState.hasBling = nil end)

	fState.Outline = CreateFrame("Frame", nil, fState.Root)
	fState.Outline:SetParentKey("Outline")
	fState.Outline:SetAllPoints()

	fState.Assist = fState.Outline:CreateTexture(nil, "OVERLAY", nil, 1)
	fState.Assist:SetParentKey("Assist")
	fState.Assist:SetAllPoints()
	fState.Assist:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	fState.Assist:SetTextureSliceMargins(1, 1, 1, 1)

	-- TODO: Does PixelAnts actually need to create a frame?
	fState.Proc = PixelAnts.Create(fState.Outline)

	fState.Override = CreateFrame("StatusBar", nil, fState.Outline)
	fState.Override:SetParentKey("Override")
	fState.Override:SetFrameLevel(fState.Override:GetParent():GetFrameLevel() + 2)
	fState.Override:SetPoint("BOTTOMLEFT")
	fState.Override:SetPoint("BOTTOMRIGHT")
	fState.Override:SetTimerDuration(C_DurationUtil.CreateDuration(), nil, Enum.StatusBarTimerDirection.RemainingTime)

	fState.OverrideBG = fState.Override:CreateTexture(nil, "BACKGROUND")
	fState.OverrideBG:SetParentKey("Background")
	fState.OverrideBG:SetAllPoints()

	return fState
end

function CDM.EnableFrame(fState, cdvInfo)
	-- NOTE: We don't rebuild "pressed" state here. We don't track pressCount for spells that aren't
	-- on the CDM. So we can't tell if it was already being held when a rebuild occurs. We could
	-- track it, but it could be an override and we always store the base spellID specifically to
	-- avoid dealing with complexity from overrides. So it's not worth handling that edge case.

	fState.baseSpellID   = cdvInfo.spellID
	fState.spellID       = cdvInfo.spellID
	fState.categoryID    = cdvInfo.spellCategoryID
	fState.equipSlot     = cdvInfo.equipSlot
	fState.overrideTimer = fState.cfg.overrideTimers[CDM.classToken][fState.spellID]
	fState.empowerBuff   = fState.cfg.empowerBuffs[CDM.classToken][fState.spellID]

	if fState.empowerBuff then
		-- NOTE: GetSpellMaxCumulativeAuraApplications returns secrets
		fState.empowerMaxStacks = C_Spell.GetSpellMaxCumulativeAuraApplications(fState.empowerBuff)
		fState.empowerMaxStacks = max(1, fState.empowerMaxStacks)

		fState.Empower:SetAuraSlotCandidateFilters(tostring(fState), { includeSpellIDs = { [fState.empowerBuff] = true } })
		fState.EmpowerButton:SetApplicationBar(fState.EmpowerBar, { maxApplications = fState.empowerMaxStacks })
	end

	if fState.categoryID then
		CDM.categoryLookup[fState.categoryID] = fState

	elseif fState.equipSlot then
		-- TODO: Do equipped items ever need a range check?

	elseif fState.spellID then
		C_Spell.EnableSpellRangeCheck(fState.baseSpellID, true)
	end

	fState.Root:Show()
end

function CDM.DisableFrame(fState)
	if fState.baseSpellID and not fState.categoryID then
		C_Spell.EnableSpellRangeCheck(fState.baseSpellID, false)
	end

	fState.Root:Hide()
	fState.Icon:SetTexture(nil)
	fState.Icon:SetDesaturated(false)
	fState.Icon:SetVertexColor(1, 1, 1, 1)
	fState.Recharge:Clear()
	fState.Cooldown:Clear()
	fState.Press:Hide()
	fState.Queued:Hide()
	fState.Charges:SetText("")
	fState.Bling:Clear()
	fState.Assist:Hide()
	fState.Proc:Hide()
	fState.Override:Hide()
	fState.Empower:SetAuraSlotCandidateFilters(tostring(fState), { includeSpellIDs = {} })

	fState.spellID = nil
	fState.baseSpellID = nil
	fState.categoryID = nil
	fState.itemID = nil
	fState.equipSlot = nil
	fState.hasBling = nil
	fState.empowerMaxStacks = 1
end

function CDM.AssignFrames()
	wipe(CDM.spellLookup)
	wipe(CDM.categoryLookup)
	CDM.assistSpellID = nil

	for category, vState in pairs(CDM.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end
		wipe(vState.cdFrames)

		-- Construct new frames (if needed)
		local have = #vState.pool
		local need = #vState.cdvInfos
		for iNeed = have + 1, need do
			local fState = CDM.ConstructFrame(vState)
			-- TODO: Not sure if this is a good idea
			CDM.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end

		-- Enable new frames
		for iInfo, cdvInfo in ipairs(vState.cdvInfos) do
			local fState = table.remove(vState.pool)
			CDM.EnableFrame(fState, cdvInfo)
			table.insert(vState.cdFrames, fState)

			if cdvInfo.spellID then
				CDM.spellLookup[cdvInfo.spellID] = fState
			end
		end

		-- Cache raw counts
		vState.maxRowCount = 0
		wipe(vState.rowCounts)
		local remaining = #vState.cdFrames
		while remaining > 0 do
			local rowLimit = vState.cfg.rowLimits[#vState.rowCounts + 1] or vState.cfg.rowLimit
			local nRow = min(remaining, rowLimit)

			vState.maxRowCount = max(vState.maxRowCount, nRow)
			table.insert(vState.rowCounts, nRow)
			remaining = remaining - nRow
		end
	end
end

function CDM.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	for category, vState in pairs(CDM.viewers) do
		vState.Root:SetScale(pixelsToUI)
	end

	Config.RefreshValues(CDM.cfgTree, pixelsToUI)
end

function CDM.RefreshConfig(fState)
	fState.Border:SetVertexColor(fState.cfg.borderColor:GetRGBA())
	fState.Press:SetColorTexture(fState.cfg.pressColor:GetRGBA())
	fState.Queued:SetColorTexture(fState.cfg.queuedColor:GetRGBA())
	fState.Assist:SetVertexColor(fState.cfg.assistColor:GetRGBA())
	fState.Override:SetColorFill(fState.cfg.procColor:GetRGBA())
	fState.OverrideBG:SetColorTexture(fState.cfg.borderColor:GetRGBA())
	fState.EmpowerBorder:SetVertexColor(fState.cfg.borderColor:GetRGBA())
	fState.EmpowerFill:SetVertexColor(CDM.classColor:GetRGBA())

	fState.Proc:SetConfig(
		nil,
		nil,
		fState.cfg.procColor,
		fState.cfg.procSpeed,
		fState.cfg.procSegments,
		fState.cfg.procDuty)
end

function CDM.RefreshAllConfig()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.RefreshConfig(fState)
		end
	end
end

function CDM.RefreshAllSizes()
	local pxSize, pySize = GetPhysicalScreenSize()

	for category, vState in pairs(CDM.viewers) do
		local cfg               = vState.cfg
		local iconZoom          = cfg.iconZoom
		local iconAspect        = cfg.iconAspect
		local iconSize          = Round(cfg.iconSize          + cfg.iconSizeRel          * pySize)
		local borderSize        = Round(cfg.borderSize        + cfg.borderSizeRel        * iconSize)
		local assistSize        = Round(cfg.assistSize        + cfg.assistSizeRel        * iconSize)
		local procSize          = Round(cfg.procSize          + cfg.procSizeRel          * iconSize)
		local procInset         = Round(cfg.procInset         + cfg.procInsetRel         * iconSize)
		local overrideSize      = Round(cfg.overrideSize      + cfg.overrideSizeRel      * iconSize)
		local empowerSize       = Round(cfg.empowerSize       + cfg.empowerSizeRel       * iconSize)
		local empowerGapSize    = Round(cfg.empowerGapSize    + cfg.empowerGapSizeRel    * iconSize)
		local empowerBorderSize = Round(cfg.empowerBorderSize + cfg.empowerBorderSizeRel * iconSize)

		local xScale, yScale = Util.AspectScale(iconAspect)
		vState.xSize = Round(xScale * iconSize)
		vState.ySize = Round(yScale * iconSize)

		local cxSize   = vState.xSize - 2*borderSize
		local cySize   = vState.ySize - 2*borderSize
		local diagSize = sqrt(cxSize^2 + cySize^2)

		local chargeXOffset  = Round(cfg.chargeXOffset  + cfg.chargeXOffsetRel  * cxSize)
		local chargeYOffset  = Round(cfg.chargeYOffset  + cfg.chargeYOffsetRel  * cySize)
		local cdFontSize     = Round(cfg.cdFontSize     + cfg.cdFontSizeRel     * cySize)
		local chargeFontSize = Round(cfg.chargeFontSize + cfg.chargeFontSizeRel * cySize)

		vState.cdFont:SetFontHeight(cdFontSize)
		vState.chargeFont:SetFontHeight(chargeFontSize)

		for iFrame, fState in ipairs(vState.cdFrames) do
			fState.Root:SetSize(vState.xSize, vState.ySize)
			fState.Content:SetSize(cxSize, cySize)
			fState.Recharge:SetSize(diagSize, diagSize)
			fState.Charges:SetPoint("BOTTOMRIGHT", fState.Content, "BOTTOMRIGHT", chargeXOffset, chargeYOffset)
			fState.Bling:SetSize(diagSize, diagSize)
			fState.Proc:SetConfig(procSize, procInset, nil, nil, nil, nil)
			fState.Proc:RefreshSize()
			fState.Override:SetHeight(overrideSize)

			Util.ZoomIcon(fState.Icon, iconZoom, cxSize, cySize)
			Util.SetSliceScale(fState.Border, borderSize)
			Util.SetSliceScale(fState.Assist, assistSize)

			if fState.empowerBuff then
				-- TODO: This is no longer pixel perfect if tiles are wider than 64, which happens with
				-- a 1 stack buff. Consider increasing the texture size to 128 or 256.
				local xTileSize     = floor((cxSize + empowerGapSize - 6) / fState.empowerMaxStacks)
				local xBorderSize   = xTileSize - empowerGapSize
				local xFillSize     = xBorderSize - 2*empowerBorderSize
				local xTotalSize    = xTileSize * fState.empowerMaxStacks - empowerGapSize
				local barScale      = xTileSize / 64
				local borderSize    = empowerBorderSize / barScale
				local xCenterOffset = floor((cxSize - xTotalSize) / 2) / barScale
				local yOffset       = 1 / barScale
				local xBarSize      = fState.empowerMaxStacks * 64
				local yBarSize      = (empowerSize - 2*empowerBorderSize) / barScale
				local vFill         = (Round(xFillSize   / barScale) - 0.5) / 64
				local vBorder       = (Round(xBorderSize / barScale) - 0.5) / 64

				fState.Empower:SetPoint("TOPLEFT", fState.Content, "BOTTOMLEFT", 0, empowerSize)
				fState.EmpowerBar:SetScale(barScale)
				fState.EmpowerBar:SetPoint("TOPLEFT", borderSize + xCenterOffset, -borderSize + yOffset)
				fState.EmpowerBar:SetSize(xBarSize, yBarSize)
				fState.EmpowerFill:SetTexCoord(0, 1, vFill, vFill)
				fState.EmpowerBorder:SetTexCoord(0, 1, vBorder, vBorder)
				fState.EmpowerBorder:SetPoint("TOPLEFT",     fState.EmpowerFill, "TOPLEFT",     -borderSize,  borderSize)
				fState.EmpowerBorder:SetPoint("BOTTOMRIGHT", fState.EmpowerFill, "BOTTOMRIGHT", -borderSize, -borderSize)
			end
		end
	end
end

function CDM.RefreshAllPositions()
	local pxSize, pySize = GetPhysicalScreenSize()

	for category, vState in pairs(CDM.viewers) do
		local cfg      = vState.cfg
		local vxPos    = Round(cfg.xPos     + cfg.xPosRel     * pxSize)
		local vyPos    = Round(cfg.yPos     + cfg.yPosRel     * pySize)
		local iconSize = Round(cfg.iconSize + cfg.iconSizeRel * pySize)
		local iconPad  = Round(cfg.iconPad  + cfg.iconPadRel  * iconSize)

		local iRow = 1
		local iCol = 1
		local mxPos = 0
		local myPos = 0

		for iFrame, fState in ipairs(vState.cdFrames) do
			local rowCount = vState.rowCounts[iRow]
			local rxSize   = rowCount           * (vState.xSize + iconPad) - iconPad
			local mxSize   = vState.maxRowCount * (vState.xSize + iconPad) - iconPad
			local cxPos    = Round((mxSize - rxSize) / 2)

			local xPos = 0 + (iCol - 1) * (vState.xSize + iconPad) + cxPos
			local yPos = 0 - (iRow - 1) * (vState.ySize + iconPad)
			fState.Root:SetPoint("TOPLEFT", vState.Root, "TOPLEFT", xPos, yPos)

			iRow  = iRow + floor(iCol / rowCount)
			iCol  = iCol % rowCount + 1
			mxPos = max(mxPos, xPos + vState.xSize)
			myPos = min(myPos, yPos - vState.ySize)
		end

		vxPos = Round((0 + pxSize - mxPos) / 2 + vxPos)
		vyPos = Round((0 - pySize - myPos) / 2 + vyPos)
		vState.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
		vState.Root:SetSize(mxPos, -myPos)
	end
end

function CDM.RefreshOverride(fState, spellID)
	-- Remove the current override
	if fState.spellID ~= fState.baseSpellID then
		CDM.spellLookup[fState.spellID] = nil
		fState.spellID = fState.baseSpellID
	end

	-- Apply the new override (or revert back to base)
	if spellID and spellID ~= fState.spellID then
		CDM.spellLookup[spellID] = fState
		fState.spellID = spellID
	end
end

function CDM.RefreshOverrideTimer(fState, overrideSpellID)
	if fState.overrideTimer then
		if fState.overrideTimer.overrideSpellID == overrideSpellID then
			local duration = fState.Override:GetTimerDuration()
			duration:SetTimeFromStart(GetTime(), fState.overrideTimer.duration)
			fState.Override:Show()
		else
			fState.Override:Hide()
		end
	end
end

function CDM.RefreshAllOverrides()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				local spellID = C_Spell.GetOverrideSpell(fState.baseSpellID)
				CDM.RefreshOverride(fState, spellID)
			end
		end
	end
end

function CDM.RefreshCooldown(fState)
	local cdInfo   = C_Spell.GetSpellCooldown(fState.spellID) -- SpellCooldownInfo
	local duration = C_Spell.GetSpellCooldownDuration(fState.spellID)
	local onCD     = cdInfo.isActive and not cdInfo.isOnGCD
	local onGCD    = cdInfo.isOnGCD

	if fState.equipSlot then
		-- NOTE: GetSpellCooldown[Duration] is the item burst category cooldown for items
		local start, duration2, enable = GetInventoryItemCooldown("player", fState.equipSlot)
		if enable == 1 and duration2 > 0 then
			local BASE_GCD = 1.5
			fState.itemDuration:SetTimeFromStart(start, duration2)
			duration = fState.itemDuration
			onCD     = duration2 > BASE_GCD
			onGCD    = not onCD
		end
	end

	if onCD then
		fState.Cooldown:SetHideCountdownNumbers(not fState.cfg.cdShowTime)
		fState.Cooldown:SetCooldownFromDurationObject(duration)
		fState.Icon:SetDesaturated(true)
	elseif onGCD then
		fState.Cooldown:SetHideCountdownNumbers(true)
		fState.Cooldown:SetCooldownFromDurationObject(duration)
		fState.Icon:SetDesaturated(false)
	else
		fState.Cooldown:Clear()
		fState.Icon:SetDesaturated(false)
	end

	if onCD then
		fState.hasBling = true
		fState.Bling:SetCooldownFromDurationObject(duration, true)
	elseif fState.hasBling then
		fState.hasBling = nil
		fState.Bling:SetCooldownDuration(1e-3)
	end

	local chargeInfo = C_Spell.GetSpellCharges(fState.spellID) -- SpellChargeInfo
	local recharging = chargeInfo and chargeInfo.isActive and not onCD
	if recharging then
		local duration = C_Spell.GetSpellChargeDuration(fState.spellID)
		fState.Recharge:SetCooldownFromDurationObject(duration)
	else
		fState.Recharge:Clear()
	end

	local count
	if chargeInfo and chargeInfo.maxCharges > 1 then
		count = chargeInfo.currentCharges
	else
		count = C_Spell.GetSpellCastCount(fState.spellID)
	end
	count = C_StringUtil.TruncateWhenZero(count)
	fState.Charges:SetText(count)
end

function CDM.RefreshAllCooldowns()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				CDM.RefreshCooldown(fState)
			end
		end
	end
end

function CDM.RefreshCategory(fState, spellID, itemID)
	if fState.spellID then
		CDM.spellLookup[fState.spellID] = nil
	end

	fState.baseSpellID       = spellID
	fState.spellID           = spellID
	fState.itemID            = itemID
	CDM.spellLookup[spellID] = fState
end

function CDM.RefreshAllCategories()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.categoryID then
				local spellID, itemID = C_Spell.GetLastCategoryCooldownSource(fState.categoryID)
				local lastSource = CDM.charVars.lastCategorySource[fState.categoryID]
				if spellID and itemID then
					CDM.RefreshCategory(fState, spellID, itemID)
				elseif lastSource then
					CDM.RefreshCategory(fState, lastSource.spellID, lastSource.itemID)
				end
			end
		end
	end
end

function CDM.RefreshIcon(fState)
	if fState.itemID then
		local texture = C_Item.GetItemIconByID(fState.itemID)
		fState.Icon:SetTexture(texture)

	elseif fState.spellID then
		local texture = C_Spell.GetSpellTexture(fState.spellID)
		fState.Icon:SetTexture(texture)

	elseif fState.equipSlot then
		local texture = GetInventoryItemTexture("player", fState.equipSlot)
		fState.Icon:SetTexture(texture)

	elseif fState.categoryID then
		local texture = CDM.categoryIcons[fState.categoryID]
		fState.Icon:SetTexture(texture)
	end
end

function CDM.RefreshAllIcons()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.RefreshIcon(fState)
		end
	end
end

function CDM.RefreshUsable(fState)
	if fState.spellID then
		local usable, noMana = C_Spell.IsSpellUsable(fState.spellID)
		local noRange = C_Spell.IsSpellInRange(fState.spellID) == false -- nil is "no target" etc

		local color
		if     noRange then color = fState.cfg.noRangeColor
		elseif usable  then color = fState.cfg.usableColor
		elseif noMana  then color = fState.cfg.noManaColor
		else                color = fState.cfg.noUsableColor
		end
		fState.Icon:SetVertexColor(color:GetRGBA())
	else
		local color = fState.cfg.usableColor
		fState.Icon:SetVertexColor(color:GetRGBA())
	end
end

function CDM.RefreshAllUsable()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.RefreshUsable(fState)
		end
	end
end

function CDM.RefreshPress(spellID, pressed)
	local fState = CDM.spellLookup[spellID]
	if fState then
		fState.Press:SetShown(pressed)
	end
end

function CDM.RefreshAllPress()
	for spellID, pressCount in pairs(CDM.pressCounts) do
		CDM.RefreshPress(spellID, pressCount > 0)
	end
end

function CDM.RefreshAllQueued()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				local isCurrent = C_Spell.IsCurrentSpell(fState.spellID)
				fState.Queued:SetShown(isCurrent)
			end
		end
	end
end

function CDM.RefreshAllProcs()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				local show = C_SpellActivationOverlay.IsSpellOverlayed(fState.spellID)
				fState.Proc:SetShown(show)
			end
		end
	end
end

function CDM.OnAssistChange()
	CDM.showAssist = GetCVarBool("assistedCombatHighlight")
	CDM.RefreshAssist()
end

function CDM.RefreshAssist()

	local spellID     = C_AssistedCombat.GetNextCastSpell(false)
	local fState      = spellID and CDM.spellLookup[spellID]
	local baseSpellID = fState and fState.baseSpellID
	baseSpellID = CDM.showAssist and baseSpellID or nil

	if baseSpellID ~= CDM.assistSpellID then
		if CDM.assistSpellID then
			local fState = CDM.spellLookup[CDM.assistSpellID]
			fState.Assist:Hide()
			CDM.assistSpellID = nil
		end

		if baseSpellID then
			fState.Assist:Show()
			CDM.assistSpellID = baseSpellID
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

function CDM.OnScaleChanged()
	CDM.RefreshScale()
	CDM.RefreshAllSizes()
	CDM.RefreshAllPositions()
end

function CDM.PLAYER_REGEN_ENABLED()
	CDM.Rebuild()
end

function CDM.SPELL_RANGE_CHECK_UPDATE(spellID, isInRange, checksRange)
	local fState = CDM.spellLookup[spellID]
	if fState then
		CDM.RefreshUsable(fState)
	end
end

function CDM.BAG_UPDATE_COOLDOWN()
	-- TODO: Do we want an equipSlot lookup?
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.equipSlot then
				CDM.RefreshCooldown(fState)
			end
		end
	end
end

function CDM.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	-- NOTE: Combat potions from older expansions seem to have different categories even though they
	-- share a cooldown with current combat potions. Draenic Versatility Potion is 99 instead of the
	-- expected 4. It does update the value of C_Spell.GetLastCategoryCooldownSource(4). If we want
	-- to support these older potions we'd need to either:
	-- * Ignore the category parameter here, query each category's "last source", and do a refresh.
	-- * Build up a mapping of these undocumented categories and register them in EnableFrame.

	local fState = CDM.categoryLookup[category]
	if fState then
		if fState.spellID ~= spellID then
			-- TODO: Do we need to save this to an account saved vars too?
			-- TODO: Move the saved var update to CDM.lua
			CDM.charVars.lastCategorySource[category] = { spellID = spellID, itemID = itemID }
			CDM.RefreshCategory(fState, spellID, itemID)
			CDM.RefreshIcon(fState)
		end
	end

	local startGCD = startRecoveryCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY
	if startGCD or not spellID then
		CDM.refreshAllCooldowns = true
	else
		-- NOTE: Supposedly this event can arrive before the override event, so we need to check base
		local fState = CDM.spellLookup[spellID] or CDM.spellLookup[baseSpellID]
		if fState then
			CDM.RefreshCooldown(fState)
		end
	end
end

function CDM.SPELL_UPDATE_USES(spellID, baseSpellID)
	local fState = CDM.spellLookup[spellID] or CDM.spellLookup[baseSpellID]
	if fState then
		CDM.RefreshCooldown(fState)
	end
end

function CDM.GLOBAL_MOUSE_DOWN(mouseButton)
	CDM.mousePresses[mouseButton] = {
		time   = GetTime(),
		button = nil,
	}
end

function CDM.GLOBAL_MOUSE_UP(mouseButton)
	local press = CDM.mousePresses[mouseButton]
	CDM.mousePresses[mouseButton] = nil

	if press and press.button then
		CDM.OnClick(press.button, mouseButton, false, nil, nil)
	end
end

function CDM.CURRENT_SPELL_CAST_CHANGED(cancelledCast)
	CDM.RefreshAllQueued()
end

function CDM.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(spellID)
	local fState = CDM.spellLookup[spellID]
	if fState then
		fState.Proc:Show()
	end
end

function CDM.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(spellID)
	local fState = CDM.spellLookup[spellID]
	if fState then
		fState.Proc:Hide()
	end
end

function CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
	local fState = CDM.spellLookup[baseSpellID]
	if fState then
		CDM.RefreshOverride(fState, overrideSpellID)
		CDM.RefreshOverrideTimer(fState, overrideSpellID)
	end
end

function CDM.SPELL_UPDATE_ICON(spellID)
	if spellID then
		local fState = CDM.spellLookup[spellID]
		if fState then
			CDM.RefreshIcon(fState)
		end
	else
		CDM.RefreshAllIcons()
	end
end

function CDM.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
	-- NOTE: We are not guaranteed to get a release after a press:
	-- Mouse down, drag off, mouse release                - no event
	-- Mouse down, drag off (far), drag on, mouse release - no event, was turned into a drag
	-- Mouse down, drag spell off bar, mouse release      - no event
	-- Key down, mouse down, mouse up, key up             - no event, any up cancels other events
	-- Key down, disable action bar, key up               - no event
	-- Maybe if keybinding is programmatically changed while held?

	-- NOTE: Macros can cast/use multiple spells/items but there doesn't appear to be a way to get
	-- all of them. GetMacroSpell only returns one spellID.

	-- NOTE: This doesn't fire when clicking items in bags. They don't use a secure frame. We could
	-- hook button frames but it's a per-button hook instead of a global one.

	-- NOTE: Keybindings always send left mouse button.
	-- NOTE: Addon synthesized events send isKeyPress = nil.
	-- NOTE: When dragging a spell off a button it will no longer have an action.
	-- NOTE: We choose not to handle the action bar disable and binding change edge cases.

	local spellID = nil

	if down then
		local buttonType = SecureButton_GetModifiedAttribute(button, "type", mouseButton)
		if buttonType == "action" then
			local slot = button:CalculateAction(mouseButton)
			local actionType, id, subType = GetActionInfo(slot)

			-- plain spell or /cast macro
			if actionType == "spell" or (actionType == "macro" and subType == "spell") then
				spellID = id

			-- plain item or /use macro
			elseif actionType == "item" or (actionType == "macro" and subType == "item") then
				-- BUG: https://github.com/Stanzilla/WoWUIBugs/issues/495
				spellID = C_ActionBar.GetSpell(slot)
			end
		end

		if not isKeyPress then
			local press = CDM.mousePresses[mouseButton]
			if press and press.time == GetTime() and button:IsMouseMotionFocus() then
				press.button = button
			end
		end
	end

	local fState      = CDM.spellLookup[spellID]
	local currSpellID = fState and fState.baseSpellID
	local prevSpellID = CDM.spellPresses[button]

	if prevSpellID ~= currSpellID then
		CDM.spellPresses[button] = currSpellID

		if prevSpellID then
			local pressCount = Util.TableRefAdd(CDM.pressCounts, prevSpellID, -1)
			CDM.RefreshPress(prevSpellID, pressCount > 0)
		end

		if currSpellID then
			local pressCount = Util.TableRefAdd(CDM.pressCounts, currSpellID, 1)
			CDM.RefreshPress(currSpellID, pressCount > 0)
		end
	end
end

function CDM.OnCDMChanged()
	-- NOTE: Hook fires when events are being throttled. Wait for the unlock.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	if layoutMgr:AreNotificationsLocked() then return end

	CDM.Rebuild()
end

----------------------------------------------------------------------------------------------------
-- File Load

CDM.Load()
