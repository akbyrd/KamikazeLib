local Kami = select(2, ...)
local CDM = {}
Kami.CDM = Kami.CDM or {}
Kami.CDM.Buffs = CDM

function CDM.Load()
	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame")
	CDM.eventFrame:SetParentKey("Kami.CDM.Buffs.Event")
	CDM.eventFrame:SetScript("OnEvent", CDM.DispatchEvent)

	local categories = {
		Enum.CooldownViewerCategory.TrackedBar,
	}

	CDM.viewers = {}
	for index, category in ipairs(categories) do
	end

	CDM.Rebuild()
end

function CDM.Rebuild()
	CDM.GatherCDs()
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

----------------------------------------------------------------------------------------------------
-- File Load

CDM.Load()
