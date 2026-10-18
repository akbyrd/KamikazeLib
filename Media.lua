local Kami = select(2, ...)
local Media = {}
Kami.Media = Media

local path = "Interface\\AddOns\\KamikazeLib\\Media\\"

Media.Border       = { texture = path .. "Border.tga"                }
Media.CooldownEdge = { texture = path .. "CooldownEdge.tga"          }
Media.Staircase    = { texture = path .. "Staircase.tga", size = 256 }

Media.MaterialSymbols = {
	font    = path .. "MaterialSymbolsSharp-Regular.ttf",
	ascent  = 1056,
	descent = 96,
	grid    = 24,
	size    = 24,
}
