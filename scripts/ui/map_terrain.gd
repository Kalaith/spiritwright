extends RefCounted
## The ground of the region map: mossy earth, a stream that feeds the Sunken
## Court, broken walls, woods at the edges and a dark vignette. Shapes come from
## fixed tables or a fixed seed so the map is identical every time it is drawn.
## Positions in the tables are in the map's authored 860x560 space.

const GROUND := Color("1b2018")
const GROUND_DARK := Color("141812")
const MOSS: Array = [Color("24301e"), Color("2a3822"), Color("1f2a1a"), Color("303c25")]
const DIRT := Color("2c271d")
const ROCK := Color("3d3f44")
const ROCK_LIGHT := Color("5a5d64")
const WALL := Color("34363c")
const WALL_EDGE := Color("4b4e56")
const WATER := Color("17394d")
const WATER_LIGHT := Color("3f7f9e")
const CANOPY: Array = [Color("10180f"), Color("152013"), Color("1a2716")]
## The stream, from the top edge down into the court's pool and out west.
const STREAM: Array = [[372, -20], [362, 60], [348, 140], [338, 210], [330, 252], [280, 246], [210, 236],
	[150, 252], [80, 270], [-20, 258]]
## Broken walls: [start, end, height]. Gaps are left where the wall has fallen.
const WALLS: Array = [[[40, 110], [210, 96], 14], [[430, 500], [575, 520], 12], [[700, 300], [850, 286], 14],
	[[505, 60], [640, 48], 12]]
## Woods: [centre, radius] clumps of canopy.
const WOODS: Array = [[[30, 30], 70], [[120, -10], 60], [[860, 230], 80], [[880, 420], 90], [[830, 560], 70],
	[[-10, 560], 60], [[560, 600], 60], [[250, 590], 50], [[700, -20], 55]]


static func draw(ci: CanvasItem, size: Vector2, offset: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Patches of moss and bare earth over the whole control, not just the authored area.
	for i in range(int(size.x * size.y / 4200.0)):
		var at := Vector2(rng.randf_range(-30, size.x + 30), rng.randf_range(-30, size.y + 30))
		var color: Color = MOSS[rng.randi_range(0, MOSS.size() - 1)]
		if rng.randf() < 0.18:
			color = DIRT
		_blob(ci, at, rng.randf_range(18, 60), rng.randf_range(0.45, 0.8), rng.randf() * TAU, color, rng)
	_stream(ci, offset)
	for wall in WALLS:
		_wall(ci, offset + _v(wall[0]), offset + _v(wall[1]), wall[2], rng)
	for i in range(int(size.x * size.y / 9000.0)):
		_rock(ci, Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y)), rng.randf_range(3, 9), rng)
	for i in range(int(size.x * size.y / 2500.0)):
		var at := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var tuft: Color = Color("3c5230").lerp(Color("526b38"), rng.randf())
		for k in range(3):
			ci.draw_line(at, at + Vector2((k - 1) * 3.0, -rng.randf_range(4, 8)), Color(tuft, 0.7), 1.0)
	for wood in WOODS:
		_woods(ci, offset + _v(wood[0]), wood[1], rng)


## Moving light on the water; drawn every frame above the static ground.
static func draw_live(ci: CanvasItem, offset: Vector2, time: float) -> void:
	for i in range(STREAM.size() - 1):
		var a: Vector2 = offset + _v(STREAM[i])
		var b: Vector2 = offset + _v(STREAM[i + 1])
		var t: float = fposmod(time * 0.35 + i * 0.37, 1.0)
		var at: Vector2 = a.lerp(b, t)
		var along: Vector2 = (b - a).normalized() * 7.0
		ci.draw_line(at - along, at + along, Color(WATER_LIGHT, 0.55 * sin(t * PI)), 2.0, true)


## Darkens the edges so the eye settles on the path.
static func vignette(ci: CanvasItem, size: Vector2) -> void:
	var steps: int = 10
	for i in range(steps):
		var inset: float = i * 6.0
		var alpha: float = 0.09 * (1.0 - float(i) / steps)
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		ci.draw_rect(rect, Color(0, 0, 0, alpha), false, 6.0)


## A dark cloud over a part of the map the player has not reached yet.
static func fog(ci: CanvasItem, at: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.y)
	for i in range(9):
		var p: Vector2 = at + Vector2(rng.randf_range(-60, 60), rng.randf_range(-80, 10))
		ci.draw_circle(p, rng.randf_range(26, 44), Color(GROUND_DARK, 0.42))


static func _v(point: Array) -> Vector2:
	return Vector2(point[0], point[1])


static func _blob(ci: CanvasItem, at: Vector2, radius: float, squash: float, angle: float, color: Color,
		rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in range(12):
		var a: float = TAU * i / 12.0
		var r: float = radius * rng.randf_range(0.75, 1.1)
		points.append(at + Vector2(cos(a) * r, sin(a) * r * squash).rotated(angle))
	ci.draw_colored_polygon(points, Color(color, 0.55))


static func _stream(ci: CanvasItem, offset: Vector2) -> void:
	var points := PackedVector2Array()
	for point in STREAM:
		points.append(offset + _v(point))
	ci.draw_polyline(points, Color("23301f"), 30.0, true)
	ci.draw_polyline(points, Color(WATER, 0.85), 20.0, true)
	ci.draw_polyline(points, Color("1d4860"), 9.0, true)
	for point in points:
		ci.draw_circle(point, 10.0, Color(WATER, 0.85))
	# Stepping stones where the stream bends.
	for i in [3, 6, 8]:
		var p: Vector2 = points[i]
		ci.draw_circle(p + Vector2(-5, 2), 4.0, ROCK)
		ci.draw_circle(p + Vector2(6, -2), 3.5, ROCK)


static func _wall(ci: CanvasItem, a: Vector2, b: Vector2, height: float, rng: RandomNumberGenerator) -> void:
	var length: float = a.distance_to(b)
	var along: Vector2 = (b - a).normalized()
	var x: float = 0.0
	while x < length:
		var w: float = rng.randf_range(14, 24)
		if rng.randf() < 0.2:
			x += w  # a fallen block leaves a gap
			continue
		var rows: int = 2 if rng.randf() < 0.6 else 1
		for r in range(rows):
			var base: Vector2 = a + along * (x + (6.0 if r == 1 else 0.0))
			var top := Vector2(0, -height * (r + 1))
			var block := PackedVector2Array([base + Vector2(0, -height * r), base + along * (w - 2.0) + Vector2(0, -height * r),
				base + along * (w - 2.0) + top, base + top])
			ci.draw_colored_polygon(block, WALL)
			ci.draw_line(block[3], block[2], WALL_EDGE, 2.0)
		x += w
	# Rubble at the foot of the wall.
	for i in range(int(length / 26.0)):
		_rock(ci, a + along * rng.randf_range(0, length) + Vector2(0, rng.randf_range(3, 9)), rng.randf_range(3, 6), rng)


static func _rock(ci: CanvasItem, at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var a: float = TAU * i / 6.0 + rng.randf() * 0.4
		points.append(at + Vector2(cos(a), sin(a) * 0.7) * radius * rng.randf_range(0.8, 1.15))
	ci.draw_colored_polygon(points, ROCK)
	ci.draw_line(points[3], points[4], ROCK_LIGHT, 1.2)
	ci.draw_line(points[4], points[5], ROCK_LIGHT, 1.2)


static func _woods(ci: CanvasItem, centre: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	for i in range(int(radius / 6.0)):
		var at: Vector2 = centre + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius) * 0.8)
		var r: float = rng.randf_range(14, 26)
		ci.draw_circle(at + Vector2(3, 5), r, Color(0, 0, 0, 0.3))
		ci.draw_circle(at, r, CANOPY[rng.randi_range(0, CANOPY.size() - 1)])
		ci.draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.025))
