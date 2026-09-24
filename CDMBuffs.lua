local Kami = select(2, ...)
local CDM = {}
Kami.CDM.Buffs = CDM

local Config    = Kami.Config
local PixelAnts = Kami.PixelAnts
local Util      = Kami.Util

function CDM.Load()
	CDM.charVars = KLCharVars.CDM

	CDM.cfgTree = Config.Create()
	Config.AddNode(CDM.cfgTree, nil, "Default",
		{
			iconZoom   = Config.Number(0.08),
			iconAspect = Config.Number(2.5), -- TODO: Try making this width instead

			borderColor = Config.Color("FF000000"),
			borderSize  = Config.Size("1px"),

			pandemicColor    = Config.Color("FFFF3030"),
			pandemicInset    = Config.Size("0px"),
			pandemicSize     = Config.Size("1px"),
			pandemicSpeed    = Config.Number(0.05),
			pandemicSegments = Config.Number(8),
			pandemicDuty     = Config.Number(0.6),
		})
	Config.AddNode(CDM.cfgTree, "Default", "TrackedBar",
		{
			xPos     = Config.Size("0px"),
			yPos     = Config.Size("-335px"),
			xSize    = Config.Size("514px"),
			ySize    = Config.Size("16px"),
			padSize  = Config.Size("-1px"),
			barColor = Config.Color("FF4F4F4F"),
		})

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Buffs.Event")
	CDM.eventFrame:SetScript("OnEvent",        CDM.DispatchEvent)
	CDM.RegisterEvent("UI_SCALE_CHANGED",      CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",  CDM.OnScaleChanged)
	CDM.RegisterEvent("PLAYER_REGEN_ENABLED",  CDM.PLAYER_REGEN_ENABLED)
	CDM.RegisterEvent("PLAYER_TARGET_CHANGED", CDM.PLAYER_TARGET_CHANGED)
	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN", CDM.SPELL_UPDATE_COOLDOWN)
	hooksecurefunc(UIParent, "SetScale",       CDM.OnScaleChanged)

	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.OnCDMChanged)

	local categoryToName = EnumUtil.GenerateNameTranslation(Enum.CooldownViewerCategory)

	local categories = {
		Enum.CooldownViewerCategory.TrackedBar,
	}

	CDM.viewers = {}
	for index, category in ipairs(categories) do
		local categoryName = categoryToName(category)

		local Root = CreateFrame("Frame", nil, UIParent)
		Root:SetParentKey(("Kami.CDM.Buffs.%s.Root"):format(categoryName))

		local vState = {
			name     = categoryName,
			cfg      = Config.GetBranch(CDM.cfgTree, categoryName),
			Root     = Root,
			cdvInfos = {},
			cdFrames = {},
			pool     = {},
		}
		CDM.viewers[category] = vState
	end

	CDM.categoryLookup = {}
	CDM.onTargetLookup = {}

	CDM.Rebuild()
end

function CDM.Rebuild()
	-- NOTE: Keys (and certain other content) are restricted the whole time. We can't touch the Aura
	-- Containers.
	if C_Secrets.ShouldAurasBeSecret() then return end

	Kami.CDM.GatherCDs(CDM.viewers)

	-- TODO: RefreshScale is first because it's responsible for Config.RefreshValues. That seems a
	-- bit weird. If we make config a dedicated operation we can move RefreshScale into
	-- RefreshLayout (same for CDMCooldowns)

	CDM.RefreshScale()
	CDM.AssignFrames()
	CDM.RefreshAllConfig()
	CDM.RefreshLayout()
	CDM.RefreshAllCategories()
	CDM.RefreshAllAuras()
end

function CDM.ConstructFrame(vState)
	local fState = {}
	fState.cfg      = vState.cfg
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
				fState.IconBorder:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
				fState.IconBorder:SetTextureSliceMargins(1, 1, 1, 1)

				fState.Bar = CreateFrame("StatusBar", nil, fState.Button)
				fState.Button:SetDurationBar(fState.Bar, { direction = Enum.StatusBarTimerDirection.RemainingTime })

				fState.BarBorder = fState.Button:CreateTexture(nil, "OVERLAY")
				fState.BarBorder:SetParentKey("BarBorder")
				fState.BarBorder:SetPoint("BOTTOMLEFT")
				fState.BarBorder:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
				fState.BarBorder:SetTextureSliceMargins(1, 1, 1, 1)

				fState.Pandemic = PixelAnts.Create(fState.Button)
				fState.Pandemic:SetParentKey("Pandemic")
				fState.Button:AddPandemicRegion(fState.Pandemic)
			end,
		})

	return fState
end

function CDM.EnableFrame(fState, cdvInfo)
	fState.categoryID = cdvInfo.spellCategoryID
	if fState.categoryID then
		CDM.categoryLookup[fState.categoryID] = fState
	end

	-- NOTE: Category slots (e.g. Combat Potion) don't have a spell id
	if cdvInfo.spellID then
		fState.spellIDs[cdvInfo.spellID] = true
	end
	for iLinked, linkedSpellID in ipairs(cdvInfo.linkedSpellIDs) do
		fState.spellIDs[linkedSpellID] = true
	end
end

function CDM.DisableFrame(fState)
	wipe(fState.spellIDs)
	fState.categoryID = nil
	fState.onTarget = nil
	fState.Button:ClearAllPoints()
	fState.Container:SetUnit("none")
	fState.Container:SetAuraSlotFilterString(fState.slotKey, "")
	fState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })
end

function CDM.AssignFrames()
	wipe(CDM.categoryLookup)
	wipe(CDM.onTargetLookup)

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
			table.insert(vState.pool, fState)
		end

		-- Enable new frames
		for iInfo, cdvInfo in ipairs(vState.cdvInfos) do
			local fState = table.remove(vState.pool)
			CDM.EnableFrame(fState, cdvInfo)
			table.insert(vState.cdFrames, fState)
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

function CDM.RefreshAllConfig()
	for category, vState in pairs(CDM.viewers) do
		local cfg = vState.cfg

		for iFrame, fState in ipairs(vState.cdFrames) do
			fState.Bar:SetColorFill(cfg.barColor:GetRGBA())
			fState.IconBorder:SetVertexColor(cfg.borderColor:GetRGBA())
			fState.BarBorder:SetVertexColor(cfg.borderColor:GetRGBA())

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

function CDM.RefreshLayout()
	local pxSize, pySize = GetPhysicalScreenSize()

	for category, vState in pairs(CDM.viewers) do
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

		for iFrame, fState in ipairs(vState.cdFrames) do
			fState.Button:ClearAllPoints()
		end

		for iFrame, fState in ipairs(vState.cdFrames) do
			local below  = vState.cdFrames[iFrame + 1]
			local anchor = below and below.Button or vState.Root
			local point  = below and "TOPLEFT" or "BOTTOMLEFT"
			fState.Button:SetSize(xSize, ySize)
			fState.Button:SetPoint("BOTTOMLEFT", anchor, point)
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

function CDM.RefreshCategory(fState, spellID)
	wipe(fState.spellIDs)
	fState.spellIDs[spellID] = true
end

function CDM.RefreshAllCategories()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.categoryID then
				local lastSource = CDM.charVars.lastCategorySource[fState.categoryID]
				if lastSource then
					CDM.RefreshCategory(fState, lastSource.spellID)
				end
			end
		end
	end
end

function CDM.RefreshAuras(fState)
	-- NOTE: selfAura and hasAura are unreliable. Colossus Smash selfAura is true. Avatar hasAura is
	-- false. These are not sensible values. So we check IsSpellHarmful/Helpful instead.

	local harmful = false
	local helpful = false
	for spellID in pairs(fState.spellIDs) do
		harmful = harmful or C_Spell.IsSpellHarmful(spellID)
		helpful = helpful or C_Spell.IsSpellHelpful(spellID)
	end

	fState.onTarget = harmful and not helpful
	CDM.onTargetLookup[fState] = fState.onTarget or nil

	local unit   = fState.onTarget and "target"          or "player"
	local filter = fState.onTarget and "HARMFUL|PLAYER"  or "HELPFUL|PLAYER" -- AuraUtil.AuraFilters
	fState.Container:SetUnit(unit)
	fState.Container:SetAuraSlotFilterString(fState.slotKey, filter)
	fState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })

	if not C_Secrets.ShouldAurasBeSecret() then
		fState.Bar:SetFillStyle(fState.onTarget and Enum.StatusBarFillStyle.Standard or Enum.StatusBarFillStyle.StandardNoRangeFill)
	end
end

function CDM.RefreshAllAuras()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.RefreshAuras(fState)
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

function CDM.PLAYER_REGEN_ENABLED()
	CDM.Rebuild()
end

function CDM.PLAYER_TARGET_CHANGED()
	for fState, onTarget in pairs(CDM.onTargetLookup) do
		fState.Container:UpdateAllAuras()
	end
end

function CDM.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	local fState = CDM.categoryLookup[category]
	if fState then
		if not fState.spellIDs[spellID] then
			CDM.RefreshCategory(fState, spellID)
			CDM.RefreshAuras(fState)
		end
	end
end

function CDM.OnScaleChanged()
	CDM.RefreshScale()
	CDM.RefreshLayout()
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

-- TODO: The flicker happens when tabbing between targets with Rend
-- TODO: Come up with better naming. self? buffs/cds?
