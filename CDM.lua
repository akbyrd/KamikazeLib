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

	for i, viewer in ipairs(CDM.viewers) do
		hooksecurefunc(viewer, "RefreshLayout", CDM.RefreshLayout)
	end
end

-- TODO: Disable aura highlight
function CDM.ApplyStyle()
	local viewers = { EssentialCooldownViewer, UtilityCooldownViewer }
	for i, viewer in ipairs(viewers) do
		local frames = viewer:GetLayoutChildren()
		for i, frame in ipairs(frames) do
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

			-- Replace swipe texture and extend the edge
			frame.Cooldown:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")
			frame.Cooldown:SetEdgeColor(0.6, 1, 0, 1)
			frame.Cooldown:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")

			-- Animation when cooldown finishes
			frame.CooldownFlash:SetAlpha(0)
			if not frame.Bling then
				frame.Bling = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
				frame.Bling:SetBlingTexture("Interface\\Cooldown\\starburst")
				frame.Bling:SetAllPoints(frame.Cooldown)
				frame.Bling:SetDrawSwipe(false)
				frame.Bling:SetDrawEdge(false)
				frame.Bling:SetHideCountdownNumbers(true)
				frame.Bling:Show()

				hooksecurefunc(frame.Cooldown, "SetCooldown", function(cooldown, start, duration, modRate)
					local spellID = frame:GetSpellID()
					if spellID then

						local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
						if cooldownInfo and cooldownInfo.isActive and not cooldownInfo.isOnGCD then

							local duration = C_Spell.GetSpellCooldownDuration(spellID)
							frame.Bling:SetCooldownFromDurationObject(duration)
						end
					end
				end)
			end

			-- GCD for spells with charges
			if not frame.GCD then
				frame.GCD = CreateFrame("Cooldown", nil, frame)
				frame.GCD:SetAllPoints(frame.Cooldown)
				frame.GCD:SetFrameLevel(frame.Cooldown:GetFrameLevel() + 1)
				frame.GCD:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")
				frame.GCD:SetSwipeColor(0, 0, 0, 0.6)
				frame.GCD:SetDrawEdge(true)
				frame.GCD:SetHideCountdownNumbers(true)

				hooksecurefunc(frame.Cooldown, "SetCooldown", function(cooldown, start, duration, modRate)
					local spellID = frame:GetSpellID()
					local cd = C_Spell.GetSpellCooldown(spellID)
					local count = C_Spell.GetSpellDisplayCount(spellID) or 0

					if cd.isOnGCD == nil then
						frame.GCD.fromZero = false
					end

					if cd.isOnGCD then
						if not frame.GCD.fromZero then
							local duration = C_Spell.GetSpellCooldownDuration(spellID)
							frame.GCD:SetCooldownFromDurationObject(duration)
						end
					else
						frame.GCD.fromZero = true
						frame.GCD:Clear()
					end
				end)
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
			Inset(frame.Cooldown)
		end
	end
end

function CDM.RefreshLayout(viewer)
	--print("RefreshLayout", GetTime())
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
