local Kami = select(2, ...)
local CDM = {}
Kami.CDM2 = CDM

local LCG = LibStub("LibCustomGlow-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

function CDM.Load()
	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame", "KL_CDM2_EVENT")
	CDM.eventFrame:SetScript("OnEvent", CDM.DispatchEvent)

	--CDM.RegisterEvent("SPELL_UPDATE_COOLDOWN", CDM.SPELL_UPDATE_COOLDOWN)
	local dataProvider = CooldownViewerSettings:GetDataProvider()
	hooksecurefunc(dataProvider, "Init", CDM.PrintPlayerData2)

	--CDM.PrintStaticData()
end

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

function CDM.PrintStaticData()
	-- NOTE: Only mostly static. It changes with equipment, talents, and overrides
	-- TODO: CooldownViewerSettingsDataProvider_GetCategories?
	for name, category in pairs(Enum.CooldownViewerCategory) do
		-- HiddenActive  = -1
		-- HiddenPassive = -2
		if category >= 0 then
			local includeUnlearned = true
			local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, includeUnlearned)
			print(" ")
			print(string.format("Category %s (%s) (%d)", name, category, #cooldownIDs))

			for _, cooldownID in ipairs(cooldownIDs) do
				local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) -- CooldownViewerCooldown
				if info then
					local s = string.format("cooldownID: %s, sId: %s (%s), oID: %s, category: %s, equip: %s, buff: %s, known: %s, invis: %s, aura: %s, self: %s, charges: %s, flags: %s, linked: { ",
						tostring(cooldownID),
						tostring(info.spellID), tostring(info.spellID and C_Spell.GetSpellName(info.spellID)),
						tostring(info.overrideSpellID),
						tostring(info.spellCategoryID),
						tostring(info.equipSlot),
						tostring(info.buffSlot),
						tostring(info.isKnown),
						tostring(info.isInvisible),
						tostring(info.hasAura),
						tostring(info.selfAura),
						tostring(info.charges),
						tostring(info.flags))

						for _, linkedSpellID in ipairs(info.linkedSpellIDs) do
							s = s .. string.format("%d %s, ", linkedSpellID, tostring(C_Spell.GetSpellName(linkedSpellID)))
						end
						s = s .. "}"
					print(s)
				end
			end
		end
	end
end

function CDM.PrintPlayerData()
	-- NOTE: GetOrderedCooldownIDsForCategory has an internal lazy resolve. Calling it results in
	-- taint and blows up later. We can force an update without tainting by toggling the settings
	-- panel. We could also manually deserialized the saved data, but that seems like a headache when
	-- we can force the game to do it for us. Handling CooldownViewerSettings.OnDataChanged is also
	-- an option.

	if InCombatLockdown() then return end

	if not CooldownViewerSettings:IsVisible() then
		ShowUIPanel(CooldownViewerSettings)
		HideUIPanel(CooldownViewerSettings)
	end

	local dataProvider = CooldownViewerSettings:GetDataProvider()
	if dataProvider:IsDirty() then print("CDM is dirty") return end

	for name, category in pairs(Enum.CooldownViewerCategory) do
		if category >= 0 then
			local allowUnknown = true
			local cooldownIDs = dataProvider:GetOrderedCooldownIDsForCategory(category, allowUnknown)
			print(" ")
			print(string.format("Category %s (%s) (%d)", name, category, #cooldownIDs))

			for _, cooldownID in ipairs(cooldownIDs) do
				local info = dataProvider:GetCooldownInfoForID(cooldownID)
				if info then
					local s = string.format("cooldownID: %s, sId: %s (%s), oID: %s, category: %s, equip: %s",
						tostring(cooldownID),
						tostring(info.spellID), tostring(info.spellID and C_Spell.GetSpellName(info.spellID)),
						tostring(info.overrideSpellID),
						tostring(info.spellCategoryID),
						tostring(info.equipSlot))
					print(s)
				end
			end
		end
	end
end

function CDM.PrintPlayerData2()
	-- NOTE: Alternative to the panel toggle. The build it forces just merges static cooldown data
	-- with the active layout's saved overrides, and both halves are plain table reads we can do
	-- ourselves. Reads don't taint, so no panel, no sounds, no combat gate, no save-on-close.

	-- Don't use dataProvider:GetLayoutManager(). It also has a lazy resolve and will taint.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	local layout    = layoutMgr:GetActiveLayout(Enum.CDMLayoutMode.AccessOnly)
	if not layout then print("No active layout, defaults in use") return end

	local currentTag = CooldownViewerUtil.GetCurrentClassAndSpecTag()

	print(string.format("Layout id: %s, name: %s, spec: %s (current: %s), default: %s",
		tostring(CooldownManagerLayout_GetID(layout)),
		tostring(CooldownManagerLayout_GetName(layout)),
		tostring(CooldownManagerLayout_GetClassAndSpecTag(layout)),
		tostring(currentTag),
		tostring(CooldownManagerLayout_IsDefaultLayout(layout))))

	-- All spells/items available in the CDM, default order
	local orderedCooldownIDs = CooldownManagerLayout_GetOrderedCooldownIDs(layout)
	if orderedCooldownIDs then
		print(" ")
		print(string.format("Saved order (%d):", #orderedCooldownIDs))
		for orderIndex, cooldownID in ipairs(orderedCooldownIDs) do
			local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) -- CooldownViewerCooldown
			if info then
				print(string.format("%2d: cooldownID: %7s, sId: %7s (%-24s)",
					orderIndex,
					tostring(cooldownID),
					tostring(info.spellID),
					tostring(info.spellID and C_Spell.GetSpellName(info.spellID))))
			end
		end
	end

	-- User configured spells/items, deviations from the default
	local cooldownInfo = CooldownManagerLayout_GetCooldownInfo(layout, false)
	if cooldownInfo then
		print(" ")
		print("Cooldown overrides:")
		for cooldownID, block in pairs(cooldownInfo) do
			local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) -- CooldownViewerCooldown
			if info then
				print(string.format("cooldownID: %7s, sId: %7s (%-24s), category: %2s",
					tostring(cooldownID),
					tostring(info.spellID),
					tostring(info.spellID and C_Spell.GetSpellName(info.spellID)),
					tostring(block.category)))
			end
		end
	end
end

CDM.Load()
