local Kami = select(2, ...)
local CDM = {}
Kami.CDM.Buffs = CDM

local Config = Kami.Config
local Util   = Kami.Util

function CDM.Load()
	CDM.cfgTree = Config.Create()
	Config.AddNode(CDM.cfgTree, nil, "Default",
		{
		})
	Config.AddNode(CDM.cfgTree, "Default", "TrackedBar",
		{
			xSize   = Config.Size("200px"),
			ySize   = Config.Size("20px"),
			padSize = Config.Size("2px"),
		})

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Buffs.Event")
	CDM.eventFrame:SetScript("OnEvent",       CDM.DispatchEvent)
	CDM.RegisterEvent("UI_SCALE_CHANGED",     CDM.OnScaleChanged)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED", CDM.OnScaleChanged)
	hooksecurefunc(UIParent, "SetScale",      CDM.OnScaleChanged)

	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.OnCDMChanged)

	local categoryToName = EnumUtil.GenerateNameTranslation(Enum.CooldownViewerCategory)

	local categories = {
		Enum.CooldownViewerCategory.TrackedBar,
	}

	CDM.viewers = {}
	for index, category in ipairs(categories) do
		local categoryName = categoryToName(category)

		-- TODO: Debug background
		local Root = CreateFrame("Frame", nil, UIParent)
		Root:SetParentKey(("Kami.CDM.Buffs.%s.Root"):format(categoryName))

		-- TODO: Debug background
		local Container = CreateFrame("AuraContainer", nil, Root, "CustomAuraContainerTemplate")
		Container:SetAllPoints()
		Container:SetUnit("player")

		local vState = {
			name      = categoryName,
			cfg       = Config.GetBranch(CDM.cfgTree, categoryName),
			Root      = Root,
			Container = Container,
			cdvInfos  = {},
			cdFrames  = {},
			pool      = {},
		}
		CDM.viewers[category] = vState
	end

	CDM.Rebuild()
end

function CDM.Rebuild()
	Kami.CDM.GatherCDs(CDM.viewers)

	-- TODO: RefreshScale is first because it's responsible for Config.RefreshValues. That seems a
	-- bit weird. If we make config a dedicated operation we can move RefreshScale into
	-- RefreshLayout (same for CDMCooldowns)

	CDM.RefreshScale()
	CDM.AssignFrames()
	CDM.RefreshLayout()
end

function CDM.ConstructFrame(vState)
	local fState = {}
	fState.cfg      = vState.cfg
	fState.slotKey  = tostring(fState)
	fState.spellIDs = {}

	fState.Cell = CreateFrame("Frame", nil, vState.Root)

	fState.CellBg = fState.Cell:CreateTexture(nil, "BACKGROUND")
	fState.CellBg:SetAllPoints()
	fState.CellBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

	vState.Container:AddAuraSlot(fState.slotKey, "HELPFUL",
		{
			initializeFrame = function(button)
				fState.Button = button
				fState.Button:SetAllPoints(fState.Cell)

				fState.Bar = button:CreateTexture(nil, "ARTWORK")
				fState.Bar:SetAllPoints()
				fState.Bar:SetColorTexture(0.2, 0.6, 1.0, 1.0)
			end,
		})

	return fState
end

-- TODO: When do we grab the spell for categories? When/how do we update the slot?
function CDM.EnableFrame(vState, fState, cdvInfo)
	-- NOTE: Category slots (e.g. Combat Potion) don't have a spell id
	if cdvInfo.spellID then
		fState.spellIDs[cdvInfo.spellID] = true
	end
	for iLinked, linkedSpellID in ipairs(cdvInfo.linkedSpellIDs) do
		fState.spellIDs[linkedSpellID] = true
	end

	vState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })
end

function CDM.DisableFrame(vState, fState)
	wipe(fState.spellIDs)
	vState.Container:SetAuraSlotCandidateFilters(fState.slotKey, { includeSpellIDs = fState.spellIDs })
end

function CDM.AssignFrames()
	for category, vState in pairs(CDM.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.DisableFrame(vState, fState)
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
			CDM.EnableFrame(vState, fState, cdvInfo)
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

function CDM.RefreshLayout()
	local pxSize, pySize = GetPhysicalScreenSize()

	for category, vState in pairs(CDM.viewers) do
		-- TODO: Handle relative sizes
		local cfg     = vState.cfg
		local xSize   = Round(cfg.xSize   + cfg.xSizeRel   * 0)
		local ySize   = Round(cfg.ySize   + cfg.ySizeRel   * 0)
		local padSize = Round(cfg.padSize + cfg.padSizeRel * 0)

		local vxSize = cfg.xSize
		local vySize = #vState.cdFrames * (ySize + padSize) - padSize
		local vxPos  = 0 + Round((pxSize - vxSize) / 2)
		local vyPos  = 0 - Round((pySize - vySize) / 2)
		vState.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
		vState.Root:SetSize(vxSize, vySize)

		for iFrame, fState in ipairs(vState.cdFrames) do
			local yOffset = -(iFrame - 1) * (ySize + padSize)
			fState.Cell:SetSize(xSize, ySize)
			fState.Cell:SetPoint("TOPLEFT", vState.Root, "TOPLEFT", 0, yOffset)
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

-- TODO: Come up with better naming. self? buffs/cds?
