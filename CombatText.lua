local Kami = select(2, ...)
local CT = {}
Kami.CT = CT

function CT.Init()
	CT.frame       = nil
	CT.anchorFrame = nil
	CT.playerGUID  = UnitGUID("player")
	CT.lastSource  = nil
	CT.elements    = {}
	CT.oTail       = 0
	CT.nActive     = 0
	CT.duration    = nil
	CT.cfg         = {
		iconSize      = 24,
		iconZoom      = .08,
		iconAspect    = 1.3,
		font          = nil,
		fontDesired   = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Homespun.ttf",
		fontFallback  = "GameFontNormal",
		fontSize      = 24,
		showDuration  = 0.15,
		hideDuration  = 0.35,
		totalDuration = 1.5,
		scrollDist    = 30,
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
	CT.duration = max(CT.cfg.totalDuration, CT.cfg.showDuration + CT.cfg.hideDuration)

	local tempLabel = CT.frame:CreateFontString(nil, "BACKGROUND", nil)
	local success = tempLabel:SetFont(CT.cfg.fontDesired, 12)
	CT.cfg.font = success and CT.cfg.fontDesired or CT.cfg.fontFallback
end

function CT.OnCommand(args)
	local values = {
		["1"]       = true,
		["true"]    = true,
		["enable"]  = true,

		["0"]       = false,
		["false"]   = false,
		["disable"] = false,
	}

	local enabled = values[args[2]]
	if enabled ~= nil then
		CT.SetEnabled(enabled)
	end
end

function CT.SetEnabled(enabled)
	if enabled then
		CT.frame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
		SetCVar("floatingCombatTextCombatDamage_v2", 0)
	else
		CT.frame:UnregisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
		SetCVar("floatingCombatTextCombatDamage_v2", 1)
	end
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
	local icon    = frame:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(CT.cfg.iconSize * xFactor, CT.cfg.iconSize * yFactor)
	icon:SetTexCoord(texXMin, 1 - texXMin, texYMin, 1 - texYMin)
	icon:SetPoint("RIGHT", label, "LEFT", -6, -.0625 * CT.cfg.fontSize)

	local elem = {
		frame    = frame,
		icon     = icon,
		label    = label,
		yPosInit = nil,
		tShow    = nil,
		tHide    = nil,
	}
	return elem
end

function CT.ShowElement(elem, offset, spell)
	elem.yPosInit = CT.anchorOffset + offset * (CT.cfg.iconSize + 2)
	elem.tShow    = GetTime()
	elem.tHide    = elem.tShow + CT.duration
	elem.icon:SetTexture(C_Spell.GetSpellTexture(spell.spellID))
	elem.label:SetText(AbbreviateNumbers(spell.totalAmount))
	elem.frame:SetPoint("BOTTOM", CT.anchorFrame, CT.anchorPoint, 0, elem.yPosInit)
	elem.frame:Show()
end

function CT.HideElement(elem)
	elem.yPosInit = nil
	elem.tShow    = nil
	elem.icon:SetTexture("Interface\\Icons\\Inv_misc_questionmark")
	elem.label:SetText("Inactive")
	elem.frame:SetAlpha(1)
	elem.frame:SetScale(1)
	elem.frame:ClearAllPoints()
	elem.frame:Hide()
end

function CT.EaseOutBack(t)
	local c1 = 5
	local c3 = c1 + 1
	return 1 + c3*(t - 1)^3 + c1*(t - 1)^2
end

-- TODO: Document why we can't use C_CombatText
-- TODO: Incoming damage
-- TODO: Sort by spellId (if built-in function exists)

function CT.DisplaySource(source)
	local nSpell = #source.combatSpells
	local nElem  = #CT.elements
	local tNow   = GetTime()

	-- Fade active elements
	for i = 0, CT.nActive - 1 do
		local oElem = (CT.oTail + i) % nElem
		local elem  = CT.elements[oElem + 1]

		elem.tHide = min(elem.tHide, tNow + CT.cfg.hideDuration)
		elem.tShow = elem.tHide - CT.duration
	end

	-- Create new elements
	while nElem < CT.nActive + nSpell do
		local elem  = CT.CreateElement()
		table.insert(CT.elements, CT.oTail + 1, elem)
		CT.oTail = min(CT.oTail + 1, nElem)
		nElem = nElem + 1
	end

	-- Show new active elements
	for oSpell = 0, nSpell - 1 do
		local spell = source.combatSpells[oSpell + 1]

		local oElem = (CT.oTail + CT.nActive + oSpell) % nElem
		local elem  = CT.elements[oElem + 1]
		CT.ShowElement(elem, oSpell, spell)
	end
	CT.nActive = CT.nActive + nSpell
end

function CT.OnUpdate(frame, elapsed)
	local nElem = #CT.elements
	local tNow  = GetTime()

	-- Hide inactive elements
	for i = 0, CT.nActive - 1 do
		local elem = CT.elements[CT.oTail + 1]

		if tNow >= elem.tHide then
			CT.oTail   = (CT.oTail + 1) % nElem
			CT.nActive = CT.nActive - 1
			CT.HideElement(elem)
		else
			break
		end
	end

	-- Animate active elements
	for i = 0, CT.nActive - 1 do
		local oElem = (CT.oTail + i) % nElem
		local elem  = CT.elements[oElem + 1]

		local elapsed = tNow - elem.tShow
		local showOffset = 0
		local hideOffset = CT.duration - CT.cfg.hideDuration
		local tIn        = Clamp((elapsed - showOffset) / CT.cfg.showDuration, 0, 1)
		local tOut       = Clamp((elapsed - hideOffset) / CT.cfg.hideDuration, 0, 1)

		local yPos = elem.yPosInit + tOut * CT.cfg.scrollDist
		elem.frame:SetPointsOffset(0, yPos)
		elem.frame:SetAlpha(tIn * (1 - tOut))
		elem.frame:SetScale(Lerp(.5, 1, CT.EaseOutBack(tIn)))
	end
end

--CT.Init()

-- NOTE: Have to clear meters because we can't compare amount with previous (totalAmount is secret)
-- NOTE: Can't ignore spells (spellID is secret)
