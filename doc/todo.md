To Do
-----
Name callbacks differently
Custom row wrapping
Cooldown text
Handle healthstone
Handle combat potion
Handle health potion
Pandemic support
----
Custom spell color (classify?)
Settings work in combat
Hide pip
Show permanent buff bars as full
----
Edit mode support
	C_EditMode.GetLayouts(), EDIT_MODE_LAYOUTS_UPDATED
	position changes
	Orientation and direction
Anchoring
Disable ability highlight on specific spells
Separate settings for each viewer
Profile performance
----
Track any item
Track any spell
Replace LibCustomGlow. It sucks


Items
-----
spellID         +spell +trinket -pot -stone
spellCategoryID -spell -trinket +pot +stone
cooldownID      +spell +trinket +pot +stone
{ Name = "cooldownID",             Type = "number",                      Nilable = false },
{ Name = "spellID",                Type = "number",                      Nilable = true },
{ Name = "spellCategoryID",        Type = "number",                      Nilable = true },
{ Name = "overrideSpellID",        Type = "number",                      Nilable = true },
{ Name = "overrideTooltipSpellID", Type = "number",                      Nilable = true },
{ Name = "equipSlot",              Type = "luaIndex",                    Nilable = true },
{ Name = "buffSlot",               Type = "luaIndex",                    Nilable = true },
{ Name = "linkedSpellIDs",         Type = "table", InnerType = "number", Nilable = false },
{ Name = "selfAura",               Type = "bool",                        Nilable = false },
{ Name = "hasAura",                Type = "bool",                        Nilable = false },
{ Name = "charges",                Type = "bool",                        Nilable = false },
{ Name = "isKnown",                Type = "bool",                        Nilable = false },
{ Name = "isInvisible",            Type = "bool",                        Nilable = false },
{ Name = "flags",                  Type = "CooldownSetSpellFlags",       Nilable = false },
{ Name = "category",               Type = "CooldownViewerCategory",      Nilable = false },

CDM.spellFrames = {}
CDM.equipFrames = {}

CDM.frameMapData = {
	spellID   = CDM.spellFrames,
	equipSlot = CDM.equipFrames,
}

for keyName, map in pairs(CDM.frameMapData) do
	for key, frame in pairs(map) do
	end
end



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
