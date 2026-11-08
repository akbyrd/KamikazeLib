local Kami = select(2, ...)
local Buffs = {}
Kami.CDM.Buffs = Buffs

local CDM       = Kami.CDM
local Config    = Kami.Config
local Media     = Kami.Media
local PixelAnts = Kami.PixelAnts
local Util      = Kami.Util

local auraUnits = {
	{ unit = "player", filter = "HELPFUL|PLAYER", fillStyle = Enum.StatusBarFillStyle.StandardNoRangeFill },
	{ unit = "target", filter = "HARMFUL|PLAYER", fillStyle = Enum.StatusBarFillStyle.Standard            },
}

function Buffs.Init()
	Buffs.charVars = KLCharVars.CDM

	Buffs.cfgTree = Config.Create()

	Config.AddNode(Buffs.cfgTree, nil, "Default",
		{
			iconZoom   = Config.Number(0.08),
			iconAspect = Config.Number(2.5), -- TODO: Try making this width instead

			borderColor = Config.Color("FF000000"),
			borderSize  = Config.Size("1px"),

			pandemicColor    = Config.Color("FFFF3030"),
			pandemicInset    = Config.Size("0px"),
			pandemicSize     = Config.Size("2px"),
			pandemicSpeed    = Config.Number(0.05),
			pandemicSegments = Config.Number(8),
			pandemicDuty     = Config.Number(0.6),
		})
	Config.AddNode(Buffs.cfgTree, "Default", "TrackedBar",
		{
			xSize      = Config.Size("514px"),
			ySize      = Config.Size("16px"),
			padSize    = Config.Size("-1px"),

			barColor        = Config.Color("FF4F4F4F"),
			barTexture      = Config.Texture("statusbar", "ElvUI Norm", "Solid"),
			backgroundColor = Config.Color("80000000"),
		})

	Config.AddNode(Buffs.cfgTree, "TrackedBar", "Defensive",
		{
			barColor = Config.Color("FF4232C6"),
		})

	Config.AddNode(Buffs.cfgTree, "TrackedBar", "Offensive",
		{
			barColor = Config.Color("FFC91309"),
		})

	Config.AddNode(Buffs.cfgTree, nil, "FilterCategories",
		{
			SpellCategory = Config.Table({
				[CDM.db.Category.CombatPotion] = Config.String("Offensive"),
			}),

			Ability = Config.Table({
				[CDM.db.WARRIOR.Ability.Avatar]        = Config.String("Offensive"),
				[CDM.db.WARRIOR.Ability.Bladestorm]    = Config.String("Offensive"),
				[CDM.db.WARRIOR.Ability.ColossusSmash] = Config.String("Offensive"),

				[CDM.db.WARRIOR.Ability.DieByTheSword]   = Config.String("Defensive"),
				[CDM.db.WARRIOR.Ability.RallyingCry]     = Config.String("Defensive"),
				[CDM.db.WARRIOR.Ability.SpellReflection] = Config.String("Defensive"),
				[CDM.db.WARRIOR.Ability.DefensiveStance] = Config.String("Defensive"),
			}),
		})

	local categoryToName = EnumUtil.GenerateNameTranslation(Enum.CooldownViewerCategory)

	local viewerCategories = {
		Enum.CooldownViewerCategory.TrackedBar,
	}

	Buffs.viewers = {}
	for index, category in ipairs(viewerCategories) do
		local categoryName = categoryToName(category)

		local Root = CreateFrame("Frame", nil, UIParent)
		Root:SetParentKey(("Kami.CDM.Buffs.%s.Root"):format(categoryName))

		local Base = CreateFrame("Frame", nil, Root)
		Base:SetParentKey("Base")
		Base:SetPoint("TOPLEFT",  Root, "BOTTOMLEFT")
		Base:SetPoint("TOPRIGHT", Root, "BOTTOMRIGHT")

		local vState = {
			name     = categoryName,
			cfg      = Config.GetBranch(Buffs.cfgTree, categoryName),
			Root     = Root,
			Base     = Base,
			cdvInfos = {},
			cdFrames = {},
			pool     = {},
		}
		Buffs.viewers[category] = vState
	end

	Buffs.categoryLookup   = {}
	Buffs.filterCategories = Config.GetBranch(Buffs.cfgTree, "FilterCategories")

	Buffs.Rebuild()
end

function Buffs.Rebuild()
	-- NOTE: Keys (and certain other content) are restricted the whole time. We can't touch the Aura
	-- Containers.
	if C_Secrets.ShouldAurasBeSecret() then return end

	CDM.GatherCDs(Buffs.viewers)

	-- TODO: RefreshScale is first because it's responsible for Config.RefreshValues. That seems a
	-- bit weird. If we make config a dedicated operation we can move RefreshScale into
	-- RefreshLayout (same for CDMCooldowns)

	Buffs.RefreshScale()
	Buffs.AssignFrames()
	Buffs.RefreshAllConfig()
	Buffs.RefreshLayout()
	Buffs.RefreshVisible()
	Buffs.RefreshAllCategories()
	Buffs.RefreshAllAuras()
end

function Buffs.ConstructFrame(vState)
	local fState = {}
	fState.slotKey  = tostring(fState)
	fState.spellIDs = {}
	fState.units    = {}

	for iUnit, auraUnit in ipairs(auraUnits) do
		local uState = {}
		uState.unit      = auraUnit.unit
		uState.filter    = auraUnit.filter
		uState.fillStyle = auraUnit.fillStyle

		uState.Container = CreateFrame("AuraContainer", nil, vState.Root, "CustomAuraContainerTemplate")
		uState.Container:SetAllPoints()

		uState.Container:AddAuraSlot(fState.slotKey, "HELPFUL",
			{
				initializeFrame = function(button)
					-- NOTE: Errors here are swallowed silently. This runs under securecallfunction.

					uState.Button = button
					uState.Button:EnableMouse(false)
					uState.Button:SetCollapsesLayout(true)

					uState.Icon = uState.Button:CreateTexture(nil, "ARTWORK")
					uState.Button:SetIcon(uState.Icon)

					uState.IconBorder = uState.Button:CreateTexture(nil, "OVERLAY")
					uState.IconBorder:SetParentKey("IconBorder")
					uState.IconBorder:SetPoint("BOTTOMLEFT")
					uState.IconBorder:SetTexture(Media.Border.texture, "CLAMP", "CLAMP", "NEAREST")
					uState.IconBorder:SetTextureSliceMargins(1, 1, 1, 1)

					uState.Bar = CreateFrame("StatusBar", nil, uState.Button)
					uState.Button:SetDurationBar(uState.Bar, { direction = Enum.StatusBarTimerDirection.RemainingTime })

					uState.BarBackground = uState.Bar:CreateTexture(nil, "BACKGROUND")
					uState.BarBackground:SetParentKey("Background")
					uState.BarBackground:SetAllPoints()

					uState.BarBorder = uState.Button:CreateTexture(nil, "OVERLAY")
					uState.BarBorder:SetParentKey("BarBorder")
					uState.BarBorder:SetPoint("BOTTOMLEFT")
					uState.BarBorder:SetTexture(Media.Border.texture, "CLAMP", "CLAMP", "NEAREST")
					uState.BarBorder:SetTextureSliceMargins(1, 1, 1, 1)

					uState.Pandemic = PixelAnts.Create(uState.Button)
					uState.Pandemic:SetParentKey("Pandemic")
					uState.Button:AddPandemicRegion(uState.Pandemic)
				end,
			})

		table.insert(fState.units, uState)
		fState.units[uState.unit] = uState
	end

	return fState
end

function Buffs.EnableFrame(fState, cdvInfo, vState)
	fState.spellCategory = cdvInfo.spellCategoryID
	if fState.spellCategory then
		Buffs.categoryLookup[fState.spellCategory] = fState
	end

	fState.baseSpellID = cdvInfo.spellID
	fState.spellID     = cdvInfo.spellID

	-- NOTE: Category slots (e.g. Combat Potion) don't have a spell id
	if cdvInfo.spellID then
		fState.spellIDs[cdvInfo.spellID] = true
		Buffs.SetOverride(fState, C_Spell.GetOverrideSpell(cdvInfo.spellID))
	end
	for iLinked, linkedSpellID in ipairs(cdvInfo.linkedSpellIDs) do
		fState.spellIDs[linkedSpellID] = true
	end

	local filterCategory = Buffs.filterCategories.SpellCategory[fState.spellCategory]
	for spellID, v in pairs(fState.spellIDs) do
		filterCategory = filterCategory or Buffs.filterCategories.Ability[spellID]
	end
	fState.cfg = filterCategory and Config.GetBranch(Buffs.cfgTree, filterCategory) or vState.cfg
end

function Buffs.DisableFrame(fState)
	wipe(fState.spellIDs)
	fState.baseSpellID = nil
	fState.spellID = nil
	fState.cfg = nil
	fState.spellCategory = nil
	for iUnit, uState in ipairs(fState.units) do
		uState.Button:ClearAllPoints()
		uState.Container:SetUnit("none")
		uState.Container:SetAuraSlotFilterString(fState.slotKey, "")
		uState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })
	end
end

function Buffs.AssignFrames()
	wipe(Buffs.categoryLookup)

	for category, vState in pairs(Buffs.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.cdFrames) do
			Buffs.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end
		wipe(vState.cdFrames)

		-- Construct new frames (if needed)
		local have = #vState.pool
		local need = #vState.cdvInfos
		for iNeed = have + 1, need do
			local fState = Buffs.ConstructFrame(vState)
			table.insert(vState.pool, fState)
		end

		-- Enable new frames
		for iInfo, cdvInfo in ipairs(vState.cdvInfos) do
			local fState = table.remove(vState.pool)
			Buffs.EnableFrame(fState, cdvInfo, vState)
			table.insert(vState.cdFrames, fState)
		end
	end
end

function Buffs.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	for category, vState in pairs(Buffs.viewers) do
		vState.Root:SetScale(pixelsToUI)
	end

	Config.RefreshValues(Buffs.cfgTree, pixelsToUI)
end

function Buffs.RefreshAllConfig()
	for category, vState in pairs(Buffs.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			local cfg = fState.cfg

			for iUnit, uState in ipairs(fState.units) do
				uState.Bar:SetStatusBarTexture(cfg.barTexture)
				uState.Bar:SetStatusBarColor(cfg.barColor:GetRGBA())
				uState.BarBackground:SetColorTexture(cfg.backgroundColor:GetRGBA())
				uState.BarBorder:SetVertexColor(cfg.borderColor:GetRGBA())
				uState.IconBorder:SetVertexColor(cfg.borderColor:GetRGBA())

				uState.Pandemic:SetConfig(
					nil,
					nil,
					fState.cfg.pandemicColor,
					fState.cfg.pandemicSpeed,
					fState.cfg.pandemicSegments,
					fState.cfg.pandemicDuty)
			end
		end
	end

end

function Buffs.RefreshLayout()
	for category, vState in pairs(Buffs.viewers) do
		-- TODO: Handle relative sizes
		local cfg           = vState.cfg
		local xSize         = Round(cfg.xSize         + cfg.xSizeRel         * 0)
		local ySize         = Round(cfg.ySize         + cfg.ySizeRel         * 0)
		local padSize       = Round(cfg.padSize       + cfg.padSizeRel       * 0)
		local borderSize    = Round(cfg.borderSize    + cfg.borderSizeRel    * 0)
		local pandemicSize  = Round(cfg.pandemicSize  + cfg.pandemicSizeRel  * 0)
		local pandemicInset = Round(cfg.pandemicInset + cfg.pandemicInsetRel * 0)
		local iconAspect    = cfg.iconAspect
		local iconZoom      = cfg.iconZoom

		local vxSize = cfg.xSize
		local vySize = #vState.cdFrames * #auraUnits * (ySize + padSize) - padSize
		vState.Root:SetSize(vxSize, vySize)
		vState.Base:SetHeight(max(1, abs(padSize)))
		vState.Base:SetPointsOffset(0, -padSize)

		for iFrame, fState in ipairs(vState.cdFrames) do
			for iUnit, uState in ipairs(fState.units) do
				uState.Button:ClearAllPoints()
			end
		end

		for iFrame, fState in ipairs(vState.cdFrames) do
			local below  = vState.cdFrames[iFrame + 1]
			local anchor = below and below.units[1].Button or vState.Base
			for iUnit = #fState.units, 1, -1 do
				local uState = fState.units[iUnit]
				uState.Button:SetSize(xSize, ySize)
				uState.Button:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT")
				uState.Button:SetPointsOffset(0, padSize)
				anchor = uState.Button

				local xScale, yScale = Util.AspectScale(iconAspect)
				local ibxSize = Round(xScale / yScale * ySize)
				local ixSize  = ibxSize - 2*borderSize
				local iySize  = ySize   - 2*borderSize
				Util.ZoomIcon(uState.Icon, iconZoom, ixSize, iySize)
				uState.Icon:SetPoint("TOPLEFT",     uState.IconBorder, "TOPLEFT",      borderSize, -borderSize)
				uState.Icon:SetPoint("BOTTOMRIGHT", uState.IconBorder, "BOTTOMRIGHT", -borderSize,  borderSize)
				uState.IconBorder:SetSize(ibxSize / borderSize, ySize / borderSize)
				uState.IconBorder:SetScale(borderSize)

				local bbxPos  = (ibxSize - borderSize)
				local bbxSize = xSize - bbxPos
				uState.Bar:SetPoint("TOPLEFT",     uState.BarBorder, "TOPLEFT",      borderSize, -borderSize)
				uState.Bar:SetPoint("BOTTOMRIGHT", uState.BarBorder, "BOTTOMRIGHT", -borderSize,  borderSize)
				uState.BarBorder:SetPointsOffset(bbxPos / borderSize, 0)
				uState.BarBorder:SetSize(bbxSize / borderSize, ySize / borderSize)
				uState.BarBorder:SetScale(borderSize)

				uState.Pandemic:SetConfig(pandemicSize, pandemicInset, nil, nil, nil, nil)
				uState.Pandemic:RefreshSize(xSize, ySize)
			end
		end
	end
end

function Buffs.RefreshVisible()
	local hasBar = CDM.GetActionBarOverride() ~= nil
	for category, vState in pairs(Buffs.viewers) do
		vState.Root:SetShown(not hasBar)
	end
end

function Buffs.SetOverride(fState, spellID)
	-- Remove the current override
	if fState.spellID ~= fState.baseSpellID then
		fState.spellIDs[fState.spellID] = nil
		fState.spellID = fState.baseSpellID
	end

	-- Apply the new override (or revert back to base)
	if spellID and spellID ~= fState.spellID then
		fState.spellIDs[spellID] = true
		fState.spellID = spellID
	end
end

function Buffs.RefreshCategory(fState, spellID)
	wipe(fState.spellIDs)
	fState.spellIDs[spellID] = true
end

function Buffs.RefreshAllCategories()
	for category, vState in pairs(Buffs.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellCategory then
				local lastSource = Buffs.charVars.lastCategorySource[fState.spellCategory]
				if lastSource then
					Buffs.RefreshCategory(fState, lastSource.spellID)
				end
			end
		end
	end
end

function Buffs.RefreshAuras(fState)
	-- NOTE: selfAura and hasAura are unreliable. Colossus Smash selfAura is true. Avatar hasAura is
	-- false. These are not sensible values.

	-- NOTE: IsSpellHelpful and IsSpellHarmful are unreliable. Slice and Dice is classified harmful.

	-- NOTE: The list of spell ids can include both helpful and harmful spells. Usually this is a
	-- helpful ability as the main spell id and the harmful debuff it applies. But sometimes there's
	-- a spell that genuinely has both a helpful and harmful effect, like Piercing Howl. Blizzard
	-- will show both on the same bar (player first, then target). There are two Piercing Howl
	-- entires in the CDM settings specifically so you can choose between the helpful and harmful
	-- buffs.

	for iUnit, uState in ipairs(fState.units) do
		uState.Container:SetUnit(uState.unit)
		uState.Container:SetAuraSlotFilterString(fState.slotKey, uState.filter)
		uState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })

		if not C_Secrets.ShouldAurasBeSecret() then
			uState.Bar:SetFillStyle(uState.fillStyle)
		end
	end
end

function Buffs.RefreshAllAuras()
	for category, vState in pairs(Buffs.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			Buffs.RefreshAuras(fState)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function Buffs.PLAYER_REGEN_ENABLED()
	Buffs.Rebuild()
end

function Buffs.PLAYER_TARGET_CHANGED()
	for category, vState in pairs(Buffs.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			fState.units.target.Container:UpdateAllAuras()
		end
	end
end

function Buffs.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	local fState = Buffs.categoryLookup[category]
	if fState then
		if not fState.spellIDs[spellID] then
			Buffs.RefreshCategory(fState, spellID)
			Buffs.RefreshAuras(fState)
		end
	end
end

function Buffs.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
	for category, vState in pairs(Buffs.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.baseSpellID == baseSpellID then
				Buffs.SetOverride(fState, overrideSpellID)
				Buffs.RefreshAuras(fState)
			end
		end
	end
end

function Buffs.OnScaleChanged()
	Buffs.RefreshScale()
	Buffs.RefreshLayout()
end

function Buffs.OnActionBarChanged()
	Buffs.RefreshVisible()
end

function Buffs.OnCDMChanged()
	Buffs.Rebuild()
end

-- TODO: The flicker happens when tabbing between targets with Rend
-- TODO: Come up with better naming. self? buffs/cds?
