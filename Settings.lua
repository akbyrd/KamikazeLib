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
	local rootSize = 500
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
			accentColor       = Config.Color("FFFFCC00"),
			padSize           = Config.UISize(rootSize, -7),
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
			gapSize = Config.UISize(rootSize, -10),
		})

	Config.AddNode(Settings.cfgTree, "Default", "Label",
		{
		})

	Config.AddNode(Settings.cfgTree, "Label", "Title",
		{
			font = Config.Font({
				color  = "FFFFCC00",
				size   = 24,
			}),
		})

	Config.AddNode(Settings.cfgTree, "Default", "Button",
		{
			xSize           = Config.UISize(rootSize, -7),
			ySize           = Config.UISize(rootSize, -7),
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

	Config.AddNode(Settings.cfgTree, "Button", "Checkbox",
		{
			backgroundColor = Config.Color("73000000"),
			fillSize        = Config.UISize(rootSize, -8),
		})

	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Config.RefreshValues(Settings.cfgTree, pixelsToUI)

	Settings.Window = UI.Window.Create(UI.Root, Settings.cfgTree,
		{
			name = "Settings"
		})
	Settings.Window.Content = UI.Stack.Create(Settings.Window, Settings.cfgTree,
		{
			name     = "Stack",
			xStretch = 1,
			yStretch = 1,
		})
	Settings.Window.Content.Region:SetPoint("TOPLEFT")

	for key, decl, branch, node in Config.Enumerate(Kami.CDM.Cooldowns.cfgTree, "Essential") do
		local row = UI.Row.Create(Settings.Window.Content, Settings.cfgTree,
			{
				name     = "Row",
				text     = key,
				xStretch = 1,
			})
		row.Region:SetPoint("TOPLEFT")
		table.insert(Settings.Window.Content.Children, row)

		row.Content = UI.Stack.Create(row, Settings.cfgTree,
			{
				name     = "Content",
				xDir     = 1,
				yDir     = 0,
				xStretch = 1,
				yAlign   = 0.5,
			})
		row.Content.Region:SetPoint("TOPLEFT")

		local override = UI.Checkbox.Create(row.Content, Settings.cfgTree,
			{
				name   = "Override",
				yAlign = 0.5,
			})
		override.Region:SetPoint("TOPLEFT")
		table.insert(row.Content.Children, override)

		local source = UI.Label.Create(row.Content, Settings.cfgTree,
			{
				name   = "Source",
				text   = branch,
				yAlign = 0.5,
			})
		source.Region:SetPoint("TOPLEFT")
		table.insert(row.Content.Children, source)

		local value = UI.Label.Create(row.Content, Settings.cfgTree,
			{
				name   = "Value",
				text   = Config.Format(decl),
				xAlign = 0.5,
				yAlign = 0.5,
			})
		value.Region:SetPoint("TOPLEFT")
		table.insert(row.Content.Children, value)
	end

	-- TODO: Do we need to refresh scale?
	--UI.RefreshScale()
	Settings.Window:Measure(UI.NO_LIMIT, UI.NO_LIMIT)
	Settings.Window:Arrange()
	Settings.Window.Region:Hide()
end

function Settings.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Config.RefreshValues(Settings.cfgTree, pixelsToUI)

	UI.RefreshScale()
	Settings.Window:Measure(UI.NO_LIMIT, UI.NO_LIMIT)
	Settings.Window:Arrange()
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
