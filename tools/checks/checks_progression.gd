extends "res://tools/checks/check_module.gd"
## The data and the persistent laboratory: the catalog loads, the campaign's
## progression rules, and the save on disk.

const SaveSchema = preload("res://scripts/core/save_schema.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


## Every catalog in data/ loads and validates.
func check_catalog_loads():
	_check("catalog loads", catalog.errors.is_empty(), ", ".join(catalog.errors))
	return verdict()


func check_progression():
	var progression := Progression.new(catalog)
	progression.save_path = Expect.scratch_path("progression_save.json")
	progression.new_game()
	_check("new game is a valid save", progression.valid(progression.to_dict()))
	_check("the campaign starts with one golem", progression.team.size() == 1 and progression.cores == 0)
	_check("locked part is refused", not progression.set_slot(0, "arms", "cannon"))
	_check("a resting spirit can take the golem", progression.set_slot(0, "spirit", "neris")
		and progression.team[0].spirit == "neris" and progression.resting_spirits() == ["pyra", "odo"])
	_check("no golem is built without a core", not progression.build_golem() and progression.team.size() == 1)
	var report: Dictionary = progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("first clear unlocks the cannon", "cannon" in progression.unlocks.arms and report.first_clear)
	_check("the gate yields a golem core", progression.cores == 1 and report.rewards.any(func(r): return r.kind == "cores"))
	_check("stage two opens", progression.stage_state("ruins_court") == "open")
	_check("the laboratory builds a second golem", progression.build_golem() and progression.team.size() == 2
		and progression.cores == 0 and progression.team[1].spirit == "pyra" and Catalog.cell_of(progression.team[1]) == "back:1")
	_check("moving into an occupied cell swaps the two golems", progression.set_slot(1, "cell", "front:1")
		and Catalog.cell_of(progression.team[0]) == "back:1" and Catalog.cell_of(progression.team[1]) == "front:1")
	_check("a cell off the board is refused", not progression.set_slot(0, "cell", "front:3")
		and not progression.set_slot(0, "cell", "middle:0"))
	_check("swapping spirits keeps them unique", progression.set_slot(0, "spirit", "pyra")
		and progression.team[1].spirit == "neris")
	progression.cores = int(catalog.num("team_size")) - 1
	_check("a save cannot hold more golems than team_size", not progression.valid(progression.to_dict()))
	progression.cores = 0
	var gate_xp: int = progression.stage_xp(catalog.stages["ruins_gate"], 1, catalog.num("xp.repeat_win"))
	var court_xp: int = progression.stage_xp(catalog.stages["ruins_court"], 1, catalog.num("xp.repeat_win"))
	_check("a stronger enemy team is worth more XP", court_xp > gate_xp, "%d vs %d" % [court_xp, gate_xp])
	_check("an over-levelled spirit earns less XP",
		progression.stage_xp(catalog.stages["ruins_gate"], 5, 1.0) < gate_xp)
	_check("each level costs more XP than the last", progression.xp_to_next(10) > progression.xp_to_next(1))
	var court: Dictionary = catalog.stages["ruins_court"]
	var full_xp: int = progression.stage_xp(court, 1, 1.0)
	catalog.spirit("pyra")["xp_percent"] = 50
	var halved_xp: int = progression.stage_xp(court, 1, 1.0, "pyra")
	catalog.spirit("pyra").erase("xp_percent")
	_check("a spirit's xp_percent scales its XP on top of the global rate",
		halved_xp == int(round(full_xp / 2.0)) and progression.stage_xp(court, 1, 1.0, "pyra") == full_xp,
		"%d vs %d" % [halved_xp, full_xp])
	var reachable: Array = []
	var grew: bool = true
	while grew:
		grew = false
		for stage in catalog.stages.values():
			if not stage.id in reachable and stage.get("requires", []).all(func(id): return id in reachable):
				reachable.append(stage.id)
				grew = true
	_check("every stage in every region can be reached", reachable.size() == catalog.stages.size(),
		str(catalog.stages.keys().filter(func(id): return not id in reachable)))
	progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("a replay grants no second core", progression.cores == 0)
	_check("save writes", progression.save_game(), progression.last_error)
	var reloaded := Progression.new(catalog)
	reloaded.save_path = progression.save_path
	_check("save reads back", reloaded.load_game() and JSON.stringify(reloaded.to_dict()) == JSON.stringify(progression.to_dict()))
	return verdict()


## The save survives damage: a torn save falls back to its backup and says so,
## a save from a newer version is kept and never written over, and a new game
## keeps the old laboratory as .previous.
func check_save_safety():
	var path: String = Expect.scratch_path("safety_save.json")
	var progression := _fresh()
	progression.save_enabled = true
	progression.save_path = path
	progression.save_game()
	progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("a second save keeps the first as its backup", progression.save_game() and FileAccess.file_exists(path + ".bak"),
		progression.last_error)
	var torn := FileAccess.open(path, FileAccess.WRITE)
	torn.store_string("{\"schema\": ")
	torn.close()
	var recovered := Progression.new(catalog)
	recovered.save_path = path
	_check("a torn save recovers from its backup and says so", recovered.has_save() and recovered.load_game()
		and not recovered.last_error.is_empty() and recovered.cleared.is_empty(), recovered.last_error)
	_check("the recovered laboratory saves again and keeps the torn file", recovered.save_game()
		and FileAccess.file_exists(path + ".corrupt"), recovered.last_error)
	var newer: Dictionary = progression.to_dict()
	newer.schema = SaveSchema.VERSION + 1
	var future := FileAccess.open(path, FileAccess.WRITE)
	future.store_string(JSON.stringify(newer))
	future.close()
	var cautious := Progression.new(catalog)
	cautious.save_path = path
	cautious.new_game()
	_check("a save from a newer version is not loaded", not cautious.load_game(), cautious.last_error)
	_check("nor written over", not cautious.save_game()
		and int(JSON.parse_string(FileAccess.get_file_as_string(path)).schema) == SaveSchema.VERSION + 1)
	var restart := Progression.new(catalog)
	restart.save_path = Expect.scratch_path("restart_save.json")
	restart.new_game()
	restart.save_game()
	_check("a new game keeps the old laboratory as .previous", restart.storage.keep_previous()
		and FileAccess.file_exists(restart.save_path + ".previous"))
	return verdict()
