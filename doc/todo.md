To Do
-----
Saved vars
	Approach 1 - Explicit resolve/cache step
	Approach 2 - Metatable intercepts reads with lazy caching
	----
	Overriding
	Only save overrides
	Intermediate data (converted colors)
	Related fields (coordinate space)
	Versioning
		Include in Setting_*
		Function for upgrading
	Last used potion in category
	Refresh only what changed
		Maybe register refresh functions for each setting?
	Need to be able to iterate tables with inheritance
Settings
	Don't use Blizz settings
	Editable in combat
	Edit mode support? (C_EditMode.GetLayouts(), EDIT_MODE_LAYOUTS_UPDATED)
	Cache colors / intermediates
Profile performance
----
Custom row wrapping
Disable ability highlight on specific spells
Per-talent layout
Buff Bars
	Skin
	Custom spell color (classify?)
	Show permanent buff bars as full
	Hide pip
	Pandemic support
Sweeping strikes bar
Whirlwind bar
Rage bar
----
Anchoring
Tooltips
Track any item
Track any spell
Skyriding



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
Buggy as hell
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
