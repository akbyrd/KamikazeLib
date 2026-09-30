Skyriding
---------
* Not sure about using cooldownID as the lookup key.
	* I like the string shenanigans being moved to only skyriding abilities. But it's going to break naive lookups.
	* I think multiple tables with different key types probably makes more sense.
* Seems like we shouldn't hide/clear things in EnableFrame that we don't refresh during a rebuild?
* Don't like the empower stuff being moved to RefreshAllSizes
* Doesn't removing RefreshOverride break lookups?
	* I don't understand why lookups aren't updated
* Not sure about GetActionSpell
* Remove the de-dupe from skyriding
* Don't make duplicate EnableSpellRangeCheck calls



Deal with range checking
* We can't disable events before enabling them. Looks like it's implemented as a global integer count.
* We probably need range checking for certain trinkets and potions, which is unhandled right now and can't always happen in ConstructFrame or EnableFrame
* Option 1 - avoid calling DisableFrame before EnableFrame
* Option 2 - remember whether we've called EnableSpellRangeCheck
* Option 3 - Call EnableSpellRangeCheck during ConstructFrame and never disable it
Refactor to simplify
* Maybe 3 viewers: essential, utility, skyriding
* Maybe update hidden / inactive frames
* Maybe we always rebuild when both out of combat and auras become non-secret so we don't need the flag
Why don't trinkets/potions show when skyriding?

All remaining known issues
Remaining tests
Test dimensius
Test cast prediction
Test on evoker



To Do
-----
Bladestorm buff bar doesn't show up
Stance shared cooldown isn't shown

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
