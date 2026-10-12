extends RefCounted
## Turns a loadout (spirit + frame + arms + legs + sigil + row) into the
## resolved golem the battle simulation consumes. The breakdown keeps every
## stat source so the workshop can show exactly where a number comes from.

const Catalog = preload("res://scripts/core/catalog.gd")


## Growth is smoothed rather than rolled: each level adds the growth percentage
## to a running total that starts half full, and every 100 is one stat point.
## Two spirits with the same rates at the same level always match.
static func stat_gains(catalog: Catalog, spirit_def: Dictionary, level: int) -> Dictionary:
	var gains: Dictionary = {}
	var start: float = catalog.num("growth.start_progress")
	for stat in Catalog.STATS:
		var points: int = int(floor((start + float(spirit_def.growth[stat]) * float(level - 1)) / 100.0))
		if stat == "hp":
			points *= int(catalog.num("growth.hp_per_point"))
		gains[stat] = points
	return gains


static func spirit_stats(catalog: Catalog, spirit_def: Dictionary, level: int) -> Dictionary:
	var gains: Dictionary = stat_gains(catalog, spirit_def, level)
	var stats: Dictionary = {}
	for stat in Catalog.STATS:
		stats[stat] = int(spirit_def.base[stat]) + int(gains[stat])
	return stats


## Which stats rise between `level` and `level + 1`.
static func level_up_gains(catalog: Catalog, spirit_def: Dictionary, level: int) -> Dictionary:
	var before: Dictionary = stat_gains(catalog, spirit_def, level)
	var after: Dictionary = stat_gains(catalog, spirit_def, level + 1)
	var rises: Dictionary = {}
	for stat in Catalog.STATS:
		if int(after[stat]) > int(before[stat]):
			rises[stat] = int(after[stat]) - int(before[stat])
	return rises


## `history` is what the spirit remembers and who stands beside it now:
## {"last_frame": String, "last_allies": Array, "allies": Array} (spirit ids).
static func preference(catalog: Catalog, spirit_def: Dictionary, loadout: Dictionary, history: Dictionary) -> Dictionary:
	var temperament: Dictionary = catalog.temperaments.get(String(spirit_def.get("temperament", "")), {})
	if temperament.is_empty():
		return {"active": false, "label": "", "text": "", "bonus": {}}
	var active: bool = false
	if temperament.get("prefers_new_frame", false):
		active = String(loadout.frame) != String(history.get("last_frame", ""))
	elif temperament.has("prefers_row"):
		active = String(loadout.row) == String(temperament.prefers_row)
	elif temperament.get("prefers_familiar", false):
		var remembered: Array = history.get("last_allies", [])
		active = history.get("allies", []).any(func(ally): return ally in remembered)
	else:
		var tags: Array = []
		for kind in Catalog.LOADOUT_KEYS:
			tags.append_array(catalog.part(kind, String(loadout[Catalog.LOADOUT_KEYS[kind]])).get("tags", []))
		for tag in temperament.get("prefers_tags", []):
			if tag in tags:
				active = true
	return {"active": active, "label": temperament.label, "text": temperament.text, "bonus": temperament.bonus}


## Whether a spirit at `level` has grown its second trait.
static func awakened(catalog: Catalog, spirit_def: Dictionary, level: int) -> bool:
	return spirit_def.has("awakening") and level >= int(catalog.num("awaken_level"))


## `level` and `history` (see `preference`) come from the spirit instance; wild
## spirits pass none.
static func resolve(catalog: Catalog, loadout: Dictionary, level: int, history: Dictionary = {}) -> Dictionary:
	var spirit_def: Dictionary = catalog.spirit(String(loadout.spirit))
	var frame: Dictionary = catalog.part("frames", String(loadout.frame))
	var arms: Dictionary = catalog.part("arms", String(loadout.arms))
	var legs: Dictionary = catalog.part("legs", String(loadout.legs))
	var sigil: Dictionary = catalog.part("sigils", String(loadout.get("sigil", "")))
	var trait_def: Dictionary = spirit_def["trait"]
	var row: String = String(loadout.row)
	var breakdown: Array = []
	breakdown.append({"label": "%s Lv %d" % [spirit_def.name, level], "stats": spirit_stats(catalog, spirit_def, level)})
	breakdown.append({"label": frame.name, "stats": frame.get("stats", {})})
	breakdown.append({"label": arms.name, "stats": arms.get("stats", {})})
	breakdown.append({"label": legs.name, "stats": legs.get("stats", {})})
	var pref: Dictionary = preference(catalog, spirit_def, loadout, history)
	if pref.active:
		breakdown.append({"label": pref.label + " preference", "stats": pref.bonus})
	if row == "front" and not trait_def.get("front_row", {}).is_empty():
		breakdown.append({"label": trait_def.name + " (front row)", "stats": trait_def.front_row})
	var stats: Dictionary = {}
	for stat in Catalog.STATS:
		var total: int = 0
		for source in breakdown:
			total += int(source.stats.get(stat, 0))
		stats[stat] = max(1 if stat in ["hp", "spd"] else 0, total)
	var effects: Array = []
	for effect in trait_def.get("effects", []):
		effects.append(_tagged(effect, trait_def.name))
	var is_awake: bool = awakened(catalog, spirit_def, level)
	if is_awake:
		for effect in spirit_def.awakening.effects:
			effects.append(_tagged(effect, spirit_def.awakening.name))
	if not sigil.is_empty():
		for effect in sigil.get("effects", []):
			effects.append(_tagged(effect, sigil.name))
	return {
		"spirit": spirit_def.id,
		"name": spirit_def.name,
		"element": spirit_def.element,
		"level": level,
		"row": row,
		"frame": frame.id,
		"arms": arms.id,
		"legs": legs.id,
		"sigil": sigil.get("id", ""),
		"stats": stats,
		"breakdown": breakdown,
		"preference": pref,
		"awakened": is_awake,
		"attack": arms.attack,
		"stable": legs.get("stable", false),
		"reach": legs.get("reach", false),
		"effects": effects,
	}


static func _tagged(effect: Dictionary, source: String) -> Dictionary:
	var copy: Dictionary = effect.duplicate(true)
	copy["source"] = source
	return copy
