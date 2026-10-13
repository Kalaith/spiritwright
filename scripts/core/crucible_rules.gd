extends RefCounted
## Validation of crucible.json: the unlock, the Classic sequence, the tiers,
## every encounter and final (variants of enemy loadouts whose levels are
## offsets from the tier), the vessel finishes, titles and milestones. Fills
## Catalog.crucible_encounters and reports into Catalog.errors.

const Catalog = preload("res://scripts/core/catalog.gd")
const CampaignRules = preload("res://scripts/core/campaign_rules.gd")

## Milestone rules, judged on one Crucible run (see Crucible.milestone_met):
## reach: encounters won in the run; complete: the final fell; mode, tier: which
## Royale; max_golems: at most this many golems in the locked team.
const MILESTONE_RULES: Dictionary = {"reach": TYPE_INT, "complete": TYPE_BOOL, "mode": TYPE_STRING,
	"tier": TYPE_STRING, "max_golems": TYPE_INT}
const MODES: Array[String] = ["classic", "shifting"]
const REWARD_KINDS: Array[String] = ["spirits", "titles", "finishes"]


static func validate(catalog: Catalog) -> void:
	var data: Dictionary = catalog.crucible
	var unlock: Variant = data.get("unlock")
	if not unlock is Dictionary or not catalog.stages.has(String(unlock.get("stage", ""))) or not unlock.get("text") is String:
		catalog.errors.append("Crucible unlock needs a known stage and text")
	var per_run: Variant = data.get("encounters_per_run")
	if not (per_run is int or per_run is float) or int(per_run) < 1:
		catalog.errors.append("Crucible encounters_per_run must be at least 1")
		return
	for key in ["encounters", "finals"]:
		if not data.get(key) is Array or data[key].is_empty():
			catalog.errors.append("Crucible needs a list of %s" % key)
			return
		for entry in data[key]:
			_validate_encounter(catalog, entry, key == "finals")
	if data.encounters.size() < int(per_run):
		catalog.errors.append("Crucible needs at least encounters_per_run encounters to draw from")
	var classic: Variant = data.get("classic")
	if not classic is Dictionary or not classic.get("encounters") is Array or classic.encounters.size() != int(per_run) \
			or classic.encounters.any(func(id): return not _is_kind(catalog, id, false)) \
			or not _is_kind(catalog, classic.get("final"), true):
		catalog.errors.append("Crucible classic needs encounters_per_run encounter ids and a final id")
	elif classic.encounters.size() != _distinct(classic.encounters).size():
		catalog.errors.append("Crucible classic repeats an encounter")
	for key in ["finishes", "titles", "tiers", "milestones"]:
		_index(catalog, key, data.get(key))
	for entry in catalog.crucible_index.finishes.values():
		if not entry.get("text") is String or not entry.get("color") is String or not Color.html_is_valid(entry.color):
			catalog.errors.append("Crucible finish %s needs a text and a colour" % entry.id)
	for entry in catalog.crucible_index.milestones.values():
		_validate_milestone(catalog, entry)
	for entry in catalog.crucible_index.tiers.values():
		if not entry.get("text") is String or not _whole(entry.get("level"), 1) or not _whole(entry.get("enemy_bonus"), 0) \
				or int(entry.level) > int(catalog.num("level_cap")):
			catalog.errors.append("Crucible tier %s needs a text, a level up to level_cap and an enemy_bonus" % entry.id)
		if entry.has("requires") and not catalog.crucible_index.milestones.has(String(entry.requires)):
			catalog.errors.append("Crucible tier %s requires an unknown milestone" % entry.id)
	if catalog.crucible_index.tiers.is_empty():
		catalog.errors.append("Crucible needs at least one tier")


## Whether `id` names an encounter (or, with `final`, a final).
static func _is_kind(catalog: Catalog, id: Variant, final: bool) -> bool:
	var entry: Dictionary = catalog.crucible_encounters.get(String(id), {})
	return not entry.is_empty() and bool(entry.final) == final


static func _validate_encounter(catalog: Catalog, entry: Variant, final: bool) -> void:
	if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String \
			or not entry.get("text") is String or not entry.get("test") is String or not _whole(entry.get("seed"), 0):
		catalog.errors.append("A Crucible encounter needs an id, name, test, seed and text")
		return
	var owner: String = "Crucible encounter " + entry.id
	if catalog.crucible_encounters.has(entry.id):
		catalog.errors.append(owner + " is listed twice")
	entry["final"] = final
	catalog.crucible_encounters[entry.id] = entry
	if not entry.get("variants") is Array or entry.variants.is_empty():
		catalog.errors.append(owner + " needs at least one variant")
		return
	for enemies in entry.variants:
		if not enemies is Array or enemies.is_empty() or enemies.size() > Catalog.LANES * Catalog.ROWS.size():
			catalog.errors.append("%s variants need 1-%d enemies" % [owner, Catalog.LANES * Catalog.ROWS.size()])
			continue
		for enemy in enemies:
			CampaignRules._validate_loadout(catalog, owner, enemy, true)
			if not enemy is Dictionary or not (enemy.get("offset") is int or enemy.get("offset") is float) \
					or int(enemy.offset) != enemy.offset:
				catalog.errors.append(owner + " enemies need a whole-number level offset")
		if enemies.all(func(e): return e is Dictionary) and not Catalog.distinct_cells(enemies):
			catalog.errors.append(owner + " puts two enemies in one cell")


static func _validate_milestone(catalog: Catalog, entry: Dictionary) -> void:
	var owner: String = "Crucible milestone " + entry.id
	if not entry.get("text") is String or not entry.get("rules") is Dictionary or entry.rules.is_empty():
		catalog.errors.append(owner + " needs a text and rules")
		return
	for rule in entry.rules:
		var value: Variant = entry.rules[rule]
		var expected: int = MILESTONE_RULES.get(rule, TYPE_NIL)
		var typed: bool = typeof(value) == expected or (expected == TYPE_INT and value is float and int(value) == value)
		if expected == TYPE_NIL or not typed or (expected == TYPE_BOOL and value != true) \
				or (expected == TYPE_INT and int(value) < 1) or (rule == "mode" and not value in MODES):
			catalog.errors.append("%s has a bad rule %s" % [owner, rule])
		elif rule == "tier" and not catalog.crucible_index.tiers.has(value):
			catalog.errors.append("%s names an unknown tier" % owner)
	var rewards: Variant = entry.get("rewards")
	if not rewards is Dictionary:
		catalog.errors.append(owner + " needs rewards")
		return
	for kind in rewards:
		if not kind in REWARD_KINDS or not rewards[kind] is Array:
			catalog.errors.append("%s cannot reward %s" % [owner, kind])
			continue
		for id in rewards[kind]:
			var known: bool = catalog.spirit(String(id)).get("playable", false) if kind == "spirits" \
				else catalog.crucible_index[kind].has(String(id))
			if not known:
				catalog.errors.append("%s rewards unknown %s %s" % [owner, kind, id])


## Indexes a list of {id, name, ...} entries into Catalog.crucible_index[key], in order.
static func _index(catalog: Catalog, key: String, entries: Variant) -> void:
	catalog.crucible_index[key] = {}
	if not entries is Array:
		catalog.errors.append("Crucible %s must be a list" % key)
		return
	for entry in entries:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String:
			catalog.errors.append("Crucible %s entries need an id and name" % key)
		elif catalog.crucible_index[key].has(entry.id):
			catalog.errors.append("Crucible %s lists %s twice" % [key, entry.id])
		else:
			catalog.crucible_index[key][entry.id] = entry


static func _whole(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and int(value) == value and int(value) >= minimum


static func _distinct(items: Array) -> Array:
	var seen: Array = []
	for item in items:
		if not item in seen:
			seen.append(item)
	return seen
