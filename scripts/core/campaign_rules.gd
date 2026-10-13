extends RefCounted
## Validation of campaign.json: the start block, regions, terrain, stages,
## their enemies and rewards, challenges and feats. Fills Catalog.stages,
## stage_region and finale_id as it goes, and reports into Catalog.errors.

const Catalog = preload("res://scripts/core/catalog.gd")
const Challenges = preload("res://scripts/core/challenges.gd")


static func _validate_loadout(catalog: Catalog, owner: String, loadout: Variant, wild: bool) -> void:
	if not loadout is Dictionary:
		catalog.errors.append(owner + " loadout must be an object")
		return
	var spirit_def: Dictionary = catalog.spirit(String(loadout.get("spirit", "")))
	if spirit_def.is_empty() or (not wild and not spirit_def.playable):
		catalog.errors.append(owner + " uses an unknown spirit")
	for kind in Catalog.LOADOUT_KEYS:
		if catalog.part(kind, String(loadout.get(Catalog.LOADOUT_KEYS[kind], ""))).is_empty():
			catalog.errors.append("%s uses an unknown %s" % [owner, kind])
	var sigil: String = String(loadout.get("sigil", ""))
	if not sigil.is_empty() and catalog.part("sigils", sigil).is_empty():
		catalog.errors.append(owner + " uses an unknown sigil")
	if not loadout.get("row") in Catalog.ROWS:
		catalog.errors.append(owner + " needs row front or back")
	if not Catalog.valid_lane(loadout.get("lane")):
		catalog.errors.append("%s needs a lane from 0 to %d" % [owner, Catalog.LANES - 1])


static func validate(catalog: Catalog) -> void:
	if not catalog.campaign.get("regions") is Array or catalog.campaign.regions.is_empty():
		catalog.errors.append("Campaign needs at least one region")
		return
	var start: Variant = catalog.campaign.get("start")
	if not start is Dictionary:
		catalog.errors.append("Campaign needs a start block")
		return
	for id in start.get("spirits", []):
		if not catalog.spirit(id).get("playable", false):
			catalog.errors.append("Start spirit %s is not playable" % id)
	for kind in Catalog.PART_KINDS:
		for id in start.get("unlocks", {}).get(kind, []):
			if catalog.part(kind, id).is_empty():
				catalog.errors.append("Start unlock %s %s does not exist" % [kind, id])
	var team: Variant = start.get("team")
	if not team is Array or team.is_empty():
		catalog.errors.append("The start team needs at least one golem")
		return
	for loadout in team:
		_validate_loadout(catalog, "start team", loadout, false)
	if catalog.errors.is_empty() and not Catalog.distinct_cells(team):
		catalog.errors.append("The start team puts two golems in one cell")
	var golems: int = team.size()
	for index in range(catalog.campaign.regions.size()):
		golems += _validate_region(catalog, index)
	if golems > int(catalog.num("team_size")):
		catalog.errors.append("The start team plus every golem core is %d golems, more than team_size" % golems)
	var feats: Variant = catalog.campaign.get("feats", [])
	if not feats is Array:
		catalog.errors.append("Campaign feats must be a list")
	else:
		for feat in feats:
			_add_challenge(catalog, "Feat", feat, "")
	if catalog.finale_id.is_empty():
		catalog.errors.append("One stage must be marked \"finale\": true")
	for stage in catalog.stages.values():
		for required in stage.get("requires", []):
			if not catalog.stages.has(required):
				catalog.errors.append("Stage %s requires unknown stage %s" % [stage.id, required])


## Checks one region and its stages; returns the golem cores it awards.
static func _validate_region(catalog: Catalog, index: int) -> int:
	var region: Variant = catalog.campaign.regions[index]
	if not region is Dictionary or not region.get("id") is String or not region.get("name") is String 			or not region.get("text") is String:
		catalog.errors.append("Region %d needs an id, name and text" % (index + 1))
		return 0
	var lab: Variant = region.get("laboratory")
	if not lab is Dictionary or not _is_point(lab.get("map_pos")) or not lab.get("name") is String:
		catalog.errors.append("Region %s needs a laboratory with a name and map_pos" % region.id)
	_validate_terrain(catalog, region.id, region.get("terrain"))
	if not region.get("stages") is Array or region.stages.is_empty():
		catalog.errors.append("Region %s needs at least one stage" % region.id)
		return 0
	var golems: int = 0
	for stage in region.stages:
		var id: String = String(stage.get("id", ""))
		if id.is_empty() or catalog.stages.has(id):
			catalog.errors.append("Stage ids must be unique and non-empty")
			continue
		catalog.stages[id] = stage
		catalog.stage_region[id] = index
		if stage.has("clear_text") and not stage.clear_text is String:
			catalog.errors.append("Stage %s clear_text must be text" % id)
		if stage.get("finale", false):
			if not catalog.finale_id.is_empty():
				catalog.errors.append("Only one stage can be the finale, not %s and %s" % [catalog.finale_id, id])
			catalog.finale_id = id
		var enemies: Variant = stage.get("enemies")
		if not enemies is Array or enemies.is_empty() or enemies.size() > Catalog.LANES * Catalog.ROWS.size():
			catalog.errors.append("Stage %s needs 1-%d enemies" % [id, Catalog.LANES * Catalog.ROWS.size()])
			continue
		for enemy in enemies:
			_validate_loadout(catalog, "stage " + id, enemy, true)
			if int(enemy.get("level", 0)) < 1:
				catalog.errors.append("Stage %s enemy needs a level" % id)
		if enemies.all(func(e): return e is Dictionary) and not Catalog.distinct_cells(enemies):
			catalog.errors.append("Stage %s puts two enemies in one cell" % id)
		if not _is_point(stage.get("map_pos")) or not stage.get("landmark") in Catalog.LANDMARKS:
			catalog.errors.append("Stage %s needs a map_pos and a landmark (%s)" % [id, ", ".join(Catalog.LANDMARKS)])
		for kind in stage.get("rewards", {}):
			if kind == "cores":
				if not (stage.rewards.cores is float or stage.rewards.cores is int) or int(stage.rewards.cores) < 1:
					catalog.errors.append("Stage %s rewards cores as a positive count" % id)
				else:
					golems += int(stage.rewards.cores)
				continue
			for reward in stage.rewards[kind]:
				var known: bool = catalog.spirit(reward).get("playable", false) if kind == "spirits" else not catalog.part(kind, reward).is_empty()
				if not known:
					catalog.errors.append("Stage %s rewards unknown %s %s" % [id, kind, reward])
		if not stage.get("challenges", []) is Array:
			catalog.errors.append("Stage %s challenges must be a list" % id)
			continue
		for challenge in stage.get("challenges", []):
			_add_challenge(catalog, "Stage %s challenge" % id, challenge, id)
	return golems


## Validates and indexes a stage's challenge, or a feat when `stage_id` is empty.
## Challenge and feat ids share one namespace, since the save lists them apart.
static func _add_challenge(catalog: Catalog, owner: String, entry: Variant, stage_id: String) -> void:
	var feat: bool = stage_id.is_empty()
	catalog.errors.append_array(Challenges.problems(catalog, owner, entry, feat))
	if not entry is Dictionary or not entry.get("id") is String:
		return
	if catalog.challenges.has(entry.id) or catalog.feats.has(entry.id):
		catalog.errors.append("Challenge and feat ids must be unique: %s" % entry.id)
	elif feat:
		catalog.feats[entry.id] = entry
	else:
		catalog.challenges[entry.id] = entry
		catalog.challenge_stage[entry.id] = stage_id


## A region's map ground: colours, a fixed seed, and optional stream, walls and woods.
static func _validate_terrain(catalog: Catalog, region_id: String, terrain: Variant) -> void:
	var owner: String = "Region %s terrain" % region_id
	if not terrain is Dictionary or not (terrain.get("seed") is float or terrain.get("seed") is int):
		catalog.errors.append(owner + " needs an object with a seed")
		return
	for key in Catalog.TERRAIN_COLORS:
		if not terrain.get(key) is String or not Color.html_is_valid(terrain[key]):
			catalog.errors.append("%s needs a %s colour" % [owner, key])
	for key in Catalog.TERRAIN_PALETTES:
		var palette: Variant = terrain.get(key)
		if not palette is Array or palette.is_empty() or palette.any(func(c): return not c is String or not Color.html_is_valid(c)):
			catalog.errors.append("%s needs a list of %s colours" % [owner, key])
	var stream: Variant = terrain.get("stream")
	if not stream is Array or stream.size() == 1 or not stream.all(_is_point):
		catalog.errors.append(owner + " stream must be a list of points (empty for none)")
	var walls: Variant = terrain.get("walls")
	if not walls is Array or not walls.all(func(w): return w is Array and w.size() == 3 and _is_point(w[0]) 			and _is_point(w[1]) and (w[2] is float or w[2] is int)):
		catalog.errors.append(owner + " walls must be [start, end, height] entries")
	var woods: Variant = terrain.get("woods")
	if not woods is Array or not woods.all(func(w): return w is Array and w.size() == 2 and _is_point(w[0]) 			and (w[1] is float or w[1] is int)):
		catalog.errors.append(owner + " woods must be [centre, radius] entries")


static func _is_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value.all(func(v): return v is float or v is int)
