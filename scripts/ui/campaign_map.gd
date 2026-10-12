extends Control
## The region map: a path of stage markers. Locked stages are drawn but cannot
## be chosen; cleared stages show a check and stay repeatable.

signal stage_selected(stage_id: String)

const Style = preload("res://scripts/ui/style.gd")

var stages: Array = []
## stage id -> "locked" | "open" | "cleared"
var states: Dictionary = {}
var selected: String = ""
var _hover: String = ""
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _offset() -> Vector2:
	# Stage coordinates are authored for an 860x560 map; centre them in the control.
	return (size - Vector2(860, 560)) / 2.0


func _stage_at(point: Vector2) -> String:
	for stage in stages:
		if point.distance_to(_offset() + Vector2(stage.map_pos[0], stage.map_pos[1])) < 34.0:
			return stage.id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: String = _stage_at(event.position)
		if hovered != _hover:
			_hover = hovered
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hovered.is_empty() and states.get(hovered) != "locked" else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id: String = _stage_at(event.position)
		if not id.is_empty() and states.get(id) != "locked":
			selected = id
			stage_selected.emit(id)
			accept_event()


func _draw() -> void:
	var offset: Vector2 = _offset()
	draw_rect(Rect2(Vector2.ZERO, size), Color("161a17"))
	# Ruined flagstones and moss give the region its texture.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(70):
		var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var r: float = rng.randf_range(12, 46)
		draw_circle(p, r, Color(0.2, 0.26, 0.2, rng.randf_range(0.15, 0.4)))
	for i in range(26):
		var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		draw_rect(Rect2(p, Vector2(rng.randf_range(30, 80), rng.randf_range(16, 30))), Color(0.32, 0.31, 0.28, 0.35), false, 2.0)
	for stage in stages:
		for required in stage.get("requires", []):
			var from: Dictionary = _find(required)
			if from.is_empty():
				continue
			var a: Vector2 = offset + Vector2(from.map_pos[0], from.map_pos[1])
			var b: Vector2 = offset + Vector2(stage.map_pos[0], stage.map_pos[1])
			var open: bool = states.get(stage.id) != "locked"
			_dashed(a, b, Style.GOLD.darkened(0.2) if open else Color("4a4a4a"))
	for stage in stages:
		_marker(stage, offset + Vector2(stage.map_pos[0], stage.map_pos[1]))


func _find(id: String) -> Dictionary:
	for stage in stages:
		if stage.id == id:
			return stage
	return {}


func _dashed(a: Vector2, b: Vector2, color: Color) -> void:
	var length: float = a.distance_to(b)
	var direction: Vector2 = (b - a).normalized()
	var t: float = 30.0
	while t < length - 30.0:
		draw_line(a + direction * t, a + direction * min(t + 12.0, length - 30.0), color, 4.0, true)
		t += 22.0


func _marker(stage: Dictionary, at: Vector2) -> void:
	var state: String = states.get(stage.id, "locked")
	var boss: bool = stage.get("boss", false)
	var radius: float = 30.0 if boss else 24.0
	var fill: Color = Color("3a3a3a")
	var ring: Color = Color("5c5c5c")
	if state == "open":
		fill = Color("5a4a2a")
		ring = Style.GOLD
		radius += sin(_time * 3.0) * 2.0
	elif state == "cleared":
		fill = Color("2d4a35")
		ring = Style.GOOD
	if stage.id == selected:
		draw_circle(at, radius + 10.0, Color(1, 1, 1, 0.12))
	draw_circle(at, radius, fill)
	draw_arc(at, radius, 0, TAU, 40, ring, 3.0 if stage.id != _hover else 5.0, true)
	var font: Font = ThemeDB.fallback_font
	var mark: String = "B" if boss else str(stages.find(stage) + 1)
	if state == "cleared":
		mark = "OK"
	elif state == "locked":
		mark = "-"
	var mark_size: Vector2 = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, at + Vector2(-mark_size.x / 2.0, 7), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Style.TEXT)
	var name_size: Vector2 = font.get_string_size(stage.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var name_at: Vector2 = at + Vector2(-name_size.x / 2.0, radius + 22.0)
	draw_string(font, name_at + Vector2(1, 1), stage.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.8))
	draw_string(font, name_at, stage.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Style.TEXT if state != "locked" else Style.MUTED)
