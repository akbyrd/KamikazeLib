To Do
-----
Spell overrides
Item categories
Charge text
Settings
Saved vars
----
Sweeping strikes bar
Whirlwind bar
Rage bar
Potions
	Use item id to support older potions
	Store C_Spell.GetLastCategoryCooldownSource across reloads
	Initialize from first item in bags?
Modularize
	Each behavior gets an object with { init, enable, update, disable, deinit }
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
Anchoring
Buff Bars
	Skin
	Custom spell color (classify?)
	Show permanent buff bars as full
	Hide pip
	Pandemic support
Profile performance
Replace LibCustomGlow. It sucks



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
Can't track health potion / healthstone
Can't change assistant highlight type
Borders are uneven
Mediocre control over row count
Can't have non-square icons on bars
Custom spell don't match style
Can't reorder custom spells



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
