local Kami = select(2, ...)
local Settings = {}
Kami.Settings = Settings

local Config = Kami.Config
local UI     = Kami.UI

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
		})

	Config.AddNode(Settings.cfgTree, "Default", "Window",
		{
			xSize       = Config.UISize(rootSize, 0),
			ySize       = Config.UISize(rootSize, 1),
			paddingSize = Config.UISize(rootSize, -8),
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
				info    = iconFont,
				color   = "A6FFFFFF",
				shadow  = true,
			}),
			hoverFont = Config.Font({
				info    = iconFont,
				color   = "FFFFFFFF",
				shadow  = true,
			}),
			disabledFont = Config.Font({
				info    = iconFont,
				color   = "59FFFFFF",
				shadow  = true,
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
	Settings.Window.Frame:Hide()

	Settings.Window:RefreshScale()
end

function Settings.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	Config.RefreshValues(Settings.cfgTree, pixelsToUI)

	UI.RefreshScale()
	Settings.Window:RefreshScale()
end

function Settings.Toggle()
	Settings.Window.Frame:SetShown(not Settings.Window.Frame:IsShown())
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

-- TODO: Should we use a flat colored box or a gradient texture for things?
-- TODO: Refine cfg and construction ordering
-- TODO: Improve slash command handling
