extends RefCounted
## Loads and validates every hand-edited catalog in data/. Missing or mistyped
## data is reported in `errors` and the game refuses to start; there are no
## silent defaults in code.

const STATS: Array[String] = ["hp", "str", "mag", "spd", "def", "res"]
const PART_KINDS: Array[String] = ["frames", "arms", "legs", "sigils", "materials"]
## Catalog kind -> the key a loadout uses for it.
const LOADOUT_KEYS: Dictionary = {"frames": "frame", "arms": "arms", "legs": "legs", "materials": "material"}
const ROWS: Array[String] = ["front", "back"]
## Each side stands on LANES lanes of two rows: six cells, one golem in each.
const LANES: int = 3
## Which row an arms' attack aims at; it falls back to the other row once that one is empty.
const AIMS: Array[String] = ["front", "back"]
## Map illustrations a stage can stand beside (drawn by map_landmarks.gd and
## map_landmarks_wild.gd).
const LANDMARKS: Array[String] = ["gate", "court", "stair", "cloister", "vault", "heart", "bridge", "hut", "tower",
	"kiln", "spire", "camp", "monolith", "peak"]
## Colours a region's terrain block names (hex strings); lists hold one or more.
const TERRAIN_COLORS: Array[String] = ["ground", "dirt", "rock", "wall", "water"]
const TERRAIN_PALETTES: Array[String] = ["patches", "canopy"]
## "fatal" fires once, when a blow would destroy the golem; "ally_death" when a teammate falls.
const TRIGGERS: Array[String] = ["battle_start", "turn_start", "hit", "hurt", "low_hp", "kill", "fatal", "ally_death"]
## "drain" heals the owner a fraction of the hit's damage; "cleanse" clears Burn, Soaked,
## Weaken, Expose and Stun; "revive" sets HP to a fraction of max (only on "fatal");
## a negative "haste" slows the receiver.
const ACTIONS: Array[String] = ["status", "ward", "heal", "chain", "damage", "haste", "drain", "cleanse", "revive"]
const STATUSES: Array[String] = ["burn", "soaked", "taunt", "regen", "stun", "weaken", "expose"]
## Optional attack modifiers: armour ignored, share dealt to row neighbours,
## extra power against targets below half HP (fractions), and blows per action.
const ATTACK_FRACTIONS: Array[String] = ["pierce", "splash", "execute"]
## Who an effect lands on. "team" includes the owner; "allies" does not.
## "lane" is the owner and whoever shares its lane; "wounded" is the living
## ally (or owner) with the lowest share of its HP, if anyone is hurt.
const RECEIVERS: Array[String] = ["self", "target", "attacker", "team", "allies", "enemies", "lane", "wounded"]
## Receivers that only exist for some triggers: the struck target on a hit,
## the attacker when hurt.
const RECEIVER_TRIGGERS: Dictionary = {"target": ["hit"], "attacker": ["hurt"]}

var balance: Dictionary = {}
var elements: Dictionary = {}
var temperaments: Dictionary = {}
## id -> definition, for player spirits and wild spirits alike.
var spirits: Dictionary = {}
var player_spirit_ids: Array[String] = []
## kind ("frames", "arms", "legs", "sigils", "materials") -> id -> definition.
var parts: Dictionary = {}
## Ordered id lists per kind, so menus keep catalog order.
var part_order: Dictionary = {}
var campaign: Dictionary = {}
## Every stage of every region, by id, in campaign order.
var stages: Dictionary = {}
## stage id -> index into campaign.regions.
var stage_region: Dictionary = {}
var errors: Array[String] = []


func load_all() -> bool:
	errors.clear()
	balance = _read("res://data/balance.json")
	var spirit_data: Dictionary = _read("res://data/spirits.json")
	var part_data: Dictionary = _read("res://data/parts.json")
	campaign = _read("res://data/campaign.json")
	if not errors.is_empty():
		return false
	elements = spirit_data.get("elements", {})
	temperaments = spirit_data.get("temperaments", {})
	for entry in spirit_data.get("spirits", []):
		_add_spirit(entry, true)
	for entry in spirit_data.get("wild", []):
		_add_spirit(entry, false)
	for kind in PART_KINDS:
		parts[kind] = {}
		part_order[kind] = []
		for entry in part_data.get(kind, []):
			_add_part(kind, entry)
	_validate_campaign()
	_validate_balance()
	for message in errors:
		push_error("Spiritwright data: " + message)
	return errors.is_empty()


func part(kind: String, id: String) -> Dictionary:
	return parts.get(kind, {}).get(id, {})


func spirit(id: String) -> Dictionary:
	return spirits.get(id, {})


func element_color(element: String) -> Color:
	return Color(String(elements.get(element, {}).get("color", "ffffff")))


func element_label(element: String) -> String:
	return String(elements.get(element, {}).get("label", element.capitalize()))


func element_glyph(element: String) -> String:
	return String(elements.get(element, {}).get("glyph", "?"))


## What a spirit of `element` becomes in a body of `material_id`, or {}.
func reaction(material_id: String, element: String) -> Dictionary:
	return part("materials", material_id).get("reactions", {}).get(element, {})


func regions() -> Array:
	return campaign.regions


func region_of(stage_id: String) -> Dictionary:
	return campaign.regions[int(stage_region.get(stage_id, 0))]


## Dot-separated lookup into balance.json, e.g. "battle.gauge_threshold".
func num(path: String) -> float:
	var node: Variant = balance
	for key in path.split("."):
		if not node is Dictionary or not node.has(key):
			push_error("Balance data has no value at " + path)
			return 0.0
		node = node[key]
	return float(node)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Missing " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		errors.append("Unreadable or unsupported " + path)
		return {}
	return parsed


func _add_spirit(entry: Variant, playable: bool) -> void:
	if not entry is Dictionary or not entry.get("id") is String:
		errors.append("Spirit entry without an id")
		return
	var id: String = entry.id
	if spirits.has(id):
		errors.append("Duplicate spirit id " + id)
	if not elements.has(entry.get("element", "")):
		errors.append("Spirit %s has an unknown element" % id)
	if playable and not temperaments.has(entry.get("temperament", "")):
		errors.append("Spirit %s has an unknown temperament" % id)
	for block in ["base", "growth"]:
		if not entry.get(block) is Dictionary:
			errors.append("Spirit %s needs %s stats" % [id, block])
			continue
		for stat in STATS:
			if not (entry[block].get(stat) is float or entry[block].get(stat) is int):
				errors.append("Spirit %s %s is missing %s" % [id, block, stat])
	if not entry.get("trait") is Dictionary or not entry["trait"].get("name") is String:
		errors.append("Spirit %s needs a named trait" % id)
	else:
		_validate_effects("spirit " + id, entry["trait"].get("effects", []))
		_validate_stat_block("spirit " + id + " front_row", entry["trait"].get("front_row", {}))
	# Player spirits grow a second trait at balance.awaken_level.
	if playable:
		var awakening: Variant = entry.get("awakening")
		if not awakening is Dictionary or not awakening.get("name") is String or not awakening.get("text") is String:
			errors.append("Spirit %s needs a named awakening" % id)
		else:
			_validate_effects("spirit %s awakening" % id, awakening.get("effects"))
	entry["playable"] = playable
	spirits[id] = entry
	if playable:
		player_spirit_ids.append(id)


func _add_part(kind: String, entry: Variant) -> void:
	if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String:
		errors.append("A %s entry needs an id and name" % kind)
		return
	var id: String = entry.id
	if parts[kind].has(id):
		errors.append("Duplicate %s id %s" % [kind, id])
	_validate_stat_block(kind + " " + id, entry.get("stats", {}))
	if kind == "arms":
		var attack: Variant = entry.get("attack")
		if not attack is Dictionary or not attack.get("kind") in ["physical", "magical"] \
				or not attack.get("range") in ["melee", "ranged"] or not attack.get("aim") in AIMS 				or int(attack.get("cost", 0)) <= 0:
			errors.append("Arms %s need a valid attack" % id)
		_validate_effects("arms " + id, entry.get("effects", []))
		if attack is Dictionary:
			for key in ATTACK_FRACTIONS:
				if attack.has(key) and (not (attack[key] is float or attack[key] is int) or float(attack[key]) <= 0.0):
					errors.append("Arms %s %s must be a positive fraction" % [id, key])
			if attack.has("strikes") and (not (attack.strikes is float or attack.strikes is int) or int(attack.strikes) < 1):
				errors.append("Arms %s strikes must be at least 1" % id)
	if kind in ["frames", "legs"]:
		_validate_effects(kind + " " + id, entry.get("effects", []))
	if kind == "legs" and entry.has("perch"):
		if not (entry.perch is float or entry.perch is int) or float(entry.perch) <= 0.0:
			errors.append("Legs %s perch must be a positive fraction" % id)
	if kind in ["frames", "legs"] and entry.has("immune"):
		if not entry.immune is Array or entry.immune.any(func(status): return not status in STATUSES):
			errors.append("%s %s immune must list statuses" % [kind.capitalize(), id])
	if kind == "legs" and entry.has("brace"):
		if not (entry.brace is float or entry.brace is int) or float(entry.brace) <= 0.0 or float(entry.brace) >= 1.0:
			errors.append("Legs %s brace must be a fraction between 0 and 1" % id)
	if kind == "sigils":
		_validate_effects("sigil " + id, entry.get("effects", []))
	if kind == "materials":
		_validate_reactions(id, entry.get("reactions"))
	parts[kind][id] = entry
	part_order[kind].append(id)


## A material reacts with some elements: a named bundle of stats and effects
## that applies only while a spirit of that element inhabits it.
func _validate_reactions(material_id: String, reactions: Variant) -> void:
	if not reactions is Dictionary:
		errors.append("Material %s needs a reactions object" % material_id)
		return
	for element in reactions:
		var owner: String = "material %s reaction %s" % [material_id, element]
		var entry: Variant = reactions[element]
		if not elements.has(element):
			errors.append(owner + " names an unknown element")
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String 				or not entry.get("text") is String:
			errors.append(owner + " needs an id, name and text")
			continue
		_validate_stat_block(owner, entry.get("stats", {}))
		_validate_effects(owner, entry.get("effects", []))


func _validate_stat_block(owner: String, block: Variant) -> void:
	if not block is Dictionary:
		errors.append(owner + " stats must be an object")
		return
	for stat in block:
		if not stat in STATS:
			errors.append("%s has unknown stat %s" % [owner, stat])


func _validate_effects(owner: String, effects: Variant) -> void:
	if not effects is Array:
		errors.append(owner + " effects must be a list")
		return
	for effect in effects:
		if not effect is Dictionary or not effect.get("on") in TRIGGERS or not effect.get("do") in ACTIONS:
			errors.append(owner + " has an unsupported effect")
			continue
		if effect.do == "status" and not effect.get("status") in STATUSES:
			errors.append(owner + " applies an unknown status")
		if effect.has("if_target"):
			var conditions: Variant = effect.if_target
			if effect.on != "hit" or not conditions is Array or conditions.is_empty() \
					or conditions.any(func(status): return not status in ["burn", "soaked", "taunt", "regen", "weaken", "expose"]):
				errors.append(owner + " if_target needs on hit and lasting statuses")
		if effect.do in ["chain", "drain"]:
			if effect.on != "hit" or not (effect.get("fraction") is float or effect.get("fraction") is int):
				errors.append("%s %s needs on hit and a fraction" % [owner, effect.do])
			continue
		if effect.do == "revive" and (effect.on != "fatal" or effect.get("to") != "self" 				or not (effect.get("fraction") is float or effect.get("fraction") is int)):
			errors.append(owner + " revive needs on fatal, to self and a fraction")
		var receiver: Variant = effect.get("to")
		if not receiver in RECEIVERS:
			errors.append(owner + " effect needs a known 'to'")
		elif RECEIVER_TRIGGERS.has(receiver) and not effect.on in RECEIVER_TRIGGERS[receiver]:
			errors.append("%s effect cannot reach '%s' on %s" % [owner, receiver, effect.on])
		if effect.has("stat") and not effect.stat in STATS:
			errors.append(owner + " effect scales with an unknown stat")
		if effect.do in ["ward", "heal", "damage", "haste"] and not effect.has("flat") and not effect.has("stat"):
			errors.append(owner + " effect needs a flat amount or a stat")
		if effect.do == "status" and int(effect.get("amount", 0)) <= 0:
			errors.append(owner + " status effect needs an amount")


func _validate_loadout(owner: String, loadout: Variant, wild: bool) -> void:
	if not loadout is Dictionary:
		errors.append(owner + " loadout must be an object")
		return
	var spirit_def: Dictionary = spirit(String(loadout.get("spirit", "")))
	if spirit_def.is_empty() or (not wild and not spirit_def.playable):
		errors.append(owner + " uses an unknown spirit")
	for kind in LOADOUT_KEYS:
		if part(kind, String(loadout.get(LOADOUT_KEYS[kind], ""))).is_empty():
			errors.append("%s uses an unknown %s" % [owner, kind])
	var sigil: String = String(loadout.get("sigil", ""))
	if not sigil.is_empty() and part("sigils", sigil).is_empty():
		errors.append(owner + " uses an unknown sigil")
	if not loadout.get("row") in ROWS:
		errors.append(owner + " needs row front or back")
	if not valid_lane(loadout.get("lane")):
		errors.append("%s needs a lane from 0 to %d" % [owner, LANES - 1])


static func valid_lane(lane: Variant) -> bool:
	return (lane is int or lane is float) and int(lane) == lane and int(lane) >= 0 and int(lane) < LANES


## "front:1" style key for the cell a loadout stands in.
static func cell_of(loadout: Dictionary) -> String:
	return "%s:%d" % [loadout.get("row", ""), int(loadout.get("lane", -1))]


## True when no two loadouts share a cell.
static func distinct_cells(team: Array) -> bool:
	var seen: Dictionary = {}
	for loadout in team:
		var cell: String = cell_of(loadout)
		if seen.has(cell):
			return false
		seen[cell] = true
	return true


func _validate_campaign() -> void:
	if not campaign.get("regions") is Array or campaign.regions.is_empty():
		errors.append("Campaign needs at least one region")
		return
	var start: Variant = campaign.get("start")
	if not start is Dictionary:
		errors.append("Campaign needs a start block")
		return
	for id in start.get("spirits", []):
		if not spirit(id).get("playable", false):
			errors.append("Start spirit %s is not playable" % id)
	for kind in PART_KINDS:
		for id in start.get("unlocks", {}).get(kind, []):
			if part(kind, id).is_empty():
				errors.append("Start unlock %s %s does not exist" % [kind, id])
	var team: Variant = start.get("team")
	if not team is Array or team.is_empty():
		errors.append("The start team needs at least one golem")
		return
	for loadout in team:
		_validate_loadout("start team", loadout, false)
	if errors.is_empty() and not distinct_cells(team):
		errors.append("The start team puts two golems in one cell")
	var golems: int = team.size()
	for index in range(campaign.regions.size()):
		golems += _validate_region(index)
	if golems > int(num("team_size")):
		errors.append("The start team plus every golem core is %d golems, more than team_size" % golems)
	for stage in stages.values():
		for required in stage.get("requires", []):
			if not stages.has(required):
				errors.append("Stage %s requires unknown stage %s" % [stage.id, required])


## Checks one region and its stages; returns the golem cores it awards.
func _validate_region(index: int) -> int:
	var region: Variant = campaign.regions[index]
	if not region is Dictionary or not region.get("id") is String or not region.get("name") is String 			or not region.get("text") is String:
		errors.append("Region %d needs an id, name and text" % (index + 1))
		return 0
	var lab: Variant = region.get("laboratory")
	if not lab is Dictionary or not _is_point(lab.get("map_pos")) or not lab.get("name") is String:
		errors.append("Region %s needs a laboratory with a name and map_pos" % region.id)
	_validate_terrain(region.id, region.get("terrain"))
	if not region.get("stages") is Array or region.stages.is_empty():
		errors.append("Region %s needs at least one stage" % region.id)
		return 0
	var golems: int = 0
	for stage in region.stages:
		var id: String = String(stage.get("id", ""))
		if id.is_empty() or stages.has(id):
			errors.append("Stage ids must be unique and non-empty")
			continue
		stages[id] = stage
		stage_region[id] = index
		if stage.has("clear_text") and not stage.clear_text is String:
			errors.append("Stage %s clear_text must be text" % id)
		var enemies: Variant = stage.get("enemies")
		if not enemies is Array or enemies.is_empty() or enemies.size() > LANES * ROWS.size():
			errors.append("Stage %s needs 1-%d enemies" % [id, LANES * ROWS.size()])
			continue
		for enemy in enemies:
			_validate_loadout("stage " + id, enemy, true)
			if int(enemy.get("level", 0)) < 1:
				errors.append("Stage %s enemy needs a level" % id)
		if enemies.all(func(e): return e is Dictionary) and not distinct_cells(enemies):
			errors.append("Stage %s puts two enemies in one cell" % id)
		if not _is_point(stage.get("map_pos")) or not stage.get("landmark") in LANDMARKS:
			errors.append("Stage %s needs a map_pos and a landmark (%s)" % [id, ", ".join(LANDMARKS)])
		for kind in stage.get("rewards", {}):
			if kind == "cores":
				if not (stage.rewards.cores is float or stage.rewards.cores is int) or int(stage.rewards.cores) < 1:
					errors.append("Stage %s rewards cores as a positive count" % id)
				else:
					golems += int(stage.rewards.cores)
				continue
			for reward in stage.rewards[kind]:
				var known: bool = spirit(reward).get("playable", false) if kind == "spirits" else not part(kind, reward).is_empty()
				if not known:
					errors.append("Stage %s rewards unknown %s %s" % [id, kind, reward])
	return golems


## A region's map ground: colours, a fixed seed, and optional stream, walls and woods.
func _validate_terrain(region_id: String, terrain: Variant) -> void:
	var owner: String = "Region %s terrain" % region_id
	if not terrain is Dictionary or not (terrain.get("seed") is float or terrain.get("seed") is int):
		errors.append(owner + " needs an object with a seed")
		return
	for key in TERRAIN_COLORS:
		if not terrain.get(key) is String or not Color.html_is_valid(terrain[key]):
			errors.append("%s needs a %s colour" % [owner, key])
	for key in TERRAIN_PALETTES:
		var palette: Variant = terrain.get(key)
		if not palette is Array or palette.is_empty() or palette.any(func(c): return not c is String or not Color.html_is_valid(c)):
			errors.append("%s needs a list of %s colours" % [owner, key])
	var stream: Variant = terrain.get("stream")
	if not stream is Array or stream.size() == 1 or not stream.all(_is_point):
		errors.append(owner + " stream must be a list of points (empty for none)")
	var walls: Variant = terrain.get("walls")
	if not walls is Array or not walls.all(func(w): return w is Array and w.size() == 3 and _is_point(w[0]) 			and _is_point(w[1]) and (w[2] is float or w[2] is int)):
		errors.append(owner + " walls must be [start, end, height] entries")
	var woods: Variant = terrain.get("woods")
	if not woods is Array or not woods.all(func(w): return w is Array and w.size() == 2 and _is_point(w[0]) 			and (w[1] is float or w[1] is int)):
		errors.append(owner + " woods must be [centre, radius] entries")


func _is_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value.all(func(v): return v is float or v is int)


func _validate_balance() -> void:
	if int(balance.get("team_size", 0)) > LANES * ROWS.size():
		errors.append("team_size cannot exceed the %d cells of the board" % (LANES * ROWS.size()))
	for path in ["team_size", "level_cap", "awaken_level", "xp_per_level", "xp_per_level_growth", "xp.per_stage_level", "xp.first_clear", "xp.repeat_win", "xp.loss",
			"xp.level_gap_step", "xp.min_factor", "xp.max_factor",
			"growth.hp_per_point", "growth.start_progress", "battle.gauge_threshold", "battle.gauge_base",
			"battle.max_ticks", "battle.damage_variance", "battle.armour_factor", "battle.min_damage_fraction", "battle.back_row_melee_factor", "status.burn_damage_per_stack",
			"status.burn_max_stacks", "status.soaked_magic_bonus", "status.soaked_speed_multiplier",
			"status.regen_heal", "status.weaken_fraction", "status.expose_fraction"]:
		var node: Variant = balance
		for key in path.split("."):
			node = node.get(key) if node is Dictionary else null
		if not (node is float or node is int):
			errors.append("Balance is missing " + path)
