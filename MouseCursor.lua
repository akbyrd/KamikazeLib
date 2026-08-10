-- TODO: This needs to be completely rewritten for the new settings API

-- TODO: Make a color swatch button for color
-- TODO: Mouse position is wrong after reloading UI
-- TODO: Implement an unpack function

-- TODO: Scroll view
-- TODO: Slider value/edit box
-- TODO: Better color picker
-- TODO: Try to refactor to make it easier to follow and harder to make mistakes
-- TODO: Add a circle option
-- TODO: Lazily create config options when opened

local Kami = select(2, ...)
local MC = {}
Kami.MC = MC

function MC.Load()
	MC.frame = CreateFrame("FRAME", "KL_MOUSE_CURSOR", UIParent)
	MC.frame:RegisterEvent("VARIABLES_LOADED")
	MC.frame:SetScript("OnEvent", MC.OnEvent)
end

function MC.Initialize()
	MC.defaultConfig = {
		enabled           = true,
		thickness         = 3,
		color             = { r = 1, g = 1, b = 1, a = 0.1 },
		strata            = "BACKGROUND",
		hideInScreenshots = true,
	}

	-- TODO: Mark the root from/to as visited
	local function DeepCopy(from, to, visited)
		to = to or {}
		visited = visited or {}
		for k, v in pairs(from) do
			if type(v) == "table" then
				if visited[v] then
					to[k] = visited[v]
				else
					local t = {}
					to[k] = t
					visited[v] = t
					DeepCopy(v, t, visited)
				end
			else
				to[k] = v
			end
		end
		return to
	end

	local function ShallowCopyTableNoRefs(from, to)
		to = to or {}
		for k, v in pairs(from) do
			assert(type(v) ~= "table", "Attempting to shallow copy a reference to a table")
			to[k] = v
		end
		return to
	end

	-- TODO: New defaults will not get added
	-- TODO: Use a metatable for defaults?
	if KLSavedVars.MC == nil then
		KLSavedVars.MC = DeepCopy(MC.defaultConfig)
	end

	MC.config = KLSavedVars.MC

	MC.options = CreateFrame("FRAME", "KL_MOUSE_OPTIONS", nil, "VerticalLayoutFrame")
	MC.options.name   = "KamikazeLib"
	MC.options.parent = nil

	local category, layout = Settings.RegisterCanvasLayoutCategory(MC.options, MC.options.name)
	MC.options.category = category
	Settings.RegisterAddOnCategory(category)

	MC.options:SetScript("OnHide", function()
		MC.TryHideColorPicker()
	end)

	MC.options.OnRefresh = function()
		-- NOTE: Runs twice when opening the window
		-- NOTE: If the user resets to defaults then hits cancel we want to undo all changes,
		-- including the reset to defaults. Since refresh happens right after defaults we have to be
		-- careful to avoid creating a new "previousConfig" checkpoint, which would make it impossible
		-- to revert to the original settings from before the default button was pressed.
		if MC.justAppliedDefaults then
			MC.justAppliedDefaults = nil
			return
		end

		MC.previousConfig = DeepCopy(MC.config)
	end

	MC.options.OnCommit = function()
		-- NOTE: Runs when closing the window
		MC.previousConfig = nil
	end

	-- TODO Requires a vertical layout to work
	MC.options.OnDefault = function()
		print("OnDefault")
		DeepCopy(MC.defaultConfig, MC.config)
		MC.UpdateEverything()
		MC.RefreshWidgets()
		MC.TryHideColorPicker()
		MC.justAppliedDefaults = true
	end

	local layoutIndex = 1
	local function NextLayoutIndex()
		local li = layoutIndex
		layoutIndex = layoutIndex + 1
		return li
	end

	local header = MC.options:CreateFontString(nil, "ARTWORK")
	header:SetFontObject(GameFontNormalLarge)
	header:SetText("KamikazeLib Options")
	header:SetJustifyH("LEFT")
	header:SetJustifyV("TOP")
	header.bottomPadding = 14
	header.layoutIndex = NextLayoutIndex()

	local enableCheckbox = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_ENABLE", MC.options, "InterfaceOptionsCheckButtonTemplate")
	enableCheckbox.Text:SetText("Enable")
	enableCheckbox:SetChecked(MC.config.enabled)
	enableCheckbox:SetScript("OnClick", function(checkbox)
		local enabled = checkbox:GetChecked()
		MC.config.enabled = enabled
		MC.UpdateEnabled()
		MC.UpdatePosition()
	end)
	enableCheckbox.layoutIndex = NextLayoutIndex()
	MC.options.enableCheckbox = enableCheckbox

	local step = 1
	local min, max = 1, 33
	local slider = CreateFrame("Slider", "KL_MOUSE_OPTIONS_THICKNESS", MC.options, "OptionsSliderTemplate")
	slider.Text:SetFontObject(GameFontNormal)
	slider.Text:SetText("Crosshair Thickness")
	slider.Low:SetText(tostring(min))
	slider.High:SetText(tostring(max))
	slider.topPadding = 10
	slider.bottomPadding = 10
	slider:SetValueStep(step)
	slider:SetMinMaxValues(min, max)
	slider:SetObeyStepOnDrag(true)
	slider:SetValue(MC.config.thickness)
	slider:SetScript("OnValueChanged", function(slider, value)
		MC.config.thickness = value
		MC.UpdateSize()
		MC.UpdatePosition()
	end)
	slider.layoutIndex = NextLayoutIndex()
	MC.options.slider = slider

	local label = MC.options:CreateFontString(nil, "ARTWORK");
	label:SetFontObject("GameFontNormal")
	label:SetText("Strata");
	label.bottomPadding = -8
	label.layoutIndex = NextLayoutIndex()

	local values = {
		"BACKGROUND",
		"LOW",
		"MEDIUM",
		"HIGH",
		"DIALOG",
	}
	local dropdown = CreateFrame("Frame", "KL_MOUSE_OPTIONS_STRATA", MC.options, "UIDropDownMenuTemplate")
	local function DropDownSetValue(dropdown, button, value, arg2, wasChecked)
		if wasChecked then return end
		MC.config.strata = value
		MC.UpdateStrata()
		UIDropDownMenu_SetText(dropdown, value)
	end
	local function DropDownInit(dropdown, level, menuList)
		-- NOTE: For some reason this is also called when the drop opens and menuList will be nil
		local info = UIDropDownMenu_CreateInfo()

		for _, value in ipairs(values) do
			info.text     = value
			info.arg1     = value
			info.checked  = MC.config.strata == value
			info.func     = DropDownSetValue
			info.menuList = menuList
			UIDropDownMenu_AddButton(info, level)
			if info.checked then
				UIDropDownMenu_SetText(dropdown, info.text)
			end
		end
	end
	dropdown.layoutIndex = NextLayoutIndex()
	UIDropDownMenu_Initialize(dropdown, DropDownInit, nil, 1, values)
	dropdown.leftPadding = -15
	MC.options.dropdown = dropdown

	local hideInScreenshotsCheckbox = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_HIDE_IN_SCREENSHOTS", MC.options, "InterfaceOptionsCheckButtonTemplate")
	hideInScreenshotsCheckbox.Text:SetText("Hide In Screenshots")
	hideInScreenshotsCheckbox:SetChecked(MC.config.hideInScreenshots)
	hideInScreenshotsCheckbox.SetValue = function(checkbox, value)
		-- NOTE: Value is a string for whatever weird reason
		local enabled = value == "1"
		MC.config.hideInScreenshots = enabled
	end
	hideInScreenshotsCheckbox.layoutIndex = NextLayoutIndex()
	MC.options.hideInScreenshotsCheckbox = hideInScreenshotsCheckbox

	local box = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_COLOR", MC.options, "InterfaceOptionsCheckButtonTemplate")
	box.Text:SetText("Test Color")
	box.SetValue = function()
		local c = MC.config.color
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - c.a
		ColorPickerFrame.previousValues = ShallowCopyTableNoRefs(c)
		ColorPickerFrame.func = function()
			local c = MC.config.color
			c.r, c.g, c.b = ColorPickerFrame:GetColorRGB()
			MC.UpdateColor()
		end
		ColorPickerFrame.opacityFunc = function()
			local c = MC.config.color
			c.a = 1 - OpacitySliderFrame:GetValue()
			MC.UpdateColor()
		end
		ColorPickerFrame.cancelFunc = function(previousValues)
			local c = MC.config.color
			c = ShallowCopyTableNoRefs(previousValues, c)
			MC.UpdateColor()
		end
		ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
		MC.colorPickerFunc = ColorPickerFrame.func
	end
	box.layoutIndex = NextLayoutIndex()

	MC.options.spacing       = 10
	MC.options.topPadding    = 16
	MC.options.leftPadding   = 16
	MC.options.bottomPadding = 16
	MC.options.rightPadding  = 16
	MC.options:Layout()

	MC.crosshairH = CreateFrame("FRAME", "KL_MOUSE_CURSOR_HORIZONTAL", MC.frame)
	MC.crosshairH:SetPoint("LEFT")
	MC.crosshairH.texture = MC.crosshairH:CreateTexture()
	MC.crosshairH.texture:SetAllPoints(true)

	MC.crosshairVT = CreateFrame("FRAME", "KL_MOUSE_CURSOR_VERTICAL_TOP", MC.frame)
	MC.crosshairVT:SetPoint("TOP")
	MC.crosshairVT.texture = MC.crosshairVT:CreateTexture()
	MC.crosshairVT.texture:SetAllPoints(true)

	MC.crosshairVB = CreateFrame("FRAME", "KL_MOUSE_CURSOR_VERTICAL_BOTTOM", MC.frame)
	MC.crosshairVB:SetPoint("BOTTOM")
	MC.crosshairVB.texture = MC.crosshairVB:CreateTexture()
	MC.crosshairVB.texture:SetAllPoints(true)

	MC.frame:SetIgnoreParentScale(true)
	MC.UpdateEverything()
end

function MC.RefreshWidgets()
	MC.options.enableCheckbox:SetChecked(MC.config.enabled)
	MC.options.slider:SetValue(MC.config.thickness)
	UIDropDownMenu_SetText(MC.options.dropdown, MC.config.strata)
	MC.options.hideInScreenshotsCheckbox:SetChecked(MC.config.hideInScreenshots)
end

local function Round(x)
	-- NOTE: Round half up toward positive infinity. Not great for negative numbers.
	return math.floor(x + 0.5)
end

function MC.ShowCrosshair()
	MC.crosshairH:Show()
	MC.crosshairVT:Show()
	MC.crosshairVB:Show()
end

function MC.HideCrosshair()
	MC.crosshairH:Hide()
	MC.crosshairVT:Hide()
	MC.crosshairVB:Hide()
end

function MC.TryHideColorPicker()
	-- NOTE: The color picker API is absolute garbage.
	-- - We have no way of knowing when the okay button is pressed.
	-- - We have no way to know if we still have the picker open (except the hack below).
	-- - If we open the picker before setting all possible callbacks it will call something random.
	-- - If we open the picker while someone else is using it out values aren't applied.
	-- - Built-in uses of the picker don't do the hide-show pattern (e.g. the chat background color).
	-- - It isn't modal and we can interact with the frame that opened the picker.
	-- - Reading opacity from "func" callback has undefined results.
	-- So we can't really tell when we need to hide the color picker. We don't know if it's still
	-- open and we don't know if someone else started using it. In fact, someone else using the
	-- picker without setting all the fields can break _us_ by causing callbacks at unexpected
	-- times.
	if ColorPickerFrame.func == MC.colorPickerFunc then
		ColorPickerFrame:Hide()
		ColorPickerFrame.func = nil
		ColorPickerFrame.opacityFunc = nil
		ColorPickerFrame.cancelFunc = nil
	end
end

function MC.UpdateEnabled()
	if MC.config.enabled then
		MC.frame:RegisterEvent("UI_SCALE_CHANGED")
		MC.frame:RegisterEvent("SCREENSHOT_STARTED")
		MC.frame:RegisterEvent("SCREENSHOT_SUCCEEDED")
		MC.frame:RegisterEvent("SCREENSHOT_FAILED")
		MC.frame:SetScript("OnUpdate", MC.OnUpdate)

		MC.ShowCrosshair()
	else
		MC.frame:UnregisterEvent("UI_SCALE_CHANGED")
		MC.frame:UnregisterEvent("SCREENSHOT_STARTED")
		MC.frame:UnregisterEvent("SCREENSHOT_SUCCEEDED")
		MC.frame:UnregisterEvent("SCREENSHOT_FAILED")
		MC.frame:SetScript("OnUpdate", nil)

		MC.HideCrosshair()
	end
end

function MC.UpdateSize()
	local canvasH = 768
	local screenW, screenH = GetPhysicalScreenSize()

	MC.screenW = screenW
	MC.screenH = screenH
	MC.screenToCanvas = canvasH / screenH
	MC.canvasToScreen = screenH / canvasH
	MC.frame:SetScale(MC.screenToCanvas)

	MC.crosshairH:SetWidth(screenW)
	MC.crosshairH:SetHeight(MC.config.thickness)
	MC.crosshairVT:SetWidth(MC.config.thickness)
	MC.crosshairVB:SetWidth(MC.config.thickness)
end

function MC.UpdateStrata()
	MC.crosshairH:SetFrameStrata(MC.config.strata)
	MC.crosshairVT:SetFrameStrata(MC.config.strata)
	MC.crosshairVB:SetFrameStrata(MC.config.strata)
end

function MC.UpdatePosition()
	local mx, my = GetCursorPosition()
	mx = Round(mx * MC.canvasToScreen)
	my = Round(my * MC.canvasToScreen - 1)

	local vth = MC.screenH - my - math.ceil (MC.config.thickness / 2)
	local vbh =              my - math.floor(MC.config.thickness / 2)
	MC.crosshairVT:SetHeight(math.max(0.001, vth))
	MC.crosshairVB:SetHeight(math.max(0.001, vbh))

	-- NOTE: Rounding in the final canvas space prevents "shimmering" that occurs from floating point
	-- rounding errors. Without this a crosshair set to 1 pixel thickness will flicker between 0 and
	-- 2 pixels of thickness based on the cursor position. This isn't actually a full round (the
	-- math.floor is missing), but presumably a truncation happens somewhere internally when
	-- rendering so it works out.
	local function RoundCanvas(x)
		return x + 0.5*MC.screenToCanvas
	end
	mx = RoundCanvas(mx)
	my = RoundCanvas(my)

	MC.crosshairH :SetPoint("LEFT",   nil, "BOTTOMLEFT", 0,  my)
	MC.crosshairVT:SetPoint("TOP",    nil, "TOPLEFT",    mx, 0)
	MC.crosshairVB:SetPoint("BOTTOM", nil, "BOTTOMLEFT", mx, 0)
end

function MC.UpdateColor()
	local c = MC.config.color
	local r, g, b, a = c.r, c.g, c.b, c.a
	MC.crosshairH.texture:SetColorTexture(r, g, b, a)
	MC.crosshairVT.texture:SetColorTexture(r, g, b, a)
	MC.crosshairVB.texture:SetColorTexture(r, g, b, a)
end

function MC.UpdateEverything()
	MC.UpdateEnabled()
	MC.UpdateSize()
	MC.UpdateStrata()
	MC.UpdatePosition()
	MC.UpdateColor()
end

-- Built-in Callbacks

function MC.OnUpdate(frame, elapsed)
	if MC.initialized then
		MC.UpdatePosition()
	end
end

function MC.OnEvent(frame, event, ...)
	if event == "VARIABLES_LOADED" then
		MC.Initialize()
		MC.initialized = true
	elseif event == "UI_SCALE_CHANGED" then
		-- NOTE: UI_SCALE_CHANGED can happen before VARIABLES_LOADED
		if MC.initialized then
			MC.UpdateSize()
			MC.UpdatePosition()
		end
	elseif event == "SCREENSHOT_STARTED" then
		if MC.config.hideInScreenshots then
			MC.HideCrosshair()
		end
	elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
		if MC.config.hideInScreenshots then
			MC.ShowCrosshair()
		end
	end
end

MC.Load()
