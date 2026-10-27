local Kami = select(2, ...)
local CDM = {}
Kami.CDM = CDM

local CDs
local Buffs
local Res

function CDM.Load()
	KLSavedVars.CDM = KLSavedVars.CDM or {}
	KLCharVars.CDM  = KLCharVars.CDM  or {}

	KLCharVars.CDM.lastCategorySource = KLCharVars.CDM.lastCategorySource or {}

	CDM.db = {
		-- https://wago.tools/db2/SpellCategory
		Category = {
			GCD          = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY, -- 133
			CombatPotion = Constants.SpellCooldownConsts.COMBAT_POTION_CATEGORY,   -- 4
			HealthPotion = Constants.SpellCooldownConsts.HEALTH_POTION_CATEGORY,   -- 30
			Healthstone  = Constants.SpellCooldownConsts.HEALTHSTONE_CATEGORY,     -- 1711
			Bloodstone   = 2566,
			SkyridingGCD = 2316,
		},

		Misc = {
			ThrillOfTheSkies  = 377234,
			SkyridingBarIndex = 11,
		},

		WARRIOR = {
			Ability = {
				Avatar          = 107574,
				Bladestorm      = 446035,
				ColossusSmash   = 167105,
				DieByTheSword   = 118038,
				RallyingCry     = 97462,
				SpellReflection = 23920,
				Rend            = 772,
				DefensiveStance = 386208,
				MortalStrike    = 12294,
				Overpower       = 7384,
				Execute         = 163201,
				Cleave          = 845,
				Slam            = 1464,
				HeroicStrike    = 1269383,
			},

			Aura = {
				MasterOfWarfareProc   = 1269391,
				MasterOfWarfareBuff   = 1269394,
				Opportunist           = 456120,
				CollateralDamage      = 334783,
				ImminentDemise        = 445606,
				WindingUp             = 1300670,
				Executioner           = 445584,
				ExecutionersPrecision = 386633,
			},

			Talent = {
				Bladestorm = 227847,
			},
		},
	}

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Event")
	CDM.eventFrame:SetScript("OnEvent", CDM.DispatchEvent)
	CDM.RegisterEvent("PLAYER_LOGIN", CDM.PLAYER_LOGIN)
	hooksecurefunc("SecureActionButton_OnClick", CDM.OnClick)
end

function CDM.Init()
	CDs   = CDM.Cooldowns
	Buffs = CDM.Buffs
	Res   = CDM.Resources

	CDM.RegisterEvent("UI_SCALE_CHANGED",                       CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",                   CDM.OnScaleChanged)
	CDM.RegisterEvent("UPDATE_VEHICLE_ACTIONBAR",               CDM.OnActionBarChanged)
	CDM.RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR",              CDM.OnActionBarChanged)
	CDM.RegisterEvent("UPDATE_BONUS_ACTIONBAR",                 CDM.OnActionBarChanged)
	CDM.RegisterEvent("ACTIONBAR_SLOT_CHANGED",                 CDs.ACTIONBAR_SLOT_CHANGED)
	CDM.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED",        CDs.ADDON_RESTRICTION_STATE_CHANGED)
	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN",                  CDM.SPELL_UPDATE_COOLDOWN)
	CDM.RegisterEvent("BAG_UPDATE_COOLDOWN",                    CDs.BAG_UPDATE_COOLDOWN)
	CDM.RegisterEvent("SPELL_UPDATE_USES",                      CDs.SPELL_UPDATE_USES)
	CDM.RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED)
	CDM.RegisterEvent("SPELL_UPDATE_ICON",                      CDs.SPELL_UPDATE_ICON)
	CDM.RegisterEvent("UPDATE_SHAPESHIFT_FORM",                 CDs.UPDATE_SHAPESHIFT_FORM)
	CDM.RegisterEvent("SPELL_UPDATE_USABLE",                    CDs.SPELL_UPDATE_USABLE)
	CDM.RegisterEvent("ACTIONBAR_UPDATE_USABLE",                CDs.ACTIONBAR_UPDATE_USABLE)
	CDM.RegisterEvent("SPELL_RANGE_CHECK_UPDATE",               CDs.SPELL_RANGE_CHECK_UPDATE)
	CDM.RegisterEvent("ACTION_RANGE_CHECK_UPDATE",              CDs.ACTION_RANGE_CHECK_UPDATE)
	CDM.RegisterEvent("CURRENT_SPELL_CAST_CHANGED",             CDs.CURRENT_SPELL_CAST_CHANGED)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",     CDs.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",     CDs.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
	CDM.RegisterEvent("PLAYER_REGEN_ENABLED",                   Buffs.PLAYER_REGEN_ENABLED)
	CDM.RegisterEvent("PLAYER_TARGET_CHANGED",                  Buffs.PLAYER_TARGET_CHANGED)
	CDM.RegisterUnitEvent("UNIT_DISPLAYPOWER",                  Res.UNIT_DISPLAYPOWER,     "player", "vehicle", "pet")
	CDM.RegisterUnitEvent("UNIT_MAXPOWER",                      Res.UNIT_MAXPOWER,         "player", "vehicle", "pet")
	CDM.RegisterUnitEvent("UNIT_POWER_FREQUENT",                Res.UNIT_POWER_FREQUENT,   "player", "vehicle", "pet")
	CDM.RegisterUnitEvent("UNIT_ENTERED_VEHICLE",               Res.UNIT_ENTERED_VEHICLE,  "player")
	CDM.RegisterUnitEvent("UNIT_SPELLCAST_START",               Res.UNIT_SPELLCAST_START,  "player", "vehicle", "pet")
	CDM.RegisterUnitEvent("UNIT_SPELLCAST_STOP",                Res.UNIT_SPELLCAST_STOP,   "player", "vehicle", "pet")
	CDM.RegisterUnitEvent("UNIT_SPELLCAST_FAILED",              Res.UNIT_SPELLCAST_FAILED, "player", "vehicle", "pet")

	SecureStateDriverManager:HookScript("OnUpdate", CDM.Update)
	hooksecurefunc(UIParent, "SetScale", CDM.OnScaleChanged)

	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.OnCDMChanged)
end

function CDM.GatherCDs(viewers)
	for category, vState in pairs(viewers) do
		wipe(vState.cdvInfos)
	end

	local categoryOverrides = {} -- cooldownID -> user category, deviations from the default
	local positionOverrides = {} -- cooldownID -> boolean,       deviations from the default

	local function AddCD(cooldownID)
		local cdvInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) -- CooldownViewerCooldown
		if cdvInfo and cdvInfo.isKnown then
			local hidden   = FlagsUtil.IsSet(cdvInfo.flags, Enum.CooldownSetSpellFlags.HideByDefault)
			local category = categoryOverrides[cooldownID] or (hidden and -1 or cdvInfo.category)

			local vState = viewers[category]
			if vState then
				table.insert(vState.cdvInfos, cdvInfo)
			end
		end
	end

	-- Don't use dataProvider:GetLayoutManager(). It has a lazy resolve and will taint.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	local layout    = layoutMgr:GetActiveLayout(Enum.CDMLayoutMode.AccessOnly)
	if layout then

		-- User category overrides
		local layoutInfo = CooldownManagerLayout_GetCooldownInfo(layout, false)
		if layoutInfo then -- nil when no user overrides
			for cooldownID, block in pairs(layoutInfo) do
				-- Apparently block.category can be a string sometimes?
				categoryOverrides[cooldownID] = tonumber(block.category)
			end
		end

		-- User position overrides
		local orderedCooldownIDs = CooldownManagerLayout_GetOrderedCooldownIDs(layout)
		if orderedCooldownIDs then -- nil when no user overrides
			for iCooldown, cooldownID in ipairs(orderedCooldownIDs) do
				positionOverrides[cooldownID] = true
				AddCD(cooldownID)
			end
		end
	end

	-- All spells/items, default ordering
	for iCategory, category in ipairs(CooldownViewerSettingsDataProvider_GetCategories()) do
		local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
		for iCooldown, cooldownID in ipairs(cooldownIDs) do
			if not positionOverrides[cooldownID] then
				AddCD(cooldownID)
			end
		end
	end
end

function CDM.GetActionBarOverride()
	local db = CDM.db

	if C_ActionBar.HasVehicleActionBar() then
		local unit = C_ActionBar.IsPossessBarVisible() and "pet" or "vehicle"
		return C_ActionBar.GetVehicleBarIndex(), unit
	elseif C_ActionBar.HasOverrideActionBar() then
		return C_ActionBar.GetOverrideBarIndex(), "player"
	elseif C_ActionBar.HasTempShapeshiftActionBar() then
		return C_ActionBar.GetTempShapeshiftBarIndex(), "player"
	elseif C_ActionBar.GetBonusBarIndex() == db.Misc.SkyridingBarIndex then
		return db.Misc.SkyridingBarIndex, "player"
	end
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

function CDM.PLAYER_LOGIN()
	CDM.Init()
	CDs.Init()
	Buffs.Init()
	Res.Init()
end

function CDM.OnScaleChanged()
	CDs.OnScaleChanged()
	Buffs.OnScaleChanged()
	Res.OnScaleChanged()
end

function CDM.OnActionBarChanged()
	CDs.OnActionBarChanged()
	Buffs.OnActionBarChanged()
	Res.OnActionBarChanged()
end

function CDM.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
	CDs.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
end

function CDM.Update()
	CDs.Update()
	Res.Update()
end

function CDM.OnCDMChanged()
	-- NOTE: Hook fires when events are being throttled. Wait for the unlock.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	if layoutMgr:AreNotificationsLocked() then return end

	CDs.OnCDMChanged()
	Buffs.OnCDMChanged()
end

function CDM.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	CDs.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	Buffs.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
end

function CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
	CDs.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
	Buffs.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
end

----------------------------------------------------------------------------------------------------
-- File Load

CDM.Load()
