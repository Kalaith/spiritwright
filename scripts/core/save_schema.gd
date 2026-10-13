extends RefCounted
## The save file's shape: validation of the current schema, and the steps that
## bring an older save up to it, one schema at a time. Each step only fills in
## what the older schema lacked; `valid` then checks the result.

const Catalog = preload("res://scripts/core/catalog.gd")
const Crucible = preload("res://scripts/core/crucible.gd")
const CrucibleRecord = preload("res://scripts/core/crucible_record.gd")
const VERSION: int = 8
## The playthrough record's counters (see Progression.run).
const RUN_KEYS: Array[String] = ["falls", "losses", "most_golems"]
## Where newly built golems stand, in order of preference: centre lanes first.
const BUILD_CELLS: Array[String] = ["front:1", "back:1", "front:0", "front:2", "back:0", "back:2"]


## Schema 1 predates Loyal spirits remembering their allies: they start with none.
## Schema 2 predates materials: every golem is rebuilt in the first starting
## material, and the materials the start and cleared stages grant unlock.
## Schema 3 predates golem cores: those saves already field a full team.
## Schema 4 predates lanes: each row's golems take its centre lane first.
## Schema 5 predates New Game+ and the playthrough record: it is the first
## playthrough, and one already under way cannot prove it never lost a golem,
## so its record starts spoiled (the next playthrough starts clean).
## Schema 6 predates the Codex: no challenge or feat has been met yet.
## Schema 7 predates the Crucible and Restless spirits: no run, no records, and
## no spirit remembers its last build.
static func migrate(catalog: Catalog, data: Variant) -> Variant:
	if not data is Dictionary or not data.get("spirits") is Dictionary:
		return data
	if int(data.get("schema", 0)) == 1:
		for id in data.spirits:
			if data.spirits[id] is Dictionary:
				data.spirits[id]["last_allies"] = []
		data["schema"] = 2
	if int(data.get("schema", 0)) == 2 and data.get("unlocks") is Dictionary and data.get("team") is Array \
			and data.get("cleared") is Array:
		var start: Array = catalog.campaign.start.unlocks.get("materials", [])
		var granted: Array = start.duplicate()
		for id in data.cleared:
			for material in catalog.stages.get(String(id), {}).get("rewards", {}).get("materials", []):
				granted.append(material)
		data.unlocks["materials"] = catalog.part_order.materials.filter(func(id): return id in granted)
		for loadout in data.team:
			if loadout is Dictionary and not start.is_empty():
				loadout["material"] = start[0]
		data["schema"] = 3
	if int(data.get("schema", 0)) == 3:
		data["cores"] = 0
		data["schema"] = 4
	if int(data.get("schema", 0)) == 4 and data.get("team") is Array:
		var taken: Array = []
		for loadout in data.team:
			if not loadout is Dictionary:
				continue
			for cell in BUILD_CELLS:
				if cell.begins_with(String(loadout.get("row", "")) + ":") and not cell in taken:
					taken.append(cell)
					loadout["lane"] = int(cell.get_slice(":", 1))
					break
		data["schema"] = 5
	if int(data.get("schema", 0)) == 5:
		data["cycle"] = 0
		var played: bool = int(data.get("battles", 0)) > 0
		data["run"] = {"falls": 1 if played else 0, "losses": 1 if played else 0,
			"most_golems": int(catalog.num("team_size")) if played else 0}
		data["schema"] = 6
	if int(data.get("schema", 0)) == 6:
		data["challenges"] = []
		data["feats"] = []
		data["schema"] = 7
	if int(data.get("schema", 0)) == 7:
		for id in data.spirits:
			if data.spirits[id] is Dictionary:
				data.spirits[id]["last_build"] = ""
		data["crucible"] = CrucibleRecord.empty()
		data["schema"] = 8
	return data


## Whether `data` is a complete save of this schema that the catalog can load.
static func valid(catalog: Catalog, data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema", 0)) != VERSION:
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
		if not entry.get("last_frame") is String or not entry.get("last_build") is String or not entry.get("last_allies") is Array:
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
	for key in ["challenges", "feats"]:
		var known: Dictionary = catalog.challenges if key == "challenges" else catalog.feats
		if not data.get(key) is Array or data[key].any(func(id): return not known.has(id)):
			return false
	if not data.get("team") is Array or data.team.is_empty():
		return false
	if data.team.size() + int(data.cores) > int(catalog.num("team_size")):
		return false
	if not data.get("crucible") is Dictionary or not _valid_crucible(catalog, data, data.crucible):
		return false
	return valid_team(catalog, data, data.team)


## Whether `team` is a list of loadouts the save `data` can field: owned
## spirits, each once, unlocked parts, finishes its Crucible milestones earned,
## and one golem per cell.
static func valid_team(catalog: Catalog, data: Dictionary, team: Variant) -> bool:
	if not team is Array or team.is_empty() or team.size() > int(catalog.num("team_size")):
		return false
	var finishes: Array = Crucible.unlocked(catalog, data.crucible.milestones, "finishes")
	var used: Dictionary = {}
	for loadout in team:
		if not loadout is Dictionary or not data.spirits.has(loadout.get("spirit", "")) or used.has(loadout.spirit):
			return false
		used[loadout.spirit] = true
		for key in Catalog.LOADOUT_KEYS:
			if not loadout.get(Catalog.LOADOUT_KEYS[key], "") in data.unlocks[key]:
				return false
		var sigil: Variant = loadout.get("sigil", "")
		if not sigil is String or (sigil != "" and not sigil in data.unlocks.sigils):
			return false
		var finish: Variant = loadout.get("finish", "")
		if not finish is String or (finish != "" and not finish in finishes):
			return false
		if not loadout.get("row") in Catalog.ROWS or not Catalog.valid_lane(loadout.get("lane")):
			return false
	return Catalog.distinct_cells(team)


## The Crucible block (see CrucibleRecord): known milestones, encounters and
## titles, whole-number records, and a run in progress whose sequence is the
## one its mode and seed name and whose locked team the save could field.
static func _valid_crucible(catalog: Catalog, data: Dictionary, block: Dictionary) -> bool:
	var index: Dictionary = catalog.crucible_index
	for key in ["milestones", "seen"]:
		var known: Dictionary = index.milestones if key == "milestones" else catalog.crucible_encounters
		if not block.get(key) is Array or block[key].any(func(id): return not known.has(String(id))):
			return false
	var title: Variant = block.get("title")
	if not title is String or (title != "" and not title in Crucible.unlocked(catalog, block.milestones, "titles")):
		return false
	if not block.get("records") is Dictionary or not block.get("last") is Dictionary:
		return false
	for key in block.records:
		var entry: Variant = block.records[key]
		if not entry is Dictionary or not ["best", "runs", "completions"].all(func(k): return _count(entry.get(k))):
			return false
		if not entry.get("teams") is Array or entry.teams.any(func(t): return not t is Dictionary or not _count(t.get("seed")) \
				or not t.get("golems") is Array or t.golems.is_empty()):
			return false
	var run: Variant = block.get("run")
	if not run is Dictionary:
		return false
	if run.is_empty():
		return true
	if not run.get("mode") in Crucible.MODES or not index.tiers.has(String(run.get("tier", ""))) or not _count(run.get("seed")) \
			or not _count(run.get("next")) or not run.get("history") is Dictionary:
		return false
	if not Crucible.tier_open(catalog, run.tier, block.milestones):
		return false
	var expected: Array = Crucible.sequence(catalog, run.mode, int(run.seed))
	var steps: Variant = run.get("sequence")
	if not steps is Array or steps.size() != expected.size() or int(run.next) >= expected.size():
		return false
	for i in range(expected.size()):
		if not steps[i] is Dictionary or String(steps[i].get("encounter", "")) != expected[i].encounter \
				or not _count(steps[i].get("variant")) or int(steps[i].variant) != expected[i].variant:
			return false
	if not valid_team(catalog, data, run.get("team")):
		return false
	for loadout in run.team:
		var history: Variant = run.history.get(loadout.spirit)
		if not history is Dictionary or not history.get("last_frame") is String or not history.get("last_build") is String \
				or not history.get("last_allies") is Array or not history.get("allies") is Array:
			return false
	return true


static func _count(value: Variant) -> bool:
	return (value is int or value is float) and int(value) == value and int(value) >= 0
