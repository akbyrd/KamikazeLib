local Kami = select(2, ...)
local CDM = {}
Kami.CDM2 = CDM

local LCG = LibStub("LibCustomGlow-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

function CDM.Load()
	CDM.cfg = {
		default = {
			xPos = 0,
			yPos = 0,

			iconSize   = 50,
			iconZoom   = 0.08,
			iconAspect = 1.65,
			iconPad    = 1,
			iconLimit  = 5,

			borderColor = "000000FF",
			borderSize  = 1,

			cdShowTime  = true,
			cdFontScale = 0.75,
		},

		[Enum.CooldownViewerCategory.Essential] = {
			yPos = -288,
		},

		[Enum.CooldownViewerCategory.Utility] = {
			yPos = -344,
			iconSize = 30,
		},
	}

	setmetatable(CDM.cfg[Enum.CooldownViewerCategory.Essential], { __index = CDM.cfg.default })
	setmetatable(CDM.cfg[Enum.CooldownViewerCategory.Utility],   { __index = CDM.cfg.default })

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Event")
	CDM.eventFrame:SetScript("OnEvent", CDM.DispatchEvent)
	CDM.RegisterEvent("UI_SCALE_CHANGED",      CDM.RefreshScale)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",  CDM.RefreshScale)
	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN", CDM.SPELL_UPDATE_COOLDOWN)
	hooksecurefunc(UIParent, "SetScale", CDM.RefreshScale)

	local viewers = {
		Enum.CooldownViewerCategory.Essential,
		Enum.CooldownViewerCategory.Utility,
	}
	local categoryToName = EnumUtil.GenerateNameTranslation(Enum.CooldownViewerCategory)

	CDM.viewers = {}
	for index, category in ipairs(viewers) do
		local categoryName = categoryToName(category)

		local Root = CreateFrame("Frame", nil, UIParent)
		Root:SetParentKey(("Kami.CDM.%s.Root"):format(categoryName))

		local vState = {
			name       = categoryName,
			cfg        = CDM.cfg[category],
			Root       = Root,
			pool       = {},
			cdvInfos   = {},
			cdFrames   = {},
			spells     = {},
			--items      = {},
			--categories = {},
			xSize      = nil,
			ySize      = nil,
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

	-- TODO: Should we throttle this?
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.Rebuild)

	-- CD fonts
	local cdTypeface = LSM:Fetch("font", "PT Sans Narrow")
	for category, vState in pairs(CDM.viewers) do
		vState.cdFontName = ("Kami.CDM2.Font.%s"):format(vState.name)
		vState.cdFont = CreateFont(vState.cdFontName)
		vState.cdFont:SetFont(cdTypeface, 18, "OUTLINE")
	end
end

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

function CDM.Rebuild()
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	if layoutMgr:AreNotificationsLocked() then return end

	print("Kami CDM Rebuild")
	CDM.GatherCDs()
	CDM.AssignFrames()
	CDM.RefreshSizes()
	CDM.RefreshPositions()
end

function CDM.GatherCDs()
	for category, vState in pairs(CDM.viewers) do
		wipe(vState.cdvInfos)
	end

	local categoryOverrides = {} -- cooldownID -> user category, deviations from the default
	local positionOverrides = {} -- cooldownID -> boolean,       deviations from the default

	local function AddCD(cooldownID)
		local cdvInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) -- CooldownViewerCooldown
		if cdvInfo and cdvInfo.isKnown then
			local hidden   = FlagsUtil.IsSet(cdvInfo.flags, Enum.CooldownSetSpellFlags.HideByDefault)
			local category = categoryOverrides[cooldownID] or (hidden and -1 or cdvInfo.category)

			local vState = CDM.viewers[category]
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

function CDM.ConstructFrame(vState)
	local fState = {}

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
	fState.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
	fState.Cooldown:SetDrawBling(false)
	fState.Cooldown:SetCountdownFormatter(CDM.cdFormatter)
	fState.Cooldown:SetCountdownFont(vState.cdFontName)
	fState.Cooldown:SetScript("OnCooldownDone", function() fState.Icon:SetDesaturated(false) end)

	-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.

	-- Bling
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

	--fState.Root    :SetFrameLevel(0)
	--fState.Content :SetFrameLevel(1)
	--fState.Recharge:SetFrameLevel(3)
	--fState.Cooldown:SetFrameLevel(2)
	--fState.Bling   :SetFrameLevel(4)

	return fState
end

function CDM.EnableFrame(fState, vState, cdvInfo)
	local texture
	if cdvInfo.spellID then
		texture = C_Spell.GetSpellTexture(cdvInfo.spellID)
	else
		texture = GetInventoryItemTexture("player", cdvInfo.equipSlot)
	end

	local bColor = CreateColorFromRGBAHexString(vState.cfg.borderColor)

	fState.cdvInfo = cdvInfo
	fState.Root:Show()
	fState.Icon:SetTexture(texture)
	fState.Border:SetVertexColor(bColor:GetRGBA())
end

-- TODO: We only need to clear the things EnableFrame and a CD update won't handle
function CDM.DisableFrame(fState)
	fState.Root:Hide()
	fState.Icon:SetDesaturated(false)
	fState.Cooldown:Clear()
	fState.Recharge:Clear()
	--fState.Press:Hide()
	--fState.Assist:Hide()
	fState.Bling:Clear()

	--if CDM.assistGlow == fState then
	--	CDM.AssistGlow(nil, nil)
	--end

	--if fState.hasProcGlow then
	--	CDM.ProcGlow(fState.frame, nil, false)
	--end

	fState.cdvInfo = nil
	fState.hasBling = nil
	--fState.hasProcGlow = nil
	--fState.hasAssistGlow = nil
end

function CDM.AssignFrames()
	for category, vState in pairs(CDM.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end
		wipe(vState.cdFrames)
		wipe(vState.spells)

		-- Construct new frames (if needed)
		local have = #vState.pool
		local need = #vState.cdvInfos
		for iNeed = have + 1, need do
			local fState = CDM.ConstructFrame(vState)
			CDM.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end

		-- Enable new frames
		for iInfo, cdvInfo in ipairs(vState.cdvInfos) do
			local fState = table.remove(vState.pool)
			CDM.EnableFrame(fState, vState, cdvInfo)
			table.insert(vState.cdFrames, fState)

			if cdvInfo.spellID then
				vState.spells[cdvInfo.spellID] = fState
			end
		end
	end
end

function CDM.RefreshScale()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / vState.Root:GetParent():GetEffectiveScale()
		vState.Root:SetScale(pixelsToUI)

		CDM.RefreshSizes()
		CDM.RefreshPositions()
	end
end

function CDM.RefreshSizes()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
		local iconSize    = Round(vState.cfg.iconSize   / pixelsToUI)
		local borderSize  = Round(vState.cfg.borderSize / pixelsToUI)
		--local assistSize  = vState.cfg.assistSize  / pixelsToUI
		local iconZoom    = vState.cfg.iconZoom
		local iconAspect  = vState.cfg.iconAspect
		local cdFontScale = vState.cfg.cdFontScale

		local xScale, yScale = Kami.Util.AspectScale(iconAspect)
		vState.xSize = Round(xScale * iconSize)
		vState.ySize = Round(yScale * iconSize)

		local cxSize   = vState.xSize - 2*borderSize
		local cySize   = vState.ySize - 2*borderSize
		local diagSize = sqrt(cxSize^2 + cySize^2)

		local cdFontSize = Round(cdFontScale * cySize)
		vState.cdFont:SetFontHeight(cdFontSize)

		for iFrame, fState in ipairs(vState.cdFrames) do
			fState.Root:SetSize(vState.xSize, vState.ySize)
			fState.Content:SetSize(cxSize, cySize)
			fState.Recharge:SetSize(diagSize, diagSize)
			fState.Bling:SetSize(diagSize, diagSize)

			Kami.Util.ZoomIcon(fState.Icon, iconZoom, cxSize, cySize)
			Kami.Util.SetSliceScale(fState.Border, borderSize)
			--Kami.Util.SetSliceScale(fState.Assist, assistSize)
		end
	end
end

function CDM.RefreshPositions()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
		local xPos      = Round(vState.cfg.xPos    / pixelsToUI)
		local yPos      = Round(vState.cfg.yPos    / pixelsToUI)
		local iconPad   = Round(vState.cfg.iconPad / pixelsToUI)
		local iconLimit = vState.cfg.iconLimit

		local mxPos = 0
		local myPos = 0

		for iFrame, fState in ipairs(vState.cdFrames) do
			local iCol = (iFrame - 1) % iconLimit
			local iRow = floor((iFrame - 1) / iconLimit)

			local nRow   = min(iconLimit, #vState.cdFrames - (iRow * iconLimit))
			local nMax   = min(iconLimit, #vState.cdFrames)
			local rxSize = nRow * (vState.xSize + iconPad) - iconPad
			local lxSize = nMax * (vState.xSize + iconPad) - iconPad
			local cxPos  = Round((lxSize - rxSize) / 2)

			local xPos = 0 + iCol * (vState.xSize + iconPad) + cxPos
			local yPos = 0 - iRow * (vState.ySize + iconPad)
			fState.Root:SetPoint("TOPLEFT", vState.Root, "TOPLEFT", xPos, yPos)

			mxPos = math.max(mxPos, xPos + vState.xSize)
			myPos = math.min(myPos, yPos - vState.ySize)
		end

		local pxSize, pySize = GetPhysicalScreenSize()
		local vxPos = Round((0 + pxSize - mxPos) / 2 + xPos)
		local vyPos = Round((0 - pySize - myPos) / 2 + yPos)
		vState.Root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", vxPos, vyPos)
		vState.Root:SetSize(mxPos, -myPos)
	end
end

-- TODO: Canonicalize spells
function CDM.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	local function Impl(vState, fState)
		local spellID  = fState.cdvInfo.spellID
		local cdInfo   = C_Spell.GetSpellCooldown(spellID) -- SpellCooldownInfo
		local onCD     = cdInfo.isActive and not cdInfo.isOnGCD
		local onGCD    = cdInfo.isOnGCD
		local duration = C_Spell.GetSpellCooldownDuration(spellID)

		if onCD then
			fState.Cooldown:SetHideCountdownNumbers(not vState.cfg.cdShowTime)
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

		local chargeInfo = C_Spell.GetSpellCharges(spellID) -- SpellChargeInfo
		local recharging = chargeInfo and chargeInfo.isActive and not onCD
		if recharging then
			local duration = C_Spell.GetSpellChargeDuration(spellID)
			fState.Recharge:SetCooldownFromDurationObject(duration)
		else
			fState.Recharge:Clear()
		end
	end

	for category, vState in pairs(CDM.viewers) do
		local startGCD = startRecoveryCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY
		if startGCD or not spellID then
			for spellID, fState in pairs(vState.spells) do
				Impl(vState, fState)
			end
		else
			local fState = vState.spells[spellID] or vState.spells[baseSpellID]
			if fState then
				Impl(vState, fState)
			end
		end
	end
end

CDM.Load()
