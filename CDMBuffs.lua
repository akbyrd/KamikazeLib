local Kami = select(2, ...)
local Buffs = {}
Kami.CDM.Buffs = Buffs

local CDM       = Kami.CDM
local Config    = Kami.Config
local Media     = Kami.Media
local PixelAnts = Kami.PixelAnts
local Util      = Kami.Util

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
			xPos       = Config.Size("0px"),
			yPos       = Config.Size("-337px"),
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
	Buffs.onTargetLookup   = {}
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

	fState.Container = CreateFrame("AuraContainer", nil, vState.Root, "CustomAuraContainerTemplate")
	fState.Container:SetAllPoints()

	fState.Container:AddAuraSlot(fState.slotKey, "HELPFUL",
		{
			initializeFrame = function(button)
				-- NOTE: Errors here are swallowed silently. This runs under securecallfunction.

				fState.Button = button
				fState.Button:EnableMouse(false)
				fState.Button:SetCollapsesLayout(true)

				fState.Icon = fState.Button:CreateTexture(nil, "ARTWORK")
				fState.Button:SetIcon(fState.Icon)

				fState.IconBorder = fState.Button:CreateTexture(nil, "OVERLAY")
				fState.IconBorder:SetParentKey("IconBorder")
				fState.IconBorder:SetPoint("BOTTOMLEFT")
				fState.IconBorder:SetTexture(Media.Border.texture, "CLAMP", "CLAMP", "NEAREST")
				fState.IconBorder:SetTextureSliceMargins(1, 1, 1, 1)

				fState.Bar = CreateFrame("StatusBar", nil, fState.Button)
				fState.Button:SetDurationBar(fState.Bar, { direction = Enum.StatusBarTimerDirection.RemainingTime })

				fState.BarBackground = fState.Bar:CreateTexture(nil, "BACKGROUND")
				fState.BarBackground:SetParentKey("Background")
				fState.BarBackground:SetAllPoints()

				fState.BarBorder = fState.Button:CreateTexture(nil, "OVERLAY")
				fState.BarBorder:SetParentKey("BarBorder")
				fState.BarBorder:SetPoint("BOTTOMLEFT")
				fState.BarBorder:SetTexture(Media.Border.texture, "CLAMP", "CLAMP", "NEAREST")
				fState.BarBorder:SetTextureSliceMargins(1, 1, 1, 1)

				fState.Pandemic = PixelAnts.Create(fState.Button)
				fState.Pandemic:SetParentKey("Pandemic")
				fState.Button:AddPandemicRegion(fState.Pandemic)
			end,
		})

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

	fState.auraSpellID = cdvInfo.linkedSpellIDs[1] or cdvInfo.spellID

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
	fState.auraSpellID = nil
	fState.spellCategory = nil
	fState.onTarget = nil
	fState.Button:ClearAllPoints()
	fState.Container:SetUnit("none")
	fState.Container:SetAuraSlotFilterString(fState.slotKey, "")
	fState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })
end

function Buffs.AssignFrames()
	wipe(Buffs.categoryLookup)
	wipe(Buffs.onTargetLookup)

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

			fState.Bar:SetStatusBarTexture(cfg.barTexture)
			fState.Bar:SetStatusBarColor(cfg.barColor:GetRGBA())
			fState.BarBackground:SetColorTexture(cfg.backgroundColor:GetRGBA())
			fState.BarBorder:SetVertexColor(cfg.borderColor:GetRGBA())
			fState.IconBorder:SetVertexColor(cfg.borderColor:GetRGBA())

			fState.Pandemic:SetConfig(
				nil,
				nil,
				fState.cfg.pandemicColor,
				fState.cfg.pandemicSpeed,
				fState.cfg.pandemicSegments,
				fState.cfg.pandemicDuty)
		end
	end

end

function Buffs.RefreshLayout()
	local pxSize, pySize = GetPhysicalScreenSize()

	for category, vState in pairs(Buffs.viewers) do
		-- TODO: Handle relative sizes
		local cfg           = vState.cfg
		local xPos          = Round(cfg.xPos          + cfg.xPosRel          * 0)
		local yPos          = Round(cfg.yPos          + cfg.yPosRel          * 0)
		local xSize         = Round(cfg.xSize         + cfg.xSizeRel         * 0)
		local ySize         = Round(cfg.ySize         + cfg.ySizeRel         * 0)
		local padSize       = Round(cfg.padSize       + cfg.padSizeRel       * 0)
		local borderSize    = Round(cfg.borderSize    + cfg.borderSizeRel    * 0)
		local pandemicSize  = Round(cfg.pandemicSize  + cfg.pandemicSizeRel  * 0)
		local pandemicInset = Round(cfg.pandemicInset + cfg.pandemicInsetRel * 0)
		local iconAspect    = cfg.iconAspect
		local iconZoom      = cfg.iconZoom

		local vxSize = cfg.xSize
		local vySize = #vState.cdFrames * (ySize + padSize) - padSize
		local vxPos  = xPos + Round((pxSize - vxSize) / 2)
		local vyPos  = yPos - Round(pySize / 2) + vySize
		vState.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
		vState.Root:SetSize(vxSize, vySize)
		vState.Base:SetHeight(max(1, abs(padSize)))
		vState.Base:SetPointsOffset(0, -padSize)

		for iFrame, fState in ipairs(vState.cdFrames) do
			fState.Button:ClearAllPoints()
		end

		for iFrame, fState in ipairs(vState.cdFrames) do
			local below  = vState.cdFrames[iFrame + 1]
			local anchor = below and below.Button or vState.Base
			fState.Button:SetSize(xSize, ySize)
			fState.Button:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT")
			fState.Button:SetPointsOffset(0, padSize)

			local xScale, yScale = Util.AspectScale(iconAspect)
			local ibxSize = Round(xScale / yScale * ySize)
			local ixSize  = ibxSize - 2*borderSize
			local iySize  = ySize   - 2*borderSize
			Util.ZoomIcon(fState.Icon, iconZoom, ixSize, iySize)
			fState.Icon:SetPoint("TOPLEFT",     fState.IconBorder, "TOPLEFT",      borderSize, -borderSize)
			fState.Icon:SetPoint("BOTTOMRIGHT", fState.IconBorder, "BOTTOMRIGHT", -borderSize,  borderSize)
			fState.IconBorder:SetSize(ibxSize / borderSize, ySize / borderSize)
			fState.IconBorder:SetScale(borderSize)

			local bbxPos  = (ibxSize - borderSize)
			local bbxSize = xSize - bbxPos
			fState.Bar:SetPoint("TOPLEFT",     fState.BarBorder, "TOPLEFT",      borderSize, -borderSize)
			fState.Bar:SetPoint("BOTTOMRIGHT", fState.BarBorder, "BOTTOMRIGHT", -borderSize,  borderSize)
			fState.BarBorder:SetPointsOffset(bbxPos / borderSize, 0)
			fState.BarBorder:SetSize(bbxSize / borderSize, ySize / borderSize)
			fState.BarBorder:SetScale(borderSize)

			fState.Pandemic:SetConfig(pandemicSize, pandemicInset, nil, nil, nil, nil)
			fState.Pandemic:RefreshSize(xSize, ySize)
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
	fState.auraSpellID = spellID
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
	-- false. These are not sensible values. So we check IsSpellHarmful/Helpful instead.

	-- NOTE: The list of spell ids can include both helpful and harmful spells. Usually this is a
	-- helpful ability as the main spell id and the harmful debuff it applies. But sometimes there's
	-- a spell that genuinely has both a helpful and harmful effect, like Piercing Howl. Blizzard
	-- will show both on the same bar (player first, then target). We prioritize the first linked
	-- spell, which appears to always give us the expected result. There are two Piercing Howl
	-- entires in the CDM settings specifically so you can choose between the helpful and harmful
	-- buffs and that works correctly with this approach.

	fState.onTarget = fState.auraSpellID and C_Spell.IsSpellHarmful(fState.auraSpellID)
	Buffs.onTargetLookup[fState] = fState.onTarget or nil

	local unit   = fState.onTarget and "target"          or "player"
	local filter = fState.onTarget and "HARMFUL|PLAYER"  or "HELPFUL|PLAYER" -- AuraUtil.AuraFilters
	fState.Container:SetUnit(unit)
	fState.Container:SetAuraSlotFilterString(fState.slotKey, filter)
	fState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })

	if not C_Secrets.ShouldAurasBeSecret() then
		fState.Bar:SetFillStyle(fState.onTarget and Enum.StatusBarFillStyle.Standard or Enum.StatusBarFillStyle.StandardNoRangeFill)
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
	for fState, onTarget in pairs(Buffs.onTargetLookup) do
		fState.Container:UpdateAllAuras()
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
