# Spiritwright

A 2D, browser-playable PvE auto-battler built in Godot 4.2.2. Collect spirits, build golem vessels for them from frames, arms, legs and sigils, arrange a team of three and watch a deterministic battle decide whether your theory works. Design: `Spiritwright_Game_Design.md`.

## What is in this build (GDD section 10 vertical slice)

- **4 spirits**: Pyra (Fire, Brash), Neris (Water, Calm), Odo (Earth, Stubborn) and Sefa (Wind, Curious, rescued in the campaign). Each has its own base stats, growth rates, a trait and a temperament preference.
- **3 frames** (Bulwark, Strider, Conduit), **3 arms** (Hammer, Shield, Spirit Cannon), **2 legs** (Pillar, Spider) and **4 sigils** (Ember Sigil, Guard Bell, Surge Lens, Moss Charm). Every part changes behaviour, not just stats.
- **3v3 automated battles** with front and back rows, Burn, Soaked, Ward, Stun, Taunt and Regen, interceptions, chained damage and a readable combat log.
- **One region**, the Ancient Ruins: four stages and the Root Warden boss. First clears unlock parts and a spirit; replays give XP.
- **Persistent saves** (IndexedDB in the browser, `user://` on desktop) with a backup.

## Prototype answers to the GDD's open questions

| Question | Decision for this slice |
| --- | --- |
| Combat representation | Side view, two teams of three, each golem in a front or back row. |
| Battle cadence | Timed initiative: gauges fill by SPD each tick; arms set the action cost (Hammer slow, Shield fast). |
| Spirit acquisition | Rescued as first-clear stage rewards. |
| Growth variance | Smoothed, not rolled: each level adds the growth % to a running total and every 100 is +1. No unlucky spirits. |
| Arms vs weapon | Arms define the attack; there is no separate weapon slot. One sigil slot. |
| Rebuild economy | Free. Unlocked parts are blueprints usable by any number of golems. |
| Team size | 3. |
| Affinity | Both: universal status rules (Soaked puts out Burn, blocks new Burn, slows and takes +30% magic damage) plus per-spirit traits. |
| Compatibility | Simple temperament bonuses only (no Resonance yet). |
| Visuals | Procedural 2D golems assembled from part silhouettes at runtime; the element shows as core colour plus a letter. |

Targeting rules: melee hits the first front-row enemy (back row only when the front is empty); Spider Legs and cannons go for the enemy with the lowest HP; a Taunting enemy overrides both; front-row Shield Arms take one hit aimed at a back-row ally between their turns.

## Layout

```
data/                 catalogs: spirits, parts, campaign, balance
scenes/main.tscn      single scene; scripts/main.gd swaps screens
scripts/core/         catalog (load + validate), builds (stat resolution, growth), progression (save state)
scripts/sim/          battle_sim.gd: deterministic simulation and event log
scripts/ui/           title, campaign map, workshop, battle playback, results, golem art
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
