local Kami = select(2, ...)
local CDM = {}
Kami.CDM.Buffs = CDM

local Config = Kami.Config
local Util   = Kami.Util

function CDM.Load()
	CDM.charVars = KLCharVars.CDM

	CDM.cfgTree = Config.Create()
	Config.AddNode(CDM.cfgTree, nil, "Default",
		{
			iconZoom   = Config.Number(0.08),
			iconAspect = Config.Number(1.65),

			borderColor = Config.Color("FF000000"),
			borderSize  = Config.Size("1ui"),
		})
	Config.AddNode(CDM.cfgTree, "Default", "TrackedBar",
		{
			xPos     = Config.Size("0px"),
			yPos     = Config.Size("-272px"),
			xSize    = Config.Size("514px"),
			ySize    = Config.Size("16px"),
			padSize  = Config.Size("-1ui"),
			barColor = Config.Color("FF4F4F4F"),
		})

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Buffs.Event")
	CDM.eventFrame:SetScript("OnEvent",        CDM.DispatchEvent)
	CDM.RegisterEvent("UI_SCALE_CHANGED",      CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",  CDM.OnScaleChanged)
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

-- TODO: There are 2 bars on top of each other at the top
-- add item, then remove it
-- layout leaves orphaned item at the top, still visible
-- This probably goes away when we hide inactive buffs

-- TODO: ElvUI texture
function CDM.ConstructFrame(vState)
	local fState = {}
	fState.cfg      = vState.cfg
	fState.slotKey  = tostring(fState)
	fState.spellIDs = {}

	fState.Cell = CreateFrame("Frame", nil, vState.Root)

	fState.CellBg = fState.Cell:CreateTexture(nil, "BACKGROUND")
	fState.CellBg:SetAllPoints()
	fState.CellBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

	fState.Container = CreateFrame("AuraContainer", nil, fState.Cell, "CustomAuraContainerTemplate")
	fState.Container:SetAllPoints()

	fState.Container:AddAuraSlot(fState.slotKey, "HELPFUL",
		{
			initializeFrame = function(button)
				-- NOTE: Errors here are swallowed silently. This runs under securecallfunction.

				fState.Button = button
				fState.Button:SetAllPoints(fState.Cell)
				fState.Button:EnableMouse(false)

				fState.Icon = fState.Button:CreateTexture(nil, "ARTWORK")
				fState.Button:SetIcon(fState.Icon)

				fState.IconBorder = fState.Button:CreateTexture(nil, "OVERLAY")
				fState.IconBorder:SetParentKey("IconBorder")
				fState.IconBorder:SetPoint("TOPLEFT")
				fState.IconBorder:SetPoint("BOTTOMLEFT")
				fState.IconBorder:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
				fState.IconBorder:SetTextureSliceMargins(1, 1, 1, 1)

				fState.Bar = CreateFrame("StatusBar", nil, fState.Button)
				fState.Bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
				fState.Button:SetDurationBar(fState.Bar, { direction = Enum.StatusBarTimerDirection.RemainingTime })

				fState.BarBorder = fState.Button:CreateTexture(nil, "OVERLAY")
				fState.BarBorder:SetParentKey("BarBorder")
				fState.BarBorder:SetPoint("TOPLEFT")
				fState.BarBorder:SetPoint("BOTTOMLEFT")
				fState.BarBorder:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
				fState.BarBorder:SetTextureSliceMargins(1, 1, 1, 1)
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
		end
	end

end

function CDM.RefreshLayout()
	local pxSize, pySize = GetPhysicalScreenSize()

	for category, vState in pairs(CDM.viewers) do
		-- TODO: Handle relative sizes
		local cfg        = vState.cfg
		local xPos       = Round(cfg.xPos       + cfg.xPosRel       * 0)
		local yPos       = Round(cfg.yPos       + cfg.yPosRel       * 0)
		local xSize      = Round(cfg.xSize      + cfg.xSizeRel      * 0)
		local ySize      = Round(cfg.ySize      + cfg.ySizeRel      * 0)
		local padSize    = Round(cfg.padSize    + cfg.padSizeRel    * 0)
		local borderSize = Round(cfg.borderSize + cfg.borderSizeRel * 0)
		local iconAspect = cfg.iconAspect
		local iconZoom   = cfg.iconZoom

		local vxSize = cfg.xSize
		local vySize = #vState.cdFrames * (ySize + padSize) - padSize
		local vxPos  = xPos + Round((pxSize - vxSize) / 2)
		local vyPos  = yPos - Round((pySize - vySize) / 2)
		vState.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
		vState.Root:SetSize(vxSize, vySize)

		for iFrame, fState in ipairs(vState.cdFrames) do
			local cyOffset = -(iFrame - 1) * (ySize + padSize)
			fState.Cell:SetSize(xSize, ySize)
			fState.Cell:SetPoint("TOPLEFT", vState.Root, "TOPLEFT", 0, cyOffset)

			local xScale, yScale = Util.AspectScale(iconAspect)
			local ibxSize = Round(xScale / yScale * ySize)
			local ibySize = Round(yScale / yScale * ySize)
			local ixSize  = ibxSize - 2*borderSize
			local iySize  = ibySize - 2*borderSize
			Util.ZoomIcon(fState.Icon, iconZoom, ixSize, iySize)
			fState.Icon:SetPoint("TOPLEFT",     fState.IconBorder, "TOPLEFT",      borderSize, -borderSize)
			fState.Icon:SetPoint("BOTTOMRIGHT", fState.IconBorder, "BOTTOMRIGHT", -borderSize,  borderSize)
			fState.IconBorder:SetWidth(ibxSize / borderSize)
			fState.IconBorder:SetScale(borderSize)

			local bbxPos  = (ibxSize - borderSize)
			local bbxSize = xSize - bbxPos
			fState.Bar:SetPoint("TOPLEFT",     fState.BarBorder, "TOPLEFT",      borderSize, -borderSize)
			fState.Bar:SetPoint("BOTTOMRIGHT", fState.BarBorder, "BOTTOMRIGHT", -borderSize,  borderSize)
			fState.BarBorder:SetPointsOffset(bbxPos / borderSize, 0)
			fState.BarBorder:SetWidth(bbxSize / borderSize)
			fState.BarBorder:SetScale(borderSize)
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
-- TODO: Order is unstable (flip-flops when a proc occurs)
-- TODO: Come up with better naming. self? buffs/cds?
