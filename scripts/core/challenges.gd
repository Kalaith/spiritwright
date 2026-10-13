extends RefCounted
## Codex challenges and feats. A challenge is an optional rule set on one
## stage, met by any win whose golems keep every rule. A feat is a rule set on a
## whole playthrough, met when the playthrough's record keeps every rule once
## every stage has been cleared in it. A region's mastery is earned by meeting
## every challenge on its stages. Both are data in campaign.json; the
## rules are a small fixed vocabulary, checked exactly against the battle's
## final state, so a challenge can never disagree with what happened.

const Catalog = preload("res://scripts/core/catalog.gd")

## Challenge rules, by the type of value each takes.
## no_falls: none of your golems falls. front_stands: none that started in the
## front row falls. max_golems: field at most this many. forbid_elements /
## only_elements / only_materials / forbid_arms: lists of ids. attack_kind:
## every golem's arms are "physical" or "magical". empty_row: nobody stands in
## that row. no_sigils: no golem carries one. require: at least one golem
## matches every field given. max_level: no spirit above this level.
## min_cycle: only in that New Game+ cycle or later.
const RULES: Dictionary = {
	"no_falls": TYPE_BOOL, "front_stands": TYPE_BOOL, "max_golems": TYPE_INT, "forbid_elements": TYPE_ARRAY,
	"only_elements": TYPE_ARRAY, "only_materials": TYPE_ARRAY, "forbid_arms": TYPE_ARRAY, "attack_kind": TYPE_STRING,
	"empty_row": TYPE_STRING, "no_sigils": TYPE_BOOL, "require": TYPE_DICTIONARY, "max_level": TYPE_INT,
	"min_cycle": TYPE_INT,
}
## Feat rules, judged on Progression.run: no golem fell, no battle was lost or
## timed out, never more than this many golems fielded, and the cycle.
const FEAT_RULES: Dictionary = {"no_falls": TYPE_BOOL, "no_losses": TYPE_BOOL, "max_golems": TYPE_INT,
	"min_cycle": TYPE_INT}
## Golem fields a "require" rule may name.
const REQUIRE_KEYS: Array[String] = ["spirit", "element", "frame", "arms", "legs", "material", "sigil", "row"]


## Whether a won battle meets `rules`. `golems` are the player's side of the
## finished battle (BattleSim units with side 0).
static func met(rules: Dictionary, golems: Array, cycle: int) -> bool:
	for rule in rules:
		var value: Variant = rules[rule]
		var ok: bool = true
		match rule:
			"no_falls":
				ok = golems.all(func(g): return g.alive)
			"front_stands":
				ok = golems.all(func(g): return g.alive or g.row != "front")
			"max_golems":
				ok = golems.size() <= int(value)
			"forbid_elements":
				ok = golems.all(func(g): return not g.element in value)
			"only_elements":
				ok = golems.all(func(g): return g.element in value)
			"only_materials":
				ok = golems.all(func(g): return g.material in value)
			"forbid_arms":
				ok = golems.all(func(g): return not g.arms in value)
			"attack_kind":
				ok = golems.all(func(g): return g.attack.kind == value)
			"empty_row":
				ok = golems.all(func(g): return g.row != value)
			"no_sigils":
				ok = golems.all(func(g): return String(g.sigil).is_empty())
			"require":
				ok = golems.any(func(g): return value.keys().all(func(key): return String(g[key]) == String(value[key])))
			"max_level":
				ok = golems.all(func(g): return int(g.level) <= int(value))
			"min_cycle":
				ok = cycle >= int(value)
		if not ok:
			return false
	return true


## Whether a completed playthrough's record meets a feat's `rules`.
static func feat_met(rules: Dictionary, run: Dictionary, cycle: int) -> bool:
	for rule in rules:
		var value: Variant = rules[rule]
		var ok: bool = true
		match rule:
			"no_falls":
				ok = int(run.falls) == 0
			"no_losses":
				ok = int(run.losses) == 0
			"max_golems":
				ok = int(run.most_golems) <= int(value)
			"min_cycle":
				ok = cycle >= int(value)
		if not ok:
			return false
	return true


## Whether a playthrough's record so far still leaves a feat possible: every
## rule it has not yet broken (a fall, a loss, a fourth golem) can still hold.
static func feat_in_reach(rules: Dictionary, run: Dictionary, cycle: int) -> bool:
	return feat_met(rules, run, cycle)


## Ids of every challenge on a region's stages, in campaign order.
static func region_ids(region: Dictionary) -> Array:
	var ids: Array = []
	for stage in region.stages:
		ids.append_array(stage.get("challenges", []).map(func(c): return c.id))
	return ids


## Whether a region with a mastery has every one of its challenges in `met`.
static func mastered(region: Dictionary, met: Array) -> bool:
	return region.has("mastery") and region_ids(region).all(func(id): return id in met)


## Regions that `newly` met challenges have just completed: each one's
## mastery is earned at that moment, once.
static func newly_mastered(catalog: Catalog, newly: Array, met: Array) -> Array:
	var found: Array = []
	for region in catalog.regions():
		if mastered(region, met) and region_ids(region).any(func(id): return id in newly):
			found.append(region)
	return found


## Every way each playable spirit can join, by spirit id: a list of
## {"tier", "kind", "id"} where kind is "start", "stage", "challenge", "feat" or "crucible"
## (id names it; a Crucible milestone for "crucible") and tier is "play" (start or a stage's first clear),
## "challenge" or "extreme" (an extreme challenge, a feat or a Crucible milestone).
static func spirit_sources(catalog: Catalog) -> Dictionary:
	var found: Dictionary = {}
	var add := func(spirit_id: String, tier: String, kind: String, id: String) -> void:
		found[spirit_id] = found.get(spirit_id, []) + [{"tier": tier, "kind": kind, "id": id}]
	for spirit_id in catalog.campaign.start.spirits:
		add.call(spirit_id, "play", "start", "")
	for stage in catalog.stages.values():
		for spirit_id in stage.get("rewards", {}).get("spirits", []):
			add.call(spirit_id, "play", "stage", stage.id)
	for entry in catalog.challenges.values():
		for spirit_id in entry.get("rewards", {}).get("spirits", []):
			add.call(spirit_id, "extreme" if entry.get("extreme", false) else "challenge", "challenge", entry.id)
	for entry in catalog.feats.values():
		for spirit_id in entry.get("rewards", {}).get("spirits", []):
			add.call(spirit_id, "extreme", "feat", entry.id)
	for entry in catalog.crucible_index.milestones.values():
		for spirit_id in entry.rewards.get("spirits", []):
			add.call(spirit_id, "extreme", "crucible", entry.id)
	return found


## Problems with one challenge or feat entry, for Catalog.errors.
static func problems(catalog: Catalog, owner: String, entry: Variant, feat: bool) -> Array[String]:
	var found: Array[String] = []
	if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String \
			or not entry.get("text") is String:
		found.append(owner + " needs an id, name and text")
		return found
	owner += " " + entry.id
	var vocabulary: Dictionary = FEAT_RULES if feat else RULES
	var rules: Variant = entry.get("rules")
	if not rules is Dictionary or rules.is_empty():
		found.append(owner + " needs rules")
		return found
	for rule in rules:
		var value: Variant = rules[rule]
		if not vocabulary.has(rule):
			found.append("%s has unknown rule %s" % [owner, rule])
			continue
		var expected: int = vocabulary[rule]
		var typed: bool = typeof(value) == expected or (expected == TYPE_INT and value is float and int(value) == value)
		if not typed or (expected == TYPE_BOOL and value != true):
			found.append("%s rule %s has the wrong kind of value" % [owner, rule])
			continue
		if expected == TYPE_INT and int(value) < (0 if rule == "min_cycle" else 1):
			found.append("%s rule %s is out of range" % [owner, rule])
		var lists: Dictionary = {"forbid_elements": catalog.elements, "only_elements": catalog.elements,
			"only_materials": catalog.parts.materials, "forbid_arms": catalog.parts.arms}
		if lists.has(rule) and (value.is_empty() or value.any(func(id): return not lists[rule].has(id))):
			found.append("%s rule %s names something unknown" % [owner, rule])
		if rule == "attack_kind" and not value in ["physical", "magical"]:
			found.append(owner + " attack_kind must be physical or magical")
		if rule == "empty_row" and not value in Catalog.ROWS:
			found.append(owner + " empty_row must be front or back")
		if rule == "require" and (value.is_empty() or value.keys().any(func(key): return not key in REQUIRE_KEYS)):
			found.append("%s require may only name %s" % [owner, ", ".join(REQUIRE_KEYS)])
	if entry.has("extreme") and not entry.extreme is bool:
		found.append(owner + " extreme must be true or false")
	var rewards: Variant = entry.get("rewards", {})
	if not rewards is Dictionary:
		found.append(owner + " rewards must be an object")
		return found
	for kind in rewards:
		if not kind in ["spirits"] + Catalog.PART_KINDS or not rewards[kind] is Array:
			found.append("%s cannot reward %s" % [owner, kind])
			continue
		for id in rewards[kind]:
			var known: bool = catalog.spirit(String(id)).get("playable", false) if kind == "spirits" \
				else not catalog.part(kind, String(id)).is_empty()
			if not known:
				found.append("%s rewards unknown %s %s" % [owner, kind, id])
	return found
