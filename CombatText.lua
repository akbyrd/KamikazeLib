local CT = {}
Kami = {}
Kami.CT = CT

function CT.Init()
	CT.frame       = nil
	CT.anchorFrame = nil
	CT.playerGUID  = UnitGUID("player")
	CT.lastSource  = nil
	CT.elements    = {}
	CT.iTail       = 1
	CT.nActive     = 0
	CT.cfg         = {
		iconSize     = 24,
		iconZoom     = .08,
		iconAspect   = 1.3,
		font         = nil,
		fontDesired  = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Homespun.ttf",
		fontFallback = "GameFontNormal",
		fontSize     = 24,
		fadeDelay    = 1.0,
		fadeDuration = 0.35,
		scrollDist   = 30,
	}

	CT.frame = CreateFrame("Frame", "KL_COMBAT_TEXT", UIParent)
	CT.frame:SetSize(100, 100)
	CT.frame:SetPoint("LEFT", UIParent, "CENTER", 100, 0)
	CT.frame:SetScript("OnEvent", CT.OnEvent)
	CT.frame:SetScript("OnUpdate", CT.OnUpdate)
	CT.frame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	CT.frame:RegisterEvent("DAMAGE_METER_RESET")
	CT.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	CT.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	CT.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

	CT.anchorFrame = CT.frame

	-- TODO: Remove
	local bg = CT.frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.5)

	local tempLabel = CT.frame:CreateFontString(nil, "BACKGROUND", nil)
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

function CT.SetAnchor(frame)
	if frame then
		CT.anchorFrame  = frame
		CT.anchorPoint  = "TOP"
		CT.anchorOffset = -17 + 4
	else
		CT.anchorFrame  = CT.frame
		CT.anchorPoint  = "BOTTOM"
		CT.anchorOffset = 0
	end
end

function CT.PLAYER_TARGET_CHANGED()
	local nameplate = C_NamePlate.GetNamePlateForUnit("target")
	CT.SetAnchor(nameplate)
end

function CT.NAME_PLATE_UNIT_ADDED(unitID)
	if UnitIsUnit(unitID, "target") then
		local nameplate = C_NamePlate.GetNamePlateForUnit(unitID)
		CT.SetAnchor(nameplate)
	end
end

function CT.NAME_PLATE_UNIT_REMOVED(unitID)
	if UnitIsUnit(unitID, "target") then
		CT.SetAnchor(nil)
	end
end

function CT.CreateElement()
	local frameHeight = max(CT.cfg.iconSize, CT.cfg.fontSize)
	local frame       = CreateFrame("Frame", nil, CT.frame)
	frame:SetSize(100, frameHeight)
	frame:SetParent(CT.frame)
	frame:Hide()

	local label = frame:CreateFontString(nil, "BACKGROUND", nil)
	label:SetHeight(frameHeight)
	label:SetFont(CT.cfg.font, CT.cfg.fontSize, "OUTLINE")
	label:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -(100 - 80) / 2, 0)
	label:SetTextColor(1, 0.87, 0)

	local xFactor = 1 * min(1, CT.cfg.iconAspect)
	local yFactor = 1 / max(1, CT.cfg.iconAspect)
	local texXMin = 0.5 - (0.5 - CT.cfg.iconZoom) * xFactor
	local texYMin = 0.5 - (0.5 - CT.cfg.iconZoom) * yFactor
	local icon   = frame:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(CT.cfg.iconSize * xFactor, CT.cfg.iconSize * yFactor)
	icon:SetTexCoord(texXMin, 1 - texXMin, texYMin, 1 - texYMin)
	icon:SetPoint("RIGHT", label, "LEFT", -6, -.0625 * CT.cfg.fontSize)

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
	elem.yPosInit = CT.anchorOffset + (index - 1) * (CT.cfg.iconSize + 2)
	elem.tShow    = GetTime()
	elem.icon:SetTexture(C_Spell.GetSpellTexture(spell.spellID))
	elem.label:SetText(AbbreviateNumbers(spell.totalAmount))
	elem.frame:SetAlpha(1)
	elem.frame:ClearAllPoints()
	elem.frame:SetPoint("BOTTOM", CT.anchorFrame, CT.anchorPoint, 0, elem.yPosInit)
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

-- TODO: Simplify index handling (position, offset, index?)
-- TODO: Document why we can't use C_CombatText
-- TODO: Improve animations (separate in and out, maybe add scale)
-- TODO: Fade current frames if new frames come in early (bloodlust)
-- TODO: Incoming damage
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
	end
	CT.nActive = CT.nActive + nSpell
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

		local t    = Clamp((tNow - elem.tShow - CT.cfg.fadeDelay) / CT.cfg.fadeDuration, 0, 1)
		local yPos = elem.yPosInit + t * CT.cfg.scrollDist
		elem.frame:SetPointsOffset(0, yPos)
		elem.frame:SetAlpha(1 - t)
	end
end

CT.Init()

-- NOTE: Have to clear meters because we can't compare amount with previous (totalAmount is secret)
-- NOTE: Can't ignore spells (spellID is secret)
