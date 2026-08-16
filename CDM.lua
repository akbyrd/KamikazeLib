local Kami = select(2, ...)
local CDM = {}
Kami.CDM = CDM

-- TODO: What is LibStub?
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

		pressColor = { 1, 1, 1, 0.25 },
	}

	CDM.viewers = {
		EssentialCooldownViewer,
		UtilityCooldownViewer,
	}

	CDM.frame = CreateFrame("Frame", "KL_CDM")
	CDM.frame:SetScript("OnEvent", CDM.OnEvent)
	CDM.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	CDM.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	CDM.frame:RegisterEvent("SPELL_UPDATE_CHARGES")

	hooksecurefunc("SecureActionButton_OnClick", CDM.OnSecureActionButtonClick)

	--for viewer, v in pairs(CDM.viewers) do
	--	hooksecurefunc(viewer, "RefreshLayout", CDM.RefreshLayout)
	--end
end

function CDM.ApplyStyle()
	for iViewer, viewer in ipairs(CDM.viewers) do
		local frames = viewer:GetLayoutChildren() -- TODO: GetItemFrames?
		for iFrame, frame in ipairs(frames) do
			-- Remove mask (reveals the silver border)
			local mask = frame.Icon:GetMaskTexture(1)
			if mask then
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

			-- Cooldown animations
			if not frame.Cooldown2 then
				local level = frame.Cooldown:GetFrameLevel()
				local a = CDM.cfg.iconAspect
				local b = CDM.cfg.iconBorder
				local size = sqrt(1 + min(a, 1/a)^2) * frame:GetWidth() - 2*b

				-- NOTE: The CD/GCD swipes are separate because we don't want the active aura highlight

				-- Cooldown swipe
				frame.Cooldown2 = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
				frame.Cooldown2:SetAllPoints(frame.Cooldown)
				frame.Cooldown2:SetFrameLevel(level + 2)
				frame.Cooldown2:SetDrawEdge(false)
				frame.Cooldown2:SetSwipeColor(0, 0, 0, 0.6)
				frame.Cooldown2:SetDrawBling(false)
				frame.Cooldown2:SetHideCountdownNumbers(false) -- TODO: Use edit mode setting
				frame.Cooldown2:SetScript("OnCooldownDone", function(cooldown) frame.activeSpellID = nil end)

				-- BUG: Edge and bling are broken in 12.1 They aren't scaled properly and they don't
				-- clip. They show up as a rotating rectangle. So we manually rescale and clip them.
				frame.Clip = CreateFrame("Frame", nil, frame)
				frame.Clip:SetAllPoints(frame.Cooldown2)
				frame.Clip:SetClipsChildren(true)

				-- Recharge edge
				frame.Recharge = CreateFrame("Cooldown", nil, frame.Clip)
				frame.Recharge:SetPoint("CENTER")
				frame.Recharge:SetSize(size, size)
				frame.Recharge:SetFrameLevel(level + 1)
				frame.Recharge:SetDrawSwipe(false)
				frame.Recharge:SetDrawEdge(true)
				frame.Recharge:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")
				frame.Recharge:SetEdgeColor(0.6, 1, 0, 1)
				frame.Recharge:SetHideCountdownNumbers(true)

				-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.

				-- Bling
				frame.Bling = CreateFrame("Cooldown", nil, frame.Clip, "CooldownFrameTemplate")
				frame.Bling:SetPoint("CENTER")
				frame.Bling:SetSize(size, size)
				frame.Bling:SetFrameLevel(level + 4)
				frame.Bling:SetDrawSwipe(false)
				frame.Bling:SetDrawEdge(false)
				frame.Bling:SetDrawBling(true)
				frame.Bling:SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
				frame.Bling:SetHideCountdownNumbers(true)

				-- GCD swipe
				frame.GCD = CreateFrame("Cooldown", nil, frame)
				frame.GCD:SetAllPoints(frame.Cooldown2)
				frame.GCD:SetFrameLevel(level + 3)
				frame.GCD:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")
				frame.GCD:SetSwipeColor(0, 0, 0, 0.6)
				frame.GCD:SetHideCountdownNumbers(true)

				-- Press highlight
				frame.Press = CreateFrame("Frame", nil, frame)
				frame.Press:SetAllPoints(frame.Cooldown2)
				frame.Press:SetFrameLevel(level + 5)
				frame.Press:Hide()

				frame.Press.Texture = frame.Press:CreateTexture(nil, "OVERLAY")
				frame.Press.Texture:SetAllPoints()
				frame.Press.Texture:SetColorTexture(unpack(CDM.cfg.pressColor))
				frame.Press.Texture:SetBlendMode("ADD")
			end

			-- Proc glow
			hooksecurefunc(frame, "RefreshOverlayGlow", CDM.ProcGlow)

			-- Zoom & aspect ratio
			local z = CDM.cfg.iconZoom
			local a = CDM.cfg.iconAspect
			local s = max(frame:GetSize())
			Kami.Util.RectIcon(frame, frame.Icon, s, z, a)

			-- Add border (shrink icon, range overlay, and swipe)
			local ppScale = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
			frame.Border1 = frame:CreateTexture(nil, "BACKGROUND", nil, 0) -- TODO: Don't recreate
			frame.Border1:SetAllPoints()
			frame.Border1:SetColorTexture(0, 0, 0, 1)

			frame.Border2 = frame:CreateTexture(nil, "BACKGROUND", nil, 1) -- TODO: Don't recreate
			frame.Border2:SetPoint("TOPLEFT", ppScale, -ppScale)
			frame.Border2:SetPoint("BOTTOMRIGHT", -ppScale, ppScale)
			frame.Border2:SetColorTexture(0, 0, 0, 1)

			local function Inset(f)
				local s = CDM.cfg.iconBorder * ppScale
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", s, -s)
				f:SetPoint("BOTTOMRIGHT", -s, s)
			end
			Inset(frame.Icon)
			Inset(frame.OutOfRange)
			Inset(frame.Cooldown2)
		end
	end
end

--function CDM.RefreshLayout(viewer)
--	print("RefreshLayout", GetTime())
--end

function CDM.RefreshCooldown(frame, trusted)
	-- TODO: Avoid this systemically. 2 problem cases:
	-- 1. SPELL_UPDATE_* events arrive before PLAYER_ENTERING_WORLD
	-- 2. Frame pool grows after we ran init
	-- We can handle those cases and avoid this late decision
	if not frame.Cooldown2 then return end

	-- Spell id can be nil in edit mode. At least 2 spells are always shown.
	local spellID = frame:GetSpellID()
	if not spellID then return end

	-- Pooled items can be rebound to a new spell while an old timeline is running
	if frame.activeSpellID and frame.activeSpellID ~= spellID then
		frame.activeSpellID = nil
		frame.Cooldown2:Clear()
		frame.Bling:Clear()
	end

	if trusted then
		local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
		local onCooldown = cooldownInfo.isActive and not cooldownInfo.isOnGCD
		if onCooldown then
			local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
			frame.activeSpellID = spellID
			frame.Cooldown2:SetCooldownFromDurationObject(duration)
			frame.Bling:SetCooldownFromDurationObject(duration)
		elseif frame.activeSpellID then
			frame.activeSpellID = nil
			frame.Cooldown2:Clear()
			frame.Bling:SetCooldownDuration(1e-3)
		end

		if cooldownInfo.isOnGCD then
			local duration = C_Spell.GetSpellCooldownDuration(spellID, false)
			frame.GCD:SetCooldownFromDurationObject(duration)
		else
			frame.GCD:Clear()
		end
	end

	local chargeInfo = C_Spell.GetSpellCharges(spellID)
	local recharging = chargeInfo and chargeInfo.isActive and not frame.activeSpellID
	if recharging then
		local duration = C_Spell.GetSpellChargeDuration(spellID)
		frame.Recharge:SetCooldownFromDurationObject(duration)
	else
		frame.Recharge:Clear()
	end
end

-- TODO: Might want SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE if it's used for assistant
-- TODO: Try a 9-slice
-- TODO: Should we store state on the frame or in our own table?
function CDM.ProcGlow(frame, show)
	local show = frame.SpellActivationAlert and frame.SpellActivationAlert:IsShown()

	if show then
		if not frame.ProcGlow then
			frame.SpellActivationAlert:SetAlpha(0)
			local ppScale = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
			LCG.PixelGlow_Start(frame, CDM.cfg.procColor, nil, CDM.cfg.procSpeed, nil, CDM.cfg.procWidth * ppScale, nil, nil, false)
		end
	else
		if frame.ProcGlow then
			LCG.PixelGlow_Stop(frame)
		end
	end
	frame.ProcGlow = show
end

-- TODO: We don't always get paired down/up events. Might want to do more robust cleanup
-- TODO: Test mouse 3-5
function CDM.OnSecureActionButtonClick(button, mouseButton, down, isKeyPress, isSecureAction)
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

		if spellID then
			for iViewer, viewer in ipairs(CDM.viewers) do
				for iFrame, frame in ipairs(viewer:GetItemFrames()) do
					local info = frame:GetCooldownInfo()
					if info then
						if spellID == info.spellID or spellID == info.overrideSpellID then
							frame.Press:SetShown(down)

							if CDM.activePress and CDM.activePress ~= frame.Press then
								CDM.activePress.Hide()
								CDM.activePress = frame.Press
							end
						end
					end
				end
			end
		end
	end
end

-- TODO: Direct dispatch for events?
function CDM.OnEvent(frame, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		CDM.ApplyStyle()
	-- TODO: Might be able to use recovery category to check for GCD
	-- SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, spellCategory, startRecoveryCategory, itemID)
	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
		local trusted = event == "SPELL_UPDATE_COOLDOWN"
		-- TODO: Push loops into the function?
		for iViewer, viewer in ipairs(CDM.viewers) do
			local frames = viewer:GetLayoutChildren()
			for iFrame, frame in ipairs(frames) do
				CDM.RefreshCooldown(frame, trusted)
			end
		end
	end
end

CDM.Load()
