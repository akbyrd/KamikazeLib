local Kami = select(2, ...)
local SCT = {}
Kami.SCT = SCT

function SCT.Load()
	SCT.cfgTree = Kami.Config.Create()

	Kami.Config.AddNode(SCT.cfgTree, nil, "Default",
		{
			style = Kami.Config.String("Stack"),

			font       = Kami.Config.Texture("font", "Expressway", "Friz Quadrata TT"),
			fontSize   = Kami.Config.Number(28),
			fontFlags  = Kami.Config.String(""),
			fontShadow = Kami.Config.Bool(true),
			xOffset    = Kami.Config.Number(0),
			yOffset    = Kami.Config.Number(16),
			iconSize   = Kami.Config.Number(20),
			iconZoom   = Kami.Config.Number(0.08),
			iconAspect = Kami.Config.Number(1.65),
			iconGap    = Kami.Config.Number(4),
			lineGap    = Kami.Config.Number(0.05),

			hitColor        = Kami.Config.Color("FFFFDE00"),
			critColor       = Kami.Config.Color("FFFF8000"),
			positionalColor = Kami.Config.Color("FFFF4040"),
			lesserColor     = Kami.Config.Color("FFFFDE00"),
		})

	Kami.Config.AddNode(SCT.cfgTree, nil, "Stack",
		{
			life = Kami.Config.Number(2),
			show = Kami.Config.Raw({
				scale = SCT.Tween(1.25, 1, 0.12, EasingUtil.OutBack),
				alpha = SCT.Tween(0.5,  1, 0.12),
			}),
			hide = Kami.Config.Raw({
				y     = SCT.Tween(0, 1, 0.5, EasingUtil.InQuadratic),
				alpha = SCT.Tween(1, 0, 0.5),
			}),
			push = Kami.Config.Raw({
				y = SCT.Tween(0, 1, 0.1, EasingUtil.OutQuadratic),
			}),
		})

	Kami.Config.AddNode(SCT.cfgTree, "Stack", "StackCrit",
		{
			show = Kami.Config.Raw({
				scale = SCT.Tween(2, 1, 0.25, EasingUtil.OutBack),
			}),
		})

	Kami.Config.AddNode(SCT.cfgTree, nil, "Vertical",
		{
			life = Kami.Config.Number(1.5),
			show = Kami.Config.Raw({
				scale = SCT.Tween(1.25, 1,   0.12, EasingUtil.OutBack),
				alpha = SCT.Tween(0.5,  1,   0.12),
				y     = SCT.Tween(0,    1.5, 1.5),
			}),
			hide = Kami.Config.Raw({
				alpha = SCT.Tween(1, 0, 0.3),
			}),
			push = Kami.Config.Raw({
				y = SCT.Tween(0, 1, 0.1, EasingUtil.OutQuadratic),
			}),
		})

	Kami.Config.AddNode(SCT.cfgTree, "Vertical", "VerticalCrit",
		{
			show = Kami.Config.Raw({
				scale = SCT.Tween(2, 1, 0.25, EasingUtil.OutBack),
			}),
		})

	SCT.Suffixes   = { CRITICAL = "+", GLANCING = "-", BLOCK_REDUCED = "-" }
	SCT.Positional = { PARRY = true, BLOCK = true, BLOCK_REDUCED = true }
	SCT.Lesser     = { GLANCING = true, ABSORB = true, RESIST = true }

	SCT.live           = {}
	SCT.spare          = {}
	SCT.autoAttackIcon = nil
	SCT.iconWidth      = nil

	SCT.eventFrame = CreateFrame("Frame")
	SCT.eventFrame:Hide()
	SCT.eventFrame:SetScript("OnEvent", SCT.OnEvent)
	SCT.eventFrame:SetScript("OnUpdate", SCT.OnUpdate)
	SCT.eventFrame:RegisterEvent("PLAYER_LOGIN")
end

----------------------------------------------------------------------------------------------------
-- Tracks

function SCT.Tween(from, to, seconds, curve)
	curve = curve or SCT.Linear
	return {
		seconds = seconds,
		Value   = function(t) return Lerp(from, to, curve(Saturate(t / seconds))) end,
	}
end

function SCT.Linear(progress)
	return progress
end

----------------------------------------------------------------------------------------------------
-- Texts

function SCT.NewText()
	local text = {}
	text.Root = CreateFrame("Frame", nil, UIParent)
	text.Root:SetFrameStrata("HIGH")
	text.Root:SetSize(1, 1)
	text.Root:Hide()

	text.Label = text.Root:CreateFontString(nil, "OVERLAY")
	text.Label:SetFont(SCT.cfg.font, SCT.cfg.fontSize, SCT.cfg.fontFlags)
	if SCT.cfg.fontShadow then
		text.Label:SetShadowColor(0, 0, 0, 1)
		text.Label:SetShadowOffset(1, -1)
	end

	text.Icon = text.Root:CreateTexture(nil, "OVERLAY")
	text.Icon:SetSize(SCT.iconWidth, SCT.cfg.iconSize)
	text.Icon:SetPoint("RIGHT", text.Label, "LEFT", -SCT.cfg.iconGap, 0)
	Kami.Util.ZoomIcon(text.Icon, SCT.cfg.iconZoom, SCT.iconWidth, SCT.cfg.iconSize)

	return text
end

function SCT.Place(text, now)
	-- NOTE: We can't use animation groups for this. On a frame that follows a nameplate, a
	-- translation moves the icon but not the number, and a scale grows the icon about its own
	-- center.

	local style = text.style
	local age   = now - text.start
	local hide  = age - text.hideAt
	local scale = SCT.Value(style.show.scale, age, 1) * SCT.Value(style.hide.scale, hide, 1)
	local alpha = SCT.Value(style.show.alpha, age, 1) * SCT.Value(style.hide.alpha, hide, 1)
	local x     = SCT.Value(style.show.x, age, 0) + SCT.Value(style.hide.x, hide, 0)
	local y     = SCT.Risen(text, age) + SCT.Pushed(text, now)

	local height = SCT.cfg.fontSize
	text.Root:SetScale(scale)
	text.Root:SetAlpha(alpha)
	text.Root:SetPointsOffset((SCT.cfg.xOffset + x * height) / scale, (SCT.cfg.yOffset + y * height) / scale)
	return age < style.life
end

function SCT.Value(track, t, none)
	return track and track.Value(t) or none
end

function SCT.Length(anim)
	return math.max(SCT.Seconds(anim.scale), SCT.Seconds(anim.alpha), SCT.Seconds(anim.x), SCT.Seconds(anim.y))
end

function SCT.Seconds(track)
	return track and track.seconds or 0
end

function SCT.Risen(text, age)
	return SCT.Value(text.style.show.y, age, 0) + SCT.Value(text.style.hide.y, age - text.hideAt, 0)
end

-- Glides on from wherever the last push has got to
function SCT.PushUp(text, distance, now)
	text.pushFrom = SCT.Pushed(text, now)
	text.pushTo   = text.pushTo + distance
	text.pushAt   = now
end

function SCT.Pushed(text, now)
	local push = text.style.push
	return Lerp(text.pushFrom, text.pushTo, SCT.Value(push and push.y, now - text.pushAt, 1))
end

function SCT.Release(i)
	local text = table.remove(SCT.live, i)
	text.Root:Hide()
	table.insert(SCT.spare, text)
	SCT.eventFrame:SetShown(SCT.live[1] ~= nil)
end

function SCT.ColorOf(hit)
	if SCT.Positional[hit.action] or SCT.Positional[hit.descriptor] then return SCT.cfg.positionalColor end
	if hit.action ~= "WOUND" or SCT.Lesser[hit.descriptor] then return SCT.cfg.lesserColor end
	if hit.descriptor == "CRITICAL" then return SCT.cfg.critColor end
	return SCT.cfg.hitColor
end

function SCT.OnHit(hit)
	local text = table.remove(SCT.spare) or SCT.NewText()
	local now  = GetTime()

	if hit.action == "WOUND" then
		text.Label:SetText(AbbreviateNumbers(hit.amount) .. (SCT.Suffixes[hit.descriptor] or ""))
	else
		text.Label:SetText(CombatFeedbackText[hit.action])
	end
	text.Label:SetTextColor(SCT.ColorOf(hit):GetRGB())

	local icon = hit.spellID and C_Spell.GetSpellTexture(hit.spellID)
	if not icon and hit.swinger then
		icon = hit.swinger == "pet" and PET_ATTACK_TEXTURE or SCT.autoAttackIcon
	end
	text.Icon:SetTexture(icon)
	text.Icon:SetShown(icon ~= nil)
	text.Label:SetPoint("CENTER", icon and (SCT.iconWidth + SCT.cfg.iconGap) / 2 or 0, 0)

	if SCT.style.push then
		local below = 0
		for i = #SCT.live, 1, -1 do
			local older = SCT.live[i]
			if older.plate == hit.frame then
				local at    = older.pushTo + SCT.Risen(older, now - older.start)
				local clear = below + 1 + SCT.cfg.lineGap
				if at < clear then
					SCT.PushUp(older, clear - at, now)
				end
				below = math.max(at, clear)
			end
		end
	end
	table.insert(SCT.live, text)

	local style = hit.descriptor == "CRITICAL" and SCT.critStyle or SCT.style
	text.plate    = hit.frame
	text.style    = style
	text.start    = now
	text.hideAt   = style.life - SCT.Length(style.hide)
	text.pushFrom = 0
	text.pushTo   = 0
	text.pushAt   = now
	text.Root:SetPoint("BOTTOM", text.plate, "TOP")
	SCT.Place(text, now)
	text.Root:Show()
	SCT.eventFrame:Show()
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function SCT.OnEvent(frame, event, ...)
	SCT[event](...)
end

function SCT.OnUpdate()
	local now = GetTime()
	for i = #SCT.live, 1, -1 do
		if not SCT.Place(SCT.live[i], now) then
			SCT.Release(i)
		end
	end
end

function SCT.PLAYER_LOGIN()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Kami.Config.RefreshValues(SCT.cfgTree, pixelsToUI)

	SCT.cfg            = Kami.Config.GetBranch(SCT.cfgTree, "Default")
	SCT.style          = Kami.Config.GetBranch(SCT.cfgTree, SCT.cfg.style)
	SCT.critStyle      = Kami.Config.GetBranch(SCT.cfgTree, SCT.cfg.style .. "Crit")
	SCT.autoAttackIcon = C_Spell.GetSpellTexture(6603)

	local xScale, yScale = Kami.Util.AspectScale(SCT.cfg.iconAspect)
	SCT.iconWidth = Round(xScale / yScale * SCT.cfg.iconSize)

	-- Saved, so a session that ends without a logout can't lose the setting
	KLSavedVars.SCT = KLSavedVars.SCT or {}
	local shown = GetCVar("floatingCombatTextCombatDamage_v2")
	if shown ~= "0" then
		KLSavedVars.SCT.blizzardDamageText = shown
	end
	SetCVar("floatingCombatTextCombatDamage_v2", "0")

	SCT.eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	SCT.eventFrame:RegisterEvent("PLAYER_LOGOUT")
	Kami.DamageEvents.Init(SCT.OnHit)
end

function SCT.NAME_PLATE_UNIT_ADDED(token)
	local plate = C_NamePlate.GetNamePlateForUnit(token)
	for i = #SCT.live, 1, -1 do
		if SCT.live[i].plate == plate then
			SCT.Release(i)
		end
	end
end

function SCT.PLAYER_LOGOUT()
	local saved = KLSavedVars.SCT.blizzardDamageText
	if saved and GetCVar("floatingCombatTextCombatDamage_v2") == "0" then
		SetCVar("floatingCombatTextCombatDamage_v2", saved)
	end
end

----------------------------------------------------------------------------------------------------
-- File Load

SCT.Load()
