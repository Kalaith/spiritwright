extends RefCounted
## The save file's shape: validation of the current schema, and the steps that
## bring an older save up to it, one schema at a time. Each step only fills in
## what the older schema lacked; `valid` then checks the result.

const Catalog = preload("res://scripts/core/catalog.gd")
const VERSION: int = 7
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
	for key in ["challenges", "feats"]:
		var known: Dictionary = catalog.challenges if key == "challenges" else catalog.feats
		if not data.get(key) is Array or data[key].any(func(id): return not known.has(id)):
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
