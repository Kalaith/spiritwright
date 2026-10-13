extends RefCounted
## Experience and levels: what each level costs, what a stage is worth, and
## levelling one spirit up. Pure rules on balance.json; Progression owns the
## spirits these are applied to.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")


## XP a spirit at `level` needs to reach the next level: each level costs more.
static func xp_to_next(catalog: Catalog, level: int) -> int:
	return int(catalog.num("xp_per_level") + catalog.num("xp_per_level_growth") * (level - 1))


## XP one spirit earns from a stage: the enemies' `average` level times
## xp.per_stage_level, scaled by the outcome, and by how far the spirit's level
## sits below (more) or above (less) that average. Levels cost a steady amount
## more each time, so a spirit keeps pace with the stages without grinding.
## The total is then scaled by the whole-number percentages xp.gain_percent
## (every spirit) and the spirit's own xp_percent (100 when absent).
static func stage_xp(catalog: Catalog, average: float, spirit_level: int, outcome_factor: float, spirit_id: String = "") -> int:
	var level_factor: float = clampf(1.0 + (average - spirit_level) * catalog.num("xp.level_gap_step"),
		catalog.num("xp.min_factor"), catalog.num("xp.max_factor"))
	var percent: float = catalog.num("xp.gain_percent") * int(catalog.spirit(spirit_id).get("xp_percent", 100)) / 10000.0
	return max(1, int(round(average * catalog.num("xp.per_stage_level") * outcome_factor * level_factor * percent)))


## Adds XP to one spirit's `entry` ({level, xp, ...}) and levels it up to the
## cap; returns the result screen's line: {spirit, gained, from, to, rises, awakened}.
static func give(catalog: Catalog, id: String, entry: Dictionary, gained: int) -> Dictionary:
	var spirit_def: Dictionary = catalog.spirit(id)
	var cap: int = int(catalog.num("level_cap"))
	var line: Dictionary = {"spirit": id, "gained": gained, "from": entry.level, "rises": {}}
	entry.xp += gained
	while entry.xp >= xp_to_next(catalog, entry.level) and entry.level < cap:
		entry.xp -= xp_to_next(catalog, entry.level)
		var rises: Dictionary = Builds.level_up_gains(catalog, spirit_def, entry.level)
		for stat in rises:
			line.rises[stat] = int(line.rises.get(stat, 0)) + int(rises[stat])
		entry.level += 1
	if entry.level >= cap:
		entry.xp = 0
	line["to"] = entry.level
	line["awakened"] = Builds.awakened(catalog, spirit_def, entry.level) and not Builds.awakened(catalog, spirit_def, int(line.from))
	return line
