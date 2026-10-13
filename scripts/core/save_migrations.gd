extends RefCounted
## Brings an older save up to the current schema one step at a time. Each step
## only fills in what the older schema lacked; Progression validates the result.

const Catalog = preload("res://scripts/core/catalog.gd")
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
	return data
