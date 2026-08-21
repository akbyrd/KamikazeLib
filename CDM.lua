local Kami = select(2, ...)
local CDM = {}
Kami.CDM = CDM

local LCG = LibStub("LibCustomGlow-1.0")

-- TODO: Look for hex conversion utility
function CDM.Load()
	CDM.cfg = {
		iconZoom   = 0.08,
		iconBorder = 2,
		iconAspect = 1.65,

		procColor = { 1, 1, 0, 1 },
		procSpeed = 0.15,
		procWidth = 2,

		borderColor = { 0, 0, 0, 1 },
		pressColor  = { 1, 1, 1, 0.25 },
		assistColor = { 0.2, 0.6, 0.95, 1 },
	}

	-- TODO: Simplify these lookups
	CDM.frames = {}
	CDM.overrides = {}

	CDM.viewers = {
		[EssentialCooldownViewer] = {},
		[UtilityCooldownViewer]   = {},
	}

	CDM.handlers = {}
	CDM.frame = CreateFrame("Frame", "KL_CDM")
	CDM.frame:SetScript("OnEvent", CDM.DispatchEvent)

	CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN", CDM.RefreshSpells)
	CDM.RegisterEvent("BAG_UPDATE_COOLDOWN",   CDM.RefreshSpells)
	CDM.RegisterEvent("UI_SCALE_CHANGED",      CDM.RefreshSizesAndPositions)
	CDM.RegisterEvent("DISPLAY_SIZE_CHANGED",  CDM.RefreshSizesAndPositions)

	hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell", CDM.AssistantGlow)
	hooksecurefunc("SecureActionButton_OnClick", CDM.OnClick)

	for viewer, vState in pairs(CDM.viewers) do
		hooksecurefunc(viewer, "RefreshData", CDM.ReconcileFrames)
		hooksecurefunc(viewer, "Layout",      CDM.RefreshPositions)
	end
end

function CDM.ReconcileFrames(viewer, cooldownIDs, forceSet)
	-- NOTE: This can run in combat in a couple of potentially common cases:
	-- Pet summon/dismiss/death
	-- Some procs?

	local vState = CDM.viewers[viewer]

	for spellID, frame in pairs(CDM.frames) do
		local cd = frame:GetCooldownInfo() -- CooldownViewerCooldown
		local unbound = cd == nil
		local rebound = cd ~= nil and spellID ~= cd.spellID

		if unbound or rebound then
			local state = frame.Kami
			CDM.frames[spellID] = nil
			state.equipSlot = nil

			if state.overrideSpellID then
				CDM.overrides[state.overrideSpellID] = nil
				state.overrideSpellID = nil
			end

			CDM.OnFrameRemoved(viewer, vState, frame)
		end
	end

	-- NOTE: This re-adds / updates without necessarily removing first.
	for frame in viewer.itemFramePool:EnumerateActive() do
		CDM.OnFrameAdded(viewer, vState, frame)

		local cd = frame:GetCooldownInfo() -- CooldownViewerCooldown
		if cd and cd.spellID then
			local state = frame.Kami
			CDM.frames[cd.spellID] = frame
			state.equipSlot = cd.equipSlot

			if cd.overrideSpellID then
				CDM.overrides[cd.overrideSpellID] = frame
				state.overrideSpellID = cd.overrideSpellID
			end
		end
	end

	-- TODO: Remove this once we confirm it doesn't fire in combat too often
	--print(string.format("%.3f %s %s", GetTime(), tostring(viewer), "ReconcileFrames"))

	CDM.RefreshSpells()
	CDM.RefreshSizes(viewer, vState)
end

function CDM.OnFrameAdded(viewer, vState, frame)
	if frame.Kami then return end
	frame.Kami = {}
	local state = frame.Kami

	-- Frame stack:
	-- Built-in
	-- - Frame
	-- - Icon
	-- - Cooldown
	-- - CooldownFlash
	-- - OutOfRange
	--
	-- Added                   (Parent   Anchor    Inset)
	-- - (Frame)   Cooldown -> Frame     Frame     Yes
	-- - (Frame)   Recharge -> Cooldown  Cooldown  Yes
	-- - (Frame)   Bling    -> Cooldown  Cooldown  Yes
	-- - (Frame)   Press    -> Cooldown  Cooldown  Yes
	-- - (Texture) Border1  -> ----      Frame?    No
	-- - (Texture) Border2  -> ----      Frame?    Special

	-- Remove mask (reveals the silver border)
	for i = 1, frame.Icon:GetNumMaskTextures() do
		local mask = frame.Icon:GetMaskTexture(i)
		frame.Icon:RemoveMaskTexture(mask)
	end

	-- Hide the overlay
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetAtlas and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
			region:Hide()
		end
	end

	-- Hide the out of range overlay and built-in cooldown
	frame.OutOfRange:SetAlpha(0)
	frame.Cooldown:SetAlpha(0)
	frame.CooldownFlash:SetAlpha(0)

	-- NOTE: The CD swipe is replaced because we don't want the active aura highlight

	-- Cooldown swipe
	local level = frame.Cooldown:GetFrameLevel()
	state.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	state.Cooldown:SetFrameLevel(level + 1)
	state.Cooldown:SetDrawEdge(false)
	state.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
	state.Cooldown:SetDrawBling(false)
	state.Cooldown:SetHideCountdownNumbers(not viewer.timerShown) -- TODO: Update

	-- BUG: Edge and bling are broken in 12.1 They aren't scaled properly and they don't
	-- clip. They show up as a rotating rectangle. So we manually rescale and clip them.
	state.Cooldown:SetClipsChildren(true)

	-- Recharge edge
	state.Recharge = CreateFrame("Cooldown", nil, state.Cooldown)
	state.Recharge:SetPoint("CENTER")
	state.Recharge:SetFrameLevel(level + 2)
	state.Recharge:SetDrawSwipe(false)
	state.Recharge:SetDrawEdge(true)
	state.Recharge:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")
	state.Recharge:SetEdgeColor(0.6, 1, 0, 1)
	state.Recharge:SetHideCountdownNumbers(true)

	-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.

	-- Bling
	state.Bling = CreateFrame("Cooldown", nil, state.Cooldown, "CooldownFrameTemplate")
	state.Bling:SetPoint("CENTER")
	state.Bling:SetFrameLevel(level + 3)
	state.Bling:SetDrawSwipe(false)
	state.Bling:SetDrawEdge(false)
	state.Bling:SetDrawBling(true)
	state.Bling:SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
	state.Bling:SetHideCountdownNumbers(true)
	state.Bling:SetScript("OnCooldownDone", function(cooldown) state.hasBling = nil end)

	-- Press highlight
	state.Press = CreateFrame("Frame", nil, state.Cooldown)
	state.Press:SetAllPoints()
	state.Press:SetFrameLevel(level + 4)
	state.Press:Hide()
	state.Press.Texture = state.Press:CreateTexture(nil, "OVERLAY")
	state.Press.Texture:SetAllPoints()
	state.Press.Texture:SetColorTexture(unpack(CDM.cfg.pressColor))
	state.Press.Texture:SetBlendMode("ADD")

	-- Zoom & aspect ratio
	local z = CDM.cfg.iconZoom
	local a = CDM.cfg.iconAspect
	Kami.Util.RectIcon(frame, frame.Icon, z, a)

	-- TODO: Try a 9-slice
	-- Add border
	state.Border1 = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
	state.Border1:SetAllPoints()
	state.Border1:SetColorTexture(unpack(CDM.cfg.borderColor))

	state.Border2 = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	state.Border2:SetColorTexture(unpack(CDM.cfg.borderColor))

	-- NOTE: We round the frame size to make it pixel perfect. If the ui scale changes between frames
	-- being added we can end up rounding to a different size. I think this happens due to floating
	-- point rounding in "effective scale". If we don't scale the frame, we probably end up with
	-- subsequent frames not being positioned on pixel boundaries. Seems like it'll be more of a
	-- fight that way. So we cache the size of the most recent frame and use that for size
	-- calculations later.
	vState.xSize = frame:GetWidth()
	vState.ySize = frame:GetHeight()

	-- Reuse allocation for item durations
	state.itemDuration = C_DurationUtil.CreateDuration()

	-- Proc glow
	hooksecurefunc(frame, "RefreshOverlayGlow", CDM.ProcGlow)

	-- Don't desaturate trinkets on GCD
	hooksecurefunc(frame, "RefreshIconDesaturation", CDM.OnDesaturate)
end

function CDM.OnFrameRemoved(viewer, vState, frame)
	local state = frame.Kami

	state.hasBling = nil
	state.Cooldown:Clear()
	state.Recharge:Clear()
	state.Bling:Clear()
	state.Press:Hide()

	if frame == CDM.activeGlow then
		CDM.activeGlow = nil
		state.Border1:SetColorTexture(unpack(CDM.cfg.borderColor))
		state.Border2:SetColorTexture(unpack(CDM.cfg.borderColor))
	end
end

-- TODO: Set assistant glow
-- TODO: Set press overlay
function CDM.RefreshSpells()
	-- NOTE: To show the GCD swipe we run on all frames, regardless of which spell the event is for.

	for spellID, frame in pairs(CDM.frames) do
		local state = frame.Kami

		local onCD     = false
		local onGCD    = false
		local duration = nil

		-- TODO: Change onCD to not be a super set
		if state.equipSlot then
			local start, dur, enable = GetInventoryItemCooldown("player", state.equipSlot)
			state.itemDuration:SetTimeFromStart(start, dur)
			onCD     = enable and enable ~= 0 and dur ~= 0
			onGCD    = onCD and dur <= 1.5
			duration = state.itemDuration
		else
			local cd = frame:GetCooldownInfo() -- CooldownViewerCooldown
			spellID = cd.overrideSpellID or spellID

			local cdInfo = C_Spell.GetSpellCooldown(spellID) -- SpellCooldownInfo
			onCD     = cdInfo.isActive
			onGCD    = cdInfo.isOnGCD
			duration = C_Spell.GetSpellCooldownDuration(spellID)
		end

		if onCD then
			state.Cooldown:SetCooldownFromDurationObject(duration)
		else
			state.Cooldown:Clear()
		end

		if onCD and not onGCD then
			state.hasBling = true
			state.Bling:SetCooldownFromDurationObject(duration, true)
		elseif state.hasBling then
			state.hasBling = nil
			state.Bling:SetCooldownDuration(1e-3)
		end

		local chargeInfo = C_Spell.GetSpellCharges(spellID) -- SpellChargeInfo
		local recharging = chargeInfo and chargeInfo.isActive and (not onCD or onGCD)
		if recharging then
			local duration = C_Spell.GetSpellChargeDuration(spellID)
			state.Recharge:SetCooldownFromDurationObject(duration)
		else
			state.Recharge:Clear()
		end
	end
end

function CDM.ProcGlow(frame, showFromEvent)
	-- NOTE: showFromEvent can be nil, in which case we have to derive it anyway.

	local state = frame.Kami
	local show = ActionButtonSpellAlertManager:HasAlert(frame)
	if show then
		frame.SpellActivationAlert:SetAlpha(0)

		if not state.hasProcGlow then
			state.hasProcGlow = true
			-- NOTE: The math here is correcting for the glow not actually being pixel perfect.
			local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
			local thickness  = CDM.cfg.procWidth * pixelsToUI
			local xSizeEff   = frame:GetWidth()  - thickness - 0.05
			local ySizeEff   = frame:GetHeight() - thickness - 0.00
			local xOffset    = (Round(xSizeEff) - xSizeEff) / 2
			local yOffset    = (Round(ySizeEff) - ySizeEff) / 2
			LCG.PixelGlow_Start(frame, CDM.cfg.procColor, nil, CDM.cfg.procSpeed, nil, thickness, xOffset, yOffset, false)
		end
	else
		if state.hasProcGlow then
			state.hasProcGlow = false
			LCG.PixelGlow_Stop(frame)
		end
	end
end

-- TODO: How do we handle overlapping borders?
function CDM.AssistantGlow(mgr, oSpellID)
	-- Hide old glow
	if CDM.activeGlow then
		local frame = CDM.activeGlow
		local state = frame.Kami

		CDM.activeGlow = nil
		state.Border1:SetColorTexture(unpack(CDM.cfg.borderColor))
		state.Border2:SetColorTexture(unpack(CDM.cfg.borderColor))
	end

	-- Show new glow
	if oSpellID then
		local frame = CDM.frames[oSpellID] or CDM.overrides[oSpellID]
		if frame then
			local state = frame.Kami

			CDM.activeGlow = frame
			state.Border1:SetColorTexture(unpack(CDM.cfg.assistColor))
			state.Border2:SetColorTexture(unpack(CDM.cfg.assistColor))
		end
	end
end

function CDM.OnDesaturate(frame)
	local state = frame.Kami
	if state.equipSlot then
		local start, dur, enable = GetInventoryItemCooldown("player", state.equipSlot)
		local onCD  = enable and enable ~= 0 and dur ~= 0
		local onGCD = onCD and dur <= 1.5
		frame.Icon:SetDesaturated(onCD and not onGCD)
	end
end

-- TODO: We don't always get paired down/up events. Might want to do more robust cleanup
function CDM.OnClick(button, mouseButton, down, isKeyPress, isSecureAction)
	local actionType = SecureButton_GetModifiedAttribute(button, "type", mouseButton)
	if actionType == "action" then
		local slot = button:CalculateAction(mouseButton)
		local slotType, id, subType = GetActionInfo(slot)
		local spellID

		if slotType == "spell" then
			spellID = id

		elseif slotType == "macro" and subType == "spell" then
			spellID = id

		elseif slotType == "macro" then
			spellID = GetMacroSpell(id)

		elseif slotType == "item" then
			spellID = C_ActionBar.GetSpell(slot)
		end

		if spellID and CDM.frames[spellID] then
			local frame = CDM.frames[spellID]
			local state = frame.Kami

			-- TODO: There can be multiple active presses
			if CDM.activePress and CDM.activePress ~= state.Press then
				CDM.activePress:Hide()
			end
			CDM.activePress = state.Press
			state.Press:SetShown(down)
		end
	end
end

-- TODO: Orientation and direction
function CDM.RefreshPositions(viewer)
	local frames = viewer:GetLayoutChildren()
	if #frames == 0 then return end

	local vPixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / viewer:GetEffectiveScale()
	local fPixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / frames[1]:GetEffectiveScale()

	local vxSize = viewer:GetWidth()     / vPixelsToUI
	local vxPos  = viewer:GetLeft()      / vPixelsToUI
	local vyPos  = viewer:GetTop()       / vPixelsToUI
	local xSize  = frames[1]:GetWidth()  / fPixelsToUI
	local ySize  = frames[1]:GetHeight() / fPixelsToUI

	local pad   = viewer.iconPadding
	local limit = viewer.iconLimit

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
		frame:SetPoint("TOPLEFT", viewer, "TOPLEFT", xPos * fPixelsToUI, yPos * fPixelsToUI)
	end
end

-- TODO: Handle position changes through Edit Mode
function CDM.RefreshSizesAndPositions()
	-- NOTE: This can get called during login before the viewers have been anchored
	for viewer, vState in pairs(CDM.viewers) do
		if viewer:IsRectValid() then
			CDM.RefreshSizes(viewer, vState)
			CDM.RefreshPositions(viewer)
		end
	end
end

function CDM.RefreshSizes(viewer, vState)
	-- NOTE: Our icon ends up visually larger than the built-in. The built in has transparent edges
	-- and an additional padding offset of -4 (viewer:GetAdditionalPaddingOffset()). The base size is
	-- 50px, the ui-to-pixel scale comes out to 1.687 with my current settings. At 100%, the built-in
	-- ends up with a frame size of 84

	local frames = viewer:GetLayoutChildren()
	if #frames == 0 then return end

	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / frames[1]:GetEffectiveScale()
	local xSize = Round(vState.xSize / pixelsToUI) * pixelsToUI
	local ySize = Round(vState.ySize / pixelsToUI) * pixelsToUI

	for frame in viewer.itemFramePool:EnumerateActive() do
		if frame.Kami then
			local state = frame.Kami
			frame:SetSize(xSize, ySize)

			local onePx = 1 * pixelsToUI
			CDM.Inset(state.Border2, onePx)

			local borderSize = CDM.cfg.iconBorder * pixelsToUI
			CDM.Inset(frame.Icon,       borderSize)
			CDM.Inset(frame.OutOfRange, borderSize)
			CDM.Inset(state.Cooldown,   borderSize)

			local inset = 2 * borderSize
			local diagSize = sqrt((xSize - inset)^2 + (ySize - inset)^2)
			state.Recharge:SetSize(diagSize, diagSize)
			state.Bling:SetSize(diagSize, diagSize)
		end
	end
end

function CDM.Inset(frame, amount)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT",      amount, -amount)
	frame:SetPoint("BOTTOMRIGHT", -amount,  amount)
end

function CDM.RegisterEvent(event, func)
	CDM.frame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

CDM.Load()
