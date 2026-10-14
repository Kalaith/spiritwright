extends RefCounted
## Loads and validates every hand-edited catalog in data/. Missing or mistyped
## data is reported in `errors` and the game refuses to start; there are no
## silent defaults in code.

const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const DotTable = preload("res://addons/hatchery/core/dot_table.gd")

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
## balance.json read by dot-separated paths (see num).
var balance_table: DotTable = DotTable.from_dictionary({}) as DotTable
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
## The one stage marked "finale": winning it completes a playthrough and opens New Game+.
var finale_id: String = ""
## Codex challenge id -> entry, in campaign order, and the stage each belongs to.
var challenges: Dictionary = {}
var challenge_stage: Dictionary = {}
## Feat id -> entry: rules on a whole playthrough (see challenges.gd).
var feats: Dictionary = {}
## crucible.json as loaded, every encounter and final by id, and the tiers,
## milestones, finishes and titles by id (see crucible_rules.gd).
var crucible: Dictionary = {}
var crucible_encounters: Dictionary = {}
var crucible_index: Dictionary = {"tiers": {}, "milestones": {}, "finishes": {}, "titles": {}}
var errors: Array[String] = []


func load_all() -> bool:
	errors.clear()
	balance = JsonIO.read_object("res://data/balance.json", errors, 1)
	var spirit_data: Dictionary = JsonIO.read_object("res://data/spirits.json", errors, 1)
	var part_data: Dictionary = JsonIO.read_object("res://data/parts.json", errors, 1)
	campaign = JsonIO.read_object("res://data/campaign.json", errors, 1)
	crucible = JsonIO.read_object("res://data/crucible.json", errors, 1)
	if not errors.is_empty():
		return false
	_load_regions()
	if not errors.is_empty():
		return false
	balance_table = DotTable.from_dictionary(balance, "res://data/balance.json") as DotTable
	elements = spirit_data.get("elements", {})
	temperaments = spirit_data.get("temperaments", {})
	for entry in spirit_data.get("spirits", []):
		_add_spirit(entry, true)
	# A wild spirit with a temperament can also be recruited; it still fights
	# the player in its wild form (see Builds.resolve).
	for entry in spirit_data.get("wild", []):
		_add_spirit(entry, entry is Dictionary and entry.has("temperament"))
	for kind in PART_KINDS:
		parts[kind] = {}
		part_order[kind] = []
		for entry in part_data.get(kind, []):
			_add_part(kind, entry)
	for id in player_spirit_ids:
		_validate_by_frame(spirits[id])
	load("res://scripts/core/campaign_rules.gd").validate(self)
	load("res://scripts/core/crucible_rules.gd").validate(self)
	_validate_balance()
	for message in errors:
		push_error("Spiritwright data: " + message)
	return errors.is_empty()


## campaign.json lists its regions by id, in campaign order; each region lives
## in data/regions/<id>.json. They are read into campaign.regions, so the rest
## of the game sees one campaign.
func _load_regions() -> void:
	var ids: Variant = campaign.get("regions")
	if not ids is Array or ids.is_empty() or not ids.all(func(id): return DataRules.nonempty(id)):
		errors.append("campaign.json regions must list region ids")
		return
	var regions: Array = []
	for id in ids:
		var path: String = "res://data/regions/%s.json" % id
		var region: Dictionary = JsonIO.read_object(path, errors, 1)
		if region.is_empty():
			continue
		region.erase("schema_version")
		if region.get("id") != id:
			errors.append("%s must have the id %s" % [path, id])
		regions.append(region)
	campaign.regions = regions


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


## Dot-separated lookup into balance.json, e.g. "battle.gauge_threshold". A
## missing path is a data error (the toolkit's DotTable reports it).
func num(path: String) -> float:
	return balance_table.number(path)


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
			if not DataRules.finite(entry[block].get(stat)):
				errors.append("Spirit %s %s is missing %s" % [id, block, stat])
	if not entry.get("trait") is Dictionary or not entry["trait"].get("name") is String:
		errors.append("Spirit %s needs a named trait" % id)
	else:
		_validate_effects("spirit " + id, entry["trait"].get("effects", []))
		_validate_stat_block("spirit " + id + " front_row", entry["trait"].get("front_row", {}))
	if playable and (not entry.get("title") is String or not entry.get("description") is String):
		errors.append("Spirit %s needs a title and a description" % id)
	# Player spirits grow a second trait at balance.awaken_level.
	if playable:
		var awakening: Variant = entry.get("awakening")
		if not awakening is Dictionary or not awakening.get("name") is String or not awakening.get("text") is String:
			errors.append("Spirit %s needs a named awakening" % id)
		else:
			_validate_effects("spirit %s awakening" % id, awakening.get("effects"))
	# Optional whole-number percentage on top of balance.xp.gain_percent.
	if entry.has("xp_percent") and (not DataRules.whole(entry.xp_percent) or int(entry.xp_percent) < 0):
		errors.append("Spirit %s xp_percent must be a whole number of at least 0" % id)
	entry["playable"] = playable
	spirits[id] = entry
	if playable:
		player_spirit_ids.append(id)


## A trait's optional by_frame: frame id -> stats the spirit gains in that frame.
func _validate_by_frame(spirit_def: Dictionary) -> void:
	if not spirit_def.get("trait") is Dictionary:
		return
	var by_frame: Variant = spirit_def["trait"].get("by_frame", {})
	if not by_frame is Dictionary:
		errors.append("Spirit %s by_frame must be an object" % spirit_def.id)
		return
	for frame_id in by_frame:
		if part("frames", frame_id).is_empty():
			errors.append("Spirit %s by_frame names an unknown frame %s" % [spirit_def.id, frame_id])
		_validate_stat_block("spirit %s by_frame %s" % [spirit_def.id, frame_id], by_frame[frame_id])


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
				if attack.has(key) and (not DataRules.finite(attack[key]) or float(attack[key]) <= 0.0):
					errors.append("Arms %s %s must be a positive fraction" % [id, key])
			if attack.has("strikes") and (not DataRules.finite(attack.strikes) or int(attack.strikes) < 1):
				errors.append("Arms %s strikes must be at least 1" % id)
	if kind in ["frames", "legs"]:
		_validate_effects(kind + " " + id, entry.get("effects", []))
	if kind == "legs" and entry.has("perch"):
		if not DataRules.finite(entry.perch) or float(entry.perch) <= 0.0:
			errors.append("Legs %s perch must be a positive fraction" % id)
	if kind in ["frames", "legs"] and entry.has("immune"):
		if not entry.immune is Array or entry.immune.any(func(status): return not status in STATUSES):
			errors.append("%s %s immune must list statuses" % [kind.capitalize(), id])
	if kind == "legs" and entry.has("brace"):
		if not DataRules.finite(entry.brace) or float(entry.brace) <= 0.0 or float(entry.brace) >= 1.0:
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
			if effect.on != "hit" or not DataRules.finite(effect.get("fraction")):
				errors.append("%s %s needs on hit and a fraction" % [owner, effect.do])
			continue
		if effect.do == "revive" and (effect.on != "fatal" or effect.get("to") != "self" 				or not DataRules.finite(effect.get("fraction"))):
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


static func valid_lane(lane: Variant) -> bool:
	return DataRules.integer_in(lane, 0, LANES - 1)


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


func _validate_balance() -> void:
	if int(balance.get("team_size", 0)) > LANES * ROWS.size():
		errors.append("team_size cannot exceed the %d cells of the board" % (LANES * ROWS.size()))
	for path in ["team_size", "level_cap", "awaken_level", "xp_per_level", "xp_per_level_growth", "xp.gain_percent", "xp.per_stage_level", "xp.first_clear", "xp.repeat_win", "xp.loss", "xp.resting",
			"xp.level_gap_step", "xp.min_factor", "xp.max_factor",
			"growth.hp_per_point", "growth.start_progress", "battle.gauge_threshold", "battle.gauge_base",
			"battle.max_ticks", "battle.damage_variance", "battle.armour_factor", "battle.min_damage_fraction", "battle.back_row_melee_factor", "status.burn_damage_per_stack",
			"status.burn_max_stacks", "status.soaked_magic_bonus", "status.soaked_speed_multiplier",
			"status.regen_heal", "status.weaken_fraction", "status.expose_fraction", "new_game_plus.level_step"]:
		if not balance_table.has(path) or not DataRules.finite(balance_table.value(path)):
			errors.append("Balance is missing " + path)
	var gain: Variant = balance.get("xp", {}).get("gain_percent")
	if DataRules.finite(gain) and (not DataRules.whole(gain) or int(gain) < 0):
		errors.append("Balance xp.gain_percent must be a whole number of at least 0")
