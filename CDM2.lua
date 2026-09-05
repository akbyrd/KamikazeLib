local Kami = select(2, ...)
local CDM = {}
Kami.CDM2 = CDM

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

			borderColor = "FF000000",
			borderSize  = 1,

			cdShowTime  = true,
			cdFontScale = 0.75,

			pressColor  = "40FFFFFF",
			queuedColor = "4DE6CC1A",

			assistColor = "FF3399F2",
			assistSize  = 1,

			procColor = "FFFFFF00",
			procSpeed = 0.30,
			procSize  = 2,
			procDuty  = 0.6,
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
	CDM.eventFrame:SetScript("OnEvent",                         CDM.DispatchEvent)
	CDM.eventFrame:SetScript("OnUpdate",                        CDM.Update)
	CDM.RegisterEvent("UI_SCALE_CHANGED",                       CDM.RefreshScale)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",                   CDM.RefreshScale)
	CDM.RegisterEvent("SPELL_UPDATE_USABLE",                    CDM.RefreshAllUsable)
	CDM.RegisterEvent("PLAYER_REGEN_ENABLED",                   CDM.PLAYER_REGEN_ENABLED)
	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN",                  CDM.SPELL_UPDATE_COOLDOWN)
	CDM.RegisterEvent("SPELL_RANGE_CHECK_UPDATE",               CDM.SPELL_RANGE_CHECK_UPDATE)
	CDM.RegisterEvent("GLOBAL_MOUSE_DOWN",                      CDM.GLOBAL_MOUSE_DOWN)
	CDM.RegisterEvent("GLOBAL_MOUSE_UP",                        CDM.GLOBAL_MOUSE_UP)
	CDM.RegisterEvent("CURRENT_SPELL_CAST_CHANGED",             CDM.CURRENT_SPELL_CAST_CHANGED)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",     CDM.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
	CDM.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",     CDM.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
	CDM.RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED)
	CDM.RegisterEvent("SPELL_UPDATE_ICON",                      CDM.SPELL_UPDATE_ICON)
	hooksecurefunc(UIParent, "SetScale",                        CDM.RefreshScale)
	hooksecurefunc("SecureActionButton_OnClick",                CDM.OnClick)

	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.Rebuild)

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
			name     = categoryName,
			cfg      = CDM.cfg[category],
			Root     = Root,
			pool     = {},
			cdvInfos = {},
			cdFrames = {},
			xSize    = nil,
			ySize    = nil,
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

	CDM.usableColor   = CreateColorFromHexString("FFFFFFFF")
	CDM.noManaColor   = CreateColorFromHexString("FF8080FF")
	CDM.noRangeColor  = CreateColorFromHexString("FFA32626")
	CDM.noUsableColor = CreateColorFromHexString("FF666666")
	CDM.spellLookup   = {}
	CDM.mousePresses  = {}
	CDM.spellPresses  = {}
	CDM.pressCounts   = {}
	CDM.dirty = {
		cooldown = false,
	}

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

function CDM.Update()
	if CDM.dirty.cooldown then
		CDM.dirty.cooldown = false
		CDM.RefreshAllCooldowns()
	end

	CDM.RefreshAssist()
end

function CDM.Rebuild()
	-- NOTE: Hook fires when events are being throttled. Wait for the unlock.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	if layoutMgr:AreNotificationsLocked() then return end

	-- NOTE: Spell overrides trigger NotifyListeners
	if InCombatLockdown() and CDM.hasBuilt then return end
	CDM.hasBuilt = true

	print("Kami CDM Rebuild")
	CDM.GatherCDs()
	CDM.AssignFrames()
	CDM.RefreshAllSizes()
	CDM.RefreshAllPositions()
	CDM.RefreshAllOverrides()
	CDM.RefreshAllCooldowns()
	CDM.RefreshAllIcons()
	CDM.RefreshAllUsable()
	CDM.RefreshAllPress()
	CDM.RefreshAllQueued()
	CDM.RefreshAllProcs()
	CDM.RefreshAssist()
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
	fState.cfg = vState.cfg

	-- Frame        | Textures      | Purpose
	-- -------------|---------------|--------
	-- Root         | Border        | Size, Position
	--   Content    | Icon          | Inset
	--     Recharge |               | Cooldown
	--     Cooldown |               | Cooldown
	--     Overlay  | Press, Queued | Draw Order
	--     Bling    |               | Cooldown
	--   Outline    | Assist        | Draw Order

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
	fState.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
	fState.Cooldown:SetDrawBling(false)
	fState.Cooldown:SetCountdownFormatter(CDM.cdFormatter)
	fState.Cooldown:SetCountdownFont(vState.cdFontName)
	fState.Cooldown:SetScript("OnCooldownDone", function() fState.Icon:SetDesaturated(false) end)

	fState.Overlay = CreateFrame("Frame", nil, fState.Content)
	fState.Overlay:SetParentKey("Overlay")
	fState.Overlay:SetAllPoints()

	local pressColor = CreateColorFromHexString(vState.cfg.pressColor)
	fState.Press = fState.Overlay:CreateTexture(nil, "OVERLAY", nil, 0)
	fState.Press:SetParentKey("Press")
	fState.Press:SetAllPoints()
	fState.Press:SetColorTexture(pressColor:GetRGBA())
	fState.Press:SetBlendMode("ADD")

	local queuedColor = CreateColorFromHexString(vState.cfg.queuedColor)
	fState.Queued = fState.Overlay:CreateTexture(nil, "OVERLAY", nil, 0)
	fState.Queued:SetParentKey("Queued")
	fState.Queued:SetAllPoints()
	fState.Queued:SetColorTexture(queuedColor:GetRGBA())
	fState.Queued:SetBlendMode("ADD")

	-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.
	-- Ideally it would be above the Outline / Assist, but it needs to be clipped by Content

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

	fState.Outline = CreateFrame("Frame", nil, fState.Root)
	fState.Outline:SetParentKey("Outline")
	fState.Outline:SetAllPoints()

	local assistColor = CreateColorFromHexString(vState.cfg.assistColor)
	fState.Assist = fState.Outline:CreateTexture(nil, "OVERLAY", nil, 1)
	fState.Assist:SetParentKey("Assist")
	fState.Assist:SetAllPoints()
	fState.Assist:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	fState.Assist:SetTextureSliceMargins(1, 1, 1, 1)
	fState.Assist:SetVertexColor(assistColor:GetRGBA())

	local procColor = CreateColorFromHexString(vState.cfg.procColor)
	fState.Proc = Kami.PixelAnts.Create(fState.Outline, vState.cfg.procSize, 0, procColor, vState.cfg.procSpeed, 2, vState.cfg.procDuty)

	return fState
end

function CDM.EnableFrame(fState, cdvInfo)
	-- NOTE: We don't rebuild "pressed" state here. We don't track pressCount for spells that aren't
	-- on the CDM. So we can't tell if it was already being held when a rebuild occurs. We could
	-- track it, but it could be an override and we always store the base spellID specifically to
	-- avoid dealing with complexity from overrides. So it's not worth handling that edge case.

	fState.baseSpellID = cdvInfo.spellID
	fState.spellID     = cdvInfo.spellID

	if fState.spellID then
		C_Spell.EnableSpellRangeCheck(fState.baseSpellID, true)
	else
		local texture = GetInventoryItemTexture("player", cdvInfo.equipSlot)
		fState.Icon:SetTexture(texture)
	end

	local borderColor = CreateColorFromHexString(fState.cfg.borderColor)
	fState.Root:Show()
	fState.Border:SetVertexColor(borderColor:GetRGBA())
end

-- TODO: We only need to clear the things EnableFrame and a CD update won't handle
function CDM.DisableFrame(fState)
	if fState.baseSpellID then
		C_Spell.EnableSpellRangeCheck(fState.baseSpellID, false)
	end

	fState.Root:Hide()
	fState.Icon:SetTexture(nil)
	fState.Icon:SetDesaturated(false)
	fState.Cooldown:Clear()
	fState.Recharge:Clear()
	fState.Press:Hide()
	fState.Queued:Hide()
	fState.Bling:Clear()
	fState.Assist:Hide()
	fState.Proc:Hide()

	fState.spellID = nil
	fState.baseSpellID = nil
	fState.hasBling = nil
end

function CDM.AssignFrames()
	wipe(CDM.spellLookup)
	CDM.assistSpellID = nil

	for category, vState in pairs(CDM.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.cdFrames) do
			-- TODO: Not sure if this is a good idea
			CDM.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end
		wipe(vState.cdFrames)

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
			CDM.EnableFrame(fState, cdvInfo)
			table.insert(vState.cdFrames, fState)

			if cdvInfo.spellID then
				CDM.spellLookup[cdvInfo.spellID] = fState
			end
		end
	end
end

function CDM.RefreshScale()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / vState.Root:GetParent():GetEffectiveScale()
		vState.Root:SetScale(pixelsToUI)
	end

	CDM.RefreshAllSizes()
	CDM.RefreshAllPositions()
end

function CDM.RefreshAllSizes()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
		local iconSize    = Round(vState.cfg.iconSize   / pixelsToUI)
		local borderSize  = Round(vState.cfg.borderSize / pixelsToUI)
		local assistSize  = Round(vState.cfg.assistSize / pixelsToUI)
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
			fState.Proc:RefreshSize()

			Kami.Util.ZoomIcon(fState.Icon, iconZoom, cxSize, cySize)
			Kami.Util.SetSliceScale(fState.Border, borderSize)
			Kami.Util.SetSliceScale(fState.Assist, assistSize)
		end
	end
end

function CDM.RefreshAllPositions()
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

function CDM.RefreshOverride(fState, spellID)
	-- Remove the current override
	if fState.spellID ~= fState.baseSpellID then
		CDM.spellLookup[fState.spellID] = nil
		fState.spellID = fState.baseSpellID
	end

	-- Apply the new override (or revert back to base)
	if spellID and spellID ~= fState.spellID then
		CDM.spellLookup[spellID] = fState
		fState.spellID = spellID
	end
end

function CDM.RefreshAllOverrides()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				local spellID = C_Spell.GetOverrideSpell(fState.baseSpellID)
				CDM.RefreshOverride(fState, spellID)
			end
		end
	end
end

function CDM.RefreshCooldown(fState)
	local cdInfo   = C_Spell.GetSpellCooldown(fState.spellID) -- SpellCooldownInfo
	local onCD     = cdInfo.isActive and not cdInfo.isOnGCD
	local onGCD    = cdInfo.isOnGCD
	local duration = C_Spell.GetSpellCooldownDuration(fState.spellID)

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
		fState.Bling:SetCooldownFromDurationObject(duration, true)
	elseif fState.hasBling then
		fState.hasBling = nil
		fState.Bling:SetCooldownDuration(1e-3)
	end

	local chargeInfo = C_Spell.GetSpellCharges(fState.spellID) -- SpellChargeInfo
	local recharging = chargeInfo and chargeInfo.isActive and not onCD
	if recharging then
		local duration = C_Spell.GetSpellChargeDuration(fState.spellID)
		fState.Recharge:SetCooldownFromDurationObject(duration)
	else
		fState.Recharge:Clear()
	end
end

function CDM.RefreshAllCooldowns()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				CDM.RefreshCooldown(fState)
			end
		end
	end
end

function CDM.RefreshIcon(fState)
	local texture = C_Spell.GetSpellTexture(fState.spellID)
	fState.Icon:SetTexture(texture)
end

function CDM.RefreshAllIcons()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				CDM.RefreshIcon(fState)
			end
		end
	end
end

function CDM.RefreshUsable(fState)
	local usable, noMana = C_Spell.IsSpellUsable(fState.spellID)
	local noRange = C_Spell.IsSpellInRange(fState.spellID) == false -- nil is "no target" etc

	local color
	if     noRange then color = CDM.noRangeColor
	elseif usable  then color = CDM.usableColor
	elseif noMana  then color = CDM.noManaColor
	else                color = CDM.noUsableColor
	end

	fState.Icon:SetVertexColor(color:GetRGBA())
end

function CDM.RefreshAllUsable()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				CDM.RefreshUsable(fState)
			end
		end
	end
end

function CDM.RefreshPress(spellID, pressed)
	local fState = CDM.spellLookup[spellID]
	if fState then
		fState.Press:SetShown(pressed)
	end
end

function CDM.RefreshAllPress()
	for spellID, pressCount in pairs(CDM.pressCounts) do
		CDM.RefreshPress(spellID, pressCount > 0)
	end
end

function CDM.RefreshAllQueued()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				local isCurrent = C_Spell.IsCurrentSpell(fState.spellID)
				fState.Queued:SetShown(isCurrent)
			end
		end
	end
end

function CDM.RefreshAllProcs()
	for category, vState in pairs(CDM.viewers) do
		for iFrame, fState in ipairs(vState.cdFrames) do
			if fState.spellID then
				local show = C_SpellActivationOverlay.IsSpellOverlayed(fState.spellID)
				fState.Proc:SetShown(show)
			end
		end
	end
end

function CDM.RefreshAssist()
	local spellID     = C_AssistedCombat.GetNextCastSpell(false)
	local fState      = spellID and CDM.spellLookup[spellID]
	local baseSpellID = fState and fState.baseSpellID

	if baseSpellID ~= CDM.assistSpellID then
		if CDM.assistSpellID then
			local fState = CDM.spellLookup[CDM.assistSpellID]
			fState.Assist:Hide()
			CDM.assistSpellID = nil
		end

		if baseSpellID then
			fState.Assist:Show()
			CDM.assistSpellID = baseSpellID
		end
	end
end

function CDM.PLAYER_REGEN_ENABLED()
	CDM.Rebuild()
end

function CDM.SPELL_RANGE_CHECK_UPDATE(spellID, isInRange, checksRange)
	local fState = CDM.spellLookup[spellID]
	if fState then
		CDM.RefreshUsable(fState)
	end
end

function CDM.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	local startGCD = startRecoveryCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY
	if startGCD or not spellID then
		CDM.dirty.cooldown = true
	else
		-- NOTE: Supposedly this event can arrive before the override event, so we need to check base
		local fState = CDM.spellLookup[spellID] or CDM.spellLookup[baseSpellID]
		if fState then
			CDM.RefreshCooldown(fState)
		end
	end
end

function CDM.GLOBAL_MOUSE_DOWN(mouseButton)
	CDM.mousePresses[mouseButton] = {
		time   = GetTime(),
		button = nil,
	}
end

function CDM.GLOBAL_MOUSE_UP(mouseButton)
	local press = CDM.mousePresses[mouseButton]
	CDM.mousePresses[mouseButton] = nil

	if press and press.button then
		CDM.OnClick(press.button, mouseButton, false, nil, nil)
	end
end

function CDM.CURRENT_SPELL_CAST_CHANGED(cancelledCast)
	CDM.RefreshAllQueued()
end

function CDM.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(spellID)
	local fState = CDM.spellLookup[spellID]
	if fState then
		fState.Proc:Show()
	end
end

function CDM.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(spellID)
	local fState = CDM.spellLookup[spellID]
	if fState then
		fState.Proc:Hide()
	end
end

function CDM.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED(baseSpellID, overrideSpellID)
	local fState = CDM.spellLookup[baseSpellID]
	if fState then
		CDM.RefreshOverride(fState, overrideSpellID)
	end
end

function CDM.SPELL_UPDATE_ICON(spellID)
	if spellID then
		local fState = CDM.spellLookup[spellID]
		if fState then
			CDM.RefreshIcon(fState)
		end
	else
		CDM.RefreshAllIcons()
	end
end

function CDM.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
	-- NOTE: We are not guaranteed to get a release after a press:
	-- Mouse down, drag off, mouse release                - no event
	-- Mouse down, drag off (far), drag on, mouse release - no event, was turned into a drag
	-- Mouse down, drag spell off bar, mouse release      - no event
	-- Key down, mouse down, mouse up, key up             - no event, any up cancels other events
	-- Key down, disable action bar, key up               - no event
	-- Maybe if keybinding is programmatically changed while held?

	-- NOTE: Macros can cast/use multiple spells/items but there doesn't appear to be a way to get
	-- all of them. GetMacroSpell only returns one spellID.

	-- NOTE: This doesn't fire when clicking items in bags. They don't use a secure frame. We could
	-- hook button frames but it's a per-button hook instead of a global one.

	-- NOTE: Keybindings always send left mouse button.
	-- NOTE: Addon synthesized events send isKeyPress = nil.
	-- NOTE: When dragging a spell off a button it will no longer have an action.
	-- NOTE: We choose not to handle the action bar disable and binding change edge cases.

	local spellID = nil

	if down then
		local buttonType = SecureButton_GetModifiedAttribute(button, "type", mouseButton)
		if buttonType == "action" then
			local slot = button:CalculateAction(mouseButton)
			local actionType, id, subType = GetActionInfo(slot)

			-- plain spell or /cast macro
			if actionType == "spell" or (actionType == "macro" and subType == "spell") then
				spellID = id

			-- plain item or /use macro
			elseif actionType == "item" or (actionType == "macro" and subType == "item") then
				-- BUG: https://github.com/Stanzilla/WoWUIBugs/issues/495
				spellID = C_ActionBar.GetSpell(slot)
			end
		end

		if not isKeyPress then
			local press = CDM.mousePresses[mouseButton]
			if press and press.time == GetTime() and button:IsMouseMotionFocus() then
				press.button = button
			end
		end
	end

	local fState      = CDM.spellLookup[spellID]
	local currSpellID = fState and fState.baseSpellID
	local prevSpellID = CDM.spellPresses[button]

	if prevSpellID ~= currSpellID then
		CDM.spellPresses[button] = currSpellID

		if prevSpellID then
			local pressCount = Kami.Util.TableRefAdd(CDM.pressCounts, prevSpellID, -1)
			CDM.RefreshPress(prevSpellID, pressCount > 0)
		end

		if currSpellID then
			local pressCount = Kami.Util.TableRefAdd(CDM.pressCounts, currSpellID, 1)
			CDM.RefreshPress(currSpellID, pressCount > 0)
		end
	end
end

CDM.Load()
