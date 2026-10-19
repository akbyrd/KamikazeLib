To Do
-----
Attempt to remove OnCDMChanged

Testing
	Test vehicle power prediction
	Nil spell id from GetShapeshiftFormInfo when exiting Ulduar
	Check that /castsequence updates as the sequence progresses
	Passenger mount - confirm resource bar behaves
	Vehicle power prediction
	Shared charges on Essential

Known issues
	Charge flicker when clearing target
	Keep empower max stacks across e.g. conditional macro changes
		Central lookup?
		Or pool frame by identity and reuse (complicated with duplicates)
	Handle press highlight for `[btn:2]` macros

Track any spell
	Power infusion
Track any item

Resources
	Sweeping strikes bar
	Whirlwind bar

Formalize the set of types
	Probably 2 concepts: source type (or slot type?) and content type (or frame type?)
	Source type: cdm, action bar
	Content type: item, spell
	What about these: macro, action

Generalize CDM infrastructure
	Root frame and pixel perfect scaling
	Scale change events
	Rebuild events
	Share more config by default?
	Maybe event handling?
	Override tracking

Settings
	Row highlights
	Tooltips
		Put file earlier in toc
		Figure out how profiles should work
	Show in built-in Options > Addons?
	Edit Mode support? (C_EditMode.GetLayouts(), EDIT_MODE_LAYOUTS_UPDATED)
	"show all" buff bars for edit mode
	Implement search
	Versioning

Auto-hide
Track active duration
Anchoring
Disable ability highlight on specific spells
Per-talent layout
Find a suitable spell category database (Danders if loaded?)
Profile performance
Alerts
Store empower max stacks - better conditional macro support in combat
Enable pandemic per-spell (disable on Bladestorm)
Consider C_ActionBar.FindAssistedCombatActionButtons()



Other Ideas
-----------
Reflect damage
Combat Text
Nameplates
Out-of-game harness
Debug tooling - repl and log window
