# Spiritwright

A 2D, browser-playable PvE auto-battler built in Godot 4.2.2. Collect spirits, build golem vessels for them from frames, arms, legs and sigils, arrange a team of up to six on a 3x2 board and watch a deterministic battle decide whether your theory works. Design: `Spiritwright_Game_Design.md`.

## What is in this build (GDD section 10 vertical slice)

- **6 spirits**: Pyra (Fire, Brash), Neris (Water, Calm), Odo (Earth, Stubborn), plus three rescued in the campaign: Briar (Nature, Loyal) in the optional Thorn Cloister, Volta (Lightning, Patient) from the Fen Mother and Sefa (Wind, Curious) from the Kiln Tyrant. Each has its own base stats, growth rates, a trait and a temperament preference.
- **Awakenings**: at Lv 5 every spirit grows a second trait (Pyra's Wildfire, Neris's Floodwall, Odo's Rumble, Sefa's Tailwind, Volta's Overcharge, Briar's Bloom). The roster shows what each will become; the result screen announces it.
- **4 frames** (Bulwark, Strider, Conduit, Colossus), **11 arms** (Hammer, Shield, Spirit Cannon, Bow, Aegis, Pike, Lantern, Chain Flail, Twin Blades, Storm Staff, Reaper Scythe), **6 legs** (Pillar, Spider, Tower, Stilts, Crawler Treads, Ice Skates) and **16 sigils** (Ember Sigil, Guard Bell, Surge Lens, Moss Charm, Stoneskin Rune, Mending Rune, Leech Fang, Thorn Crest, War Drum, Hunter's Brand, Frost Sigil, Vengeance Idol, Cleansing Charm, Hex Eye, Storm Coil, Phoenix Ember). Every part changes behaviour, not just stats. The later parts bring their own mechanics: armour pierce (Pike), splash onto row neighbours (Flail), two hits per turn (Twin Blades), execute below half HP (Scythe), heal-on-hit (Lantern), a back-row damage bonus (Stilts), status immunity (Treads, Colossus), life drain, thorns, slowing, Weaken and Expose, cleansing, a team surge when an ally falls and a once-per-battle revive. The defensive options: Shield Arms intercept, Aegis Arms ward their lane every turn, Tower Legs brace the front row (-25% attack damage), the Stoneskin Rune hardens when struck and the Mending Rune heals the most wounded ally each turn.
- **8 body materials**: Stone and Wood from the start, Ice (Sunken Court), Crystal (Glimmer Shards), Bogwood (Fen Mother), Bronze (Cinder Kiln), Obsidian (Kiln Tyrant) and Fulgurite (Charged Vault). Each shifts stats and changes the golem's look. Some react with the spirit's element: Kindling (Fire in Wood: high STR/MAG, almost no DEF/RES, singes attackers), Steam (Fire in Ice), Glacier (Water in Ice), Heartwood (Nature in Wood), Living Rock (Earth in Stone), Live Wire (Lightning in Bronze), Wind Chime (Wind in Crystal), Mangrove and Bog Spring (Nature / Water in Bogwood), Magma Heart and Basalt (Fire / Earth in Obsidian), Thunderglass and Singing Glass (Lightning / Wind in Fulgurite). Wild spirits use them too: the lead cinder motes are kindling, the brine sprite is ice and the Root Warden is heartwood.
- **Up to 6v6 automated battles** on a 3x2 board per side (three lanes, front and back rows) with Burn, Soaked, Ward, Stun, Taunt, Regen, Weaken and Expose, interceptions, chained damage and a readable combat log.
- **One golem to start**: the campaign opens with a single golem (Pyra in a kindling body) while Neris and Odo rest. The Mossy Gate and Sunken Court each yield a **golem core**, and the first stage of the Fen, Steppe and Frostspine one more, so the team is three golems through the Ruins, four in the Fen, five on the Steppe and six from the Frostspine on; spend each core in the **Golem Laboratory** to build another body for a resting spirit. Enemy teams match yours: one at the Gate, then three, four, five and six per region (the first stage of a region is fought before its core arrives).
- **Five regions, 30 stages**, each drawn as an illustrated map with a landmark for every stage, fog over places not yet reached, and your golems walking to whichever stage is selected; `<` and `>` step between regions you have reached. The **Ancient Ruins** (Lv 1-5, the Root Warden), **Glimmer Fen** (Lv 5-9, the Fen Mother), **Ember Steppe** (Lv 7-13, the Kiln Tyrant), **Frostspine Pass** (Lv 13-17, the Crag Sovereign) and **Storm Crown** (Lv 16-20, the Storm Sovereign) bring 21 wild spirits. Part and spirit rewards are spread through every region: an ordinary stage gives at most one or two, a boss two to four. Later wild spirits field the new parts too. Each region has one optional branch stage.
- **XP from the fight, not a flat amount**: the enemies' average level times `xp.per_stage_level`, scaled by first clear / replay / loss, and by how far the spirit's level sits below or above that average (`xp.level_gap_step`, clamped to `xp.min_factor`-`xp.max_factor`). Each level costs `xp_per_level + xp_per_level_growth x (level - 1)` up to `level_cap` 50. Costs and XP both grow linearly with level, and the strong level-gap factor pulls spirits toward the stage levels, so playing each stage once keeps pace without grinding. The campaign ends around Lv 20; the rest is for New Game+.
- **New Game+**: once the Storm Crown (the stage marked `"finale": true`) falls, the map offers New Game+. Every stage is fought again, and its first-clear rewards are given again (parts and spirits you own are skipped, and cores only fill empty cradles). Wild spirits are `new_game_plus.level_step` (15) levels stronger per cycle, up to `level_cap`. Spirits, levels, parts and golems carry over. Each playthrough keeps a record of golems fallen, battles not won and the most golems fielded in one battle.
- **Persistent saves** (IndexedDB in the browser, `user://` on desktop) with a backup.

## Prototype answers to the GDD's open questions

| Question | Decision for this slice |
| --- | --- |
| Combat representation | Side view, two teams of up to six, each golem in one of six cells: three lanes (top to bottom) by two rows. |
| Battle cadence | Timed initiative: gauges fill by SPD each tick; arms set the action cost (Hammer slow, Shield fast). |
| Spirit acquisition | Rescued as first-clear stage rewards. |
| Growth variance | Smoothed, not rolled: each level adds the growth % to a running total and every 100 is +1. No unlucky spirits. |
| Arms vs weapon | Arms define the attack; there is no separate weapon slot. One sigil slot. |
| Rebuild economy | Free. Unlocked parts are blueprints usable by any number of golems. |
| Team size | Up to 6 (`team_size`, at most the six cells). The campaign starts with one golem; `"cores"` stage rewards let the laboratory build more. Save schema 4 adds unspent `cores`; schema 3 saves keep their three golems. Schema 5 adds each golem's `lane`; older saves fill each row's centre lane first. Schema 6 adds the New Game+ `cycle` and the playthrough `run` record; a schema 5 save already under way starts with a spoiled record. Migrations live in `save_migrations.gd`. |
| Affinity | Both: universal status rules (Soaked puts out Burn, blocks new Burn, slows and takes +30% magic damage) plus per-spirit traits. |
| Compatibility | Simple temperament bonuses only (no Resonance yet). Tags (Brash, Calm, Stubborn), a new frame (Curious), the back row (Patient) or an ally from the last battle (Loyal). |
| Materials | One per golem (`material` in a loadout), from `parts.json` `materials`. Reactions are data: `reactions.<element>` holds stats and effects in the same vocabulary as traits. Save schema 3 adds materials; schema 2 saves rebuild every golem in stone and unlock what the start and cleared stages grant. |
| Unlocked traits | One Awakening per spirit at `balance.awaken_level` (5): a second data-driven trait, never a stat penalty. |
| Visuals | Procedural 2D golems assembled from part silhouettes at runtime, shaded and textured by material (cracks, grain, sheen, rivets, facets); the element shows as core and eye colour plus a letter; reactions add an animated aura (`golem_fx.gd`). Battles play in front of a drawn ruins backdrop; bosses (`"boss": true` on a wild spirit) stand larger. |

Targeting rules: each arms' attack has an `aim` row. Hammer, Shield, Aegis and the Spirit Cannon aim at the front row, Bow Arms at the back row; the enemy in that row whose lane is nearest the attacker's is struck, and the other row is only reached once the aimed row is empty. So a hammer cannot touch the back row while anyone stands in front. Spider Legs ignore this and hunt the lowest-HP enemy anywhere. A Taunting enemy overrides everything (nearest Taunter first). Melee from the back row strikes at `battle.back_row_melee_factor` (half) power, except on Spider Legs. Front-row Shield Arms take one hit aimed at a back-row ally in their own or a neighbouring lane between their turns.

Effect vocabulary (traits, awakenings, sigils, reactions and parts, validated by `catalog.gd`): triggers `battle_start`, `turn_start`, `hit`, `hurt`, `low_hp`, `kill`, `ally_death` (a teammate falls) and `fatal` (a blow would destroy the owner; fires once); actions `status` (burn, soaked, taunt, regen, stun, weaken, expose), `ward`, `heal`, `damage`, `haste` (action gauge; a negative amount slows), `chain` and `drain` (on hit, a `fraction` of the damage), `cleanse` (clears Burn, Soaked, Weaken, Expose and Stun) and `revive` (on `fatal`, to `self`: HP set to a `fraction` of max); receivers `self`, `target` (on hit), `attacker` (on hurt), `team`, `allies`, `enemies`, `lane` (the owner and whoever shares its lane) and `wounded` (the ally or owner with the lowest share of HP, if anyone is hurt). Frames, arms and legs may all carry `effects`. Arms attacks take optional `pierce` (armour ignored), `splash` (share dealt to the target's row neighbours), `execute` (extra power against targets below half HP) and `strikes` (blows per action). Legs may carry a `brace` fraction (front-row damage taken), a `perch` fraction (back-row damage dealt) and, like frames, an `immune` list of statuses. Weaken and Expose strengths are `status.weaken_fraction` and `status.expose_fraction`. Amounts are `flat` plus `stat` x `fraction` of the owner's stat.

## Adding regions and stages

The campaign is all data in `data/campaign.json`; `catalog.gd` validates it at startup and refuses to run with a readable error if anything is wrong.

- **A region** is an entry in `regions` (shown in list order): `id`, `name`, `text`, a `laboratory` (`name`, `map_pos`: the start of its trails, and a button into the laboratory) and a `terrain` block: `seed`, hex colours `ground`, `dirt`, `rock`, `wall`, `water`, colour lists `patches` and `canopy`, and layout lists `stream` (points; `[]` for none), `walls` (`[start, end, height]`) and `woods` (`[centre, radius]`).
- **A stage** goes in its region's `stages`: unique `id`, `name`, `text`, `map_pos`, `landmark`, `requires` (stage ids, from any region), `seed`, 1-6 `enemies` (loadouts with a `level` and a `row` + `lane` 0-2, each in its own cell; any spirit from `spirits.json`), `rewards` (`{}` for XP only), optional `"boss": true` and optional `clear_text` shown on the first win.
- Map positions are in an 860x560 space; landmarks rise about 110 px above the marker and the name sits below it. Landmarks: `gate`, `court`, `stair`, `cloister`, `vault`, `heart`, `bridge`, `hut`, `tower`, `kiln`, `spire`, `camp`, `monolith`, `peak`.
- A region opens once any of its stages is reachable, so its first stage should require the previous region's boss. Trails from stages in other regions start at the laboratory.
- New wild spirits go in `spirits.json` `wild` using the effect vocabulary below. Run the checks and `-- --report` after adding stages to see the level curve and win rates.

## Layout

```
data/                 catalogs: spirits, parts, campaign, balance
scenes/main.tscn      single scene; scripts/main.gd swaps screens
scripts/core/         catalog (load + validate), builds (stat resolution, growth), progression (save state)
scripts/sim/          battle_sim.gd: deterministic simulation and event log
scripts/ui/           title, campaign map (terrain, landmarks, wild landmarks), golem laboratory, battle playback and backdrop, results, golem art and reaction fx
tools/                sim_checks.gd (headless checks + balance report), capture.gd (screenshots), publishing/
```

## Running and checking

```powershell
.\Run.ps1                                     # run in the editor's game window
$godot = '..\small_following\exports\tooling\Godot_v4.2.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/sim_checks.gd               # checks
& $godot --headless --path . --script res://tools/sim_checks.gd -- --report   # + balance report
& $godot --path . --script res://tools/capture.gd -- C:\temp\captures        # screenshots of every screen
```

## Publishing

Same flow as `small_following`: `.\publish.ps1 -BuildOnly` exports Web and Windows builds into `builds/publish/`; `.\publish.ps1` also copies the web build to `PREVIEW_ROOT/games/spiritwright` (served at `http://127.0.0.1/games/spiritwright/`) and records the deployment in Project Roost; `-Production` / `-FTP` target production; `publish-itch.ps1` pushes to itch.io. The web build needs the COOP/COEP headers in `tools/publishing/web.htaccess`.
