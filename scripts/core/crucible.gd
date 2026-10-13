extends RefCounted
## The Shifting Crucible's rules, pure functions on crucible.json: which
## encounters a run meets and in what order, the battle seed of each, both
## teams at the tier's level, and the milestones a run meets. The run itself
## (and the records) is persistent state, kept by CrucibleRecord.
##
## A Classic Royale is the fixed sequence in crucible.json. A Shifting Royale
## draws encounters_per_run encounters, their order, each one's variant and
## the final from its seed alone, so a seed always names the same gauntlet.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")

const MODES: Array[String] = ["classic", "shifting"]
const MODE_NAMES: Dictionary = {"classic": "Classic Royale", "shifting": "Shifting Royale"}
## Shifting seeds are drawn from 1 to this, so they stay short enough to read out.
const SEED_RANGE: int = 99999


## The run's steps in order: [{"encounter": id, "variant": index}], the
## encounters then the final.
static func sequence(catalog: Catalog, mode: String, seed: int) -> Array:
	var data: Dictionary = catalog.crucible
	if mode == "classic":
		var steps: Array = data.classic.encounters.map(func(id): return {"encounter": id, "variant": 0})
		steps.append({"encounter": data.classic.final, "variant": 0})
		return steps
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Array = data.encounters.map(func(entry): return entry.id)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var steps: Array = []
	for id in pool.slice(0, int(data.encounters_per_run)):
		steps.append({"encounter": id, "variant": rng.randi_range(0, catalog.crucible_encounters[id].variants.size() - 1)})
	var final: Dictionary = data.finals[rng.randi_range(0, data.finals.size() - 1)]
	steps.append({"encounter": final.id, "variant": rng.randi_range(0, final.variants.size() - 1)})
	return steps


## The battle seed of step `index`: the encounter's own seed in a Classic
## Royale, mixed with the run's seed in a Shifting one.
static func battle_seed(catalog: Catalog, run: Dictionary, index: int) -> int:
	var entry: Dictionary = catalog.crucible_encounters[run.sequence[index].encounter]
	if run.mode == "classic":
		return int(entry.seed)
	return int(entry.seed) + int(run.seed) * 31 + index


## A step's enemies at the tier: each stands at the tier's level plus its
## enemy_bonus plus the loadout's own offset, between 1 and level_cap.
static func enemy_team(catalog: Catalog, step: Dictionary, tier_id: String) -> Array:
	var tier: Dictionary = catalog.crucible_index.tiers[tier_id]
	var resolved: Array = []
	for enemy in catalog.crucible_encounters[step.encounter].variants[int(step.variant)]:
		resolved.append(Builds.resolve(catalog, enemy, enemy_level(catalog, tier, int(enemy.offset)), {}, true))
	return resolved


static func enemy_level(catalog: Catalog, tier: Dictionary, offset: int) -> int:
	return clampi(int(tier.level) + int(tier.enemy_bonus) + offset, 1, int(catalog.num("level_cap")))


## The run's locked team, every spirit at the tier's level whatever its own:
## the Crucible tests the composition, not the grind. `run.history` holds what
## each spirit remembered when the run began, so temperaments stay fixed too.
static func player_team(catalog: Catalog, run: Dictionary) -> Array:
	var level: int = int(catalog.crucible_index.tiers[run.tier].level)
	var resolved: Array = []
	for loadout in run.team:
		resolved.append(Builds.resolve(catalog, loadout, level, run.history[loadout.spirit]))
	return resolved


## Whether a run meets a milestone's rules. `result` is {"won": encounters
## won, "complete": bool, "mode", "tier", "golems": size of the locked team}.
static func milestone_met(rules: Dictionary, result: Dictionary) -> bool:
	for rule in rules:
		var value: Variant = rules[rule]
		var ok: bool = true
		match rule:
			"reach":
				ok = int(result.won) >= int(value)
			"complete":
				ok = bool(result.complete)
			"mode":
				ok = result.mode == value
			"tier":
				ok = result.tier == value
			"max_golems":
				ok = int(result.golems) <= int(value)
		if not ok:
			return false
	return true


## Ids of every `kind` ("titles" or "finishes") the met milestones reward, in catalog order.
static func unlocked(catalog: Catalog, milestones: Array, kind: String) -> Array:
	var granted: Array = []
	for id in milestones:
		granted.append_array(catalog.crucible_index.milestones[id].rewards.get(kind, []))
	return catalog.crucible_index[kind].keys().filter(func(id): return id in granted)


## Whether a tier is open: tiers with "requires" wait for that milestone.
static func tier_open(catalog: Catalog, tier_id: String, milestones: Array) -> bool:
	var tier: Dictionary = catalog.crucible_index.tiers[tier_id]
	return not tier.has("requires") or String(tier.requires) in milestones


## "classic:adept": the key a mode and tier's record is kept under.
static func record_key(mode: String, tier_id: String) -> String:
	return "%s:%s" % [mode, tier_id]
