extends SceneTree
## Headless checks for the data and the simulation. Prints PASS/FAIL lines and
## exits non-zero on failure. Run:
##   godot --headless --path . --script res://tools/sim_checks.gd
## Pass `-- --report` to also print every stage's outcome for balance work.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")

var failures: int = 0


func _init() -> void:
	var catalog := Catalog.new()
	_check("catalog loads", catalog.load_all(), ", ".join(catalog.errors))
	if failures == 0:
		_check_growth(catalog)
		_check_determinism(catalog)
		_check_progression(catalog)
		_check_slice(catalog)
		_check_spirits(catalog)
		_check_materials(catalog)
		if "--report" in OS.get_cmdline_user_args():
			_report(catalog)
	print("%s (%d failure(s))" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		print("FAIL ", name, "  ", detail)


func _check_growth(catalog: Catalog) -> void:
	var pyra: Dictionary = catalog.spirit("pyra")
	var level_one: Dictionary = Builds.spirit_stats(catalog, pyra, 1)
	_check("level 1 stats equal base", level_one.str == int(pyra.base.str))
	var level_five: Dictionary = Builds.spirit_stats(catalog, pyra, 5)
	# 50 + 60 * 4 = 290 -> 2 points of STR.
	_check("smoothed growth adds expected STR", level_five.str == int(pyra.base.str) + 2, str(level_five))


func _check_determinism(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var stage: Dictionary = catalog.stages["ruins_court"]
	var first: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), 7)
	var second: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), 7)
	_check("same seed gives the same battle", JSON.stringify(first.events) == JSON.stringify(second.events))
	_check("battle ends", first.result in ["win", "loss", "timeout"])
	# Armour blunts blows rather than cancelling them: even the plated Rubble Imp takes real hits.
	var imp_hits: Array = first.events.filter(func(e): return e.type == "damage" and e.cause == "attack" and e.unit == "b0")
	var imp_total: int = imp_hits.reduce(func(sum, e): return sum + int(e.amount), 0)
	_check("armour does not reduce hits to chip damage", not imp_hits.is_empty() and imp_total >= 3 * imp_hits.size(),
		"%d damage over %d hits" % [imp_total, imp_hits.size()])


func _check_progression(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_path = "user://sim_checks_save.json"
	progression.new_game()
	_check("new game is a valid save", progression.valid(progression.to_dict()))
	_check("locked part is refused", not progression.set_slot(0, "arms", "cannon"))
	_check("swapping spirits keeps them unique", progression.set_slot(0, "spirit", "pyra")
		and progression.team[1].spirit == "odo")
	var report: Dictionary = progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("first clear unlocks the cannon", "cannon" in progression.unlocks.arms and report.first_clear)
	_check("stage two opens", progression.stage_state("ruins_court") == "open")
	_check("save writes", progression.save_game(), progression.last_error)
	var reloaded := Progression.new(catalog)
	reloaded.save_path = progression.save_path
	_check("save reads back", reloaded.load_game() and JSON.stringify(reloaded.to_dict()) == JSON.stringify(progression.to_dict()))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progression.save_path + suffix)


## The slice's first stage must be winnable with the starting team as given.
func _check_slice(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var stage: Dictionary = catalog.stages["ruins_gate"]
	var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), int(stage.seed))
	_check("starting team wins the Mossy Gate", outcome.result == "win", outcome.result)


## Awakenings, temperaments and the spirit-driven effects (receivers, damage,
## haste, kill triggers and Stun as a status).
func _check_spirits(catalog: Catalog) -> void:
	var awaken: int = int(catalog.num("awaken_level"))
	var pyra_loadout: Dictionary = _loadout("pyra", "strider", "hammer", "spider", "front")
	var asleep: Dictionary = Builds.resolve(catalog, pyra_loadout, awaken - 1)
	var awake: Dictionary = Builds.resolve(catalog, pyra_loadout, awaken)
	_check("awakening waits for its level", not asleep.awakened
		and not asleep.effects.any(func(e): return e.source == "Wildfire"))
	_check("awakening adds its effects", awake.awakened and awake.effects.any(func(e): return e.source == "Wildfire"))

	var briar: Dictionary = catalog.spirit("briar")
	var history: Dictionary = {"last_frame": "", "last_allies": ["odo"], "allies": ["odo", "pyra"]}
	var back: Dictionary = _loadout("briar", "bulwark", "shield", "pillar", "back")
	_check("loyal prefers a familiar ally", Builds.preference(catalog, briar, back, history).active)
	history.allies = ["neris", "pyra"]
	_check("loyal is idle beside strangers", not Builds.preference(catalog, briar, back, history).active)
	var volta: Dictionary = catalog.spirit("volta")
	_check("patient prefers the back row", Builds.preference(catalog, volta, back, {}).active
		and not Builds.preference(catalog, volta, _loadout("volta", "bulwark", "shield", "pillar", "front"), {}).active)

	var thorns: Dictionary = _duel(catalog, [["briar", 3, _loadout("briar", "bulwark", "shield", "pillar", "front")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "strider", "hammer", "spider", "front")]])
	_check("thorns lash the attacker", _has(thorns, {"type": "damage", "cause": "effect", "unit": "b0", "source": "a0"}))

	var storm: Dictionary = _duel(catalog, [
			["sefa", awaken, _loadout("sefa", "conduit", "cannon", "pillar", "back")],
			["volta", awaken, _loadout("volta", "conduit", "cannon", "pillar", "back")],
			["pyra", awaken, _loadout("pyra", "strider", "hammer", "pillar", "front")]],
		[["rubble_imp", 6, _loadout("rubble_imp", "bulwark", "shield", "spider", "front")],
			["moss_wisp", 6, _loadout("moss_wisp", "bulwark", "shield", "spider", "front")],
			["rubble_imp", 6, _loadout("rubble_imp", "bulwark", "shield", "spider", "front")]])
	_check("tailwind hastens allies", _has(storm, {"type": "haste", "cause": "Tailwind"}))
	_check("conduction jolts soaked enemies", _has(storm, {"type": "damage", "cause": "effect", "source": "a1"}))
	_check("overcharge stuns soaked enemies", _has(storm, {"type": "status", "status": "stun", "cause": "Overcharge"}))
	# Wildfire needs a kill that leaves someone standing: Pyra alone against a weak pair.
	var wildfire: Dictionary = _duel(catalog, [["pyra", 10, _loadout("pyra", "strider", "hammer", "pillar", "front")]],
		[["cinder_mote", 1, _loadout("cinder_mote", "strider", "shield", "pillar", "front")],
			["rubble_imp", 6, _loadout("rubble_imp", "bulwark", "shield", "pillar", "front")]])
	_check("wildfire spreads burn on a kill", _has(wildfire, {"type": "status", "status": "burn", "cause": "Wildfire"}))

	var migrated: Variant = Progression.new(catalog).migrate({"schema": 1, "spirits": {"pyra": {"level": 1, "xp": 0, "last_frame": ""}}})
	_check("schema 1 saves gain remembered allies", migrated.schema == 2 and migrated.spirits.pyra.last_allies == [])
	var strict := Catalog.new()
	strict._validate_effects("probe", [{"on": "hit", "do": "damage", "flat": 2, "to": "attacker"}])
	_check("catalog rejects an unreachable receiver", not strict.errors.is_empty())


## Materials: stats from the body, element reactions, their effects in battle
## and the schema 2 save migration.
func _check_materials(catalog: Catalog) -> void:
	var stone: Dictionary = Builds.resolve(catalog, _loadout("pyra", "strider", "hammer", "pillar", "front"), 3)
	var wood: Dictionary = Builds.resolve(catalog, _loadout("pyra", "strider", "hammer", "pillar", "front", "wood"), 3)
	var kindling: Dictionary = catalog.reaction("wood", "fire")
	_check("fire in wood is Kindling", wood.reaction.get("id") == "kindling"
		and wood.effects.any(func(e): return e.source == kindling.name))
	_check("kindling trades defence for attack", wood.stats.str > stone.stats.str and wood.stats.def < stone.stats.def,
		"%s vs %s" % [wood.stats, stone.stats])
	var plain: Dictionary = Builds.resolve(catalog, _loadout("neris", "strider", "hammer", "pillar", "front", "wood"), 3)
	_check("a material only reacts with its elements", plain.reaction.is_empty()
		and not plain.breakdown.any(func(b): return String(b.label).ends_with("reaction")))

	var singe: Dictionary = _duel(catalog, [["pyra", 3, _loadout("pyra", "strider", "hammer", "pillar", "front", "wood")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "strider", "hammer", "pillar", "front")]])
	_check("kindling singes its attacker", _has(singe, {"type": "status", "status": "burn", "unit": "b0", "cause": kindling.name}))
	var glacier: Dictionary = _duel(catalog, [["neris", 3, _loadout("neris", "bulwark", "shield", "pillar", "front", "ice")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "strider", "hammer", "pillar", "front")]])
	_check("glacier soaks its attacker", _has(glacier, {"type": "status", "status": "soaked", "unit": "b0", "cause": "Glacier"}))
	var wire: Dictionary = _duel(catalog, [["volta", 3, _loadout("volta", "conduit", "cannon", "pillar", "back", "bronze")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "bulwark", "shield", "pillar", "front")],
			["moss_wisp", 3, _loadout("moss_wisp", "bulwark", "shield", "pillar", "front")]])
	_check("live wire arcs every hit", _has(wire, {"type": "chain", "unit": "a0"}))

	var progression := Progression.new(catalog)
	progression.save_enabled = false
	_check("locked material is refused", progression.set_slot(0, "material", "crystal") == false)
	var old: Dictionary = {"schema": 2, "battles": 3, "cleared": ["ruins_gate", "ruins_court"],
		"spirits": {"pyra": {"level": 2, "xp": 0, "last_frame": "", "last_allies": []},
			"neris": {"level": 2, "xp": 0, "last_frame": "", "last_allies": []},
			"odo": {"level": 2, "xp": 0, "last_frame": "", "last_allies": []}},
		"unlocks": {"frames": ["bulwark"], "arms": ["shield"], "legs": ["pillar"], "sigils": []},
		"team": [_strip(_loadout("odo", "bulwark", "shield", "pillar", "front")),
			_strip(_loadout("pyra", "bulwark", "shield", "pillar", "front")),
			_strip(_loadout("neris", "bulwark", "shield", "pillar", "back"))]}
	var migrated: Variant = progression.migrate(old)
	_check("schema 2 saves migrate to materials", progression.valid(migrated)
		and migrated.unlocks.materials == ["stone", "wood", "ice"] and migrated.team[0].material == "stone",
		JSON.stringify(migrated.get("unlocks", {})))


func _strip(loadout: Dictionary) -> Dictionary:
	loadout.erase("material")
	return loadout


func _loadout(spirit: String, frame: String, arms: String, legs: String, row: String, material: String = "stone") -> Dictionary:
	return {"spirit": spirit, "frame": frame, "arms": arms, "legs": legs, "material": material, "sigil": "", "row": row}


func _has(outcome: Dictionary, fields: Dictionary) -> bool:
	for event in outcome.events:
		var matched: bool = true
		for key in fields:
			matched = matched and event.get(key) == fields[key]
		if matched:
			return true
	return false


## Each side is a list of [spirit id, level, loadout].
func _duel(catalog: Catalog, side_a: Array, side_b: Array) -> Dictionary:
	var teams: Array = []
	for side in [side_a, side_b]:
		teams.append(side.map(func(entry): return Builds.resolve(catalog, entry[2], entry[1])))
	return BattleSim.new().run(catalog, teams[0], teams[1], 11)


## Plays the campaign in order. For each stage it samples random legal builds
## from what is unlocked, prints the win rate, then fights with the best one.
func _report(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for stage in catalog.region().stages:
		var enemies: Array = progression.enemy_team(stage)
		var wins: int = 0
		var samples: int = 1500
		var best: Array = []
		var best_margin: int = -1
		var hits: int = 0
		var hit_total: int = 0
		var chip_hits: int = 0
		var turns: int = 0
		var timeouts: int = 0
		for i in range(samples):
			var trial: Array = _random_team(progression, rng)
			progression.team = trial
			var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), enemies, int(stage.seed))
			for event in outcome.events:
				if event.type == "turn":
					turns += 1
				elif event.type == "damage" and event.cause == "attack":
					hits += 1
					hit_total += int(event.amount)
					if int(event.amount) <= 2:
						chip_hits += 1
			if outcome.result == "timeout":
				timeouts += 1
			if outcome.result == "win":
				wins += 1
				var margin: int = 0
				for unit in outcome.units:
					if unit.side == 0:
						margin += unit.hp
				if margin > best_margin:
					best_margin = margin
					best = trial
		var levels: Array = progression.spirits.keys().map(func(id): return "%s%d" % [id, progression.spirits[id].level])
		print("  %-20s random-build win rate %5.1f%%  levels %s" % [stage.name, 100.0 * wins / samples, levels])
		print("    avg hit %.1f, hits of 1-2 %.0f%%, turns per battle %.1f, timeouts %d" % [
			float(hit_total) / max(hits, 1), 100.0 * chip_hits / max(hits, 1), float(turns) / samples, timeouts])
		if best.is_empty():
			print("    no winning build found; grinding the previous stage once")
			progression.team = _random_team(progression, rng)
			progression.apply_battle(stage, "loss")
			continue
		progression.team = best
		for loadout in best:
			print("    best: %s" % [loadout])
		progression.apply_battle(stage, "win")


func _random_team(progression: Progression, rng: RandomNumberGenerator) -> Array:
	var ids: Array = progression.spirits.keys()
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	var team: Array = []
	for slot in range(3):
		var sigils: Array = [""] + progression.unlocks.sigils
		team.append({
			"spirit": ids[slot],
			"frame": _pick(progression.unlocks.frames, rng),
			"arms": _pick(progression.unlocks.arms, rng),
			"legs": _pick(progression.unlocks.legs, rng),
			"material": _pick(progression.unlocks.materials, rng),
			"sigil": _pick(sigils, rng),
			"row": _pick(["front", "back"], rng),
		})
	return team


func _pick(options: Array, rng: RandomNumberGenerator) -> Variant:
	return options[rng.randi_range(0, options.size() - 1)]
