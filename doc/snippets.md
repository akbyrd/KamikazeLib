```pwsh
New-Item `
	-ItemType Junction `
	-Path "C:\\Program Files (x86)\\World of Warcraft\\_retail_\\Interface\\AddOns\\KamikazeLib" `
	-Value "D:\\Dev\\Personal\\KamikazeLib"
```

```
/dump Kami.CDM.cfg
```

```
/dump GetBuildInfo()
```

```
/dump GetCVar("useUiScale"), GetCVar("uiScale")
```

```lua
if LibStub then
	local LSM = LibStub("LibSharedMedia-3.0")
	if LSM then
		DevTools_Dump(LSM:HashTable(LSM.MediaType.FONT))
		DevTools_Dump(LSM:List(LSM.MediaType.FONT))
		local path = LSM:Fetch(LSM.MediaType.FONT, "my font")
	end
end
```

```lua
local ppScale = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()

local pixels_to_canvas = PixelUtil.GetPixelToUIUnitFactor()
local canvas_to_local = 1 / frame:GetEffectiveScale()
```
