local Kami = select(2, ...)
local CDM = {}
Kami.CDM2 = CDM

local LCG = LibStub("LibCustomGlow-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

function CDM.Load()
	CDM.cfg = {
		default = {
			xPos = 0,
			yPos = 0,

			iconSize   = 50,
			iconZoom   = 0.08,
			iconAspect = 1.65,
			iconPad    = 1,
			iconLimit  = 5,

			borderColor = "000000FF",
			borderSize  = 2,

			cdShow = true,
		},

		[Enum.CooldownViewerCategory.Essential] = {
			yPos = -288,
		},

		[Enum.CooldownViewerCategory.Utility] = {
			yPos = -344,
			iconSize = 30,
		},
	}

	setmetatable(CDM.cfg[Enum.CooldownViewerCategory.Essential], { __index = CDM.cfg.default })
	setmetatable(CDM.cfg[Enum.CooldownViewerCategory.Utility],   { __index = CDM.cfg.default })

	CDM.handlers = {}
	CDM.eventFrame = CreateFrame("Frame", "KL_CDM2_EVENT")
	CDM.eventFrame:SetScript("OnEvent", CDM.DispatchEvent)

	local viewers = {
		Enum.CooldownViewerCategory.Essential,
		Enum.CooldownViewerCategory.Utility,
	}
	local categoryToName = EnumUtil.GenerateNameTranslation(Enum.CooldownViewerCategory)

	CDM.viewers = {}
	for index, category in ipairs(viewers) do
		local name = categoryToName(category)
		local rootName = string.format("Kami.CDM2.%s", name)

		local Root = CreateFrame("Frame", rootName, UIParent)

		--local Background = Root:CreateTexture(nil, "BACKGROUND")
		--Background:SetAllPoints()
		--Background:SetColorTexture(1, 0, 0, 0.5)

		local vState = {
			name     = name,
			cfg      = CDM.cfg[category],
			pool     = {},
			cdInfos  = {},
			cdFrames = {},
			Root     = Root,
			xSize    = nil,
			ySize    = nil,
		}
		CDM.viewers[category] = vState
	end

	local units = CreateFromMixins(SecondsFormatterMixin)
	units:SetStripIntervalWhitespace(true)

	local mFmt  = units:GetFormatString(SecondsFormatter.Interval.Minutes, SecondsFormatter.Abbreviation.OneLetter, true)
	local hFmt  = units:GetFormatString(SecondsFormatter.Interval.Hours,   SecondsFormatter.Abbreviation.OneLetter, true)
	local dFmt  = units:GetFormatString(SecondsFormatter.Interval.Days,    SecondsFormatter.Abbreviation.OneLetter, true)
	local round = Enum.NumericRuleFormatRounding.Up

	CDM.cdFormatter = C_StringUtil.CreateNumericRuleFormatter()
	CDM.cdFormatter:SetBreakpoints({
		{ threshold = 0,                     format = "%d",                      components = {{ div = 1,                step = 1,   rounding = round }} },
		{ threshold = 99,                    format = mFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_MIN,  step = 0.1, rounding = round }} },
		{ threshold = 2  * SECONDS_PER_MIN,  format = mFmt,                      components = {{ div = SECONDS_PER_MIN,  step = 1,   rounding = round }} },
		{ threshold = 99 * SECONDS_PER_MIN,  format = hFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_HOUR, step = 0.1, rounding = round }} },
		{ threshold = 2  * SECONDS_PER_HOUR, format = hFmt,                      components = {{ div = SECONDS_PER_HOUR, step = 1,   rounding = round }} },
		{ threshold = 1  * SECONDS_PER_DAY,  format = dFmt:gsub("%%d", "%%.1f"), components = {{ div = SECONDS_PER_DAY,  step = 0.1, rounding = round }} },
		{ threshold = 2  * SECONDS_PER_DAY,  format = dFmt,                      components = {{ div = SECONDS_PER_DAY,  step = 1,   rounding = round }} },
	})

	-- TODO: Should we throttle this?
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	hooksecurefunc(layoutMgr, "NotifyListeners", CDM.Rebuild)

	-- CD fonts
	local cdTypeface = LSM:Fetch("font", "PT Sans Narrow")
	for category, vState in pairs(CDM.viewers) do
		vState.cdFontName = string.format("Kami.CDM2.Font.%s", vState.name)
		vState.cdFont = CreateFont(vState.cdFontName)
		vState.cdFont:SetFont(cdTypeface, 18, "OUTLINE")
	end
end

function CDM.RegisterEvent(event, func)
	CDM.eventFrame:RegisterEvent(event)
	CDM.handlers[event] = func
end

function CDM.DispatchEvent(frame, event, ...)
	local func = CDM.handlers[event]
	func(...)
end

function CDM.Rebuild()
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	if layoutMgr:AreNotificationsLocked() then return end

	print("Kami CDM Rebuild")
	CDM.GatherCDs()
	CDM.AssignFrames()
	CDM.RefreshSizes()
	CDM.RefreshPositions()
end

function CDM.GatherCDs()
	for category, vState in pairs(CDM.viewers) do
		wipe(vState.cdInfos)
	end

	local categoryOverrides = {} -- cooldownID -> user category, deviations from the default
	local positionOverrides = {} -- cooldownID -> boolean,       deviations from the default

	local function AddCD(cooldownID)
		local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) -- CooldownViewerCooldown
		if cdInfo and cdInfo.isKnown then
			local hidden   = FlagsUtil.IsSet(cdInfo.flags, Enum.CooldownSetSpellFlags.HideByDefault)
			local category = categoryOverrides[cooldownID] or (hidden and -1 or cdInfo.category)

			local vState = CDM.viewers[category]
			if vState then
				table.insert(vState.cdInfos, cdInfo)
			end
		end
	end

	-- Don't use dataProvider:GetLayoutManager(). It has a lazy resolve and will taint.
	local layoutMgr = CooldownViewerSettings:GetLayoutManager()
	local layout    = layoutMgr:GetActiveLayout(Enum.CDMLayoutMode.AccessOnly)
	if layout then

		-- User category overrides
		local layoutInfo = CooldownManagerLayout_GetCooldownInfo(layout, false)
		if layoutInfo then -- nil when no user overrides
			for cooldownID, block in pairs(layoutInfo) do
				-- Apparently block.category can be a string sometimes?
				categoryOverrides[cooldownID] = tonumber(block.category)
			end
		end

		-- User position overrides
		local orderedCooldownIDs = CooldownManagerLayout_GetOrderedCooldownIDs(layout)
		if orderedCooldownIDs then -- nil when no user overrides
			for iCooldown, cooldownID in ipairs(orderedCooldownIDs) do
				positionOverrides[cooldownID] = true
				AddCD(cooldownID)
			end
		end
	end

	-- All spells/items, default ordering
	for iCategory, category in ipairs(CooldownViewerSettingsDataProvider_GetCategories()) do
		local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
		for iCooldown, cooldownID in ipairs(cooldownIDs) do
			if not positionOverrides[cooldownID] then
				AddCD(cooldownID)
			end
		end
	end
end

function CDM.ConstructFrame(vState)
	local Frame = CreateFrame("Frame", nil, vState.Root)
	Frame:Hide()

	local Icon = Frame:CreateTexture(nil, "ARTWORK")
	Icon:SetAllPoints()

	local Border = Frame:CreateTexture(nil, "OVERLAY")
	Border:SetAllPoints()
	Border:SetTexture("Interface\\AddOns\\KamikazeLib\\Media\\Border.tga", "CLAMP", "CLAMP", "NEAREST")
	Border:SetTextureSliceMargins(1, 1, 1, 1)

	local Cooldown = CreateFrame("Cooldown", nil, Frame, "CooldownFrameTemplate")
	Cooldown:SetAllPoints()
	Cooldown:SetDrawEdge(false)
	Cooldown:SetSwipeColor(0, 0, 0, 0.6)
	Cooldown:SetDrawBling(false)
	Cooldown:SetCountdownFormatter(CDM.cdFormatter)
	Cooldown:SetCountdownFont(vState.cdFontName)

	local fState = {
		Frame    = Frame,
		Icon     = Icon,
		Border   = Border,
		Cooldown = Cooldown,
	}
	return fState
end

function CDM.EnableFrame(fState, vState, cdInfo)
	local texture
	if cdInfo.spellID then
		texture = C_Spell.GetSpellTexture(cdInfo.spellID)
	else
		texture = GetInventoryItemTexture("player", cdInfo.equipSlot)
	end

	local bColor = CreateColorFromRGBAHexString(vState.cfg.borderColor)

	fState.cdInfo = cdInfo
	fState.Frame:Show()
	fState.Icon:SetTexture(texture)
	fState.Border:SetVertexColor(bColor:GetRGBA())
	fState.Cooldown:SetHideCountdownNumbers(not vState.cfg.cdShow)
end

function CDM.DisableFrame(fState)
	fState.cdInfo = nil
	fState.Frame:ClearAllPoints()
	fState.Frame:Hide()
end

function CDM.AssignFrames()
	for category, vState in pairs(CDM.viewers) do
		-- Disable existing frames
		for iFrame, fState in ipairs(vState.cdFrames) do
			CDM.DisableFrame(fState)
			table.insert(vState.pool, fState)
		end
		wipe(vState.cdFrames)

		-- Construct new frames (if needed)
		local have = #vState.pool
		local need = #vState.cdInfos
		for iNeed = have + 1, need do
			local fState = CDM.ConstructFrame(vState)
			table.insert(vState.pool, fState)
		end

		-- Enable new frames
		for iInfo, cdInfo in ipairs(vState.cdInfos) do
			local fState = table.remove(vState.pool)
			CDM.EnableFrame(fState, vState, cdInfo)
			table.insert(vState.cdFrames, fState)
		end
	end
end

function CDM.RefreshSizes()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / vState.Root:GetEffectiveScale()

		for iFrame, fState in ipairs(vState.cdFrames) do
			Kami.Util.RectIcon(fState.Frame, fState.Icon, vState.cfg.iconSize, vState.cfg.iconZoom, vState.cfg.iconAspect)
			Kami.Util.RoundSize(fState.Frame, pixelsToUI)

			vState.xSize = fState.Frame:GetWidth()  / pixelsToUI
			vState.ySize = fState.Frame:GetHeight() / pixelsToUI
		end
	end
end

function CDM.RefreshPositions()
	for category, vState in pairs(CDM.viewers) do
		local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / vState.Root:GetEffectiveScale()

		local xSize = vState.xSize
		local ySize = vState.ySize
		local pad   = vState.cfg.iconPad
		local limit = vState.cfg.iconLimit

		local mxPos = 0
		local myPos = 0

		for iFrame, fState in ipairs(vState.cdFrames) do
			local iCol = (iFrame - 1) % limit
			local iRow = floor((iFrame - 1) / limit)

			local nRow    = min(limit, #vState.cdFrames - (iRow * limit))
			local nMax    = min(limit, #vState.cdFrames)
			local rxSize  = nRow * (xSize + pad) - pad
			local lxSize  = nMax * (xSize + pad) - pad
			local xCenter = Round((lxSize - rxSize) / 2)

			local xPos = 0 + iCol * (xSize + pad) + xCenter
			local yPos = 0 - iRow * (ySize + pad)
			fState.Frame:SetPoint("TOPLEFT", vState.Root, "TOPLEFT", xPos * pixelsToUI, yPos * pixelsToUI)

			mxPos = math.max(mxPos, xPos + xSize)
			myPos = math.min(myPos, yPos - ySize)
		end

		local vxPos = Round(vState.cfg.xPos / pixelsToUI - mxPos / 2)
		local vyPos = Round(vState.cfg.yPos / pixelsToUI - myPos / 2)
		vState.Root:SetPoint("TOPLEFT", UIParent, "CENTER", vxPos * pixelsToUI, vyPos * pixelsToUI)
		vState.Root:SetSize(mxPos * pixelsToUI, -myPos * pixelsToUI)
	end
end

CDM.Load()
