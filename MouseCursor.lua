-- TODO: Make a color swatch button for color
-- TODO: Mouse position is wrong after reloading UI
-- TODO: Implement an unpack function

-- TODO: Scroll view
-- TODO: Slider value/edit box
-- TODO: Better color picker
-- TODO: Try to refactor to make it easier to follow and harder to make mistakes
-- TODO: Add a circle option
-- TODO: Lazily create config options when opened
-- TODO: More consistent handling of self vs proper names (e.g. eventFrame, options, config)

local eventFrame = CreateFrame("FRAME", "KL_MOUSE_CURSOR", UIParent)

function eventFrame:Initialize()
	self.defaultConfig = {
		enabled           = true,
		thickness         = 3,
		color             = { r = 1, g = 1, b = 1, a = 0.1 },
		strata            = "BACKGROUND",
		hideInScreenshots = true,
	}

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

	if KLSavedVars == nil then
		KLSavedVars = {}
		KLSavedVars.cursorConfig = DeepCopy(self.defaultConfig)
	end

	self.config = KLSavedVars.cursorConfig

	self.options = CreateFrame("FRAME", "KL_MOUSE_OPTIONS", nil, "VerticalLayoutFrame")
	self.options.name   = "KamikazeLib"
	self.options.parent = nil

	self.options:SetScript("OnHide", function(self)
		eventFrame:TryHideColorPicker()
	end)

	self.options.refresh = function(self)
		-- NOTE: If the user resets to defaults then hits cancel we want to undo all changes,
		-- including the reset to defaults. Since refresh happens right after defaults we have to be
		-- careful to avoid creating a new "previousConfig" checkpoint, which would make it impossible
		-- to revert to the original settings from before the default button was pressed.
		if self.justAppliedDefaults then
			self.justAppliedDefaults = nil
			return
		end

		eventFrame.previousConfig = DeepCopy(eventFrame.config)
	end

	self.options.okay = function(self)
		eventFrame.previousConfig = nil
	end

	self.options.cancel = function(self)
		DeepCopy(eventFrame.previousConfig, eventFrame.config)
		eventFrame.previousConfig = nil
		eventFrame:UpdateEverything()
		eventFrame:RefreshWidgets()
	end

	self.options.default = function(self)
		DeepCopy(eventFrame.defaultConfig, eventFrame.config)
		eventFrame:UpdateEverything()
		eventFrame:RefreshWidgets()
		eventFrame:TryHideColorPicker()
		self.justAppliedDefaults = true
	end

	InterfaceOptions_AddCategory(self.options)

	local layoutIndex = 1
	local function NextLayoutIndex()
		local li = layoutIndex
		layoutIndex = layoutIndex + 1
		return li
	end

	local header = self.options:CreateFontString(nil, "ARTWORK")
	header:SetFontObject(GameFontNormalLarge)
	header:SetText("KamikazeLib Options")
	header:SetJustifyH("LEFT")
	header:SetJustifyV("TOP")
	header.bottomPadding = 14
	header.layoutIndex = NextLayoutIndex()

	local enableCheckbox = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_ENABLE", self.options, "InterfaceOptionsCheckButtonTemplate")
	enableCheckbox.Text:SetText("Enable")
	enableCheckbox:SetChecked(self.config.enabled)
	enableCheckbox.SetValue = function(self, value)
		-- NOTE: Value is a string for whatever weird reason
		local enabled = value == "1"
		eventFrame.config.enabled = enabled
		eventFrame:UpdateEnabled()
		eventFrame:UpdatePosition()
	end
	enableCheckbox.layoutIndex = NextLayoutIndex()
	self.options.enableCheckbox = enableCheckbox

	local step = 1
	local min, max = 1, 33
	local slider = CreateFrame("Slider", "KL_MOUSE_OPTIONS_THICKNESS", self.options, "OptionsSliderTemplate")
	slider.Text:SetFontObject(GameFontNormal)
	slider.Text:SetText("Crosshair Thickness")
	slider.Low:SetText(tostring(min))
	slider.High:SetText(tostring(max))
	slider.topPadding = 10
	slider.bottomPadding = 10
	slider:SetValueStep(step)
	slider:SetMinMaxValues(min, max)
	slider:SetObeyStepOnDrag(true)
	slider:SetValue(self.config.thickness)
	slider:SetScript("OnValueChanged", function(self, value, userInput)
		eventFrame.config.thickness = value
		eventFrame:UpdateSize()
		eventFrame:UpdatePosition()
	end)
	slider.layoutIndex = NextLayoutIndex()
	self.options.slider = slider

	local label = self.options:CreateFontString(nil, "ARTWORK");
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
	local dropdown = CreateFrame("Frame", "KL_MOUSE_OPTIONS_STRATA", self.options, "UIDropDownMenuTemplate")
	function dropdown.SetValue(button, value, arg2, wasChecked)
		if wasChecked then return end
		eventFrame.config.strata = value
		eventFrame:UpdateStrata()
		UIDropDownMenu_SetText(dropdown, value)
	end
	function dropdown:Initialize(level, menuList)
		-- NOTE: For some reason this is also called when the drop opens and menuList will be nil
		local info = UIDropDownMenu_CreateInfo()

		for _, value in ipairs(values) do
			info.text     = value
			info.arg1     = value
			info.checked  = eventFrame.config.strata == value
			info.func     = dropdown.SetValue
			info.menuList = menuList
			UIDropDownMenu_AddButton(info, level)
			if info.checked then
				UIDropDownMenu_SetText(self, info.text)
			end
		end
	end
	dropdown.layoutIndex = NextLayoutIndex()
	UIDropDownMenu_Initialize(dropdown, dropdown.Initialize, nil, 1, values)
	dropdown.leftPadding = -15
	self.options.dropdown = dropdown

	local hideInScreenshotsCheckbox = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_HIDE_IN_SCREENSHOTS", self.options, "InterfaceOptionsCheckButtonTemplate")
	hideInScreenshotsCheckbox.Text:SetText("Hide In Screenshots")
	hideInScreenshotsCheckbox:SetChecked(self.config.hideInScreenshots)
	hideInScreenshotsCheckbox.SetValue = function(self, value)
		-- NOTE: Value is a string for whatever weird reason
		local enabled = value == "1"
		eventFrame.config.hideInScreenshots = enabled
	end
	hideInScreenshotsCheckbox.layoutIndex = NextLayoutIndex()
	self.options.hideInScreenshotsCheckbox = hideInScreenshotsCheckbox

	local box = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_COLOR", self.options, "InterfaceOptionsCheckButtonTemplate")
	box.Text:SetText("Test Color")
	box.SetValue = function(self, value)


		local c = eventFrame.config.color
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - c.a
		ColorPickerFrame.previousValues = ShallowCopyTableNoRefs(c)
		ColorPickerFrame.func = function()
			local c = eventFrame.config.color
			c.r, c.g, c.b = ColorPickerFrame:GetColorRGB()
			eventFrame:UpdateColor()
		end
		ColorPickerFrame.opacityFunc = function()
			local c = eventFrame.config.color
			c.a = 1 - OpacitySliderFrame:GetValue()
			eventFrame:UpdateColor()
		end
		ColorPickerFrame.cancelFunc = function(previousValues)
			local c = eventFrame.config.color
			c = ShallowCopyTableNoRefs(previousValues, c)
			eventFrame:UpdateColor()
		end
		ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
		eventFrame.colorPickerFunc = ColorPickerFrame.func


	end
	box.layoutIndex = NextLayoutIndex()

	self.options.spacing       = 10
	self.options.topPadding    = 16
	self.options.leftPadding   = 16
	self.options.bottomPadding = 16
	self.options.rightPadding  = 16
	self.options:Layout()

	self.crosshairH = CreateFrame("FRAME", "KL_MOUSE_CURSOR_HORIZONTAL", self)
	self.crosshairH:SetPoint("LEFT")
	self.crosshairH.texture = self.crosshairH:CreateTexture()
	self.crosshairH.texture:SetAllPoints(true)

	self.crosshairVT = CreateFrame("FRAME", "KL_MOUSE_CURSOR_VERTICAL_TOP", self)
	self.crosshairVT:SetPoint("TOP")
	self.crosshairVT.texture = self.crosshairVT:CreateTexture()
	self.crosshairVT.texture:SetAllPoints(true)

	self.crosshairVB = CreateFrame("FRAME", "KL_MOUSE_CURSOR_VERTICAL_BOTTOM", self)
	self.crosshairVB:SetPoint("BOTTOM")
	self.crosshairVB.texture = self.crosshairVB:CreateTexture()
	self.crosshairVB.texture:SetAllPoints(true)

	self:SetIgnoreParentScale(true)
	self:UpdateEverything()
end

function eventFrame:RefreshWidgets()
	self.options.enableCheckbox:SetChecked(self.config.enabled)
	self.options.slider:SetValue(self.config.thickness)
	UIDropDownMenu_SetText(self.options.dropdown, self.config.strata)
	self.options.hideInScreenshotsCheckbox:SetChecked(self.config.hideInScreenshots)
end

local function Round(x)
	-- NOTE: Round half up toward positive infinity. Not great for negative numbers.
	return math.floor(x + 0.5)
end

function eventFrame:ShowCrosshair()
	self.crosshairH:Show()
	self.crosshairVT:Show()
	self.crosshairVB:Show()
end

function eventFrame:HideCrosshair()
	self.crosshairH:Hide()
	self.crosshairVT:Hide()
	self.crosshairVB:Hide()
end

function eventFrame:TryHideColorPicker()
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
	if ColorPickerFrame.func == self.colorPickerFunc then
		ColorPickerFrame:Hide()
		ColorPickerFrame.func = nil
		ColorPickerFrame.opacityFunc = nil
		ColorPickerFrame.cancelFunc = nil
	end
end

function eventFrame:UpdateEnabled()
	if self.config.enabled then
		self:RegisterEvent("UI_SCALE_CHANGED")
		self:RegisterEvent("SCREENSHOT_STARTED")
		self:RegisterEvent("SCREENSHOT_SUCCEEDED")
		self:RegisterEvent("SCREENSHOT_FAILED")
		self:SetScript("OnUpdate", self.OnUpdate)

		self:ShowCrosshair()
	else
		self:UnregisterEvent("UI_SCALE_CHANGED")
		self:UnregisterEvent("SCREENSHOT_STARTED")
		self:UnregisterEvent("SCREENSHOT_SUCCEEDED")
		self:UnregisterEvent("SCREENSHOT_FAILED")
		self:SetScript("OnUpdate", nil)

		self:HideCrosshair()
	end
end

function eventFrame:UpdateSize()
	local canvasH = 768
	local screenW, screenH = GetPhysicalScreenSize()

	self.screenW = screenW
	self.screenH = screenH
	self.screenToCanvas = canvasH / screenH
	self.canvasToScreen = screenH / canvasH
	self:SetScale(self.screenToCanvas)

	self.crosshairH:SetWidth(screenW)
	self.crosshairH:SetHeight(self.config.thickness)
	self.crosshairVT:SetWidth(self.config.thickness)
	self.crosshairVB:SetWidth(self.config.thickness)
end

function eventFrame:UpdateStrata()
	self.crosshairH:SetFrameStrata(self.config.strata)
	self.crosshairVT:SetFrameStrata(self.config.strata)
	self.crosshairVB:SetFrameStrata(self.config.strata)
end

function eventFrame:UpdatePosition()
	local mx, my = GetCursorPosition()
	mx = Round(mx * self.canvasToScreen)
	my = Round(my * self.canvasToScreen - 1)

	local vth = self.screenH - my - math.ceil (self.config.thickness / 2)
	local vbh =                my - math.floor(self.config.thickness / 2)
	self.crosshairVT:SetHeight(math.max(0.001, vth))
	self.crosshairVB:SetHeight(math.max(0.001, vbh))

	-- NOTE: Rounding in the final canvas space prevents "shimmering" that occurs from floating point
	-- rounding errors. Without this a crosshair set to 1 pixel thickness will flicker between 0 and
	-- 2 pixels of thickness based on the cursor position. This isn't actually a full round (the
	-- math.floor is missing), but presumably a truncation happens somewhere internally when
	-- rendering so it works out.
	local function RoundCanvas(x)
		return x + 0.5*self.screenToCanvas
	end
	mx = RoundCanvas(mx)
	my = RoundCanvas(my)

	self.crosshairH :SetPoint("LEFT",   nil, "BOTTOMLEFT", 0,  my)
	self.crosshairVT:SetPoint("TOP",    nil, "TOPLEFT",    mx, 0)
	self.crosshairVB:SetPoint("BOTTOM", nil, "BOTTOMLEFT", mx, 0)
end

function eventFrame:UpdateColor()
	local c = self.config.color
	local r, g, b, a = c.r, c.g, c.b, c.a
	self.crosshairH.texture:SetColorTexture(r, g, b, a)
	self.crosshairVT.texture:SetColorTexture(r, g, b, a)
	self.crosshairVB.texture:SetColorTexture(r, g, b, a)
end

function eventFrame:UpdateEverything()
	self:UpdateEnabled()
	self:UpdateSize()
	self:UpdateStrata()
	self:UpdatePosition()
	self:UpdateColor()
end

local function ShowOptions()
	-- NOTE: The very first time OpenToCategory is called it ignores the panel option. It seems it
	-- needs to be opened once before it works properly.
	if not InterfaceOptionsFrame:IsShown() then
		InterfaceOptionsFrame_Show()
	end

	InterfaceOptionsFrame_OpenToCategory(eventFrame.options)
end

-- Built-in Callbacks

function eventFrame:OnUpdate()
	if self.initialized then
		self:UpdatePosition()
	end
end

function eventFrame:OnEvent(event, ...)
	if event == "VARIABLES_LOADED" then
		self:Initialize()
		self.initialized = true
	elseif event == "UI_SCALE_CHANGED" then
		-- NOTE: UI_SCALE_CHANGED can happen before VARIABLES_LOADED
		if self.initialized then
			self:UpdateSize()
			self:UpdatePosition()
		end
	elseif event == "SCREENSHOT_STARTED" then
		if self.config.hideInScreenshots then
			self:HideCrosshair()
		end
	elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
		if self.config.hideInScreenshots then
			self:ShowCrosshair()
		end
	end
end

local function SlashCommandHandler(msg, editBox)
	ShowOptions()
end

eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:SetScript("OnEvent", eventFrame.OnEvent)

SLASH_KAMIKAZELIB1 = "/kamikazelib"
SLASH_KAMIKAZELIB2 = "/kl"
SlashCmdList.KAMIKAZELIB = SlashCommandHandler
