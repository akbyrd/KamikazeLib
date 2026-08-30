```pwsh
New-Item `
	-ItemType Junction `
	-Path "C:\\Program Files (x86)\\World of Warcraft\\_retail_\\Interface\\AddOns\\KamikazeLib" `
	-Value "D:\\Dev\\Personal\\KamikazeLib"
```

```
/api
/console taintLog 1
/dump GetBuildInfo()
/dump GetCVar("useUiScale"), GetCVar("uiScale")
/dump Kami.CDM.cfg
```

```
/dump C_Spell.GetSpellCooldown(spellID)
/dump C_Spell.GetLastCategoryCooldownSource(4)
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

```lua
local isSecure, taint = issecurevariable(table, "member")
InCombatLockdown()
```

``` lua
SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
SetBlingTexture("Interface\\Cooldown\\starburst", 0.3, 0.6, 1, 0.64)
SetBlingTexture("Interface\\BUTTONS\\WHITE8X8", 1, 1, 1, 1)
C_Spell.GetLastCategoryCooldownSource
Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY
SetUseAuraDisplayTime
```
