extends RefCounted
## Single owner of the persistent collection: spirits, unlocked parts, the
## golems (the team loadout), unspent golem cores and cleared stages. Every
## change goes through here and is validated against the catalog; the UI never edits this state directly.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const SaveSchema = preload("res://scripts/core/save_schema.gd")
const Challenges = preload("res://scripts/core/challenges.gd")
const Experience = preload("res://scripts/core/experience.gd")
const SAVE_SCHEMA: int = SaveSchema.VERSION
const BUILD_CELLS: Array[String] = SaveSchema.BUILD_CELLS
const RUN_KEYS: Array[String] = SaveSchema.RUN_KEYS

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
## Ids of every Codex challenge and feat ever met, across all playthroughs.
var challenges: Array = []
var feats: Array = []
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
	challenges = []
	feats = []


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
		"cores": cores, "cleared": cleared, "battles": battles, "cycle": cycle, "run": run,
		"challenges": challenges, "feats": feats}


func migrate(data: Variant) -> Variant:
	return SaveSchema.migrate(catalog, data)


func valid(data: Variant) -> bool:
	return SaveSchema.valid(catalog, data)


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
	challenges = data.challenges.map(func(id): return String(id))
	feats = data.feats.map(func(id): return String(id))
	# A save may have met a region's challenges before its mastery existed.
	for region in catalog.regions().filter(func(r): return Challenges.mastered(r, challenges)):
		_grant(region.mastery.rewards, [])


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
		resolved.append(Builds.resolve(catalog, enemy, enemy_level(int(enemy.level)), {}, true))
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


## Applies XP, last-used frames, first-clear rewards, challenges and feats.
## Returns a report the result screen shows: {"xp": [lines, see _give_xp; resting
## spirits' lines carry "resting"], "rewards": [{kind, id}], "first_clear",
## "challenges": [ids], "masteries": [region ids], "feats": [ids], "spoiled": [feat ids this battle put out of
## reach for the rest of the playthrough]}.
## `units` is the finished battle's golems (BattleSim's `units`); without them
## a win counts as nobody falling and a defeat as the whole team falling.
func apply_battle(stage: Dictionary, outcome: String, units: Array = []) -> Dictionary:
	battles += 1
	var won: bool = outcome == "win"
	var in_reach: Array = feats_in_reach()
	_record_run(won, units)
	var first_clear: bool = won and not stage.id in cleared
	var xp_key: String = "xp.loss"
	if won:
		xp_key = "xp.first_clear" if first_clear else "xp.repeat_win"
	var report: Dictionary = {"xp": [], "rewards": [], "first_clear": first_clear, "challenges": [], "masteries": [],
		"feats": [], "spoiled": in_reach.filter(func(id): return not id in feats_in_reach())}
	for loadout in team:
		var entry: Dictionary = spirits[loadout.spirit]
		entry.last_frame = loadout.frame
		entry.last_allies = _allies_of(loadout.spirit)
		report.xp.append(_give_xp(loadout.spirit, stage_xp(stage, int(entry.level), catalog.num(xp_key), loadout.spirit)))
	# Resting spirits watch from the laboratory and learn a share of it, so a
	# spirit left on the bench can still be fielded later without grinding.
	for id in resting_spirits():
		var line: Dictionary = _give_xp(id, stage_xp(stage, int(spirits[id].level), catalog.num(xp_key) * catalog.num("xp.resting"), id))
		line["resting"] = true
		report.xp.append(line)
	if first_clear:
		cleared.append(stage.id)
		_grant(stage.get("rewards", {}), report.rewards)
	if won and not units.is_empty():
		var golems: Array = units.filter(func(unit): return unit.side == 0)
		for id in stage.get("challenges", []).map(func(c): return c.id):
			if not id in challenges and Challenges.met(catalog.challenges[id].rules, golems, cycle):
				challenges.append(id)
				report.challenges.append(id)
				_grant(catalog.challenges[id].get("rewards", {}), report.rewards)
		for region in Challenges.newly_mastered(catalog, report.challenges, challenges):
			report.masteries.append(region.id)
			_grant(region.mastery.rewards, report.rewards)
	if first_clear and playthrough_complete():
		for id in catalog.feats:
			if not id in feats and Challenges.feat_met(catalog.feats[id].rules, run, cycle):
				feats.append(id)
				report.feats.append(id)
				_grant(catalog.feats[id].get("rewards", {}), report.rewards)
	return report


func _give_xp(id: String, gained: int) -> Dictionary:
	return Experience.give(catalog, id, spirits[id], gained)


## Adds a stage's, challenge's or feat's rewards to the collection and lists
## the new ones in `listed`. A New Game+ team is usually already whole, so
## cores only fill empty cradles, and anything already owned is skipped.
func _grant(rewards: Dictionary, listed: Array) -> void:
	var gained_cores: int = min(int(rewards.get("cores", 0)), int(catalog.num("team_size")) - team.size() - cores)
	if gained_cores > 0:
		cores += gained_cores
		listed.append({"kind": "cores", "id": str(gained_cores)})
	for kind in rewards:
		if kind == "cores":
			continue
		for id in rewards[kind]:
			if kind == "spirits":
				if not spirits.has(id):
					spirits[id] = _fresh_spirit(_join_level())
					listed.append({"kind": kind, "id": id})
			elif not id in unlocks[kind]:
				unlocks[kind] = catalog.part_order[kind].filter(func(part): return part in unlocks[kind] or part == id)
				listed.append({"kind": kind, "id": id})


func _record_run(won: bool, units: Array) -> void:
	var fell: int = units.filter(func(unit): return unit.side == 0 and not unit.alive).size()
	if units.is_empty() and not won:
		fell = team.size()
	run.falls += fell
	run.losses += 0 if won else 1
	run.most_golems = max(int(run.most_golems), team.size())


## Feats not yet earned that this playthrough's record still leaves possible.
func feats_in_reach() -> Array:
	var open: Array = []
	for id in catalog.feats:
		if not id in feats and Challenges.feat_in_reach(catalog.feats[id].rules, run, cycle):
			open.append(id)
	return open


## Whether the final stage has fallen in this playthrough.
func campaign_complete() -> bool:
	return catalog.finale_id in cleared


## Whether every stage has been cleared in this playthrough: when feats are judged.
func playthrough_complete() -> bool:
	return catalog.stages.keys().all(func(id): return id in cleared)


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


func xp_to_next(level: int) -> int:
	return Experience.xp_to_next(catalog, level)


## XP one spirit at `spirit_level` earns from this stage (see Experience.stage_xp);
## without a `spirit_id` only the global xp.gain_percent applies.
func stage_xp(stage: Dictionary, spirit_level: int, outcome_factor: float, spirit_id: String = "") -> int:
	return Experience.stage_xp(catalog, _average_level(stage), spirit_level, outcome_factor, spirit_id)


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
