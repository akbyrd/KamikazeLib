local f = CreateFrame("Frame", "KL_SETTINGS_TEST", UIParent, "SettingsFrameTemplate")
f:SetSize(660, 260)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f.NineSlice.Text:SetText("Settings Test")

local units = { "px", "ui", "%" }

-- Blizzard's own templates: stepper slider, numeric box, settings checkbox, dropdown
local function CreateNativeRow(parent, y)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(600, 26)
	row:SetPoint("TOPLEFT", 24, y)
	local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", 40, 0)
	label:SetText("Native")
	local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	slider:SetPoint("LEFT", label, "RIGHT", 24, 0)
	slider:Init(0, -100, 100, 200)

	-- UX: mouse wheel steps the value
	slider.Slider:EnableMouseWheel(true)
	slider.Slider:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(self:GetValue() + delta * self:GetValueStep())
	end)

	-- UX: type a value. Enter or clicking away applies it, Escape reverts it
	local box = CreateFrame("EditBox", nil, slider, "NumericInputBoxTemplate")
	box:SetNumericFullRange(true)
	box:SetSize(50, 20)
	box:SetPoint("LEFT", slider.Slider, "RIGHT", 24, 0)
	box:SetAutoFocus(false)
	box:SetNumber(0)
	box:SetOnValueFinalizedCallback(function(value)
		slider:SetValue(Clamp(value, -100, 100))
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetNumber(Round(slider.Slider:GetValue()))
		self:ClearFocus()
	end)
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(owner, value)
		box:SetNumber(Round(value))
	end, box)

	-- UX: tooltip on the slider, in the settings panel's style
	Mixin(slider.Slider, DefaultTooltipMixin)
	slider.Slider:SetDefaultTooltipAnchors()
	slider.Slider:SetTooltipFunc(function() Settings.InitTooltip("Native", "Size of each icon") end)
	slider.Slider:HookScript("OnEnter", slider.Slider.OnEnter)
	slider.Slider:HookScript("OnLeave", slider.Slider.OnLeave)

	-- UX: unit picker next to the value
	local unit = "ui"
	local function IsUnitSelected(data) return unit == data end
	local function SetUnitSelected(data) unit = data end
	local picker = CreateFrame("DropdownButton", nil, slider, "WowStyle1DropdownTemplate")
	picker:SetSize(60, 25)
	picker:SetPoint("LEFT", box, "RIGHT", 4, 0)
	picker:SetupMenu(function(dropdown, rootDescription)
		rootDescription:CreateRadio("px", IsUnitSelected, SetUnitSelected, "px")
		rootDescription:CreateRadio("ui", IsUnitSelected, SetUnitSelected, "ui")
		rootDescription:CreateRadio("%",  IsUnitSelected, SetUnitSelected, "%")
	end)

	-- UX: checkbox enables or greys the whole row
	local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
	checkbox:SetPoint("LEFT", 4, 0)
	checkbox:Init(true)
	checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(owner, checked)
		slider:SetEnabled(checked)
		box:SetEnabled(checked)
		picker:SetEnabled(checked)
	end, row)
end

-- Sourcery's style: one flat 26 px row, hover lights it, class color accents, - and + buttons
local function CreateSourceryRow(parent, y)
	local accent = C_ClassColor.GetClassColor(select(2, UnitClass("player")))
	local backdrop = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

	local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	row:SetSize(600, 26)
	row:SetPoint("TOPLEFT", 24, y)
	row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
	row:SetBackdropColor(0, 0, 0, 0)
	local focus = row:CreateTexture(nil, "OVERLAY")
	focus:SetWidth(2)
	focus:SetPoint("TOPLEFT")
	focus:SetPoint("BOTTOMLEFT")
	focus:SetColorTexture(accent:GetRGB())
	focus:Hide()

	local checkbox = CreateFrame("Button", nil, row, "BackdropTemplate")
	checkbox:SetSize(18, 18)
	checkbox:SetPoint("LEFT", 4, 0)
	checkbox:SetBackdrop(backdrop)
	checkbox:SetBackdropColor(0, 0, 0, 0.45)
	checkbox:SetBackdropBorderColor(1, 1, 1, 0.06)
	local check = checkbox:CreateTexture(nil, "OVERLAY")
	check:SetSize(11, 11)
	check:SetPoint("CENTER")
	check:SetColorTexture(accent:GetRGB())

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
	label:SetText("Sourcery")
	label:SetTextColor(1, 1, 1, 0.65)

	-- UX: the whole row is the hover target and the tooltip owner. Children forward their hover to it
	local function SetHover(on)
		row:SetBackdropColor(1, 1, 1, on and 0.03 or 0)
		label:SetTextColor(1, 1, 1, on and 0.95 or 0.65)
		focus:SetShown(on)
		if on then
			GameTooltip:SetOwner(row, "ANCHOR_TOPLEFT")
			GameTooltip:SetText("Size of each icon")
		else
			GameTooltip:Hide()
		end
	end
	row:SetScript("OnEnter", function() SetHover(true) end)
	row:SetScript("OnLeave", function() SetHover(false) end)
	checkbox:SetScript("OnEnter", function() SetHover(true) end)
	checkbox:SetScript("OnLeave", function() SetHover(false) end)

	-- UX: - and + buttons flank the track, the value box and unit sit at the right
	local control = CreateFrame("Frame", nil, row)
	control:SetSize(288, 18)
	control:SetPoint("RIGHT", -4, 0)
	local function CreateFlatButton(text, width)
		local button = CreateFrame("Button", nil, control, "BackdropTemplate")
		button:SetSize(width, 18)
		button:SetBackdrop(backdrop)
		button:SetBackdropColor(1, 1, 1, 0.03)
		button:SetBackdropBorderColor(1, 1, 1, 0.06)
		button:SetNormalFontObject("GameFontNormalSmall")
		button:SetText(text)
		button:GetFontString():SetTextColor(1, 1, 1, 0.65)
		button:SetScript("OnEnter", function(self)
			self:SetBackdropColor(1, 1, 1, 0.08)
			SetHover(true)
		end)
		button:SetScript("OnLeave", function(self)
			self:SetBackdropColor(1, 1, 1, 0.03)
			SetHover(false)
		end)
		return button
	end
	local minus  = CreateFlatButton("-", 18)
	local plus   = CreateFlatButton("+", 18)
	local picker = CreateFlatButton("ui", 30)
	local box = CreateFrame("EditBox", nil, control, "BackdropTemplate")
	box:SetSize(50, 18)
	box:SetBackdrop(backdrop)
	box:SetBackdropColor(0, 0, 0, 0.45)
	box:SetBackdropBorderColor(1, 1, 1, 0.06)
	box:SetFontObject("GameFontHighlightSmall")
	box:SetTextColor(accent:GetRGB())
	box:SetJustifyH("CENTER")
	box:SetAutoFocus(false)
	box:SetScript("OnEnter", function() SetHover(true) end)
	box:SetScript("OnLeave", function() SetHover(false) end)
	minus:SetPoint("LEFT")
	picker:SetPoint("RIGHT")
	box:SetPoint("RIGHT", picker, "LEFT", -4, 0)
	plus:SetPoint("RIGHT", box, "LEFT", -4, 0)

	local slider = CreateFrame("Slider", nil, control, "BackdropTemplate")
	slider:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	slider:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	slider:SetHeight(11)
	slider:SetOrientation("HORIZONTAL")
	slider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
	slider:SetBackdropColor(1, 1, 1, 0.03)
	local thumb = slider:CreateTexture(nil, "ARTWORK")
	thumb:SetSize(4, 11)
	thumb:SetColorTexture(accent:GetRGB())
	slider:SetThumbTexture(thumb)
	slider:SetMinMaxValues(-100, 100)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider:SetValue(0)
	slider:SetScript("OnValueChanged", function(self, value)
		box:SetText(Round(value))
	end)
	slider:SetScript("OnEnter", function() SetHover(true) end)
	slider:SetScript("OnLeave", function() SetHover(false) end)
	minus:SetScript("OnClick", function() slider:SetValue(slider:GetValue() - 1) end)
	plus:SetScript("OnClick", function() slider:SetValue(slider:GetValue() + 1) end)

	-- UX: mouse wheel steps the value
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(self:GetValue() + delta)
	end)

	-- UX: type a value. Enter or clicking away applies it, Escape reverts it
	local function ApplyBox(self)
		local value = tonumber(self:GetText())
		if value then
			slider:SetValue(Clamp(value, -100, 100))
		end
		self:SetText(Round(slider:GetValue()))
		self:ClearFocus()
	end
	box:SetScript("OnEnterPressed", ApplyBox)
	box:SetScript("OnEditFocusLost", ApplyBox)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(Round(slider:GetValue()))
		self:ClearFocus()
	end)

	-- UX: unit picker cycles on click
	local unit = "ui"
	picker:SetScript("OnClick", function(self)
		local index = tIndexOf(units, unit)
		unit = units[index % #units + 1]
		self:SetText(unit)
	end)

	-- UX: checkbox enables or greys the whole row
	local enabled = true
	checkbox:SetScript("OnClick", function()
		enabled = not enabled
		check:SetShown(enabled)
		control:SetAlpha(enabled and 1 or 0.35)
		slider:EnableMouse(enabled)
		box:SetEnabled(enabled)
		minus:EnableMouse(enabled)
		plus:EnableMouse(enabled)
		picker:EnableMouse(enabled)
	end)
end

-- DandersFrames' style: label above a thin track with a colored fill, value box at the right
local function CreateDandersRow(parent, y)
	local accent  = CreateColor(0.45, 0.45, 0.95)
	local grey    = CreateColor(0.4, 0.4, 0.4)
	local element = CreateColor(0.18, 0.18, 0.18)
	local border  = CreateColor(0.25, 0.25, 0.25)
	local backdrop = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
	local function CreateElementBackdrop(frame)
		frame:SetBackdrop(backdrop)
		frame:SetBackdropColor(element:GetRGB())
		frame:SetBackdropBorderColor(border:GetRGB())
	end

	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(600, 46)
	container:SetPoint("TOPLEFT", 24, y)

	local checkbox = CreateFrame("CheckButton", nil, container, "BackdropTemplate")
	checkbox:SetSize(18, 18)
	checkbox:SetPoint("TOPLEFT")
	CreateElementBackdrop(checkbox)
	local check = checkbox:CreateTexture(nil, "OVERLAY")
	check:SetSize(10, 10)
	check:SetPoint("CENTER")
	check:SetColorTexture(accent:GetRGB())
	checkbox:SetCheckedTexture(check)
	checkbox:SetChecked(true)

	local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
	label:SetText("Danders")
	label:SetTextColor(0.9, 0.9, 0.9)

	-- UX: tooltip on the label only, never over the track
	local hit = CreateFrame("Frame", nil, container)
	hit:SetAllPoints(label)
	hit:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Size of each icon")
	end)
	hit:SetScript("OnLeave", GameTooltip_Hide)

	-- UX: the value box and unit sit at the right, the track stretches to meet them
	local picker = CreateFrame("Button", nil, container, "BackdropTemplate")
	picker:SetSize(30, 20)
	picker:SetPoint("TOPRIGHT", 0, -22)
	CreateElementBackdrop(picker)
	picker:SetNormalFontObject("GameFontHighlightSmall")
	picker:SetText("ui")
	local box = CreateFrame("EditBox", nil, container, "BackdropTemplate")
	box:SetSize(50, 20)
	box:SetPoint("RIGHT", picker, "LEFT", -4, 0)
	CreateElementBackdrop(box)
	box:SetFontObject("GameFontHighlightSmall")
	box:SetJustifyH("CENTER")
	box:SetAutoFocus(false)

	local track = CreateFrame("Frame", nil, container, "BackdropTemplate")
	track:SetPoint("TOPLEFT", 0, -28)
	track:SetPoint("RIGHT", box, "LEFT", -8, 0)
	track:SetHeight(8)
	CreateElementBackdrop(track)
	local fill = track:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("LEFT", 1, 0)
	fill:SetHeight(6)
	fill:SetColorTexture(accent.r, accent.g, accent.b, 0.8)

	local slider = CreateFrame("Slider", nil, container)
	slider:SetAllPoints(track)
	slider:SetOrientation("HORIZONTAL")
	slider:SetHitRectInsets(-4, -4, -8, -8)
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(12, 16)
	thumb:SetColorTexture(accent:GetRGB())
	slider:SetThumbTexture(thumb)
	slider:SetMinMaxValues(-100, 100)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	local function UpdateFill()
		local fraction = (slider:GetValue() + 100) / 200
		fill:SetWidth(math.max(1, fraction * (track:GetWidth() - 2)))
	end
	slider:SetScript("OnValueChanged", function(self, value)
		UpdateFill()
		box:SetText(Round(value))
	end)
	track:SetScript("OnSizeChanged", UpdateFill)
	slider:SetValue(0)

	-- UX: mouse wheel steps the value
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(self:GetValue() + delta)
	end)

	-- UX: type a value. Enter or clicking away applies it, Escape reverts it
	local function ApplyBox(self)
		local value = tonumber(self:GetText())
		if value then
			slider:SetValue(Clamp(value, -100, 100))
		end
		self:SetText(Round(slider:GetValue()))
		self:ClearFocus()
	end
	box:SetScript("OnEnterPressed", ApplyBox)
	box:SetScript("OnEditFocusLost", ApplyBox)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(Round(slider:GetValue()))
		self:ClearFocus()
	end)

	-- UX: unit picker cycles on click
	local unit = "ui"
	picker:SetScript("OnClick", function(self)
		local index = tIndexOf(units, unit)
		unit = units[index % #units + 1]
		self:SetText(unit)
	end)

	-- UX: checkbox enables or greys the whole row
	checkbox:SetScript("OnClick", function(self)
		local enabled = self:GetChecked()
		local color = enabled and accent or grey
		local text  = enabled and 0.9 or 0.6
		slider:SetEnabled(enabled)
		box:SetEnabled(enabled)
		box:SetAlpha(enabled and 1 or 0.4)
		picker:SetEnabled(enabled)
		label:SetTextColor(text, text, text)
		thumb:SetColorTexture(color:GetRGB())
		fill:SetColorTexture(color.r, color.g, color.b, 0.8)
	end)
end

CreateNativeRow(f, -40)
CreateSourceryRow(f, -90)
CreateDandersRow(f, -140)
