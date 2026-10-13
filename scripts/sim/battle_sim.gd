extends RefCounted
## Deterministic auto-battle. Given the same resolved teams and seed it always
## produces the same event log; all randomness comes from `rng`. It never
## touches the scene tree. The battle view replays `events` afterwards.
##
## Board: each side stands on three lanes (0-2) of two rows, front and back;
## where a golem stands decides who it can reach and who reaches it.
##
## Cadence: every tick each golem's gauge fills by (base + SPD); at the
## threshold it acts and pays its arms' action cost back out of the gauge.

const Catalog = preload("res://scripts/core/catalog.gd")
const SIDES: Array[String] = ["a", "b"]

var catalog: Catalog
var rng := RandomNumberGenerator.new()
var units: Array = []
var events: Array = []
var tick: int = 0
var result: String = ""


## Returns {result, ticks, events, units}. result is "win" when team_a wins,
## "loss" when team_b wins, "timeout" when nobody falls in time.
func run(data: Catalog, team_a: Array, team_b: Array, seed: int) -> Dictionary:
	catalog = data
	rng.seed = seed
	units.clear()
	events.clear()
	result = ""
	_add_team(team_a, 0)
	_add_team(team_b, 1)
	for unit in units:
		_fire(unit, "battle_start", {})
	var threshold: float = catalog.num("battle.gauge_threshold")
	var max_ticks: int = int(catalog.num("battle.max_ticks"))
	tick = 0
	while result.is_empty() and tick < max_ticks:
		tick += 1
		for unit in units:
			if unit.alive:
				var speed: float = float(unit.stats.spd)
				if unit.soaked > 0:
					speed *= catalog.num("status.soaked_speed_multiplier")
				unit.gauge += catalog.num("battle.gauge_base") + speed
		var ready: Array = units.filter(func(u): return u.alive and u.gauge >= threshold)
		ready.sort_custom(func(x, y): return x.gauge > y.gauge or (x.gauge == y.gauge and x.index < y.index))
		for unit in ready:
			if not result.is_empty():
				break
			if unit.alive:
				unit.gauge -= float(unit.attack.cost)
				_take_turn(unit)
	if result.is_empty():
		result = "timeout"
		_log({"type": "end", "result": result}, "Time runs out. Neither side falls.")
	return {"result": result, "ticks": tick, "events": events, "units": units}


func _add_team(team: Array, side: int) -> void:
	var counts: Dictionary = {}
	for golem in team:
		counts[golem.name] = int(counts.get(golem.name, 0)) + 1
	var seen: Dictionary = {}
	for slot in range(team.size()):
		var golem: Dictionary = team[slot]
		var label: String = golem.name
		if int(counts[golem.name]) > 1:
			seen[golem.name] = int(seen.get(golem.name, 0)) + 1
			label += " " + "ABCDEF"[int(seen[golem.name]) - 1]
		var unit: Dictionary = golem.duplicate(true)
		unit.merge({
			"id": SIDES[side] + str(slot), "index": units.size(), "side": side, "slot": slot,
			"label": label, "hp": int(golem.stats.hp), "max_hp": int(golem.stats.hp), "alive": true,
			"gauge": 0.0, "burn": 0, "soaked": 0, "taunt": 0, "regen": 0, "weaken": 0, "expose": 0, "ward": 0,
			"stunned": false, "hits": 0, "intercept_ready": true, "low_hp_fired": false, "revived": false, "cooldowns": {},
			"dealt": 0, "taken": 0, "healed": 0, "shielded": 0, "triggers": 0, "kills": 0,
		}, true)
		units.append(unit)


func _take_turn(unit: Dictionary) -> void:
	_log({"type": "turn", "unit": unit.id}, "")
	unit.intercept_ready = true
	for key in unit.cooldowns.keys():
		unit.cooldowns[key] = max(0, int(unit.cooldowns[key]) - 1)
	if unit.burn > 0:
		var burn: int = unit.burn * int(catalog.num("status.burn_damage_per_stack"))
		_damage(unit, burn, null, "burn", "%s burns for %d." % [unit.label, burn])
		unit.burn -= 1
		if not unit.alive:
			return
	if unit.regen > 0:
		_heal(unit, int(catalog.num("status.regen_heal")), "Regen")
		unit.regen -= 1
	_fire(unit, "turn_start", {})
	for status in ["soaked", "taunt", "weaken", "expose"]:
		if unit[status] > 0:
			unit[status] -= 1
			if unit[status] == 0:
				_log({"type": "status_end", "unit": unit.id, "status": status}, "")
	if unit.stunned:
		unit.stunned = false
		_log({"type": "stun_skip", "unit": unit.id}, "%s is Stunned and loses its turn." % unit.label)
		return
	var target: Variant = _choose_target(unit)
	if target == null:
		return
	_attack(unit, target)


## Taunt overrides everything; Spider Legs hunt the weakest enemy anywhere.
## Otherwise the arms decide which row they aim at ("front" for blades and
## cannons, "back" for bows lobbed over the line) and the nearest lane in that
## row is struck; a row only falls back to the other once it is empty.
func _choose_target(unit: Dictionary) -> Variant:
	var enemies: Array = units.filter(func(u): return u.alive and u.side != unit.side)
	if enemies.is_empty():
		return null
	var taunting: Array = enemies.filter(func(u): return u.taunt > 0)
	if not taunting.is_empty():
		return _nearest(unit, taunting)
	if unit.reach:
		return _weakest(enemies)
	var aimed: Array = enemies.filter(func(u): return u.row == unit.attack.aim)
	return _nearest(unit, aimed if not aimed.is_empty() else enemies)


## The candidate whose lane is closest to the unit's own; ties go to the lower lane.
func _nearest(unit: Dictionary, candidates: Array) -> Dictionary:
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		var distance: int = abs(int(candidate.lane) - int(unit.lane))
		var best_distance: int = abs(int(best.lane) - int(unit.lane))
		if distance < best_distance or (distance == best_distance and candidate.lane < best.lane):
			best = candidate
	return best


func _weakest(candidates: Array) -> Dictionary:
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if candidate.hp < best.hp:
			best = candidate
	return best


func _attack(unit: Dictionary, target: Dictionary) -> void:
	if target.row == "back":
		var guard: Variant = _guard_for(target)
		if guard != null:
			guard.intercept_ready = false
			_log({"type": "intercept", "unit": guard.id, "protected": target.id},
				"%s steps in front of %s." % [guard.label, target.label])
			target = guard
	_log({"type": "attack", "unit": unit.id, "target": target.id, "range": unit.attack.range},
		"%s attacks %s." % [unit.label, target.label])
	for strike in range(int(unit.attack.get("strikes", 1))):
		if not target.alive or not result.is_empty():
			return
		_strike(unit, target, 1.0, true)


## One blow. `scale` shrinks splash blows; only a main blow counts as a hit
## (stuns, sigils) and splashes onto the target's neighbours in its row.
func _strike(unit: Dictionary, target: Dictionary, scale: float, main: bool) -> void:
	var magical: bool = unit.attack.kind == "magical"
	var power: float = float(unit.attack.power) + float(unit.stats.mag if magical else unit.stats.str)
	var note: String = ""
	# A melee golem in the back row has to reach past its own front line.
	if unit.attack.range == "melee" and unit.row == "back" and not unit.reach:
		power *= catalog.num("battle.back_row_melee_factor")
		note += " (reaching from the back row)"
	# Armour blunts a share of each blow, but a hit always keeps a floor of its power.
	if unit.row == "back" and float(unit.perch) > 0.0:
		power *= 1.0 + float(unit.perch)
		note += " (from the stilts)"
	if float(unit.attack.get("execute", 0.0)) > 0.0 and target.hp * 2 < target.max_hp:
		power *= 1.0 + float(unit.attack.execute)
		note += " (Execute)"
	power *= scale
	var armour: float = float(target.stats.res if magical else target.stats.def) * catalog.num("battle.armour_factor")
	armour *= 1.0 - float(unit.attack.get("pierce", 0.0))
	var floor_damage: float = power * catalog.num("battle.min_damage_fraction")
	var amount: int = max(1, int(round(max(power - armour, floor_damage))))
	amount += rng.randi_range(0, int(catalog.num("battle.damage_variance")))
	if magical and target.soaked > 0:
		amount = int(round(amount * (1.0 + catalog.num("status.soaked_magic_bonus"))))
		note += " (Soaked)"
	if target.row == "front" and float(target.brace) > 0.0:
		amount = max(1, int(round(amount * (1.0 - float(target.brace)))))
		note += " (Braced)"
	if unit.weaken > 0:
		amount = max(1, int(round(amount * (1.0 - catalog.num("status.weaken_fraction")))))
		note += " (Weakened)"
	if target.expose > 0:
		amount = int(round(amount * (1.0 + catalog.num("status.expose_fraction"))))
		note += " (Exposed)"
	var dealt: int = _damage(target, amount, unit, "attack" if main else "splash",
		"%s takes %d%s." % [target.label, amount, note])
	if not main:
		return
	var splash: float = float(unit.attack.get("splash", 0.0))
	if splash > 0.0:
		var neighbours: Array = units.filter(func(u): return u.alive and u.side == target.side and u != target \
			and u.row == target.row and abs(int(u.lane) - int(target.lane)) == 1)
		for other in neighbours:
			if result.is_empty() and other.alive:
				_strike(unit, other, splash, false)
	unit.hits += 1
	var stun_every: int = int(unit.attack.get("stun_every", 0))
	if target.alive and stun_every > 0 and unit.hits % stun_every == 0:
		_stun(target, "the hammer blow")
	_fire(unit, "hit", {"target": target, "damage": dealt})


## A ready front-row Shield golem in the same or a neighbouring lane, nearest first.
func _guard_for(target: Dictionary) -> Variant:
	var guards: Array = units.filter(func(u): return u.alive and u.side == target.side and u.row == "front" 			and u.attack.get("intercept", false) and u.intercept_ready and abs(int(u.lane) - int(target.lane)) <= 1)
	return _nearest(target, guards) if not guards.is_empty() else null


## Applies damage through Ward, records it and fires hurt/low-HP triggers.
func _damage(target: Dictionary, amount: int, source: Variant, cause: String, text: String) -> int:
	var absorbed: int = min(target.ward, amount)
	target.ward -= absorbed
	var dealt: int = min(target.hp, amount - absorbed)
	target.hp -= dealt
	target.taken += dealt
	if source != null:
		source.dealt += dealt
	if absorbed > 0:
		text += " Ward absorbs %d." % absorbed
	_log({"type": "damage", "unit": target.id, "source": source.id if source != null else "",
		"amount": dealt, "absorbed": absorbed, "hp": target.hp, "ward": target.ward, "cause": cause}, text)
	if target.hp <= 0 and not target.revived and _has_trigger(target, "fatal"):
		target.revived = true
		_fire(target, "fatal", {})
		return dealt
	if target.hp <= 0:
		target.alive = false
		_log({"type": "death", "unit": target.id}, "%s's vessel crumbles." % target.label)
		_check_end()
		if source != null:
			source.kills += 1
			_fire(source, "kill", {"target": target})
		for ally in units.filter(func(u): return u.alive and u.side == target.side):
			_fire(ally, "ally_death", {})
		return dealt
	if cause == "attack" and source != null:
		_fire(target, "hurt", {"attacker": source, "damage": dealt})
	if not target.low_hp_fired and target.hp * 2 < target.max_hp:
		target.low_hp_fired = true
		_fire(target, "low_hp", {})
	return dealt


func _has_trigger(unit: Dictionary, trigger: String) -> bool:
	return unit.effects.any(func(effect): return effect.on == trigger)


func _heal(unit: Dictionary, amount: int, cause: String) -> void:
	var healed: int = min(amount, unit.max_hp - unit.hp)
	if healed <= 0:
		return
	unit.hp += healed
	unit.healed += healed
	_log({"type": "heal", "unit": unit.id, "amount": healed, "hp": unit.hp, "cause": cause},
		"%s mends %d (%s)." % [unit.label, healed, cause])


func _fire(unit: Dictionary, trigger: String, context: Dictionary) -> void:
	for i in range(unit.effects.size()):
		var effect: Dictionary = unit.effects[i]
		if effect.on != trigger or not unit.alive or not result.is_empty():
			continue
		if int(unit.cooldowns.get(i, 0)) > 0:
			continue
		var target: Variant = context.get("target")
		if effect.has("if_target"):
			if target == null or not target.alive:
				continue
			var matched: bool = false
			for status in effect.if_target:
				matched = matched or int(target[status]) > 0
			if not matched:
				continue
		var solo: bool = effect.do in ["chain", "drain"]
		var receivers: Array = [] if solo else _receivers(unit, String(effect.to), context)
		if not solo and receivers.is_empty():
			continue
		unit.triggers += 1
		if effect.has("cooldown"):
			unit.cooldowns[i] = int(effect.cooldown)
		if effect.do == "chain":
			_chain(unit, effect, context)
		elif effect.do == "drain":
			_heal(unit, int(floor(int(context.get("damage", 0)) * float(effect.fraction))), effect.source)
		for receiver in receivers:
			if not result.is_empty():
				return
			if receiver.alive:
				_apply(unit, effect, receiver)


## Living golems an effect lands on, in board order.
func _receivers(unit: Dictionary, to: String, context: Dictionary) -> Array:
	match to:
		"self":
			return [unit]
		"target", "attacker":
			var other: Variant = context.get(to)
			return [other] if other != null and other.alive else []
		"team":
			return units.filter(func(u): return u.alive and u.side == unit.side)
		"allies":
			return units.filter(func(u): return u.alive and u.side == unit.side and u != unit)
		"enemies":
			return units.filter(func(u): return u.alive and u.side != unit.side)
		"lane":
			return units.filter(func(u): return u.alive and u.side == unit.side and u.lane == unit.lane)
		"wounded":
			var hurt: Array = units.filter(func(u): return u.alive and u.side == unit.side and u.hp < u.max_hp)
			if hurt.is_empty():
				return []
			var worst: Dictionary = hurt[0]
			for ally in hurt:
				if float(ally.hp) / ally.max_hp < float(worst.hp) / worst.max_hp:
					worst = ally
			return [worst]
	return []


## Flat amount plus a share of one of the effect owner's stats.
func _amount(unit: Dictionary, effect: Dictionary) -> int:
	var scaled: float = 0.0
	if effect.has("stat"):
		scaled = float(unit.stats[effect.stat]) * float(effect.get("fraction", 1.0))
	return int(effect.get("flat", 0)) + int(floor(scaled))


func _apply(unit: Dictionary, effect: Dictionary, receiver: Dictionary) -> void:
	var source: String = effect.source
	match effect.do:
		"status":
			_apply_status(receiver, effect.status, int(effect.amount), source)
		"ward":
			var amount: int = _amount(unit, effect)
			receiver.ward += amount
			unit.shielded += amount
			_log({"type": "ward", "unit": receiver.id, "amount": amount, "ward": receiver.ward, "cause": source},
				"%s gains %d Ward (%s)." % [receiver.label, amount, source])
		"heal":
			_heal(receiver, _amount(unit, effect), source)
		"damage":
			var amount: int = max(1, _amount(unit, effect))
			_damage(receiver, amount, unit, "effect", "%s strikes %s for %d (%s)." % [unit.label, receiver.label, amount, source])
		"haste":
			var amount: int = _amount(unit, effect)
			receiver.gauge += float(amount)
			if amount >= 0:
				_log({"type": "haste", "unit": receiver.id, "amount": amount, "cause": source},
					"%s surges forward (+%d gauge, %s)." % [receiver.label, amount, source])
			else:
				_log({"type": "slow", "unit": receiver.id, "amount": amount, "cause": source},
					"%s is slowed (%d gauge, %s)." % [receiver.label, amount, source])
		"cleanse":
			var cleared: Array = []
			for status in ["burn", "soaked", "weaken", "expose"]:
				if int(receiver[status]) > 0:
					receiver[status] = 0
					cleared.append(status.capitalize())
					_log({"type": "status_end", "unit": receiver.id, "status": status}, "")
			if receiver.stunned:
				receiver.stunned = false
				cleared.append("Stun")
				_log({"type": "status_end", "unit": receiver.id, "status": "stun"}, "")
			if not cleared.is_empty():
				_log({"type": "cleanse", "unit": receiver.id, "cause": source},
					"%s is cleansed of %s (%s)." % [receiver.label, ", ".join(cleared), source])
		"revive":
			receiver.hp = max(1, int(round(receiver.max_hp * float(effect.fraction))))
			_log({"type": "heal", "unit": receiver.id, "amount": receiver.hp, "hp": receiver.hp, "cause": source},
				"%s refuses to fall and rises with %d HP (%s)." % [receiver.label, receiver.hp, source])


func _chain(unit: Dictionary, effect: Dictionary, context: Dictionary) -> void:
	var primary: Dictionary = context.target
	var others: Array = units.filter(func(u): return u.alive and u.side != unit.side and u != primary)
	var amount: int = int(floor(int(context.get("damage", 0)) * float(effect.fraction)))
	if others.is_empty() or amount <= 0:
		return
	var arc: Dictionary = _weakest(others)
	_log({"type": "chain", "unit": unit.id, "from": primary.id, "target": arc.id}, "")
	_damage(arc, amount, unit, "chain", "%s arcs %d to %s (%s)." % [unit.label, amount, arc.label, effect.source])


func _stun(receiver: Dictionary, cause: String) -> void:
	if "stun" in receiver.immune:
		_log({"type": "resist", "unit": receiver.id}, "%s cannot be Stunned." % receiver.label)
		return
	if receiver.stable:
		_log({"type": "resist", "unit": receiver.id}, "%s's Pillar Legs hold firm: no Stun." % receiver.label)
		return
	receiver.stunned = true
	_log({"type": "status", "unit": receiver.id, "status": "stun", "value": 1, "cause": cause},
		"%s is Stunned (%s)." % [receiver.label, cause])


func _apply_status(receiver: Dictionary, status: String, amount: int, source: String) -> void:
	if status == "stun":
		_stun(receiver, source)
		return
	if status in receiver.immune:
		_log({"type": "resist", "unit": receiver.id}, "%s shrugs off %s." % [receiver.label, status.capitalize()])
		return
	if status == "burn":
		if receiver.soaked > 0:
			_log({"type": "resist", "unit": receiver.id}, "%s is Soaked: the Burn fizzles." % receiver.label)
			return
		receiver.burn = min(int(catalog.num("status.burn_max_stacks")), receiver.burn + amount)
	elif status == "soaked":
		if receiver.burn > 0:
			receiver.burn = 0
			_log({"type": "status_end", "unit": receiver.id, "status": "burn"}, "The water puts out %s's Burn." % receiver.label)
		receiver.soaked = max(receiver.soaked, amount)
	else:
		receiver[status] = max(int(receiver[status]), amount)
	_log({"type": "status", "unit": receiver.id, "status": status, "value": receiver[status], "cause": source},
		"%s: %s %d (%s)." % [receiver.label, status.capitalize(), receiver[status], source])


func _check_end() -> void:
	for side in [0, 1]:
		if units.filter(func(u): return u.alive and u.side == side).is_empty():
			result = "loss" if side == 0 else "win"
			_log({"type": "end", "result": result}, "Your golems win!" if result == "win" else "Your golems have fallen.")
			return


func _log(event: Dictionary, text: String) -> void:
	event["tick"] = tick
	event["text"] = text
	events.append(event)
