extends RefCounted
## Checks for the long game: New Game+, the playthrough record, recruits,
## challenges and feats. Called from sim_checks.gd, which owns PASS/FAIL.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")

var checks: Object
var catalog: Catalog


func _init(runner: Object, data: Catalog) -> void:
	checks = runner
	catalog = data


func run() -> void:
	_check_new_game_plus()


func _check(name: String, ok: bool, detail: String = "") -> void:
	checks._check(name, ok, detail)


func _fresh() -> Progression:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	return progression


## Wins every stage in campaign order, building golems as cores arrive.
func _clear_all(progression: Progression) -> void:
	for stage in catalog.stages.values():
		progression.apply_battle(stage, "win")
		while progression.build_golem():
			pass


func _check_new_game_plus() -> void:
	var progression := _fresh()
	_check("the level cap leaves room past the campaign", int(catalog.num("level_cap")) == 50)
	_check("a new game starts the first playthrough with a clean record", progression.cycle == 0
		and progression.run.values().all(func(count): return count == 0))
	_check("New Game+ waits for the finale", not progression.start_new_game_plus())
	progression.apply_battle(catalog.stages["ruins_gate"], "loss")
	_check("a defeat counts the whole team as fallen", progression.run.falls == progression.team.size()
		and progression.run.losses == 1)
	_clear_all(progression)
	var team_before: String = JSON.stringify(progression.team)
	var spirits_before: Array = progression.spirits.keys()
	var gate_xp: int = progression.stage_xp(catalog.stages["ruins_gate"], 10, 1.0)
	_check("the finale completes the playthrough", progression.campaign_complete())
	_check("New Game+ begins after the finale", progression.start_new_game_plus() and progression.cycle == 1
		and progression.cleared.is_empty() and progression.run.falls == 0)
	_check("New Game+ keeps the spirits and golems", progression.spirits.keys() == spirits_before
		and JSON.stringify(progression.team) == team_before)
	var step: int = int(catalog.num("new_game_plus.level_step"))
	var gate: Array = progression.enemy_team(catalog.stages["ruins_gate"])
	_check("New Game+ wild spirits are stronger", int(gate[0].level) == int(catalog.stages["ruins_gate"].enemies[0].level) + step,
		str(gate[0].level))
	_check("stronger enemies are worth more XP", progression.stage_xp(catalog.stages["ruins_gate"], 10, 1.0) > gate_xp)
	progression.cycle = 10
	_check("enemy levels stop at the level cap", progression.enemy_team(catalog.stages[catalog.finale_id]).all(
		func(golem): return int(golem.level) == int(catalog.num("level_cap"))))
	progression.cycle = 1
	var cores: int = progression.cores
	progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("a full team gains no extra golem cores", progression.cores == cores and progression.valid(progression.to_dict()))
	var old: Dictionary = progression.to_dict()
	old.schema = 5
	old.erase("cycle")
	old.erase("run")
	var migrated: Variant = progression.migrate(old)
	_check("schema 5 saves are the first playthrough with a spoiled record", progression.valid(migrated)
		and migrated.cycle == 0 and migrated.run.falls > 0, JSON.stringify(migrated.get("run", {})))
