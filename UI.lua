local Kami = select(2, ...)
local UI = {}
Kami.UI = UI

local Config = Kami.Config
local Util   = Kami.Util

-- NOTE: We assume cfg doesn't change. We don't dynamically re-apply state. Only scale fix-ups.
-- NOTE: We assume frames are not re-anchored unexpectedly. No unnecessary ClearAllPoints.
-- NOTE: The caller is responsible for anchoring, not Create (unless it's an internal component).
-- NOTE: SetPointsOffset is used for positioning to avoid repeating anchors.

----------------------------------------------------------------------------------------------------
-- Root

function UI.Load()
	UI.Root = {}
	UI.Root.Region = CreateFrame("Frame", nil, UIParent)
	UI.Root.Region:SetAllPoints()
	UI.Root.Children = {}
end

-- TODO: All 3 passes and recurse?
function UI.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	UI.Root.Region:SetScale(pixelsToUI)
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
	self.style = Config.GetBranch(cfgTree, args.styleName or "Window")

	self.Frame = CreateFrame("Frame", nil, parent.Region, "BackdropTemplate")
	self.Frame:SetParentKey(args.name)
	self.Frame:SetFrameStrata("HIGH")
	self.Frame:SetToplevel(true)
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

	self.Region = self.Frame
	self.Children = {}
	table.insert(parent.Children, self)

	self.Close = UI.IconButton.Create(self, cfgTree,
		{
			name      = "Close",
			styleName = "CloseButton",
			glyph     = 0xE5CD,
			onClick   = function() self.Frame:Hide() end,
		})
	self.Close.Region:SetPoint("TOPRIGHT")

	self.Stack = UI.Stack.Create(self, cfgTree,
		{
			name = "Stack",
		})
	self.Stack.Region:SetPoint("TOPLEFT")

	return self
end

function UI.Window:Measure()
	local s = self.style

	self.xSize = s.xSize
	self.ySize = s.ySize

	for i, child in ipairs(self.Children) do
		child:Measure()
	end
end

function UI.Window:Arrange(xSize, ySize)
	local s = self.style

	self.Frame:SetSize(xSize, ySize)
	self.Frame:SetBackdrop({
		bgFile   = s.backgroundTexture,
		edgeFile = s.backgroundTexture,
		edgeSize = s.borderSize })
	self.Frame:SetBackdropColor(s.backgroundColor:GetRGBA())
	self.Frame:SetBackdropBorderColor(s.borderColor:GetRGBA())

	self.Close.Region:SetPointsOffset(-s.padSize, -s.padSize)
	self.Stack.Region:SetPointsOffset(s.padSize, -(s.padSize + s.yContentOffset))

	for i, child in ipairs(self.Children) do
		child:Arrange(child.xSize, child.ySize)
	end
end

----------------------------------------------------------------------------------------------------
-- Stack

UI.Stack = setmetatable({}, { __index = UI.Component })
UI.Stack.__index = UI.Stack

function UI.Stack.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Stack)
	self.style = Config.GetBranch(cfgTree, args.styleName or "Stack")

	-- TODO: Remove backdrop
	self.Frame = CreateFrame("Frame", nil, parent.Region, "BackdropTemplate")
	self.Frame:SetBackdrop({ bgFile = self.style.backgroundTexture })
	self.Frame:SetBackdropColor(1, 1, 1, 0.5)
	self.Frame:SetParentKey(args.name)

	self.Region = self.Frame
	self.Children = {}
	table.insert(parent.Children, self)
	return self
end

function UI.Stack:Measure()
	local s = self.style

	local xDir = 0
	local yDir = 1
	local xSize = 0
	local ySize = 0
	local gapCount = max(0, #self.Children - 1)

	for i, child in ipairs(self.Children) do
		child:Measure()
		xSize = max(xSize, child.xSize)
		ySize = ySize + child.ySize
	end
	xSize = xSize + (s.gapSize * gapCount) * xDir
	ySize = ySize + (s.gapSize * gapCount) * yDir

	self.xSize = xSize
	self.ySize = ySize
end

function UI.Stack:Arrange(xSize, ySize)
	local s = self.style
	self.Frame:SetSize(xSize, ySize)

	local xDir = 0
	local yDir = 1
	local xOffset = 0
	local yOffset = 0

	for i, child in ipairs(self.Children) do
		child.Region:SetPointsOffset(xOffset, -yOffset)
		child:Arrange(child.xSize, child.ySize)

		xOffset = xOffset + (child.xSize + s.gapSize) * xDir
		yOffset = yOffset + (child.ySize + s.gapSize) * yDir
	end
end

----------------------------------------------------------------------------------------------------
-- Label

UI.Label = setmetatable({}, { __index = UI.Component })
UI.Label.__index = UI.Label

function UI.Label.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Label)
	self.style = Config.GetBranch(cfgTree, args.styleName or "Label")

	self.Text = parent.Region:CreateFontString(nil, "ARTWORK")
	self.Text:SetParentKey(args.name)
	self.Text:SetFontObject(self.style.font.object)
	self.Text:SetText(args.text)

	self.Region = self.Text
	self.Children = {}
	table.insert(parent.Children, self)
	return self
end

-- TODO: How do we handle wrapping?
-- * Maybe pass max size into measure?
-- * Maybe Arrange returns the actual size?
function UI.Label:Measure()
	self.xSize = self.Text:GetUnboundedStringWidth()
	self.ySize = self.Text:GetStringHeight()
end

function UI.Label:Arrange(xSize, ySize)
	self.Text:SetSize(xSize, ySize)
end

----------------------------------------------------------------------------------------------------
-- IconButton

UI.IconButton = setmetatable({}, { __index = UI.Component })
UI.IconButton.__index = UI.IconButton

function UI.IconButton.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.IconButton)
	self.style = Config.GetBranch(cfgTree, args.styleName or "IconButton")

	self.Button = CreateFrame("Button", nil, parent.Region, "BackdropTemplate")
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
	self.FontString:SetPoint("TOPLEFT")

	self.Region = self.Button
	self.Children = {}
	table.insert(parent.Children, self)
	return self
end

function UI.IconButton:Measure()
	local s = self.style
	local buttonSize = Util.SameParity(s.font.size, s.xSize)

	self.xSize = buttonSize
	self.ySize = buttonSize
end

function UI.IconButton:Arrange(xSize, ySize)
	local s = self.style
	local xOffset, yOffset = Util.CenterIcon(s.font.info, xSize, ySize, s.font.size)

	self.Button:SetSize(xSize, ySize)
	self.Button:SetBackdrop({
		bgFile   = s.backgroundTexture,
		edgeFile = s.backgroundTexture,
		edgeSize = s.borderSize,
		insets   = { left = s.borderSize, right = s.borderSize, top = s.borderSize, bottom = s.borderSize } })
	self.Button:SetBackdropColor(s.backgroundColor:GetRGBA())
	self.Button:SetBackdropBorderColor(s.borderColor:GetRGBA())

	local ht = self.Button:GetHighlightTexture()
	ht:SetPoint("TOPLEFT",      s.borderSize, -s.borderSize)
	ht:SetPoint("BOTTOMRIGHT", -s.borderSize,  s.borderSize)

	self.FontString:SetPointsOffset(xOffset, yOffset)
end

----------------------------------------------------------------------------------------------------
-- File Load

UI.Load()

-- TODO: Maybe the hierarchy should split Containers and Widgets?
-- TODO: Consider a declarative UI builder
