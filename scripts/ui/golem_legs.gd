extends RefCounted
## Every set of legs, drawn through the golem_art instance so they share its
## origin, facing, scale and palette. Legs stay still while the body above
## the hips breathes.

const WOOD := Color("5b4a3a")
const STEEL := Color("c9ccd6")
## Matches golem_art.HIP_Y.
const HIP_Y: float = -34.0


static func draw(art: RefCounted, kind: String) -> void:
	match kind:
		"spider":
			_spider(art)
		"tower":
			_tower(art)
		"stilts":
			_stilts(art)
		"treads":
			_treads(art)
		"skates":
			_skates(art)
		_:
			_pillar(art)


## Two stout legs: thigh, a knee plate, shin and a toed foot.
static func _pillar(art: RefCounted) -> void:
	var dark: Color = art.base.darkened(0.2)
	for x in [-20.0, 6.0]:
		art._rect(x, HIP_Y + 6.0, 14.0, -HIP_Y - 14.0, dark)
		art._rect(x - 2.0, HIP_Y + 2.0, 18.0, 6.0, art.trim)
		art._mark([Vector2(x + 3.5, HIP_Y + 10.0), Vector2(x + 3.5, -12.0)], Color(art.base.lightened(0.25), 0.8), 1.5)
		art._poly([Vector2(x - 1.0, -22), Vector2(x + 15.0, -22), Vector2(x + 13.0, -15), Vector2(x + 1.0, -15)], art.trim.lightened(0.08))
		art._poly([Vector2(x - 4.0, -9), Vector2(x + 16.0, -9), Vector2(x + 22.0, -3), Vector2(x + 22.0, 0), Vector2(x - 4.0, 0)], art.trim)
		art._mark([Vector2(x - 2.0, -7.5), Vector2(x + 15.0, -7.5)], Color(art.base.lightened(0.35), 0.7), 1.2)


## Four jointed legs splayed wide, each ending in a claw.
static func _spider(art: RefCounted) -> void:
	var dark: Color = art.base.darkened(0.2)
	for side in [-1.0, 1.0]:
		for spread in [0.6, 1.0]:
			var hip := Vector2(10.0 * side * spread, HIP_Y + 4.0)
			var knee := Vector2(34.0 * side * spread, HIP_Y - 10.0)
			var foot := Vector2(42.0 * side * spread, 0.0)
			art._line(hip, knee, 5.0, dark)
			art._line(knee, foot, 4.0, dark)
			art._circle(knee.x, knee.y, 3.8, art.trim)
			art._poly([foot + Vector2(-3, -6), foot + Vector2(3, -6), foot], art.trim)
	art._rect(-14, HIP_Y - 2, 28, 10, art.trim)
	art._circle(0, HIP_Y + 3, 4.0, art.trim.lightened(0.15))


## Massive braced columns on wide splayed feet, tied by a bar: built to hold a line.
static func _tower(art: RefCounted) -> void:
	var dark: Color = art.base.darkened(0.2)
	art._rect(-28, HIP_Y - 3, 56, 10, art.trim)
	for x in [-1.0, 1.0]:
		var inner: float = 4.0 * x
		var outer: float = 24.0 * x
		art._poly([Vector2(inner, HIP_Y + 6), Vector2(outer, HIP_Y + 6), Vector2(outer + 4.0 * x, -8), Vector2(inner - 1.0 * x, -8)], dark)
		art._mark([Vector2(outer * 0.75, HIP_Y + 9), Vector2(outer * 0.8, -11)], Color(art.base.lightened(0.25), 0.8), 1.5)
		for y in [-26.0, -16.0]:
			art._mark([Vector2(inner + 1.0 * x, y), Vector2(outer + 2.0 * x, y)], art.trim.darkened(0.15), 2.0)
		# The buttress: a strut from the thigh down to a spur behind the foot.
		art._line(Vector2(outer, HIP_Y + 10), Vector2(outer + 12.0 * x, -2), 4.0, art.trim)
		art._poly([Vector2(inner - 3.0 * x, -9), Vector2(outer + 14.0 * x, -9), Vector2(outer + 18.0 * x, 0), Vector2(inner - 5.0 * x, 0)], art.trim)
		art._mark([Vector2(inner - 2.0 * x, -7.5), Vector2(outer + 13.0 * x, -7.5)], Color(art.base.lightened(0.35), 0.7), 1.2)
	art._rect(-6, -20, 12, 6, art.trim.darkened(0.1))


static func _stilts(art: RefCounted) -> void:
	var dark: Color = art.base.darkened(0.2)
	for x in [-14.0, 12.0]:
		art._line(Vector2(x, HIP_Y + 4), Vector2(x - 2, -16), 5.0, dark)
		art._line(Vector2(x - 2, -16), Vector2(x - 4, 0), 3.0, WOOD)
		art._circle(x - 2, -16, 3.5, art.trim)
		art._rect(x - 9, -3, 10, 3, WOOD)
	art._mark([Vector2(-15, -10), Vector2(9, -10)], WOOD, 2.0)
	art._rect(-16, HIP_Y - 2, 32, 8, art.trim)


static func _treads(art: RefCounted) -> void:
	var dark: Color = art.base.darkened(0.2)
	art._rect(-10, HIP_Y, 20, 14, dark)
	art._poly([Vector2(-36, -20), Vector2(36, -20), Vector2(42, -10), Vector2(36, 0), Vector2(-36, 0), Vector2(-42, -10)], art.trim.darkened(0.25))
	var roll: float = fmod(art.time * 12.0, 10.0)
	for i in range(8):
		var x: float = -36.0 + fmod(i * 10.0 + roll, 72.0)
		art._mark([Vector2(x, -20), Vector2(x, -17)], art.base.lightened(0.2), 2.0)
		art._mark([Vector2(x, -3), Vector2(x, 0)], art.base.lightened(0.1), 2.0)
	for x in [-24.0, 0.0, 24.0]:
		art._circle(x, -10, 6.0, art.base)
		art._circle(x, -10, 2.0, art.trim)


static func _skates(art: RefCounted) -> void:
	var dark: Color = art.base.darkened(0.2)
	for x in [-18.0, 6.0]:
		art._rect(x, HIP_Y + 6.0, 11.0, -HIP_Y - 12.0, dark)
		art._rect(x - 2.0, HIP_Y + 2.0, 15.0, 6.0, art.trim)
		art._rect(x - 3.0, -8.0, 18.0, 6.0, art.trim)
		art._line(Vector2(x - 6.0, 1.0), Vector2(x + 18.0, 1.0), 2.0, STEEL)
		art._mark([Vector2(x + 18.0, 1.0), Vector2(x + 20.0, -3.0)], STEEL, 2.0)
		var glint: float = maxf(0.0, sin(art.time * 2.0 + x))
		art._mark([Vector2(x - 2.0, 0.0), Vector2(x + 6.0, 0.0)], Color(Color.WHITE, 0.7 * glint), 1.0)
