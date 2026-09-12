local Kami = select(2, ...)
local UI = {}
Kami.UI = UI

local Config = Kami.Config
local Util   = Kami.Util

-- NOTE: We assume cfg doesn't change. We don't dynamically re-apply state. Only scale fix-ups.
-- NOTE: We assume frames are not re-anchored unexpectedly. No ClearAllPoints calls after creation.

----------------------------------------------------------------------------------------------------
-- Root

function UI.Load()
	UI.Root = { Frame = CreateFrame("Frame", nil, UIParent) }
	UI.Root.Frame:SetAllPoints()
end

function UI.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	UI.Root.Frame:SetScale(pixelsToUI)
end

----------------------------------------------------------------------------------------------------
-- Component

UI.Component = {}
UI.Component.__index = UI.Component

----------------------------------------------------------------------------------------------------
-- Window

UI.Window = setmetatable({}, { __index = UI.Component })
UI.Window.__index = UI.Window

function UI.Window.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Window)
	self.style = Config.GetBranch(cfgTree, "Window")

	self.Frame = CreateFrame("Frame", nil, parent.Frame, "BackdropTemplate")
	self.Frame:SetParentKey(args.name)
	self.Frame:SetClampedToScreen(true)
	self.Frame:SetMovable(true)
	self.Frame:EnableMouse(true)
	self.Frame:RegisterForDrag("LeftButton")
	self.Frame:SetScript("OnDragStart", self.Frame.StartMoving)
	self.Frame:SetScript("OnDragStop", function()
		self.Frame:StopMovingOrSizing()
		local x = Round(self.Frame:GetLeft())
		local y = Round(self.Frame:GetTop())
		self.Frame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)
	end)

	local screenX, screenY = GetPhysicalScreenSize()
	local x = Round((screenX - self.style.xSize) / 2)
	local y = Round((screenY + self.style.ySize) / 2)
	self.Frame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)

	self.Close = UI.IconButton.Create(self, cfgTree,
		{
			name      = "Close",
			styleName = "CloseButton",
			glyph     = 0xE5CD,
			onClick   = function() self.Frame:Hide() end,
		})

	return self
end

function UI.Window:RefreshScale()
	self.Frame:SetSize(self.style.xSize, self.style.ySize)
	self.Frame:SetBackdrop({
		bgFile   = self.style.backgroundTexture,
		edgeFile = self.style.backgroundTexture,
		edgeSize = self.style.borderSize })
	self.Frame:SetBackdropColor(self.style.backgroundColor:GetRGBA())
	self.Frame:SetBackdropBorderColor(self.style.borderColor:GetRGBA())

	self.Close.Frame:SetPoint("TOPRIGHT", -self.style.paddingSize, -self.style.paddingSize)
	self.Close:RefreshScale()
end

----------------------------------------------------------------------------------------------------
-- IconButton

UI.IconButton = setmetatable({}, { __index = UI.Component })
UI.IconButton.__index = UI.IconButton

function UI.IconButton.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.IconButton)
	self.style = Config.GetBranch(cfgTree, args.styleName or "IconButton")

	self.Button = CreateFrame("Button", nil, parent.Frame, "BackdropTemplate")
	self.Button:SetParentKey(args.name)
	self.Button:SetText(Util.Utf8(args.glyph))
	self.Button:SetPushedTextOffset(0, 0)
	self.Button:RegisterForClicks("LeftButtonDown")
	self.Button:SetScript("OnClick", function() args.onClick(self) end)
	self.Button:SetNormalFontObject(self.style.font.object)
	self.Button:SetHighlightTexture(self.style.hoverTexture, "BLEND")
	self.Button:SetHighlightFontObject(self.style.hoverFont.object)

	local ht = self.Button:GetHighlightTexture()
	ht:SetVertexColor(self.style.hoverColor:GetRGBA())
	ht:ClearAllPoints()

	self.FontString = self.Button:GetFontString()
	self.FontString:SetJustifyH("LEFT")
	self.FontString:SetJustifyV("TOP")
	self.FontString:ClearAllPoints()

	self.Frame = self.Button
	return self
end

function UI.IconButton:RefreshScale()
	local fontSize = self.style.font.size
	local buttonSize = Util.SameParity(fontSize, self.style.xSize)
	local xOffset, yOffset = Util.CenterIcon(self.style.font.info, buttonSize, fontSize)

	local borderSize = self.style.borderSize
	self.Button:SetBackdrop({
		bgFile   = self.style.backgroundTexture,
		edgeFile = self.style.backgroundTexture,
		edgeSize = borderSize,
		insets   = { left = borderSize, right = borderSize, top = borderSize, bottom = borderSize } })
	self.Button:SetBackdropColor(self.style.backgroundColor:GetRGBA())
	self.Button:SetBackdropBorderColor(self.style.borderColor:GetRGBA())

	local ht = self.Button:GetHighlightTexture()
	ht:SetPoint("TOPLEFT",      borderSize, -borderSize)
	ht:SetPoint("BOTTOMRIGHT", -borderSize,  borderSize)

	self.Button:SetSize(buttonSize, buttonSize)
	self.FontString:SetPoint("TOPLEFT", xOffset, yOffset)
end

----------------------------------------------------------------------------------------------------
-- File Load

UI.Load()

-- TODO: Consider a declarative UI builder
