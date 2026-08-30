local Kami = select(2, ...)
local CDM = {}
Kami.CDM = CDM

local LCG = LibStub("LibCustomGlow-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- TODO: Look for hex conversion utility
function CDM.Load()
	CDM.cfg = {
		iconZoom   = 0.08,
		iconAspect = 1.65,

		borderColor = { 0, 0, 0, 1 },
		borderSize  = 2,

		procColor = { 1, 1, 0, 1 },
		procSpeed = 0.15,
		procSize  = 2,

		assistColor = { 0.2, 0.6, 0.95, 1 },
		assistSize  = 3,

		pressColor  = { 1, 1, 1, 0.25 },
		cdFontScale = 0.75,
	}

	CDM.frames = {}
	CDM.spells = {}
	CDM.overrides = {}
	CDM.categories = {}

	CDM.viewers = {
		[EssentialCooldownViewer] = { viewer = EssentialCooldownViewer },
		[UtilityCooldownViewer]   = { viewer = UtilityCooldownViewer },
	}

	-- Always 1 unit: 1m, not 1m 10s
	-- Two digits of precision if possible: 1.6m, 16m
	-- Show seconds when <3 digits: 99s, not 2m
	-- Don't units for seconds: 6, not 6s
	-- Units are a single letter
	-- Units are localized
	-- No space before units
	-- Support seconds, minutes, hours, and days

	local pick = 2
	if pick == 1 then
		-- <1s shows up as 0.xxx, ore truncated to 0

		local units = CreateFromMixins(SecondsFormatterMixin)
		units:Init(0, SecondsFormatter.Abbreviation.OneLetter)
		units:SetStripIntervalWhitespace(true)

		local function UnitFormat(interval, spec)
			return (units:GetFormatString(interval, SecondsFormatter.Abbreviation.OneLetter, false):gsub("%%d", spec))
		end

		local m = UnitFormat(SecondsFormatter.Interval.Minutes, "")
		local h = UnitFormat(SecondsFormatter.Interval.Hours, "")

		CDM.formatter = C_StringUtil.CreateAbbreviatedNumberFormatter()
		CDM.formatter:SetBreakpoints({
			{ breakpoint = 0.001, abbreviation = "", significandDivisor =    1, fractionDivisor =  1, abbreviationIsGlobal = false },
			{ breakpoint =   100, abbreviation = m,  significandDivisor =    6, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint =   600, abbreviation = m,  significandDivisor =   60, fractionDivisor =  1, abbreviationIsGlobal = false },
			{ breakpoint =  6000, abbreviation = h,  significandDivisor =  360, fractionDivisor = 10, abbreviationIsGlobal = false },
			{ breakpoint = 36000, abbreviation = h,  significandDivisor = 3600, fractionDivisor =  1, abbreviationIsGlobal = false },
		})

	elseif pick == 2 then
		local round = Enum.NumericRuleFormatRounding.Up

		local units = CreateFromMixins(SecondsFormatterMixin)
		units:SetStripIntervalWhitespace(true)

		local mFmt = units:GetFormatString(SecondsFormatter.Interval.Minutes, SecondsFormatter.Abbreviation.OneLetter, true)
		local hFmt = units:GetFormatString(SecondsFormatter.Interval.Hours,   SecondsFormatter.Abbreviation.OneLetter, true)
		local dFmt = units:GetFormatString(SecondsFormatter.Interval.Days,    SecondsFormatter.Abbreviation.OneLetter, true)

		CDM.formatter = C_StringUtil.CreateNumericRuleFormatter()
		CDM.formatter:SetBreakpoints({
			{ threshold = 0,                     format = "%d",                      components = {{ div = 1,                step = 1,   rounding = round }} },
			{ threshold = 99,                    format = mFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_MIN,  step = 0.1, rounding = round }} },
			{ threshold = 2  * SECONDS_PER_MIN,  format = mFmt,                      components = {{ div = SECONDS_PER_MIN,  step = 1,   rounding = round }} },
			{ threshold = 99 * SECONDS_PER_MIN,  format = hFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_HOUR, step = 0.1, rounding = round }} },
			{ threshold = 2  * SECONDS_PER_HOUR, format = hFmt,                      components = {{ div = SECONDS_PER_HOUR, step = 1,   rounding = round }} },
			{ threshold = 1  * SECONDS_PER_DAY,  format = dFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_DAY,  step = 0.1, rounding = round }} },
			{ threshold = 2  * SECONDS_PER_DAY,  format = dFmt,                      components = {{ div = SECONDS_PER_DAY,  step = 1,   rounding = round }} },
		})

	elseif pick == 3 then
		-- Can't hide seconds unit
		-- Can't do fractional minutes

		local band = C_CurveUtil.CreateCurve()
		band:SetType(Enum.LuaCurveType.Step)
		band:AddPoint(0,   Enum.SecondsFormatterInterval.Seconds)
		band:AddPoint(100, Enum.SecondsFormatterInterval.Minutes)

		CDM.formatter = C_StringUtil.CreateSecondsFormatter()
		CDM.formatter:SetDesiredUnitCount(1)
		CDM.formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
		CDM.formatter:SetMaxIntervalCurve(band)
		CDM.formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
		CDM.formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.StripIgnoreLocale)
		CDM.formatter:SetRounding(Enum.SecondsFormatterRounding.RoundUp)
		CDM.formatter:SetCanRoundUpLastUnit(true)
	end

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame", "KL_CDM")
	CDM.eventFrame:SetScript("OnEvent", CDM.DispatchEvent)

	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN", CDM.SPELL_UPDATE_COOLDOWN)
	CDM.RegisterEvent("BAG_UPDATE_COOLDOWN",   CDM.RefreshSpells)
	CDM.RegisterEvent("UI_SCALE_CHANGED",      CDM.RefreshSizesAndPositions)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",  CDM.RefreshSizesAndPositions)

	-- Assist glow
	hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell", CDM.AssistGlow)

	-- Press overlay
	hooksecurefunc("SecureActionButton_OnClick", CDM.OnClick)

	local cdTypeface = LSM:Fetch("font", "PT Sans Narrow")
	for viewer, vState in pairs(CDM.viewers) do
		hooksecurefunc(viewer, "RefreshData", CDM.ReconcileFrames)  -- Frames added/removed
		hooksecurefunc(viewer, "Layout",      CDM.RefreshPositions) -- Frame positions changed

		-- CD font
		vState.cdFontName = string.format("Kami.CDM.Font.%s", viewer:GetName())
		vState.cdFont = CreateFont(vState.cdFontName)
		vState.cdFont:SetFont(cdTypeface, 18, "OUTLINE")
	end
end

function CDM.ReconcileFrames(viewer, cooldownIDs, forceSet)
	-- NOTE: This can run in combat in a couple of potentially common cases:
	-- Pet summon/dismiss/death
	-- Some procs?

	local vState = CDM.viewers[viewer]

	for categoryID, fState in pairs(CDM.categories) do
		local cd = fState.frame:GetCooldownInfo() -- CooldownViewerCooldown
		local unbound = cd == nil
		local rebound = cd ~= nil and categoryID ~= cd.spellCategoryID

		if unbound or rebound then
			CDM.categories[categoryID] = nil
			fState.categoryID = nil
			if fState.spellID then
				CDM.spells[fState.spellID] = nil
				fState.spellID = nil
			end

			CDM.OnFrameRemoved(vState, fState)
		end
	end

	for spellID, fState in pairs(CDM.spells) do
		local cd = fState.frame:GetCooldownInfo() -- CooldownViewerCooldown
		local unbound = cd == nil
		local rebound = cd ~= nil and spellID ~= cd.spellID

		if unbound or rebound then
			CDM.spells[spellID] = nil
			fState.equipSlot = nil

			if fState.overrideSpellID then
				CDM.overrides[fState.overrideSpellID] = nil
				fState.overrideSpellID = nil
			end

			CDM.OnFrameRemoved(vState, fState)
		end
	end

	-- NOTE: This re-adds / updates without necessarily removing first.
	for frame in vState.viewer.itemFramePool:EnumerateActive() do
		local fState = CDM.frames[frame]
		if not fState then
			fState = { frame = frame }
			CDM.frames[frame] = fState
			CDM.OnFrameAdded(vState, fState)
		end

		local cd = fState.frame:GetCooldownInfo() -- CooldownViewerCooldown
		if cd then
			if cd.spellCategoryID then
				CDM.categories[cd.spellCategoryID] = fState
				fState.categoryID = cd.spellCategoryID
				if cd.spellID then
					fState.spellID = cd.spellID
					CDM.spells[fState.spellID] = fState
				end

			elseif cd.spellID then
				CDM.spells[cd.spellID] = fState
				fState.equipSlot = cd.equipSlot

				if cd.overrideSpellID then
					CDM.overrides[cd.overrideSpellID] = fState
					fState.overrideSpellID = cd.overrideSpellID
				end
			end
		end
	end

	CDM.RefreshSpells()
	CDM.RefreshSizes(vState)
end

function CDM.OnFrameAdded(vState, fState)
	-- Frame stack:
	-- Built-in
	-- - Frame
	-- - Icon
	-- - Cooldown
	-- - CooldownFlash
	-- - OutOfRange
	--
	-- Added                   (Parent    Anchor    Inset)
	-- - (Texture) Border    -> Frame     Frame     No
	-- - (Frame)   Cooldown  -> Frame     Frame     Yes
	-- - (Frame)   Clip      -> Frame     Frame     Yes
	-- - (Frame)   Recharge  -> Clip      Clip      Yes
	-- - (Frame)   Container -> Frame     Frame     No
	-- - (Texture) Press     -> Container Cooldown  Yes
	-- - (Texture) Assist    -> Container Container No
	-- - (Frame)   Bling     -> Clip      Clip      Yes

	-- Remove mask (reveals the silver border)
	for i = 1, fState.frame.Icon:GetNumMaskTextures() do
		local mask = fState.frame.Icon:GetMaskTexture(i)
		fState.frame.Icon:RemoveMaskTexture(mask)
	end

	-- Hide the overlay
	for _, region in ipairs({ fState.frame:GetRegions() }) do
		if region.GetAtlas and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
			region:Hide()
		end
	end

	-- Hide the out of range overlay and built-in cooldown
	fState.frame.OutOfRange:SetAlpha(0)
	fState.frame.Cooldown:SetAlpha(0)
	fState.frame.CooldownFlash:SetAlpha(0)

	-- Add border
	fState.Border = fState.frame:CreateTexture(nil, "OVERLAY")
	fState.Border:SetAllPoints()
	fState.Border:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	fState.Border:SetTextureSliceMargins(1, 1, 1, 1)
	fState.Border:SetVertexColor(unpack(CDM.cfg.borderColor))

	-- NOTE: The CD swipe is replaced because we don't want the active aura highlight
	-- NOTE: Cooldown frames hide themselves when they aren't active (and thus textures & children)

	-- Cooldown swipe
	local level = fState.frame:GetFrameLevel()
	fState.showCDTime = vState.viewer.timerShown -- TODO: Update
	fState.Cooldown = CreateFrame("Cooldown", nil, fState.frame, "CooldownFrameTemplate")
	fState.Cooldown:ClearAllPoints()
	fState.Cooldown:SetFrameLevel(level + 2)
	fState.Cooldown:SetDrawEdge(false)
	fState.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
	fState.Cooldown:SetDrawBling(false)
	fState.Cooldown:SetHideCountdownNumbers(not fState.showCDTime)
	fState.Cooldown:SetCountdownFormatter(CDM.formatter)
	fState.Cooldown:SetCountdownFont(vState.cdFontName)

	-- BUG: Edge and bling are broken in 12.1 They aren't scaled properly and they don't
	-- clip. They show up as a rotating rectangle. So we manually rescale and clip them.
	fState.Clip = CreateFrame("Frame", nil, fState.frame)
	fState.Clip:SetAllPoints(fState.Cooldown)
	fState.Clip:SetFrameLevel(level + 3)
	fState.Clip:SetClipsChildren(true)

	-- Recharge edge
	fState.Recharge = CreateFrame("Cooldown", nil, fState.Clip)
	fState.Recharge:SetPoint("CENTER")
	fState.Recharge:SetFrameLevel(level + 1)
	fState.Recharge:SetDrawSwipe(false)
	fState.Recharge:SetDrawEdge(true)
	fState.Recharge:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")
	fState.Recharge:SetEdgeColor(0.6, 1, 0, 1)
	fState.Recharge:SetHideCountdownNumbers(true)

	fState.Container = CreateFrame("Frame", nil, fState.frame)
	fState.Container:SetAllPoints()
	fState.Container:SetFrameLevel(level + 4)

	-- Press highlight
	fState.Press = fState.Container:CreateTexture(nil, "OVERLAY", nil, 0)
	fState.Press:SetAllPoints(fState.Cooldown)
	fState.Press:SetColorTexture(unpack(CDM.cfg.pressColor))
	fState.Press:SetBlendMode("ADD")
	fState.Press:Hide()

	-- Assist glow
	fState.Assist = fState.Container:CreateTexture(nil, "OVERLAY", nil, 1)
	fState.Assist:SetAllPoints()
	fState.Assist:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	fState.Assist:SetTextureSliceMargins(1, 1, 1, 1)
	fState.Assist:SetVertexColor(unpack(CDM.cfg.assistColor))
	fState.Assist:Hide()

	-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.

	-- Bling
	fState.Bling = CreateFrame("Cooldown", nil, fState.Clip, "CooldownFrameTemplate")
	fState.Bling:ClearAllPoints()
	fState.Bling:SetPoint("CENTER")
	fState.Bling:SetFrameLevel(level + 5)
	fState.Bling:SetDrawSwipe(false)
	fState.Bling:SetDrawEdge(false)
	fState.Bling:SetDrawBling(true)
	fState.Bling:SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
	fState.Bling:SetHideCountdownNumbers(true)
	fState.Bling:SetScript("OnCooldownDone", function(cooldown) fState.hasBling = nil end)

	-- Zoom & aspect ratio
	local z = CDM.cfg.iconZoom
	local a = CDM.cfg.iconAspect
	Kami.Util.RectIcon(fState.frame, fState.frame.Icon, z, a)

	-- NOTE: We round the frame size to make it pixel perfect. If the ui scale changes between frames
	-- being added we can end up rounding to a different size. I think this happens due to floating
	-- point rounding in "effective scale". If we don't scale the frame, we probably end up with
	-- subsequent frames not being positioned on pixel boundaries. Seems like it'll be more of a
	-- fight that way. So we cache the size of the most recent frame and use that for size
	-- calculations later.
	vState.xSize = fState.frame:GetWidth()
	vState.ySize = fState.frame:GetHeight()

	-- Reuse allocation for item durations
	fState.itemDuration = C_DurationUtil.CreateDuration()

	-- Proc glow
	hooksecurefunc(fState.frame, "RefreshOverlayGlow", CDM.ProcGlow)

	-- Don't desaturate trinkets on GCD
	hooksecurefunc(fState.frame, "RefreshIconDesaturation", CDM.OnDesaturate)
end

function CDM.OnFrameRemoved(vState, fState)
	fState.hasBling = nil
	fState.Cooldown:Clear()
	fState.Recharge:Clear()
	fState.Press:Hide()
	fState.Assist:Hide()
	fState.Bling:Clear()

	if CDM.assistGlow == fState then
		CDM.AssistGlow(nil, nil)
	end

	if fState.hasProcGlow then
		CDM.ProcGlow(fState.frame, nil, false)
	end
end

-- TODO: Set assistant glow
-- TODO: Set press overlay
function CDM.RefreshSpells()
	-- NOTE: To show the GCD swipe we run on all frames, regardless of which spell the event is for.

	for spellID, fState in pairs(CDM.spells) do
		local onCD     = false
		local onGCD    = false
		local duration = nil

		-- TODO: Change onCD to not be a super set
		if fState.equipSlot then
			local start, dur, enable = GetInventoryItemCooldown("player", fState.equipSlot)
			fState.itemDuration:SetTimeFromStart(start, dur)
			onCD     = enable and enable ~= 0 and dur ~= 0
			onGCD    = onCD and dur <= 1.5
			duration = fState.itemDuration
		else
			local cd = fState.frame:GetCooldownInfo() -- CooldownViewerCooldown
			spellID = cd.overrideSpellID or spellID

			local cdInfo = C_Spell.GetSpellCooldown(spellID) -- SpellCooldownInfo
			onCD     = cdInfo.isActive
			onGCD    = cdInfo.isOnGCD
			duration = C_Spell.GetSpellCooldownDuration(spellID)
		end

		if onCD then
			local showNumbers = fState.showCDTime and not onGCD
			fState.Cooldown:SetHideCountdownNumbers(not showNumbers)
			fState.Cooldown:SetCooldownFromDurationObject(duration)
		else
			fState.Cooldown:Clear()
		end

		if onCD and not onGCD then
			fState.hasBling = true
			fState.Bling:SetCooldownFromDurationObject(duration, true)
		elseif fState.hasBling then
			fState.hasBling = nil
			fState.Bling:SetCooldownDuration(1e-3)
		end

		local chargeInfo = C_Spell.GetSpellCharges(spellID) -- SpellChargeInfo
		local recharging = chargeInfo and chargeInfo.isActive and (not onCD or onGCD)
		if recharging then
			local duration = C_Spell.GetSpellChargeDuration(spellID)
			fState.Recharge:SetCooldownFromDurationObject(duration)
		else
			fState.Recharge:Clear()
		end
	end
end

function CDM.ProcGlow(frame, showFromEvent, show)
-- NOTE: showFromEvent can be nil, in which case we have to derive it anyway.

	local fState = CDM.frames[frame]
	if show == nil then
		show = ActionButtonSpellAlertManager:HasAlert(fState.frame)
	end

	if show then
		fState.frame.SpellActivationAlert:SetAlpha(0)

		if not fState.hasProcGlow then
			fState.hasProcGlow = true
			-- NOTE: The math here is correcting for the glow not actually being pixel perfect.
			local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / fState.frame:GetEffectiveScale()
			local thickness  = CDM.cfg.procSize * pixelsToUI
			local offset     = 0
			local xSizeEff   = fState.frame:GetWidth()  - thickness + (2 * offset) - 0.05
			local ySizeEff   = fState.frame:GetHeight() - thickness + (2 * offset) - 0.00
			local xOffset    = (Round(xSizeEff) - xSizeEff) / 2 + offset
			local yOffset    = (Round(ySizeEff) - ySizeEff) / 2 + offset
			LCG.PixelGlow_Start(fState.frame, CDM.cfg.procColor, nil, CDM.cfg.procSpeed, nil, thickness, xOffset, yOffset, false)
		end
	else
		if fState.hasProcGlow then
			fState.hasProcGlow = nil
			LCG.PixelGlow_Stop(fState.frame)
		end
	end
end

function CDM.AssistGlow(mgr, oSpellID)

	-- Hide old glow
	if CDM.assistGlow then
		CDM.assistGlow.Assist:Hide()
		CDM.assistGlow = nil
	end

	-- Show new glow
	local fState = oSpellID and (CDM.spells[oSpellID] or CDM.overrides[oSpellID])
	if fState then
		CDM.assistGlow = fState
		fState.Assist:Show()
	end
end

function CDM.OnDesaturate(frame)
	local fState = CDM.frames[frame]
	if fState.equipSlot then
		local start, dur, enable = GetInventoryItemCooldown("player", fState.equipSlot)
		local onCD  = enable and enable ~= 0 and dur ~= 0
		local onGCD = onCD and dur <= 1.5
		frame.Icon:SetDesaturated(onCD and not onGCD)
	end
end

-- TODO: We don't always get paired down/up events. Might want to do more robust cleanup
function CDM.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
	-- NOTE: Macros can cast/use multiple spells/items but there doesn't appear to be a way to get
	-- all of them. GetMacroSpell only returns one spellID.

	-- NOTE: This doesn't fire when clicking items in bags. They don't use a secure frame. We could
	-- hook button frames but it's a per-button hook instead of a global one. We could also use
	-- UNIT_SPELLCAST_SENT/SUCCEEDED/FAILED. The events are better, but still more trouble than it's
	-- worth.

	local buttonType = SecureButton_GetModifiedAttribute(button, "type", mouseButton)
	if buttonType == "action" then
		local slot = button:CalculateAction(mouseButton)
		local actionType, id, subType = GetActionInfo(slot)
		local spellID

		-- plain spell
		if actionType == "spell" then
			spellID = id

		-- /cast macro
		elseif actionType == "macro" and subType == "spell" then
			spellID = id

		-- /use macro
		elseif actionType == "macro" and subType == "item" then
			-- BUG: https://github.com/Stanzilla/WoWUIBugs/issues/495
			-- id seems to be slot - 1
			spellID = C_ActionBar.GetSpell(slot)

		-- plain item
		elseif actionType == "item" then
			spellID = C_ActionBar.GetSpell(slot)
		end

		if spellID then
			local fState = CDM.spells[spellID] or CDM.overrides[spellID]
			if fState then
				-- TODO: There can be multiple active presses
				if CDM.activePress and CDM.activePress ~= fState.Press then
					CDM.activePress:Hide()
				end
				CDM.activePress = fState.Press
				fState.Press:SetShown(down)
			end
		end
	end
end

function CDM.RefreshPositions(viewer)
	local vState = CDM.viewers[viewer]

	local frames = vState.viewer:GetLayoutChildren()
	if #frames == 0 then return end

	local vPixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / vState.viewer:GetEffectiveScale()
	local fPixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / frames[1]:GetEffectiveScale()

	local vxSize = vState.viewer:GetWidth() / vPixelsToUI
	local vxPos  = vState.viewer:GetLeft()  / vPixelsToUI
	local vyPos  = vState.viewer:GetTop()   / vPixelsToUI
	local xSize  = frames[1]:GetWidth()     / fPixelsToUI
	local ySize  = frames[1]:GetHeight()    / fPixelsToUI

	local pad   = vState.viewer.iconPadding
	local limit = vState.viewer.iconLimit

	vxPos = Round(vxPos) - vxPos
	vyPos = Round(vyPos) - vyPos

	for iFrame, frame in ipairs(frames) do
		local iCol = (iFrame - 1) % limit
		local iRow = floor((iFrame - 1) / limit)

		local nRow    = min(limit, #frames - (iRow * limit))
		local rxSize  = nRow * (xSize + pad) - pad
		local xCenter = Round((vxSize - rxSize) / 2)

		local xPos = vxPos + iCol * (xSize + pad) + xCenter
		local yPos = vyPos - iRow * (ySize + pad)

		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", vState.viewer, "TOPLEFT", xPos * fPixelsToUI, yPos * fPixelsToUI)
	end
end

function CDM.RefreshSizesAndPositions()
	-- NOTE: This can get called during login before the viewers have been anchored
	for viewer, vState in pairs(CDM.viewers) do
		if vState.viewer:IsRectValid() then
			CDM.RefreshSizes(vState)
			CDM.RefreshPositions(vState)
		end
	end
end

-- TODO: Pixel perfect is broken after a scale change
-- TODO: Could we set frame scale so local space is pixels? We would only need to update the frame
-- scale here, which is presumably a faster path.
function CDM.RefreshSizes(vState)
	-- NOTE: Our icon ends up visually larger than the built-in. The built in has transparent edges
	-- and an additional padding offset of -4 (viewer:GetAdditionalPaddingOffset()). The base size is
	-- 50px, the ui-to-pixel scale comes out to 1.687 with my current settings. At 100%, the built-in
	-- ends up with a frame size of 85 but a visual size 77. Ours, without the transparent
	-- edges/padding, is visually the full 85px.

	local frames = vState.viewer:GetLayoutChildren()
	if #frames == 0 then return end

	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / frames[1]:GetEffectiveScale()
	local xSize = Kami.Util.RoundToPixel(vState.xSize, pixelsToUI)
	local ySize = Kami.Util.RoundToPixel(vState.ySize, pixelsToUI)

	local cdFontSize = Kami.Util.RoundToPixel(CDM.cfg.cdFontScale * vState.ySize, pixelsToUI)
	vState.cdFont:SetFontHeight(cdFontSize)

	for frame in vState.viewer.itemFramePool:EnumerateActive() do
		local fState = CDM.frames[frame]
		if fState then
			frame:SetSize(xSize, ySize)

			local borderSize = CDM.cfg.borderSize * pixelsToUI
			Kami.Util.SetSliceScale(fState.Border, borderSize)

			local assistSize = CDM.cfg.assistSize * pixelsToUI
			Kami.Util.SetSliceScale(fState.Assist, assistSize)

			Kami.Util.Inset(frame.Icon,       borderSize)
			Kami.Util.Inset(frame.OutOfRange, borderSize)
			Kami.Util.Inset(fState.Cooldown,  borderSize)

			local inset = 2 * borderSize
			local diagSize = sqrt((xSize - inset)^2 + (ySize - inset)^2)
			fState.Recharge:SetSize(diagSize, diagSize)
			fState.Bling:SetSize(diagSize, diagSize)
		end
	end
end

function CDM.SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID)
	if category then
		local fState = CDM.categories[category]
		if fState then
			-- NOTE: If/when we add arbitrary item support this will break when an item and category
			-- resolve to the same spell
			if fState.spellID then
				CDM.spells[fState.spellID] = nil
			end
			fState.spellID = baseSpellID or spellID
			CDM.spells[fState.spellID] = fState
		end
	end
	CDM.RefreshSpells()
end

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

CDM.Load()
