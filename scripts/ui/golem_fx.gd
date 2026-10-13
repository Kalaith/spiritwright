extends RefCounted
## Animated auras for element reactions (a spirit in a material it reacts
## with). Drawn through the golem_art instance so they share its origin,
## facing, scale and breathing offset. `front` is false for the layer behind
## the body and true for the layer in front of it. Purely presentational:
## the time only ever comes from the UI.

const SHOULDERS: Dictionary = {
	"bulwark": [Vector2(-31, -98), Vector2(31, -98)],
	"strider": [Vector2(-6, -90), Vector2(22, -86)],
	"conduit": [Vector2(-20, -84), Vector2(20, -84)],
	"colossus": [Vector2(-38, -112), Vector2(38, -112)],
}
const CROWN: Dictionary = {"bulwark": Vector2(0, -114), "strider": Vector2(13, -113), "conduit": Vector2(0, -115),
	"colossus": Vector2(0, -128)}
const FIRE := Color("ff7a3d")
const FLAME_CORE := Color("ffd36b")
const LEAF := Color("7fd35a")
const VINE := Color("3f7a32")
const FROST := Color("e6f7ff")
const SPARK := Color("f2e15a")
const GALE := Color("9fe8c8")
const MOSS := Color("6f9a46")


static func draw(art: RefCounted, reaction: String, front: bool) -> void:
	match reaction:
		"kindling", "magma_heart":
			_kindling(art, front)
		"heartwood", "mangrove":
			_heartwood(art, front)
		"glacier", "bog_spring":
			_glacier(art, front)
		"steam":
			_steam(art, front)
		"live_wire", "thunderglass":
			_live_wire(art, front)
		"wind_chime", "singing_glass":
			_wind_chime(art, front)
		"living_rock", "basalt":
			_living_rock(art, front)


## Points that flames, leaves and frost grow from: both shoulders and the crown.
static func _anchors(art: RefCounted) -> Array:
	var points: Array = SHOULDERS[art.frame].duplicate()
	points.append(CROWN[art.frame])
	return points


static func _blob(art: RefCounted, at: Vector2, radius: float, color: Color) -> void:
	art.ci.draw_circle(art._p(at.x, at.y), radius * art.s, art._c(color))


static func _shape(art: RefCounted, points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(art._p(point.x, point.y))
	art.ci.draw_colored_polygon(packed, art._c(color))


## A flame licking upward from `at`, flickering with time.
static func _flame(art: RefCounted, at: Vector2, size: float, phase: float) -> void:
	var t: float = art.time
	var height: float = size * (1.6 + 0.35 * sin(t * 9.0 + phase) + 0.2 * sin(t * 13.0 + phase * 2.0))
	var sway: float = 3.0 * sin(t * 5.0 + phase)
	_shape(art, [at + Vector2(-size * 0.6, 0), at + Vector2(-size * 0.3, -height * 0.55),
		at + Vector2(sway, -height), at + Vector2(size * 0.35, -height * 0.5), at + Vector2(size * 0.6, 0)], Color(FIRE, 0.85))
	_shape(art, [at + Vector2(-size * 0.3, 0), at + Vector2(sway * 0.6, -height * 0.6), at + Vector2(size * 0.3, 0)],
		Color(FLAME_CORE, 0.9))


static func _kindling(art: RefCounted, front: bool) -> void:
	if not front:
		art.glow(Vector2(0, -74), 58.0, Color(FIRE, 0.35 + 0.1 * sin(art.time * 7.0)))
		return
	var anchors: Array = _anchors(art)
	for i in range(anchors.size()):
		_flame(art, anchors[i], 6.0 if i < 2 else 7.0, i * 1.7)
	# Embers drift up off the body and fade.
	for i in range(6):
		var rise: float = fmod(art.time * 28.0 + i * 17.0, 60.0)
		var x: float = -24.0 + i * 9.0 + 4.0 * sin(art.time * 3.0 + i)
		_blob(art, Vector2(x, -80.0 - rise), 1.8, Color(FLAME_CORE, 1.0 - rise / 60.0))
	# Scorch marks where the wood is already burning.
	var torso: Array = art.torso
	for uv in [Vector2(0.2, 0.15), Vector2(0.85, 0.55)]:
		var at: Vector2 = art.quad(torso, uv.x, uv.y)
		_blob(art, at, 4.5, Color("2a1a12", 0.6))
		_blob(art, at, 2.0, Color(FIRE, 0.5 + 0.5 * sin(art.time * 6.0 + uv.x * 9.0)))


## A leaf on a short stem, swaying.
static func _leaf(art: RefCounted, at: Vector2, angle: float, size: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side: Vector2 = dir.orthogonal() * size * 0.4
	var tip: Vector2 = at + dir * size
	var mid: Vector2 = at + dir * size * 0.5
	_shape(art, [at, mid + side, tip, mid - side], LEAF)
	art._mark([at, tip], Color(VINE, 0.9), 1.0)


static func _heartwood(art: RefCounted, front: bool) -> void:
	if not front:
		return
	var torso: Array = art.torso
	var vine: Array = []
	for i in range(8):
		var v: float = i / 7.0
		vine.append(art.quad(torso, 0.5 + 0.38 * sin(v * 5.0), v))
	art._mark(vine, VINE, 2.5)
	for i in range(3):
		_leaf(art, vine[2 + i * 2], -0.6 + i * 1.1 + 0.2 * sin(art.time * 2.0 + i), 7.0)
	var anchors: Array = _anchors(art)
	for i in range(anchors.size()):
		var sway: float = 0.25 * sin(art.time * 1.8 + i * 1.3)
		_leaf(art, anchors[i], -PI / 2.0 - 0.5 + sway, 10.0)
		_leaf(art, anchors[i], -PI / 2.0 + 0.5 + sway, 8.0)


static func _glacier(art: RefCounted, front: bool) -> void:
	if not front:
		# Cold mist pooling around the feet.
		for i in range(5):
			var drift: float = sin(art.time * 0.8 + i * 1.4) * 8.0
			art.glow(Vector2(-36.0 + i * 18.0 + drift, -4.0), 13.0, Color(FROST, 0.4))
		return
	var anchors: Array = _anchors(art)
	for i in range(anchors.size()):
		var at: Vector2 = anchors[i]
		for spike in [[-6.0, 10.0], [0.0, 16.0], [6.0, 9.0]]:
			var foot: Vector2 = at + Vector2(spike[0], 2)
			art._poly([foot + Vector2(-3.5, 0), foot + Vector2(spike[0] * 0.3, -spike[1]), foot + Vector2(3.5, 0)], FROST)
	var twinkle: float = maxf(0.0, sin(art.time * 3.0))
	var glint: Vector2 = anchors[2] + Vector2(10, -10)
	art._mark([glint + Vector2(-4 * twinkle, 0), glint + Vector2(4 * twinkle, 0)], Color(Color.WHITE, twinkle), 1.5)
	art._mark([glint + Vector2(0, -4 * twinkle), glint + Vector2(0, 4 * twinkle)], Color(Color.WHITE, twinkle), 1.5)


static func _steam(art: RefCounted, front: bool) -> void:
	if not front:
		return
	var anchors: Array = _anchors(art)
	for i in range(7):
		var cycle: float = fmod(art.time * 0.55 + i * 0.37, 1.0)
		var from: Vector2 = anchors[i % anchors.size()]
		var at: Vector2 = from + Vector2(10.0 * sin(cycle * 4.0 + i), -cycle * 46.0)
		art.glow(at, 6.0 + cycle * 10.0, Color(Color.WHITE, 0.95 * (1.0 - cycle)))
	# Meltwater drips from the base of the torso.
	var torso: Array = art.torso
	for i in range(2):
		var fall: float = fmod(art.time * 40.0 + i * 23.0, 30.0)
		var at: Vector2 = art.quad(torso, 0.25 + i * 0.5, 0.0) + Vector2(0, fall)
		_blob(art, at, 2.0, Color("7fc6ff", 1.0 - fall / 30.0))


## Jagged arcs that re-roll a few times a second.
static func _live_wire(art: RefCounted, front: bool) -> void:
	if not front:
		art.glow(Vector2(0, -66), 50.0, Color(SPARK, 0.2 + 0.25 * maxf(0.0, sin(art.time * 11.0))))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(art.time * 9.0) * 7919 + int(art.origin.x)
	var torso: Array = art.torso
	var anchors: Array = _anchors(art)
	for arc in range(3):
		var from: Vector2 = art.quad(torso, rng.randf(), rng.randf())
		var to: Vector2 = anchors[arc] + Vector2(rng.randf_range(-8, 8), rng.randf_range(-14, -4))
		var bolt: Array = [from]
		for step in range(1, 5):
			bolt.append(from.lerp(to, step / 5.0) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4)))
		bolt.append(to)
		art._mark(bolt, Color(SPARK, 0.85), 2.5)
		art._mark(bolt, Color(Color.WHITE, 0.9), 1.0)


static func _wind_chime(art: RefCounted, front: bool) -> void:
	var crown: Vector2 = CROWN[art.frame]
	for i in range(3):
		var angle: float = art.time * 1.4 + i * TAU / 3.0
		var in_front: bool = sin(angle) > 0.0
		if in_front != front:
			continue
		var at: Vector2 = crown + Vector2(cos(angle) * 30.0, -6.0 + sin(angle) * 8.0)
		art._poly([at + Vector2(0, -7), at + Vector2(4, 0), at + Vector2(0, 7), at + Vector2(-4, 0)], art.base.lightened(0.2))
	if front:
		for i in range(2):
			var start: float = art.time * 2.0 + i * PI
			art.ci.draw_arc(art._p(crown.x, crown.y + 4), (36.0 + i * 8.0) * art.s, start, start + 1.4, 12,
				art._c(Color(GALE, 0.6)), 2.0 * art.s, true)


static func _living_rock(art: RefCounted, front: bool) -> void:
	for i in range(3):
		var angle: float = art.time * 0.9 + i * TAU / 3.0
		if (sin(angle) > 0.0) != front:
			continue
		var at := Vector2(cos(angle) * 44.0, -64.0 + sin(angle) * 10.0 + 3.0 * sin(art.time * 2.0 + i))
		art._poly([at + Vector2(-5, -2), at + Vector2(-1, -6), at + Vector2(5, -3), at + Vector2(4, 4), at + Vector2(-3, 4)],
			art.base.darkened(0.1))
	if front:
		for at in SHOULDERS[art.frame]:
			for k in range(4):
				var tuft: Vector2 = at + Vector2(-6 + k * 4, 1)
				art._mark([tuft, tuft + Vector2(sin(art.time * 2.0 + k) * 1.5, -5 - (k % 2) * 2)], MOSS, 2.0)
