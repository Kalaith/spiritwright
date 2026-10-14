extends Control
## Replays a finished simulation. The outcome is already decided; this view
## only presents the event log, one golem's turn per beat, so every hit,
## trigger and status can be read. Speed, pause and skip are always available.
## Heavy hits and falls shake the scene (not the controls) unless the player
## has turned screen shake off.

signal finished
signal settings_requested

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const Backdrop = preload("res://scripts/ui/battle_backdrop.gd")
const Weather = preload("res://scripts/ui/battle_weather.gd")
const Shake = preload("res://addons/hatchery/fx/shake.gd")
const BEAT_SECONDS: float = 0.85
const IMPACT: float = 0.4
const ART_SCALE: float = 0.85
## Bosses stand a head taller than everyone else.
const BOSS_SCALE: float = 1.25
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var catalog: RefCounted
var stage: Dictionary = {}
## Which region's scene the battle is fought in (see battle_backdrop.gd).
var scene: String = "ruins"
var outcome: Dictionary = {}
## Set `shake.enabled` from the player's screen shake setting.
var shake := Shake.new()
## id -> display state; the view never reads the simulation's final numbers.
var units: Dictionary = {}
var _beats: Array = []
var _beat: int = -1
var _beat_time: float = 0.0
var _impact_done: bool = true
var _speed_index: int = 0
var _paused: bool = false
var _done: bool = false
## While skipping, events update state silently instead of spawning floaters.
var _quiet: bool = false
var _attack: Dictionary = {}
var _floaters: Array = []
var _log_lines: Array[String] = []
var _log_label: Label
var _pause_button: Button
var _speed_button: Button
var _skip_button: Button
var _continue_button: Button
## The backdrop and weather, moved with the shake.
var _scenery: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Behind this view's own drawing, so the golems stand in front of the scene.
	for layer in [Backdrop.new(), Weather.new()]:
		layer.scene = scene
		layer.show_behind_parent = true
		add_child(layer)
		_scenery.append(layer)
	_build_ui()
	for unit in outcome.units:
		units[unit.id] = {
			"id": unit.id, "label": unit.label, "level": unit.level, "side": unit.side, "lane": unit.lane,
			"row": unit.row, "hp": unit.max_hp, "max_hp": unit.max_hp, "ward": 0, "burn": 0, "soaked": 0, "weaken": 0, "expose": 0,
			"taunt": 0, "regen": 0, "stun": 0, "alive": true, "flash": 0.0, "alpha": 1.0, "offset": Vector2.ZERO,
			"look": GolemArt.look_for(catalog, unit, Style.ALLY if unit.side == 0 else Style.ENEMY),
			"scale": ART_SCALE * (BOSS_SCALE if catalog.spirit(unit.spirit).get("boss", false) else 1.0),
		}
	var current: Array = []
	for event in outcome.events:
		if event.type == "turn" and not current.is_empty():
			_beats.append(current)
			current = []
		current.append(event)
	if not current.is_empty():
		_beats.append(current)
	# Battle-start effects (bells, wards) happen before anyone's first turn.
	if not _beats.is_empty() and _beats[0][0].type != "turn":
		for event in _beats.pop_front():
			_apply(event)
	_say("The golems take their places. %s." % stage.name)


func _build_ui() -> void:
	var top := Style.hbox(10)
	top.position = Vector2(14, 10)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 10
	add_child(top)
	var title := Style.label(stage.name, 24, Style.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_pause_button = Style.button("Pause", _toggle_pause)
	_speed_button = Style.button("Speed 1x", _cycle_speed)
	_skip_button = Style.button("Skip to end", _skip)
	_continue_button = Style.button("Continue", func(): finished.emit(), 20)
	_continue_button.hide()
	var settings_button := Style.button("Settings", func(): settings_requested.emit())
	for node in [_pause_button, _speed_button, _skip_button, _continue_button, settings_button]:
		top.add_child(node)
	var log_panel := Style.panel(10)
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	log_panel.offset_left = 14
	log_panel.offset_right = -14
	log_panel.offset_top = -138
	log_panel.offset_bottom = -12
	add_child(log_panel)
	_log_label = Style.label("", 15, Style.TEXT)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log_label.clip_text = true
	log_panel.add_child(_log_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _done:
		finished.emit()
	elif event.is_action_pressed("ui_select") and not _done:
		_toggle_pause()


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_button.text = "Play" if _paused else "Pause"


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_speed_button.text = "Speed %dx" % int(SPEEDS[_speed_index])


func _skip() -> void:
	if _beat >= 0 and not _impact_done:
		_finish_beat()
	_quiet = true
	while _beat + 1 < _beats.size():
		_beat += 1
		for event in _beats[_beat]:
			_apply(event)
	_quiet = false
	_floaters.clear()
	_attack = {}
	for unit in units.values():
		unit.offset = Vector2.ZERO
		unit.flash = 0.0
	_end()


func _end() -> void:
	_done = true
	_pause_button.hide()
	_speed_button.hide()
	_skip_button.hide()
	_continue_button.show()
	_continue_button.grab_focus()


func _process(delta: float) -> void:
	for floater in _floaters:
		floater.t += delta
	_floaters = _floaters.filter(func(f): return f.t < 1.3)
	for unit in units.values():
		unit.flash = max(0.0, unit.flash - delta * 3.0)
		if not unit.alive:
			unit.alpha = max(0.25, unit.alpha - delta * 1.5)
	if not _done and not _paused:
		_advance(delta * SPEEDS[_speed_index])
	shake.step(delta)
	for layer in _scenery:
		layer.position = shake.offset
	queue_redraw()


func _advance(delta: float) -> void:
	_beat_time += delta
	if _beat < 0 or _beat_time >= BEAT_SECONDS:
		if _beat >= 0 and not _impact_done:
			_finish_beat()
		_beat += 1
		_beat_time = 0.0
		if _beat >= _beats.size():
			_end()
			return
		_start_beat()
	elif not _impact_done and _beat_time >= IMPACT:
		_finish_beat()
	_animate()


## Applies everything up to the attack (turn-start burn, regen, stun skips).
func _start_beat() -> void:
	_attack = {}
	_impact_done = false
	for event in _beats[_beat]:
		_apply(event)
		if event.type == "attack":
			_attack = event
			return
	_impact_done = true


func _finish_beat() -> void:
	_impact_done = true
	var after: bool = false
	for event in _beats[_beat]:
		if after:
			_apply(event)
		elif event == _attack:
			after = true
	if not _attack.is_empty():
		units[_attack.unit].offset = Vector2.ZERO


func _animate() -> void:
	if _attack.is_empty():
		return
	var attacker: Dictionary = units[_attack.unit]
	if _attack.range != "melee":
		attacker.offset = Vector2(-8.0 * _facing(attacker), 0) * sin(clampf(_beat_time / IMPACT, 0, 1) * PI)
		return
	var reach: Vector2 = (_home(units[_attack.target]) - _home(attacker)) * 0.7
	var t: float = _beat_time / IMPACT
	attacker.offset = reach * (t * t if t <= 1.0 else max(0.0, 1.0 - (t - 1.0) * 1.6))


func _apply(event: Dictionary) -> void:
	if not String(event.text).is_empty():
		_say(event.text)
	var unit: Variant = units.get(event.get("unit", ""))
	match event.type:
		"damage":
			unit.hp = int(event.hp)
			unit.ward = int(event.ward)
			unit.flash = 1.0
			var color: Color = Style.STATUS_COLORS.burn if event.cause == "burn" else Color.WHITE
			if event.cause == "chain":
				color = Color("b9a6ff")
			elif event.cause == "effect":
				color = Style.GOLD
			_float(unit, "-%d" % int(event.amount), color)
			# A blow jolts the scene in proportion to how much of the golem it took.
			if not _quiet and event.cause != "burn":
				shake.add(0.12 + 0.8 * float(event.amount) / float(unit.max_hp))
			if int(event.absorbed) > 0:
				_float(unit, "WARD -%d" % int(event.absorbed), Style.STATUS_COLORS.ward)
		"heal":
			unit.hp = int(event.hp)
			_float(unit, "+%d" % int(event.amount), Style.GOOD)
		"ward":
			unit.ward = int(event.ward)
			_float(unit, "+%d WARD" % int(event.amount), Style.STATUS_COLORS.ward)
		"status":
			unit[event.status] = int(event.value)
			_float(unit, Style.STATUS_LABELS[event.status], Style.STATUS_COLORS[event.status])
		"status_end":
			unit[event.status] = 0
		"stun_skip":
			unit.stun = 0
			_float(unit, "STUNNED", Style.STATUS_COLORS.stun)
		"haste":
			_float(unit, "HASTE", Style.STATUS_COLORS.haste)
		"slow":
			_float(unit, "SLOWED", Style.STATUS_COLORS.slow)
		"cleanse":
			_float(unit, "CLEANSED", Style.GOOD)
		"intercept":
			_float(unit, "INTERCEPT", Style.GOLD)
		"resist":
			_float(unit, "RESIST", Style.MUTED)
		"death":
			if not _quiet:
				shake.add(0.45)
			unit.alive = false
			unit.hp = 0
			for status in ["ward", "burn", "soaked", "taunt", "regen", "stun", "weaken", "expose"]:
				unit[status] = 0
	# Burn loses a stack each time it deals its turn-start damage, as in the simulation.
	if event.type == "damage" and event.cause == "burn":
		unit.burn = max(0, unit.burn - 1)


func _say(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 5:
		_log_lines = _log_lines.slice(_log_lines.size() - 5)
	_log_label.text = "\n".join(_log_lines)


## Floaters for the same golem stack upward instead of overlapping.
func _float(unit: Dictionary, text: String, color: Color) -> void:
	if _quiet:
		return
	var recent: int = _floaters.filter(func(f): return f.unit == unit.id and f.t < 0.6).size()
	var width: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var at: Vector2 = _home(unit) + Vector2(-width / 2.0, -176.0 * unit.scale - 22.0 * recent)
	_floaters.append({"unit": unit.id, "text": text, "pos": at, "color": color, "t": 0.0})


func _facing(unit: Dictionary) -> float:
	return 1.0 if unit.side == 0 else -1.0


## Feet position: row sets the distance from the centre line, lane sets depth.
func _home(unit: Dictionary) -> Vector2:
	var arena_top: float = 60.0
	var arena_bottom: float = size.y - 150.0
	var depth: float = arena_top + (arena_bottom - arena_top) * (0.4 + 0.29 * unit.lane)
	var distance: float = (110.0 if unit.row == "front" else 290.0) + 26.0 * unit.lane
	return Vector2(size.x / 2.0 - distance * _facing(unit), depth)


func _draw() -> void:
	# The golems and everything over them move with the scenery.
	draw_set_transform(shake.offset)
	var horizon: float = Backdrop.horizon_for(size)
	draw_line(Vector2(size.x / 2.0, horizon), Vector2(size.x / 2.0, Backdrop.floor_bottom_for(size)), Color(1, 1, 1, 0.06), 2.0)
	var order: Array = units.values()
	order.sort_custom(func(a, b): return a.lane < b.lane or (a.lane == b.lane and a.side < b.side))
	for unit in order:
		var at: Vector2 = _home(unit) + unit.offset
		if not _attack.is_empty() and _attack.unit == unit.id and unit.alive:
			draw_arc(at, 50.0 * unit.scale, 0, TAU, 32, Style.GOLD, 2.0, true)
		GolemArt.draw(self, at, unit.scale, _facing(unit), unit.look, {"flash": unit.flash, "alpha": unit.alpha,
			"time": Time.get_ticks_msec() / 1000.0 if unit.alive else 0.0})
		_draw_hud(unit, _home(unit))
	if not _attack.is_empty() and _attack.range != "melee" and not _impact_done:
		var t: float = clampf(_beat_time / IMPACT, 0.0, 1.0)
		var shooter: Dictionary = units[_attack.unit]
		var from: Vector2 = _home(shooter) + Vector2(70 * _facing(shooter), -70) * shooter.scale
		var to: Vector2 = _home(units[_attack.target]) + Vector2(0, -60) * units[_attack.target].scale
		var color: Color = units[_attack.unit].look.element_color
		draw_circle(from.lerp(to, t), 7.0, color)
		draw_circle(from.lerp(to, max(0.0, t - 0.08)), 4.0, Color(color.r, color.g, color.b, 0.5))
	var font: Font = ThemeDB.fallback_font
	for floater in _floaters:
		var alpha: float = clampf(1.6 - floater.t * 1.3, 0.0, 1.0)
		var pos: Vector2 = floater.pos - Vector2(0, floater.t * 26.0)
		draw_string_outline(font, pos, floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, alpha))
		draw_string(font, pos, floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(floater.color, alpha))
	draw_set_transform(Vector2.ZERO)
	if _done:
		_draw_banner(font)


func _draw_hud(unit: Dictionary, feet: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	# Clear of the tallest head plus its reaction aura, with room for badges.
	var top: float = feet.y - 120.0 * unit.scale - 30.0
	var bar := Rect2(feet.x - 46, top, 92, 9)
	var name_text: String = "%s  Lv %d" % [unit.label, unit.level]
	var width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string_outline(font, Vector2(feet.x - width / 2.0, top - 6), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(feet.x - width / 2.0, top - 6), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.TEXT if unit.alive else Style.MUTED)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.8))
	var ratio: float = float(unit.hp) / float(unit.max_hp)
	var hp_color: Color = Style.ALLY if unit.side == 0 else Style.ENEMY
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), hp_color)
	if unit.ward > 0:
		var ward_ratio: float = min(1.0, float(unit.ward) / float(unit.max_hp))
		draw_rect(Rect2(bar.position + Vector2(0, -4), Vector2(bar.size.x * ward_ratio, 3)), Style.STATUS_COLORS.ward)
	draw_string(font, Vector2(bar.end.x + 4, bar.end.y), str(unit.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.TEXT)
	var badges: Array = []
	for status in ["ward", "burn", "soaked", "taunt", "regen", "stun", "weaken", "expose"]:
		if int(unit[status]) > 0:
			badges.append([status, Style.STATUS_LABELS[status] + (" %d" % int(unit[status]) if status in ["ward", "burn"] else "")])
	var x: float = bar.position.x
	for badge in badges:
		var text_width: float = font.get_string_size(badge[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var rect := Rect2(x, bar.end.y + 3, text_width + 8, 15)
		draw_rect(rect, Color(Style.STATUS_COLORS[badge[0]], 0.85))
		draw_string(font, rect.position + Vector2(4, 12), badge[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("101018"))
		x += rect.size.x + 3


func _draw_banner(font: Font) -> void:
	var text: String = {"win": "VICTORY", "loss": "DEFEAT"}.get(outcome.result, "TIME UP")
	var color: Color = Style.GOOD if outcome.result == "win" else Style.BAD
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	var at := Vector2(size.x / 2.0 - width / 2.0, 98)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 8, Color(0, 0, 0, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, color)
