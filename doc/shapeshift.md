Two things make cooldowns for shapeshifts / stances / forms difficult: stateful icons and shared cooldowns.



Stateful Icons
--------------
Examples (assume some inaccuracies):
* Death Knight - None.
* Demon Hunter - Glide, Spectral Sight.
* Druid        - Cat, Bear, etc forms. Prowl.
* Evoker       - Black, Bronze Attunement. Emerald Communion, Sense Power.
* Hunter       - Aspect of the Turtle, Camouflage, Eagle Eye, Prowl, Pets.
* Mage         - Ice Block.
* Monk         - Leg Sweep, Sheilun's Gift, Zen Flight.
* Paladin      - Devotion, Crusader, etc auras. Blessing of Sacrifice?
* Priest       - Shadowform.
* Rogue        - Stealth, Vanish.
* Shaman       - Ghost Wolf.
* Warlock      - Burning, Threatening Presence. Pets.
* Warrior      - Battle, Defensive, etc stances.

Behaviors:
* Not all things with stateful icons are shapeshifts (e.g. Warrior stances).
* Usually 136116. But also 136047, 132327, 132331, 136222.
* C_Spell.IsCurrentSpell is true for some spells (e.g. Ghost Wolf).
* C_Spell.IsCurrentSpell is false for some spells (e.g. Battle Stance).
* GetShapeshiftFormInfo returns stateful icons.
* C_ActionBar.GetActionTexture returns stateful icons.
* Druid Prowl does not sent UPDATE_SHAPESHIFT_FORM (but does send UPDATE_STEALTH).

Problems:
* There's no way to query the alternate icon for a spell (ActiveIconFileDataID in spell data).
* C_Spell.GetSpellTexture always returns the default icon.
* C_Spell.IsCurrentSpell is true for some stateful spells (e.g. Ghost Wolf).

Workarounds:
1. Use the shapeshift bar (GetShapeshiftFormInfo) to get the icon.
	* Only works for things on the shapeshift bar, obviously.
2. Find the spell on a bar slot (C_ActionBar.GetActionTexture) to get the icon.

Current Solution:
Workaround 1



Shared Cooldowns
----------------
Behaviors:
* Battle Stance and Defensive Stance share a cooldown. Using either causes both to be on cooldown.
* Not all things on the shapeshift bar apply a shapeshift (GetShapeshiftFormID) (e.g. Warrior stances).
* I think everything on the shapeshift bar sends UPDATE_SHAPESHIFT_FORM (e.g. Warrior stances).
* I think shared cooldowns always have a category.
* Few categories are actually a shared cooldown.

Problems:
* There's only a cooldown event for the one that was cast and not for the other.
* There's no way to get all spells in a category.
* There's no way to get the category for a specific spell until it goes on cooldown.
* There's no way to ask if a spell is on the shapeshift bar (but you can iterate the bar).
Thus, there's no way to know which spells need to refresh their cooldown.

Workarounds:
1. For any cooldown event with a category (SPELL_UPDATE_COOLDOWN), refresh all cooldowns.
	* Many spells have a category with spells they are mutually exclusive with.
2. For any shapeshift change event (UPDATE_SHAPESHIFT_FORM), refresh all shapeshift cooldowns.
3. For any shapeshift cooldown event (UPDATE_SHAPESHIFT_COOLDOWN), refresh all shapeshift cooldowns.
	* This event gets spammed for every cooldown of any kind and is unsuitable for use.

Current Solution:
Workaround 2



Sticky IsCurrentSpell
---------------------
TODO: What do we want to do here?
