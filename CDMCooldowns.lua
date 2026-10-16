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

	local db = Kami.CDM.db
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
				WARRIOR     = Config.Raw({
					--[db.WARRIOR.Ability.Slam] = Config.Table({ overrideSpellID = Config.Number(db.WARRIOR.Ability.HeroicStrike), duration = Config.Number(15) }),
					[db.WARRIOR.Ability.Slam] = { overrideSpellID = db.WARRIOR.Ability.HeroicStrike, duration = 15 },
				}),
				PALADIN     = Config.Table({}),
				HUNTER      = Config.Table({}),
				ROGUE       = Config.Table({}),
				PRIEST      = Config.Table({}),
				DEATHKNIGHT = Config.Table({}),
				SHAMAN      = Config.Table({}),
				MAGE        = Config.Table({}),
				WARLOCK     = Config.Table({}),
				MONK        = Config.Table({}),
				DRUID       = Config.Table({}),
				DEMONHUNTER = Config.Table({}),
				EVOKER      = Config.Table({}),
			}),

			empowerSize       = Config.Size("7px"),
			empowerGapSize    = Config.Size("3px"),
			empowerBorderSize = Config.Size("2px"),
			empowerBuffs      = Config.Table({
				WARRIOR     = Config.Table({
					[db.WARRIOR.Ability.Overpower]    = Config.Number(db.WARRIOR.Aura.Opportunist),
					[db.WARRIOR.Ability.Cleave]       = Config.Number(db.WARRIOR.Aura.CollateralDamage),
					[db.WARRIOR.Talent.Bladestorm]    = Config.Number(db.WARRIOR.Aura.ImminentDemise),
					[db.WARRIOR.Ability.Slam]         = Config.Number(db.WARRIOR.Aura.WindingUp),
					[db.WARRIOR.Ability.Execute]      = Config.Number(db.WARRIOR.Aura.Executioner),
					[db.WARRIOR.Ability.MortalStrike] = Config.Number(db.WARRIOR.Aura.ExecutionersPrecision),
				}),
				PALADIN     = Config.Table({}),
				HUNTER      = Config.Table({}),
				ROGUE       = Config.Table({}),
				PRIEST      = Config.Table({}),
				DEATHKNIGHT = Config.Table({}),
				SHAMAN      = Config.Table({}),
				MAGE        = Config.Table({}),
				WARLOCK     = Config.Table({}),
				MONK        = Config.Table({}),
				DRUID       = Config.Table({}),
				DEMONHUNTER = Config.Table({}),
				EVOKER      = Config.Table({}),
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
			rowLimits = Config.Table({ Config.Number(4) }),
		})

	Config.AddNode(CDM.cfgTree, "Essential", "Skyriding", {})

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Cooldowns.Event")
	CDM.eventFrame:SetScript("OnEvent",                              CDM.DispatchEvent)
	CDM.RegisterEvent("UI_SCALE_CHANGED",                            CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",                        CDM.OnScaleChanged)
	CDM.RegisterEvent("SPELL_UPDATE_USABLE",                         CDM.SPELL_UPDATE_USABLE)
	CDM.RegisterEvent("ACTIONBAR_UPDATE_USABLE",                     CDM.ACTIONBAR_UPDATE_USABLE)
	CDM.RegisterEvent("PLAYER_CAN_GLIDE_CHANGED",                    CDM.PLAYER_CAN_GLIDE_CHANGED)
	CDM.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED",             CDM.ADDON_RESTRICTION_STATE_CHANGED)
	CDM.RegisterEvent("ACTIONBAR_SLOT_CHANGED",                      CDM.ACTIONBAR_SLOT_CHANGED)
	CDM.RegisterEvent("BAG_UPDATE_COOLDOWN",                         CDM.BAG_UPDATE_COOLDOWN)
	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN",                       CDM.SPELL_UPDATE_COOLDOWN)
	CDM.RegisterEvent("SPELL_RANGE_CHECK_UPDATE",                    CDM.SPELL_RANGE_CHECK_UPDATE)
	CDM.RegisterEvent("CURRENT_SPELL_CAST_CHANGED",                  CDM.CURRENT_SPELL_CAST_CHANGED)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",          CDM.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",          CDM.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
	CDM.RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",      CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED)
	CDM.RegisterEvent("SPELL_UPDATE_ICON",                           CDM.SPELL_UPDATE_ICON)
	CDM.RegisterEvent("UPDATE_SHAPESHIFT_FORM",                      CDM.UPDATE_SHAPESHIFT_FORM)
	CDM.RegisterEvent("SPELL_UPDATE_USES",                           CDM.SPELL_UPDATE_USES)
	hooksecurefunc(UIParent, "SetScale",                             CDM.OnScaleChanged)
	hooksecurefunc("SecureActionButton_OnClick",                     CDM.OnClick)
	SecureStateDriverManager:HookScript("OnUpdate",                  CDM.Update)
	RegisterStateDriver(CDM.eventFrame, "poll", "1")
	CVarCallbackRegistry:RegisterCallback("assistedCombatHighlight", CDM.OnAssistChange, CDM)

	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.OnCDMChanged)

	local cdTypeface = LSM:Fetch("font", "PT Sans Narrow")
	local chargeTypeface = LSM:Fetch("font", "Homespun")

	local categories = {
		[Enum.CooldownViewerCategory.Essential] = "Essential",
		[Enum.CooldownViewerCategory.Utility]   = "Utility",
		Skyriding                               = "Skyriding",
	}

	CDM.viewers = {}
	for category, categoryName in pairs(categories) do
		local Root = CreateFrame("Frame", nil, UIParent)
		Root:SetParentKey(("Kami.CDM.Cooldowns.%s.Root"):format(categoryName))

		local cdFontName = ("Kami.CDM.Cooldowns.CDFont.%s"):format(categoryName)
		local cdFont = CreateFont(cdFontName)
		cdFont:SetFont(cdTypeface, 18, "OUTLINE")

		local chargeFontName = ("Kami.CDM.Cooldowns.ChargeFont.%s"):format(categoryName)
		local chargeFont = CreateFont(chargeFontName)
		chargeFont:SetFont(chargeTypeface, 18, "OUTLINE")

		local vState = {
			name         = categoryName,
			cfg          = Config.GetBranch(CDM.cfgTree, categoryName),
			Root         = Root,
			cdFontName   = cdFontName,
			cdFont       = cdFont,
			chargeFont   = chargeFont,
			cdvInfos     = {},
			slots        = {},
			allFrames    = {},
			activeFrames = {},
			maxRowCount  = 0,
			rowCounts    = {},
			xSize        = nil,
			ySize        = nil,
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
	CDM.formLookup     = {}
	CDM.categoryIcons  = {
		[db.Category.CombatPotion] = "Interface/ICONS/INV_POTION_114",
		[db.Category.HealthPotion] = "Interface/ICONS/INV_POTION_54",
		[db.Category.Healthstone]  = "Interface/ICONS/Warlock_ Healthstone",
		[db.Category.Bloodstone]   = "Interface/ICONS/Warlock_ Bloodstone",
	}
	CDM.activePresses       = {}
	CDM.pressKeyIDLookup    = {}
	CDM.activeOverrides     = {}
	CDM.refreshAllCooldowns = false
	CDM.refreshAllUsable    = false
	CDM.aurasSecret         = C_Secrets.ShouldAurasBeSecret()

	CDM.OnAssistChange()
	CDM.Rebuild("Load")
end

function CDM.Update()
	if CDM.refreshAllCooldowns then
		CDM.refreshAllCooldowns = false
		CDM.RefreshAllCooldowns()
	end

	if CDM.refreshAllUsable then
		CDM.refreshAllUsable = false
		CDM.RefreshAllUsable()
	end

	CDM.PollAssist()
	CDM.PollPresses()
end

function CDM.Rebuild(reason)
	print("Rebuild", reason)

	CDM.GatherCDs()
	CDM.RefreshFormLookup()
	CDM.RefreshScale()
	CDM.RefreshAllOverrideRecords()
	CDM.RefreshAllBarSlots()
	CDM.RefreshAllCategorySlots()
	CDM.AssignFrames()
	CDM.RefreshAllConfig()
	CDM.RefreshAllOverrides()
	CDM.RefreshAllCooldowns()
	CDM.RefreshAllQueued()
	CDM.RefreshAllProcs()
	CDM.RefreshAllAssist()
	CDM.RefreshAllEmpower()
	CDM.RefreshAllSizes()
	CDM.RefreshAllPositions()
	CDM.RefreshAllRangeChecks()
	CDM.RefreshAllIcons()
	CDM.RefreshAllUsable()
	CDM.RefreshAllPress()
	CDM.RefreshSkyriding()
end

function CDM.ConstructFrame(vState, slot)
	-- Frame        | Textures/Text          | Purpose
	-- -------------|------------------------|--------
	-- Root         | Border                 | Size, Position
	--   Content    | Icon                   | Inset
	--     Recharge |                        | Cooldown
	--     Cooldown |                        | Cooldown
	--     Overlay  | Press, Queued, Charges | Draw Order
	--     Bling    |                        | Cooldown
	--   Outline    | Assist                 | Draw Order

	local fState = {}
	fState.cfg              = vState.cfg
	fState.slot             = nil
	fState.baseSpellID      = nil
	fState.spellID          = nil
	fState.categoryID       = slot.categoryID
	fState.equipSlot        = slot.equipSlot
	fState.barSlot          = slot.barSlot
	fState.itemDuration     = C_DurationUtil.CreateDuration()
	fState.empowerMaxStacks = 1
	fState.itemID           = nil
	fState.pressKeyType     = nil
	fState.pressKeyID       = nil
	fState.empowerBuff      = nil
	fState.hasBling         = nil
	fState.overrideTimer    = nil
	fState.rangeSpellID     = nil

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
	fState.Empower:Hide()

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

function CDM.EnableFrame(fState, slot)
	fState.slot         = slot
	fState.baseSpellID  = slot.spellID
	fState.spellID      = slot.spellID
	fState.itemID       = slot.itemID
	fState.pressKeyType = slot.pressKeyType
	fState.pressKeyID   = slot.pressKeyID

	if fState.spellID then
		CDM.spellLookup[fState.spellID] = CDM.spellLookup[fState.spellID] or {}
		CDM.spellLookup[fState.spellID][fState] = true
	end

	if fState.pressKeyID then
		CDM.pressKeyIDLookup[fState.pressKeyID] = CDM.pressKeyIDLookup[fState.pressKeyID] or {}
		CDM.pressKeyIDLookup[fState.pressKeyID][fState] = true
	end

	CDM.ClearBling(fState)
	fState.Root:Show()
end

function CDM.DisableFrame(fState)
	if fState.spellID then
		CDM.spellLookup[fState.spellID][fState] = nil
		CDM.spellLookup[fState.baseSpellID][fState] = nil
	end

	if fState.pressKeyID then
		CDM.pressKeyIDLookup[fState.pressKeyID][fState] = nil
	end

	fState.Root:Hide()
end

function CDM.AssignFrames()
	-- NOTE: We key slots by a stable id then reassign the frame in that slot to different spells /
	-- items as necessary. This approach allows duplicate spells and single-frame reassignment. We
	-- don't have to run a rebuild or layout pass. This is especially nice for conditional macros
	-- that change spell/item with a modifier key. The cost is that some details are not refreshed if
	-- the reassignment happens while auras are secret. Currently, querying max stacks for empower
	-- bars is the only thing that isn't supported, but it gets fixed up as soon as auras are no
	-- longer secret.

	for category, vState in pairs(CDM.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.DisableFrame(fState)
		end
		wipe(vState.activeFrames)

		-- Construct or re-enable frames
		for iSlot, slot in ipairs(vState.slots) do
			if slot.hasAction then
				local fState = vState.allFrames[slot.key]
				if not fState then
					fState = CDM.ConstructFrame(vState, slot)
					vState.allFrames[slot.key] = fState
				end

				CDM.EnableFrame(fState, slot)
				table.insert(vState.activeFrames, fState)
			end
		end

		-- Cache raw counts
		vState.maxRowCount = 0
		wipe(vState.rowCounts)
		local remaining = #vState.activeFrames
		while remaining > 0 do
			local rowLimit = vState.cfg.rowLimits[#vState.rowCounts + 1] or vState.cfg.rowLimit
			local nRow = min(remaining, rowLimit)

			vState.maxRowCount = max(vState.maxRowCount, nRow)
			table.insert(vState.rowCounts, nRow)
			remaining = remaining - nRow
		end
	end
end

function CDM.ReassignFrame(fState, slot)
	CDM.DisableFrame(fState)
	CDM.EnableFrame(fState, slot)

	CDM.RefreshConfig(fState)
	CDM.RefreshOverride(fState)
	CDM.RefreshCooldown(fState)
	CDM.RefreshQueued(fState)
	CDM.RefreshProc(fState)
	CDM.RefreshAssist(fState)
	CDM.RefreshEmpower(fState)
	CDM.RefreshRangeCheck(fState)
	CDM.RefreshIcon(fState)
	CDM.RefreshUsable(fState)
	CDM.RefreshPress(fState)

	if fState.empowerBuff then
		CDM.RefreshAllSizes()
	end
end

function CDM.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	for category, vState in pairs(CDM.viewers) do
		vState.Root:SetScale(pixelsToUI)
	end

	Config.RefreshValues(CDM.cfgTree, pixelsToUI)
end

function CDM.RefreshEmpower(fState)
	local empowerBuff = fState.cfg.empowerBuffs[CDM.classToken][fState.baseSpellID]

	if empowerBuff and not C_Secrets.ShouldAurasBeSecret() then
		fState.empowerMaxStacks = max(1, C_Spell.GetSpellMaxCumulativeAuraApplications(empowerBuff))
		fState.EmpowerButton:SetApplicationBar(fState.EmpowerBar, { maxApplications = fState.empowerMaxStacks })
	end

	if fState.empowerBuff ~= empowerBuff then
		if empowerBuff and not C_Secrets.ShouldAurasBeSecret() then
			fState.empowerBuff = empowerBuff
			fState.Empower:SetAuraSlotCandidateFilters(tostring(fState), { includeSpellIDs = { [fState.empowerBuff] = true } })
			fState.Empower:Show()
		else
			fState.empowerBuff = nil
			fState.empowerMaxStacks = 1
			fState.Empower:SetAuraSlotCandidateFilters(tostring(fState), { includeSpellIDs = {} })
			fState.Empower:Hide()
		end
	end
end

function CDM.RefreshAllEmpower()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshEmpower(fState)
		end
	end
end

function CDM.RefreshConfig(fState)
	fState.overrideTimer = fState.cfg.overrideTimers[CDM.classToken][fState.baseSpellID]

	fState.Border:SetVertexColor(fState.cfg.borderColor:GetRGBA())
	fState.Press:SetColorTexture(fState.cfg.pressColor:GetRGBA())
	fState.Queued:SetColorTexture(fState.cfg.queuedColor:GetRGBA())
	fState.Assist:SetVertexColor(fState.cfg.assistColor:GetRGBA())
	fState.Override:SetColorFill(fState.cfg.procColor:GetRGBA())
	fState.OverrideBG:SetColorTexture(fState.cfg.borderColor:GetRGBA())

	if not C_Secrets.ShouldAurasBeSecret() then
		fState.EmpowerBorder:SetVertexColor(fState.cfg.borderColor:GetRGBA())
		fState.EmpowerFill:SetVertexColor(CDM.classColor:GetRGBA())
	end

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
		for iFrame, fState in ipairs(vState.activeFrames) do
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

		for iFrame, fState in ipairs(vState.activeFrames) do
			fState.Root:SetSize(vState.xSize, vState.ySize)
			fState.Content:SetSize(cxSize, cySize)
			fState.Recharge:SetSize(diagSize, diagSize)
			fState.Charges:SetPoint("BOTTOMRIGHT", fState.Content, "BOTTOMRIGHT", chargeXOffset, chargeYOffset)
			fState.Bling:SetSize(diagSize, diagSize)
			fState.Proc:SetConfig(procSize, procInset, nil, nil, nil, nil)
			fState.Proc:RefreshSize() -- TODO: Pass the size in
			fState.Override:SetHeight(overrideSize)

			Util.ZoomIcon(fState.Icon, iconZoom, cxSize, cySize)
			Util.SetSliceScale(fState.Border, borderSize)
			Util.SetSliceScale(fState.Assist, assistSize)

			if fState.empowerBuff and not C_Secrets.ShouldAurasBeSecret() then
				-- TODO: This is no longer pixel perfect if tiles are wider than 64, which happens with
				-- a 1 stack buff. Consider increasing the texture size to 128 or 256.
				local maxStacks     = fState.empowerMaxStacks
				local xTileSize     = floor((cxSize + empowerGapSize - 6) / maxStacks)
				local xBorderSize   = xTileSize - empowerGapSize
				local xFillSize     = xBorderSize - 2*empowerBorderSize
				local xTotalSize    = xTileSize * maxStacks - empowerGapSize
				local barScale      = xTileSize / 64
				local borderSize    = empowerBorderSize / barScale
				local xCenterOffset = floor((cxSize - xTotalSize) / 2) / barScale
				local yOffset       = 1 / barScale
				local xBarSize      = maxStacks * 64
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

		for iFrame, fState in ipairs(vState.activeFrames) do
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

function CDM.RefreshOverrideRecord(spellID)
	if not CDM.activeOverrides[spellID] then
		local overrideSpellID = C_Spell.GetOverrideSpell(spellID)
		if overrideSpellID ~= spellID then
			CDM.activeOverrides[spellID] = { overrideSpellID = overrideSpellID, time = nil }
		end
	end
end

function CDM.RefreshAllOverrideRecords()
	for category, vState in pairs(CDM.viewers) do
		for iSlot, slot in ipairs(vState.slots) do
			if slot.spellID then
				CDM.RefreshOverrideRecord(slot.spellID)
			end
		end
	end
end

function CDM.SetOverride(fState, spellID)
	-- Remove the current override
	if fState.spellID ~= fState.baseSpellID then
		CDM.spellLookup[fState.spellID][fState] = nil
		fState.spellID = fState.baseSpellID
	end

	-- Apply the new override (or revert back to base)
	if spellID and spellID ~= fState.spellID then
		CDM.spellLookup[spellID] = CDM.spellLookup[spellID] or {}
		CDM.spellLookup[spellID][fState] = true
		fState.spellID = spellID
	end
end

function CDM.RefreshOverride(fState)
	local override = CDM.activeOverrides[fState.baseSpellID]
	local spellID  = override and override.overrideSpellID
	CDM.SetOverride(fState, spellID)

	local timer = fState.overrideTimer
	if timer and override and override.time and override.overrideSpellID == timer.overrideSpellID then
		local duration = fState.Override:GetTimerDuration()
		duration:SetTimeFromStart(override.time, timer.duration)
		fState.Override:Show()
	else
		fState.Override:Hide()
	end
end

function CDM.RefreshAllOverrides()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshOverride(fState)
		end
	end
end

function CDM.RefreshCooldown(fState)
	-- NOTE: The shared, GCD-like cooldown on several skyriding abilities is not actually the GCD.
	-- It's a shared cooldown category (closer to the trinket / item burst category). So we go out of
	-- our way to re-classify it as a GCD. activeCategory is secret in combat for most spells, but
	-- luckily not skyriding abilities so we're able to read it when it matters. If it's secret, it's
	-- definitely not the skyriding GCD and we can ignore it.

	-- NOTE: isOnGCD is always false for an item's bar action.

	-- NOTE: At first glance it seems like we could drop the action bar path below and treat
	-- everything as either an item or a spell. But, there are in fact things with cooldowns that are
	-- neither: e.g. companion pets (on the GCD) and transmog outfits (3s CD).

	-- NOTE: Other fun edge cases to know about:
	-- * C_ActionBar APIs follow #showtooltip when it differs from what will actually be cast/used.
	-- * [btn:2] casts a different spell from what is visible (noteworthy for the press overlay).
	-- * There can be multiple spells/uses in a single macro when they aren't on the GCD.
	-- * /castsequence exists.
	-- * Many complex conditionals (stance, exists, harm, etc). Must rely on ACTIONBAR_SLOT_CHANGED.

	-- NOTE: API behavior for items
	-- API                                   | Secret | GCD | isOnGCD | CD  | Shared | ignoreGCD |
	--
	-- C_Item.GetItemCooldown                | No     | Yes | No      | Yes | Yes    | N/A       |
	-- C_ActionBar.GetActionCooldown         | Yes    | Yes | No      | Yes | Yes    | N/A       |
	-- C_Spell.GetSpellCooldown              | Yes    | Yes | Yes     | No  | Yes    | N/A       |
	--
	-- C_Item.GetItemCooldownDuration        | doesn't exist                                     |
	-- C_ActionBar.GetActionCooldownDuration | Yes    | Yes | N/A     | Yes | Yes    | Broken    |
	-- C_Spell.GetSpellCooldownDuration      | Yes    | Yes | N/A     | No  | Yes    | Works     |

	local db = Kami.CDM.db

	local isItem, onCD, onGCD, duration, rechargeDuration, chargeCount

	if fState.itemID then
		-- NOTE: GetSpellCooldown[Duration] is the item burst category cooldown for items
		local BASE_GCD = 1.5
		local start, itemDuration, enable = C_Item.GetItemCooldown(fState.itemID)
		fState.itemDuration:SetTimeFromStart(start, itemDuration)

		isItem      = true
		onCD        = enable and itemDuration > BASE_GCD
		onGCD       = enable and itemDuration > 0 and not onCD
		duration    = fState.itemDuration
		chargeCount = C_Item.GetItemCount(fState.itemID)

	elseif fState.barSlot then
		local cdInfo     = C_ActionBar.GetActionCooldown(fState.barSlot) -- SpellCooldownInfo
		local chargeInfo = C_ActionBar.GetActionCharges(fState.barSlot) -- SpellChargeInfo

		isItem           = C_ActionBar.IsItemAction(fState.barSlot)
		onGCD            = cdInfo.isOnGCD or Util.Sanitize(cdInfo.activeCategory) == db.Category.SkyridingGCD
		onCD             = cdInfo.isActive and not onGCD
		duration         = C_ActionBar.GetActionCooldownDuration(fState.barSlot)
		rechargeDuration = C_ActionBar.GetActionChargeDuration(fState.barSlot)
		chargeCount      = chargeInfo.maxCharges > 1 and chargeInfo.currentCharges or C_ActionBar.GetActionUseCount(fState.barSlot)

	elseif fState.spellID then
		local cdInfo     = C_Spell.GetSpellCooldown(fState.spellID) -- SpellCooldownInfo
		local chargeInfo = C_Spell.GetSpellCharges(fState.spellID) -- SpellChargeInfo

		isItem           = false
		onGCD            = cdInfo.isOnGCD or Util.Sanitize(cdInfo.activeCategory) == db.Category.SkyridingGCD
		onCD             = cdInfo.isActive and not onGCD
		duration         = C_Spell.GetSpellCooldownDuration(fState.spellID)
		rechargeDuration = C_Spell.GetSpellChargeDuration(fState.spellID)
		chargeCount      = chargeInfo and chargeInfo.maxCharges > 1 and chargeInfo.currentCharges or C_Spell.GetSpellCastCount(fState.spellID)
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
		fState.Bling:SetCooldownFromDurationObject(duration)
	elseif fState.hasBling then
		fState.hasBling = nil
		fState.Bling:SetCooldownDuration(1e-3)
	end

	if rechargeDuration and not onCD then
		fState.Recharge:SetCooldownFromDurationObject(rechargeDuration)
	else
		fState.Recharge:Clear()
	end

	chargeCount = not isItem and chargeCount or 0
	chargeCount = C_StringUtil.TruncateWhenZero(chargeCount)
	fState.Charges:SetText(chargeCount)
end

function CDM.RefreshAllCooldowns()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshCooldown(fState)
		end
	end
end

function CDM.ClearBling(fState)
	fState.hasBling = nil
	fState.Bling:Clear()
end

function CDM.ClearAllBlings()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.ClearBling(fState)
		end
	end
end

function CDM.RefreshRangeCheck(fState)
	if fState.rangeSpellID ~= fState.baseSpellID then
		if fState.rangeSpellID then
			C_Spell.EnableSpellRangeCheck(fState.rangeSpellID, false)
		end
		fState.rangeSpellID = fState.baseSpellID
		if fState.rangeSpellID then
			C_Spell.EnableSpellRangeCheck(fState.rangeSpellID, true)
		end
	end
end

function CDM.RefreshAllRangeChecks()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshRangeCheck(fState)
		end
	end
end

function CDM.RefreshIcon(fState)
	local texture = nil
	local formIndex = CDM.formLookup[fState.baseSpellID]

	if     fState.barSlot    then texture = C_ActionBar.GetActionTexture(fState.barSlot)
	elseif fState.itemID     then texture = C_Item.GetItemIconByID(fState.itemID)
	elseif fState.equipSlot  then texture = GetInventoryItemTexture("player", fState.equipSlot)
	elseif formIndex         then texture = GetShapeshiftFormInfo(formIndex)
	elseif fState.spellID    then texture = C_Spell.GetSpellTexture(fState.spellID)
	elseif fState.categoryID then texture = CDM.categoryIcons[fState.categoryID]
	end

	fState.Icon:SetTexture(texture)
end

function CDM.RefreshAllIcons()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshIcon(fState)
		end
	end
end

function CDM.RefreshUsable(fState)
	-- NOTE: Each of the "in range" functions return nil for "no target", etc
	local usable, noMana, noRange
	if fState.barSlot then
		usable, noMana = C_ActionBar.IsUsableAction(fState.barSlot)
		noRange        = C_ActionBar.IsActionInRange(fState.barSlot, "target") == false
	elseif fState.itemID then
		usable, noMana = C_Item.IsUsableItem(fState.itemID)
		noRange        = C_Item.IsItemInRange(fState.itemID, "target") == false
	elseif fState.spellID then
		usable, noMana = C_Spell.IsSpellUsable(fState.spellID)
		noRange        = C_Spell.IsSpellInRange(fState.spellID, "target") == false
	else
		usable = true
	end

	local color
	if     noRange then color = fState.cfg.noRangeColor
	elseif usable  then color = fState.cfg.usableColor
	elseif noMana  then color = fState.cfg.noManaColor
	else                color = fState.cfg.noUsableColor
	end
	fState.Icon:SetVertexColor(color:GetRGBA())
end

function CDM.RefreshAllUsable()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshUsable(fState)
		end
	end
end

function CDM.RefreshPress(fState)
	-- BUG: Flyouts on ElvUI action bars do not have a press highlight
	local pressed = false
	if fState.pressKeyType then
		for button, mouseButton in pairs(CDM.activePresses) do
			if button.klPressKeyType == fState.pressKeyType and button.klPressKeyID == fState.pressKeyID then
				pressed = true
			end
		end
	end
	fState.Press:SetShown(pressed)
end

function CDM.RefreshAllPress()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshPress(fState)
		end
	end
end

function CDM.RefreshQueued(fState)
	local isCurrent = false
	if fState.barSlot then
		isCurrent = C_ActionBar.IsCurrentAction(fState.barSlot)
	elseif fState.itemID then
		isCurrent = C_Item.IsCurrentItem(fState.itemID)
	elseif fState.spellID then
		isCurrent = C_Spell.IsCurrentSpell(fState.spellID)
	end
	fState.Queued:SetShown(isCurrent)
end

function CDM.RefreshAllQueued()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshQueued(fState)
		end
	end
end

function CDM.RefreshProc(fState)
	local show = fState.spellID and C_SpellActivationOverlay.IsSpellOverlayed(fState.spellID)
	fState.Proc:SetShown(show)
end

function CDM.RefreshAllProcs()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshProc(fState)
		end
	end
end

function CDM.PollAssist()
	local assistSpellID = CDM.showAssist and C_AssistedCombat.GetNextCastSpell(false) or nil
	if CDM.assistSpellID ~= assistSpellID then
		local prevAssistSpellID = CDM.assistSpellID
		CDM.assistSpellID = assistSpellID
		for fState in pairs(CDM.spellLookup[prevAssistSpellID] or {}) do
			CDM.RefreshAssist(fState)
		end
		for fState in pairs(CDM.spellLookup[CDM.assistSpellID] or {}) do
			CDM.RefreshAssist(fState)
		end
	end
end

function CDM.RefreshAssist(fState)
	local shown = fState.spellID and (fState.spellID == CDM.assistSpellID or fState.baseSpellID == CDM.assistSpellID)
	fState.Assist:SetShown(shown)
end

function CDM.RefreshAllAssist()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			CDM.RefreshAssist(fState)
		end
	end
end

function CDM.PollPresses()
	for button, mouseButton in pairs(CDM.activePresses) do
		local down = button:GetButtonState() == "PUSHED"
		CDM.OnClick(button, mouseButton, down, nil, nil)
	end
end

function CDM.GetBarAction(barSlot, needItemID)
	-- BUG: https://github.com/Stanzilla/WoWUIBugs/issues/495
	--
	-- Getting the item id is important for cooldowns to work properly. The spell cooldown shows the
	-- GCD and the shared cooldown, but not the actual idem cooldown. A few options for getting the
	-- item id:
	-- 1. Map the macro name to the macro index, then query the macro. This mapping is ambiguous
	--    because macro names are not required to be unique. We can mostly disambiguate by confirming
	--    the spell id matches, but that can fail too when multiple items have the same spell, like
	--    ranks of the Algari Healing Potion.
	-- 2. Get the item id from the tooltip. This can fail if the macro doesn't use #showtooltip. The
	--    line index is undocumented so it's unclear if it will always be in the first slot.
	-- 3. Learn items from SPELL_UPDATE_COOLDOWN. This can fail if the cast wasn't seen, e.g. when
	--    first installing the addon, when saved vars where reset, or when the spell was cast while
	--    logged in on a different PC.
	--
	-- Since all of these options kind of suck, we go with the tooltip approach. This is the only one
	-- that requires no additional state. If they're all sort-of-broken we might as well take the
	-- simplest one.

	-- NOTE: Every transmog outfit has the same spell, so they are keyed by actionType instead of "spell"

	local spellID, itemID, pressKeyType, pressKeyID
	local actionType, id, subType = GetActionInfo(barSlot)

	-- spell
	do
		-- NOTE: spellID can be 0 while logging in
		spellID = C_ActionBar.GetSpell(barSlot)
		spellID = spellID ~= 0 and spellID or nil

		for baseSpellID, override in pairs(CDM.activeOverrides) do
			if override.overrideSpellID == spellID then
				spellID = baseSpellID
			end
		end
	end

	-- item
	if needItemID then
		if actionType == "item" then
			itemID = id

		elseif actionType == "macro" and subType == "item" then
			local tooltipData = C_TooltipInfo.GetAction(barSlot)
			local line        = tooltipData.lines[1]
			if line.tooltipType == Enum.TooltipDataType.Item then
				itemID = line.tooltipID
			end
		end
	end

	-- press key
	do
		if spellID and actionType ~= "outfit" then
			pressKeyType = "spell"
			pressKeyID   = spellID
		elseif actionType ~= "macro" or subType == "" then
			pressKeyType = actionType
			pressKeyID   = id
		end
	end

	return spellID, itemID, pressKeyType, pressKeyID
end

function CDM.GatherCDs()
	Kami.CDM.GatherCDs(CDM.viewers)
	for category, vState in pairs(CDM.viewers) do
		wipe(vState.slots)
		for iInfo, cdvInfo in ipairs(vState.cdvInfos) do
			local slot = {
				key          = cdvInfo.cooldownID,
				spellID      = cdvInfo.spellID,
				itemID       = cdvInfo.equipSlot and GetInventoryItemID("player", cdvInfo.equipSlot) or nil,
				categoryID   = cdvInfo.spellCategoryID,
				equipSlot    = cdvInfo.equipSlot,
				barSlot      = nil,
				pressKeyType = cdvInfo.spellID and "spell",
				pressKeyID   = cdvInfo.spellID,
				hasAction    = true,
			}
			table.insert(vState.slots, slot)
		end
	end

	local FIRST_SLOT = 121
	local LAST_SLOT  = 132
	local vState = CDM.viewers.Skyriding
	wipe(vState.slots)
	for barSlot = FIRST_SLOT, LAST_SLOT do
		local slot = {
			key          = barSlot,
			spellID      = nil,
			itemID       = nil,
			categoryID   = nil,
			equipSlot    = nil,
			barSlot      = barSlot,
			pressKeyType = nil,
			pressKeyID   = nil,
			hasAction    = false,
		}
		table.insert(vState.slots, slot)
	end
end

function CDM.RefreshFormLookup()
	wipe(CDM.formLookup)
	for iForm = 1, GetNumShapeshiftForms() do
		local spellID = select(4, GetShapeshiftFormInfo(iForm))
		CDM.formLookup[spellID] = iForm
	end
end

function CDM.RefreshSkyriding()
	local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo()
	for category, vState in pairs(CDM.viewers) do
		vState.Root:SetShown(not canGlide)
	end

	local vState = CDM.viewers.Skyriding
	vState.Root:SetShown(canGlide)
end

function CDM.RefreshBarSlot(slot)
	slot.spellID, slot.itemID, slot.pressKeyType, slot.pressKeyID = CDM.GetBarAction(slot.barSlot, true)
	slot.hasAction = C_ActionBar.HasAction(slot.barSlot)
end

function CDM.RefreshAllBarSlots()
	for category, vState in pairs(CDM.viewers) do
		for iSlot, slot in ipairs(vState.slots) do
			if slot.barSlot then
				CDM.RefreshBarSlot(slot)
			end
		end
	end
end

function CDM.RefreshCategorySlot(slot)
	local source = CDM.charVars.lastCategorySource[slot.categoryID]
	if source then
		slot.spellID      = source.spellID
		slot.itemID       = source.itemID
		slot.pressKeyType = source.spellID and "spell"
		slot.pressKeyID   = source.spellID
	end
end

function CDM.RefreshAllCategorySlots()
	for category, vState in pairs(CDM.viewers) do
		for iSlot, slot in ipairs(vState.slots) do
			if slot.categoryID then
				CDM.RefreshCategorySlot(slot)
			end
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

function CDM.OnAssistChange()
	CDM.showAssist = GetCVarBool("assistedCombatHighlight")
end

function CDM.ACTIONBAR_SLOT_CHANGED(barSlot)
	-- NOTE: Any spell with a cooldown causes this event (e.g. Whirling Surge and Aerial Halt)
	-- NOTE: Fires when a conditional macro changes state

	-- NOTE: There are two approaches we can use when CDM contents change: rebuild everything or
	-- reassign individual frames. Rebuilding is nice because it's simple. The downside is that it's
	-- expensive so we don't want to do it for something like a conditional macro on the skyriding
	-- viewer. Pressing a modifier key probably shouldn't be a full rebuild. So we pick a hybrid
	-- approach. We rebuild when adding or removing something, which is uncommon and happens when
	-- manually dragging abilities around. We reassign when an existing slot changes, which is the
	-- conditional macro case.

	local FIRST_SLOT = 121
	local LAST_SLOT  = 132

	if barSlot >= FIRST_SLOT and barSlot <= LAST_SLOT then
		for category, vState in pairs(CDM.viewers) do
			local slot = vState.slots[barSlot - FIRST_SLOT + 1]
			if slot and slot.barSlot == barSlot then
				local hadAction = slot.hasAction
				CDM.RefreshBarSlot(slot)

				local added   = not hadAction and     slot.hasAction
				local removed =     hadAction and not slot.hasAction
				local changed =     hadAction and     slot.hasAction

				if changed then
					local fState = vState.allFrames[slot.key]
					local spellChanged    = slot.spellID ~= fState.baseSpellID
					local itemChanged     = slot.itemID  ~= fState.itemID
					local pressKeyChanged = slot.pressKeyType ~= fState.pressKeyType or slot.pressKeyID ~= fState.pressKeyID
					if spellChanged or itemChanged or pressKeyChanged then
						CDM.ReassignFrame(fState, slot)
					else
						-- NOTE: There are cases where we need to refresh things even when the spell hasn't changed:
						-- * Macros can have custom icons and need to be updated when swapped with the same spell.
						-- * Different items can have the same spell (e.g. Algari Healing Potion).
						CDM.RefreshIcon(fState)
						CDM.RefreshCooldown(fState)
						CDM.RefreshQueued(fState)
						CDM.RefreshUsable(fState)
					end

				elseif added or removed then
					CDM.Rebuild("ACTIONBAR_SLOT_CHANGED")
				end
			end
		end

	elseif barSlot == 0 then
		CDM.Rebuild("ACTIONBAR_SLOT_CHANGED")
	end
end

function CDM.SPELL_UPDATE_USABLE()
	CDM.refreshAllUsable = true
end

function CDM.ACTIONBAR_UPDATE_USABLE()
	-- NOTE: We could use ACTION_USABLE_UPDATE which carries an array of changes as payload, but
	-- SPELL_UPDATE_USABLE already forces us to run the full RefreshAllUsable so we know it has to be
	-- fast enough to be acceptable.

	-- NOTE: Runs on the same frame as SPELL_UPDATE_USABLE about a third of the time, so deferred.
	CDM.refreshAllUsable = true
end

function CDM.PLAYER_CAN_GLIDE_CHANGED()
	CDM.ClearAllBlings()
	CDM.RefreshSkyriding()
	CDM.RefreshAllCooldowns()
end

function CDM.ADDON_RESTRICTION_STATE_CHANGED(type, state)
	-- NOTE: Only states Activating and Inactive are sent, not Active.
	local aurasSecret = state == Enum.AddOnRestrictionState.Activating or C_Secrets.ShouldAurasBeSecret()
	if CDM.aurasSecret and not aurasSecret then
		CDM.Rebuild("ADDON_RESTRICTION_STATE_CHANGED")
	end
	CDM.aurasSecret = aurasSecret
end

function CDM.SPELL_RANGE_CHECK_UPDATE(spellID, isInRange, checksRange)
	for fState in pairs(CDM.spellLookup[spellID] or {}) do
		CDM.RefreshUsable(fState)
	end
end

function CDM.BAG_UPDATE_COOLDOWN()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.activeFrames) do
			if fState.itemID or fState.barSlot then
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

	-- NOTE: Sometimes the item id isn't set
	if category and itemID then
		-- TODO: Do we need to save this to an account saved vars too?
		-- TODO: Move the saved var update to CDM.lua
		CDM.charVars.lastCategorySource[category] = { spellID = baseSpellID or spellID, itemID = itemID }

		for vCategory, vState in pairs(CDM.viewers) do
			for iFrame, fState in ipairs(vState.activeFrames) do
				if fState.categoryID == category then
					local slot = fState.slot
					CDM.RefreshCategorySlot(slot)

					local spellChanged = slot.spellID ~= fState.baseSpellID
					local itemChanged  = slot.itemID  ~= fState.itemID
					if spellChanged or itemChanged then
						CDM.ReassignFrame(fState, slot)
					end
				end
			end
		end
	end

	local hasCategory         = category and category ~= 0
	local hasRecoveryCategory = startRecoveryCategory and startRecoveryCategory ~= 0
	if hasCategory or hasRecoveryCategory or not spellID then
		CDM.refreshAllCooldowns = true
	else
		-- NOTE: Supposedly this event can arrive before the override event, so we need to check base
		for fState in pairs(CDM.spellLookup[baseSpellID or spellID] or {}) do
			CDM.RefreshCooldown(fState)
		end
	end
end

function CDM.SPELL_UPDATE_USES(spellID, baseSpellID)
	for fState in pairs(CDM.spellLookup[baseSpellID or spellID] or {}) do
		CDM.RefreshCooldown(fState)
	end
end

function CDM.CURRENT_SPELL_CAST_CHANGED(cancelledCast)
	CDM.RefreshAllQueued()
end

function CDM.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(spellID)
	for fState in pairs(CDM.spellLookup[spellID] or {}) do
		fState.Proc:Show()
	end
end

function CDM.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(spellID)
	for fState in pairs(CDM.spellLookup[spellID] or {}) do
		fState.Proc:Hide()
	end
end

function CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
	if overrideSpellID then
		CDM.activeOverrides[baseSpellID] = { overrideSpellID = overrideSpellID, time = GetTime() }
	else
		CDM.activeOverrides[baseSpellID] = nil
	end

	for fState in pairs(CDM.spellLookup[baseSpellID] or {}) do
		CDM.RefreshOverride(fState)
		CDM.RefreshAssist(fState)
	end
end

function CDM.SPELL_UPDATE_ICON(spellID)
	if spellID then
		for fState in pairs(CDM.spellLookup[spellID] or {}) do
			CDM.RefreshIcon(fState)
		end
	else
		CDM.RefreshAllIcons()
	end
end

function CDM.UPDATE_SHAPESHIFT_FORM()
	for spellID in pairs(CDM.formLookup) do
		for fState in pairs(CDM.spellLookup[spellID] or {}) do
			CDM.RefreshIcon(fState)
		end
	end
end

function CDM.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
	-- NOTE: We are not guaranteed to get a release after a press:
	-- Mouse down, drag off, mouse release                - no event
	-- Mouse down, drag off (far), drag on, mouse release - no event, was turned into a drag
	-- Mouse down, drag spell off bar, mouse release      - no event
	-- Key down, mouse down, mouse up, key up             - no event, any up cancels other events
	-- Key down, disable action bar, key up               - no event, includes action bar hiding
	-- Maybe if keybinding is programmatically changed while held?

	-- NOTE: Macros can cast/use multiple spells/items but there doesn't appear to be a way to get
	-- all of them. GetMacroSpell only returns one spellID.

	-- NOTE: This doesn't fire when clicking items in bags. They don't use a secure frame. We could
	-- hook button frames but it's a per-button hook instead of a global one.

	-- NOTE: Keybindings always send left mouse button.
	-- NOTE: Addon synthesized events send isKeyPress = nil.
	-- NOTE: When dragging a spell off a button it will no longer have an action.
	-- NOTE: We choose not to handle the action bar disable and binding change edge cases.

	local pressKeyType = nil
	local pressKeyID   = nil

	if down then
		local buttonType = SecureButton_GetModifiedAttribute(button, "type", mouseButton)
		if buttonType == "action" then
			local barSlot = button:CalculateAction(mouseButton)
			pressKeyType, pressKeyID = select(3, CDM.GetBarAction(barSlot, false))
		end
	end

	CDM.activePresses[button] = down and mouseButton or nil

	if button.klPressKeyType ~= pressKeyType or button.klPressKeyID ~= pressKeyID then
		local prevKeyID = button.klPressKeyID
		button.klPressKeyType = pressKeyType
		button.klPressKeyID   = pressKeyID

		for fState in pairs(CDM.pressKeyIDLookup[prevKeyID] or {}) do
			CDM.RefreshPress(fState)
		end
		for fState in pairs(CDM.pressKeyIDLookup[button.klPressKeyID] or {}) do
			CDM.RefreshPress(fState)
		end
	end
end

-- TODO: We want to rebuild in combat when a spell is added or removed
function CDM.OnCDMChanged()
	-- NOTE: Hook fires when events are being throttled. Wait for the unlock.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	if layoutMgr:AreNotificationsLocked() then return end

	-- NOTE: Spell overrides cause this event. We don't need to rebuild due to overrides and that
	-- would cause rebuilds in combat. I wish we could be more selective about when we get this
	-- event. Really, we only want it for non-combat related events like hotfixes, talent changes,
	-- and CDM settings changes.
	if InCombatLockdown() then return end

	CDM.Rebuild("OnCDMChanged")
end

----------------------------------------------------------------------------------------------------
-- File Load

CDM.Load()
