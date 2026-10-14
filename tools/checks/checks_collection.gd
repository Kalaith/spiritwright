extends "res://tools/checks/check_module.gd"
## The long game: New Game+, the playthrough record, recruits, challenges,
## region masteries and feats, and the challenge part of the balance report.

const Challenges = preload("res://scripts/core/challenges.gd")
const SpiritPortrait = preload("res://scripts/ui/spirit_portrait.gd")
## Conforming teams tried per challenge and level band in the balance report.
const CHALLENGE_SAMPLES: int = 60


func check_new_game_plus():
	var progression := _fresh()
	_check("the level cap leaves room past the campaign", int(catalog.num("level_cap")) == 50)
	_check("a new game starts the first playthrough with a clean record", progression.cycle == 0
		and progression.run.values().all(func(count): return count == 0))
	_check("New Game+ waits for the finale", not progression.start_new_game_plus())
	progression.apply_battle(catalog.stages["ruins_gate"], "loss")
	_check("a defeat counts the whole team as fallen", progression.run.falls == progression.team.size()
		and progression.run.losses == 1)
	_clear_all(progression)
	var team_before: String = JSON.stringify(progression.team)
	var spirits_before: Array = progression.spirits.keys()
	var gate_xp: int = progression.stage_xp(catalog.stages["ruins_gate"], 10, 1.0)
	_check("the finale completes the playthrough", progression.campaign_complete())
	_check("New Game+ begins after the finale", progression.start_new_game_plus() and progression.cycle == 1
		and progression.cleared.is_empty() and progression.run.falls == 0)
	_check("New Game+ keeps the spirits and golems", progression.spirits.keys() == spirits_before
		and JSON.stringify(progression.team) == team_before)
	var step: int = int(catalog.num("new_game_plus.level_step"))
	var gate: Array = progression.enemy_team(catalog.stages["ruins_gate"])
	_check("New Game+ wild spirits are stronger", int(gate[0].level) == int(catalog.stages["ruins_gate"].enemies[0].level) + step,
		str(gate[0].level))
	_check("stronger enemies are worth more XP", progression.stage_xp(catalog.stages["ruins_gate"], 10, 1.0) > gate_xp)
	progression.cycle = 10
	_check("enemy levels stop at the level cap", progression.enemy_team(catalog.stages[catalog.finale_id]).all(
		func(golem): return int(golem.level) == int(catalog.num("level_cap"))))
	progression.cycle = 1
	var cores: int = progression.cores
	progression.apply_battle(catalog.stages["ruins_gate"], "win")
	_check("a full team gains no extra golem cores", progression.cores == cores and progression.valid(progression.to_dict()))
	var old: Dictionary = progression.to_dict()
	old.schema = 5
	old.erase("cycle")
	old.erase("run")
	var migrated: Variant = progression.migrate(old)
	_check("schema 5 saves are the first playthrough with a spoiled record", progression.valid(migrated)
		and migrated.cycle == 0 and migrated.run.falls > 0, JSON.stringify(migrated.get("run", {})))
	return verdict()


## Every spirit can join exactly one way, and the collection splits about
## 60% from playing, 30% from challenges and 10% from extreme feats.
func check_collection():
	var found: Dictionary = Challenges.spirit_sources(catalog)
	var stray: Array = catalog.player_spirit_ids.filter(func(id): return found.get(id, []).size() != 1)
	_check("every spirit joins in exactly one way", stray.is_empty(), str(stray))
	var tiers: Dictionary = {"play": 0, "challenge": 0, "extreme": 0}
	for id in found:
		tiers[found[id][0].tier] += 1
	var total: float = float(catalog.player_spirit_ids.size())
	_check("the collection is about 60% play, 30% challenges, 10% extreme",
		absf(tiers.play / total - 0.6) < 0.05 and absf(tiers.challenge / total - 0.3) < 0.05
		and absf(tiers.extreme / total - 0.1) < 0.05, str(tiers))
	var progression := _fresh()
	var stage: Dictionary = catalog.stages["ruins_heart"]
	var wild: Array = progression.enemy_team(stage)
	progression.spirits["root_warden"] = progression._fresh_spirit(int(wild[0].level))
	progression.set_slot(0, "spirit", "root_warden")
	_check("a wild spirit fights without its awakening", not wild[0].awakened and not wild[0].preference.active)
	_check("the same spirit awakens once recruited", progression.resolve_slot(0).awakened)
	var faceless: Array = catalog.spirits.keys().filter(func(id): return not SpiritPortrait.has_portrait(id))
	_check("every spirit has a portrait for its journal", faceless.is_empty(), str(faceless))
	return verdict()


func check_challenges():
	var golem := func(element: String, row: String, alive: bool = true, kind: String = "physical") -> Dictionary:
		return {"spirit": "pyra", "element": element, "row": row, "alive": alive, "material": "stone",
			"arms": "hammer", "attack": {"kind": kind}, "sigil": "", "level": 5, "frame": "strider", "legs": "pillar"}
	var team: Array = [golem.call("fire", "front"), golem.call("water", "back", false)]
	_check("no_falls sees a fallen golem", not Challenges.met({"no_falls": true}, team, 0))
	_check("front_stands ignores the back row", Challenges.met({"front_stands": true}, team, 0)
		and not Challenges.met({"front_stands": true}, [golem.call("earth", "front", false)], 0))
	_check("forbid_elements and only_elements read each golem's element",
		not Challenges.met({"forbid_elements": ["fire"]}, team, 0) and Challenges.met({"only_elements": ["fire", "water"]}, team, 0))
	_check("max_golems counts the team", Challenges.met({"max_golems": 2}, team, 0) and not Challenges.met({"max_golems": 1}, team, 0))
	_check("require needs one golem matching every field", Challenges.met({"require": {"element": "water", "row": "back"}}, team, 0)
		and not Challenges.met({"require": {"element": "water", "row": "front"}}, team, 0))
	_check("attack_kind, empty_row, max_level and min_cycle", not Challenges.met({"attack_kind": "magical"}, team, 0)
		and not Challenges.met({"empty_row": "back"}, team, 0) and Challenges.met({"max_level": 5}, team, 0)
		and not Challenges.met({"min_cycle": 1}, team, 0) and Challenges.met({"min_cycle": 1}, team, 1))
	_check("the catalog rejects an unknown challenge rule", not Challenges.problems(catalog, "probe",
		{"id": "x", "name": "x", "text": "x", "rules": {"fly": true}}, false).is_empty())
	_check("a feat cannot use a battle-only rule", not Challenges.problems(catalog, "probe",
		{"id": "x", "name": "x", "text": "x", "rules": {"front_stands": true}}, true).is_empty())

	# Cold Hearth on the Broken Stair: win without a Fire spirit and the Cinder Mote joins.
	var progression := _fresh()
	for id in ["ruins_gate", "ruins_court"]:
		progression.apply_battle(catalog.stages[id], "win")
		progression.build_golem()
	var stage: Dictionary = catalog.stages["ruins_stair"]
	var fiery: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), int(stage.seed))
	var report: Dictionary = progression.apply_battle(stage, fiery.result, fiery.units)
	_check("a team with Pyra does not meet Cold Hearth", not "stair_cold" in report.challenges
		and not progression.spirits.has("cinder_mote"))
	for slot in range(progression.team.size()):
		if progression.team[slot].spirit == "pyra":
			progression.set_slot(slot, "spirit", "rubble_imp")
	for id in progression.spirits:
		progression.spirits[id].level = 5
	var cold: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), int(stage.seed))
	report = progression.apply_battle(stage, cold.result, cold.units)
	_check("winning without Fire meets Cold Hearth and the Cinder Mote joins", cold.result == "win"
		and "stair_cold" in report.challenges and progression.spirits.has("cinder_mote")
		and report.rewards.any(func(r): return r.kind == "spirits" and r.id == "cinder_mote"), cold.result)
	report = progression.apply_battle(stage, cold.result, cold.units)
	_check("a met challenge is not met twice", report.challenges.is_empty() and progression.valid(progression.to_dict()))
	return verdict()


## A region is mastered, and its sigil earned, by meeting every challenge on its stages.
func check_masteries():
	var sigils: Array = []
	for region in catalog.regions():
		sigils.append_array(region.get("mastery", {}).get("rewards", {}).get("sigils", []))
	var elsewhere: Array = catalog.campaign.start.unlocks.get("sigils", []).duplicate()
	for entry in catalog.stages.values() + catalog.challenges.values() + catalog.feats.values():
		elsewhere.append_array(entry.get("rewards", {}).get("sigils", []))
	_check("every region's mastery earns its own sigil, found nowhere else",
		sigils.size() == catalog.regions().size() and sigils.all(func(id): return sigils.count(id) == 1 and not id in elsewhere),
		str(sigils))

	var progression := _fresh()
	var ruins: Dictionary = catalog.regions()[0]
	var ids: Array = Challenges.region_ids(ruins)
	progression.challenges = ids.filter(func(id): return id != "gate_cold")
	var golem: Dictionary = {"side": 0, "spirit": "neris", "element": "water", "row": "front", "alive": true}
	var report: Dictionary = progression.apply_battle(catalog.stages["ruins_court"], "win", [golem])
	_check("a region with a challenge still open is not mastered", report.masteries.is_empty()
		and not "warden_seal" in progression.unlocks.sigils)
	report = progression.apply_battle(catalog.stages["ruins_gate"], "win", [golem])
	_check("meeting a region's last challenge masters it and earns its sigil", report.masteries == [ruins.id]
		and "warden_seal" in progression.unlocks.sigils
		and report.rewards.any(func(r): return r.kind == "sigils" and r.id == "warden_seal"), str(report.masteries))
	report = progression.apply_battle(catalog.stages["ruins_gate"], "win", [golem])
	_check("a region is mastered once", report.masteries.is_empty())
	var saved: Dictionary = progression.to_dict()
	saved.unlocks.sigils.erase("warden_seal")
	progression._apply(saved)
	_check("a save that met every challenge before masteries existed gets the sigil on load",
		"warden_seal" in progression.unlocks.sigils and progression.valid(progression.to_dict()))

	var imps: Array = [0, 2].map(func(lane): return ["rubble_imp", 2,
		_loadout("rubble_imp", "strider", "hammer", "pillar", "front", "stone", lane)])
	var duel := func(sigil: String, spirit: String = "pyra", arms: String = "hammer", row: String = "front") -> Dictionary:
		return _duel([[spirit, 12, _loadout(spirit, "strider", arms, "pillar", row, "stone", 1, sigil)]], imps)
	var seal: Dictionary = duel.call("warden_seal", "odo", "shield")
	_check("a warden's seal wards the team at the start", _has(seal, {"type": "ward", "unit": "a0", "cause": "Warden's Seal"}))
	var lantern: Dictionary = duel.call("mire_lantern")
	_check("a mire lantern soaks the target and arcs to another enemy",
		_has(lantern, {"type": "status", "status": "soaked", "cause": "Mire Lantern"}) and _has(lantern, {"type": "chain", "unit": "a0"}))
	var kiln: Dictionary = duel.call("kiln_heart", "odo")
	_check("a kiln heart burns deep and a kill hurries the team",
		_has(kiln, {"type": "status", "status": "burn", "value": 2, "cause": "Kiln Heart"})
		and _has(kiln, {"type": "haste", "unit": "a0", "cause": "Kiln Heart"}))
	var rime: Dictionary = duel.call("rime_crown")
	_check("a rime crown slows every enemy at the start", _has(rime, {"type": "slow", "unit": "b0", "cause": "Rime Crown"})
		and _has(rime, {"type": "slow", "unit": "b1", "cause": "Rime Crown"}))
	var tempest: Dictionary = duel.call("tempest_eye", "volta", "cannon", "back")
	_check("a tempest eye strikes every enemy and exposes its target", _said(tempest, "damage", "Tempest Eye")
		and _has(tempest, {"type": "status", "status": "expose", "cause": "Tempest Eye"}))
	return verdict()


## Feats are judged once every stage of a playthrough is cleared.
func check_feats():
	var progression := _fresh()
	var stages: Array = catalog.stages.values()
	for stage in stages.slice(0, stages.size() - 1):
		progression.apply_battle(stage, "win")
		while progression.build_golem():
			pass
	_check("no feat before the playthrough is complete", progression.feats.is_empty())
	var report: Dictionary = progression.apply_battle(stages[-1], "win")
	_check("a playthrough with no golem falling earns Unbroken and the Storm Sovereign",
		"feat_unbroken" in report.feats and progression.spirits.has("storm_sovereign"), str(report.feats))
	_check("a full team does not earn Skeleton Crew", not "feat_skeleton" in progression.feats)
	_check("The Second Road waits for New Game+", not "feat_second_road" in progression.feats)
	progression.start_new_game_plus()
	progression.apply_battle(stages[0], "loss")
	for stage in stages:
		progression.apply_battle(stage, "win")
	_check("a fall spoils Flawless Road but not the New Game+ feat", "feat_second_road" in progression.feats
		and progression.run.falls > 0 and progression.valid(progression.to_dict()))

	var spoiler := _fresh()
	var lost: Dictionary = spoiler.apply_battle(stages[0], "loss")
	_check("a defeat puts Unbroken and Flawless Road out of reach for the playthrough",
		"feat_unbroken" in lost.spoiled and "feat_flawless" in lost.spoiled and not "feat_skeleton" in lost.spoiled,
		str(lost.spoiled))

	var crew := _fresh()
	for stage in stages:
		crew.apply_battle(stage, "win")
		if crew.team.size() < 3:
			crew.build_golem()
	_check("three golems or fewer all the way earns Skeleton Crew and the Crag Sovereign",
		"feat_skeleton" in crew.feats and crew.spirits.has("crag_sovereign"), str(crew.feats))
	var old: Dictionary = crew.to_dict()
	old.schema = 6
	old.erase("challenges")
	old.erase("feats")
	_check("schema 6 saves migrate with an empty Codex", crew.valid(crew.migrate(old)))
	return verdict()


## Wins every stage in campaign order, building golems as cores arrive.
func _clear_all(progression: Progression) -> void:
	for stage in catalog.stages.values():
		progression.apply_battle(stage, "win")
		while progression.build_golem():
			pass


## For the balance report: how often random builds that keep a challenge's
## composition rules (elements, arms, materials, rows, sigils, size, require)
## win and meet it, on a replay at the team's levels now and ten levels on
## (and 25 on, for an extreme challenge). 0%
## at both flags a challenge to look at; "no parts" means nothing unlocked yet fits.
func challenge_report(progression: Progression, stage: Dictionary, rng: RandomNumberGenerator) -> void:
	var team: Array = progression.team
	var enemies: Array = progression.enemy_team(stage)
	var samples: int = CHALLENGE_SAMPLES
	for challenge in stage.get("challenges", []):
		var rates: Array = []
		var bonuses: Array = [0, 10, 25] if challenge.get("extreme", false) else [0, 10]
		for bonus in bonuses:
			var levels: Dictionary = {}
			for id in progression.spirits:
				levels[id] = progression.spirits[id].level
				progression.spirits[id].level = min(int(catalog.num("level_cap")), levels[id] + bonus)
			var met: int = 0
			var possible: bool = true
			for i in range(samples):
				progression.team = team
				var trial: Array = _conforming_team(progression, challenge.rules, rng)
				if trial.is_empty():
					possible = false
					break
				progression.team = trial
				var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), enemies, int(stage.seed))
				if outcome.result == "win" and Challenges.met(challenge.rules,
						outcome.units.filter(func(u): return u.side == 0), progression.cycle):
					met += 1
			for id in levels:
				progression.spirits[id].level = levels[id]
			rates.append("%5.1f%%" % (100.0 * met / samples) if possible else "no parts")
		var reward: String = ", ".join(challenge.get("rewards", {}).get("spirits", []))
		print("    challenge %-26s %s now, %s ten levels on%s%s" % [challenge.name, rates[0], rates[1],
			("  EXTREME, %s 25 levels on" % rates[2]) if rates.size() > 2 else "",
			("  recruits " + reward) if not reward.is_empty() else ""])
	progression.team = team


## A random team from what is unlocked that keeps every composition rule, or
## [] when nothing unlocked can.
func _conforming_team(progression: Progression, rules: Dictionary, rng: RandomNumberGenerator) -> Array:
	var require: Dictionary = rules.get("require", {})
	var fits := func(field: String, id: String) -> bool:
		match field:
			"spirit":
				var element: String = catalog.spirit(id).element
				return not element in rules.get("forbid_elements", []) 					and (not rules.has("only_elements") or element in rules.only_elements)
			"arms":
				return not id in rules.get("forbid_arms", []) 					and (not rules.has("attack_kind") or catalog.part("arms", id).attack.kind == rules.attack_kind)
			"material":
				return not rules.has("only_materials") or id in rules.only_materials
		return true
	var pools: Dictionary = {"spirit": _shuffled(progression.spirits.keys().filter(func(id): return fits.call("spirit", id)), rng)}
	for field in ["frame", "arms", "legs", "material"]:
		var kind: String = {"frame": "frames", "material": "materials"}.get(field, field)
		pools[field] = progression.unlocks[kind].filter(func(id): return fits.call(field, id))
	pools["sigil"] = [""] if rules.get("no_sigils", false) else [""] + progression.unlocks.sigils
	var cells: Array = _shuffled(Progression.BUILD_CELLS.filter(func(c): return not c.begins_with(String(rules.get("empty_row", "-")) + ":")), rng)
	# The golem that answers "require" goes first: its spirit and cell are picked to match.
	if require.has("spirit"):
		pools.spirit = [require.spirit] + pools.spirit.filter(func(id): return id != require.spirit)
	if require.has("element"):
		var matching: Array = pools.spirit.filter(func(id): return catalog.spirit(id).element == require.element)
		pools.spirit = matching.slice(0, 1) + pools.spirit.filter(func(id): return not id in matching.slice(0, 1))
	if require.has("row"):
		cells.sort_custom(func(x, y): return x.begins_with(require.row) and not y.begins_with(require.row))
	var size: int = mini(mini(progression.team.size(), int(rules.get("max_golems", 6))), mini(pools.spirit.size(), cells.size()))
	if size == 0 or pools.values().any(func(pool): return pool.is_empty()):
		return []
	if (require.has("spirit") and not progression.spirits.has(require.spirit)) 			or (require.has("element") and catalog.spirit(pools.spirit[0]).element != require.element):
		return []
	var built: Array = []
	for slot in range(size):
		var loadout: Dictionary = {"spirit": pools.spirit[slot], "row": String(cells[slot]).get_slice(":", 0),
			"lane": String(cells[slot]).get_slice(":", 1).to_int()}
		for field in ["frame", "arms", "legs", "material", "sigil"]:
			var options: Array = pools[field]
			loadout[field] = require[field] if slot == 0 and require.has(field) else Det.pick(rng, options)
		built.append(loadout)
	if require.has("row") and built[0].row != require.row:
		return []
	for field in ["frame", "arms", "legs", "material", "sigil"]:
		if require.has(field) and not require[field] in pools[field]:
			return []
	return built


func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var copy: Array = items.duplicate()
	Det.shuffle(rng, copy)
	return copy
