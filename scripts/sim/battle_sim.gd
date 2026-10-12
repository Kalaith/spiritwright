extends RefCounted
## Deterministic auto-battle. Given the same resolved teams and seed it always
## produces the same event log; all randomness comes from `rng`. It never
## touches the scene tree. The battle view replays `events` afterwards.
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
			label += " " + "ABC"[int(seen[golem.name]) - 1]
		var unit: Dictionary = golem.duplicate(true)
		unit.merge({
			"id": SIDES[side] + str(slot), "index": units.size(), "side": side, "slot": slot,
			"label": label, "hp": int(golem.stats.hp), "max_hp": int(golem.stats.hp), "alive": true,
			"gauge": 0.0, "burn": 0, "soaked": 0, "taunt": 0, "regen": 0, "ward": 0, "stunned": false,
			"hits": 0, "intercept_ready": true, "low_hp_fired": false, "cooldowns": {},
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
	for status in ["soaked", "taunt"]:
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


func _choose_target(unit: Dictionary) -> Variant:
	var enemies: Array = units.filter(func(u): return u.alive and u.side != unit.side)
	if enemies.is_empty():
		return null
	var taunting: Array = enemies.filter(func(u): return u.taunt > 0)
	if not taunting.is_empty():
		return taunting[0]
	if unit.attack.range == "ranged" or unit.reach:
		return _weakest(enemies)
	var front: Array = enemies.filter(func(u): return u.row == "front")
	return front[0] if not front.is_empty() else enemies[0]


func _weakest(candidates: Array) -> Dictionary:
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if candidate.hp < best.hp:
			best = candidate
	return best


func _attack(unit: Dictionary, target: Dictionary) -> void:
	if target.row == "back":
		for guard in units:
			if guard.alive and guard.side == target.side and guard.row == "front" \
					and guard.attack.get("intercept", false) and guard.intercept_ready:
				guard.intercept_ready = false
				_log({"type": "intercept", "unit": guard.id, "protected": target.id},
					"%s steps in front of %s." % [guard.label, target.label])
				target = guard
				break
	_log({"type": "attack", "unit": unit.id, "target": target.id, "range": unit.attack.range},
		"%s attacks %s." % [unit.label, target.label])
	var magical: bool = unit.attack.kind == "magical"
	var power: int = int(unit.attack.power) + int(unit.stats.mag if magical else unit.stats.str)
	var amount: int = max(1, power - int(target.stats.res if magical else target.stats.def))
	amount += rng.randi_range(0, int(catalog.num("battle.damage_variance")))
	var note: String = ""
	if magical and target.soaked > 0:
		amount = int(round(amount * (1.0 + catalog.num("status.soaked_magic_bonus"))))
		note = " (Soaked)"
	var dealt: int = _damage(target, amount, unit, "attack", "%s takes %d%s." % [target.label, amount, note])
	unit.hits += 1
	var stun_every: int = int(unit.attack.get("stun_every", 0))
	if target.alive and stun_every > 0 and unit.hits % stun_every == 0:
		if target.stable:
			_log({"type": "resist", "unit": target.id}, "%s's Pillar Legs hold firm: no Stun." % target.label)
		else:
			target.stunned = true
			_log({"type": "status", "unit": target.id, "status": "stun", "value": 1, "cause": unit.arms},
				"%s is Stunned by the hammer blow." % target.label)
	_fire(unit, "hit", {"target": target, "damage": dealt})


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
	if target.hp <= 0:
		target.alive = false
		if source != null:
			source.kills += 1
		_log({"type": "death", "unit": target.id}, "%s's vessel crumbles." % target.label)
		_check_end()
		return dealt
	if cause == "attack" and source != null:
		_fire(target, "hurt", {"attacker": source, "damage": dealt})
	if not target.low_hp_fired and target.hp * 2 < target.max_hp:
		target.low_hp_fired = true
		_fire(target, "low_hp", {})
	return dealt


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
		if effect.get("to", "") == "target" and (target == null or not target.alive):
			continue
		unit.triggers += 1
		if effect.has("cooldown"):
			unit.cooldowns[i] = int(effect.cooldown)
		_apply(unit, effect, target if effect.get("to", "") == "target" else unit, context)


func _apply(unit: Dictionary, effect: Dictionary, receiver: Dictionary, context: Dictionary) -> void:
	var source: String = effect.source
	match effect.do:
		"status":
			_apply_status(receiver, effect.status, int(effect.amount), source)
		"ward":
			var amount: int = int(effect.get("flat", 0)) + int(receiver.stats.get(effect.get("stat", ""), 0))
			receiver.ward += amount
			unit.shielded += amount
			_log({"type": "ward", "unit": receiver.id, "amount": amount, "ward": receiver.ward, "cause": source},
				"%s gains %d Ward (%s)." % [receiver.label, amount, source])
		"heal":
			_heal(receiver, int(effect.flat), source)
		"chain":
			var primary: Dictionary = context.target
			var others: Array = units.filter(func(u): return u.alive and u.side != unit.side and u != primary)
			var amount: int = int(floor(int(context.get("damage", 0)) * float(effect.fraction)))
			if others.is_empty() or amount <= 0:
				return
			var arc: Dictionary = _weakest(others)
			_log({"type": "chain", "unit": unit.id, "from": primary.id, "target": arc.id}, "")
			_damage(arc, amount, unit, "chain", "%s arcs %d to %s (%s)." % [unit.label, amount, arc.label, source])


func _apply_status(receiver: Dictionary, status: String, amount: int, source: String) -> void:
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
