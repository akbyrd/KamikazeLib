local Kami = select(2, ...)
local CDM = {}
Kami.CDM.Buffs = CDM

local Config = Kami.Config
local Util   = Kami.Util

function CDM.Load()
	CDM.cfgTree = Config.Create()
	Config.AddNode(CDM.cfgTree, nil, "Default",
		{
			iconZoom   = Config.Number(0.08),
			iconAspect = Config.Number(1.65),

			borderColor = Config.Color("FF000000"),
			borderSize  = Config.Size("1px"),
		})
	Config.AddNode(CDM.cfgTree, "Default", "TrackedBar",
		{
			xSize    = Config.Size("200px"),
			ySize    = Config.Size("20px"),
			padSize  = Config.Size("2px"),
			barColor = Config.Color("FF4F4F4F"),
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
	CDM.RefreshAllConfig()
	CDM.RefreshLayout()
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

	vState.Container:AddAuraSlot(fState.slotKey, "HELPFUL",
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
		local xSize      = Round(cfg.xSize      + cfg.xSizeRel      * 0)
		local ySize      = Round(cfg.ySize      + cfg.ySizeRel      * 0)
		local padSize    = Round(cfg.padSize    + cfg.padSizeRel    * 0)
		local borderSize = Round(cfg.borderSize + cfg.borderSizeRel * 0)
		local iconAspect = cfg.iconAspect
		local iconZoom   = cfg.iconZoom

		local vxSize = cfg.xSize
		local vySize = #vState.cdFrames * (ySize + padSize) - padSize
		local vxPos  = 0 + Round((pxSize - vxSize) / 2)
		local vyPos  = 0 - Round((pySize - vySize) / 2)
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
