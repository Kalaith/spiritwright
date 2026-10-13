# Spiritwright: playtime suggestions

A follow-up to `game_concepts.md`. That document makes the right diagnosis: the player understands the game long before the content runs out, and the missing piece is *a reason to change a build that already works*. This file checks its ideas against what is actually in the game today (data files and the `sim_checks.gd --report` balance report, run 2026-10-13), then suggests what to do, in order.

## What the review gets right, and where it is out of date

| Concept doc says | State of the game now | Takeaway |
| --- | --- | --- |
| Add enemy previews (priority 1) | The campaign screen already shows a scouting report: enemy builds and traits | Done. The next step is making the report *point at a weakness* (see 2.2) |
| Add 20-30 spirits | 6 player spirits, but **21 wild spirits** already exist in `spirits.json` with sim-supported traits | Much of the work is done. Turning wild spirits into recruits is the cheapest big win (see 3.1) |
| Add spirit mastery | `progression.gd` already records `last_frame` and `last_allies` per spirit (used by Curious) | The tracking hooks are already there |
| Build identities (Shield + Kindling, etc.) | 4 frames, 11 arms, 6 legs, 16 sigils, 8 materials, with pierce, splash, drain, thorns, Weaken, Expose, revive | The part catalog is big enough. Encounter design is the bottleneck, not part count |
| Build more than six golems | Cores cap the team at 6, and there are exactly 6 spirits | Agreed, and it is more urgent than the doc suggests (see 1.1) |

## What the balance report shows

The random-build win rate per stage (`-- --report`) points to three problems that cost playtime in the *bad* way, or waste playtime that could be good:

1. **The difficulty curve peaks in the middle.** The Great Kiln (Steppe boss) is the hardest fight in the game at a 19.6% random-build win rate. After it, Whispering Cairn (69.8%), Thunder Stones (69.6%) and Charged Vault (67.0%) are among the *easiest* stages, and the final Storm Crown sits at 48.6%. The last two regions feel like a victory lap, not a summit.
2. **Frostspine fights are slogs.** Glacier Stair and Rimeglass Spire average about 170 turns, 59-66% of hits deal only 1-2 damage, and Rimeglass Spire times out 27 times per sample. Thorn Cloister, Heart of the Roots and Sagging Crossing also time out a lot. Long, low-damage fights add minutes without adding decisions.
3. **The player hits the level cap just as the content ends.** Spirits reach about level 19 by the Storm Crown, and the cap is 20. There is no room left for post-game growth, and no reason to keep fighting after the credits.

Fix these before adding content. They are cheap (data tuning) and they shape how every later addition feels.

---

## 1. Fix the foundations first (data and tuning only)

### 1.1 Give the player more spirits than golems
With exactly six spirits and six cores, the player never chooses *who* fights, only how they are built. Recruiting (3.1) solves this. In the meantime, check that the campaign hands out spirits faster than cores from the Fen onward, so that from mid-game there are always one or two spirits resting on the bench.

### 1.2 Reshape the curve
- Bring Frostspine and Storm Crown stages down into the 25-45% random-build band, and keep each region boss as that region's low point.
- Let the Storm Crown be the hardest fight in the campaign, for example around 15%.
- Use the report as a regression check: no stage after the Great Kiln should be easier than the Fen stages.

### 1.3 Shorten the slogs
Long, low-damage fights come from stacked wards (Rime Ogre's Frost Ward), healing (Root Warden, Fen Mother) and high-DEF front lines. Options that stay inside the existing sim:
- An escalation rule: after N turns, all damage rises each round. This is a single `balance.json` value and the sim enforces it, so battles are still explainable ("The storm grows fierce: damage +20%").
- Fewer Rime Ogres per stage, mixed with fragile threats.
- A target to aim for: no stage averages more than about 100 turns, and timeouts stay under 5%.

### 1.4 Raise the level cap and keep the steady XP curve
Raise `level_cap` to about 30 and leave the growth curve alone. The campaign then ends around level 19-20, leaving ten levels of earned growth for post-game modes. Do not add an XP wall. Post-game content should be built around engineering puzzles, not around levels.

---

## 2. Turn stages into engineering puzzles

### 2.1 Add a "counter-build gap" metric to the balance report
The report gives the random-build win rate, but not whether a stage *demands a rebuild*. Add two numbers per stage:

- **Carry-over rate:** the win rate of the best builds from the *previous* stage, unchanged, on this stage.
- **Best-found rate:** the win rate of the best builds the search finds for this stage.

A good puzzle stage has a low carry-over rate and a high best-found rate: "your old team loses, the right team wins". This is the measurable form of the concept doc's "one important design test", and it can run headless in `sim_checks.gd`.

### 2.2 Make the scouting report hint at the puzzle
The preview already lists the enemy builds. Add one generated "Warden's note" per stage from the enemy traits, for example:
- "Heals every turn. Long fights favour it." (Overgrowth, Tidecaller)
- "Strikes back when hit." (Slag Hide, Forgeheart)
- "Wards itself when struck." (Frost Ward)

The text comes from data the sim already uses, so it can never disagree with what happens in battle.

### 2.3 Name the loss on the result screen
On a defeat, pick out the single biggest cause from the event log ("Root Warden healed 140 HP", "Slag Hide reflected 62 damage to your hammers"). It is the same data the result screen already shows, ranked. A player who knows *why* they lost rebuilds. A player who doesn't, quits.

---

## 3. Grow the collection from what already exists

### 3.1 Make wild spirits recruitable
The 21 wild spirits already have elements and traits the simulation supports. To make one a recruit, it needs base stats, growths, a temperament and an awakening. That is data work, but awakenings still have to stay within effects the sim already implements.
- Recruit by beating a stage that contains the spirit under an optional condition ("Defeat the Mossy Gate without your front row falling"), so recruiting feeds the challenge system (4).
- Recruits join at the team's average level (the `_join_level` rule already does this), so a new spirit is usable at once and never a grind.
- Give each recruit one *new reason* to field it, such as a trait that combines differently with existing parts: Spark Newt's Arc on a Flail, Bog Lurker's Clinging Mud on a Bulwark.

Even 8-10 recruits takes the roster from 6 to about 15, which brings in bench choice, expeditions (3.3) and stage-specific line-ups.

### 3.2 Spirit mastery from data already tracked
`last_frame` is already recorded. Extend it to a per-spirit set of frames, arms and materials each spirit has *won* with. Rewards:
- Each spirit: win in all 4 frames to unlock a small, character-specific bonus (bonuses only, never a lock-out, in line with the temperament rule).
- A codex page per spirit showing which combinations it has tried. This makes "I haven't put Odo in a Strider yet" a visible goal.

### 3.3 Expeditions for the bench (later)
Once there are more spirits than slots, resting spirits can be sent on short expeditions to replay cleared stages off-screen (simulated with their own builds) for schematic fragments. Use battle counts or stage clears, never real-time timers. The concept doc rightly warns against those.

---

## 4. The Codex: optional challenges on existing stages

This is the highest playtime-per-effort feature, because it reuses all 30 stages.

- **2-3 challenges per stage**, defined in `campaign.json` and checked from the event log after a win, for example:
  - Restriction: "Only Wood and Bogwood bodies", "No front row", "Three golems or fewer"
  - Style: "Win without direct attack damage" (Burn, thorns and reflect only), "No golem falls"
  - Spirit: "Win with Neris in a Strider carrying Twin Blades"
- Because the sim is deterministic and logs every event, each challenge can be checked exactly, and `sim_checks.gd` can prove that every challenge is winnable.
- **Rewards:** recruits (3.1), material finishes, codex entries and a few *challenge-only* sigil variants. Keep every variant inside the implemented effect catalog: a variant tunes existing effects with new amounts or triggers, it does not invent new ones.
- **Unlock early:** the Ruins challenges should open as soon as each stage is cleared.

A rough target: 30 stages x 2.5 challenges = about 75 puzzles, where each one asks for a different build than the one that cleared the stage.

---

## 5. The Shifting Crucible, scoped down

Agreed with the concept doc that this is the biggest single addition. To keep it small and on-brand:

- **Run shape:** 6 encounters drawn from cleared stages, with enemy levels set to the team's level, then a remixed boss. Use the persistent roster, with no permanent loss on defeat (keeping the "defeat never destroys progress" invariant).
- **Boons as data:** each boon is an effect entry using existing triggers and actions, for example `{"on": "battle_start", "do": "status", "status": "regen", ...}` scoped to Stone bodies. No new sim systems are needed for the first version.
- **Forge stops:** between fights, the player may *swap* parts freely (as now), plus one Forge choice from three temporary part upgrades.
- **Seeded weekly Crucible:** one fixed seed per week gives everyone the same run to compare. It costs nothing to build because the sim is already deterministic.
- **Rewards:** relics are cosmetic or codex-only at first. Add power later, and only if the Crucible proves fun on its own.

---

## 6. Post-game hooks

- **Heroic stages:** after the Storm Crown, each region boss can be replayed at levels 25-30 with one added enemy trait. This uses the raised level cap (1.4).
- **Boss mastery:** each boss gets three "signature solutions" (for example, beat the Root Warden by out-damaging its healing, by Weaken plus burst, or by cleansing and attrition), each recorded in the codex when found. This is the Root Warden experiment the concept doc proposes, turned into a feature.
- **Golem blueprints:** saved builds per spirit (no cost), so switching between a "Fen line-up" and a "Kiln line-up" takes one click. The cheaper experimenting is, the more of it players do.

---

## Suggested order of work

| # | Work | Effort | Why now |
| --- | --- | --- | --- |
| 1 | Reshape the curve, shorten slogs, raise the level cap (1.2-1.4) | Data only | Fixes playtime that is currently lost to boredom or a soft end |
| 2 | Counter-build gap metric in the report (2.1) | Small, tooling | Lets every later change be measured |
| 3 | Scouting notes and named loss reasons (2.2, 2.3) | Small, UI | Makes losing lead to rebuilding |
| 4 | Codex challenges on existing stages (4) | Medium | Largest playtime gain per unit of work |
| 5 | 8-10 recruitable wild spirits (3.1) | Medium, data heavy | Creates bench choice, ties into challenges |
| 6 | Spirit mastery and blueprints (3.2, 6) | Small-medium | Medium-term goals, cheaper experimenting |
| 7 | Crucible v1 with data-only boons (5) | Large | Repeatable content once the systems are deep enough |
| 8 | Heroic bosses, expeditions (6, 3.3) | Medium | Long tail |

## Rough playtime picture

These are illustrative targets, not measurements:

- **Campaign today:** 30 stages at roughly 40-170 sim turns each, with about 1-3 attempts per stage at current win rates. That is probably 2-3 hours, some of it spent on slogs.
- **After tuning (1):** about the same length, but the time is spent on decisions rather than waiting out timeouts.
- **Plus the Codex (4) and recruits (3.1):** +3-6 hours of build-driven replays of content that already exists.
- **Plus the Crucible and post-game (5, 6):** open-ended, as long as the counter-build gap metric shows stages genuinely reward new builds.

The guiding test is the same one both documents end on: *does losing make the player want to rebuild, and does the new build winning feel like their invention?* Every item above should be judged against it, and against the carry-over metric in 2.1.
