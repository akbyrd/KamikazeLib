Skyriding
---------
* Don't like the empower stuff being moved to RefreshAllSizes
* Not sure about GetActionSpell

Should hidden frames remain in the lookups?
	* Ideally, we don't update them while hidden
	* Requires everything that isn't updated to be derivable on a rebuild
	* Bling and Override are the hold outs
	* Currently inconsistent: hidden frames are in lookups but not activeFramers and get mixed updates

Are slots pulling their weight?
All remaining known issues
Remaining tests
Full review
Test conditional macro on skyriding while mounting
Test dimensius
Test cast prediction
Test on evoker



To Do
-----
Add range check support for potions and trinkets
Bladestorm buff bar doesn't show up
Stance shared cooldown isn't shown
Stance icon change doesn't work
Consider tracking pressed state for things not on the CDM

Possess bar
	Similar to skyriding - hide buffs, swap resource, show abilities

Power infusion
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
Track any item
Track any spell
Find a suitable spell category database (Danders if loaded?)
Profile performance
Empower flickers when rebuilding
	Consider minimizing unnecessary rebuilds?
	Only if CD data changes?
Test vehicle power prediction
Alerts



Other Ideas
-----------
Reflect damage
Combat Text
Nameplates
Out-of-game harness
