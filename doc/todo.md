Requirements
------------
-[ ] Button press flash/overlay
-[ ] Custom row wrapping
-[ ] Track any item
-[ ] Track any spell
-[ ] Include item/spell in containers
-[ ] Rotation assistant
-[ ] Ability highlight
-[ ] Disable ability highlight on specific spells
-[ ] Cooldown text
-[ ] Custom spell color (classify?)
-[x] Non-square icons
-[ ] Settings work in combat
-[ ] Hide pip
-[ ] Edit mode support
-[ ] Anchoring
-[ ] Show permanent buff bars as full
-[x] No bling. Complicated and not terribly useful



Cooldown Manager Control
------------------------
Abandoned
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



Colors
------
Rage      ff180c
Whirlwind 4fb1e0
Offensive ff180c
Defensive 5440ff
CD Swipe  000000 70
CD Edge   99ff00    / 0.6, 1.0, 0.0
Assistant 3399f2 90 / 0.2, 0.6, 0.95, 0.9



Aspect Ratios
-------------
Essential - 1.65
Utility   - 1.27
Buff Bars - 1.5



Maybe Useful
------------
EssentialCooldownViewer:MarkDirty()
SetBlingTexture("Interface\\Cooldown\\star4", 0.3, 0.6, 1, 0.64)
SetBlingTexture("Interface\\Cooldown\\starburst", 0.3, 0.6, 1, 0.64)
SetBlingTexture("Interface\\BUTTONS\\WHITE8X8", 1, 1, 1, 1)



To Do
-----
Show GCD on Raging Blow
Separate settings for each viewer
Hide proc glow on Rampage
Set cooldown text font
Split into one-time and every-time parts
C_Spell.IsCurrentSpell - for button press?
