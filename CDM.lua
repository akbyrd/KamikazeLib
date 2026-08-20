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

		borderColor = { 0, 0, 0, 1 },
		pressColor  = { 1, 1, 1, 0.25 },
		assistColor = { 0.2, 0.6, 0.95, 1 },
	}

	CDM.frames = {}
	CDM.viewers = {
		EssentialCooldownViewer,
		UtilityCooldownViewer,
	}

	CDM.frame = CreateFrame("Frame", "KL_CDM")
	CDM.frame:SetScript("OnEvent", CDM.OnEvent)
	CDM.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

	hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell", CDM.AssistantGlow)
	hooksecurefunc("SecureActionButton_OnClick", CDM.OnSecureActionButtonClick)

	for iViewer, viewer in ipairs(CDM.viewers) do
		hooksecurefunc(viewer, "RefreshData", CDM.ReconcileFrames)
	end
end

function CDM.ReconcileFrames(viewer, cooldownIDs, forceSet)
	for spellID, frame in pairs(CDM.frames) do
		local cd = frame:GetCooldownInfo() -- CooldownViewerCooldown
		local unbound = cd == nil
		local rebound = cd ~= nil and spellID ~= cd.spellID

		if unbound or rebound then
			CDM.frames[spellID] = nil
			CDM.OnFrameRemoved(frame)
		end
	end

	for frame in viewer.itemFramePool:EnumerateActive() do
		-- TODO: Handle items
		-- spellID         +spell +trinket -pot -stone
		-- spellCategoryID -spell -trinket +pot +stone
		-- cooldownID      +spell +trinket +pot +stone
		--
		-- { Name = "cooldownID",             Type = "number",                      Nilable = false },
		-- { Name = "spellID",                Type = "number",                      Nilable = true },
		-- { Name = "spellCategoryID",        Type = "number",                      Nilable = true },
		-- { Name = "overrideSpellID",        Type = "number",                      Nilable = true },
		-- { Name = "overrideTooltipSpellID", Type = "number",                      Nilable = true },
		-- { Name = "equipSlot",              Type = "luaIndex",                    Nilable = true },
		-- { Name = "buffSlot",               Type = "luaIndex",                    Nilable = true },
		-- { Name = "linkedSpellIDs",         Type = "table", InnerType = "number", Nilable = false },
		-- { Name = "selfAura",               Type = "bool",                        Nilable = false },
		-- { Name = "hasAura",                Type = "bool",                        Nilable = false },
		-- { Name = "charges",                Type = "bool",                        Nilable = false },
		-- { Name = "isKnown",                Type = "bool",                        Nilable = false },
		-- { Name = "isInvisible",            Type = "bool",                        Nilable = false },
		-- { Name = "flags",                  Type = "CooldownSetSpellFlags",       Nilable = false },
		-- { Name = "category",               Type = "CooldownViewerCategory",      Nilable = false },

		local cd = frame:GetCooldownInfo() -- CooldownViewerCooldown
		if cd.spellID then
			CDM.frames[cd.spellID] = frame

			if not frame.Kami then
				frame.Kami = {}
				CDM.OnFrameAdded(frame)
			end
		end
	end

	CDM.RefreshCooldowns()
end

function CDM.OnFrameAdded(frame)
	local state = frame.Kami

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

	-- Cooldown animations
	local level = frame.Cooldown:GetFrameLevel()
	local a = CDM.cfg.iconAspect
	local b = CDM.cfg.iconBorder
	local size = sqrt(1 + min(a, 1/a)^2) * frame:GetWidth() - 2*b

	-- NOTE: The CD/GCD swipes are separate because we don't want the active aura highlight

	-- Cooldown swipe
	state.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	state.Cooldown:SetAllPoints(frame.Cooldown)
	state.Cooldown:SetFrameLevel(level + 1)
	state.Cooldown:SetDrawEdge(false)
	state.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
	state.Cooldown:SetDrawBling(false)
	state.Cooldown:SetHideCountdownNumbers(false) -- TODO: Use edit mode setting
	state.Cooldown:SetScript("OnCooldownDone", function(cooldown) state.onCD = nil end)

	-- BUG: Edge and bling are broken in 12.1 They aren't scaled properly and they don't
	-- clip. They show up as a rotating rectangle. So we manually rescale and clip them.
	state.Clip = CreateFrame("Frame", nil, frame)
	state.Clip:SetAllPoints(state.Cooldown)
	state.Clip:SetClipsChildren(true)

	-- Recharge edge
	state.Recharge = CreateFrame("Cooldown", nil, state.Clip)
	state.Recharge:SetPoint("CENTER")
	state.Recharge:SetSize(size, size)
	state.Recharge:SetFrameLevel(level + 2)
	state.Recharge:SetDrawSwipe(false)
	state.Recharge:SetDrawEdge(true)
	state.Recharge:SetEdgeTexture("Interface\\AddOns\\KamikazeLib\\Media\\CD-Swipe-Edge.tga")
	state.Recharge:SetEdgeColor(0.6, 1, 0, 1)
	state.Recharge:SetHideCountdownNumbers(true)

	-- GCD swipe
	state.GCD = CreateFrame("Cooldown", nil, frame)
	state.GCD:SetAllPoints(state.Cooldown)
	state.GCD:SetFrameLevel(level + 3)
	state.GCD:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")
	state.GCD:SetSwipeColor(0, 0, 0, 0.6)
	state.GCD:SetHideCountdownNumbers(true)

	-- BUG: Bling is broken in 12.1. It occasionally flickers at the end of its duration.

	-- Bling
	state.Bling = CreateFrame("Cooldown", nil, state.Clip, "CooldownFrameTemplate")
	state.Bling:SetPoint("CENTER")
	state.Bling:SetSize(size, size)
	state.Bling:SetFrameLevel(level + 4)
	state.Bling:SetDrawSwipe(false)
	state.Bling:SetDrawEdge(false)
	state.Bling:SetDrawBling(true)
	state.Bling:SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
	state.Bling:SetHideCountdownNumbers(true)

	-- Press highlight
	state.Press = CreateFrame("Frame", nil, frame)
	state.Press:SetAllPoints(state.Cooldown)
	state.Press:SetFrameLevel(level + 5)
	state.Press:Hide()
	state.Press.Texture = state.Press:CreateTexture(nil, "OVERLAY")
	state.Press.Texture:SetAllPoints()
	state.Press.Texture:SetColorTexture(unpack(CDM.cfg.pressColor))
	state.Press.Texture:SetBlendMode("ADD")

	-- TODO: Swap to SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE
	-- Proc glow
	hooksecurefunc(frame, "RefreshOverlayGlow", CDM.ProcGlow)

	-- Zoom & aspect ratio
	local z = CDM.cfg.iconZoom
	local a = CDM.cfg.iconAspect
	local s = max(frame:GetSize())
	Kami.Util.RectIcon(frame, frame.Icon, s, z, a)

	-- TODO: Try a 9-slice
	-- Add border
	local ppScale = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
	state.Border1 = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
	state.Border1:SetAllPoints()
	state.Border1:SetColorTexture(unpack(CDM.cfg.borderColor))

	state.Border2 = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	state.Border2:SetPoint("TOPLEFT", ppScale, -ppScale)
	state.Border2:SetPoint("BOTTOMRIGHT", -ppScale, ppScale)
	state.Border2:SetColorTexture(unpack(CDM.cfg.borderColor))

	-- Shrink all content to fit inside border
	local function Inset(f)
		local s = CDM.cfg.iconBorder * ppScale
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", s, -s)
		f:SetPoint("BOTTOMRIGHT", -s, s)
	end
	Inset(frame.Icon)
	Inset(frame.OutOfRange)
	Inset(state.Cooldown)
end

function CDM.OnFrameRemoved(frame)
	local state = frame.Kami

	state.onCD = nil
	state.Cooldown:Clear()
	state.Bling:Clear()
	state.Recharge:Clear()
	state.GCD:Clear()
	state.Press:Hide()

	if frame == CDM.activeGlow then
		CDM.activeGlow = nil
		state.Border1:SetColorTexture(unpack(CDM.cfg.borderColor))
		state.Border2:SetColorTexture(unpack(CDM.cfg.borderColor))
	end
end

function CDM.RefreshCooldowns()
	-- NOTE: To show the GCD swipe we run on all frames, regardless of which spell the event is for.

	for spellID, frame in pairs(CDM.frames) do
		local state = frame.Kami

		local cdInfo = C_Spell.GetSpellCooldown(spellID) -- SpellCooldownInfo
		local onCooldown = cdInfo.isActive and not cdInfo.isOnGCD
		if onCooldown then
			local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
			state.onCD = true
			state.Cooldown:SetCooldownFromDurationObject(duration)
			state.Bling:SetCooldownFromDurationObject(duration)
		elseif state.onCD then
			state.onCD = nil
			state.Cooldown:Clear()
			state.Bling:SetCooldownDuration(1e-3)
		end

		if cdInfo.isOnGCD then
			local duration = C_Spell.GetSpellCooldownDuration(spellID, false)
			state.GCD:SetCooldownFromDurationObject(duration)
		else
			state.GCD:Clear()
		end

		local chargeInfo = C_Spell.GetSpellCharges(spellID) -- SpellChargeInfo
		local recharging = chargeInfo and chargeInfo.isActive and not state.onCD
		if recharging then
			local duration = C_Spell.GetSpellChargeDuration(spellID)
			state.Recharge:SetCooldownFromDurationObject(duration)
		else
			state.Recharge:Clear()
		end
	end
end

function CDM.ProcGlow(frame, show)
	local state = frame.Kami
	local show = frame.SpellActivationAlert and frame.SpellActivationAlert:IsShown()
	if show then
		if not state.hasProcGlow then
			frame.SpellActivationAlert:SetAlpha(0)
			local ppScale = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
			LCG.PixelGlow_Start(frame, CDM.cfg.procColor, nil, CDM.cfg.procSpeed, nil, CDM.cfg.procWidth * ppScale, nil, nil, false)
		end
	else
		if state.hasProcGlow then
			LCG.PixelGlow_Stop(frame)
		end
	end
	state.hasProcGlow = show
end

-- TODO: How do we handle overlapping borders?
-- TODO: Does this send the base or override spell id?
function CDM.AssistantGlow(mgr, spellID)
	-- Hide old glow
	if CDM.activeGlow then
		local frame = CDM.activeGlow
		local state = frame.Kami

		CDM.activeGlow = nil
		state.Border1:SetColorTexture(unpack(CDM.cfg.borderColor))
		state.Border2:SetColorTexture(unpack(CDM.cfg.borderColor))
	end

	-- Show new glow
	if spellID and CDM.frames[spellID] then
		local frame = CDM.frames[spellID]
		local state = frame.Kami

		CDM.activeGlow = frame
		state.Border1:SetColorTexture(unpack(CDM.cfg.assistColor))
		state.Border2:SetColorTexture(unpack(CDM.cfg.assistColor))
	end
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

function CDM.OnEvent(frame, event, ...)
	if event == "SPELL_UPDATE_COOLDOWN" then
		CDM.RefreshCooldowns()
	end
end

CDM.Load()
