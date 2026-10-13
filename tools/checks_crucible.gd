extends RefCounted
## Checks and the balance report for the Shifting Crucible: sequences and
## seeds, normalised levels, the locked team, runs ending and completing,
## records, milestones and Vesper, the save, and that teams of different
## shapes can finish the whole gauntlet. Called from sim_checks.gd, which owns
## PASS/FAIL and the random team builder.

const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const Crucible = preload("res://scripts/core/crucible.gd")

var checks: Object
var catalog: Catalog


func _init(runner: Object, data: Catalog) -> void:
	checks = runner
	catalog = data


func run() -> void:
	_check_rules()
	_check_runs()
	_check_rewards()
	_check_save()
	_check_vesper()
	_check_variety()


## [spirit, frame, arms, legs, material, sigil, cell]
static func _team(rows: Array) -> Array:
	return rows.map(func(r): return {"spirit": r[0], "frame": r[1], "arms": r[2], "legs": r[3], "material": r[4],
		"sigil": r[5], "row": String(r[6]).get_slice(":", 0), "lane": String(r[6]).get_slice(":", 1).to_int()})


## The design goal: one team must answer every test, and teams of quite
## different shapes can. A team built around many small burning blows still
## falls where blows are punished.
func _check_variety() -> void:
	var finishers: Dictionary = {
		"guardians and casters": _team([["odo", "bulwark", "aegis", "tower", "stone", "stoneskin", "front:1"],
			["briar", "bulwark", "shield", "tower", "wood", "warden_seal", "front:0"],
			["rime_ogre", "colossus", "shield", "treads", "stone", "guard_bell", "front:2"],
			["volta", "conduit", "storm_staff", "stilts", "fulgurite", "tempest_eye", "back:1"],
			["neris", "conduit", "lantern", "pillar", "ice", "mending", "back:0"],
			["sefa", "conduit", "cannon", "stilts", "crystal", "mire_lantern", "back:2"]]),
		"nature sustain": _team([["briar", "bulwark", "shield", "tower", "wood", "thorn_crest", "front:1"],
			["root_warden", "colossus", "aegis", "treads", "wood", "warden_seal", "front:0"],
			["fen_mother", "bulwark", "flail", "pillar", "bogwood", "mire_lantern", "front:2"],
			["moss_wisp", "conduit", "lantern", "pillar", "wood", "mending", "back:1"],
			["reed_sprite", "conduit", "storm_staff", "stilts", "wood", "tempest_eye", "back:0"],
			["neris", "conduit", "cannon", "stilts", "ice", "hex_eye", "back:2"]]),
		"lightning skirmishers": _team([["thunder_drake", "bulwark", "aegis", "tower", "bronze", "guard_bell", "front:1"],
			["storm_hawk", "strider", "twin_blades", "spider", "bronze", "hunters_brand", "front:0"],
			["gale_kite", "strider", "spear", "skates", "crystal", "war_drum", "front:2"],
			["volta", "conduit", "storm_staff", "stilts", "fulgurite", "tempest_eye", "back:1"],
			["spark_newt", "conduit", "cannon", "pillar", "fulgurite", "surge_lens", "back:0"],
			["volt_shade", "strider", "bow", "spider", "bronze", "storm_coil", "back:2"]]),
	}
	var steps: int = int(catalog.crucible.encounters_per_run) + 1
	var short: Array = finishers.keys().filter(func(name): return gauntlet(finishers[name], "classic", "adept", 0) != steps)
	_check("teams of different shapes finish the Classic Royale", short.is_empty(), str(short))
	var brawlers: Array = _team([["pyra", "strider", "spear", "pillar", "wood", "kiln_heart", "front:1"],
		["kiln_tyrant", "colossus", "flail", "treads", "obsidian", "thorn_crest", "front:0"],
		["ash_hound", "strider", "twin_blades", "spider", "obsidian", "ember_sigil", "front:2"],
		["cinder_mote", "conduit", "cannon", "stilts", "wood", "hunters_brand", "back:1"],
		["moss_wisp", "conduit", "lantern", "pillar", "bogwood", "mending", "back:0"],
		["slag_brute", "bulwark", "aegis", "tower", "stone", "cleansing_charm", "back:2"]])
	var bellows: int = catalog.crucible.classic.encounters.find("bellows")
	_check("a team of many small burning blows falls at the Bellows", gauntlet(brawlers, "classic", "adept", 0) == bellows)


func _check(name: String, ok: bool, detail: String = "") -> void:
	checks._check(name, ok, detail)


## A player past the finale with every part, every spirit and six golems.
func veteran() -> Progression:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	for kind in Catalog.PART_KINDS:
		progression.unlocks[kind] = catalog.part_order[kind].duplicate()
	for id in catalog.player_spirit_ids:
		if not progression.spirits.has(id):
			progression.spirits[id] = progression._fresh_spirit(12)
	progression.cleared = catalog.stages.keys()
	progression.cores = int(catalog.num("team_size")) - progression.team.size()
	while progression.build_golem():
		pass
	return progression


## Fights the run's current step and applies it; returns the battle's result.
func fight(progression: Progression) -> String:
	var run: Dictionary = progression.crucible.run
	var outcome: Dictionary = BattleSim.new().run(catalog, Crucible.player_team(catalog, run),
		Crucible.enemy_team(catalog, progression.crucible.step(), run.tier), Crucible.battle_seed(catalog, run, int(run.next)))
	progression.apply_crucible(outcome.result)
	return outcome.result


## How far `team` gets through a mode and tier: steps won (all of them is a completion).
func gauntlet(team: Array, mode: String, tier: String, seed: int) -> int:
	var progression := veteran()
	progression.team = team.duplicate(true)
	progression.crucible.milestones = catalog.crucible_index.milestones.keys()
	progression.start_crucible(mode, tier, seed)
	var won: int = 0
	while not progression.crucible.run.is_empty():
		if fight(progression) != "win":
			break
		won += 1
	return won


func _check_rules() -> void:
	var classic: Array = Crucible.sequence(catalog, "classic", 0)
	var per_run: int = int(catalog.crucible.encounters_per_run)
	_check("a Classic Royale is six encounters and a final", classic.size() == per_run + 1 and per_run == 6
		and catalog.crucible_encounters[classic[-1].encounter].final)
	var tests: Array = []
	for step in classic.slice(0, per_run):
		var test: String = catalog.crucible_encounters[step.encounter].test
		if not test in tests:
			tests.append(test)
	_check("each Classic encounter tests something different", tests.size() == per_run, str(tests))
	var first: Array = Crucible.sequence(catalog, "shifting", 4242)
	_check("a Shifting seed always names the same gauntlet", JSON.stringify(first) == JSON.stringify(Crucible.sequence(catalog, "shifting", 4242)))
	var shapes: Dictionary = {}
	for seed in range(1, 41):
		var steps: Array = Crucible.sequence(catalog, "shifting", seed)
		shapes[JSON.stringify(steps)] = true
		var ids: Array = steps.map(func(s): return s.encounter)
		if ids.size() != per_run + 1 or not catalog.crucible_encounters[ids[-1]].final:
			shapes.clear()
			break
	_check("Shifting seeds vary the order, the variants and the final", shapes.size() >= 35, "%d distinct of 40" % shapes.size())
	var tier: Dictionary = catalog.crucible_index.tiers.adept
	var enemies: Array = Crucible.enemy_team(catalog, classic[0], "adept")
	var offsets: Array = catalog.crucible_encounters[classic[0].encounter].variants[0].map(func(e): return int(e.offset))
	_check("enemy levels are the tier's level plus their offsets", range(enemies.size()).all(func(i):
		return int(enemies[i].level) == int(tier.level) + int(tier.enemy_bonus) + offsets[i]))
	var progression := veteran()
	progression.spirits[progression.team[0].spirit].level = 3
	progression.spirits[progression.team[1].spirit].level = 40
	progression.start_crucible("classic", "adept", 0)
	var levels: Array = Crucible.player_team(catalog, progression.crucible.run).map(func(g): return int(g.level))
	_check("every golem of yours fights at the tier's level", levels.all(func(l): return l == int(tier.level)), str(levels))


func _check_runs() -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	_check("the Crucible waits for the Storm Crown", not progression.crucible_open()
		and not progression.start_crucible("classic", "adept", 0))
	progression = veteran()
	_check("the Master tier waits for a Classic Royale", not progression.start_crucible("classic", "master", 0))
	var levels_before: String = JSON.stringify(progression.spirits)
	_check("a run begins with the laboratory team", progression.start_crucible("classic", "adept", 0)
		and progression.crucible.run.team.size() == 6 and progression.crucible.record("classic", "adept").runs == 1)
	_check("only one run at a time", not progression.start_crucible("shifting", "adept", 7))
	var locked: String = JSON.stringify(progression.crucible.run.team)
	progression.set_slot(0, "arms", "bow")
	progression.set_slot(0, "cell", "back:2")
	_check("laboratory changes leave the locked team alone", JSON.stringify(progression.crucible.run.team) == locked)
	var first: Dictionary = progression.crucible.step()
	var a: Dictionary = BattleSim.new().run(catalog, Crucible.player_team(catalog, progression.crucible.run),
		Crucible.enemy_team(catalog, first, "adept"), Crucible.battle_seed(catalog, progression.crucible.run, 0))
	var b: Dictionary = BattleSim.new().run(catalog, Crucible.player_team(catalog, progression.crucible.run),
		Crucible.enemy_team(catalog, first, "adept"), Crucible.battle_seed(catalog, progression.crucible.run, 0))
	_check("a Crucible battle is deterministic", JSON.stringify(a.events) == JSON.stringify(b.events))
	var report: Dictionary = progression.apply_crucible("win")
	_check("a win moves on to the next encounter", report.won and not report.ended and progression.crucible.run.next == 1
		and progression.crucible.record("classic", "adept").best == 1 and report.new_best)
	report = progression.apply_crucible("timeout")
	_check("a defeat or timeout ends the run", report.ended and not report.complete and progression.crucible.run.is_empty()
		and progression.crucible.last.fell_at == 1)
	_check("the furthest encounter reached is kept", progression.crucible.record("classic", "adept").best == 1)
	_check("a Crucible run gives no XP and takes nothing", JSON.stringify(progression.spirits) == levels_before)
	_check("a failed run starts again from the first encounter", progression.start_crucible("classic", "adept", 0)
		and progression.crucible.run.next == 0)
	progression.crucible.abandon()
	_check("abandoning ends the run where it stood", progression.crucible.run.is_empty() and progression.crucible.last.fell_at == 0
		and progression.crucible.record("classic", "adept").runs == 2)


## Completing a Royale: the record, the winning team, milestones, Vesper,
## the titles and finishes, and the Master tier.
func _check_rewards() -> void:
	var progression := veteran()
	progression.spirits.erase("vesper")
	progression.start_crucible("classic", "adept", 0)
	var reports: Array = []
	while not progression.crucible.run.is_empty():
		reports.append(progression.apply_crucible("win"))
	var last: Dictionary = reports[-1]
	var record: Dictionary = progression.crucible.record("classic", "adept")
	_check("winning the final completes the Royale", last.complete and record.completions == 1 and record.best == 7
		and record.teams.size() == 1 and record.teams[0].golems.size() == 6)
	_check("three wins meet Into the Fire", reports[2].milestones == ["crucible_initiate"])
	_check("a Classic Royale brings Vesper, a title and a finish", "crucible_champion" in last.milestones
		and progression.spirits.has("vesper") and last.rewards.any(func(r): return r.kind == "spirits" and r.id == "vesper")
		and last.rewards.any(func(r): return r.kind == "finishes" and r.id == "champion_gold"))
	_check("a six-golem Royale does not meet Lean Royale", not "crucible_lean" in progression.crucible.milestones)
	_check("the Master tier opens", progression.start_crucible("classic", "master", 0))
	progression.crucible.abandon()
	_check("an earned finish can be worn, an unearned one cannot", progression.set_slot(0, "finish", "champion_gold")
		and not progression.set_slot(0, "finish", "lean_iron") and progression.resolve_slot(0).finish == "champion_gold")
	_check("an earned title can be chosen", progression.set_crucible_title("champion") and not progression.set_crucible_title("master"))
	progression.team = progression.team.slice(0, 4)
	progression.cores = 0
	progression.start_crucible("shifting", "adept", 99)
	while not progression.crucible.run.is_empty():
		progression.apply_crucible("win")
	_check("four golems through a Shifting Royale meet Lean Royale and Shifting Sands",
		"crucible_lean" in progression.crucible.milestones and "crucible_shifting" in progression.crucible.milestones)


func _check_save() -> void:
	var progression := veteran()
	progression.save_enabled = true
	progression.save_path = "user://crucible_checks_save.json"
	progression.start_crucible("shifting", "adept", 31337)
	progression.apply_crucible("win")
	progression.set_slot(1, "arms", "lantern")
	_check("a run in progress saves", progression.save_game(), progression.last_error)
	var reloaded := Progression.new(catalog)
	reloaded.save_path = progression.save_path
	_check("a run in progress reads back", reloaded.load_game()
		and JSON.stringify(reloaded.to_dict()) == JSON.stringify(progression.to_dict()))
	var tampered: Dictionary = progression.to_dict().duplicate(true)
	tampered.crucible.run.sequence[0].encounter = "storm_reborn"
	_check("a save whose run does not match its seed is refused", not progression.valid(tampered))
	tampered = progression.to_dict().duplicate(true)
	tampered.team[0]["finish"] = "master_obsidian"
	_check("a save wearing an unearned finish is refused", not progression.valid(tampered))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progression.save_path + suffix)
	var old: Dictionary = progression.to_dict().duplicate(true)
	old.schema = 7
	old.erase("crucible")
	for id in old.spirits:
		old.spirits[id].erase("last_build")
	for loadout in old.team:
		loadout.erase("finish")
	var migrated: Variant = progression.migrate(old)
	_check("schema 7 saves migrate with an empty Crucible", progression.valid(migrated) and migrated.crucible.run.is_empty()
		and migrated.spirits.values().all(func(s): return s.last_build == ""))


func _check_vesper() -> void:
	var vesper: Dictionary = catalog.spirit("vesper")
	var looks: Dictionary = {}
	for frame in catalog.part_order.frames:
		var golem: Dictionary = Builds.resolve(catalog, {"spirit": "vesper", "frame": frame, "arms": "hammer", "legs": "pillar",
			"material": "stone", "sigil": "", "row": "front", "lane": 1}, 10, {})
		looks[frame] = golem.breakdown.any(func(source): return source.label.begins_with("Adaptation"))
	_check("Vesper adapts to every frame", looks.values().all(func(v): return v), str(looks))
	var reacts: Array = catalog.part_order.materials.filter(func(id): return catalog.reaction(id, "echo").is_empty())
	_check("Vesper takes something from every material", reacts.is_empty(), str(reacts))
	var loadout: Dictionary = {"spirit": "vesper", "frame": "bulwark", "arms": "hammer", "legs": "pillar", "material": "stone",
		"sigil": "", "row": "front", "lane": 1}
	_check("Restless prefers a changed build", Builds.preference(catalog, vesper, loadout, {"last_build": "x"}).active
		and not Builds.preference(catalog, vesper, loadout, {"last_build": Builds.build_key(loadout)}).active)


## For balance work: each encounter's win rate for random six-golem teams at
## Adept, the parts most over-represented among the wins (what the encounter
## rewards), how far random teams get through the Classic Royale, and how
## often they finish it.
func report() -> void:
	var progression := veteran()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples: int = 300
	var teams: Array = []
	for i in range(samples):
		teams.append(checks._random_team(progression, rng))
	print("Crucible at Adept, %d random six-golem teams with every part:" % samples)
	for entry in catalog.crucible.encounters + catalog.crucible.finals:
		for variant in range(entry.variants.size()):
			_encounter_report(entry, variant, teams)
	# Fought one by one (health resets between encounters anyway): how many of
	# the seven each team would win. Tests that ask different things spread
	# this out; tests that only ask for raw strength pile it at 0 and 7.
	var spread: Array = []
	spread.resize(8)
	spread.fill(0)
	var reached: Dictionary = {}
	var winners: Array = []
	for team in teams:
		var resolved: Array = team.map(func(l): return Builds.resolve(catalog, l, int(catalog.crucible_index.tiers.adept.level), {}))
		var count: int = 0
		var run: Dictionary = {"mode": "classic", "seed": 0, "sequence": Crucible.sequence(catalog, "classic", 0)}
		for index in range(run.sequence.size()):
			var outcome: Dictionary = BattleSim.new().run(catalog, resolved, Crucible.enemy_team(catalog, run.sequence[index], "adept"),
				Crucible.battle_seed(catalog, run, index))
			count += 1 if outcome.result == "win" else 0
		spread[count] += 1
		var won: int = gauntlet(team, "classic", "adept", 0)
		reached[won] = int(reached.get(won, 0)) + 1
		if won == run.sequence.size():
			winners.append(team)
	print("  Classic Royale, of seven fought one by one, random teams win: %s" % str(spread))
	print("  Classic Royale run, encounters won before falling: %s" % str(reached))
	for team in winners.slice(0, 6):
		print("    finished: %s" % ", ".join(team.map(func(l): return "%s %s/%s/%s %s %s" % [l.spirit, l.frame, l.arms, l.legs,
			l.sigil, Catalog.cell_of(l)])))


func _encounter_report(entry: Dictionary, variant: int, teams: Array) -> void:
	var enemies: Array = Crucible.enemy_team(catalog, {"encounter": entry.id, "variant": variant}, "adept")
	var wins: int = 0
	var timeouts: int = 0
	var with_part: Dictionary = {}
	for team in teams:
		var resolved: Array = team.map(func(l): return Builds.resolve(catalog, l, int(catalog.crucible_index.tiers.adept.level), {}))
		var outcome: Dictionary = BattleSim.new().run(catalog, resolved, enemies, int(entry.seed) + variant)
		var won: bool = outcome.result == "win"
		wins += 1 if won else 0
		timeouts += 1 if outcome.result == "timeout" else 0
		var parts: Dictionary = {}
		for loadout in team:
			for key in ["arms", "legs", "sigil", "frame"]:
				if not String(loadout[key]).is_empty():
					parts[loadout[key]] = true
		for part in parts:
			var tally: Array = with_part.get(part, [0, 0])
			with_part[part] = [tally[0] + (1 if won else 0), tally[1] + 1]
	var rate: float = float(wins) / teams.size()
	var lifts: Array = []
	for part in with_part:
		if with_part[part][1] >= 20:
			lifts.append([part, float(with_part[part][0]) / with_part[part][1] - rate])
	lifts.sort_custom(func(x, y): return x[1] > y[1])
	var best: Array = lifts.slice(0, 4).map(func(l): return "%s %+.0f" % [l[0], 100.0 * l[1]])
	var worst: Array = lifts.slice(lifts.size() - 3).map(func(l): return "%s %+.0f" % [l[0], 100.0 * l[1]])
	print("  %-24s v%d [%s] win %5.1f%%  timeouts %d  helps: %s  hurts: %s" % [entry.name, variant, entry.test, 100.0 * rate,
		timeouts, ", ".join(best), ", ".join(worst)])
