extends "res://tools/checks/check_module.gd"
## The campaign's balance report (`-- --report`): every stage in campaign
## order, the win rate of random legal builds from what is unlocked, then the
## best one fights and the campaign moves on.

const CollectionChecks = preload("res://tools/checks/checks_collection.gd")


## Plays the campaign in order. For each stage it samples random legal builds
## from what is unlocked, prints the win rate, then fights with the best one.
func run() -> void:
	var progression := Progression.new(catalog)
	progression.save_enabled = false
	progression.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var collection := CollectionChecks.new()
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
