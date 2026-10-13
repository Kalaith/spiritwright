extends RefCounted
## Single owner of the persistent collection: spirits, unlocked parts, the
## golems (the team loadout), unspent golem cores and cleared stages. Every
## change goes through here and is validated against the catalog; the UI never edits this state directly.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const SaveMigrations = preload("res://scripts/core/save_migrations.gd")
const SAVE_SCHEMA: int = 6
const BUILD_CELLS: Array[String] = SaveMigrations.BUILD_CELLS
const RUN_KEYS: Array[String] = ["falls", "losses", "most_golems"]

var catalog: Catalog
## spirit id -> {"level", "xp", "last_frame", "last_allies"}
var spirits: Dictionary = {}
## catalog kind -> Array of unlocked ids, in catalog order.
var unlocks: Dictionary = {}
## One loadout per built golem: the campaign starts with one and the
## laboratory builds more, up to team_size, by spending golem cores.
var team: Array = []
var cores: int = 0
var cleared: Array = []
var battles: int = 0
## Which playthrough this is: 0 for the first, 1 for the first New Game+, and so
## on. Each cycle fights every stage again with stronger wild spirits.
var cycle: int = 0
## This playthrough's record, for the feats: golems of yours that fell, battles
## not won, and the most golems fielded in one battle.
var run: Dictionary = {}
var save_path: String = "user://spiritwright_save.json"
var save_enabled: bool = true
var last_error: String = ""


func _init(data: Catalog) -> void:
	catalog = data


func new_game() -> void:
	var start: Dictionary = catalog.campaign.start
	spirits.clear()
	for id in start.spirits:
		spirits[id] = _fresh_spirit(1)
	unlocks.clear()
	for kind in Catalog.PART_KINDS:
		unlocks[kind] = []
		for id in catalog.part_order[kind]:
			if id in start.unlocks.get(kind, []):
				unlocks[kind].append(id)
	team = start.team.duplicate(true)
	cores = 0
	cleared = []
	battles = 0
	cycle = 0
	_reset_run()


func _reset_run() -> void:
	run = {}
	for key in RUN_KEYS:
		run[key] = 0


func has_save() -> bool:
	return save_enabled and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"))


func load_game() -> bool:
	for path in [save_path, save_path + ".bak"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		parsed = migrate(parsed)
		if valid(parsed):
			_apply(parsed)
			last_error = "" if path == save_path else "Recovered your laboratory from the backup save."
			return true
	last_error = "The save could not be read."
	return false


func save_game() -> bool:
	if not save_enabled:
		return true
	var snapshot: Dictionary = to_dict()
	if not valid(snapshot):
		last_error = "Refused to write an invalid save."
		return false
	var temporary: String = save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the save."
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	if not valid(JSON.parse_string(FileAccess.get_file_as_string(temporary))):
		last_error = "The written save did not read back."
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		last_error = "Could not replace the save."
		return false
	last_error = ""
	return true


func to_dict() -> Dictionary:
	return {"schema": SAVE_SCHEMA, "spirits": spirits, "unlocks": unlocks, "team": team,
		"cores": cores, "cleared": cleared, "battles": battles, "cycle": cycle, "run": run}


func migrate(data: Variant) -> Variant:
	return SaveMigrations.migrate(catalog, data)


func valid(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema", 0)) != SAVE_SCHEMA:
		return false
	if not data.get("spirits") is Dictionary or data.spirits.is_empty():
		return false
	for id in data.spirits:
		var entry: Variant = data.spirits[id]
		if not catalog.spirit(id).get("playable", false) or not entry is Dictionary:
			return false
		var level: int = int(entry.get("level", 0))
		if level < 1 or level > int(catalog.num("level_cap")) or int(entry.get("xp", -1)) < 0:
			return false
		if not entry.get("last_frame") is String or not entry.get("last_allies") is Array:
			return false
		for ally in entry.last_allies:
			if not catalog.spirit(String(ally)).get("playable", false):
				return false
	if not data.get("unlocks") is Dictionary:
		return false
	for kind in Catalog.PART_KINDS:
		if not data.unlocks.get(kind) is Array:
			return false
		for id in data.unlocks[kind]:
			if catalog.part(kind, String(id)).is_empty():
				return false
	if not data.get("cleared") is Array or not (data.get("battles") is int or data.get("battles") is float):
		return false
	for id in data.cleared:
		if not catalog.stages.has(id):
			return false
	if not (data.get("cores") is int or data.get("cores") is float) or int(data.cores) < 0:
		return false
	if not (data.get("cycle") is int or data.get("cycle") is float) or int(data.cycle) < 0:
		return false
	if not data.get("run") is Dictionary:
		return false
	for key in RUN_KEYS:
		var count: Variant = data.run.get(key)
		if not (count is int or count is float) or int(count) < 0:
			return false
	if not data.get("team") is Array or data.team.is_empty():
		return false
	if data.team.size() + int(data.cores) > int(catalog.num("team_size")):
		return false
	var used: Dictionary = {}
	for loadout in data.team:
		if not loadout is Dictionary or not data.spirits.has(loadout.get("spirit", "")) or used.has(loadout.spirit):
			return false
		used[loadout.spirit] = true
		for key in Catalog.LOADOUT_KEYS:
			if not loadout.get(Catalog.LOADOUT_KEYS[key], "") in data.unlocks[key]:
				return false
		var sigil: Variant = loadout.get("sigil", "")
		if not sigil is String or (sigil != "" and not sigil in data.unlocks.sigils):
			return false
		if not loadout.get("row") in Catalog.ROWS or not Catalog.valid_lane(loadout.get("lane")):
			return false
	return Catalog.distinct_cells(data.team)


func _apply(data: Dictionary) -> void:
	spirits = {}
	for id in data.spirits:
		var entry: Dictionary = data.spirits[id]
		spirits[id] = {"level": int(entry.level), "xp": int(entry.xp), "last_frame": String(entry.last_frame),
			"last_allies": entry.last_allies.map(func(ally): return String(ally))}
	unlocks = {}
	for kind in Catalog.PART_KINDS:
		unlocks[kind] = []
		for id in catalog.part_order[kind]:
			if id in data.unlocks[kind]:
				unlocks[kind].append(id)
	team = data.team.duplicate(true)
	for loadout in team:
		loadout["sigil"] = String(loadout.get("sigil", ""))
		loadout["lane"] = int(loadout.lane)
	cores = int(data.cores)
	cleared = data.cleared.duplicate()
	battles = int(data.battles)
	cycle = int(data.cycle)
	run = {}
	for key in RUN_KEYS:
		run[key] = int(data.run[key])


func stage_state(stage_id: String) -> String:
	if stage_id in cleared:
		return "cleared"
	for required in catalog.stages[stage_id].get("requires", []):
		if not required in cleared:
			return "locked"
	return "open"


func resolve_slot(slot: int) -> Dictionary:
	var loadout: Dictionary = team[slot]
	var entry: Dictionary = spirits[loadout.spirit]
	var history: Dictionary = {"last_frame": entry.last_frame, "last_allies": entry.last_allies,
		"allies": _allies_of(loadout.spirit)}
	return Builds.resolve(catalog, loadout, int(entry.level), history)


func _allies_of(spirit_id: String) -> Array:
	var allies: Array = []
	for loadout in team:
		if loadout.spirit != spirit_id:
			allies.append(loadout.spirit)
	return allies


func resolved_team() -> Array:
	var resolved: Array = []
	for slot in range(team.size()):
		resolved.append(resolve_slot(slot))
	return resolved


func enemy_team(stage: Dictionary) -> Array:
	var resolved: Array = []
	for enemy in stage.enemies:
		resolved.append(Builds.resolve(catalog, enemy, enemy_level(int(enemy.level))))
	return resolved


## A wild spirit's level in this playthrough: each New Game+ cycle adds
## new_game_plus.level_step to the level the stage lists, up to level_cap.
func enemy_level(listed: int) -> int:
	return min(int(catalog.num("level_cap")), listed + cycle * int(catalog.num("new_game_plus.level_step")))


## Changes one loadout field. Choosing a spirit already in another slot swaps
## the two, and so does moving to a cell ("front:0") another golem stands in.
## Returns false when the choice is not unlocked.
func set_slot(slot: int, key: String, value: String) -> bool:
	if slot < 0 or slot >= team.size():
		return false
	match key:
		"spirit":
			if not spirits.has(value):
				return false
			for other in range(team.size()):
				if other != slot and team[other].spirit == value:
					team[other].spirit = team[slot].spirit
		"frame", "arms", "legs", "material":
			var kind: String = {"frame": "frames", "material": "materials"}.get(key, key)
			if not value in unlocks[kind]:
				return false
		"sigil":
			if value != "" and not value in unlocks.sigils:
				return false
		"cell":
			var row: String = value.get_slice(":", 0)
			if value.get_slice_count(":") != 2 or not row in Catalog.ROWS or not value.get_slice(":", 1).is_valid_int() 					or not Catalog.valid_lane(value.get_slice(":", 1).to_int()):
				return false
			for other in range(team.size()):
				if other != slot and Catalog.cell_of(team[other]) == value:
					team[other].row = team[slot].row
					team[other].lane = team[slot].lane
			team[slot].row = row
			team[slot].lane = value.get_slice(":", 1).to_int()
			return true
		_:
			return false
	team[slot][key] = value
	return true


## Applies XP, last-used frames and first-clear rewards. Returns a report the
## result screen shows: {"xp": [{spirit, gained, from, to, rises}], "rewards": [...], "first_clear"}.
## `units` is the finished battle's golems (BattleSim's `units`); without them
## a win counts as nobody falling and a defeat as the whole team falling.
func apply_battle(stage: Dictionary, outcome: String, units: Array = []) -> Dictionary:
	battles += 1
	var won: bool = outcome == "win"
	_record_run(won, units)
	var first_clear: bool = won and not stage.id in cleared
	var xp_key: String = "xp.loss"
	if won:
		xp_key = "xp.first_clear" if first_clear else "xp.repeat_win"
	var report: Dictionary = {"xp": [], "rewards": [], "first_clear": first_clear}
	var cap: int = int(catalog.num("level_cap"))
	for loadout in team:
		var entry: Dictionary = spirits[loadout.spirit]
		var spirit_def: Dictionary = catalog.spirit(loadout.spirit)
		var gained: int = stage_xp(stage, int(entry.level), catalog.num(xp_key))
		var line: Dictionary = {"spirit": loadout.spirit, "gained": gained, "from": entry.level, "rises": {}}
		entry.last_frame = loadout.frame
		entry.last_allies = _allies_of(loadout.spirit)
		entry.xp += gained
		while entry.xp >= xp_to_next(entry.level) and entry.level < cap:
			entry.xp -= xp_to_next(entry.level)
			var rises: Dictionary = Builds.level_up_gains(catalog, spirit_def, entry.level)
			for stat in rises:
				line.rises[stat] = int(line.rises.get(stat, 0)) + int(rises[stat])
			entry.level += 1
		if entry.level >= cap:
			entry.xp = 0
		line["to"] = entry.level
		line["awakened"] = Builds.awakened(catalog, spirit_def, entry.level) 			and not Builds.awakened(catalog, spirit_def, int(line.from))
		report.xp.append(line)
	if first_clear:
		cleared.append(stage.id)
		var rewards: Dictionary = stage.get("rewards", {})
		# A New Game+ team is usually already whole: cores only fill empty cradles.
		var gained_cores: int = min(int(rewards.get("cores", 0)), int(catalog.num("team_size")) - team.size() - cores)
		if gained_cores > 0:
			cores += gained_cores
			report.rewards.append({"kind": "cores", "id": str(gained_cores)})
		for kind in rewards:
			if kind == "cores":
				continue
			for id in rewards[kind]:
				if kind == "spirits":
					if not spirits.has(id):
						spirits[id] = _fresh_spirit(_join_level())
						report.rewards.append({"kind": kind, "id": id})
				elif not id in unlocks[kind]:
					unlocks[kind].append(id)
					report.rewards.append({"kind": kind, "id": id})
		for kind in Catalog.PART_KINDS:
			var ordered: Array = []
			for id in catalog.part_order[kind]:
				if id in unlocks[kind]:
					ordered.append(id)
			unlocks[kind] = ordered
	return report


func _record_run(won: bool, units: Array) -> void:
	var fell: int = units.filter(func(unit): return unit.side == 0 and not unit.alive).size()
	if units.is_empty() and not won:
		fell = team.size()
	run.falls += fell
	run.losses += 0 if won else 1
	run.most_golems = max(int(run.most_golems), team.size())


## Whether the final stage has fallen in this playthrough.
func campaign_complete() -> bool:
	return catalog.finale_id in cleared


## Starts the next playthrough once the finale is won: every stage is fought
## again with stronger wild spirits, and the spirits, their levels, the parts
## and the golems all carry over.
func start_new_game_plus() -> bool:
	if not campaign_complete():
		return false
	cycle += 1
	cleared = []
	_reset_run()
	return true


## XP a spirit at `level` needs to reach the next level: each level costs more.
func xp_to_next(level: int) -> int:
	return int(catalog.num("xp_per_level") + catalog.num("xp_per_level_growth") * (level - 1))


## XP one spirit earns from a stage: the enemies' average level times
## xp.per_stage_level, scaled by the outcome, and by how far the spirit's level
## sits below (more) or above (less) that average. Levels cost a steady amount
## more each time, so a spirit keeps pace with the stages without grinding.
func stage_xp(stage: Dictionary, spirit_level: int, outcome_factor: float) -> int:
	var average: float = _average_level(stage)
	var level_factor: float = clampf(1.0 + (average - spirit_level) * catalog.num("xp.level_gap_step"),
		catalog.num("xp.min_factor"), catalog.num("xp.max_factor"))
	return max(1, int(round(average * catalog.num("xp.per_stage_level") * outcome_factor * level_factor)))


func _average_level(stage: Dictionary) -> float:
	var total_levels: int = 0
	for enemy in stage.enemies:
		total_levels += enemy_level(int(enemy.level))
	return float(total_levels) / max(1, stage.enemies.size())


## Average enemy level of a stage, rounded, for the campaign screen.
func stage_level(stage: Dictionary) -> int:
	return int(round(_average_level(stage)))


func can_build() -> bool:
	return cores > 0 and team.size() < int(catalog.num("team_size")) and not resting_spirits().is_empty()


## Spirits with no golem, in catalog order.
func resting_spirits() -> Array:
	var resting: Array = []
	for id in catalog.player_spirit_ids:
		if spirits.has(id) and not team.any(func(loadout): return loadout.spirit == id):
			resting.append(id)
	return resting


## The laboratory spends a golem core on a new body for the first resting
## spirit, built from the first unlocked part of each kind, standing in the
## first free cell of BUILD_CELLS.
func build_golem() -> bool:
	if not can_build():
		return false
	var taken: Array = team.map(func(loadout): return Catalog.cell_of(loadout))
	var cell: String = BUILD_CELLS.filter(func(c): return not c in taken)[0]
	team.append({"spirit": resting_spirits()[0], "frame": unlocks.frames[0], "arms": unlocks.arms[0],
		"legs": unlocks.legs[0], "material": unlocks.materials[0], "sigil": "",
		"row": cell.get_slice(":", 0), "lane": cell.get_slice(":", 1).to_int()})
	cores -= 1
	return true


func _fresh_spirit(level: int) -> Dictionary:
	return {"level": level, "xp": 0, "last_frame": "", "last_allies": []}


## A rescued spirit joins at the team's average level so it can fight at once.
func _join_level() -> int:
	var total: int = 0
	for loadout in team:
		total += int(spirits[loadout.spirit].level)
	return max(1, int(floor(float(total) / max(1, team.size()))))


func region_cleared() -> bool:
	for id in catalog.stages:
		if not id in cleared:
			return false
	return true
