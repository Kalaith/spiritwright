extends RefCounted
## The ground a battle stands on: mossy flagstones, fen pools, cracked steppe,
## packed snow and ice, wet slate under the storm, or the Crucible's sand ring.
## Depth runs 0 at the horizon to 1 at the front of the field.

const Backdrop = preload("res://scripts/ui/battle_backdrop.gd")

## Fen pools: [x fraction, depth fraction, radius x, radius y]. The weather layer ripples them.
const POOLS: Array = [[0.1, 0.3, 110, 16], [0.36, 0.52, 80, 13], [0.62, 0.2, 70, 10], [0.88, 0.62, 130, 20],
	[0.24, 0.86, 120, 18], [0.72, 0.9, 90, 14]]
## Storm puddles, in the same form.
const PUDDLES: Array = [[0.14, 0.42, 70, 10], [0.42, 0.78, 90, 13], [0.66, 0.36, 60, 9], [0.9, 0.84, 80, 12]]


static func draw(ci: CanvasItem, area: Vector2, horizon: float, bottom: float, scene: String, pal: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene + "ground")
	var depth: float = bottom - horizon
	match scene:
		"fen":
			_fen(ci, area, horizon, depth, pal, rng)
		"steppe":
			_steppe(ci, area, horizon, depth, pal, rng)
		"frost":
			_frost(ci, area, horizon, depth, pal, rng)
		"storm":
			flagstones(ci, area, horizon, bottom, Color(1, 1, 1, 0.05))
			for puddle in PUDDLES:
				var at := Vector2(area.x * puddle[0], horizon + depth * puddle[1])
				Backdrop.ellipse(ci, at, puddle[2], puddle[3], Color(pal.patch))
				Backdrop.ellipse(ci, at + Vector2(-puddle[2] * 0.2, -2), puddle[2] * 0.5, puddle[3] * 0.35, Color(pal.haze, 0.12))
		"crucible":
			_crucible(ci, area, horizon, depth, pal, rng)
		_:
			for i in range(8):
				var at := Vector2(rng.randf_range(0, area.x), horizon + depth * rng.randf_range(0.05, 1.0))
				var r: float = rng.randf_range(50, 110)
				Backdrop.ellipse(ci, at, r, r * 0.16, Color(pal.patch, 0.8))
				Backdrop.ellipse(ci, at + Vector2(r * 0.25, 1), r * 0.6, r * 0.1, Color(pal.patch, 0.8))
			flagstones(ci, area, horizon, bottom, Color(1, 1, 1, 0.045))
			_tufts(ci, area, horizon, depth, Color(pal.patch).lightened(0.25), rng, 50)


## Rows widening toward the viewer, joints converging on a vanishing point.
static func flagstones(ci: CanvasItem, area: Vector2, horizon: float, bottom: float, seam: Color) -> void:
	var depth: float = bottom - horizon
	var vanish := Vector2(area.x / 2.0, horizon - depth * 1.4)
	for i in range(1, 10):
		var y: float = horizon + pow(i / 9.0, 1.6) * depth
		ci.draw_line(Vector2(0, y), Vector2(area.x, y), seam, 1.0)
	for i in range(-12, 13):
		var foot := Vector2(area.x / 2.0 + i * 120.0, bottom)
		var top: Vector2 = vanish.lerp(foot, (horizon - vanish.y) / (bottom - vanish.y))
		ci.draw_line(top, foot, seam, 1.0)


static func _tufts(ci: CanvasItem, area: Vector2, horizon: float, depth: float, color: Color,
		rng: RandomNumberGenerator, count: int) -> void:
	for i in range(count):
		var d: float = rng.randf_range(0.0, 1.0)
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * d)
		var h: float = 3.0 + 6.0 * d
		for k in range(3):
			ci.draw_line(at, at + Vector2((k - 1) * h * 0.4, -h * rng.randf_range(0.7, 1.0)), Color(color, 0.5), 1.0)


static func _fen(ci: CanvasItem, area: Vector2, horizon: float, depth: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var water: Color = Color(pal.patch)
	for pool in POOLS:
		var at := Vector2(area.x * pool[0], horizon + depth * pool[1])
		Backdrop.ellipse(ci, at, pool[2] + 6, pool[3] + 3, Color(pal.floor[0]).darkened(0.3))
		Backdrop.ellipse(ci, at, pool[2], pool[3], water)
		# The sky's light caught on the surface.
		Backdrop.ellipse(ci, at + Vector2(pool[2] * 0.15, -pool[3] * 0.2), pool[2] * 0.55, pool[3] * 0.3, Color(pal.haze, 0.1))
		for k in range(3):
			var pad: Vector2 = at + Vector2(rng.randf_range(-0.7, 0.7) * pool[2], rng.randf_range(-0.4, 0.4) * pool[3])
			Backdrop.ellipse(ci, pad, 7, 3, Color("2f5a34"))
	for i in range(26):
		var d: float = rng.randf_range(0.05, 1.0)
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * d)
		var h: float = 10.0 + 22.0 * d
		for k in range(5):
			ci.draw_line(at + Vector2(k * 2.0 - 4.0, 0), at + Vector2((k - 2) * 3.0, -h * rng.randf_range(0.6, 1.0)), Color("2a4a30"), 1.5)
	_tufts(ci, area, horizon, depth, Color("3a5a3c"), rng, 60)


static func _steppe(ci: CanvasItem, area: Vector2, horizon: float, depth: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	for i in range(10):
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * rng.randf_range(0.05, 1.0))
		var r: float = rng.randf_range(50, 120)
		Backdrop.ellipse(ci, at, r, r * 0.15, Color(pal.patch))
	# Cracks in the baked earth, some still glowing from below.
	var glow: Color = Color(pal.haze)
	for i in range(34):
		var d: float = rng.randf_range(0.02, 1.0)
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * d)
		var points := PackedVector2Array([at])
		for k in range(rng.randi_range(3, 6)):
			at += Vector2(rng.randf_range(8, 22) * (1.0 + d), rng.randf_range(-4, 4) * (0.5 + d))
			points.append(at)
		ci.draw_polyline(points, Color(0, 0, 0, 0.45), 2.0 + d * 1.5)
		if i % 3 == 0:
			ci.draw_polyline(points, Color(glow, 0.35), 1.0 + d)
	for i in range(40):
		var d: float = rng.randf_range(0.0, 1.0)
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * d)
		var r: float = 1.5 + 3.5 * d
		Backdrop.ellipse(ci, at, r * 1.4, r, Color(pal.edge).darkened(0.2))
		ci.draw_circle(at + Vector2(-r * 0.4, -r * 0.4), r * 0.4, Color(pal.edge, 0.6))


static func _frost(ci: CanvasItem, area: Vector2, horizon: float, depth: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	# Wind-packed drifts and polished ice between them.
	for i in range(9):
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * rng.randf_range(0.05, 1.0))
		var r: float = rng.randf_range(60, 140)
		Backdrop.ellipse(ci, at, r, r * 0.14, Color(pal.patch, 0.6))
		Backdrop.ellipse(ci, at + Vector2(-r * 0.15, -r * 0.03), r * 0.7, r * 0.07, Color(pal.edge, 0.12))
	for i in range(30):
		var d: float = rng.randf_range(0.05, 1.0)
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * d)
		var length: float = 20.0 + 60.0 * d
		ci.draw_line(at, at + Vector2(length, -length * 0.05), Color(pal.edge, 0.12), 1.0)
	for i in range(18):
		var d: float = rng.randf_range(0.05, 1.0)
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * d)
		var points := PackedVector2Array([at])
		for k in range(4):
			at += Vector2(rng.randf_range(6, 16), rng.randf_range(-5, 5)) * (0.6 + d)
			points.append(at)
		ci.draw_polyline(points, Color(pal.edge, 0.22), 1.0)
	flagstones(ci, area, horizon, horizon + depth, Color(1, 1, 1, 0.02))


static func _crucible(ci: CanvasItem, area: Vector2, horizon: float, depth: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var centre := Vector2(area.x / 2.0, horizon + depth * 0.62)
	var line: Color = Color(pal.haze)
	Backdrop.ellipse(ci, centre, area.x * 0.46, depth * 0.56, Color(pal.patch, 0.35))
	for ring in [[0.46, 0.56, 0.28, 3.0], [0.43, 0.52, 0.12, 1.5], [0.12, 0.14, 0.18, 2.0]]:
		var points := PackedVector2Array()
		for i in range(65):
			var a: float = TAU * i / 64.0
			points.append(centre + Vector2(cos(a) * area.x * ring[0], sin(a) * depth * ring[1]))
		ci.draw_polyline(points, Color(line, ring[2]), ring[3], true)
	# Raked sand: faint arcs following the ring.
	for i in range(14):
		var r: float = rng.randf_range(0.15, 0.42)
		var start: float = rng.randf_range(0, TAU)
		var points := PackedVector2Array()
		for k in range(12):
			var a: float = start + k * 0.06
			points.append(centre + Vector2(cos(a) * area.x * r, sin(a) * depth * r * 1.2))
		ci.draw_polyline(points, Color(0, 0, 0, 0.18), 1.0)
	for i in range(50):
		var at := Vector2(rng.randf_range(0, area.x), horizon + depth * rng.randf_range(0, 1))
		ci.draw_circle(at, rng.randf_range(1, 2.5), Color(pal.edge, 0.35))
