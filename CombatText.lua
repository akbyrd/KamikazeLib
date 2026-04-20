local CT = {}
Kami = {}
Kami.CT = CT

function CT.Init()
	CT.playerGUID = UnitGUID("player")
	CT.lastSource = nil
	CT.elements   = {}
	CT.iTail      = 1
	CT.nActive    = 0
	CT.cfg        = {
		iconSize     = 20,
		iconZoom     = .08,
		font         = nil,
		fontDesired  = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Homespun.ttf",
		fontFallback = "GameFontNormal",
		fontSize     = 24,
		fadeDelay    = 1.0,
		fadeDuration = 0.5,
		scrollDist   = 30,
	}

	for k, v in pairs(Enum.DamageMeterType) do
		Enum.DamageMeterType[v] = k
	end

	CT.frame = CreateFrame("Frame", "KL_COMBAT_TEXT", UIParent)
	CT.frame:SetSize(100, 100)
	CT.frame:SetPoint("CENTER")
	CT.frame:SetScript("OnEvent", CT.OnEvent)
	CT.frame:SetScript("OnUpdate", CT.OnUpdate)
	CT.frame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	CT.frame:RegisterEvent("DAMAGE_METER_RESET")

	-- TODO: Remove
	local bg = CT.frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.5)

	local tempLabel = CT.frame:CreateFontString(nil, "OVERLAY", nil)
	local success = tempLabel:SetFont(CT.cfg.fontDesired, 12)
	CT.cfg.font = success and CT.cfg.fontDesired or CT.cfg.fontFallback
end

function CT.OnEvent(frame, event, ...)
	CT[event](...)
end

function CT.DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)
	if type == Enum.DamageMeterType.DamageDone then
		if sessionID == 0 then
			local sessionType = Enum.DamageMeterSessionType.Current
			local sourceGUID  = CT.playerGUID
			local source      = C_DamageMeter.GetCombatSessionSourceFromType(sessionType, type, sourceGUID)

			CT.lastSource = source
			C_DamageMeter.ResetAllCombatSessions()
		end
	end
end

function CT.DAMAGE_METER_RESET()
	if CT.lastSource then
		CT.DisplaySource(CT.lastSource)
		CT.lastSource = nil
	end
end

function CT.CreateElement()
	local frameHeight = max(CT.cfg.iconSize, CT.cfg.fontSize)
	local frame       = CreateFrame("Frame", nil, CT.frame)
	frame:SetPoint("LEFT",  CT.frame, "LEFT")
	frame:SetPoint("RIGHT", CT.frame, "RIGHT")
	frame:SetPoint("BOTTOM", CT.frame, "BOTTOM", 0, 0)
	frame:SetHeight(frameHeight)
	frame:Hide()

	local label = frame:CreateFontString(nil, "OVERLAY", nil)
	label:SetHeight(frameHeight)
	label:SetFont(CT.cfg.font, CT.cfg.fontSize, "OUTLINE")
	label:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -(100 - 80) / 2, 0)

	local texMin = 0 + CT.cfg.iconZoom
	local texMax = 1 - CT.cfg.iconZoom
	local icon   = frame:CreateTexture(nil, "OVERLAY")
	icon:SetSize(CT.cfg.iconSize, CT.cfg.iconSize)
	icon:SetTexCoord(texMin, texMax, texMin, texMax)
	icon:SetPoint("RIGHT", label, "LEFT", -8, -.0625 * CT.cfg.fontSize)

	-- TODO: Remove
	do
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.5)

		local iconBg = frame:CreateTexture(nil, "BACKGROUND")
		iconBg:SetAllPoints(icon)
		iconBg:SetColorTexture(1, 0, 0, 0.5)

		local labelBg = frame:CreateTexture(nil, "BACKGROUND")
		labelBg:SetAllPoints(label)
		labelBg:SetColorTexture(0, 0, 1, 0.5)
	end

	local elem = {
		frame    = frame,
		icon     = icon,
		label    = label,
		yPosInit = nil,
		tShow    = nil,
	}
	return elem
end

function CT.ShowElement(elem, index, spell)
	elem.yPosInit = (index - 1) * CT.cfg.iconSize
	elem.tShow    = GetTime()
	elem.icon:SetTexture(C_Spell.GetSpellTexture(spell.spellID))
	elem.label:SetText(AbbreviateNumbers(spell.totalAmount))
	elem.frame:SetAlpha(1)
	elem.frame:SetPointsOffset(0, elem.yPosInit)
	elem.frame:Show()
end

function CT.HideElement(elem)
	elem.yPosInit = nil
	elem.tShow    = nil
	elem.icon:SetTexture("Interface\\Icons\\Inv_misc_questionmark")
	elem.label:SetText("Inactive")
	elem.frame:SetAlpha(1)
	elem.frame:Hide()
end

-- TODO: Attach to target nameplate
-- TODO: Improve animations (separate in and out, maybe add scale)
-- TODO: Fade current frames if new frames come in early (bloodlust)
-- TODO: Incoming damage
-- TODO: Simplify index handling (position, offset, index?) (current is still buggy)
-- TODO: Sort by spellId (if built-in function exists)

function CT.DisplaySource(source)
	local nSpell = #source.combatSpells
	local nElem  = #CT.elements

	-- Create new elements
	while nElem < CT.nActive + nSpell do
		local elem = CT.CreateElement()
		table.insert(CT.elements, CT.iTail, elem)
		if nElem ~= 0 then
			CT.iTail = CT.iTail + 1
		end
		nElem = nElem + 1
	end

	-- Show new active elements
	for iSpell = 1, nSpell do
		local spell = source.combatSpells[iSpell]

		local iElem = (CT.iTail - 1 + CT.nActive + iSpell - 1) % nElem + 1
		local elem  = CT.elements[iElem]

		CT.ShowElement(elem, iSpell, spell)
		CT.nActive = CT.nActive + 1
	end
end

function CT.OnUpdate(frame, elapsed)
	local nElem = #CT.elements
	local tNow  = GetTime()

	-- Hide inactive elements
	for i = 1, CT.nActive do
		local elem  = CT.elements[CT.iTail]

		local tHide = elem.tShow + CT.cfg.fadeDelay + CT.cfg.fadeDuration
		if tNow >= tHide then
			CT.iTail   = (CT.iTail - 1 + 1) % nElem + 1
			CT.nActive = CT.nActive - 1
			CT.HideElement(elem)
		else
			break
		end
	end

	-- Animate active elements
	for i = 1, CT.nActive do
		local iElem = (CT.iTail - 1 + i - 1) % nElem + 1
		local elem  = CT.elements[iElem]

		local t = Clamp((tNow - elem.tShow - CT.cfg.fadeDelay) / CT.cfg.fadeDuration, 0, 1)
		elem.frame:SetPointsOffset(0, elem.yPosInit + t * CT.cfg.scrollDist)
		elem.frame:SetAlpha(1 - t)
	end
end

CT.Init()

-- NOTE: Have to clear meters because we can't compare amount with previous (totalAmount is secret)
-- NOTE: Can't ignore spells (spellID is secret)
