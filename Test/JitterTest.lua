local Kami = select(2, ...)
local JitterTest = {}
Kami.JitterTest = JitterTest

-- NOTE: Learning-mode harness for the text jitter. Three windows. A and B have the same cells: A has
-- the framework's structure (scaled root, unscaled window), B has Sourcery's (UIParent, no scale,
-- sizes in UI units). Each cell draws a 1 px green box at an integer pixel position and the same
-- string inset from the box by a sub-pixel offset. C asks whether a string's snapped x depends on its
-- y: four columns of strings that share one x anchor per column and differ only in y, creation order
-- or font object. Drag any window to compare cells by eye. Run steps all three through the offsets in
-- STEPS, takes a screenshot at each, and records every C string's engine position in KLSavedVars
-- (written to disk at the next reload). The screenshots and the saved variables are measured offline.

local X0      = 1400   -- window A top-left, pixels from the screen's top-left
local Y0      = 200
local TITLE_Y = 56     -- title row and column header row
local LABEL_X = 90     -- row label column
local PAD     = 10
local CELL_X  = 120
local CELL_Y  = 40
local BOX_X   = 100
local BOX_Y   = 28
local INSET_X = 8      -- text inset from the box, pixels
local INSET_Y = 4
local OFFSETS = { 0, 0.25, 0.5, 0.75 }             -- text offset from its inset, pixels, x and y
local STEPS   = { 0, 0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7, 8 }   -- window offset per screenshot, pixels
local SWEEP   = 16     -- rows in window C; row k puts its string k/16 px below the row's inset

local LSM   = LibStub("LibSharedMedia-3.0")
local FONTS = {
	{ name = "PTSans18",  path = LSM:Fetch("font", "PT Sans Narrow", true) or "Fonts\\ARIALN.TTF", size = 18, text = "Hello", shadow = true },
	{ name = "Friz20",    path = "Fonts\\FRIZQT__.TTF", size = 20, text = "Hello" },
	{ name = "ArialN14",  path = "Fonts\\ARIALN.TTF",   size = 14, text = "Hello" },
	{ name = "Symbol24",  path = "Interface\\AddOns\\KamikazeLib\\Media\\MaterialSymbolsSharp-Regular.ttf", size = 24, text = Kami.Util.Utf8(0xE5CD) },
}

-- Window C columns: P rows only, Q rows plus k/16 px, R as Q but created last row first, S as P with
-- a font object per cell
local SWEEP_COLUMNS = {
	{ name = "P rows",     fraction = false, reverse = false, ownFont = false },
	{ name = "Q k/16",     fraction = true,  reverse = false, ownFont = false },
	{ name = "R reversed", fraction = true,  reverse = true,  ownFont = false },
	{ name = "S own font", fraction = false, reverse = false, ownFont = true  },
}

local X_SIZE = 2 * PAD + LABEL_X + #OFFSETS * #OFFSETS * CELL_X
local Y_SIZE = 2 * PAD + TITLE_Y + #FONTS * CELL_Y
local X_SIZE_C = 2 * PAD + LABEL_X + #SWEEP_COLUMNS * CELL_X
local Y_SIZE_C = 2 * PAD + TITLE_Y + SWEEP * CELL_Y

-- NOTE: BackdropTemplate draws its centre fill on the BORDER layer, so the cell textures sit on
-- ARTWORK below the string (sublevel 0).
local function CreateCell(frame, unit, object, text, cx, cy, dx, dy)
	local box = frame:CreateTexture(nil, "ARTWORK", nil, -2)
	box:SetColorTexture(0, 1, 0, 1)
	box:SetPoint("TOPLEFT", cx * unit, -cy * unit)
	box:SetSize(BOX_X * unit, BOX_Y * unit)

	local fill = frame:CreateTexture(nil, "ARTWORK", nil, -1)
	fill:SetColorTexture(0.11, 0.11, 0.11, 1)
	fill:SetPoint("TOPLEFT", (cx + 1) * unit, -(cy + 1) * unit)
	fill:SetSize((BOX_X - 2) * unit, (BOX_Y - 2) * unit)

	local string = frame:CreateFontString(nil, "ARTWORK")
	string:SetFontObject(object)
	string:SetJustifyH("LEFT")
	string:SetJustifyV("TOP")
	string:SetText(text)
	string:SetPoint("TOPLEFT", (cx + INSET_X + dx) * unit, -(cy + INSET_Y + dy) * unit)
	return string
end

local function CreateLabel(frame, unit, object, text, x, y)
	local string = frame:CreateFontString(nil, "ARTWORK")
	string:SetFontObject(object)
	string:SetJustifyH("LEFT")
	string:SetJustifyV("TOP")
	string:SetText(text)
	string:SetPoint("TOPLEFT", x * unit, -y * unit)
end

local function CreateButton(frame, unit, object, text, xRight, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(80 * unit, 22 * unit)
	button:SetPoint("TOPRIGHT", -xRight * unit, -(PAD - 2) * unit)
	button:SetNormalFontObject(object)
	button:SetHighlightFontObject(object)
	button:SetDisabledFontObject(object)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
end

local function CreateFontObject(name, font, unit)
	local object = CreateFont(name)
	object:SetFont(font.path, font.size * unit, "")
	object:SetTextColor(1, 1, 1, 1)
	if font.shadow then
		object:SetShadowColor(0, 0, 0, 1)
		object:SetShadowOffset(unit, -unit)
	end
	return object
end

local function Move(frame, step)
	local unit = frame.unit
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", (X0 + step) * unit, -(frame.y0 + step) * unit)
end

local function HideAll()
	JitterTest.A:Hide()
	JitterTest.B:Hide()
	JitterTest.C:Hide()
end

local function CreateChrome(name, parent, unit, y0, xSize, ySize, title)
	local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
	frame.unit = unit
	frame.y0   = y0
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetSize(xSize * unit, ySize * unit)
	frame:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = unit })
	frame:SetBackdropColor(0.11, 0.11, 0.11, 1)
	frame:SetBackdropBorderColor(1, 1, 1, 0.25)
	Move(frame, 0)

	local ui = CreateFont(name .. "UI")
	ui:SetFont("Fonts\\FRIZQT__.TTF", 14 * unit, "")
	ui:SetTextColor(1, 0.82, 0, 1)
	frame.ui = ui

	CreateLabel(frame, unit, ui, title, PAD, PAD)
	CreateButton(frame, unit, ui, "Step",  PAD + 180, function() JitterTest.Run(false) end)
	CreateButton(frame, unit, ui, "Run",   PAD + 90,  function() JitterTest.Run(true) end)
	CreateButton(frame, unit, ui, "Close", PAD,       HideAll)
	return frame
end

local function CreateWindow(name, parent, unit, y0, title)
	local frame = CreateChrome(name, parent, unit, y0, X_SIZE, Y_SIZE, title)

	local iCol = 0
	for iX, dx in ipairs(OFFSETS) do
		for iY, dy in ipairs(OFFSETS) do
			local cx = PAD + LABEL_X + iCol * CELL_X
			CreateLabel(frame, unit, frame.ui, ("x %.2f  y %.2f"):format(dx, dy), cx, PAD + 32)
			iCol = iCol + 1
		end
	end

	for iFont, font in ipairs(FONTS) do
		local object = CreateFontObject(name .. font.name, font, unit)
		local cy = PAD + TITLE_Y + (iFont - 1) * CELL_Y
		CreateLabel(frame, unit, frame.ui, font.name, PAD, cy + INSET_Y)

		iCol = 0
		for iX, dx in ipairs(OFFSETS) do
			for iY, dy in ipairs(OFFSETS) do
				local cx = PAD + LABEL_X + iCol * CELL_X
				CreateCell(frame, unit, object, font.text, cx, cy, dx, dy)
				iCol = iCol + 1
			end
		end
	end

	return frame
end

local function CreateSweepWindow(name, parent, unit, y0, title)
	local frame = CreateChrome(name, parent, unit, y0, X_SIZE_C, Y_SIZE_C, title)
	frame.cells = {}

	local font   = FONTS[3]
	local shared = CreateFontObject(name .. font.name, font, unit)

	for iRow = 1, SWEEP do
		local cy = PAD + TITLE_Y + (iRow - 1) * CELL_Y
		CreateLabel(frame, unit, frame.ui, ("k=%d"):format(iRow - 1), PAD, cy + INSET_Y)
	end

	for iCol, column in ipairs(SWEEP_COLUMNS) do
		local cx = PAD + LABEL_X + (iCol - 1) * CELL_X
		CreateLabel(frame, unit, frame.ui, column.name, cx, PAD + 32)

		for iCreate = 1, SWEEP do
			local iRow = column.reverse and SWEEP + 1 - iCreate or iCreate
			local k    = iRow - 1
			local cy   = PAD + TITLE_Y + k * CELL_Y
			local dy   = column.fraction and k / SWEEP or 0
			local cell = ("%s%02d"):format(column.name:sub(1, 1), k)
			local object = column.ownFont and CreateFontObject(name .. cell, font, unit) or shared
			frame.cells[cell] = CreateCell(frame, unit, object, font.text, cx, cy, 0, dy)
		end
	end

	return frame
end

-- Every C string's position as the engine stores it, in the string's own units
local function RecordSweep(step)
	local record = { offset = step, cells = {} }
	for cell, string in pairs(JitterTest.C.cells) do
		local left, top = string:GetLeft(), string:GetTop()
		record.cells[cell] = { left = left, top = top, scale = string:GetEffectiveScale() }
	end
	table.insert(KLSavedVars.JitterTest.steps, record)
end

-- screenshots - take one per step and print the positions; false steps for the eye only
function JitterTest.Run(screenshots)
	local iStep = 0
	local function Next()
		iStep = iStep + 1
		local step = STEPS[iStep]
		if not step then
			print("JitterTest: done")
			return
		end

		Move(JitterTest.A, step)
		Move(JitterTest.B, step)
		Move(JitterTest.C, step)
		if not screenshots then
			C_Timer.After(0.8, Next)
			return
		end

		C_Timer.After(0.25, function()
			local aLeft = JitterTest.A:GetLeft()
			local bLeft = JitterTest.B:GetLeft() / JitterTest.B.unit
			local cLeft = JitterTest.C:GetLeft() / JitterTest.C.unit
			print(("JitterTest: step %d offset %.2f A left %.6f B left %.6f C left %.6f"):format(iStep, step, aLeft, bLeft, cLeft))
			RecordSweep(step)
			Screenshot()
			C_Timer.After(1.25, Next)
		end)
	end

	local screenX, screenY = GetPhysicalScreenSize()
	if screenshots then
		KLSavedVars.JitterTest = {
			started = date("%Y-%m-%d %H:%M:%S"),
			screen  = { screenX, screenY },
			uiScale = UIParent:GetEffectiveScale(),
			factor  = PixelUtil.GetPixelToUIUnitFactor(),
			steps   = {},
		}
	end
	print(("JitterTest: run started %s, %d steps, screenshots %s, screen %dx%d, UIParent scale %.8f"):format(
		date("%H:%M:%S"), #STEPS, tostring(screenshots), screenX, screenY, UIParent:GetEffectiveScale()))
	Next()
end

-- NOTE: The UI scale is applied after addon files load, so the windows are built on
-- PLAYER_ENTERING_WORLD and rebuilt if the scale changes. B and C bake the scale into their sizes.
function JitterTest.Load()
	local pixelsToUI = PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()

	if JitterTest.A then
		HideAll()
	end

	JitterTest.Root = JitterTest.Root or CreateFrame("Frame", "KamiJitterTestRoot", UIParent)
	JitterTest.Root:SetAllPoints()
	JitterTest.Root:SetScale(pixelsToUI)

	local yB = Y0 + Y_SIZE + 60
	local yC = yB + Y_SIZE + 60
	JitterTest.A = CreateWindow(     "KamiJitterTestA", JitterTest.Root, 1,          Y0, "Jitter test A: scaled root")
	JitterTest.B = CreateWindow(     "KamiJitterTestB", UIParent,        pixelsToUI, yB, "Jitter test B: no scale, UI units")
	JitterTest.C = CreateSweepWindow("KamiJitterTestC", UIParent,        pixelsToUI, yC, "Jitter test C: one x anchor per column, y sweep")

	local screenX, screenY = GetPhysicalScreenSize()
	print(("JitterTest: screen %dx%d, UIParent scale %.8f, pixels to UI %.8f, A left %.6f, B left %.6f"):format(
		screenX, screenY, UIParent:GetEffectiveScale(), pixelsToUI, JitterTest.A:GetLeft(), JitterTest.B:GetLeft() / pixelsToUI))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(self, event)
	print("JitterTest: building on " .. event)
	JitterTest.Load()
end)
