_G.BINDING_HEADER_KAMIKAZELIB = "KamikazeLib"

-- Re-order world markers to match target markers
local wmReorder = { 5, 6, 3, 2, 7, 1, 4, 8 }
local wmNext = 1

local function GetNextMarker()
	local wmActual = wmReorder[wmNext]
	wmNext = (wmNext % 8) + 1
	return wmActual
end

local function ResetNextMarker()
	wmNext = 1
end

local function MakeButton(buttonName, bindingName, onPreClick)
	_G[string.format("BINDING_NAME_CLICK %s:LeftButton", buttonName)] = bindingName
	local btn = CreateFrame("button", buttonName, nil, "SecureActionButtonTemplate")
	btn:SetAttribute("type", "macro")
	btn:RegisterForClicks("AnyDown")
	btn:SetScript("PreClick", onPreClick)
end

-- Initialize

MakeButton("KL_NEXT_WORLD_MARKER", "Next World Marker",
	function(self, button, down)
		local marker = GetNextMarker()
		local macro = string.format("/wm %d", marker)
		self:SetAttribute("macrotext", macro)
	end
)

MakeButton("KL_CLEAR_WORLD_MARKERS", "Clear World Markers",
	function(self, button, down)
		ResetNextMarker()
		local macro = "/cwm all"
		self:SetAttribute("macrotext", macro)
	end
)

MakeButton("KL_CLEAR_AND_NEXT_WORLD_MARKER", "Clear and Place Next World Marker",
	function(self, button, down)
		ResetNextMarker()
		local marker = GetNextMarker()
		local macro = string.format("/cwm all\n/wm %d", marker)
		self:SetAttribute("macrotext", macro)
	end
)
