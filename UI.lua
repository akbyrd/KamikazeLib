local Kami = select(2, ...)
local UI = {}
Kami.UI = UI

local Config = Kami.Config
local Util   = Kami.Util

-- NOTE: We assume cfg doesn't change. We don't dynamically re-apply state. Only scale fix-ups.
-- NOTE: We assume frames are not re-anchored unexpectedly. No unnecessary ClearAllPoints.
-- NOTE: The caller is responsible for anchoring, not Create (unless it's an internal component).
-- NOTE: SetPointsOffset is used for positioning to avoid repeating anchors.
-- NOTE: Arrange may pass a larger size, but never a smaller size.

----------------------------------------------------------------------------------------------------
-- Constants

UI.NO_LIMIT = math.huge

----------------------------------------------------------------------------------------------------
-- Root

function UI.Load()
	UI.Root = {}
	UI.Root.Region = CreateFrame("Frame", nil, UIParent)
	UI.Root.Region:SetParentKey("KAMI_UI_ROOT")
	UI.Root.Region:SetAllPoints()
end

-- TODO: All 3 passes and recurse?
function UI.RefreshScale()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
	UI.Root.Region:SetScale(pixelsToUI)
end

----------------------------------------------------------------------------------------------------
-- Component

UI.Component = {
	xStretch = 0,
	yStretch = 0,
	xAlign   = 0,
	yAlign   = 0,
}
UI.Component.__index = UI.Component

function UI.Component:Place(xCellPos, yCellPos, xCellSize, yCellSize)
	self.xSize = Round(self.xSize + max(0, xCellSize - self.xSize) * self.xStretch)
	self.ySize = Round(self.ySize + max(0, yCellSize - self.ySize) * self.yStretch)
	self:ConstrainSize()
	self.Region:SetSize(self.xSize, self.ySize)

	self.xPos = Round(xCellPos + max(0, xCellSize - self.xSize) * self.xAlign)
	self.yPos = Round(yCellPos - max(0, yCellSize - self.ySize) * self.yAlign)
	self.Region:SetPointsOffset(self.xPos, self.yPos)
end

function UI.Component:ConstrainSize()
end

function UI.AdjustString(string, xPos, yPos)
	-- NOTE: Strings have their position floored to pixel positions before rendering. Floating point
	-- noise from the scale chain causes tiny shifts above and below the desired integer value. A
	-- half pixel offset turns the floor into a round. This fixes the position jitter visible on
	-- strings, which is most obvious during dragging. Textures round and don't need the same fix. We
	-- do this as a separate step and don't modify the stored position because we don't want the
	-- rendering fix to infect other layout concerns.
	string:SetPointsOffset(xPos + 0.5, yPos + 0.5)
end

----------------------------------------------------------------------------------------------------
-- Window

UI.Window = setmetatable({}, { __index = UI.Component })
UI.Window.__index = UI.Window

function UI.Window.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Window)
	self.style    = Config.GetBranch(cfgTree, args.styleName or "Window")
	self.xAlign   = args.xAlign
	self.yAlign   = args.yAlign
	self.xStretch = args.xStretch
	self.yStretch = args.yStretch

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

	self.Title = UI.Label.Create(self, cfgTree,
		{
			name      = "Title",
			styleName = "Title",
			text      = args.name,
		})
	self.Title.Region:SetPoint("TOPLEFT")

	self.Close = UI.IconButton.Create(self, cfgTree,
		{
			name      = "Close",
			styleName = "CloseButton",
			glyph     = 0xE5CD,
			onClick   = function() self.Frame:Hide() end,
			xAlign    = 1,
		})
	self.Close.Region:SetPoint("TOPLEFT")

	self.Content = nil
	return self
end

function UI.Window:Measure(xTargetSize, yTargetSize)
	local s = self.style

	self.Title:Measure(UI.NO_LIMIT, UI.NO_LIMIT)
	self.Close:Measure(UI.NO_LIMIT, UI.NO_LIMIT)

	local cxTargetSize = s.xSize - 2 * s.padSize
	local cyTargetSize = s.ySize - 3 * s.padSize - self.Close.ySize
	self.Content:Measure(cxTargetSize, cyTargetSize)

	self.xSize = s.xSize
	self.ySize = s.ySize
end

function UI.Window:Arrange(xCellPos, yCellPos, xCellSize, yCellSize)
	local s = self.style

	self.Frame:SetSize(self.xSize, self.ySize)
	self.Frame:SetBackdrop({
		bgFile   = s.backgroundTexture,
		edgeFile = s.backgroundTexture,
		edgeSize = s.borderSize })
	self.Frame:SetBackdropColor(s.backgroundColor:GetRGBA())
	self.Frame:SetBackdropBorderColor(s.borderColor:GetRGBA())

	local xPos  = s.padSize
	local xSize = self.xSize - 2 * s.padSize

	local yTitlePos  = -s.padSize
	local yTitleSize = self.Title.ySize
	self.Title:Arrange(xPos, yTitlePos, xSize, yTitleSize)

	local yCloseSize = self.Close.ySize
	self.Close:Arrange(xPos, yTitlePos, xSize, yCloseSize)

	local yHeaderSize  = max(yTitleSize, yCloseSize)
	local yContentPos  = 0          - 2 * s.padSize - yHeaderSize
	local yContentSize = self.ySize - 3 * s.padSize - yHeaderSize
	self.Content:Arrange(xPos, yContentPos, xSize, yContentSize)
end

----------------------------------------------------------------------------------------------------
-- Row

UI.Row = setmetatable({}, { __index = UI.Component })
UI.Row.__index = UI.Row

function UI.Row.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Row)
	self.style    = Config.GetBranch(cfgTree, args.styleName or "Row")
	self.xAlign   = args.xAlign
	self.yAlign   = args.yAlign
	self.xStretch = args.xStretch
	self.yStretch = args.yStretch

	self.Frame = CreateFrame("Frame", nil, parent.Region)
	self.Frame:SetParentKey(args.name)

	self.Region = self.Frame

	self.Label = UI.Label.Create(self, cfgTree,
		{
			name   = "Label",
			text   = args.text,
			yAlign = 0.5,
		})
	self.Label.Region:SetPoint("TOPLEFT")
	self.Content = nil
	return self
end

function UI.Row:Measure(xTargetSize, yTargetSize)
	local s = self.style

	self.Label:Measure(s.labelWidth, yTargetSize)
	self.Content:Measure(xTargetSize - s.labelWidth, yTargetSize)

	self.xSize = s.labelWidth + self.Content.xSize
	self.ySize = max(s.ySize, self.Label.ySize, self.Content.ySize)
end

function UI.Row:Arrange(xCellPos, yCellPos, xCellSize, yCellSize)
	local s = self.style
	self:Place(xCellPos, yCellPos, xCellSize, yCellSize)

	self.Label:Arrange(0, 0, s.labelWidth, self.ySize)
	self.Content:Arrange(s.labelWidth, 0, self.xSize - s.labelWidth, self.ySize)
end

----------------------------------------------------------------------------------------------------
-- Stack

UI.Stack = setmetatable({}, { __index = UI.Component })
UI.Stack.__index = UI.Stack

function UI.Stack.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Stack)
	self.style    = Config.GetBranch(cfgTree, args.styleName or "Stack")
	self.xAlign   = args.xAlign
	self.yAlign   = args.yAlign
	self.xStretch = args.xStretch
	self.yStretch = args.yStretch

	self.Frame = CreateFrame("Frame", nil, parent.Region)
	self.Frame:SetParentKey(args.name)

	self.Region = self.Frame
	self.Children = {}
	self.xDir = args.xDir or 0
	self.yDir = args.yDir or 1
	return self
end

function UI.Stack:Measure(xTargetSize, yTargetSize)
	local s = self.style

	xTargetSize = self.xDir == 0 and xTargetSize or UI.NO_LIMIT
	yTargetSize = self.yDir == 0 and yTargetSize or UI.NO_LIMIT

	self.xSize = 0
	self.ySize = 0

	local xLargest = 0
	local yLargest = 0

	for i, child in ipairs(self.Children) do
		child:Measure(xTargetSize, yTargetSize)
		xLargest = max(xLargest, child.xSize)
		yLargest = max(yLargest, child.ySize)

		self.xSize = self.xSize + child.xSize
		self.ySize = self.ySize + child.ySize
	end

	local gapSize = s.gapSize * max(0, #self.Children - 1)
	self.xSize = self.xDir ~= 0 and self.xSize + gapSize or xLargest
	self.ySize = self.yDir ~= 0 and self.ySize + gapSize or yLargest
end

function UI.Stack:Arrange(xCellPos, yCellPos, xCellSize, yCellSize)
	local s = self.style
	self:Place(xCellPos, yCellPos, xCellSize, yCellSize)

	local cxPos  = 0
	local cyPos  = 0

	for i, child in ipairs(self.Children) do
		local cxSize = self.xDir ~= 0 and child.xSize or self.xSize
		local cySize = self.yDir ~= 0 and child.ySize or self.ySize
		child:Arrange(cxPos, cyPos, cxSize, cySize)

		cxPos = cxPos + (child.xSize + s.gapSize) * self.xDir
		cyPos = cyPos - (child.ySize + s.gapSize) * self.yDir
	end
end

----------------------------------------------------------------------------------------------------
-- Label

UI.Label = setmetatable({}, { __index = UI.Component })
UI.Label.__index = UI.Label

function UI.Label.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.Label)
	self.style    = Config.GetBranch(cfgTree, args.styleName or "Label")
	self.xAlign   = args.xAlign
	self.yAlign   = args.yAlign
	self.xStretch = args.xStretch
	self.yStretch = args.yStretch

	self.Text = parent.Region:CreateFontString(nil, "ARTWORK")
	self.Text:SetParentKey(args.name)
	self.Text:SetFontObject(self.style.font.object)
	self.Text:SetText(args.text)

	self.Region = self.Text
	return self
end

function UI.Label:Measure(xTargetSize, yTargetSize)
	-- NOTE: There's no way to measure wrapping without mutating the string.
	self.Text:SetWidth(xTargetSize == UI.NO_LIMIT and 0 or xTargetSize)

	self.xSize = min(xTargetSize, self.Text:GetUnboundedStringWidth())
	self.ySize = self.Text:GetStringHeight()
end

function UI.Label:Arrange(xCellPos, yCellPos, xCellSize, yCellSize)
	self:Place(xCellPos, yCellPos, xCellSize, yCellSize)
	UI.AdjustString(self.Text, self.xPos, self.yPos)
end

----------------------------------------------------------------------------------------------------
-- IconButton

UI.IconButton = setmetatable({}, { __index = UI.Component })
UI.IconButton.__index = UI.IconButton

function UI.IconButton.Create(parent, cfgTree, args)
	local self = setmetatable({}, UI.IconButton)
	self.style    = Config.GetBranch(cfgTree, args.styleName or "IconButton")
	self.xAlign   = args.xAlign
	self.yAlign   = args.yAlign
	self.xStretch = args.xStretch
	self.yStretch = args.yStretch

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
	self.FontString:ClearAllPoints()
	self.FontString:SetPoint("TOPLEFT")

	self.Region = self.Button
	return self
end

function UI.IconButton:ConstrainSize()
	local s = self.style
	self.xSize = Util.SameParity(s.font.size, self.xSize)
	self.ySize = Util.SameParity(s.font.size, self.ySize)
end

function UI.IconButton:Measure(xTargetSize, yTargetSize)
	local s = self.style
	self.xSize = s.xSize
	self.ySize = s.ySize
	self:ConstrainSize()
end

function UI.IconButton:Arrange(xCellPos, yCellPos, xCellSize, yCellSize)
	local s = self.style
	self:Place(xCellPos, yCellPos, xCellSize, yCellSize)

	local xPos, yPos = Util.CenterIcon(s.font.info, self.xSize, self.ySize, s.font.size)
	UI.AdjustString(self.FontString, xPos, yPos)

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
end

----------------------------------------------------------------------------------------------------
-- File Load

UI.Load()

-- TODO: Try nil for NO_LIMIT
-- TODO: Maybe the hierarchy should split Containers and Widgets?
-- TODO: Consider a declarative UI builder
