-- TODO: Add option to hide with screenshots
-- TODO: Add a color option

-- TODO: Scroll view
-- TODO: Slider value/edit box
-- TODO: Better way to specify padding?
-- TODO: Try to refactor to make it easier to follow and harder to make mistakes
-- TODO: Add a circle option
-- TODO: Lazily create config options when opened
-- TODO: More consistent handling of self vs proper names (e.g. eventFrame, options, config)

local eventFrame = CreateFrame("FRAME", "KL_MOUSE_CURSOR", UIParent)

function eventFrame:Initialize()
	self.defaultConfig = {
		enabled = true,
		strata = "BACKGROUND",
		thickness = 3,
		r = 1,
		g = 1,
		b = 1,
		a = 0.1,
	}

	local function ShallowCopyTableNoRefs(from, to)
		to = to or {}
		for k, v in pairs(from) do
			assert(type(value) ~= "table", "Attempting to shallow copy a reference to a table")
			to[k] = v
		end
		return to
	end

	if KLSavedVars == nil then
		KLSavedVars = {}
		KLSavedVars.cursorConfig = ShallowCopyTableNoRefs(self.defaultConfig)
	end

	self.config = KLSavedVars.cursorConfig

	self.options = CreateFrame("FRAME", "KL_MOUSE_OPTIONS", nil, "VerticalLayoutFrame")
	self.options.name   = "KamikazeLib"
	self.options.parent = nil

	self.options.refresh = function(self)
		-- NOTE: If the user resets to defaults then hits cancel we want to undo all changes,
		-- including the reset to defaults. Since refresh happens right after defaults we have to be
		-- careful to avoid creating a new "previousConfig" checkpoint, which would make it impossible
		-- to revert to the original settings from before the default button was pressed.
		if self.justAppliedDefaults then
			self.justAppliedDefaults = nil
			return
		end

		eventFrame.previousConfig = ShallowCopyTableNoRefs(eventFrame.config)
	end

	self.options.okay = function(self)
		eventFrame.previousConfig = nil
	end

	self.options.cancel = function(self)
		ShallowCopyTableNoRefs(eventFrame.previousConfig, eventFrame.config)
		eventFrame.previousConfig = nil
		eventFrame:UpdateEverything()
		eventFrame:RefreshWidgets()
	end

	self.options.default = function(self)
		ShallowCopyTableNoRefs(eventFrame.defaultConfig, eventFrame.config)
		eventFrame:UpdateEverything()
		eventFrame:RefreshWidgets()
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

	local checkbox = CreateFrame("CheckButton", "KL_MOUSE_OPTIONS_ENABLE", self.options, "InterfaceOptionsCheckButtonTemplate")
	checkbox.Text:SetText("Enable")
	checkbox:SetChecked(self.config.enabled)
	checkbox.SetValue = function(self, value)
		-- NOTE: Value is a string for whatever weird reason
		local enabled = value == "1"
		eventFrame.config.enabled = enabled
		eventFrame:UpdateEnabled()
		eventFrame:UpdatePosition()
	end
	checkbox.layoutIndex = NextLayoutIndex()
	self.options.checkbox = checkbox

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
	self.crosshairH.texture:SetColorTexture(self.config.r, self.config.g, self.config.b, self.config.a)

	self.crosshairVT = CreateFrame("FRAME", "KL_MOUSE_CURSOR_VERTICAL_TOP", self)
	self.crosshairVT:SetPoint("TOP")
	self.crosshairVT.texture = self.crosshairVT:CreateTexture()
	self.crosshairVT.texture:SetAllPoints(true)
	self.crosshairVT.texture:SetColorTexture(self.config.r, self.config.g, self.config.b, self.config.a)

	self.crosshairVB = CreateFrame("FRAME", "KL_MOUSE_CURSOR_VERTICAL_BOTTOM", self)
	self.crosshairVB:SetPoint("BOTTOM")
	self.crosshairVB.texture = self.crosshairVB:CreateTexture()
	self.crosshairVB.texture:SetAllPoints(true)
	self.crosshairVB.texture:SetColorTexture(self.config.r, self.config.g, self.config.b, self.config.a)

	self:SetIgnoreParentScale(true)
	self:UpdateEverything()
end

function eventFrame:RefreshWidgets()
	self.options.checkbox:SetChecked(self.config.enabled)
	self.options.slider:SetValue(self.config.thickness)
	UIDropDownMenu_SetText(self.options.dropdown, self.config.strata)
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

function eventFrame:UpdateEverything()
	self:UpdateEnabled()
	self:UpdateSize()
	self:UpdateStrata()
	self:UpdatePosition()
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
		self:HideCrosshair()
	elseif event == "SCREENSHOT_SUCCEEDED" then
		self:ShowCrosshair()
	elseif event == "SCREENSHOT_FAILED" then
		self:ShowCrosshair()
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
