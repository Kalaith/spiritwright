extends Control
## A region map: illustrated ground with a landmark for every stage, the trails
## between them and the golem laboratory where the region's journey starts. Locked stages lie under fog and cannot be chosen; cleared stages
## stay repeatable. The player's golems walk to whichever place is selected.

signal stage_selected(stage_id: String)
signal laboratory_selected

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const MapTerrain = preload("res://scripts/ui/map_terrain.gd")
const MapLandmarks = preload("res://scripts/ui/map_landmarks.gd")
const LAB_ID: String = "laboratory"
const PARTY_SCALE: float = 0.4
const PARTY_SPEED: float = 280.0

var stages: Array = []
## stage id -> "locked" | "open" | "cleared"
var states: Dictionary = {}
var selected: String = ""
## {"name", "map_pos"} from the region data.
var laboratory: Dictionary = {}
## The region's "terrain" block from campaign.json.
var terrain: Dictionary = {}
## One look per built golem, leader first.
var party_looks: Array = []
var golem_slots: int = 3
var core_ready: bool = false
var _hover: String = ""
var _time: float = 0.0
var _party_pos: Vector2 = Vector2.INF
var _walking: bool = false
var _terrain := _Layer.new()
var _live := _Layer.new()


## A full-rect child that paints with its owner's function, so the still
## ground is drawn once while the moving parts redraw every frame.
class _Layer extends Control:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for layer in [_terrain, _live]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	_terrain.painter = _draw_terrain
	_live.painter = _draw_live
	resized.connect(_terrain.queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	var target: Vector2 = _party_anchor()
	if _party_pos == Vector2.INF:
		_party_pos = target
	var gap: Vector2 = target - _party_pos
	_walking = gap.length() > 1.0
	_party_pos = target if gap.length() <= PARTY_SPEED * delta else _party_pos + gap.normalized() * PARTY_SPEED * delta
	_live.queue_redraw()


func _offset() -> Vector2:
	# Positions are authored for an 860x560 map; centre them in the control.
	return (size - Vector2(860, 560)) / 2.0


func _at(point: Array) -> Vector2:
	return _offset() + Vector2(point[0], point[1])


## Where the leading golem stands: just left of a stage marker, or in front of
## the laboratory's cradle.
func _party_anchor() -> Vector2:
	if selected.is_empty() or selected == LAB_ID or _find(selected).is_empty():
		return _at(laboratory.map_pos) + Vector2(64, 14)
	return _at(_find(selected).map_pos) + Vector2(-44, 22)


func _place_at(point: Vector2) -> String:
	if not laboratory.is_empty() and point.distance_to(_at(laboratory.map_pos) + Vector2(-14, -46)) < 56.0:
		return LAB_ID
	for stage in stages:
		if point.distance_to(_at(stage.map_pos)) < 34.0:
			return stage.id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: String = _place_at(event.position)
		if hovered != _hover:
			_hover = hovered
			var usable: bool = not hovered.is_empty() and states.get(hovered) != "locked"
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id: String = _place_at(event.position)
		if id == LAB_ID:
			laboratory_selected.emit()
			accept_event()
		elif not id.is_empty() and states.get(id) != "locked":
			selected = id
			stage_selected.emit(id)
			accept_event()


func _draw_terrain(ci: Control) -> void:
	MapTerrain.draw(ci, size, _offset(), terrain)
	for stage in stages:
		var requires: Array = stage.get("requires", [])
		# A stage reached from another region (or from nowhere) starts at the laboratory.
		var froms: Array = requires.map(func(id): return _find(id).get("map_pos", laboratory.map_pos))
		if requires.is_empty():
			froms = [laboratory.map_pos]
		for from in froms:
			_trail(ci, _at(from), _at(stage.map_pos), states.get(stage.id) != "locked")
	MapLandmarks.draw(ci, "laboratory", _at(laboratory.map_pos))
	for stage in stages:
		MapLandmarks.draw(ci, stage.landmark, _at(stage.map_pos), 1.0 if states.get(stage.id) == "locked" else 0.0)
	for stage in stages:
		if states.get(stage.id) == "locked":
			MapTerrain.fog(ci, _at(stage.map_pos), terrain)
	MapTerrain.vignette(ci, size)


func _draw_live(ci: Control) -> void:
	MapTerrain.draw_live(ci, _offset(), _time, terrain)
	MapLandmarks.draw_live(ci, "laboratory", _at(laboratory.map_pos), _time, core_ready)
	for stage in stages:
		if states.get(stage.id) != "locked":
			MapLandmarks.draw_live(ci, stage.landmark, _at(stage.map_pos), _time, false)
	_lab_label(ci)
	for stage in stages:
		_marker(ci, stage, _at(stage.map_pos))
	_party(ci)


func _find(id: String) -> Dictionary:
	for stage in stages:
		if stage.id == id:
			return stage
	return {}


## A worn dirt trail with a dashed line on top: gold once it can be walked.
func _trail(ci: Control, a: Vector2, b: Vector2, open: bool) -> void:
	ci.draw_line(a, b, Color("2a2419", 0.85), 12.0, true)
	ci.draw_line(a, b, Color("3a3224", 0.9), 7.0, true)
	var length: float = a.distance_to(b)
	var direction: Vector2 = (b - a).normalized()
	var color: Color = Style.GOLD.darkened(0.25) if open else Color("4a4a4a")
	var t: float = 30.0
	while t < length - 30.0:
		ci.draw_line(a + direction * t, a + direction * min(t + 10.0, length - 30.0), color, 3.0, true)
		t += 20.0


func _marker(ci: Control, stage: Dictionary, at: Vector2) -> void:
	var state: String = states.get(stage.id, "locked")
	var boss: bool = stage.get("boss", false)
	var radius: float = 24.0 if boss else 19.0
	var fill: Color = Color("2c2c30")
	var ring: Color = Color("55555c")
	if state == "open":
		fill = Color("4d3d1f")
		ring = Style.GOLD
		var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
		ci.draw_arc(at, radius + 5.0 + pulse * 5.0, 0, TAU, 40, Color(Style.GOLD, 0.45 * (1.0 - pulse)), 2.0, true)
	elif state == "cleared":
		fill = Color("244232")
		ring = Style.GOOD
	if stage.id == selected:
		ci.draw_circle(at, radius + 9.0, Color(1, 1, 1, 0.14))
	ci.draw_circle(at + Vector2(2, 3), radius + 3.0, Color(0, 0, 0, 0.45))
	ci.draw_circle(at, radius + 3.0, Color("3a3b40"))
	ci.draw_circle(at, radius, fill)
	ci.draw_arc(at, radius, 0, TAU, 40, ring, 2.5 if stage.id != _hover else 4.5, true)
	ci.draw_arc(at, radius + 3.0, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.18), 2.0, true)
	if state == "cleared":
		ci.draw_polyline(PackedVector2Array([at + Vector2(-8, 0), at + Vector2(-2, 7), at + Vector2(9, -7)]), Style.GOOD, 3.5, true)
	elif state == "locked":
		ci.draw_rect(Rect2(at + Vector2(-7, -2), Vector2(14, 10)), Color("8a8a90"))
		ci.draw_arc(at + Vector2(0, -2), 5.0, PI, TAU, 10, Color("8a8a90"), 2.5, true)
	elif boss:
		ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-11, 7), at + Vector2(11, 7), at + Vector2(13, -8),
			at + Vector2(5, -1), at + Vector2(0, -11), at + Vector2(-5, -1), at + Vector2(-13, -8)]), Style.GOLD)
	else:
		_text(ci, str(stages.find(stage) + 1), at + Vector2(0, 7), 20, Style.TEXT)
	_name_tag(ci, stage.name, at + Vector2(0, radius + 20.0), Style.TEXT if state != "locked" else Style.MUTED)


func _lab_label(ci: Control) -> void:
	var at: Vector2 = _at(laboratory.map_pos)
	var color: Color = Style.GOLD if _hover == LAB_ID else Style.TEXT
	_name_tag(ci, laboratory.name, at + Vector2(-14, 18), color)
	var line: String = "Golems %d / %d" % [party_looks.size(), golem_slots]
	if core_ready:
		line = "Golem core ready!"
	_text(ci, line, at + Vector2(-14, 36), 13, Style.GOLD if core_ready else Style.MUTED)


## The built golems in a short file, the leader in front; they bob as they walk.
func _party(ci: Control) -> void:
	for i in range(party_looks.size() - 1, -1, -1):
		var at: Vector2 = _party_pos + Vector2(-30.0 * i, -7.0 * i)
		if _walking:
			at.y -= abs(sin(_time * 9.0 + i * 1.3)) * 3.0
		var shadow := PackedVector2Array()
		for k in range(16):
			var a: float = TAU * k / 16.0
			shadow.append(at + Vector2(cos(a) * 19.0, sin(a) * 5.5))
		ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
		GolemArt.draw(ci, at, PARTY_SCALE, 1.0, party_looks[i], {"time": _time + i * 0.7})


func _name_tag(ci: Control, text: String, centre: Vector2, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var box := Rect2(centre + Vector2(-width / 2.0 - 7.0, -14.0), Vector2(width + 14.0, 20.0))
	ci.draw_rect(box, Color(0.05, 0.05, 0.07, 0.72))
	ci.draw_rect(box, Color(1, 1, 1, 0.08), false, 1.0)
	_text(ci, text, centre + Vector2(0, 1), 15, color)


func _text(ci: Control, text: String, baseline_centre: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at: Vector2 = baseline_centre - Vector2(width / 2.0, 0)
	ci.draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
