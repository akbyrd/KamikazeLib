To Do
-----
Test healthstone
Rebuild
	Update single buttons
Track any item
Track any spell
Per-talent layout
Disable ability highlight on specific spells
Settings support
	Don't use Blizz settings
	Editable in combat
	Edit mode support? (C_EditMode.GetLayouts(), EDIT_MODE_LAYOUTS_UPDATED)
	Default + inheritance + override based
Custom row wrapping
Orientation and direction
Anchoring
Buff Bars
	Skin
	Custom spell color (classify?)
	Show permanent buff bars as full
	Hide pip
	Pandemic support
Profile performance
Replace LibCustomGlow. It sucks



Custom Implementation
---------------------
Potions
	Use item id to support older potions
	Store C_Spell.GetLastCategoryCooldownSource across reloads
	Initialize from first item in bags?
Modularize
	Each behavior gets an object with { init, enable, update, disable, deinit }



Cooldown Manager Control
------------------------
Mostly abandoned
Can't control row wrapping well
No button press overlay
No assistant highlight
Can't anchor buff bar width to cooldowns
Desaturation doesn't work properly on trinkets
Bar color override linked to unrelated settings
Can't track racial



ClassUIEnhanced
---------------
Can't track racial
Can't track health pots, missing customization
Can't change assistant highlight type
Borders are uneven
Mediocre control over row count
Can't have non-square icons on bars
Custom spell don't match style
Can't reorder custom spells
Can't track racial
Can't track health potion / healthstone



Ellesmere Cooldown Manager
--------------------------
Can't change assistant highlight type
No button press overlay (Bug, there's a setting for it "Mirror Key Presses)
Can't set highlight color
Can't make rectangular icons



Action Bars
-----------
Will it auto-center when button count changes?
Won't get press highlight
Doesn't work as well for utility bar
Use unit frame aura bars for buff bars?



Maybe Useful
------------
SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE
EssentialCooldownViewer:MarkDirty()
SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
SetBlingTexture("Interface\\Cooldown\\starburst", 0.3, 0.6, 1, 0.64)
SetBlingTexture("Interface\\BUTTONS\\WHITE8X8", 1, 1, 1, 1)
viewer.orientationSetting
viewer.iconDirection, Enum.CooldownViewerIconDirection.Right
C_Spell.GetLastCategoryCooldownSource(categoryID
Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY)
SetUseAuraDisplayTime
