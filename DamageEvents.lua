local Kami = select(2, ...)
local Dmg = {}
Kami.DamageEvents = Dmg

function Dmg.Load()
	-- Seconds
	Dmg.Time = {
		Spell           = 0.125, -- a spell's line comes up to this before its hit; under 0.143, the earliest proc hit
		Shot            = 0.35,  -- a shot's line comes up to this before its hit, on a recent shot's target
		ShotFlight      = 2.5,   -- a shot lands up to this after its cast
		MeleeFrom       = 0.25,  -- a swing's line comes one swing delay before its hit: at least this...
		MeleeTo         = 1.1,   -- ...and at most this
		ProcAfterStrike = 0.15,  -- a weapon proc's line comes up to this after the strike that made it...
		ProcTo          = 1.45,  -- ...and its hit up to this after the line
		Hold            = 0.15,  -- a hit can come up to this before its line
		Direct          = 1.5,   -- a cast's hit lands up to this after the cast
		Miss            = 0.1,   -- a missed application comes up to this after its cast
		Tick            = 0.1,   -- a tick lands up to this far from its rhythm
		Judgement       = 0.2,   -- Judgement's hit comes up to this after its cast
		SealProc        = 0.15,  -- a seal proc comes up to this after the swing that landed it
		SealDuration    = 30,
		Consecration    = 8.2,
		DotSlack        = 1,     -- a DoT counts as up this long past its longest duration, for one that travels or drifts
	}
	Dmg.Time.History = Dmg.Time.SealDuration -- the longest anything looks back at casts

	-- When a hit can come relative to its line, as hit time minus line time. swing: the hit is an auto
	-- attack's or a weapon proc's, so it's physical. delay: it's at one of its owner's swing delays.
	Dmg.Windows = {
		Spell    = { from = 0,                  to = Dmg.Time.Spell                                    },
		Shot     = { from = 0,                  to = Dmg.Time.Shot,                  shotTarget = true },
		Melee    = { from = Dmg.Time.MeleeFrom, to = Dmg.Time.MeleeTo, swing = true, delay = true      },
		OffDelay = { from = Dmg.Time.MeleeFrom, to = Dmg.Time.MeleeTo, swing = true                    },
		Proc     = { from = 0,                  to = Dmg.Time.ProcTo,  swing = true                    },
		Late     = { from = -Dmg.Time.Hold,     to = 0                                                 },
		Early    = { from = 0,                  to = Dmg.Time.Spell,   swing = true                    },
	}

	-- windows   - when a hit can take the line as it comes, tried in order. The line is dropped once
	--             the last one has passed.
	-- unclaimed - once the line is `claim` old and no newer hit has taken it, the oldest waiting hit in
	--             the first of these windows that has one gets it. A weapon proc's line stays takeable
	--             after that. A shot's gets the hit that passed it by for its school (Takes), and a
	--             swing's the hit off its swing delay before one too early.
	Dmg.Timing = {
		Spell = { windows = { Dmg.Windows.Spell },                   unclaimed = { Dmg.Windows.Late },                                     claim = Dmg.Time.Spell   },
		Shot  = { windows = { Dmg.Windows.Spell, Dmg.Windows.Shot }, unclaimed = { Dmg.Windows.Spell, Dmg.Windows.Shot, Dmg.Windows.Late }, claim = Dmg.Time.Shot    },
		Proc  = { windows = { Dmg.Windows.Spell, Dmg.Windows.Proc }, unclaimed = { Dmg.Windows.Late },                                     claim = Dmg.Time.Spell   },
		Swing = { windows = { Dmg.Windows.Melee },                   unclaimed = { Dmg.Windows.OffDelay, Dmg.Windows.Early },              claim = Dmg.Time.MeleeTo },
	}

	-- In a group another player's hit often lands in a swing line's window, so a swing line takes the
	-- hit at one of its owner's swing delays first. Each owner's delays sit in a cluster or two 10-30 ms
	-- wide (upstream's warlock-bfd-group trace), learned from clean swings: a swing line with one hit
	-- in its window and no other swing line near. A hit is at one when `pair` of the `keep` latest
	-- delays, and `share` of them, are within `near` of it; until `min` are in, any hit is. Upstream's
	-- first guesses, untuned.
	Dmg.SwingDelay = { keep = 20, min = 4, near = 0.02, pair = 2, share = 0.1 }

	-- r, g, b   - the color the log filter gives the kind's events
	-- accepts   - the hits a line of this kind can be: "damage" or "miss". nil for a line we ignore,
	--             colored only so it can't pass for one of ours
	-- timing    - when its hit can come (Timing)
	-- group     - where spell identity looks for its spell: "direct", "tick", "shot" or "shield"
	-- nextSwing - the kind of line a next-swing ability's hit comes with
	-- crowds    - two of its hits at one time on one unit can't be told apart
	-- lands     - a landed swing, which can proc a seal
	-- events    - the combat log events of this kind
	Dmg.LineKinds = {
		{ r = 1.00, g = 0.85, b = 0.25, accepts = "damage", timing = Dmg.Timing.Spell,               group = "direct",                nextSwing = true, events = { "SPELL_DAMAGE", "SPELL_LEECH" }                   },
		{ r = 0.75, g = 0.55, b = 1.00, accepts = "damage", timing = Dmg.Timing.Spell,               group = "tick",   crowds = true,                   events = { "SPELL_PERIODIC_DAMAGE", "SPELL_PERIODIC_LEECH" } },
		{ r = 0.85, g = 0.85, b = 0.85, accepts = "damage", timing = Dmg.Timing.Swing, lands = true,                                                    events = { "SWING_DAMAGE" }                                  },
		{ r = 0.90, g = 0.70, b = 0.45, accepts = "damage", timing = Dmg.Timing.Shot,                group = "shot",                                    events = { "RANGE_DAMAGE" }                                  },
		{ r = 1.00, g = 0.55, b = 0.20, accepts = "damage", timing = Dmg.Timing.Spell,               group = "shield",                                  events = { "DAMAGE_SHIELD" }                                 },
		{ r = 0.55, g = 0.65, b = 0.85, accepts = "miss",   timing = Dmg.Timing.Spell,               group = "direct",                                  events = { "SPELL_MISSED" }                                  },
		{ r = 0.65, g = 0.50, b = 0.85, accepts = "miss",   timing = Dmg.Timing.Spell,               group = "tick",                                    events = { "SPELL_PERIODIC_MISSED" }                         },
		{ r = 0.60, g = 0.60, b = 0.60, accepts = "miss",   timing = Dmg.Timing.Swing,                                                                  events = { "SWING_MISSED" }                                  },
		{ r = 0.75, g = 0.60, b = 0.50, accepts = "miss",   timing = Dmg.Timing.Shot,                group = "shot",                                    events = { "RANGE_MISSED" }                                  },
		{ r = 0.70, g = 0.55, b = 0.35, accepts = "miss",   timing = Dmg.Timing.Spell,               group = "shield",                                  events = { "DAMAGE_SHIELD_MISSED" }                          },
		{ r = 0.30, g = 1.00, b = 0.40,                                                                                                                 events = { "SPELL_HEAL" }                                    },
		{ r = 0.55, g = 0.85, b = 0.55,                                                                                                                 events = { "SPELL_PERIODIC_HEAL" }                           },
		{ r = 1.00, g = 1.00, b = 1.00,                                                                                                                 events = { "PARTY_KILL" }                                    },
	}

	Dmg.LogFilter = {
		ownSources     = { [0x4511] = true, [0x3111] = true }, -- Done By "Me" and "My pet"
		byKind         = 3,                                    -- lineColorPriority: by event type
		tolerance      = 0.02,                                 -- line colors arrive as 8-bit values
		apart          = 0.04,                                 -- a kind's color is further than this from any other a line can have
		savedTolerance = 0.005,                                -- saved colors are their writer's floats, or 8-bit after an edit
		uncolored      = { r = 0.5, g = 0.5, b = 0.5 },        -- an event with no color of its own
		highlight      = 1.5,                                  -- highlighting brightens a line this much, to at most white
		keepAlive      = 2,                                    -- dungeons turn COMBAT_LOG_MESSAGE off; re-enable it this often
		missTypes      = { "ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST" },
		-- Events that a filter may color as one of a kind's, read as that kind: MikScrollingBattleText
		-- colors a hit on a building as a spell's hit, and a heal on one as a heal
		aliases        = { SPELL_BUILDING_DAMAGE = "SPELL_DAMAGE", SPELL_BUILDING_HEAL = "SPELL_HEAL" },
	}

	-- Each kind's lines are colored by its events' names, a miss's with its miss type added
	Dmg.KindOfEvent = {}
	for _, kind in ipairs(Dmg.LineKinds) do
		kind.colored = {}
		for _, event in ipairs(kind.events) do
			table.insert(kind.colored, event)
			for _, missType in ipairs(kind.accepts == "miss" and Dmg.LogFilter.missTypes or {}) do
				table.insert(kind.colored, event .. "_" .. missType)
			end
		end
		for _, event in ipairs(kind.colored) do
			Dmg.KindOfEvent[event] = kind
		end
	end

	-- Spells by the spell ID of their cast, from Forever's spell data (wago.tools DB2, 1.60.1.70888)
	--
	-- school       - the school its hits report
	-- explains     - line group -> how long after the cast a hit in that group can be the cast's
	-- misses       - the same for a miss, when it differs
	-- strike       - a melee strike, which can make a weapon proc
	-- nextSwing    - replaces the next swing; that frame has an empty physical report before the hit
	-- seal         - a seal; true when its proc gets an icon
	-- consecration - ticks as direct holy hits with no cast, which look like a seal proc
	-- nearness     - tied to its cast only by nearness, so ambiguous during Consecration
	-- interval, duration, travels, landing (travels and hits), area (ticks as direct hits of another
	--              spell, on a grid from the cast) - a spell that ticks

	Dmg.Spells = {}

	-- A cast whose spell ID is secret could be any spell
	Dmg.Secret = { explains = { direct = Dmg.Time.Direct, shot = Dmg.Time.ShotFlight } }

	-- A damage shield's line has no cast, so its hit takes the player's shield of its school. Its ranks
	-- share an icon and a name, so the first stands for all.
	Dmg.Shields = {
		[Enum.Damageclass.MaskNature] = 467,  -- Thorns
		[Enum.Damageclass.MaskHoly]   = 7294, -- Retribution Aura
		[Enum.Damageclass.MaskFire]   = 2947, -- Fire Shield, an Imp's
	}

	-- Temporary weapon enchants whose proc hits, by enchant ID: the proc's spell. A proc has no cast,
	-- so the enchant on the player's weapons names it. From the same data's SpellItemEnchantment.
	Dmg.EnchantProcs = {}
	Dmg.ProcsFrom(Enum.Damageclass.MaskNature, { [323] = 8680, [324] = 8685, [325] = 8689, [623] = 11335, [624] = 11336, [625] = 11337 })  -- Instant Poison
	Dmg.ProcsFrom(Enum.Damageclass.MaskFrost,  { [2] = 8034, [12] = 8037, [524] = 10458, [1667] = 16352, [1668] = 16353, [7566] = 16353 }) -- Frostbrand Weapon (untested)
	Dmg.ProcsFrom(Enum.Damageclass.MaskShadow, { [25] = 350026 })                                                                          -- Shadow Oil (untested)
	Dmg.ProcsFrom(Enum.Damageclass.MaskFrost,  { [26] = 350025 })                                                                          -- Frost Oil (untested)

	-- Ranged attacks
	Dmg.Shoots(nil,                           { 5019 })             -- Shoot, whose school its wand sets
	Dmg.Shoots(Enum.Damageclass.MaskPhysical, { 75 })               -- Auto Shot
	Dmg.Shoots(Enum.Damageclass.MaskPhysical, { 2480, 7918, 7919 }) -- Shoot Bow, Shoot Gun, Shoot Crossbow
	Dmg.Shoots(Enum.Damageclass.MaskPhysical, { 2764 })             -- Throw

	-- Druid
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 769, 779, 780, 9754, 9908 })                      -- Swipe
	Dmg.Hits(Enum.Damageclass.MaskArcane,   { 2912, 8949, 8950, 8951, 9875, 9876, 25298 })      -- Starfire
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1082, 3029, 5201, 9849, 9850 })                   -- Claw
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912 }) -- Wrath
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 5221, 6800, 8992, 9829, 9830 })                   -- Shred
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 6785, 6787, 9866, 9867 })                         -- Ravage
	Dmg.ReplacesSwing(                      { 6807, 6808, 6809, 8972, 9745, 9880, 9881 })       -- Maul
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 22568, 22827, 22828, 22829, 31018 })              -- Ferocious Bite
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1328618 })                                        -- Ferocious Bite, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 407995, 1238069, 1238070, 1238073 })              -- Primal Bite, Forever only (the first rank is Mangle's ID)

	Dmg.Ticks(3, Enum.Damageclass.MaskNature,   27, {},              { 339, 1062, 5195, 5196, 9852, 9853 })                          -- Entangling Roots
	Dmg.Ticks(2, Enum.Damageclass.MaskPhysical, 12, {},              { 1079, 9492, 9493, 9752, 9894, 9896 })                         -- Rip
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 9,  { hits = true }, { 1822, 1823, 1824, 9904 })                                     -- Rake
	Dmg.Ticks(2, Enum.Damageclass.MaskNature,   12, {},              { 5570, 24974, 24975, 24976, 24977 })                           -- Insect Swarm
	Dmg.Ticks(3, Enum.Damageclass.MaskArcane,   12, { hits = true }, { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 }) -- Moonfire
	Dmg.Ticks(1, Enum.Damageclass.MaskNature,   10, { area = true }, { 16914, 17401, 17402 })                                        -- Hurricane
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 15, {},              { 414644 })                                                     -- Lacerate
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 18, {},              { 9005, 9823, 9827 })                                           -- Pounce; its ticks are Pounce Bleed's
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 15, {},              { 1235826, 1235827, 1328616, 1328617 })                         -- Lacerate, Forever's ranks (interval untested)

	-- Hunter
	Dmg.Hits(Enum.Damageclass.MaskPhysical,       { 1495, 14269, 14270, 14271 })                             -- Mongoose Bite
	Dmg.RangedHits(Enum.Damageclass.MaskPhysical, { 2643 })                                                  -- Multi-Shot
	Dmg.Hits(Enum.Damageclass.MaskPhysical,       { 2974, 14267, 14268, 27633 })                             -- Wing Clip
	Dmg.Hits(Enum.Damageclass.MaskArcane,         { 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287 }) -- Arcane Shot
	Dmg.ReplacesSwing(                            { 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266 }) -- Raptor Strike
	Dmg.Hits(Enum.Damageclass.MaskPhysical,       { 19306, 20909, 20910 })                                   -- Counterattack
	Dmg.RangedHits(Enum.Damageclass.MaskPhysical, { 19434, 20900, 20901, 20902, 20903, 20904, 27632 })       -- Aimed Shot
	Dmg.RangedHits(Enum.Damageclass.MaskPhysical, { 19503 })                                                 -- Scatter Shot
	Dmg.Hits(Enum.Damageclass.MaskPhysical,       { 1242634 })                                               -- Counterattack, Forever's rank
	Dmg.RangedHits(Enum.Damageclass.MaskPhysical, { 1310687, 1310785, 1310786 })                             -- Sniper Shot, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical,       { 1317257 })                                               -- Strider Kick, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical,       { 1293241, 1293525, 1293526, 1293527 })                    -- Summon Hawk, Forever only

	Dmg.Ticks(1, Enum.Damageclass.MaskArcane,   6,  { travels = true, area = true }, { 1510, 14294, 14295 })                                           -- Volley
	Dmg.Ticks(3, Enum.Damageclass.MaskNature,   15, { travels = true },              { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295 }) -- Serpent Sting
	Dmg.Ticks(2, Enum.Damageclass.MaskShadow,   30, { travels = true },              { 3674, 14296 })                                                  -- Black Arrow
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 21, {},                              { 24118, 24119, 24120, 1299332 })                                 -- Lacerate, the Hunter's

	-- Mage
	Dmg.Hits(Enum.Damageclass.MaskFrost,  { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 }) -- Frostbolt
	Dmg.Hits(Enum.Damageclass.MaskFrost,  { 120, 8492, 10159, 10160, 10161 })                                    -- Cone of Cold
	Dmg.Hits(Enum.Damageclass.MaskFrost,  { 122, 865, 6131, 10230 })                                             -- Frost Nova
	Dmg.Hits(Enum.Damageclass.MaskArcane, { 1449, 8437, 8438, 8439, 10201, 10202 })                              -- Arcane Explosion
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 2136, 2137, 2138, 8412, 8413, 10197, 10199 })                        -- Fire Blast
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 2948, 8444, 8445, 8446, 10205, 10206, 10207 })                       -- Scorch
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 11113, 13018, 13019, 13020, 13021 })                                 -- Blast Wave
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 2120, 2121, 8422, 8423, 10215, 10216 })                              -- Flamestrike; its DoT is left out (TickSpells.lua)
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 24530 })                                                             -- Felfire
	Dmg.Hits(Enum.Damageclass.MaskArcane, { 400574 })                                                            -- Arcane Blast
	Dmg.Hits(Enum.Damageclass.MaskFrost,  { 400640 })                                                            -- Ice Lance
	Dmg.Hits(Enum.Damageclass.MaskArcane, { 1239696, 1239697, 1239699, 1239700 })                                -- Arcane Blast, Forever's ranks
	Dmg.Hits(Enum.Damageclass.MaskFrost,  { 1240044, 1240045, 1240046, 1240047, 1312002 })                       -- Ice Lance, Forever's ranks
	Dmg.Hits(Enum.Damageclass.MaskFrost,  { 1326053, 1326054, 1326055 })                                         -- Frost Blast, Forever only
	Dmg.Hits(Enum.Damageclass.MaskArcane, { 1326079, 1326080, 1326081, 1326082 })                                -- Arcane Wrath, Forever only

	Dmg.Ticks(1, Enum.Damageclass.MaskFrost,                             8,  { area = true },                 { 10, 6141, 8427, 10185, 10186, 10187 })                                      -- Blizzard
	Dmg.Ticks(2, Enum.Damageclass.MaskFire,                              8,  { hits = true, travels = true }, { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 }) -- Fireball
	Dmg.Ticks(3, Enum.Damageclass.MaskFire,                              12, { hits = true, travels = true }, { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 })                   -- Pyroblast
	Dmg.Ticks(3, Enum.Damageclass.MaskFire + Enum.Damageclass.MaskFrost, 9,  { hits = true, travels = true }, { 401502 })                                                                   -- Frostfire Bolt
	Dmg.Ticks(3, Enum.Damageclass.MaskFire + Enum.Damageclass.MaskFrost, 9,  { hits = true, travels = true }, { 1237312, 1237313 })                                                         -- Frostfire Bolt, Forever's ranks (interval untested)

	-- Paladin
	Dmg.Hits(Enum.Damageclass.MaskHoly, { 879, 5614, 5615, 10312, 10313, 10314 })          -- Exorcism
	Dmg.Hits(Enum.Damageclass.MaskHoly, { 2812, 10318 })                                   -- Holy Wrath
	Dmg.Hits(Enum.Damageclass.MaskHoly, { 24239, 24274, 24275 })                           -- Hammer of Wrath
	Dmg.Hits(Enum.Damageclass.MaskHoly, { 678, 679, 680, 1866, 2495, 5569, 10332, 10333 }) -- Holy Strike, Forever only
	Dmg.Hits(Enum.Damageclass.MaskHoly, { 1311606, 20473, 20929, 20930 })                  -- Holy Shock; Forever's first rank, then the Classic ranks
	Dmg.Hits(Enum.Damageclass.MaskHoly, { 407632 })                                        -- Hammer of the Righteous
	Dmg.Judges(                         { 20271 })                                         -- Judgement

	-- Priest
	Dmg.Hits(Enum.Damageclass.MaskHoly,   { 585, 591, 598, 984, 1004, 6060, 10933, 10934 })            -- Smite
	Dmg.Hits(Enum.Damageclass.MaskShadow, { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947 }) -- Mind Blast
	Dmg.Hits(Enum.Damageclass.MaskHoly,   { 15237, 15430, 15431, 27799, 27800, 27801 })                -- Holy Nova
	Dmg.Hits(Enum.Damageclass.MaskHoly,   { 1277331, 1277332, 1277333, 1277334, 1277335 })             -- Chastise, Forever only
	Dmg.Hits(Enum.Damageclass.MaskShadow, { 1309595, 1309633, 1309635, 1309636 })                      -- Shadow Word: Death, Forever only

	Dmg.Ticks(3, Enum.Damageclass.MaskShadow, 24, {},              { 589, 594, 970, 992, 2767, 10892, 10893, 10894 })          -- Shadow Word: Pain
	Dmg.Ticks(3, Enum.Damageclass.MaskShadow, 24, {},              { 2944, 19276, 19277, 19278, 19279, 19280 })                -- Devouring Plague
	Dmg.Ticks(1, Enum.Damageclass.MaskArcane, 6,  {},              { 10797, 19296, 19299, 19302, 19303, 19304, 19305 })        -- Starshards
	Dmg.Ticks(2, Enum.Damageclass.MaskHoly,   10, { hits = true }, { 14914, 15261, 15262, 15263, 15264, 15265, 15266, 15267 }) -- Holy Fire
	Dmg.Ticks(1, Enum.Damageclass.MaskShadow, 3,  {},              { 15407, 17311, 17312, 17313, 17314, 18807 })               -- Mind Flay
	Dmg.Ticks(1, Enum.Damageclass.MaskHoly,   2,  { hits = true }, { 402174, 1240720, 1240721, 1316995 })                      -- Penance, Forever only (untested; may hit, not tick)

	-- Rogue
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 53, 2589, 2590, 2591, 8721, 11279, 11280, 11281, 25300 })  -- Backstab
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1752, 1757, 1758, 1759, 1760, 8621, 11293, 11294 })        -- Sinister Strike
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1766, 1767, 1768, 1769 })                                  -- Kick
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1776, 1777, 8629, 11285, 11286 })                          -- Gouge
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 31016 }) -- Eviscerate
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 8676, 8724, 8725, 11267, 11268, 11269 })                   -- Ambush
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 14251 })                                                   -- Riposte
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 14278 })                                                   -- Ghostly Strike
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 16511 })                                                   -- Hemorrhage
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1329283, 1329549 })                                        -- Shank, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1310707, 399956, 1241582, 1241584 })                       -- Mutilate, Forever only

	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 18, {}, { 703, 8631, 8632, 8633, 11289, 11290 })   -- Garrote
	Dmg.Ticks(2, Enum.Damageclass.MaskPhysical, 16, {}, { 1943, 8639, 8640, 11273, 11274, 11275 }) -- Rupture
	Dmg.Ticks(6, Enum.Damageclass.MaskPhysical, 6,  {}, { 1316709, 1325756, 1325757, 1325758 })    -- Death Mark, Forever only (one tick as it ends; untested)

	-- Shaman
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208 }) -- Lightning Bolt
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 421, 930, 2860, 10605 })                                     -- Chain Lightning
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 8042, 8044, 8045, 8046, 10412, 10413, 10414 })               -- Earth Shock
	Dmg.Hits(Enum.Damageclass.MaskFrost,    { 8056, 8058, 10472, 10473 })                                  -- Frost Shock
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 17364 })                                                     -- Stormstrike
	Dmg.Hits(Enum.Damageclass.MaskFire,     { 408490 })                                                    -- Lava Burst
	Dmg.Hits(Enum.Damageclass.MaskFire,     { 1238299, 1238300, 1326047 })                                 -- Lava Burst, Forever's ranks

	Dmg.Ticks(3, Enum.Damageclass.MaskFire, 12, { hits = true }, { 8050, 8052, 8053, 10447, 10448, 29228 }) -- Flame Shock

	-- Warlock
	Dmg.Hits(Enum.Damageclass.MaskShadow, { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 }) -- Shadow Bolt
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 5676, 17919, 17920, 17921, 17922, 17923 })                     -- Searing Pain
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 6353, 17924 })                                                 -- Soul Fire
	Dmg.Hits(Enum.Damageclass.MaskShadow, { 6789, 17925, 17926 })                                          -- Death Coil
	Dmg.Hits(Enum.Damageclass.MaskShadow, { 17877, 18867, 18868, 18869, 18870, 18871 })                    -- Shadowburn
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 17962, 18930, 18931, 18932 })                                  -- Conflagrate
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 412758 })                                                      -- Incinerate
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 1293812, 1293813 })                                            -- Incinerate, Forever's ranks
	Dmg.Hits(Enum.Damageclass.MaskFire,   { 1293817, 1293818 })                                            -- Conflagrate, Forever's ranks

	Dmg.Ticks(3, Enum.Damageclass.MaskShadow, 18, {},              { 172, 6222, 6223, 7648, 11671, 11672, 25311 })       -- Corruption
	Dmg.Ticks(3, Enum.Damageclass.MaskFire,   15, { hits = true }, { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 }) -- Immolate
	Dmg.Ticks(1, Enum.Damageclass.MaskShadow, 5,  {},              { 689, 699, 709, 7651, 11699, 11700 })                -- Drain Life
	Dmg.Ticks(2, Enum.Damageclass.MaskShadow, 24, {},              { 980, 1014, 6217, 11711, 11712, 11713 })             -- Curse of Agony; Bane of Agony on Forever
	Dmg.Ticks(3, Enum.Damageclass.MaskShadow, 15, {},              { 1120, 8288, 8289, 11675 })                          -- Drain Soul
	Dmg.Ticks(2, Enum.Damageclass.MaskFire,   8,  { area = true }, { 5740, 6219, 11677, 11678 })                         -- Rain of Fire
	Dmg.Ticks(3, Enum.Damageclass.MaskShadow, 30, {},              { 18265, 18879, 18880, 18881 })                       -- Siphon Life
	Dmg.Ticks(1, Enum.Damageclass.MaskShadow, 6,  {},              { 1316697 })                                          -- Wrack, Forever only (a channel)

	-- Warrior
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 72, 1671, 1672 })                                               -- Shield Bash
	Dmg.ReplacesSwing(                      { 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 25712 }) -- Heroic Strike
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 694, 7400, 7402, 20559, 20560 })                                -- Mocking Blow
	Dmg.ReplacesSwing(                      { 845, 7369, 11608, 11609, 20569 })                               -- Cleave
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1464, 8820, 11604, 11605 })                                     -- Slam
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1680 })                                                         -- Whirlwind
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1715, 7372, 7373, 27584 })                                      -- Hamstring
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 6343, 8198, 8204, 8205, 11580, 11581 })                         -- Thunder Clap
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 6552, 6554 })                                                   -- Pummel
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 6572, 6574, 7379, 11600, 11601, 25288 })                        -- Revenge
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 7384, 7887, 11584, 11585 })                                     -- Overpower
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 12294, 21551, 21552, 21553, 27580 })                            -- Mortal Strike
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 23881, 23892, 23893, 23894 })                                   -- Bloodthirst
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 23922, 23923, 23924, 23925 })                                   -- Shield Slam
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 402927 })                                                       -- Victory Rush
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1240193 })                                                      -- Slam, Forever's rank
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1310222 })                                                      -- Spearing Strike, Forever only

	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 21, {}, { 772, 6546, 6547, 6548, 11572, 11573, 11574 }) -- Rend

	-- Pets
	Dmg.Hits(Enum.Damageclass.MaskFire,     { 3110, 7799, 7800, 7801, 7802, 9057, 11762, 11763, 15598, 18187 }) -- Firebolt, the Imp's
	Dmg.Hits(Enum.Damageclass.MaskShadow,   { 7814, 7815, 7816, 11778, 11779, 11780 })                          -- Lash of Pain, the Succubus's
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 3009, 3010, 16827, 16828, 16829, 16830, 16831, 16832 })           -- Claw
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 17253, 17255, 17256, 17257, 17258, 17259, 17260, 17261 })         -- Bite
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 24844, 25008, 25009, 25010, 25011, 25012 })                       -- Lightning Breath
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 24423, 24577, 24578, 24579 })                                     -- Demoralizing Screech (Screech in Classic)
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 26090, 26187, 26188, 1264455 })                                   -- Thunderstomp
	Dmg.Hits(Enum.Damageclass.MaskFire,     { 444678, 444681 })                                                 -- Lava Breath
	Dmg.Hits(Enum.Damageclass.MaskNature,   { 1264478, 1264479, 1264480, 1264481, 1264482 })                    -- Sonic Blast, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1264494, 1264497, 1264498, 1264501, 1264502 })                    -- Swipe, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1264735, 1264736, 1264739, 1264741, 1264742 })                    -- Pinch, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1264758, 1264927, 1264929, 1264930, 1264933 })                    -- Dismember, Forever only
	Dmg.Hits(Enum.Damageclass.MaskPhysical, { 1265054, 1265055, 1265056, 1265057, 1265058 })                    -- Mine!, Forever only

	Dmg.Ticks(2, Enum.Damageclass.MaskNature,   10, {}, { 24583, 24586, 24587, 24640 })                  -- Scorpid Poison
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 9,  {}, { 1265038, 1265039, 1265040, 1265041, 1265042 }) -- Tendon Rip, Forever only
	Dmg.Ticks(3, Enum.Damageclass.MaskPhysical, 18, {}, { 1265065, 1265066, 1265067, 1265068, 1265069 }) -- Savage Rend, Forever only
	Dmg.Ticks(1, Enum.Damageclass.MaskNature,   4,  {}, { 1265843, 1265878, 1265880, 1265881, 1265883 }) -- Web, Forever only

	Dmg.SealsWith(true,  { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 21084 }) -- Righteousness
	Dmg.SealsWith(true,  { 20375, 20915, 20918, 20919, 20920 })                             -- Command
	Dmg.SealsWith(true,  { 20163, 20419, 20421, 20422, 20423, 1311649, 1311656 })           -- Fury, Forever only
	Dmg.SealsWith(false, { 20164 })                                                         -- Justice
	Dmg.SealsWith(false, { 20165, 20347, 20348, 20349 })                                    -- Light
	Dmg.SealsWith(false, { 20166, 20356, 20357 })                                           -- Wisdom
	Dmg.SealsWith(false, { 20162, 20305, 20306, 20307, 20308, 21082 })                      -- the Crusader
	Dmg.SealsWith(false, { 407798 })                                                        -- Martyrdom
	Dmg.Consecrates(     { 20116, 20922, 20923, 20924, 26573 })                             -- Consecration

	Dmg.Reports = { WOUND = "damage" }
	for _, missType in ipairs(Dmg.LogFilter.missTypes) do
		Dmg.Reports[missType] = "miss"
	end

	Dmg.EnemyTokens = { target = true, softenemy = true, softinteract = true }

	-- The OnUpdate runs only while something waits
	Dmg.eventFrame = CreateFrame("Frame")
	Dmg.eventFrame:Hide()
	Dmg.eventFrame:SetScript("OnEvent", Dmg.OnEvent)
	Dmg.eventFrame:SetScript("OnUpdate", Dmg.OnUpdate)

	-- State
	Dmg.onHit = nil
	Dmg.seq   = 0 -- counts events, to order those of one batch

	Dmg.lives            = { player = Dmg.NewLife(), pet = Dmg.NewLife() } -- token -> its unit's life
	Dmg.lives.player.own = true
	Dmg.lives.pet.own    = true
	Dmg.plates           = {} -- nameplate frame -> its life, kept for the session

	-- Hits on an enemy with no nameplate still use up their line and cast. The reports of a batch on
	-- the tokens that can name such an enemy are taken to name one.
	Dmg.noPlate = Dmg.NewLife()

	-- The batch: every event of one rendered frame, which share a GetTime()
	Dmg.batchTime     = nil
	Dmg.batchHits     = {}
	Dmg.batchLines    = {}
	Dmg.batchSwung    = nil -- the player swung in this batch
	Dmg.nextSwingCast = nil

	Dmg.waiting     = {} -- lines no hit has taken yet, oldest first
	Dmg.pending     = {} -- hits no line has taken yet, oldest first
	Dmg.paired      = {} -- hits paired since the last emit
	Dmg.casts       = {} -- the player's and pet's casts, oldest first
	Dmg.swings      = {} -- times of the player's landed swing lines
	Dmg.swingDelays = { player = {}, pet = {} } -- each owner's latest clean swing delays, oldest first
	Dmg.swingClocks = {} -- the swing lines whose window is open, to learn delays from
	Dmg.lastStrike  = nil
	Dmg.palette     = nil -- line kind -> its color under the picked filter
	Dmg.paletteOf   = nil -- the filter the palette was read from
	Dmg.weaponProcs = {} -- the procs of the enchants on the player's weapons
	Dmg.spare       = {} -- wiped record tables to reuse

	-- Scratch for spell identity
	Dmg.candidates = {}
	Dmg.tried      = {}
end

function Dmg.AddSpell(spell, ids)
	for _, id in ipairs(ids) do
		Dmg.Spells[id] = spell
	end
end

function Dmg.Hits(school, ids)       Dmg.AddSpell({ school = school,                        explains = { direct = Dmg.Time.Direct }, strike = school == Enum.Damageclass.MaskPhysical }, ids) end
function Dmg.RangedHits(school, ids) Dmg.AddSpell({ school = school,                        explains = { direct = Dmg.Time.Direct }                                                   }, ids) end
function Dmg.Shoots(school, ids)     Dmg.AddSpell({ school = school,                        explains = { shot = Dmg.Time.ShotFlight }                                                 }, ids) end
function Dmg.Judges(ids)             Dmg.AddSpell({ school = Enum.Damageclass.MaskHoly,     explains = { direct = Dmg.Time.Judgement }, nearness = true                               }, ids) end
function Dmg.ReplacesSwing(ids)      Dmg.AddSpell({ school = Enum.Damageclass.MaskPhysical, explains = { direct = Dmg.Time.Direct }, strike = true, nextSwing = true                  }, ids) end
function Dmg.SealsWith(proc, ids)    Dmg.AddSpell({ seal = proc,                            explains = {}                                                                             }, ids) end
function Dmg.Consecrates(ids)        Dmg.AddSpell({ consecration = true,                    explains = {}                                                                             }, ids) end
function Dmg.Ticks(interval, school, duration, kind, ids)
	Dmg.AddSpell({
		interval = interval,
		school   = school,
		duration = duration,
		landing  = kind.hits and kind.travels,
		travels  = kind.travels,
		area     = kind.area,
		explains = { direct = kind.hits and Dmg.Time.Direct or nil                                },
		misses   = { direct = kind.travels and not kind.area and Dmg.Time.Direct or Dmg.Time.Miss },
	}, ids)
end

function Dmg.ProcsFrom(school, enchants)
	for enchantID, spellID in pairs(enchants) do
		Dmg.EnchantProcs[enchantID] = { spellID = spellID, school = school }
	end
end

-- unitID counts the units a nameplate frame has shown; a hit is shown only while its frame still
-- shows the unit it came for
function Dmg.NewLife(frame)
	return { frame = frame, unitID = 0, first = {}, rhythms = {} }
end

----------------------------------------------------------------------------------------------------
-- Pairing: the line that proves a hit is ours

function Dmg.IsPhysical(hit)
	return not issecretvalue(hit.school) and hit.school == Enum.Damageclass.MaskPhysical
end

function Dmg.IsShotTarget(hit)
	for _, cast in ipairs(Dmg.casts) do
		local onUnit = cast.target == hit.life and cast.targetID == hit.unitID
		local flight = cast.spell.explains.shot
		if onUnit and flight and cast.unit == "player" and hit.time - cast.time <= flight then
			return true
		end
	end
	return false
end

function Dmg.InWindow(window, hit, line)
	local age = hit.time - line.time
	return age >= window.from and age <= window.to
		and line.kind.accepts == Dmg.Reports[hit.action]
		and (not window.swing or Dmg.IsPhysical(hit))
		and (not window.shotTarget or Dmg.IsShotTarget(hit))
		and (not window.delay or Dmg.AtSwingDelay(line, age))
end

function Dmg.AtSwingDelay(line, age)
	local delays = Dmg.swingDelays[line.pet and "pet" or "player"]
	if #delays < Dmg.SwingDelay.min then
		return true
	end
	local near = 0
	for _, delay in ipairs(delays) do
		if abs(delay - age) <= Dmg.SwingDelay.near then
			near = near + 1
		end
	end
	return near >= Dmg.SwingDelay.pair and near >= Dmg.SwingDelay.share * #delays
end

-- Whether the hit's school is known to be, or known not to be (right false), one the line's spell can
-- have: a tick's, an active DoT's; a shot's, one in flight's. Only a wound's school counts, as a miss
-- reports physical.
function Dmg.SchoolIs(hit, line, right)
	if hit.action ~= "WOUND" or issecretvalue(hit.school) then
		return false
	end
	local group          = line.kind.group
	local known, matches = false, false
	for _, cast in ipairs(Dmg.casts) do
		local spell  = cast.spell
		local dot    = group == "tick" and spell.interval and not spell.area
			and hit.time <= cast.time + spell.duration + Dmg.Time.DotSlack
		local flying = group == "shot" and spell.explains.shot and hit.time - cast.time <= spell.explains.shot
		if (dot or flying) and spell.school then
			known   = true
			matches = matches or spell.school == hit.school
		end
	end
	return known and matches == right
end

-- Another player's hit can come in the frame of our tick, or before our shot's, so a hit known to be
-- the wrong school passes a tick or shot line by: a shot line waits for its school, and takes this hit
-- if none comes (Timing); a tick line goes to a later hit of its frame that's of its school. A hit
-- that suits another kind of line in its frame could be ours, so it keeps the usual order. `from` is
-- the first of the frame's hits still to pair, nil for a waiting line.
function Dmg.Takes(hit, line, lines, from)
	if not Dmg.SchoolIs(hit, line, false) then
		return true
	end
	if line.kind.group == "shot" then
		return false
	end
	if not from then
		return true
	end
	for _, other in ipairs(lines) do
		local direct = other.kind.group ~= "tick" and other.kind.group ~= "shot" and other.kind.timing ~= Dmg.Timing.Swing
		if direct and other.kind.accepts == Dmg.Reports[hit.action] then
			return true
		end
	end
	for i = from, #Dmg.batchHits do
		local other = Dmg.batchHits[i]
		if not other.life.own and line.kind.accepts == Dmg.Reports[other.action] and Dmg.SchoolIs(other, line, true) then
			return false
		end
	end
	return true
end

-- Pairs the hit with the first line in the list it can take, and says whether it found one. A hit
-- in an older swing line's window, though off its delay, waits on that line, and leaves a newer weapon
-- proc's line for the proc's own hit.
function Dmg.Pair(hit, lines, from)
	local offDelay = false
	for i, line in ipairs(lines) do
		if not (offDelay and line.timing == Dmg.Timing.Proc) then
			for _, window in ipairs(line.timing.windows) do
				if Dmg.InWindow(window, hit, line) and Dmg.Takes(hit, line, lines, from) then
					hit.line, hit.swing = table.remove(lines, i), window.swing
					return true
				end
			end
		end
		offDelay = offDelay or line.timing == Dmg.Timing.Swing and Dmg.InWindow(Dmg.Windows.OffDelay, hit, line)
	end
	return false
end

function Dmg.Free(record)
	wipe(record)
	table.insert(Dmg.spare, record)
end

function Dmg.Prune(list, now, age)
	local old = 0
	while list[old + 1] and now - list[old + 1].time > age do
		old = old + 1
		Dmg.Free(list[old])
	end
	for i = 1, old > 0 and #list or 0 do
		list[i] = list[i + old]
	end
end

-- Hands each line nobody took to the oldest waiting hit it can be, once no newer hit can take it,
-- and drops the lines and hits that can no longer pair
function Dmg.Settle(now)
	local i = 1
	while Dmg.waiting[i] do
		local line    = Dmg.waiting[i]
		local age     = now - line.time
		local claimed = false
		if age > line.timing.claim and not line.offered then
			line.offered = true
			for _, window in ipairs(line.timing.unclaimed) do
				local j = Dmg.Waiter(window, line)
				if j then
					local hit = table.remove(Dmg.pending, j)
					hit.line, hit.swing = line, window.swing
					table.insert(Dmg.paired, hit)
					claimed = true
					break
				end
			end
		end
		if claimed then
			table.remove(Dmg.waiting, i)
		elseif age > line.timing.windows[#line.timing.windows].to then
			Dmg.Free(table.remove(Dmg.waiting, i))
		else
			i = i + 1
		end
	end
	Dmg.Prune(Dmg.pending, now, Dmg.Time.MeleeTo)
end

----------------------------------------------------------------------------------------------------
-- Identity: which spell made a hit. Everything that could explain the hit is a candidate, keyed by
-- the spell it would name, and the hit gets a spell only when exactly one key remains. Casts of one
-- spell share a key, so of two bolts in flight the older is used. A secret cast, a pet's cast, and
-- a nearness spell during Consecration are each a key of their own that names nothing.

function Dmg.IsConsecrated(hit)
	for _, cast in ipairs(Dmg.casts) do
		if cast.unit == "player" and (cast.spell == Dmg.Secret or cast.spell.consecration)
			and cast.seq < hit.seq and hit.time - cast.time <= Dmg.Time.Consecration then
			return true
		end
	end
	return false
end

-- The active seal's proc: the last seal cast before the hit, a landed swing just before, and no
-- Consecration to mistake it for. A secret cast could be any seal.
function Dmg.SealProcOf(hit)
	local seal
	for _, cast in ipairs(Dmg.casts) do
		if cast.unit == "player" and (cast.spell == Dmg.Secret or cast.spell.seal ~= nil) and cast.seq < hit.seq then
			seal = cast
		end
	end
	local active = seal and seal.spell.seal and hit.time - seal.time <= Dmg.Time.SealDuration
	if not active or Dmg.IsConsecrated(hit) then return nil end

	for _, time in ipairs(Dmg.swings) do
		local since = hit.time - time
		if since >= 0 and since <= Dmg.Time.SealProc then
			return seal.spellID
		end
	end
end

function Dmg.Candidate(key, cast)
	if Dmg.candidates.key == nil then
		Dmg.candidates.key, Dmg.candidates.cast = key, cast
	elseif Dmg.candidates.key ~= key then
		Dmg.candidates.ambiguous = true
	end
end

function Dmg.IdentifyDirect(hit, group, school, miss)
	wipe(Dmg.candidates)
	for _, cast in ipairs(Dmg.casts) do
		local spell      = cast.spell
		local age        = hit.time - cast.time
		local limit      = (miss and spell.misses or spell.explains)[group]
		local schoolFits = not (school and spell.school and spell.school ~= school)
		if not cast.used and limit and age >= 0 and age <= limit and schoolFits then
			local names = spell ~= Dmg.Secret and cast.unit == "player" and not (spell.nearness and Dmg.IsConsecrated(hit))
			Dmg.Candidate(names and cast.spellID or cast, cast)
		end

		-- An area spell ticks a whole number of intervals after its last tick on any unit, until its
		-- duration ends or its channel stops. One that travels lands up to Time.Direct late.
		local tick    = Dmg.Time.Tick
		local area    = group == "direct" and spell.area and cast.unit == "player" and (not school or spell.school == school)
		local ongoing = area and age <= spell.duration + tick and not (cast.stopped and hit.time > cast.stopped + tick)
		if ongoing then
			local from    = cast.lastTick or cast.time
			local steps   = floor((hit.time - from) / spell.interval + 0.5)
			local due     = steps >= 1 or (steps == 0 and cast.lastTick)
			local onGrid  = due and abs(hit.time - from - steps * spell.interval) <= tick
			local landing = not cast.lastTick and spell.travels
			local landed  = landing and age >= spell.interval - tick and age <= spell.interval + tick + Dmg.Time.Direct
			if onGrid or landed then
				cast.lastTick = hit.time
				Dmg.Candidate(cast.spellID)
			end
		end
	end
	-- A weapon enchant's proc: its line comes just after a strike
	if group == "direct" and school and hit.line.afterStrike then
		for _, proc in ipairs(Dmg.weaponProcs) do
			if proc.school == school then
				Dmg.Candidate(proc.spellID)
			end
		end
	end
	if group == "direct" and school == Enum.Damageclass.MaskHoly then
		local seal = Dmg.SealProcOf(hit)
		if seal then
			Dmg.Candidate(seal)
		end
	end
	if Dmg.candidates.ambiguous or not Dmg.candidates.key then return nil end

	local cast = Dmg.candidates.cast
	if cast then
		cast.used = true
	end
	if type(Dmg.candidates.key) ~= "number" then return nil end

	local spell = Dmg.Spells[Dmg.candidates.key]
	if cast and spell.interval and miss then
		cast.missed = true
	elseif cast and spell.landing then
		-- The landing replaces the DoT, so its old rhythm on this unit ends
		local rhythm = hit.life.rhythms[Dmg.candidates.key] or {}
		hit.life.rhythms[Dmg.candidates.key] = rhythm
		rhythm.source, rhythm.last, rhythm.ends = hit.time, nil, nil
	end
	return Dmg.candidates.key
end

function Dmg.FirstTickFits(hit, spell, from, extra)
	local since = hit.time - from
	return since >= spell.interval - Dmg.Time.Tick and since <= spell.interval + Dmg.Time.Tick + extra
end

-- Whether this tick fits the spell's rhythm on the unit, updating it: the first tick one interval
-- after its cast (or its landing, for one that travels and hits), then one interval after the last
-- until its duration ends. A first tick starts the rhythm over, as a refresh does.
function Dmg.TickFits(hit, spellID, spell, rhythms)
	local rhythm = rhythms[spellID]
	local source
	if spell.landing then
		source = rhythm and not rhythm.last and Dmg.FirstTickFits(hit, spell, rhythm.source, 0) and rhythm.source or nil
	else
		for _, cast in ipairs(Dmg.casts) do
			if cast.spellID == spellID and cast.unit == "player" and not cast.missed and not (rhythm and rhythm.source == cast.time)
				and Dmg.FirstTickFits(hit, spell, cast.time, spell.travels and Dmg.Time.Direct or 0) then
				source = cast.time
			end
		end
	end
	if source then
		rhythm = rhythm or {}
		rhythms[spellID] = rhythm
		rhythm.source, rhythm.last, rhythm.ends = source, hit.time, hit.time - spell.interval + spell.duration
		return true
	end
	local onBeat  = rhythm and rhythm.last and abs(hit.time - rhythm.last - spell.interval) <= Dmg.Time.Tick
	local lasting = onBeat and hit.time <= rhythm.ends + Dmg.Time.Tick
	if lasting then
		rhythm.last = hit.time
		return true
	end
	return false
end

-- Every spell that fits keeps its rhythm, so a tie doesn't end the rhythm of the one that ticked
function Dmg.IdentifyTick(hit, school, crowded)
	local lifeRhythms = hit.life.rhythms

	wipe(Dmg.tried)
	for spellID in pairs(lifeRhythms) do
		Dmg.tried[spellID] = true
	end
	for _, cast in ipairs(Dmg.casts) do
		if cast.unit == "player" and cast.spellID then
			Dmg.tried[cast.spellID] = true
		end
	end

	wipe(Dmg.candidates)
	Dmg.candidates.ambiguous = crowded
	for spellID in pairs(Dmg.tried) do
		local spell = Dmg.Spells[spellID]
		local ticks = spell.interval and not spell.area and not (school and spell.school ~= school)
		if ticks and Dmg.TickFits(hit, spellID, spell, lifeRhythms) then
			Dmg.Candidate(spellID)
		end
	end
	return not Dmg.candidates.ambiguous and Dmg.candidates.key or nil
end

-- A miss reports school 1 whatever the spell, so its school tells nothing. Two ticks of one school
-- at one time on one unit (crowded) can't be told apart.
function Dmg.Identify(hit)
	local kind   = hit.line.kind
	local miss   = kind.accepts == "miss"
	local school = not miss and not issecretvalue(hit.school) and hit.school or nil
	if kind.group == "shield" then
		return Dmg.Shields[school]
	end
	if kind.group == "tick" then
		local crowded = false
		for _, other in ipairs(Dmg.paired) do
			local together = other ~= hit and other.line.kind.crowds and other.life == hit.life and other.time == hit.time
			if together and (issecretvalue(hit.school) or issecretvalue(other.school) or hit.school == other.school) then
				crowded = true
			end
		end
		return Dmg.IdentifyTick(hit, school, crowded)
	end
	return kind.group and Dmg.IdentifyDirect(hit, kind.group, school, miss)
end

----------------------------------------------------------------------------------------------------
-- Batches: every event of one rendered frame shares a GetTime()

function Dmg.EmitPaired()
	for _, hit in ipairs(Dmg.paired) do
		if hit.line.kind.timing ~= Dmg.Timing.Swing then
			for _, clock in ipairs(Dmg.swingClocks) do
				clock.tookOther = clock.tookOther or clock.hitSeq == hit.seq
			end
		end
		-- A hit whose nameplate now shows another unit can't be shown, and identifying it would touch
		-- that unit's rhythms. One with no nameplate is still identified, to use up its cast. A
		-- swing, weapon procs included, has no cast to find.
		local current = hit.unitID == hit.life.unitID
		hit.spellID = current and not hit.swing and Dmg.Identify(hit) or nil
		if current and hit.life.frame then
			hit.swinger = hit.swing and (hit.line.pet and "pet" or "player") or nil
			hit.frame   = hit.life.frame
			Dmg.onHit(hit)
		end
	end
	for _, hit in ipairs(Dmg.paired) do
		Dmg.Free(hit.line)
		Dmg.Free(hit)
	end
	wipe(Dmg.paired)
end

-- The oldest waiting hit in the window of the line
function Dmg.Waiter(window, line)
	for j, hit in ipairs(Dmg.pending) do
		if Dmg.InWindow(window, hit, line) then
			return j
		end
	end
end

-- Learns from the swing lines whose window has closed, counts the batch's hits in the windows still
-- open, and opens one for each swing line of the batch. Any physical hit or avoid on an enemy counts,
-- ours or not, as another player's makes a swing unclean. A swing teaches nothing when its one hit took
-- another kind of line (EmitPaired), and two swing lines of one sort whose windows overlap teach nothing.
function Dmg.LearnSwingDelays()
	local now = Dmg.batchTime
	while Dmg.swingClocks[1] and now - Dmg.swingClocks[1].time > Dmg.Time.MeleeTo do
		local clock = table.remove(Dmg.swingClocks, 1)
		if clock.hits == 1 and not clock.crowded and not clock.tookOther then
			local delays = Dmg.swingDelays[clock.owner]
			table.insert(delays, clock.delay)
			if #delays > Dmg.SwingDelay.keep then
				table.remove(delays, 1)
			end
		end
		Dmg.Free(clock)
	end
	for _, hit in ipairs(Dmg.batchHits) do
		if not hit.life.own and (hit.action ~= "WOUND" or Dmg.IsPhysical(hit)) then
			for _, clock in ipairs(Dmg.swingClocks) do
				local age = hit.time - clock.time
				if age >= Dmg.Time.MeleeFrom and age <= Dmg.Time.MeleeTo and clock.accepts == Dmg.Reports[hit.action] then
					clock.hits, clock.hitSeq, clock.delay = clock.hits + 1, hit.seq, age
				end
			end
		end
	end
	for _, line in ipairs(Dmg.batchLines) do
		if line.kind.timing == Dmg.Timing.Swing then
			local clock = table.remove(Dmg.spare) or {}
			clock.time, clock.owner, clock.accepts, clock.hits = line.time, line.pet and "pet" or "player", line.kind.accepts, 0
			for _, other in ipairs(Dmg.swingClocks) do
				if other.accepts == clock.accepts and line.time - other.time <= Dmg.Time.MeleeTo then
					other.crowded, clock.crowded = true, true
				end
			end
			table.insert(Dmg.swingClocks, clock)
		end
	end
end

-- In a next-swing ability's frame its target gets an empty physical report, then the ability's
-- line, then the real report. Amounts are secret, so that shape is what finds the empty one.
function Dmg.DropEmptyReport()
	local lineSeq
	for _, line in ipairs(Dmg.batchLines) do
		if line.kind.nextSwing then
			lineSeq = line.seq
			break
		end
	end
	if not lineSeq then return end

	local before, index, hasAfter
	for i, hit in ipairs(Dmg.batchHits) do
		local cast = Dmg.nextSwingCast
		if hit.life == cast.target and hit.seq > cast.seq and hit.action == "WOUND" and Dmg.IsPhysical(hit) then
			if hit.seq > lineSeq then
				hasAfter = true
			elseif before then
				return
			else
				before, index = hit, i
			end
		end
	end
	if before and hasAfter and issecretvalue(before.amount) then
		Dmg.Free(table.remove(Dmg.batchHits, index))
	end
end

function Dmg.CloseBatch()
	if Dmg.nextSwingCast and Dmg.nextSwingCast.time == Dmg.batchTime then
		Dmg.DropEmptyReport()
	end

	-- PLAYER_SWING comes only for the player's own swings, in the frame of the swing's line. Only now
	-- is every strike of the batch in: a line can come before its strike.
	for _, line in ipairs(Dmg.batchLines) do
		line.pet         = line.timing == Dmg.Timing.Swing and not Dmg.batchSwung and line.hasPet
		line.afterStrike = line.kind.group == "direct" and Dmg.lastStrike and line.time - Dmg.lastStrike <= Dmg.Time.ProcAfterStrike
		if line.kind.lands and not line.pet then
			table.insert(Dmg.swings, line.time)
		end
	end

	Dmg.Settle(Dmg.batchTime)
	Dmg.LearnSwingDelays()
	-- A hit takes a line of its own batch first, then the oldest waiting line. Enemy hits go first,
	-- so a mob's attack on us can't take the line of our hit.
	for i, hit in ipairs(Dmg.batchHits) do
		if not hit.life.own then
			local found = Dmg.Pair(hit, Dmg.batchLines, i + 1) or Dmg.Pair(hit, Dmg.waiting)
			table.insert(found and Dmg.paired or Dmg.pending, hit)
		end
	end
	-- Hits on us only use up the lines of our self-damage, in their own batch
	for _, hit in ipairs(Dmg.batchHits) do
		if hit.life.own then
			if Dmg.Pair(hit, Dmg.batchLines) then
				Dmg.Free(hit.line)
			end
			Dmg.Free(hit)
		end
	end
	for _, line in ipairs(Dmg.batchLines) do
		if line.afterStrike then
			line.timing = Dmg.Timing.Proc
		end
		table.insert(Dmg.waiting, line)
	end
	Dmg.EmitPaired()

	Dmg.batchTime, Dmg.batchSwung, Dmg.nextSwingCast = nil, nil, nil
	wipe(Dmg.batchHits)
	wipe(Dmg.batchLines)
end

----------------------------------------------------------------------------------------------------
-- Units

-- A unit's GUID can be secret, so a unit is found by the plate showing it
function Dmg.LifeOf(unit)
	return Dmg.lives[unit] or Dmg.plates[C_NamePlate.GetNamePlateForUnit(unit)]
end

-- A nameplate frame starts showing a unit
function Dmg.ShowPlate(token, frame)
	local life = Dmg.plates[frame] or Dmg.NewLife(frame)
	Dmg.plates[frame] = life
	Dmg.lives[token]  = life
	life.unitID       = life.unitID + 1
	life.hidAt        = nil
	life.guid         = nil
	wipe(life.rhythms)
end

-- A new time closes the open batch
function Dmg.OpenBatch(time)
	if Dmg.batchTime and time ~= Dmg.batchTime then
		Dmg.CloseBatch()
	end
	if not Dmg.batchTime and #Dmg.waiting == 0 and #Dmg.pending == 0 then
		Dmg.eventFrame:Show()
	end
	Dmg.batchTime = time
end

----------------------------------------------------------------------------------------------------
-- Log filter. Only the filter picked above the combat log tab sends lines, and its first part holds
-- the event types and Done By sources (Blizzard_CombatLogProcessor.lua, ApplyFilterSettings). The
-- game refuses a filter an addon changes mid-session, so the fix is written into Blizzard's saved
-- table at logout and Blizzard applies it at the next load.

-- Every part asks only for our lines, the first for our events at every destination, and whole lines
-- are colored by event type
function Dmg.FixSources(filter)
	for _, part in ipairs(filter.filters) do
		part.sourceFlags = CopyTable(Dmg.LogFilter.ownSources)
	end
	local part = filter.filters[1]
	part.destFlags = nil
	for _, kind in ipairs(Dmg.LineKinds) do
		for _, event in ipairs(kind.accepts and kind.events or {}) do
			part.eventList[event] = true
		end
	end
	filter.settings.lineColoring      = true
	filter.settings.lineColorPriority = Dmg.LogFilter.byKind
end

-- Each kind in our color, unhighlighted, and any other event the filter sends that could pass for a
-- kind back in Blizzard's grey
function Dmg.FixColors(filter)
	local colors = filter.colors
	colors.highlightedEvents = colors.highlightedEvents or {}
	local palette = {}
	for _, kind in ipairs(Dmg.LineKinds) do
		palette[kind] = kind
		for _, event in ipairs(kind.colored) do
			colors.eventColoring[event]     = { r = kind.r, g = kind.g, b = kind.b, a = 1 }
			colors.highlightedEvents[event] = nil
		end
	end
	for event in pairs(Dmg.SentEvents(filter)) do
		if not Dmg.KindOfEvent[event] and Dmg.Clashes(palette, filter, event) then
			colors.eventColoring[event]     = nil
			colors.highlightedEvents[event] = nil
		end
	end
end

function Dmg.FixFilter(filter)
	Dmg.FixSources(filter)
	Dmg.FixColors(filter)
end

-- Each kind's color under the filter, when it sends our lines and only ours, colored so each kind
-- reads back, in our colors or another addon's: MikScrollingBattleText writes its own filter at every
-- logout. Otherwise nil.
function Dmg.Palette(filter)
	local fixed = CopyTable(filter)
	Dmg.FixSources(fixed)
	return tCompare(fixed, filter, 4) and Dmg.ReadColors(filter) or nil
end

-- Each kind needs one color for all its events, unhighlighted, apart from every other kind's and
-- from Blizzard's grey, and no other event the filter sends may come near one
function Dmg.ReadColors(filter)
	local colors      = filter.colors
	local highlighted = filter.settings.lineHighlighting and colors.highlightedEvents or {}
	local palette     = {}
	for _, kind in ipairs(Dmg.LineKinds) do
		for _, event in ipairs(kind.colored) do
			local color = colors.eventColoring[event]
			if not color or highlighted[event] then
				return nil
			end
			if palette[kind] and not Dmg.Near(color.r, color.g, color.b, palette[kind], Dmg.LogFilter.savedTolerance) then
				return nil
			end
			palette[kind] = palette[kind] or color
		end
	end
	for kind, color in pairs(palette) do
		if Dmg.Near(color.r, color.g, color.b, Dmg.LogFilter.uncolored, Dmg.LogFilter.apart) then
			return nil
		end
		for other, otherColor in pairs(palette) do
			if other ~= kind and Dmg.Near(color.r, color.g, color.b, otherColor, Dmg.LogFilter.apart) then
				return nil
			end
		end
	end
	for event in pairs(Dmg.SentEvents(filter)) do
		if not Dmg.KindOfEvent[event] and Dmg.Clashes(palette, filter, event) then
			return nil
		end
	end
	return palette
end

-- Every event the filter sends. The game colors some lines by the event's name with a suffix, as a
-- dispel's by SPELL_DISPEL_DEBUFF, so a colored or highlighted name that extends a sent one counts.
function Dmg.SentEvents(filter)
	local sent, suffixed = {}, {}
	for _, part in ipairs(filter.filters) do
		for event, on in pairs(part.eventList or {}) do
			sent[event] = on or nil
		end
	end
	local colors = filter.colors
	for _, names in ipairs({ colors.eventColoring, colors.highlightedEvents or {} }) do
		for name in pairs(names) do
			for event in pairs(sent) do
				if name:sub(1, #event + 1) == event .. "_" then
					suffixed[name] = true
				end
			end
		end
	end
	for name in pairs(suffixed) do
		sent[name] = true
	end
	return sent
end

-- Whether an event's lines, in its color or Blizzard's grey and brighter when highlighted, come near
-- a kind's color, but for an alias in exactly its kind's
function Dmg.Clashes(palette, filter, event)
	local colors  = filter.colors
	local color   = colors.eventColoring[event] or Dmg.LogFilter.uncolored
	local lit     = filter.settings.lineHighlighting and (colors.highlightedEvents or {})[event]
	local bright  = lit and Dmg.LogFilter.highlight or 1
	local r, g, b = min(color.r * bright, 1), min(color.g * bright, 1), min(color.b * bright, 1)
	local alias   = Dmg.KindOfEvent[Dmg.LogFilter.aliases[event]]
	for kind, kindColor in pairs(palette) do
		local exactAlias = kind == alias and Dmg.Near(r, g, b, kindColor, Dmg.LogFilter.savedTolerance)
		if Dmg.Near(r, g, b, kindColor, Dmg.LogFilter.apart) and not exactAlias then
			return true
		end
	end
	return false
end

function Dmg.Near(r, g, b, color, tolerance)
	return abs(r - color.r) <= tolerance and abs(g - color.g) <= tolerance and abs(b - color.b) <= tolerance
end

-- The player or another addon can pick another filter at any time. A filter edited in place keeps its
-- palette until a reload.
function Dmg.PickedPalette()
	local saved  = Blizzard_CombatLog_Filters
	local filter = saved.filters[saved.currentFilter]
	if filter ~= Dmg.paletteOf then
		Dmg.paletteOf = filter
		Dmg.palette   = Dmg.Palette(filter)
	end
	return Dmg.palette
end

-- A picked filter that colors by event type but doesn't suit, and isn't the one we fix, is likely
-- another addon's, which would write it back at its next logout
function Dmg.Foreign(saved)
	local filter = saved.filters[saved.currentFilter]
	return filter.settings.lineColorPriority == Dmg.LogFilter.byKind and filter.name ~= QUICKBUTTON_NAME_MY_ACTIONS
end

function Dmg.MyActions(saved)
	for index, filter in ipairs(saved.filters) do
		if filter.name == QUICKBUTTON_NAME_MY_ACTIONS then
			return index, filter
		end
	end
end

function Dmg.KeepFilteredEvents()
	if not C_CombatLog.AreFilteredEventsEnabled() then
		C_CombatLog.SetFilteredEventsEnabled(true)
	end
end

----------------------------------------------------------------------------------------------------
-- Setup

function Dmg.Enable()
	Dmg.eventFrame:UnregisterAllEvents()
	Dmg.eventFrame:RegisterEvent("UNIT_COMBAT")
	Dmg.eventFrame:RegisterEvent("COMBAT_LOG_MESSAGE")
	Dmg.eventFrame:RegisterEvent("PLAYER_SWING")
	Dmg.eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	Dmg.eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	Dmg.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
	Dmg.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	Dmg.eventFrame:RegisterEvent("WEAPON_ENCHANT_CHANGED")
	Dmg.eventFrame:RegisterEvent("WEAPON_SLOT_CHANGED")
	Dmg.WEAPON_ENCHANT_CHANGED()

	for i = 1, 40 do
		local token = "nameplate" .. i
		if UnitExists(token) then
			Dmg.ShowPlate(token, C_NamePlate.GetNamePlateForUnit(token))
		end
	end

	Dmg.paletteOf = nil
	Dmg.KeepFilteredEvents()
	C_Timer.NewTicker(Dmg.LogFilter.keepAlive, Dmg.KeepFilteredEvents)
end

-- onHit(hit) gets each of our hits on an enemy nameplate, in a table reused once it returns: frame
-- (the nameplate's, which stays where its unit was after it hides), action, descriptor, amount,
-- school, spellID (or nil), swinger ("player", "pet", or nil). Without a suitable log filter it does
-- nothing that session, and fixes the filter at logout.
function Dmg.Init(func)
	Dmg.onHit = func
	Dmg.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	Dmg.eventFrame:RegisterEvent("PLAYER_LOGOUT")
end

----------------------------------------------------------------------------------------------------
-- Event Handlers

function Dmg.NAME_PLATE_UNIT_ADDED(token)
	Dmg.ShowPlate(token, C_NamePlate.GetNamePlateForUnit(token))
end

-- A killing blow's hit can come after its nameplate hid, on a target or soft target token. The
-- token still names the leaving unit here.
function Dmg.NAME_PLATE_UNIT_REMOVED(token)
	local time = GetTime()
	local life = Dmg.lives[token]
	Dmg.lives[token] = nil
	life.hidAt = time
	local guid = UnitGUID(token)
	life.guid = not issecretvalue(guid) and guid or nil
end

-- The game sends one report per token naming the unit. Each unit we care about reports through
-- player, pet, its nameplate, or with no nameplate a target token, so the rest are ignored, and
-- only the first token's reports count.
function Dmg.UNIT_COMBAT(token, action, descriptor, amount, school)
	local time = GetTime()
	local zero = action == "WOUND" and not issecretvalue(amount) and amount == 0
	if not Dmg.Reports[action] or zero then return end
	if not (Dmg.lives[token] or Dmg.EnemyTokens[token]) then return end

	-- Checked per report: a duel can make a unit attackable mid-fight. Our own reports through a
	-- target token stop here; they come through player and pet too.
	local life = Dmg.lives[token]
	if life and life.own and action ~= "WOUND" then return end
	if not (life and life.own) then
		local canAttack = UnitCanAttack("player", token)
		if not issecretvalue(canAttack) and not canAttack then return end
	end
	life = life or Dmg.LifeOf(token)
	if not life then
		local guid = UnitGUID(token)
		if guid and not issecretvalue(guid) then
			for _, plate in pairs(Dmg.plates) do
				local recent = plate.hidAt and time - plate.hidAt <= Dmg.Time.ProcTo
				if recent and plate.guid == guid and (not life or plate.hidAt > life.hidAt) then
					life = plate
				end
			end
		end
		life = life or Dmg.noPlate
	end
	Dmg.OpenBatch(time)

	if life.firstAt ~= time then
		life.firstAt = time
		wipe(life.first)
	end
	life.first[action] = life.first[action] or token
	if life.first[action] ~= token then return end

	local hit = table.remove(Dmg.spare) or {}
	hit.time       = time
	hit.seq        = Dmg.seq
	hit.life       = life
	hit.unitID     = life.unitID
	hit.action     = action
	hit.descriptor = descriptor
	hit.amount     = amount
	hit.school     = school
	table.insert(Dmg.batchHits, hit)
end

-- When a chat frame opens, the game resends old lines to fill it
function Dmg.COMBAT_LOG_MESSAGE(text, r, g, b, order)
	local time = GetTime()
	if order == Enum.CombatLogMessageOrder.Oldest then return end
	Dmg.OpenBatch(time)

	local palette = Dmg.PickedPalette()
	for _, kind in ipairs(palette and Dmg.LineKinds or {}) do
		if kind.accepts and Dmg.Near(r, g, b, palette[kind], Dmg.LogFilter.tolerance) then
			-- A shot's line can wait for its own hit and another line in the batch can't, so shot lines
			-- go last
			local at = #Dmg.batchLines + 1
			while kind.timing ~= Dmg.Timing.Shot and at > 1 and Dmg.batchLines[at - 1].timing == Dmg.Timing.Shot do
				at = at - 1
			end
			local hasPet = UnitExists("pet")
			local line   = table.remove(Dmg.spare) or {}
			line.time   = time
			line.seq    = Dmg.seq
			line.kind   = kind
			line.timing = kind.timing
			line.hasPet = not issecretvalue(hasPet) and hasPet
			table.insert(Dmg.batchLines, at, line)
			return
		end
	end
end

function Dmg.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
	local time   = GetTime()
	local secret = issecretvalue(spellID)
	local spell  = secret and Dmg.Secret or Dmg.Spells[spellID]
	if not spell then return end

	Dmg.OpenBatch(time)
	local cast = table.remove(Dmg.spare) or {}
	cast.time    = time
	cast.seq     = Dmg.seq
	cast.unit    = unit
	cast.spellID = not secret and spellID or nil
	cast.spell   = spell
	if spell.explains.shot or spell.nextSwing then
		cast.target   = Dmg.LifeOf("target")
		cast.targetID = cast.target and cast.target.unitID
	end
	Dmg.Prune(Dmg.casts, time, Dmg.Time.History)
	table.insert(Dmg.casts, cast)
	if unit == "player" and spell.strike then
		Dmg.lastStrike = time
	end
	if unit == "player" and spell.nextSwing then
		Dmg.nextSwingCast = cast
	end
end

function Dmg.UNIT_SPELLCAST_CHANNEL_STOP(unit, castGUID, spellID)
	local time = GetTime()
	if issecretvalue(spellID) then return end
	for _, cast in ipairs(Dmg.casts) do
		if cast.spellID == spellID and not cast.stopped then
			cast.stopped = time
			return
		end
	end
end

function Dmg.WEAPON_ENCHANT_CHANGED()
	wipe(Dmg.weaponProcs)
	for slot = INVSLOT_MAINHAND, INVSLOT_OFFHAND do
		local enchant = C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)
		local proc    = enchant and Dmg.EnchantProcs[enchant.enchantID]
		if proc then
			table.insert(Dmg.weaponProcs, proc)
		end
	end
end

function Dmg.WEAPON_SLOT_CHANGED()
	Dmg.WEAPON_ENCHANT_CHANGED()
end

function Dmg.PLAYER_SWING(duration, swingType)
	local time = GetTime()
	if swingType == Enum.PlayerSwingType.Ranged then return end
	Dmg.OpenBatch(time)
	Dmg.lastStrike = time
	Dmg.batchSwung = true
end

function Dmg.OnUpdate()
	local now = GetTime()
	if Dmg.batchTime and now > Dmg.batchTime then
		Dmg.CloseBatch()
	end
	Dmg.Settle(now)
	Dmg.EmitPaired()
	while Dmg.swings[1] and now - Dmg.swings[1] > Dmg.Time.SealProc + Dmg.Time.MeleeTo do
		table.remove(Dmg.swings, 1)
	end
	if not Dmg.batchTime and #Dmg.waiting == 0 and #Dmg.pending == 0 then
		Dmg.eventFrame:Hide()
	end
end

function Dmg.OnEvent(frame, event, ...)
	Dmg.seq = Dmg.seq + 1
	Dmg[event](...)
end

function Dmg.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	if not (isInitialLogin or isReloadingUi) then return end

	local saved = Blizzard_CombatLog_Filters
	if Dmg.Palette(saved.filters[saved.currentFilter]) then
		Dmg.Enable()
	elseif Dmg.Foreign(saved) then
		local name = saved.filters[saved.currentFilter].name
		print(("KamikazeLib: the combat log filter \"%s\" can't tell your hits apart. Pick \"%s\" above the combat log, and it's fixed when you log out or /reload."):format(name, QUICKBUTTON_NAME_MY_ACTIONS))
	elseif Dmg.MyActions(saved) then
		print("KamikazeLib: the combat log filter can't tell your hits apart yet. It's fixed when you log out or /reload.")
	else
		print(("KamikazeLib: the combat log has no \"%s\" filter. Press Defaults in the combat log settings."):format(QUICKBUTTON_NAME_MY_ACTIONS))
	end
end

function Dmg.PLAYER_LOGOUT()
	local saved = Blizzard_CombatLog_Filters
	local index, filter = Dmg.MyActions(saved)
	if filter and not Dmg.Palette(saved.filters[saved.currentFilter]) and not Dmg.Foreign(saved) then
		saved.currentFilter = index
		Dmg.FixFilter(filter)
	end
end

----------------------------------------------------------------------------------------------------
-- File Load

Dmg.Load()
