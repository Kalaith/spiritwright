extends RefCounted
## What stands on each battle's horizon: ruined columns, fen trees and lanterns,
## steppe mesas and kilns, frost peaks, the broken Storm Crown, or the Crucible's
## tiered walls. Positions are fractions of the width; heights are in pixels.

const Backdrop = preload("res://scripts/ui/battle_backdrop.gd")

## [x fraction, width, height, broken-top tilt]
const COLUMNS: Array = [[0.05, 34, 120, 8], [0.17, 26, 70, -6], [0.31, 30, 140, 0], [0.44, 22, 52, 10],
	[0.58, 28, 96, -9], [0.7, 34, 150, 0], [0.83, 24, 64, 7], [0.95, 30, 110, -5]]
## [left column index, right column index]: arches spring from the shorter column.
const ARCHES: Array = [[0, 1], [6, 7]]
## Fen lantern posts: [x fraction, post height]. The weather layer makes them flicker.
const LANTERNS: Array = [[0.12, 74], [0.4, 52], [0.66, 64], [0.9, 80]]
## Steppe kilns: [x fraction, width, height]. Their mouths glow.
const KILNS: Array = [[0.2, 46, 96], [0.76, 54, 120]]
## Crucible braziers: [x fraction, pillar height]. The weather layer lights them.
const BRAZIERS: Array = [[0.08, 70], [0.3, 56], [0.7, 56], [0.92, 70]]


static func draw(ci: CanvasItem, area: Vector2, horizon: float, scene: String, pal: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene)
	match scene:
		"fen":
			_fen(ci, area, horizon, pal, rng)
		"steppe":
			_steppe(ci, area, horizon, pal, rng)
		"frost":
			_frost(ci, area, horizon, pal, rng)
		"storm":
			_storm(ci, area, horizon, pal, rng)
		"crucible":
			_crucible(ci, area, horizon, pal)
		_:
			_ruins(ci, area, horizon, pal, rng)


## A jagged skyline: `count` points between `low` and `high` above the horizon.
static func ridge(ci: CanvasItem, area: Vector2, horizon: float, low: float, high: float, count: int,
		color: Color, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(0, horizon + 2)])
	for i in range(count + 1):
		points.append(Vector2(area.x * i / count, horizon - rng.randf_range(low, high)))
	points.append(Vector2(area.x, horizon + 2))
	ci.draw_colored_polygon(points, color)
	return points


static func _ruins(ci: CanvasItem, area: Vector2, horizon: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	ridge(ci, area, horizon, 18, 46, 14, Color(pal.far), rng)
	var ruin: Color = Color(pal.near)
	var edge: Color = Color(pal.edge)
	var moss: Color = Color(pal.patch)
	for arch in ARCHES:
		var left: Array = COLUMNS[arch[0]]
		var right: Array = COLUMNS[arch[1]]
		var x0: float = area.x * left[0]
		var x1: float = area.x * right[0]
		var centre := Vector2((x0 + x1) / 2.0, horizon - min(left[2], right[2]) + 6.0)
		ci.draw_arc(centre, (x1 - x0) / 2.0, PI, TAU, 40, ruin, 22.0, true)
		ci.draw_arc(centre, (x1 - x0) / 2.0 + 11.0, PI + 0.05, TAU - 0.05, 40, edge, 2.0, true)
	for column in COLUMNS:
		var x: float = area.x * column[0]
		var w: float = column[1]
		var h: float = column[2]
		var tilt: float = column[3]
		var shape := PackedVector2Array([Vector2(x - w / 2.0, horizon), Vector2(x + w / 2.0, horizon),
			Vector2(x + w / 2.0, horizon - h + tilt), Vector2(x - w / 2.0, horizon - h - tilt)])
		ci.draw_colored_polygon(shape, ruin)
		# Lit from the left: a pale rim on one side, shade on the other.
		ci.draw_line(shape[3], shape[0], edge, 2.0)
		ci.draw_line(shape[2], shape[3], edge, 2.0)
		ci.draw_rect(Rect2(x + w / 6.0, horizon - h + 14, w / 3.0, h - 22), Color(0, 0, 0, 0.18))
		ci.draw_line(Vector2(x - w / 6.0, horizon - 8), Vector2(x - w / 6.0, horizon - h + 14), Color(edge, 0.5), 1.0)
		ci.draw_rect(Rect2(x - w / 2.0 - 5.0, horizon - 10.0, w + 10.0, 10.0), edge)
		for k in range(int(h / 22.0)):
			var at := Vector2(x + (w / 3.0) * sin(k * 1.9 + x), horizon - h + 10.0 + k * 20.0)
			ci.draw_circle(at, 4.0, moss)
			ci.draw_circle(at + Vector2(-1, -1), 2.0, moss.lightened(0.2))
	# Fallen blocks at the foot of the ruins.
	for i in range(10):
		var at := Vector2(rng.randf_range(0, area.x), horizon + rng.randf_range(2, 10))
		var w: float = rng.randf_range(12, 26)
		ci.draw_rect(Rect2(at.x, at.y - 8, w, 9), ruin)
		ci.draw_line(Vector2(at.x, at.y - 8), Vector2(at.x + w, at.y - 8), edge, 1.0)


static func _fen(ci: CanvasItem, area: Vector2, horizon: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	# A far treeline of rounded crowns, then mist lying over it.
	var far: Color = Color(pal.far)
	for i in range(int(area.x / 26.0)):
		var x: float = i * 26.0 + rng.randf_range(-8, 8)
		ci.draw_circle(Vector2(x, horizon - rng.randf_range(18, 40)), rng.randf_range(18, 30), far)
	ci.draw_rect(Rect2(0, horizon - 24, area.x, 26), far)
	Backdrop.gradient(ci, Rect2(0, horizon - 36, area.x, 36), Color(pal.haze, 0.0), Color(pal.haze, 0.09))
	# Dead trees leaning out of the water.
	var near: Color = Color(pal.near)
	for spec in [[0.04, 150, -0.12], [0.27, 96, 0.08], [0.55, 120, -0.05], [0.83, 170, 0.1]]:
		var base := Vector2(area.x * spec[0], horizon + 4)
		var top: Vector2 = base + Vector2(spec[1] * spec[2], -spec[1])
		ci.draw_line(base, top, near, 9.0)
		ci.draw_line(base + Vector2(-8, 0), base + Vector2(8, 0), near, 6.0)
		for k in range(4):
			var from: Vector2 = base.lerp(top, 0.45 + k * 0.15)
			var side: float = -1.0 if k % 2 == 0 else 1.0
			var tip: Vector2 = from + Vector2(side * rng.randf_range(20, 38), -rng.randf_range(10, 26))
			ci.draw_line(from, tip, near, 4.0 - k * 0.6)
			ci.draw_line(tip, tip + Vector2(side * 8, rng.randf_range(-8, 4)), near, 2.0)
	# Reeds along the waterline.
	for i in range(70):
		var x: float = rng.randf_range(0, area.x)
		var h: float = rng.randf_range(10, 30)
		ci.draw_line(Vector2(x, horizon + 6), Vector2(x + rng.randf_range(-5, 5), horizon + 6 - h), near.lightened(0.1), 1.5)
	for lantern in LANTERNS:
		var x: float = area.x * lantern[0]
		var top := Vector2(x, horizon - lantern[1])
		ci.draw_line(Vector2(x, horizon + 6), top, near, 4.0)
		ci.draw_line(top, top + Vector2(16, 0), near, 3.0)
		ci.draw_rect(Rect2(top + Vector2(10, 4), Vector2(12, 14)), near.lightened(0.15))


static func _steppe(ci: CanvasItem, area: Vector2, horizon: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	# A swollen sun sinking behind the mesas.
	var sun := Vector2(area.x * 0.62, horizon - 30)
	Backdrop.glow(ci, sun, 210, Color(pal.haze), 1.2)
	ci.draw_circle(sun, 64, Color("e8673a"))
	ci.draw_circle(sun + Vector2(-8, -8), 52, Color("f08a4c"))
	for i in range(4):
		ci.draw_rect(Rect2(sun.x - 80, sun.y + 6 + i * 11, 160, 3 + i), Color(pal.sky[1]))
	# Flat-topped mesas, far and near.
	for layer in [[Color(pal.far), 40, 90, 0.0], [Color(pal.near), 20, 54, 0.5]]:
		var x: float = -40.0 + layer[3] * 120.0
		while x < area.x:
			var w: float = rng.randf_range(90, 220)
			var h: float = rng.randf_range(layer[1], layer[2])
			var slope: float = rng.randf_range(14, 30)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, horizon + 2), Vector2(x + slope, horizon - h),
				Vector2(x + w - slope, horizon - h), Vector2(x + w, horizon + 2)]), layer[0])
			ci.draw_line(Vector2(x + slope, horizon - h), Vector2(x + w - slope, horizon - h), Color(pal.edge, 0.7), 2.0)
			x += w + rng.randf_range(30, 160)
	# Kilns: tapering stacks with a glowing mouth and a smoke plume.
	var near: Color = Color(pal.near).darkened(0.2)
	for kiln in KILNS:
		var x: float = area.x * kiln[0]
		var w: float = kiln[1]
		var h: float = kiln[2]
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - w / 2.0, horizon + 4), Vector2(x + w / 2.0, horizon + 4),
			Vector2(x + w / 4.0, horizon - h), Vector2(x - w / 4.0, horizon - h)]), near)
		ci.draw_rect(Rect2(x - w / 4.0 - 4, horizon - h - 6, w / 2.0 + 8, 8), near.lightened(0.1))
		var mouth := Vector2(x, horizon - 12)
		Backdrop.glow(ci, mouth, 40, Color(pal.haze), 1.4)
		ci.draw_colored_polygon(PackedVector2Array([mouth + Vector2(-10, 10), mouth + Vector2(10, 10),
			mouth + Vector2(10, -4), mouth + Vector2(0, -12), mouth + Vector2(-10, -4)]), Color("ff9a4d"))
		for k in range(6):
			var puff := Vector2(x + k * 9.0 + sin(k * 1.3) * 6.0, horizon - h - 14 - k * 16.0)
			ci.draw_circle(puff, 10.0 + k * 3.0, Color(0.12, 0.08, 0.08, 0.5 - k * 0.07))


static func _frost(ci: CanvasItem, area: Vector2, horizon: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	for layer in [[Color(pal.far), 70, 170, 9, 0.75], [Color(pal.near), 30, 100, 13, 0.45]]:
		var ridge_points: PackedVector2Array = ridge(ci, area, horizon, layer[1], layer[2], layer[3], layer[0], rng)
		# Snow on every peak: a cap down to a fraction of the slope on each side.
		var snow: Color = Color(pal.edge, layer[4])
		for i in range(2, ridge_points.size() - 2):
			var peak: Vector2 = ridge_points[i]
			if peak.y > ridge_points[i - 1].y or peak.y > ridge_points[i + 1].y:
				continue
			var left: Vector2 = peak.lerp(ridge_points[i - 1], 0.32)
			var right: Vector2 = peak.lerp(ridge_points[i + 1], 0.32)
			ci.draw_colored_polygon(PackedVector2Array([peak, right, peak.lerp(right, 0.5) + Vector2(0, 6), left.lerp(peak, 0.4) + Vector2(0, 9), left]), snow)
	# Pines on the near slopes.
	var pine: Color = Color(pal.near).darkened(0.35)
	for i in range(34):
		var at := Vector2(rng.randf_range(0, area.x), horizon + rng.randf_range(0, 6))
		var h: float = rng.randf_range(18, 42)
		for k in range(3):
			var y: float = at.y - h * k / 3.0
			var w: float = h * (0.36 - k * 0.09)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x - w, y), Vector2(at.x + w, y), Vector2(at.x, y - h * 0.5)]), pine)
		ci.draw_line(at + Vector2(-h * 0.2, -h * 0.66), at + Vector2(0, -h * 0.84), Color(pal.edge, 0.5), 1.5)


static func _storm(ci: CanvasItem, area: Vector2, horizon: float, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	# Banks of heavy cloud rolling low, darker underneath.
	var cloud: Color = Color(pal.far)
	for i in range(22):
		var at := Vector2(rng.randf_range(-60, area.x + 60), rng.randf_range(10, horizon * 0.5))
		var rx: float = rng.randf_range(90, 180)
		Backdrop.ellipse(ci, at + Vector2(0, 8), rx, rx * 0.22, Color(cloud.darkened(0.35), 0.7))
		Backdrop.ellipse(ci, at, rx * 0.8, rx * 0.2, Color(cloud, 0.75))
		Backdrop.ellipse(ci, at + Vector2(-rx * 0.15, -rx * 0.08), rx * 0.45, rx * 0.12, Color(cloud.lightened(0.1), 0.6))
	ridge(ci, area, horizon, 20, 70, 18, Color(pal.near).lightened(0.04), rng)
	# The Storm Crown: a shattered tower whose crown points still hold the lightning.
	var near: Color = Color(pal.near)
	var edge: Color = Color(pal.edge)
	var haze: Color = Color(pal.haze)
	var x: float = area.x * 0.5
	var rim: float = horizon - 150.0
	Backdrop.glow(ci, Vector2(x, rim - 14), 120, haze, 0.6)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 30, horizon + 4), Vector2(x + 30, horizon + 4),
		Vector2(x + 22, rim), Vector2(x - 22, rim)]), near)
	# Buttresses and a broken ledge.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 52, horizon + 4), Vector2(x - 28, horizon + 4), Vector2(x - 26, horizon - 50)]), near)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 52, horizon + 4), Vector2(x + 28, horizon + 4), Vector2(x + 26, horizon - 50)]), near)
	ci.draw_rect(Rect2(x - 32, rim - 6, 64, 10), near)
	for k in range(5):
		var px: float = x - 24 + k * 12
		var tip := Vector2(px, rim - 6 - [30, 16, 44, 10, 26][k])
		ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 6, rim - 4), Vector2(px + 6, rim - 4), tip]), near)
		Backdrop.glow(ci, tip, 14, haze, 1.2)
		ci.draw_circle(tip, 1.5, haze.lightened(0.5))
	ci.draw_line(Vector2(x - 22, rim), Vector2(x - 30, horizon + 4), edge, 2.0)
	ci.draw_line(Vector2(x - 32, rim - 6), Vector2(x + 32, rim - 6), edge, 2.0)
	for k in range(4):
		ci.draw_rect(Rect2(x - 4, rim + 20 + k * 30, 8, 12), Color(haze, 0.5))
	# Broken lesser towers either side.
	for spec in [[0.18, 80, 8], [0.32, 50, -6], [0.7, 64, 10], [0.86, 96, -8]]:
		var tx: float = area.x * spec[0]
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 16, horizon + 2), Vector2(tx + 16, horizon + 2),
			Vector2(tx + 13, horizon - spec[1] + spec[2]), Vector2(tx - 13, horizon - spec[1] - spec[2])]), near)
		ci.draw_line(Vector2(tx - 16, horizon + 2), Vector2(tx - 13, horizon - spec[1] - spec[2]), edge, 1.5)


static func _crucible(ci: CanvasItem, area: Vector2, horizon: float, pal: Dictionary) -> void:
	# Tiered arena walls with a row of dark arches, lit from the braziers below.
	var far: Color = Color(pal.far)
	var near: Color = Color(pal.near)
	var edge: Color = Color(pal.edge)
	for tier in range(3):
		var y: float = horizon - 150.0 + tier * 44.0
		ci.draw_rect(Rect2(0, y, area.x, horizon - y), far.lerp(near, tier / 2.0))
		ci.draw_line(Vector2(0, y), Vector2(area.x, y), Color(edge, 0.6), 2.0)
	var arch_count: int = int(area.x / 64.0)
	for i in range(arch_count):
		var x: float = (i + 0.5) * area.x / arch_count
		ci.draw_rect(Rect2(x - 14, horizon - 44, 28, 44), Color(0, 0, 0, 0.45))
		ci.draw_circle(Vector2(x, horizon - 44), 14, Color(0, 0, 0, 0.45))
		ci.draw_rect(Rect2(x - 4, horizon - 136, 8, 16), Color(0, 0, 0, 0.3))
	# Banners of the Crucible: gold and crimson, notched at the foot.
	for i in range(6):
		var x: float = area.x * (0.12 + i * 0.152)
		var color: Color = Color("b8903c") if i % 2 == 0 else Color("8a2a2a")
		var top: float = horizon - 146.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, top), Vector2(x + 14, top), Vector2(x + 14, top + 70),
			Vector2(x, top + 58), Vector2(x - 14, top + 70)]), color)
		ci.draw_line(Vector2(x - 18, top), Vector2(x + 18, top), edge.lightened(0.2), 3.0)
		ci.draw_circle(Vector2(x, top + 26), 6, Color(0, 0, 0, 0.3))
	for brazier in BRAZIERS:
		var x: float = area.x * brazier[0]
		var top: float = horizon - brazier[1]
		Backdrop.glow(ci, Vector2(x, top - 6), 90, Color(pal.haze), 1.0)
		ci.draw_rect(Rect2(x - 7, top, 14, brazier[1] + 4), near.darkened(0.3))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 20, top - 10), Vector2(x + 20, top - 10),
			Vector2(x + 10, top + 4), Vector2(x - 10, top + 4)]), edge.darkened(0.2))
