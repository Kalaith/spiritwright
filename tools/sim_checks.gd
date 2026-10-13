extends SceneTree
## Headless checks for the data and the simulation. Prints PASS/FAIL lines and
## exits non-zero on failure. Run:
##   godot --headless --path . --script res://tools/sim_checks.gd
## Pass `-- --report` to also print every stage's outcome and the Crucible's for balance
## work, or `-- --crucible` for the Crucible alone.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const CollectionChecks = preload("res://tools/checks_collection.gd")
const CrucibleChecks = preload("res://tools/checks_crucible.gd")

var failures: int = 0


func _init() -> void:
	var catalog := Catalog.new()
	_check("catalog loads", catalog.load_all(), ", ".join(catalog.errors))
	if failures == 0:
		_check_growth(catalog)
		_check_determinism(catalog)
		_check_progression(catalog)
		_check_slice(catalog)
		_check_spirits(catalog)
		_check_materials(catalog)
		_check_board(catalog)
		_check_arsenal(catalog)
		CollectionChecks.new(self, catalog).run()
		CrucibleChecks.new(self, catalog).run()
		if "--report" in OS.get_cmdline_user_args():
			_report(catalog)
		if "--report" in OS.get_cmdline_user_args() or "--crucible" in OS.get_cmdline_user_args():
			CrucibleChecks.new(self, catalog).report()
	print("%s (%d failure(s))" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		print("FAIL ", name, "  ", detail)


func _check_growth(catalog: Catalog) -> void:
	var pyra: Dictionary = catalog.spirit("pyra")
	var level_one: Dictionary = Builds.spirit_stats(catalog, pyra, 1)
	_check("level 1 stats equal base", level_one.str == int(pyra.base.str))
	var level_five: Dictionary = Builds.spirit_stats(catalog, pyra, 5)
	# 50 + 60 * 4 = 290 -> 2 points of STR.
	_check("smoothed growth adds expected STR", level_five.str == int(pyra.base.str) + 2, str(level_five))


func _check_determinism(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var stage: Dictionary = catalog.stages["ruins_court"]
	var first: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), 7)
	var second: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), 7)
	_check("same seed gives the same battle", JSON.stringify(first.events) == JSON.stringify(second.events))
	_check("battle ends", first.result in ["win", "loss", "timeout"])
	# Armour blunts blows rather than cancelling them: even the plated Rubble Imp takes real hits.
	var imp_hits: Array = first.events.filter(func(e): return e.type == "damage" and e.cause == "attack" and e.unit == "b0")
	var imp_total: int = imp_hits.reduce(func(sum, e): return sum + int(e.amount), 0)
	_check("armour does not reduce hits to chip damage", not imp_hits.is_empty() and imp_total >= 3 * imp_hits.size(),
		"%d damage over %d hits" % [imp_total, imp_hits.size()])


func _check_progression(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_path = "user://sim_checks_save.json"
	progression.new_game()
	_check("new game is a valid save", progression.valid(progression.to_dict()))
	_check("the campaign starts with one golem", progression.team.size() == 1 and progression.cores == 0)
	_check("locked part is refused", not progression.set_slot(0, "arms", "cannon"))
	_check("a resting spirit can take the golem", progression.set_slot(0, "spirit", "neris")
		and progression.team[0].spirit == "neris" and progression.resting_spirits() == ["pyra", "odo"])
	_check("no golem is built without a core", not progression.build_golem() and progression.team.size() == 1)
	var report: Dictionary = progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("first clear unlocks the cannon", "cannon" in progression.unlocks.arms and report.first_clear)
	_check("the gate yields a golem core", progression.cores == 1 and report.rewards.any(func(r): return r.kind == "cores"))
	_check("stage two opens", progression.stage_state("ruins_court") == "open")
	_check("the laboratory builds a second golem", progression.build_golem() and progression.team.size() == 2
		and progression.cores == 0 and progression.team[1].spirit == "pyra" and Catalog.cell_of(progression.team[1]) == "back:1")
	_check("moving into an occupied cell swaps the two golems", progression.set_slot(1, "cell", "front:1")
		and Catalog.cell_of(progression.team[0]) == "back:1" and Catalog.cell_of(progression.team[1]) == "front:1")
	_check("a cell off the board is refused", not progression.set_slot(0, "cell", "front:3")
		and not progression.set_slot(0, "cell", "middle:0"))
	_check("swapping spirits keeps them unique", progression.set_slot(0, "spirit", "pyra")
		and progression.team[1].spirit == "neris")
	progression.cores = int(catalog.num("team_size")) - 1
	_check("a save cannot hold more golems than team_size", not progression.valid(progression.to_dict()))
	progression.cores = 0
	var gate_xp: int = progression.stage_xp(catalog.stages["ruins_gate"], 1, catalog.num("xp.repeat_win"))
	var court_xp: int = progression.stage_xp(catalog.stages["ruins_court"], 1, catalog.num("xp.repeat_win"))
	_check("a stronger enemy team is worth more XP", court_xp > gate_xp, "%d vs %d" % [court_xp, gate_xp])
	_check("an over-levelled spirit earns less XP",
		progression.stage_xp(catalog.stages["ruins_gate"], 5, 1.0) < gate_xp)
	_check("each level costs more XP than the last", progression.xp_to_next(10) > progression.xp_to_next(1))
	var court: Dictionary = catalog.stages["ruins_court"]
	var full_xp: int = progression.stage_xp(court, 1, 1.0)
	catalog.spirit("pyra")["xp_percent"] = 50
	var halved_xp: int = progression.stage_xp(court, 1, 1.0, "pyra")
	catalog.spirit("pyra").erase("xp_percent")
	_check("a spirit's xp_percent scales its XP on top of the global rate",
		halved_xp == int(round(full_xp / 2.0)) and progression.stage_xp(court, 1, 1.0, "pyra") == full_xp,
		"%d vs %d" % [halved_xp, full_xp])
	var reachable: Array = []
	var grew: bool = true
	while grew:
		grew = false
		for stage in catalog.stages.values():
			if not stage.id in reachable and stage.get("requires", []).all(func(id): return id in reachable):
				reachable.append(stage.id)
				grew = true
	_check("every stage in every region can be reached", reachable.size() == catalog.stages.size(),
		str(catalog.stages.keys().filter(func(id): return not id in reachable)))
	progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("a replay grants no second core", progression.cores == 0)
	_check("save writes", progression.save_game(), progression.last_error)
	var reloaded := Progression.new(catalog)
	reloaded.save_path = progression.save_path
	_check("save reads back", reloaded.load_game() and JSON.stringify(reloaded.to_dict()) == JSON.stringify(progression.to_dict()))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progression.save_path + suffix)


## The slice's first stage must be winnable with the starting team as given.
func _check_slice(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var stage: Dictionary = catalog.stages["ruins_gate"]
	var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), int(stage.seed))
	_check("starting team wins the Mossy Gate", outcome.result == "win", outcome.result)


## Awakenings, temperaments and the spirit-driven effects (receivers, damage,
## haste, kill triggers and Stun as a status).
func _check_spirits(catalog: Catalog) -> void:
	var awaken: int = int(catalog.num("awaken_level"))
	var pyra_loadout: Dictionary = _loadout("pyra", "strider", "hammer", "spider", "front")
	var asleep: Dictionary = Builds.resolve(catalog, pyra_loadout, awaken - 1)
	var awake: Dictionary = Builds.resolve(catalog, pyra_loadout, awaken)
	_check("awakening waits for its level", not asleep.awakened
		and not asleep.effects.any(func(e): return e.source == "Wildfire"))
	_check("awakening adds its effects", awake.awakened and awake.effects.any(func(e): return e.source == "Wildfire"))

	var briar: Dictionary = catalog.spirit("briar")
	var history: Dictionary = {"last_frame": "", "last_allies": ["odo"], "allies": ["odo", "pyra"]}
	var back: Dictionary = _loadout("briar", "bulwark", "shield", "pillar", "back")
	_check("loyal prefers a familiar ally", Builds.preference(catalog, briar, back, history).active)
	history.allies = ["neris", "pyra"]
	_check("loyal is idle beside strangers", not Builds.preference(catalog, briar, back, history).active)
	var volta: Dictionary = catalog.spirit("volta")
	_check("patient prefers the back row", Builds.preference(catalog, volta, back, {}).active
		and not Builds.preference(catalog, volta, _loadout("volta", "bulwark", "shield", "pillar", "front"), {}).active)

	var thorns: Dictionary = _duel(catalog, [["briar", 3, _loadout("briar", "bulwark", "shield", "pillar", "front")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "strider", "hammer", "spider", "front")]])
	_check("thorns lash the attacker", _has(thorns, {"type": "damage", "cause": "effect", "unit": "b0", "source": "a0"}))

	var storm: Dictionary = _duel(catalog, [
			["sefa", awaken, _loadout("sefa", "conduit", "cannon", "pillar", "back", "stone", 0)],
			["volta", awaken, _loadout("volta", "conduit", "cannon", "pillar", "back", "stone", 1)],
			["pyra", awaken, _loadout("pyra", "strider", "hammer", "pillar", "front")]],
		[["moss_wisp", 6, _loadout("moss_wisp", "bulwark", "shield", "spider", "front", "stone", 1)],
			["rubble_imp", 6, _loadout("rubble_imp", "bulwark", "shield", "spider", "back", "stone", 0)],
			["rubble_imp", 6, _loadout("rubble_imp", "bulwark", "shield", "spider", "back", "stone", 2)]])
	_check("tailwind hastens allies", _has(storm, {"type": "haste", "cause": "Tailwind"}))
	_check("conduction jolts soaked enemies", _has(storm, {"type": "damage", "cause": "effect", "source": "a1"}))
	_check("overcharge stuns soaked enemies", _has(storm, {"type": "status", "status": "stun", "cause": "Overcharge"}))
	# Wildfire needs a kill that leaves someone standing: Pyra alone against a weak pair.
	var wildfire: Dictionary = _duel(catalog, [["pyra", 10, _loadout("pyra", "strider", "hammer", "pillar", "front")]],
		[["cinder_mote", 1, _loadout("cinder_mote", "strider", "shield", "pillar", "front")],
			["rubble_imp", 6, _loadout("rubble_imp", "bulwark", "shield", "pillar", "front", "stone", 0)]])
	_check("wildfire spreads burn on a kill", _has(wildfire, {"type": "status", "status": "burn", "cause": "Wildfire"}))

	var migrated: Variant = Progression.new(catalog).migrate({"schema": 1, "spirits": {"pyra": {"level": 1, "xp": 0, "last_frame": ""}}})
	_check("schema 1 saves gain remembered allies", migrated.schema == 2 and migrated.spirits.pyra.last_allies == [])
	var strict := Catalog.new()
	strict._validate_effects("probe", [{"on": "hit", "do": "damage", "flat": 2, "to": "attacker"}])
	_check("catalog rejects an unreachable receiver", not strict.errors.is_empty())


## Materials: stats from the body, element reactions, their effects in battle
## and the schema 2 save migration.
func _check_materials(catalog: Catalog) -> void:
	var stone: Dictionary = Builds.resolve(catalog, _loadout("pyra", "strider", "hammer", "pillar", "front"), 3)
	var wood: Dictionary = Builds.resolve(catalog, _loadout("pyra", "strider", "hammer", "pillar", "front", "wood"), 3)
	var kindling: Dictionary = catalog.reaction("wood", "fire")
	_check("fire in wood is Kindling", wood.reaction.get("id") == "kindling"
		and wood.effects.any(func(e): return e.source == kindling.name))
	_check("kindling trades defence for attack", wood.stats.str > stone.stats.str and wood.stats.def < stone.stats.def,
		"%s vs %s" % [wood.stats, stone.stats])
	var plain: Dictionary = Builds.resolve(catalog, _loadout("neris", "strider", "hammer", "pillar", "front", "wood"), 3)
	_check("a material only reacts with its elements", plain.reaction.is_empty()
		and not plain.breakdown.any(func(b): return String(b.label).ends_with("reaction")))

	var singe: Dictionary = _duel(catalog, [["pyra", 3, _loadout("pyra", "strider", "hammer", "pillar", "front", "wood")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "strider", "hammer", "pillar", "front")]])
	_check("kindling singes its attacker", _has(singe, {"type": "status", "status": "burn", "unit": "b0", "cause": kindling.name}))
	var glacier: Dictionary = _duel(catalog, [["neris", 3, _loadout("neris", "bulwark", "shield", "pillar", "front", "ice")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "strider", "hammer", "pillar", "front")]])
	_check("glacier soaks its attacker", _has(glacier, {"type": "status", "status": "soaked", "unit": "b0", "cause": "Glacier"}))
	var wire: Dictionary = _duel(catalog, [["volta", 3, _loadout("volta", "conduit", "cannon", "pillar", "back", "bronze")]],
		[["rubble_imp", 3, _loadout("rubble_imp", "bulwark", "shield", "pillar", "front")],
			["moss_wisp", 3, _loadout("moss_wisp", "bulwark", "shield", "pillar", "front", "stone", 0)]])
	_check("live wire arcs every hit", _has(wire, {"type": "chain", "unit": "a0"}))

	var progression := Progression.new(catalog)
	progression.save_enabled = false
	_check("locked material is refused", progression.set_slot(0, "material", "crystal") == false)
	var old: Dictionary = {"schema": 2, "battles": 3, "cleared": ["ruins_gate", "ruins_court"],
		"spirits": {"pyra": {"level": 2, "xp": 0, "last_frame": "", "last_allies": []},
			"neris": {"level": 2, "xp": 0, "last_frame": "", "last_allies": []},
			"odo": {"level": 2, "xp": 0, "last_frame": "", "last_allies": []}},
		"unlocks": {"frames": ["bulwark"], "arms": ["shield"], "legs": ["pillar"], "sigils": []},
		"team": [_strip(_loadout("odo", "bulwark", "shield", "pillar", "front")),
			_strip(_loadout("pyra", "bulwark", "shield", "pillar", "front")),
			_strip(_loadout("neris", "bulwark", "shield", "pillar", "back"))]}
	var migrated: Variant = progression.migrate(old)
	_check("schema 2 saves migrate to materials and keep their three golems", progression.valid(migrated)
		and migrated.team.size() == 3 and migrated.cores == 0
		and migrated.unlocks.materials == ["stone", "wood", "ice"] and migrated.team[0].material == "stone",
		JSON.stringify(migrated.get("unlocks", {})))
	_check("schema 4 saves spread each row across its lanes, centre first", migrated.schema == Progression.SAVE_SCHEMA
		and migrated.team.map(func(l): return Catalog.cell_of(l)) == ["front:1", "front:0", "back:1"],
		JSON.stringify(migrated.team))


## The 3x2 board: arms aim at a row and strike the nearest lane in it, the back
## row is only reached past an empty front (or by bows and Spider Legs), and the
## defensive parts guard, brace, harden and mend.
func _check_board(catalog: Catalog) -> void:
	var imp := func(lane: int, row: String = "front", arms: String = "shield") -> Dictionary:
		return _loadout("rubble_imp", "bulwark", arms, "pillar", row, "stone", lane)
	var wall: Array = [["rubble_imp", 6, imp.call(0, "front", "hammer")], ["rubble_imp", 6, imp.call(2, "front", "hammer")],
		["cinder_mote", 1, _loadout("cinder_mote", "strider", "shield", "pillar", "back", "stone", 2)]]
	var hammer: Dictionary = _duel(catalog, [["odo", 6, _loadout("odo", "bulwark", "hammer", "pillar", "front", "stone", 2)]], wall)
	var hammer_targets: Array = _attacks(hammer, "a0")
	_check("melee strikes the front-row enemy in its own lane first", not hammer_targets.is_empty() and hammer_targets[0] == "b1",
		str(hammer_targets))
	var front_left: bool = false
	for event in hammer.events:
		if event.type == "attack" and event.unit == "a0" and event.target == "b2":
			front_left = _alive_before(hammer, "b0", event) or _alive_before(hammer, "b1", event)
			break
	_check("a hammer cannot reach the back row while the front row stands", not front_left)
	var bow: Dictionary = _duel(catalog, [["sefa", 6, _loadout("sefa", "strider", "bow", "pillar", "back", "stone", 0)]], wall)
	var bow_targets: Array = _attacks(bow, "a0")
	_check("a bow lobs over the front row at the back row", not bow_targets.is_empty() and bow_targets[0] == "b2", str(bow_targets))
	var reaching: Dictionary = _duel(catalog, [["odo", 6, _loadout("odo", "bulwark", "hammer", "pillar", "back")]], wall)
	_check("melee from the back row reaches at reduced power", _said(reaching, "damage", "reaching from the back row"))

	var far_guard: Dictionary = _duel(catalog, [["sefa", 6, _loadout("sefa", "strider", "bow", "pillar", "back")]],
		[["rubble_imp", 6, imp.call(0)], ["cinder_mote", 6, _loadout("cinder_mote", "strider", "shield", "pillar", "back", "stone", 2)]])
	_check("a shield only guards its own and neighbouring lanes", not _has(far_guard, {"type": "intercept"}))
	var near_guard: Dictionary = _duel(catalog, [["sefa", 6, _loadout("sefa", "strider", "bow", "pillar", "back")]],
		[["rubble_imp", 6, imp.call(1)], ["cinder_mote", 6, _loadout("cinder_mote", "strider", "shield", "pillar", "back", "stone", 2)]])
	_check("a shield steps in for the neighbouring lane", _has(near_guard, {"type": "intercept", "unit": "b0", "protected": "b1"}))

	var aegis: Dictionary = _duel(catalog, [["odo", 3, _loadout("odo", "bulwark", "aegis", "tower", "front")],
			["neris", 3, _loadout("neris", "conduit", "cannon", "pillar", "back", "stone", 1, "mending")]],
		[["rubble_imp", 4, imp.call(1, "front", "hammer")], ["brine_sprite", 4, _loadout("brine_sprite", "strider", "bow", "pillar", "back")]])
	_check("aegis arms ward the golem sharing their lane", _has(aegis, {"type": "ward", "unit": "a1", "cause": "Aegis Arms"}))
	_check("tower legs brace the front row", _said(aegis, "damage", "Braced"))
	_check("the mending rune heals the most wounded", _has(aegis, {"type": "heal", "cause": "Mending Rune"}))
	var stoneskin: Dictionary = _duel(catalog, [["odo", 3, _loadout("odo", "bulwark", "shield", "pillar", "front", "stone", 1, "stoneskin")]],
		[["rubble_imp", 4, imp.call(1, "front", "hammer")]])
	_check("the stoneskin rune hardens when struck", _has(stoneskin, {"type": "ward", "unit": "a0", "cause": "Stoneskin Rune"}))

	var six: Array = []
	for cell in Progression.BUILD_CELLS:
		six.append(_loadout("rubble_imp", "bulwark", "hammer", "pillar", cell.get_slice(":", 0), "stone", cell.get_slice(":", 1).to_int()))
	_check("six golems fill the six cells", Catalog.distinct_cells(six))
	six[5].lane = 1
	_check("two golems cannot share a cell", not Catalog.distinct_cells(six))


## The later parts: each new mechanic shows up in the event log.
func _check_arsenal(catalog: Catalog) -> void:
	var brute: Callable = func(lane: int = 1, row: String = "front", arms: String = "hammer", sigil: String = "") -> Dictionary:
		return _loadout("slag_brute", "bulwark", arms, "pillar", row, "stone", lane, sigil)
	var line: Array = [["slag_brute", 8, brute.call(0)], ["slag_brute", 8, brute.call(1)], ["slag_brute", 8, brute.call(2)]]
	var flail: Dictionary = _duel(catalog, [["odo", 8, _loadout("odo", "bulwark", "flail", "pillar", "front")]], line)
	_check("a flail splashes the golems beside its target", _has(flail, {"type": "damage", "source": "a0", "cause": "splash"}))
	var blades: Dictionary = _duel(catalog, [["pyra", 8, _loadout("pyra", "strider", "twin_blades", "pillar", "front")]], line)
	var cuts: int = blades.events.filter(func(e): return e.type == "damage" and e.source == "a0" and e.cause == "attack").size()
	_check("twin blades cut twice a turn", cuts > _attacks(blades, "a0").size(), "%d cuts" % cuts)
	var spear_team: Array = [Builds.resolve(catalog, _loadout("odo", "strider", "spear", "pillar", "front"), 8)]
	var blunt_team: Array = spear_team.duplicate(true)
	blunt_team[0].attack.erase("pierce")
	var foes: Array = [Builds.resolve(catalog, _loadout("slag_brute", "bulwark", "shield", "tower", "back", "bronze"), 8, {}, true)]
	var pierced: Array = BattleSim.new().run(catalog, spear_team, foes, 3).events.filter(func(e): return e.type == "damage" and e.cause == "attack" and e.source == "a0")
	var blunted: Array = BattleSim.new().run(catalog, blunt_team, foes, 3).events.filter(func(e): return e.type == "damage" and e.cause == "attack" and e.source == "a0")
	_check("a pike punches through armour", int(pierced[0].amount) + int(pierced[0].absorbed) > int(blunted[0].amount) + int(blunted[0].absorbed))
	_check("a scythe executes the badly wounded", _said(_duel(catalog, [["odo", 10, _loadout("odo", "strider", "scythe", "pillar", "front")]],
		[["slag_brute", 6, brute.call()]]), "damage", "Execute"))
	var lantern: Dictionary = _duel(catalog, [["odo", 8, _loadout("odo", "bulwark", "shield", "pillar", "front")],
		["neris", 8, _loadout("neris", "conduit", "lantern", "stilts", "back")]], [["slag_brute", 8, brute.call()]])
	_check("a lantern mends the wounded as it hits", _has(lantern, {"type": "heal", "cause": "Lantern Arms"}))
	_check("stilts strike harder from the back row", _said(lantern, "damage", "from the stilts"))
	var staff: Dictionary = _duel(catalog, [["volta", 8, _loadout("volta", "conduit", "storm_staff", "pillar", "back")]],
		[["slag_brute", 8, brute.call()], ["dust_devil", 8, brute.call(1, "back")]])
	_check("a storm staff strikes the back row", _attacks(staff, "a0").front() == "b1")

	var burner: Array = [["cinder_mote", 8, _loadout("cinder_mote", "strider", "hammer", "pillar", "front", "stone", 1, "ember_sigil")]]
	var treads: Dictionary = _duel(catalog, [["odo", 8, _loadout("odo", "bulwark", "shield", "treads", "front")]], burner)
	_check("treads cannot be set Burning", _said(treads, "resist", "shrugs off Burn") and not _has(treads, {"type": "status", "unit": "a0", "status": "burn"}))
	var cleanse: Dictionary = _duel(catalog, [["odo", 8, _loadout("odo", "bulwark", "shield", "pillar", "front", "stone", 1, "cleansing_charm")]], burner)
	_check("a cleansing charm washes off Burn", _has(cleanse, {"type": "cleanse", "unit": "a0"}))
	var colossus: Dictionary = _duel(catalog, [["odo", 8, _loadout("odo", "colossus", "shield", "spider", "front")]],
		[["slag_brute", 8, brute.call()]])
	_check("a colossus starts warded and cannot be Stunned", _has(colossus, {"type": "ward", "unit": "a0", "cause": "Colossus Frame"})
		and not _has(colossus, {"type": "status", "unit": "a0", "status": "stun"}))

	var sigil_duel: Callable = func(sigil: String, legs: String = "pillar") -> Dictionary:
		return _duel(catalog, [["pyra", 8, _loadout("pyra", "strider", "hammer", legs, "front", "stone", 1, sigil)]],
			[["slag_brute", 8, brute.call()]])
	_check("skates leap forward at the start", _has(sigil_duel.call("", "skates"), {"type": "haste", "cause": "Ice Skates"}))
	_check("a leech fang drinks from its hits", _has(sigil_duel.call("leech_fang"), {"type": "heal", "unit": "a0", "cause": "Leech Fang"}))
	_check("a war drum hurries the team", _has(sigil_duel.call("war_drum"), {"type": "haste", "cause": "War Drum"}))
	_check("a hunter's brand exposes the target", _said(sigil_duel.call("hunters_brand"), "damage", "Exposed"))
	_check("a frost sigil slows the target", _has(sigil_duel.call("frost_sigil"), {"type": "slow", "unit": "b0"}))
	_check("a hex eye weakens the target", _said(sigil_duel.call("hex_eye"), "damage", "Weakened"))
	_check("thorns lash the attacker", _has(_duel(catalog, [["odo", 8, _loadout("odo", "bulwark", "shield", "pillar", "front", "stone", 1, "thorn_crest")]],
		[["slag_brute", 8, brute.call()]]), {"type": "damage", "source": "a0", "cause": "effect"}))
	_check("a storm coil crackles over every enemy", _said(_duel(catalog, [["volta", 8, _loadout("volta", "conduit", "cannon", "pillar", "back", "stone", 1, "storm_coil")]],
		line), "damage", "Storm Coil"))
	var phoenix: Dictionary = _duel(catalog, [["pyra", 3, _loadout("pyra", "strider", "hammer", "pillar", "front", "stone", 1, "phoenix_ember")]],
		[["slag_brute", 12, brute.call()]])
	_check("a phoenix ember rises once from a killing blow", _has(phoenix, {"type": "heal", "unit": "a0", "cause": "Phoenix Ember"})
		and phoenix.events.filter(func(e): return e.type == "heal" and e.cause == "Phoenix Ember").size() == 1)
	var vengeance: Dictionary = _duel(catalog, [["pyra", 2, _loadout("pyra", "strider", "hammer", "pillar", "front")],
		["odo", 12, _loadout("odo", "bulwark", "shield", "pillar", "back", "stone", 1, "vengeance_idol")]], [["slag_brute", 12, brute.call()]])
	_check("a vengeance idol answers a fallen ally", _has(vengeance, {"type": "haste", "unit": "a1", "cause": "Vengeance Idol"}))
	_check("magma heart sets its targets Burning", _has(_duel(catalog, [["pyra", 8, _loadout("pyra", "strider", "hammer", "pillar", "front", "obsidian")]],
		[["slag_brute", 8, brute.call()]]), {"type": "status", "unit": "b0", "status": "burn", "cause": "Magma Heart"}))


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
func _duel(catalog: Catalog, side_a: Array, side_b: Array) -> Dictionary:
	var teams: Array = []
	for side in [side_a, side_b]:
		var wild: bool = teams.size() == 1
		teams.append(side.map(func(entry): return Builds.resolve(catalog, entry[2], entry[1], {}, wild)))
	return BattleSim.new().run(catalog, teams[0], teams[1], 11)


## Plays the campaign in order. For each stage it samples random legal builds
## from what is unlocked, prints the win rate, then fights with the best one.
func _report(catalog: Catalog) -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var collection := CollectionChecks.new(self, catalog)
	var tiers: Dictionary = {}
	var sources: Dictionary = CollectionChecks.Challenges.spirit_sources(catalog)
	for id in sources:
		tiers[sources[id][0].tier] = tiers.get(sources[id][0].tier, []) + [id]
	for tier in tiers:
		print("  %d spirits join from %s: %s" % [tiers[tier].size(), tier, ", ".join(tiers[tier])])
	for stage in catalog.stages.values():
		while progression.build_golem():
			pass
		var enemies: Array = progression.enemy_team(stage)
		var wins: int = 0
		var samples: int = 500
		var best: Array = []
		var best_margin: int = -1
		var hits: int = 0
		var hit_total: int = 0
		var chip_hits: int = 0
		var turns: int = 0
		var timeouts: int = 0
		for i in range(samples):
			var trial: Array = _random_team(progression, rng)
			progression.team = trial
			var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), enemies, int(stage.seed))
			for event in outcome.events:
				if event.type == "turn":
					turns += 1
				elif event.type == "damage" and event.cause == "attack":
					hits += 1
					hit_total += int(event.amount)
					if int(event.amount) <= 2:
						chip_hits += 1
			if outcome.result == "timeout":
				timeouts += 1
			if outcome.result == "win":
				wins += 1
				var margin: int = 0
				for unit in outcome.units:
					if unit.side == 0:
						margin += unit.hp
				if margin > best_margin:
					best_margin = margin
					best = trial
		var levels: Array = progression.spirits.keys().map(func(id): return "%s%d" % [id, progression.spirits[id].level])
		print("  %-20s %d golem(s), random-build win rate %5.1f%%  levels %s" % [stage.name, progression.team.size(),
			100.0 * wins / samples, levels])
		print("    avg hit %.1f, hits of 1-2 %.0f%%, turns per battle %.1f, timeouts %d" % [
			float(hit_total) / max(hits, 1), 100.0 * chip_hits / max(hits, 1), float(turns) / samples, timeouts])
		if best.is_empty():
			print("    no winning build found; grinding the previous stage once")
			progression.team = _random_team(progression, rng)
			progression.apply_battle(stage, "loss")
			continue
		progression.team = best
		for loadout in best:
			print("    best: %s" % [loadout])
		progression.apply_battle(stage, "win")
		collection.challenge_report(progression, stage, rng)


func _random_team(progression: Progression, rng: RandomNumberGenerator) -> Array:
	var ids: Array = progression.spirits.keys()
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	var cells: Array = Progression.BUILD_CELLS.duplicate()
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap_cell: Variant = cells[i]
		cells[i] = cells[j]
		cells[j] = swap_cell
	var team: Array = []
	for slot in range(progression.team.size()):
		var sigils: Array = [""] + progression.unlocks.sigils
		team.append({
			"spirit": ids[slot],
			"frame": _pick(progression.unlocks.frames, rng),
			"arms": _pick(progression.unlocks.arms, rng),
			"legs": _pick(progression.unlocks.legs, rng),
			"material": _pick(progression.unlocks.materials, rng),
			"sigil": _pick(sigils, rng),
			"row": String(cells[slot]).get_slice(":", 0),
			"lane": String(cells[slot]).get_slice(":", 1).to_int(),
		})
	return team


func _pick(options: Array, rng: RandomNumberGenerator) -> Variant:
	return options[rng.randi_range(0, options.size() - 1)]
