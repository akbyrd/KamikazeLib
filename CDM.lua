local Kami = select(2, ...)
local CDM = {}
Kami.CDM = CDM

function CDM.Load()
	KLSavedVars.CDM = KLSavedVars.CDM or {}
	KLCharVars.CDM  = KLCharVars.CDM  or {}

	KLCharVars.CDM.lastCategorySource = KLCharVars.CDM.lastCategorySource or {}

	CDM.db = {
		Category = {
			GCD          = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY,
			CombatPotion = Constants.SpellCooldownConsts.COMBAT_POTION_CATEGORY,
			HealthPotion = Constants.SpellCooldownConsts.HEALTH_POTION_CATEGORY,
			Healthstone  = Constants.SpellCooldownConsts.HEALTHSTONE_CATEGORY,
			SkyridingGCD = 2316,
		},

		Misc = {
			ThrillOfTheSkies = 377234,
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

CDM.Load()
