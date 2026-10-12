# Spiritwright

**Working title / codename:** Spiritwright  
**Genre:** PvE-first, collection-focused auto-battler with modular golem construction  
**Status:** Early game design / prototype specification  
**Design reference:** *Batomon Showdown* for collecting, team composition, synergies and automatic battles; *Fire Emblem* for distinct character stat-growth profiles.  

> **Core pitch:** Collect spirits with individual personalities, elements and growth tendencies. Construct interchangeable golem vessels, outfit them with parts and equipment, and assemble a team whose builds and synergies determine the outcome of automated PvE battles.

## 1. Vision and pillars

1. **The spirit is the character.** A spirit is a persistent individual with a name, personality, elemental affinity, stats and growth rates. Its body is replaceable.
2. **The player builds the fighter.** Frame, components and equipment create combat roles, not a rigid elemental class system.
3. **Experimentation is encouraged.** Any spirit can inhabit a compatible vessel, including counterintuitive builds such as a water spirit in a fortress body. Preferences should offer bonuses, never lock out whole playstyles.
4. **Preparation is gameplay.** The player collects, assembles and configures a team; combat resolves automatically, with readable ability triggers and interactions.
5. **A permanent PvE collection.** Spirits, blueprints, parts and progress persist. This is **not** primarily a run-resetting roguelike.
6. **AI supports visual breadth, not combat adjudication.** The rules engine owns stats, abilities and outcomes; generated art and flavour can make combinations distinctive.

## 2. Player fantasy and loop

The player is a spiritwright who builds vessels to let otherwise incorporeal spirits compete and fight. Each spirit has a recognisable identity, but its current form is a workshop decision.

**Core loop:**

1. Choose a PvE stage, challenge, boss or repeatable encounter.
2. Inspect enemy compositions and potential rewards.
3. Pick spirits, construct or refit bodies, equip components and arrange the team.
4. Start an automatic battle; see targeting, triggers, statuses and team synergies play out.
5. Earn resources, blueprints, equipment, spirit-related rewards and/or progression.
6. Upgrade the collection, adjust builds and tackle the next encounter.

**Intended emphasis:** collecting and construction first; PvE battles demonstrate whether the player's theory works. Asynchronous PvP is optional future scope, **not a launch requirement**.

## 3. Unit anatomy

A deployed golem has four conceptual layers:

| Layer | Defines | Persistent or interchangeable? |
| --- | --- | --- |
| **Spirit** | Name, personality, affinity, base stats, level, growth rates, personal passive, preferences | Persistent character |
| **Frame / body** | Base role, silhouette, HP/defence profile, movement style, part-slot layout | Interchangeable vessel |
| **Body parts** | Attack actions, armour, mobility, targeting modifiers and physical appearance | Interchangeable components |
| **Equipment / sigils** | Additional tactical effects, trigger combinations and situational bonuses | Interchangeable gear |

### Initial proposed loadout

- **Spirit:** one occupying the vessel.
- **Frame / torso:** main chassis and slot rules.
- **Arms:** attack or protection style; may be represented by a paired-arm component to reduce asset complexity.
- **Legs / locomotion:** speed, positioning and stability.
- **Weapon:** primary or secondary attack modification, if supported by the chosen arm assembly.
- **Accessory / sigil:** one conditional passive or synergy effect.

**Scope note:** Heads, armour layers, multiple individual arm slots and additional accessories can be added later. Aim for **moderate modularity**, not a full engineering simulator. Avoid redundant decisions between arms and weapon: either the arms define the attack, or they define the mount/handling while the weapon defines the attack.

## 4. Spirits: the persistent collection

Every spirit has:

- **Identity:** name, portrait/visual motif, short description.
- **Elemental affinity:** e.g. Fire, Water, Earth, Wind, Lightning, Nature, Shadow; final set TBD.
- **Personality / temperament:** informs preference bonuses and potentially a minor passive.
- **Base stats and growth rates:** distinct enough that two spirits in identical vessels perform differently.
- **Innate trait:** a mechanically recognisable personal ability.
- **Preferences:** body styles, role tags, equipment traits or ally synergies that provide modest advantages.
- **Progression:** level, experience and potentially bond, unlocked traits and battle history.

### Element is identity, not class

Fire does not mean damage dealer; Water does not mean healer. An affinity may influence effects and elemental interactions, but **any affinity can be built into a tank, striker, caster or support**.

Examples of a heavy tank vessel:

- **Fire spirit:** retaliates with Burn or gains Heat when struck.
- **Water spirit:** gains Ward or reduces debuff duration when struck.
- **Wind spirit:** mitigates hits through evasion and repositioning.

These are **illustrative ability directions**, not final or guaranteed affinity-wide rules.

### Stat model and growth

Inspired by *Fire Emblem*, spirits have varied growth probabilities rather than uniformly scaling stats.

**Candidate stats:**

| Stat | Use |
| --- | --- |
| HP | Survivability |
| STR | Physical damage |
| MAG | Magical/elemental effects |
| SPD | Attack/action frequency and/or initiative |
| DEX | Accuracy or precision-dependent effects |
| DEF | Physical mitigation |
| RES | Magical/elemental mitigation |
| LCK | Optional crit/proc-related stat |

**CHA** from the reference growth table is **not assumed for v1**. It needs a meaningful battle role before inclusion. DEX and LCK can also be merged or dropped if they do not create interesting decisions.

Example *illustrative* growth profiles (percent chance of +1 on level-up, subject to balance):

| Spirit archetype | HP | STR | MAG | SPD | DEF | RES |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Emberling: aggressive | 45% | 60% | 20% | 50% | 35% | 20% |
| Tidelume: resilient mystic | 50% | 30% | 45% | 40% | 35% | 50% |
| Gravemind: stoic bruiser | 60% | 50% | 15% | 20% | 55% | 25% |
| Zephra: agile skirmisher | 35% | 35% | 40% | 60% | 20% | 45% |

Balance considerations:

- Define how growth affects a spirit independently of vessel bonuses.
- Consider deterministic or seeded/guaranteed growth smoothing if random levelling produces frustrating permanently weaker spirits.
- Ensure a supposedly low-growth spirit can still have an attractive trait, ability or niche.
- Keep the total power contribution of spirit, body and gear legible.

### Personality and preferences

Personalities **nudge**, rather than forbid, construction choices.

| Temperament | Example preference or behaviour |
| --- | --- |
| Brash | Bonus when using aggressive or close-range builds |
| Patient | Bonus to guarding, charging or defensive setups |
| Curious | Small reward for adapting to unfamiliar vessel categories |
| Loyal | Synergy with familiar teammates |
| Proud | Prefers finely crafted parts; avoid punitive gear restrictions |
| Stubborn | Bonus to stability or holding position |

**Important:** A poor match should still be playable. Do not apply crippling penalties for experimentation.

### Compatibility / resonance (proposed)

Spirits may have an affinity with frame tags, expressed as a lightweight compatibility grade or set of bonuses. High compatibility could grant **Resonance**, a special interaction between spirit and build.

Examples:

- **Molten Bastion:** Fire-aligned spirit + fortress setup; accumulating Heat while hit can release an area pulse.
- **Flowing Ward:** Water-aligned spirit + support setup; some overhealing becomes shielding.
- **Gale Pursuit:** Wind-aligned spirit + agile setup; follow-up attacks or repositioning.

**Design caution:** Avoid using compatibility to penalise unusual builds twice. Prefer bonus synergies over reduced base-stat efficiency. Treat resonance as a *candidate feature*, not a hard requirement for the first prototype.

### Remembering past vessels (future candidate)

The spirit can acquire small identity traits through use:

- **Fortified:** spent many fights in heavy vessels.
- **Measured:** frequently used ranged attacks.
- **Resolute:** survived dangerous battles.

If implemented, this needs limits, retraining or reversibility so experimentation remains practical. History should add character without permanently trapping an early-game build.

## 5. Frames and parts

### Candidate frame families

| Frame | Primary identity | Possible weakness |
| --- | --- | --- |
| **Bulwark** | High HP/DEF, front-line guardian | Slow |
| **Strider** | Mobile close-range attacker | Fragile |
| **Conduit** | Magical ranged attacks and support | Low physical defence |
| **Siege** | Long-range heavy attacks / area pressure | Vulnerable to fast enemies |
| **Caretaker** | Healing, shields, buffs and utility | Lower direct damage |

These are body configurations, **not classes assigned to spirits**.

### Example body components

| Component | Behavioural impact |
| --- | --- |
| Hammer Arms | Slow heavy blows, possible stun |
| Blade Arms | Frequent attacks, critical/bleed synergy |
| Shield Arms | Blocking, intercepting or guarding allies |
| Cannon Assembly | Ranged targeting, cooldown-dependent attacks |
| Pillar Legs | Stability, resistance to knockback |
| Spider Legs | Mobility, repositioning or flanking |
| Root Base | Reduced mobility, regeneration or zone control |
| Floating Base | Ignores some terrain/positioning constraints |

Every major part should contribute an **understandable combat behaviour**, not only a flat stat increment. Exact behaviour is to be balanced once the simulation model is chosen.

### Body materials

Vessels are not always stone. Each golem is built from one **material** (stone, wood, ice, bronze, crystal and stranger things later), which shifts its stats and appearance: wood is light and roomy but splinters, ice is hard and slow, crystal focuses magic but is brittle.

A material can **react** with the element of the spirit inside it. A reaction is a named bonus with its own trade-off and, often, a behaviour:

| Spirit + material | Reaction | Effect |
| --- | --- | --- |
| Fire in Wood | Kindling | The body burns as it fights: much higher STR/MAG, much lower DEF/RES; attackers are singed |
| Fire in Ice | Steam | The ice melts: faster and stronger magic, weaker plating; a scalding mist Soaks every enemy |
| Water in Ice | Glacier | Tougher, and attackers are Soaked |
| Nature in Wood | Heartwood | The timber takes root: more HP and early Regen |
| Earth in Stone | Living Rock | The stone knits around its own kind |
| Lightning in Bronze | Live Wire | Current runs through the metal: every hit arcs to another enemy |
| Wind in Crystal | Wind Chime | The wind sings through the facets: the whole team surges forward |

Reactions follow the same rule as preferences: they reward a pairing, they never lock a spirit out of a material. A reaction may trade one strength for another (Kindling), but no material is unusable for any spirit.

### Equipment

Keep the prototype to **one weapon and one accessory/sigil at most**, or fewer if the arm component already defines the weapon.

Candidate effects:

- **Ember Sigil:** attacks apply Burn.
- **Guard Bell:** taunts or guards at the start of battle.
- **Surge Lens:** spell criticals can chain to another target.
- **Moss Charm:** regenerates health under a condition.

Condition-based gear should create interesting interactions without a wall of unreadable triggers.

## 6. Combat design

### Core format

- Team-based **autobattler**: players make decisions before the fight, not by manually controlling each attack.
- **Initial target:** up to **six golems** in a team (subject to prototype testing).
- Formation and position matter, but exact grid dimensions are **undecided**.
- Damage, targeting, ability timing, statuses and victory are handled by a **deterministic simulation engine** given the same initial state and RNG seed.
- Each spirit brings at least one signature influence; its body and equipment determine most practical battle actions.

### Interesting tactical levers

1. **Formation:** who can protect whom, threat exposure, frontline/backline interactions.
2. **Targeting:** nearest, weakest, marked targets, support units, etc., under clear rules.
3. **Action economy:** fast attacks versus slower powerful abilities.
4. **Status effects:** Burn, Soaked, Ward, Stun, Knockback, etc.
5. **Cross-unit combinations:** Water may apply Soaked; Lightning may benefit against Soaked enemies.
6. **Counterbuilding:** a PvE boss may reward magic resistance, interruption, splash protection or mobility.

**Avoid:** unpredictable AI-driven battle adjudication; mandatory micro during combat; vague combat logs; excessive on-screen stat displays.

### Readability

- Make the battlefield the dominant visual area.
- Show health, team identity, status and ability activations clearly.
- Reveal detailed formulas, growth information and equipment interactions in inspection/workshop views instead of filling battle UI with text.
- Support playback speed/pause in a later iteration if useful for understanding triggers.

## 7. PvE campaign and collecting

The main mode is a persistent campaign featuring themed regions, escalating stage challenges and repeatable encounters for targeted component collection.

| Region concept | Example rewards | Encounter identity |
| --- | --- | --- |
| Ancient Ruins | Earth/Nature spirits and basic frame parts | Defensive formations, regeneration |
| Molten Foundry | Fire components, heavy armour, forge materials | Burn and high physical damage |
| Storm Spire | Lightning/Wind spirits and fast frames | Mobility and chained attacks |

A region might contain:

- Main stages that open the next area.
- Repeatable encounters with **visible, targeted loot pools**.
- Challenge variants encouraging specialised teams.
- A boss whose defeat unlocks a distinctive component or blueprint.

### Permanent progression

- **Spirits:** obtained, levelled and kept.
- **Blueprints:** unlock build options, not just direct stat upgrades.
- **Components/equipment:** found, crafted and refitted.
- **Workshop:** manages spirit roster, vessels, loadouts and team presets.
- **Campaign:** expands enemy patterns and acquisition options.

**Default stance:** Battle defeat does not destroy spirits or erase progress. Reconfiguration should be affordable enough to encourage experimentation.

### Economy questions to resolve

- How are new spirits obtained: rescuing, recruiting, summoning, defeating bosses or crafting?
- Are parts unique inventory objects, craftable instances, or unlimited once a blueprint is unlocked?
- Can players use multiple copies of the same spirit type? If so, how are identities differentiated?
- How much progression comes from spirit levels versus item quality versus player strategy?
- How do repeated farming stages stay useful without feeling compulsory?

## 8. Example spirit and build

### Neris, the Calm Tide

- **Affinity:** Water
- **Temperament:** Calm
- **Growth tendencies:** high RES, fair HP, moderate MAG, low STR
- **Innate trait:** *Tide Memory*, gains a small Ward after taking magical damage (cooldown TBD)
- **Preferences:** defensive and balanced bodies, but **no prohibited frames**

**Chosen vessel:** Bulwark frame + shell torso + anchor arms + reinforced legs.  
**Equipment:** Ward Sigil + Iron Bell, if both slots are supported.

**Outcome:** A magic-resistant frontline guardian that helps protect allies rather than a default water healer. A different Neris setup could be a ranged support or mobile debuffer.

## 9. AI-generated asset direction

The game should be technically feasible for a small, AI-assisted development workflow.

### Recommended phases

**Prototype visuals:** use a limited library of complete sprites or placeholder silhouettes. Show affinity with effects, colour and core-glow treatments. This is faster and more reliable than generating matching interchangeable anatomy on day one.

**Production direction:** modular bodies with fixed attachment anchors and consistent visual rules; generated content can provide variant textures, designs, portraits and item imagery.

**Possible hybrid:** assemble mechanical parts at runtime but generate polished whole-golem portraits for collection pages. These portraits are cosmetic and must not change stats or rules.

### Asset constraints

- Choose one perspective (e.g. side view or three-quarter isometric) and keep it consistent.
- Standardise part silhouettes, sizes, anchor coordinates and weapon clearance.
- Plan how arms, legs and large equipment animate before expanding the part library.
- Avoid assuming an image model can reliably generate animation frames or cuttable components with perfect registration.
- Make every important elemental effect readable without relying on subtle colour alone.

### AI responsibilities

**Good fits:** concepts, alternative body skins, portraits, flavour descriptions, spirit names, reference variations and optional lore.  
**Rules-engine responsibilities:** gear legality, stat growth, attacks, targeting, cooldowns, loot, combat outcomes and saves.

## 10. Suggested first playable prototype

The goal is to answer **“Is assembling a team and watching the interactions genuinely fun?”** before building a large content pipeline.

### Vertical slice

- **4 spirits** with different growths, traits and preferences.
- **3 frames**: Bulwark, Strider, Conduit.
- **3 arm styles**: Hammer, Shield, Cannon.
- **2 locomotion styles**: Pillar, Spider.
- **4 equipment effects** with obvious triggers.
- **3v3 automated battles** (expand toward six per side once readability works).
- **One PvE region** containing several fights and a boss.
- **Persistent roster/loadout saving** and simple rewards that unlock a new part or option.

### Must be proven

1. Swapping a spirit between bodies creates a meaningfully different build.
2. Swapping parts creates visible behavioural differences during battle.
3. A weaker-on-paper composition can win through synergy or counterbuilding.
4. It is easy to understand **why** a team won or lost.
5. The player wants to earn more spirits and components after winning.

### Defer until after the slice

- Full six-unit roster battles, if 3v3 is not yet readable.
- Advanced bond/history and resonance systems.
- Extensive crafting economy, rarity ladders or gacha-like acquisition.
- Hundreds of spirits, fully generated modular animation sets.
- Multiplayer/asynchronous PvP.
- Complex battle scripting or highly granular unit tactics.

## 11. Architecture notes

A separation of data and simulation will make this game easier to expand and AI-assist:

```text
SpiritDefinition
  id, element, baseStats, growthRates, innateTrait, preferenceTags

SpiritInstance
  uniqueId, definitionId, name, level, experience, earnedTraits

FrameDefinition
  id, baseStats, slotRules, tags, movementStyle

PartDefinition
  id, slot, statModifiers, behaviours, tags, visualKey

EquipmentDefinition
  id, slot, triggerEffects, tags, visualKey

GolemLoadout
  spiritInstanceId, frameId, partIds[], equipmentIds[]

TeamPreset
  golemLoadouts[], formations[]

BattleSimulation
  input: resolvedTeams, encounterRules, rngSeed
  output: result, eventLog, rewards
```

Combat mechanics should be expressed as reusable, data-driven effects wherever reasonable (e.g. `onHit -> applyStatus(Burn, stacks=1)`) rather than bespoke code for every spirit. This makes balance adjustments and content generation much safer.

## 12. Decisions established vs still open

### Established direction

- Golem-themed, collectible autobattler.
- Spirits are persistent characters occupying constructed bodies.
- Spirits differ in personality, elemental affinity and Fire Emblem-like growth rates.
- Bodies are moderately modular; equipment adds additional strategy.
- Unusual spirit/body pairings are supported.
- Primarily **PvE**, with permanent collecting/progression rather than a roguelike run loop.
- AI-generated visuals should support variety without replacing a rules-based simulator.

### Questions for the next design pass

1. **Combat representation:** side-view lanes, small grid, or compact arena?
2. **Battle cadence:** simultaneous cooldowns, discrete turns, or timed initiative?
3. **Spirit acquisition:** how are new spirits recruited, and what makes individual spirits collectible?
4. **Growth variance:** random level-up rolls versus predictable or smoothed advancement?
5. **Body-part schema:** does an arm assembly include its weapon, or is weapon always an independent slot?
6. **Rebuild economy:** entirely free swapping, or minor costs on crafting but not on equipping?
7. **Team size:** is six the right eventual size, or is four more readable with highly customised units?
8. **Affinity:** do elements have fixed universal rules, individual spirit abilities, or both?
9. **Compatibility:** simple preference bonuses or a deeper Resonance system?
10. **Visual implementation:** modular 2D sprites, 3D models, or a hybrid?

---

**One-sentence design test:** *Can the player take a spirit they love, construct a surprising vessel for it, and win a difficult battle because of the combination they invented?*
