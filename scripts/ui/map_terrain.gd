extends RefCounted
## The ground of a region map: earth and moss patches, an optional stream,
## broken walls, woods at the edges and a dark vignette. Colours and layout come
## from the region's "terrain" block in campaign.json; scatter comes from its
## fixed seed, so the map is identical every time it is drawn. Positions are in
## the map's authored 860x560 space.

const ROCK_LIGHT_SHIFT: float = 0.25
const WALL_EDGE_SHIFT: float = 0.2


static func draw(ci: CanvasItem, size: Vector2, offset: Vector2, terrain: Dictionary) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(terrain.ground))
	var patches: Array = terrain.patches.map(func(c): return Color(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.seed)
	# Patches of moss and bare earth over the whole control, not just the authored area.
	for i in range(int(size.x * size.y / 4200.0)):
		var at := Vector2(rng.randf_range(-30, size.x + 30), rng.randf_range(-30, size.y + 30))
		var color: Color = patches[rng.randi_range(0, patches.size() - 1)]
		if rng.randf() < 0.18:
			color = Color(terrain.dirt)
		_blob(ci, at, rng.randf_range(18, 60), rng.randf_range(0.45, 0.8), rng.randf() * TAU, color, rng)
	_stream(ci, offset, terrain)
	var rock: Color = Color(terrain.rock)
	for wall in terrain.walls:
		_wall(ci, offset + _v(wall[0]), offset + _v(wall[1]), wall[2], rng, Color(terrain.wall), rock)
	for i in range(int(size.x * size.y / 9000.0)):
		_rock(ci, Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y)), rng.randf_range(3, 9), rng, rock)
	var grass: Color = patches[0].lightened(0.25)
	for i in range(int(size.x * size.y / 2500.0)):
		var at := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var tuft: Color = grass.lerp(grass.lightened(0.2), rng.randf())
		for k in range(3):
			ci.draw_line(at, at + Vector2((k - 1) * 3.0, -rng.randf_range(4, 8)), Color(tuft, 0.7), 1.0)
	var canopy: Array = terrain.canopy.map(func(c): return Color(c))
	for wood in terrain.woods:
		_woods(ci, offset + _v(wood[0]), wood[1], rng, canopy)


## Moving light on the water; drawn every frame above the static ground.
static func draw_live(ci: CanvasItem, offset: Vector2, time: float, terrain: Dictionary) -> void:
	var stream: Array = terrain.stream
	var shine: Color = Color(terrain.water).lightened(0.4)
	for i in range(stream.size() - 1):
		var a: Vector2 = offset + _v(stream[i])
		var b: Vector2 = offset + _v(stream[i + 1])
		var t: float = fposmod(time * 0.35 + i * 0.37, 1.0)
		var at: Vector2 = a.lerp(b, t)
		var along: Vector2 = (b - a).normalized() * 7.0
		ci.draw_line(at - along, at + along, Color(shine, 0.55 * sin(t * PI)), 2.0, true)


## Darkens the edges so the eye settles on the path.
static func vignette(ci: CanvasItem, size: Vector2) -> void:
	var steps: int = 10
	for i in range(steps):
		var inset: float = i * 6.0
		var alpha: float = 0.09 * (1.0 - float(i) / steps)
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		ci.draw_rect(rect, Color(0, 0, 0, alpha), false, 6.0)


## A dark cloud over a part of the map the player has not reached yet.
static func fog(ci: CanvasItem, at: Vector2, terrain: Dictionary) -> void:
	var dark: Color = Color(terrain.ground).darkened(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.y)
	for i in range(9):
		var p: Vector2 = at + Vector2(rng.randf_range(-60, 60), rng.randf_range(-80, 10))
		ci.draw_circle(p, rng.randf_range(26, 44), Color(dark, 0.42))


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


static func _stream(ci: CanvasItem, offset: Vector2, terrain: Dictionary) -> void:
	if terrain.stream.is_empty():
		return
	var water: Color = Color(terrain.water)
	var points := PackedVector2Array()
	for point in terrain.stream:
		points.append(offset + _v(point))
	ci.draw_polyline(points, Color(terrain.ground).darkened(0.1), 30.0, true)
	ci.draw_polyline(points, Color(water, 0.85), 20.0, true)
	ci.draw_polyline(points, water.lightened(0.1), 9.0, true)
	for point in points:
		ci.draw_circle(point, 10.0, Color(water, 0.85))
	# Stepping stones at every third bend.
	for i in range(2, points.size() - 1, 3):
		var p: Vector2 = points[i]
		ci.draw_circle(p + Vector2(-5, 2), 4.0, Color(terrain.rock))
		ci.draw_circle(p + Vector2(6, -2), 3.5, Color(terrain.rock))


static func _wall(ci: CanvasItem, a: Vector2, b: Vector2, height: float, rng: RandomNumberGenerator, wall: Color,
		rock: Color) -> void:
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
			ci.draw_colored_polygon(block, wall)
			ci.draw_line(block[3], block[2], wall.lightened(WALL_EDGE_SHIFT), 2.0)
		x += w
	# Rubble at the foot of the wall.
	for i in range(int(length / 26.0)):
		_rock(ci, a + along * rng.randf_range(0, length) + Vector2(0, rng.randf_range(3, 9)), rng.randf_range(3, 6), rng, rock)


static func _rock(ci: CanvasItem, at: Vector2, radius: float, rng: RandomNumberGenerator, rock: Color) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var a: float = TAU * i / 6.0 + rng.randf() * 0.4
		points.append(at + Vector2(cos(a), sin(a) * 0.7) * radius * rng.randf_range(0.8, 1.15))
	ci.draw_colored_polygon(points, rock)
	ci.draw_line(points[3], points[4], rock.lightened(ROCK_LIGHT_SHIFT), 1.2)
	ci.draw_line(points[4], points[5], rock.lightened(ROCK_LIGHT_SHIFT), 1.2)


static func _woods(ci: CanvasItem, centre: Vector2, radius: float, rng: RandomNumberGenerator, canopy: Array) -> void:
	for i in range(int(radius / 6.0)):
		var at: Vector2 = centre + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius) * 0.8)
		var r: float = rng.randf_range(14, 26)
		ci.draw_circle(at + Vector2(3, 5), r, Color(0, 0, 0, 0.3))
		ci.draw_circle(at, r, canopy[rng.randi_range(0, canopy.size() - 1)])
		ci.draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.025))
