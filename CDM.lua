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

		procColor = { 1, 1, 0, 1},
		procSpeed = 0.15,
		procWidth = 2,
	}

	CDM.viewers = {
		[EssentialCooldownViewer] = true,
		[UtilityCooldownViewer]   = true,
		[BuffIconCooldownViewer]  = true,
		[BuffBarCooldownViewer]   = true,
	}

	CDM.frame = CreateFrame("Frame", "KL_CDM")
	CDM.frame:SetScript("OnEvent", CDM.OnEvent)
	CDM.frame:RegisterEvent("PLAYER_ENTERING_WORLD")

	for iViewer, viewer in ipairs(CDM.viewers) do
		hooksecurefunc(viewer, "RefreshLayout", CDM.RefreshLayout)
	end
end

-- TODO: Disable aura highlight
function CDM.ApplyStyle()
	local viewers = { EssentialCooldownViewer, UtilityCooldownViewer }
	for iViewer, viewer in ipairs(viewers) do
		local frames = viewer:GetLayoutChildren()
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

			-- Hide the out of range overlay
			frame.OutOfRange:SetColorTexture(0, 0, 0, 0)

			-- Hide cooldown
			frame.Cooldown:SetAlpha(0)
			frame.CooldownFlash:SetAlpha(0)

			-- Cooldown animations
			if not frame.Cooldown2 then
				local level = frame.Cooldown:GetFrameLevel()

				-- Cooldown swipe
				frame.Cooldown2 = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
				frame.Cooldown2:SetAllPoints(frame.Cooldown)
				frame.Cooldown2:SetFrameLevel(level + 3)
				frame.Cooldown2:SetDrawEdge(false)
				frame.Cooldown2:SetSwipeColor(0, 0, 0, 0.6)
				frame.Cooldown2:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")
				frame.Cooldown2:SetBlingTexture("Interface\\Cooldown\\starburst", 1, 1, 1, 1)
				frame.Cooldown2:SetHideCountdownNumbers(false) -- TODO: Use edit mode setting
				frame.Cooldown2:SetScript("OnCooldownDone", function(cooldown)
					frame.Cooldown2.wasOnGCD = nil
					frame.Cooldown2.onGCDCount = 0
					frame.Cooldown2.activeSpellID = nil
				end)

				frame.Cooldown2.iViewer = iViewer
				frame.Cooldown2.iFrame = iFrame

				-- Recharge edge
				frame.Recharge = CreateFrame("Cooldown", nil, frame)
				frame.Recharge:SetAllPoints(frame.Cooldown2)
				frame.Recharge:SetFrameLevel(level + 2)
				frame.Recharge:SetDrawSwipe(false)
				frame.Recharge:SetDrawEdge(true)
				frame.Recharge:SetEdgeColor(0.6, 1, 0, 1)
				frame.Recharge:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")
				frame.Recharge:SetHideCountdownNumbers(true)

				-- GCD swipe
				frame.GCD = CreateFrame("Cooldown", nil, frame)
				frame.GCD:SetAllPoints(frame.Cooldown2)
				frame.GCD:SetFrameLevel(level + 1)
				frame.GCD:SetSwipeColor(0, 0, 0, 0.6)
				frame.GCD:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")
				frame.GCD:SetHideCountdownNumbers(true)

				hooksecurefunc(frame.Cooldown, "SetCooldown", function(cooldown, start, duration, modRate) CDM.RefreshCooldown(frame) end)
				hooksecurefunc(frame.Cooldown, "Clear",       function(cooldown)                           CDM.RefreshCooldown(frame) end)
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
			local bSize   = CDM.cfg.iconBorder * ppScale
			frame.Border1 = frame:CreateTexture(nil, "BACKGROUND", nil, 0) -- TODO: Don't recreate
			frame.Border1:SetAllPoints()
			frame.Border1:SetColorTexture(0, 0, 0, 1)

			frame.Border2 = frame:CreateTexture(nil, "BACKGROUND", nil, 1) -- TODO: Don't recreate
			frame.Border2:SetPoint("TOPLEFT", ppScale, -ppScale)
			frame.Border2:SetPoint("BOTTOMRIGHT", -ppScale, ppScale)
			frame.Border2:SetColorTexture(0, 0, 0, 1)

			local function Inset(f)
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", bSize, -bSize)
				f:SetPoint("BOTTOMRIGHT", -bSize, bSize)
			end
			Inset(frame.Icon)
			Inset(frame.OutOfRange)
			Inset(frame.Cooldown2)
		end
	end
end

function CDM.RefreshLayout(viewer)
	--print("RefreshLayout", GetTime())
end

-- TODO: Occasional flicker with bling
-- TODO: Maybe separate the bling?
-- TODO: When an ability is cast while a charge ability has less time remaining than the GCD the recharge edge is enabled early.
-- TODO: Don't play bling when charges instantly refund

-- NOTE: This is incredibly fussy, despite the seemingly simple desired outcome.
-- SetCooldown is called 2-3x when a spell is activated and 1x when a non-final recharge completes
-- Clear() will kill the bling
-- Problem: When a charge spell charge completes, the cooldown is no longer active and Clear kills the bling
-- Solution: When there's no cooldown, end the animation immediately if one is active
--
-- After a GCD finishes, sometimes there's an errant call where isActive is true and isOnGCD is false
-- The duration object is a default / empty one
-- Problem: This tricks us into thinking the spell is on CD and showing a full swipe for a frame
-- Solution: ???
function CDM.RefreshCooldown(frame)
	local spellID = frame:GetSpellID()
	if not spellID then return end

	local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
	local chargeInfo   = C_Spell.GetSpellCharges(spellID)

	-- isActive false, isOnGCD nil   - init
	-- isActive true,  isOnGCD true  - cast x2 (on gcd until server confirms cast)
	-- isActive true,  isOnGCD false - cast x2 (actually cast)
	-- isActive true,  isOnGCD nil   - done

	-- isActive true,  isOnGCD false - cast
	-- isActive true,  isOnGCD true  - other
	-- isActive false, isOnGCD false - done
	-- isActive true,  isOnGCD false - bad frame ()

	if cooldownInfo.isActive then
		if frame.Cooldown2.wasOnGCD ~= cooldownInfo.isOnGCD then
			frame.Cooldown2.wasOnGCD = cooldownInfo.isOnGCD
			if frame.Cooldown2.wasOnGCD then
				frame.Cooldown2.onGCDCount = (frame.Cooldown2.onGCDCount or 0) + 1
			end
		end
	end

	if frame.Cooldown2.iViewer == 1 and frame.Cooldown2.iFrame == 2 then
		print(GetTime(), cooldownInfo.isActive, cooldownInfo.isOnGCD, frame.Cooldown2.onGCDCount)
	end

	local onCooldown = cooldownInfo.isActive and not cooldownInfo.isOnGCD
	if onCooldown and frame.Cooldown2.onGCDCount ~= 2 then
		if frame.Cooldown2.activeSpellID == nil then
			local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
			frame.Cooldown2.activeSpellID = spellID
			frame.Cooldown2:SetDrawSwipe(true)
			frame.Cooldown2:SetCooldownFromDurationObject(duration)
		end
	else
		if frame.Cooldown2.activeSpellID then
			frame.Cooldown2.wasOnGCD = nil
			frame.Cooldown2.onGCDCount = 0
			frame.Cooldown2.activeSpellID = nil
			frame.Cooldown2:SetDrawSwipe(false)
			frame.Cooldown2:SetCooldownDuration(1e-3)
		end
	end

	local recharging = chargeInfo and chargeInfo.isActive and not onCooldown
	if recharging then
		local duration = C_Spell.GetSpellChargeDuration(spellID)
		frame.Recharge:SetCooldownFromDurationObject(duration)
	else
		frame.Recharge:Clear()
	end

	if cooldownInfo.isOnGCD then
		local duration = C_Spell.GetSpellCooldownDuration(spellID, false)
		frame.GCD:SetCooldownFromDurationObject(duration)
	else
		frame.GCD:Clear()
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

function CDM.OnEvent(frame, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		CDM.ApplyStyle()
	end
end

CDM.Load()

-- NOTE: Potentially useful things
-- EssentialCooldownViewer:MarkDirty()
