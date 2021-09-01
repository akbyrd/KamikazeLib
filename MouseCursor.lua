-- TODO: Apply config change immediately
-- TODO: Restore previous options on Cancel button
-- TODO: Support Default button
-- TODO: Add a circle option

local eventFrame = CreateFrame("FRAME", "KL_MOUSE_CURSOR")

function eventFrame:Initialize()
	self.defaultConfig = {
		strata = "LOW",
		thickness = 1,
		r = 1,
		g = 1,
		b = 1,
		a = 0.1,
	}

	if KLSavedVars == nil then
		KLSavedVars = {}
		KLSavedVars.cursorConfig = {}
		for k, v in pairs(self.defaultConfig) do
			KLSavedVars.cursorConfig[k] = v
		end
	end
	self.config = KLSavedVars.cursorConfig

	self.options = CreateFrame("FRAME", "KL_MOUSE_OPTIONS", nil, "VerticalLayoutFrame")
	self.options.name    = "KamikazeLib"
	self.options.parent  = nil
	self.options.okay    = nil
	self.options.cancel  = nil
	self.options.default = nil
	self.options.refresh = nil
	InterfaceOptions_AddCategory(self.options)

	local header = self.options:CreateFontString(nil, "ARTWORK")
	header:SetFontObject(GameFontNormalLarge)
	header:SetText("KamikazeLib Options")
	header:SetJustifyH("LEFT")
	header:SetJustifyV("TOP")
	header.layoutIndex = 1

	local default = 1
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
	end)
	slider.layoutIndex = 2

	local label = self.options:CreateFontString(nil, "ARTWORK");
	label:SetFontObject("GameFontNormal")
	label.bottomPadding = -8
	label:SetText("Strata");
	label.layoutIndex = 3

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
	dropdown.layoutIndex = 4
	UIDropDownMenu_Initialize(dropdown, dropdown.Initialize, nil, 1, values)
	dropdown.leftPadding = -15

	-- TODO: Better way to specify padding?
	-- TODO: Scroll view
	-- TODO: Backdrop for testing
	-- TODO: Slider value/edit box
	self.options.spacing       = 10
	self.options.topPadding    = 16
	self.options.leftPadding   = 16
	self.options.bottomPadding = 16
	self.options.rightPadding  = 16
	self.options: Layout()

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

	self:UpdateSize()
	self:UpdateStrata()
	self:UpdatePosition()
end

local function Round(x)
	-- NOTE: Round half up toward positive infinity. Not great for negative numbers.
	return math.floor(x + 0.5)
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
		end
	end
end

local function SlashCommandHandler(msg, editBox)
	ShowOptions()
end

eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:SetScript("OnUpdate", eventFrame.OnUpdate)
eventFrame:SetScript("OnEvent", eventFrame.OnEvent)

SLASH_KAMIKAZELIB1 = "/kamikazelib"
SLASH_KAMIKAZELIB2 = "/kl"
SlashCmdList.KAMIKAZELIB = SlashCommandHandler
