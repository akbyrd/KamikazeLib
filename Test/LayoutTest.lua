local Kami = select(2, ...)
local LayoutTest = {}
Kami.LayoutTest = LayoutTest

local UI  = Kami.UI
local LSM = LibStub("LibSharedMedia-3.0")

-- NOTE: The harness places its own frames rather than using the framework's containers, so the only
-- thing being exercised is one stack per case. Each case gets a cell (red) of a fixed size, a stack
-- (green) arranged into exactly that rect, and its boxes (blue) carrying their stretch and align.

local PAD      = 16
local TITLE_Y  = 24
local HEADER_Y = 26
local ROW_Y    = 30
local LABEL_X  = 150
local CELL_X   = 400
local GAP_X    = 24
local COLUMN_X = LABEL_X + CELL_X + GAP_X
local BOX_X    = 48
local BOX_Y    = 24

-- { header, { { name, { { stretch, align }, ... } }, ... } }
local COLUMNS = {
	{ "1 item", {
		{ "align 0",              { { 0, 0    } } },
		{ "align .25",            { { 0, 0.25 } } },
		{ "align .33",            { { 0, 0.33 } } },
		{ "align .5",             { { 0, 0.5  } } },
		{ "align .67",            { { 0, 0.67 } } },
		{ "align .75",            { { 0, 0.75 } } },
		{ "align 1",              { { 0, 1    } } },
		{ "stretch 0",            { { 0,   0 } } },
		{ "stretch .5",           { { 0.5, 0 } } },
		{ "stretch 1",            { { 1,   0 } } },
		{ "stretch .5 align .5",  { { 0.5, 0.5 } } },
		{ "stretch .5 align 1",   { { 0.5, 1   } } },
	} },
	{ "2 items", {
		{ "align 0/1",            { { 0, 0    }, { 0, 1    } } },
		{ "align .2/.8",          { { 0, 0.2  }, { 0, 0.8  } } },
		{ "align .25/.75",        { { 0, 0.25 }, { 0, 0.75 } } },
		{ "align .33/.67",        { { 0, 0.33 }, { 0, 0.67 } } },
		{ "align .5/.5",          { { 0, 0.5  }, { 0, 0.5  } } },
		{ "align .5/.7",          { { 0, 0.5  }, { 0, 0.7  } } },
		{ "align .6/.7",          { { 0, 0.6  }, { 0, 0.7  } } },
		{ "align .6/.4",          { { 0, 0.6  }, { 0, 0.4  } } },
		{ "align 0/0",            { { 0, 0    }, { 0, 0    } } },
		{ "align 1/1",            { { 0, 1    }, { 0, 1    } } },
		{ "stretch 0/0",          { { 0,   0 }, { 0,   0 } } },
		{ "stretch .5/.5",        { { 0.5, 0 }, { 0.5, 0 } } },
		{ "stretch 1/1",          { { 1,   0 }, { 1,   0 } } },
		{ "stretch 1/0",          { { 1,   0 }, { 0,   0 } } },
		{ "stretch 0/1",          { { 0,   0 }, { 1,   0 } } },
		{ "stretch 2/1",          { { 2,   0 }, { 1,   0 } } },
		{ "str .5/0 al 0/0",      { { 0.5, 0 }, { 0, 0 } } },
		{ "str .5/0 al 0/1",      { { 0.5, 0 }, { 0, 1 } } },
		{ "str .5/.5 al .5/.5",   { { 0.5, 0.5 }, { 0.5, 0.5 } } },
	} },
	{ "3 items", {
		{ "align 0/.5/1",         { { 0, 0    }, { 0, 0.5 }, { 0, 1    } } },
		{ "align .25/.5/.75",     { { 0, 0.25 }, { 0, 0.5 }, { 0, 0.75 } } },
		{ "align .5/.5/.5",       { { 0, 0.5  }, { 0, 0.5 }, { 0, 0.5  } } },
		{ "align 0/0/1",          { { 0, 0    }, { 0, 0   }, { 0, 1    } } },
		{ "align 1/1/1",          { { 0, 1    }, { 0, 1   }, { 0, 1    } } },
		{ "align 1/0/1",          { { 0, 1    }, { 0, 0   }, { 0, 1    } } },
		{ "stretch 0/0/0",        { { 0,    0 }, { 0,    0 }, { 0,    0 } } },
		{ "stretch .5/.5/.5",     { { 0.5,  0 }, { 0.5,  0 }, { 0.5,  0 } } },
		{ "stretch 1/1/1",        { { 1,    0 }, { 1,    0 }, { 1,    0 } } },
		{ "stretch 1/0/0",        { { 1,    0 }, { 0,    0 }, { 0,    0 } } },
		{ "stretch 0/.5/1",       { { 0,    0 }, { 0.5,  0 }, { 1,    0 } } },
		{ "stretch .25/.25/.25",  { { 0.25, 0 }, { 0.25, 0 }, { 0.25, 0 } } },
		{ "str .5/0/0 al 0/.5/1", { { 0.5, 0 }, { 0, 0.5 }, { 0, 1 } } },
	} },
}


----------------------------------------------------------------------------------------------------
-- Box: a fixed-size component with a visible border and its own stretch and align written on it

local Box = setmetatable({}, { __index = UI.Component })
Box.__index = Box

function Box.Create(parent, font, xStretch, xAlign)
	local self = setmetatable({}, Box)
	self.xStretch = xStretch
	self.xAlign   = xAlign

	self.Frame = CreateFrame("Frame", nil, parent.Region, "BackdropTemplate")
	self.Frame:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1 })
	self.Frame:SetBackdropColor(0.2, 0.4, 0.8, 0.35)
	self.Frame:SetBackdropBorderColor(0.4, 0.7, 1, 1)

	self.Text = self.Frame:CreateFontString(nil, "ARTWORK")
	self.Text:SetFontObject(font)
	self.Text:SetAllPoints()
	self.Text:SetPointsOffset(0.5, 0.5)
	self.Text:SetText(("%g/%g"):format(xStretch, xAlign))

	self.Region = self.Frame
	return self
end

function Box:Measure(xTargetSize, yTargetSize)
	self.xSize = BOX_X
	self.ySize = BOX_Y
end

----------------------------------------------------------------------------------------------------

local EDGES = {
	{ "TOPLEFT",    "TOPRIGHT",    0, 1 },
	{ "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
	{ "TOPLEFT",    "BOTTOMLEFT",  1, 0 },
	{ "TOPRIGHT",   "BOTTOMRIGHT", 1, 0 },
}

-- NOTE: A child frame draws over every texture of its parent, so an outline on the parent would be
-- hidden by a child that fills it. The edges go on an overlay frame above both.
local function ShowRect(frame, r, g, b)
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
	overlay:SetAllPoints()

	for iEdge, edge in ipairs(EDGES) do
		local line = overlay:CreateTexture(nil, "OVERLAY")
		line:SetColorTexture(r, g, b, 1)
		line:SetPoint(edge[1])
		line:SetPoint(edge[2])
		line:SetSize(edge[3], edge[4])
	end
end

local function CreateText(parent, font, text, xPos, yPos)
	local string = parent:CreateFontString(nil, "ARTWORK")
	string:SetFontObject(font)
	string:SetJustifyH("LEFT")
	string:SetJustifyV("TOP")
	string:SetText(text)
	-- The framework's labels are offset half a pixel off the grid; these are placed by hand, so they
	-- need the same treatment or they jitter while the window is dragged
	string:SetPoint("TOPLEFT", xPos + 0.5, -yPos + 0.5)
	return string
end

function LayoutTest.Load()
	local caseCount = 0
	for iColumn, column in ipairs(COLUMNS) do
		caseCount = max(caseCount, #column[2])
	end

	local xSize = 2 * PAD + #COLUMNS * COLUMN_X - GAP_X
	local ySize = 2 * PAD + TITLE_Y + HEADER_Y + caseCount * ROW_Y

	local font = CreateFont("KamiLayoutTestFont")
	font:SetFont(LSM:Fetch("font", "PT Sans Narrow", true) or "Fonts\\ARIALN.TTF", 14, "")
	font:SetTextColor(1, 1, 1, 1)

	local titleFont = CreateFont("KamiLayoutTestTitleFont")
	titleFont:SetFont(LSM:Fetch("font", "PT Sans Narrow", true) or "Fonts\\ARIALN.TTF", 18, "")
	titleFont:SetTextColor(1, 0.82, 0, 1)

	local window = CreateFrame("Frame", "KamiLayoutTest", UI.Root.Region, "BackdropTemplate")
	window:SetParentKey("LayoutTest")
	window:SetFrameStrata("HIGH")
	window:SetToplevel(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	window:SetSize(xSize, ySize)
	window:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1 })
	window:SetBackdropColor(0.11, 0.11, 0.11, 0.98)
	window:SetBackdropBorderColor(1, 1, 1, 0.25)

	local screenX, screenY = GetPhysicalScreenSize()
	window:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", Round((screenX - xSize) / 2), Round((screenY + ySize) / 2))
	CreateText(window, titleFont, "Layout test", PAD, PAD)

	LayoutTest.Window = window
	LayoutTest.Stacks = {}

	local cfgTree = Kami.Settings.cfgTree
	for iColumn, column in ipairs(COLUMNS) do
		local xColumn = PAD + (iColumn - 1) * COLUMN_X
		CreateText(window, titleFont, column[1], xColumn, PAD + TITLE_Y)

		for iCase, case in ipairs(column[2]) do
			local yCase = PAD + TITLE_Y + HEADER_Y + (iCase - 1) * ROW_Y
			CreateText(window, font, case[1], xColumn, yCase + 4)

			local cell = CreateFrame("Frame", nil, window)
			cell:SetPoint("TOPLEFT", xColumn + LABEL_X, -yCase)
			cell:SetSize(CELL_X, BOX_Y)
			ShowRect(cell, 1, 0.3, 0.3)

			local stack = UI.Stack.Create({ Region = cell }, cfgTree,
				{
					name     = "Stack",
					xDir     = 1,
					yDir     = 0,
					xStretch = 1,
					yStretch = 1,
				})
			stack.Region:SetPoint("TOPLEFT")
			ShowRect(stack.Region, 0.3, 1, 0.3)
			table.insert(LayoutTest.Stacks, stack)

			for iItem, item in ipairs(case[2]) do
				local box = Box.Create(stack, font, item[1], item[2])
				box.Region:SetPoint("TOPLEFT")
				table.insert(stack.Children, box)
			end
		end
	end

	LayoutTest.Refresh()
end

function LayoutTest.Refresh()
	for iStack, stack in ipairs(LayoutTest.Stacks) do
		stack:Measure(CELL_X, BOX_Y)
		stack:Place(0, 0, CELL_X, BOX_Y)
	end
end

----------------------------------------------------------------------------------------------------
-- File Load

LayoutTest.Load()

-- Settings re-resolves the config tree and the root scale on these; the stacks relay out after it
local events = CreateFrame("Frame")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", LayoutTest.Refresh)
hooksecurefunc(UIParent, "SetScale", LayoutTest.Refresh)
