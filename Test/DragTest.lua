local Kami = select(2, ...)

-- Three standalone draggable windows, no framework.
--   A - scaled root, unscaled window inside it, custom font object, text directly on the window
--   B - Sourcery: no scale anywhere, stock font object, pixel sizes converted to UI units
--   C - the framework reproduced: A's structure with the text nested under stack and row frames
--   D - the real settings window reproduced: C plus its font, shadow, alpha, strata and wrapping
--   E - the original test that jittered badly: scale on the frame itself, cursor drag that rounds

local LINE_COUNT = 10
local TEXT       = "The quick brown fox jumps over the lazy dog"
local X_SIZE     = 560
local Y_SIZE     = 290

local function AddBackdrop(frame)
	frame:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1 })
	frame:SetBackdropColor(0.11, 0.11, 0.11, 0.98)
	frame:SetBackdropBorderColor(1, 1, 1, 0.25)
end

local function AddDrag(frame)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
end

local function CreateScaledRoot(name)
	local root = CreateFrame("Frame", name, UIParent)
	root:SetAllPoints()
	root:SetScale(PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale())
	return root
end

----------------------------------------------------------------------------------------------------
-- A: scaled root, text directly on the window

local function CreateWindowA()
	local root  = CreateScaledRoot("KamiDragTestRootA")
	local frame = CreateFrame("Frame", "KamiDragTestA", root, "BackdropTemplate")
	frame:SetSize(X_SIZE, Y_SIZE)
	frame:SetPoint("TOPLEFT", root, "TOPLEFT", 120, -120)
	AddDrag(frame)
	AddBackdrop(frame)

	local font = CreateFont("KamiDragTestFontA")
	font:SetFont("Fonts\\FRIZQT__.TTF", 20, "")
	font:SetTextColor(1, 1, 1, 1)

	for i = 1, LINE_COUNT do
		local text = frame:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font)
		text:SetText(("A %d  %s"):format(i, TEXT))
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10 - (i - 1) * 26)
	end

end

----------------------------------------------------------------------------------------------------
-- B: Sourcery style

local function CreateWindowB()
	local frame = CreateFrame("Frame", "KamiDragTestB", UIParent, "BackdropTemplate")
	local unit  = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()

	frame:SetSize(X_SIZE * unit, Y_SIZE * unit)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 720 * unit, -120 * unit)
	AddDrag(frame)
	AddBackdrop(frame)

	for i = 1, LINE_COUNT do
		local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		text:SetTextColor(1, 1, 1, 1)
		text:SetText(("B %d  %s"):format(i, TEXT))
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 * unit, (-10 - (i - 1) * 26) * unit)
	end

end

----------------------------------------------------------------------------------------------------
-- C: the framework reproduced, text nested under stack and row frames

local function CreateWindowC()
	local root  = CreateScaledRoot("KamiDragTestRootC")
	local frame = CreateFrame("Frame", "KamiDragTestC", root, "BackdropTemplate")
	frame:SetSize(X_SIZE, Y_SIZE)
	frame:SetPoint("TOPLEFT", root, "TOPLEFT", 120, -460)
	AddDrag(frame)
	AddBackdrop(frame)

	local font = CreateFont("KamiDragTestFontC")
	font:SetFont("Fonts\\FRIZQT__.TTF", 20, "")
	font:SetTextColor(1, 1, 1, 1)

	local stack = CreateFrame("Frame", nil, frame)
	stack:SetSize(X_SIZE - 20, Y_SIZE - 20)
	stack:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)

	for i = 1, LINE_COUNT do
		local row = CreateFrame("Frame", nil, stack)
		row:SetSize(X_SIZE - 20, 22)
		row:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, -(i - 1) * 26)

		local text = row:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font)
		text:SetText(("C %d  %s"):format(i, TEXT))
		text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	end

end

----------------------------------------------------------------------------------------------------
-- D: the real settings window reproduced, including its font and frame settings

local function CreateWindowD()
	local root  = CreateScaledRoot("KamiDragTestRootD")
	local frame = CreateFrame("Frame", "KamiDragTestD", root, "BackdropTemplate")
	frame:SetSize(X_SIZE, Y_SIZE)
	frame:SetPoint("TOPLEFT", root, "TOPLEFT", 720, -460)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	AddDrag(frame)
	AddBackdrop(frame)

	local path = LibStub("LibSharedMedia-3.0"):Fetch("font", "PT Sans Narrow", true) or "Fonts\\ARIALN.TTF"
	local font = CreateFont("KamiDragTestFontD")
	font:SetFont(path, 18, "")
	font:SetTextColor(1, 1, 1, 0.65)
	font:SetShadowColor(0, 0, 0, 1)
	font:SetShadowOffset(1, -1)

	local stack = CreateFrame("Frame", nil, frame)
	stack:SetSize(X_SIZE - 20, Y_SIZE - 20)
	stack:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)

	for i = 1, LINE_COUNT do
		local row = CreateFrame("Frame", nil, stack)
		row:SetSize(X_SIZE - 20, 22)
		row:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, -(i - 1) * 26)

		local text = row:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font)
		text:SetText(("D %d  %s"):format(i, TEXT))
		text:SetWidth(X_SIZE - 20)
		text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	end
end

----------------------------------------------------------------------------------------------------
-- E: the first test, restored as it was when it jittered

local function CreateWindowE()
	local frame = CreateFrame("Frame", "KamiDragTestE", UIParent, "BackdropTemplate")
	frame:SetScale(PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale())
	frame:SetSize(X_SIZE, Y_SIZE)
	frame:SetPoint("TOPLEFT", nil, "TOPLEFT", 720, -800)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	AddBackdrop(frame)

	local font = CreateFont("KamiDragTestFontE")
	font:SetFont("Fonts\\FRIZQT__.TTF", 20, "")
	font:SetTextColor(1, 1, 1, 1)

	for i = 1, LINE_COUNT do
		local text = frame:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font)
		text:SetText(("E %d  %s"):format(i, TEXT))
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10 - (i - 1) * 26)
	end

	local xDrag, yDrag = 0, 0
	local function DragUpdate()
		local xCursor, yCursor = GetCursorPosition()
		local effective = frame:GetEffectiveScale()
		local x = Round(xCursor / effective + xDrag)
		local y = Round(yCursor / effective + yDrag)
		frame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)
	end

	frame:SetScript("OnDragStart", function()
		local xCursor, yCursor = GetCursorPosition()
		local effective = frame:GetEffectiveScale()
		xDrag = frame:GetLeft() - xCursor / effective
		yDrag = frame:GetTop()  - yCursor / effective
		frame:SetScript("OnUpdate", DragUpdate)
	end)

	frame:SetScript("OnDragStop", function()
		frame:SetScript("OnUpdate", nil)
	end)
end

----------------------------------------------------------------------------------------------------
-- File Load

CreateWindowA()
CreateWindowB()
CreateWindowC()
CreateWindowD()
CreateWindowE()
