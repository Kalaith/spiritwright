extends RefCounted
## What every check module shares: the catalog (loaded once), assertions
## gathered into one verdict per scenario, and the builders the scenarios fight
## with. The toolkit's check runner (see tools/sim_checks.gd) calls each
## `check_*` method, which ends with `return verdict()`: "" when every
## assertion held, else the names of those that failed.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

static var _shared: Catalog = null

var catalog: Catalog
var _failed: Array[String] = []


func _init() -> void:
	catalog = shared_catalog()


## The one catalog every module reads; load_all has run on it.
static func shared_catalog() -> Catalog:
	if _shared == null:
		_shared = Catalog.new()
		_shared.load_all()
	return _shared


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failed.append(name + ("  (" + detail + ")" if not detail.is_empty() else ""))


## "" when every _check since the last verdict held, else what failed.
func verdict() -> String:
	var result: String = "; ".join(_failed)
	_failed.clear()
	return result


## A new game that never touches the disk.
func _fresh() -> Progression:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	return progression


## Whether any event of `type` reads with `fragment` in its text.
func _said(outcome: Dictionary, type: String, fragment: String) -> bool:
	return outcome.events.any(func(e): return e.type == type and String(e.text).contains(fragment))


## Target ids of every attack `unit_id` makes, in order.
func _attacks(outcome: Dictionary, unit_id: String) -> Array:
	return outcome.events.filter(func(e): return e.type == "attack" and e.unit == unit_id).map(func(e): return e.target)


## Whether `unit_id` was still standing when `moment` happened.
func _alive_before(outcome: Dictionary, unit_id: String, moment: Dictionary) -> bool:
	for event in outcome.events:
		if event == moment:
			return true
		if event.type == "death" and event.unit == unit_id:
			return false
	return true


func _strip(loadout: Dictionary) -> Dictionary:
	loadout.erase("material")
	loadout.erase("lane")
	return loadout


func _loadout(spirit: String, frame: String, arms: String, legs: String, row: String, material: String = "stone",
		lane: int = 1, sigil: String = "") -> Dictionary:
	return {"spirit": spirit, "frame": frame, "arms": arms, "legs": legs, "material": material, "sigil": sigil,
		"row": row, "lane": lane}


func _has(outcome: Dictionary, fields: Dictionary) -> bool:
	for event in outcome.events:
		var matched: bool = true
		for key in fields:
			matched = matched and event.get(key) == fields[key]
		if matched:
			return true
	return false


## Each side is a list of [spirit id, level, loadout].
func _duel(side_a: Array, side_b: Array) -> Dictionary:
	var teams: Array = []
	for side in [side_a, side_b]:
		var wild: bool = teams.size() == 1
		teams.append(side.map(func(entry): return Builds.resolve(catalog, entry[2], entry[1], {}, wild)))
	return BattleSim.new().run(catalog, teams[0], teams[1], 11)


## A random legal team from what `progression` has unlocked, one golem per
## built golem, in shuffled cells.
func _random_team(progression: Progression, rng: RandomNumberGenerator) -> Array:
	var ids: Array = progression.spirits.keys()
	Det.shuffle(rng, ids)
	var cells: Array = Progression.BUILD_CELLS.duplicate()
	Det.shuffle(rng, cells)
	var team: Array = []
	for slot in range(progression.team.size()):
		var sigils: Array = [""] + progression.unlocks.sigils
		team.append({
			"spirit": ids[slot],
			"frame": Det.pick(rng, progression.unlocks.frames),
			"arms": Det.pick(rng, progression.unlocks.arms),
			"legs": Det.pick(rng, progression.unlocks.legs),
			"material": Det.pick(rng, progression.unlocks.materials),
			"sigil": Det.pick(rng, sigils),
			"row": String(cells[slot]).get_slice(":", 0),
			"lane": String(cells[slot]).get_slice(":", 1).to_int(),
		})
	return team
