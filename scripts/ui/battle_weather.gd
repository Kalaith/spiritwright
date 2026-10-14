extends Control
## What moves in a battle's scene, drawn behind the golems every frame: spores
## over the Ruins, fireflies and lantern light in the Fen, embers on the Steppe,
## snow and aurora in the Frostspine, rain and lightning at the Storm Crown, and
## brazier fire in the Crucible. Purely decorative: each particle's path is a
## function of time and its index, so nothing here is stored or simulated.

const Backdrop = preload("res://scripts/ui/battle_backdrop.gd")
const Horizons = preload("res://scripts/ui/battle_horizons.gd")
const Grounds = preload("res://scripts/ui/battle_grounds.gd")
const LIGHTNING_EVERY: float = 5.5

var scene: String = "ruins"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var pal: Dictionary = Backdrop.palette(scene)
	var horizon: float = Backdrop.horizon_for(size)
	var bottom: float = Backdrop.floor_bottom_for(size)
	match scene:
		"fen":
			_fen(t, horizon, bottom, pal)
		"steppe":
			_embers(t, horizon, bottom, 46)
		"frost":
			_aurora(t, horizon)
			_snow(t, bottom)
		"storm":
			_storm(t, horizon, bottom, pal)
		"crucible":
			_crucible(t, horizon)
		_:
			_spores(t, horizon, bottom, Color(pal.patch).lightened(0.55))


## A fixed pseudo-random number in [0, 1) for particle `i`, property `k`.
static func _h(i: int, k: int) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


func _spores(t: float, horizon: float, bottom: float, color: Color) -> void:
	var span: float = bottom - horizon + 120.0
	for i in range(30):
		var x: float = fposmod(_h(i, 1) * size.x + t * (5.0 + 10.0 * _h(i, 2)), size.x)
		var y: float = bottom - fposmod(_h(i, 3) * span + t * (4.0 + 8.0 * _h(i, 4)), span)
		x += sin(t * 0.9 + i) * 8.0
		var alpha: float = 0.25 + 0.35 * sin(t * (1.0 + _h(i, 5)) + i * 2.1)
		var r: float = 1.2 + 1.4 * _h(i, 6)
		draw_circle(Vector2(x, y), r * 3.0, Color(color, alpha * 0.15))
		draw_circle(Vector2(x, y), r, Color(color, alpha))


func _fen(t: float, horizon: float, bottom: float, pal: Dictionary) -> void:
	var depth: float = bottom - horizon
	# Mist drifting low over the water.
	for i in range(5):
		var x: float = fposmod(_h(i, 1) * size.x + t * (8.0 + 6.0 * _h(i, 2)), size.x + 600.0) - 300.0
		var y: float = horizon + depth * (0.1 + 0.2 * i)
		Backdrop.ellipse(self, Vector2(x, y), 260, 18 + 6 * i, Color(pal.haze, 0.035))
	for i in range(Grounds.POOLS.size()):
		var pool: Array = Grounds.POOLS[i]
		var phase: float = fposmod(t * 0.35 + i * 0.37, 1.0)
		_ring(Vector2(size.x * pool[0], horizon + depth * pool[1]), pool[2] * 0.25 * (0.3 + phase),
			pool[3] * 0.25 * (0.3 + phase), Color(pal.haze, 0.3 * (1.0 - phase)))
	for i in range(Horizons.LANTERNS.size()):
		var lantern: Array = Horizons.LANTERNS[i]
		var at := Vector2(size.x * lantern[0] + 16.0, horizon - lantern[1] + 11.0)
		var flicker: float = 0.85 + 0.15 * sin(t * 7.0 + i * 3.0) * sin(t * 2.3 + i)
		Backdrop.glow(self, at, 46.0 * flicker, Color("ffcf6a"), 1.2)
		draw_rect(Rect2(at - Vector2(4, 5), Vector2(8, 10)), Color("ffdf8a", flicker))
	for i in range(26):
		var base := Vector2(_h(i, 1) * size.x, horizon - 50.0 + _h(i, 2) * (depth + 50.0))
		var at: Vector2 = base + Vector2(sin(t * (0.4 + _h(i, 3) * 0.5) + i) * 34.0, cos(t * (0.5 + _h(i, 4) * 0.4) + i * 1.7) * 16.0)
		var blink: float = pow(max(0.0, sin(t * (0.8 + _h(i, 5)) + i * 2.3)), 2.0)
		draw_circle(at, 9.0, Color(0.9, 0.95, 0.45, 0.12 * blink))
		draw_circle(at, 2.0, Color(0.95, 1.0, 0.6, 0.9 * blink))


func _embers(t: float, horizon: float, bottom: float, count: int) -> void:
	var span: float = bottom - horizon + 200.0
	for i in range(count):
		var rise: float = fposmod(_h(i, 1) * span + t * (24.0 + 30.0 * _h(i, 2)), span)
		var y: float = bottom - rise
		var x: float = _h(i, 3) * size.x + sin(t * 1.4 + i) * 14.0 + rise * 0.12
		var fade: float = clampf(1.0 - rise / span, 0.0, 1.0) * (0.6 + 0.4 * sin(t * 9.0 + i))
		var color: Color = Color("ffcf6a").lerp(Color("ff6a2a"), _h(i, 4))
		draw_circle(Vector2(x, y), 5.0, Color(color, 0.12 * fade))
		draw_circle(Vector2(x, y), 1.4 + _h(i, 5), Color(color, fade))


func _aurora(t: float, horizon: float) -> void:
	for band in range(3):
		var color: Color = [Color("7fffd4"), Color("8fd8ff"), Color("b9a6ff")][band]
		var points := PackedVector2Array()
		for k in range(33):
			var x: float = size.x * k / 32.0
			points.append(Vector2(x, horizon * (0.22 + band * 0.1) + sin(x * 0.006 + t * 0.35 + band * 1.7) * 18.0))
		draw_polyline(points, Color(color, 0.05), 26.0, true)
		draw_polyline(points, Color(color, 0.08), 8.0, true)


func _snow(t: float, bottom: float) -> void:
	for i in range(90):
		var near: float = _h(i, 1)
		var y: float = fposmod(_h(i, 2) * bottom + t * (20.0 + 40.0 * near), bottom + 20.0) - 10.0
		var x: float = fposmod(_h(i, 3) * size.x + t * 12.0 + sin(t * 0.8 + i) * 10.0, size.x)
		draw_circle(Vector2(x, y), 1.0 + 1.8 * near, Color(0.92, 0.96, 1.0, 0.35 + 0.5 * near))


func _storm(t: float, horizon: float, bottom: float, pal: Dictionary) -> void:
	var cycle: int = int(t / LIGHTNING_EVERY)
	var local: float = fposmod(t, LIGHTNING_EVERY)
	if local < 0.35:
		var strength: float = 1.0 - local / 0.35
		draw_rect(Rect2(0, 0, size.x, horizon), Color(pal.haze, 0.22 * strength))
		draw_rect(Rect2(0, horizon, size.x, bottom - horizon), Color(pal.haze, 0.06 * strength))
		if local < 0.2:
			var at := Vector2(size.x * (0.15 + 0.7 * _h(cycle, 7)), 0)
			var points := PackedVector2Array([at])
			while at.y < horizon - 30.0:
				at += Vector2((_h(cycle * 13 + points.size(), 8) - 0.5) * 40.0, 22.0)
				points.append(at)
			draw_polyline(points, Color(pal.haze, 0.5 * strength), 6.0)
			draw_polyline(points, Color(1, 1, 1, strength), 2.0)
	for i in range(110):
		var y: float = fposmod(_h(i, 1) * bottom + t * (520.0 + 200.0 * _h(i, 2)), bottom + 40.0) - 20.0
		var x: float = fposmod(_h(i, 3) * (size.x + 200.0) - y * 0.22, size.x + 200.0) - 100.0
		draw_line(Vector2(x, y), Vector2(x - 4.0, y + 16.0), Color(0.75, 0.8, 1.0, 0.18), 1.0)
	# Splashes where the rain lands.
	for i in range(18):
		var phase: float = fposmod(t * 2.0 + _h(i, 4), 1.0)
		var round_index: int = int(t * 2.0 + _h(i, 4))
		var at := Vector2(_h(i + round_index * 31, 5) * size.x, horizon + (bottom - horizon) * _h(i + round_index * 17, 6))
		_ring(at, 2.0 + 8.0 * phase, 1.0 + 2.5 * phase, Color(0.8, 0.85, 1.0, 0.3 * (1.0 - phase)))


func _crucible(t: float, horizon: float) -> void:
	for i in range(Horizons.BRAZIERS.size()):
		var brazier: Array = Horizons.BRAZIERS[i]
		var base := Vector2(size.x * brazier[0], horizon - brazier[1] - 10.0)
		Backdrop.glow(self, base + Vector2(0, -10), 40.0 + 6.0 * sin(t * 8.0 + i), Color("ffb347"), 1.0)
		for layer in [[Color("e8502a"), 1.0], [Color("ffb347"), 0.7], [Color("fff0b0"), 0.38]]:
			var points := PackedVector2Array([base + Vector2(-16 * layer[1], 0)])
			for k in range(5):
				var x: float = (k - 2) * 8.0 * layer[1]
				var lick: float = 26.0 + 10.0 * sin(t * (9.0 + k) + i * 2.0 + k)
				points.append(base + Vector2(x, -lick * layer[1] * (1.0 - abs(k - 2) * 0.22)))
			points.append(base + Vector2(16 * layer[1], 0))
			draw_colored_polygon(points, layer[0])
		# Sparks lifting off the fire.
		for k in range(8):
			var rise: float = fposmod(t * (30.0 + 20.0 * _h(i * 8 + k, 1)) + _h(i * 8 + k, 2) * 120.0, 120.0)
			var at: Vector2 = base + Vector2(sin(t * 2.0 + k) * 10.0 + (_h(i * 8 + k, 3) - 0.5) * 30.0, -20.0 - rise)
			draw_circle(at, 1.5, Color("ffcf6a", 1.0 - rise / 120.0))


## An ellipse outline, for ripples and splashes.
func _ring(centre: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(17):
		var angle: float = TAU * i / 16.0
		points.append(centre + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polyline(points, color, 1.0, true)
