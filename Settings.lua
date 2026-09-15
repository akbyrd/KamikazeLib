local Kami = select(2, ...)
local Settings = {}
Kami.Settings = Settings

local Config = Kami.Config
local UI     = Kami.UI
local LSM    = LibStub("LibSharedMedia-3.0")

function Settings.Load()
	Settings.handlers = {}
	Settings.eventFrame = CreateFrame("Frame")
	Settings.eventFrame:SetParentKey("Kami.Settings.Event")
	Settings.eventFrame:SetScript("OnEvent",       Settings.DispatchEvent)
	Settings.RegisterEvent("UI_SCALE_CHANGED",     Settings.RefreshScale)
	Settings.RegisterEvent("DISPLAY_SIZE_CHANGED", Settings.RefreshScale)
	hooksecurefunc(UIParent, "SetScale",           Settings.RefreshScale)

	-- TODO: Any good patterns for "stronger types" in lua?
	local rootSize = 400
	local textFont = {
		path = LSM:Fetch("font", "PT Sans Narrow", true) or "Fonts\\ARIALN.TTF",
	}
	local iconFont = {
		path    = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf",
		ascent  = 1056,
		descent = 96,
		grid    = 24,
		size    = 24,
	}

	Settings.cfgTree = Config.Create()

	Config.AddNode(Settings.cfgTree, nil, "Default",
		{
			borderSize        = Config.Size("1px"),
			borderColor       = Config.Color("0FFFFFFF"),
			backgroundTexture = Config.String("Interface\\Buttons\\WHITE8x8"),
			backgroundColor   = Config.Color("FA1C1C1C"),
			padSize           = Config.UISize(rootSize, -8),
			font              = Config.Font({
				info   = textFont,
				color  = "A6FFFFFF",
				shadow = true,
				size   = 18, -- TODO: Want to be able to use Config.Size for this
			}),
		})

	Config.AddNode(Settings.cfgTree, "Default", "Window",
		{
			xSize = Config.UISize(rootSize, 0),
			ySize = Config.UISize(rootSize, 1),
		})

	Config.AddNode(Settings.cfgTree, "Default", "Row",
		{
			ySize      = Config.UISize(rootSize, -6),
			labelWidth = Config.UISize(rootSize, -2),
		})

	Config.AddNode(Settings.cfgTree, "Default", "Stack",
		{
			gapSize = Config.UISize(rootSize, -7),
		})

	Config.AddNode(Settings.cfgTree, "Default", "Label",
		{
		})

	Config.AddNode(Settings.cfgTree, "Default", "Button",
		{
			xSize           = Config.UISize(rootSize, -6),
			ySize           = Config.UISize(rootSize, -6),
			backgroundColor = Config.Color("08FFFFFF"),
			hoverTexture    = Config.String("Interface\\Buttons\\WHITE8x8"),
			hoverColor      = Config.Color("14FFFFFF"),
		})

	Config.AddNode(Settings.cfgTree, "Button", "IconButton",
		{
			font = Config.Font({
				info   = iconFont,
				color  = "A6FFFFFF",
				shadow = true,
				size   = 24,
			}),
			hoverFont = Config.Font({
				info   = iconFont,
				color  = "FFFFFFFF",
				shadow = true,
				size   = 24,
			}),
			disabledFont = Config.Font({
				info   = iconFont,
				color  = "59FFFFFF",
				shadow = true,
				size   = 24,
			}),
		})

	Config.AddNode(Settings.cfgTree, "IconButton", "CloseButton",
		{
			font       = Config.Font({ color = "59FFFFFF" }),
			hoverColor = Config.Color("80E64D4D"),
		})

	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Config.RefreshValues(Settings.cfgTree, pixelsToUI)

	Settings.Window = UI.Window.Create(UI.Root, Settings.cfgTree, { name = "Settings" })
	Settings.Window.Region:Hide()

	for i = 1, 10 do
		local row = UI.Row.Create(Settings.Window.Stack, Settings.cfgTree,
			{
				name = "Row",
				text = "Hello World",
			})
		row.Region:SetPoint("TOPLEFT")

		local control = UI.IconButton.Create(row, Settings.cfgTree,
			{
				name      = "Control",
				styleName = "CloseButton",
				glyph     = 0xE5CD,
				onClick   = function() end,
				yAlign    = 0.5,
			})
		control.Region:SetPoint("TOPLEFT")
	end

	-- TODO: Do we need to refresh scale?
	--UI.RefreshScale()
	Settings.Window:Measure(UI.NO_LIMIT, UI.NO_LIMIT)
	Settings.Window:Arrange(0, 0, UI.NO_LIMIT, UI.NO_LIMIT)
end

function Settings.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Config.RefreshValues(Settings.cfgTree, pixelsToUI)

	UI.RefreshScale()
	Settings.Window:Measure(UI.NO_LIMIT, UI.NO_LIMIT)
	Settings.Window:Arrange(0, 0, UI.NO_LIMIT, UI.NO_LIMIT)
end

function Settings.Toggle()
	Settings.Window.Region:SetShown(not Settings.Window.Region:IsShown())
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function Settings.RegisterEvent(event, func)
	Settings.eventFrame:RegisterEvent(event)
	Settings.handlers[event] = func
end

function Settings.DispatchEvent(frame, event, ...)
	local func = Settings.handlers[event]
	func(...)
end

----------------------------------------------------------------------------------------------------
-- File Load

Settings.Load()
Settings.Toggle()

local login = CreateFrame("Frame")
--login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	C_Timer.After(0, function()
		DandersFrames:ToggleGUI()
		SlashCmdList.SOURCERY("")
	end)
end)

-- TODO: Refine cfg and construction ordering
-- TODO: Improve slash command handling
