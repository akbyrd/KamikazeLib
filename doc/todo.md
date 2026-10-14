Skyriding
---------
Equipment set doesn't darken consistently
Spell assistant doesn't reassign consistently

Architecture review - compare with d81b8aab46c65f01180cb7b3344e8eabc7bcc9db
Split unrelated changes



To Do
-----
Charge text is hidden at zero
Charge flicker when clearing target
Passenger mount - confirm resource bar behaves
Bladestorm buff bar doesn't show up
Imminent Demise empower doesn't show up
Stance shared cooldown isn't shown
	Icons also won't be right if added to non-action bar viewers
Keep empower max stacks across e.g. conditional macro changes
	Central lookup?
	Or pool frame by identity and reuse (complicated with duplicates)
Add range check support for potions and trinkets
	Partially works with the new RefreshUsable
	Slow to update when moving in/out of range
	Updates immediately on a target change

Show ground movement speed when skyriding but grounded
Handle press highlight for `[btn:2]` macros
Test /castsequence (should update as the sequence progresses)

Possess / vehicle cooldowns
	Test vehicle power prediction
	Test vehicle with no power - resource bar hides
	Similar to skyriding - hide buffs, swap resource, show abilities

Track any spell
	Power infusion
Track any item

Resources
	Sweeping strikes bar
	Whirlwind bar

Generalize CDM infrastructure
	Root frame and pixel perfect scaling
	Scale change events
	Rebuild events
	Share more config by default?
	Maybe event handling?

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
Custom glow when ready
Disable ability highlight on specific spells
Per-talent layout
Find a suitable spell category database (Danders if loaded?)
Profile performance
Test vehicle power prediction
Alerts
Attempt to remove OnCDMChanged
Store empower max stacks - better conditional macro support in combat



Other Ideas
-----------
Reflect damage
Combat Text
Nameplates
Out-of-game harness
Debug tooling - repl and log window
