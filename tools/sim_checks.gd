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
		for i in range(samples):
			var trial: Array = _random_team(progression, rng)
			progression.team = trial
			var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), enemies, int(stage.seed))
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
			"sigil": _pick(sigils, rng),
			"row": _pick(["front", "back"], rng),
		})
	return team


func _pick(options: Array, rng: RandomNumberGenerator) -> Variant:
	return options[rng.randi_range(0, options.size() - 1)]
