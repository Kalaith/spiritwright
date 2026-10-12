extends RefCounted
## The illustration behind each stage marker on the region map, and the golem
## laboratory where the journey starts. `draw` paints the still parts once;
## `draw_live` adds what moves (water, sparks, glow, smoke). `at` is the
## marker's centre; landmarks rise above it so the marker sits at their foot.

const STONE := Color("50535b")
const STONE_LIGHT := Color("70747d")
const STONE_DARK := Color("2c2e34")
const MOSS := Color("3f5a2e")
const MOSS_LIGHT := Color("5d7e3c")
const WATER := Color("1d4f6a")
const WATER_LIGHT := Color("6fb4d4")
const WOOD := Color("5a3d24")
const WOOD_DARK := Color("3a2716")
const BRONZE := Color("b07a3c")
const THORN := Color("4a3a24")
const LEAF: Array = [Color("1f3a1c"), Color("284a22"), Color("31572a")]
const LAB_GLOW := Color("4cc9c0")
const CORE_GOLD := Color("e8c170")


## dim: 0 for a reached landmark, up to 1 for one still hidden in fog.
static func draw(ci: CanvasItem, kind: String, at: Vector2, dim: float = 0.0) -> void:
	_shadow(ci, at + Vector2(0, -4), 58.0)
	match kind:
		"gate": _gate(ci, at)
		"court": _court(ci, at)
		"stair": _stair(ci, at)
		"cloister": _cloister(ci, at)
		"vault": _vault(ci, at)
		"heart": _heart(ci, at)
		"laboratory": _laboratory(ci, at)
	if dim > 0.0:
		_shadow(ci, at + Vector2(0, -44), 70.0, 0.5 * dim)


static func draw_live(ci: CanvasItem, kind: String, at: Vector2, time: float, active: bool) -> void:
	match kind:
		"court":
			for i in range(3):
				var t: float = fposmod(time * 0.4 + i / 3.0, 1.0)
				_ring(ci, at + Vector2(-14 + i * 14, -34 + i * 3), 4.0 + t * 16.0, 0.35, Color(WATER_LIGHT, 0.5 * (1.0 - t)))
		"stair":
			for i in range(5):
				var t: float = fposmod(time * 0.5 + i * 0.23, 1.0)
				var p: Vector2 = at + Vector2(-30 + i * 15 + sin(time * 2.0 + i) * 4.0, -20 - i * 9 - t * 26.0)
				ci.draw_circle(p, 1.8, Color(1.0, 0.55, 0.2, 1.0 - t))
		"vault":
			var glint: float = 0.5 + 0.5 * sin(time * 2.3)
			ci.draw_circle(at + Vector2(18, -50), 2.5, Color(0.8, 0.9, 1.0, 0.4 + 0.5 * glint))
			ci.draw_circle(at + Vector2(-20, -44), 2.0, Color(0.8, 0.9, 1.0, 0.9 - 0.5 * glint))
		"heart":
			var pulse: float = 0.5 + 0.5 * sin(time * 1.8)
			_glow(ci, at + Vector2(0, -44), 10.0 + pulse * 6.0, Color(0.5, 1.0, 0.45, 0.35 + 0.25 * pulse))
		"laboratory":
			var flicker: float = 0.75 + 0.25 * sin(time * 5.0) * sin(time * 1.7)
			for window in [Vector2(6, -66), Vector2(6, -46), Vector2(-28, -30)]:
				_glow(ci, at + window, 7.0, Color(LAB_GLOW, 0.35 * flicker))
			for i in range(4):
				var t: float = fposmod(time * 0.25 + i * 0.25, 1.0)
				var p: Vector2 = at + Vector2(-36 + sin(time + i) * 3.0 + t * 10.0, -64 - t * 34.0)
				ci.draw_circle(p, 4.0 + t * 7.0, Color(0.7, 0.7, 0.75, 0.22 * (1.0 - t)))
			if active:
				_glow(ci, at + Vector2(-20, -18), 12.0 + 3.0 * sin(time * 4.0), Color(CORE_GOLD, 0.5))


static func _gate(ci: CanvasItem, at: Vector2) -> void:
	var left := Rect2(at + Vector2(-44, -78), Vector2(16, 66))
	var right := Rect2(at + Vector2(28, -50), Vector2(16, 38))
	for pillar in [left, right]:
		ci.draw_rect(pillar, STONE)
		ci.draw_rect(Rect2(pillar.position, Vector2(4, pillar.size.y)), STONE_LIGHT)
		ci.draw_rect(Rect2(pillar.position + Vector2(-3, pillar.size.y - 6), Vector2(pillar.size.x + 6, 6)), STONE_DARK)
	# What is left of the arch springs from the tall pillar and stops in mid-air.
	ci.draw_arc(at + Vector2(0, -70), 36.0, PI, PI * 1.55, 16, STONE, 12.0, true)
	ci.draw_arc(at + Vector2(0, -70), 42.0, PI, PI * 1.55, 16, STONE_LIGHT, 2.0, true)
	for block in [Vector2(12, -22), Vector2(20, -16), Vector2(4, -14), Vector2(-14, -16)]:
		ci.draw_rect(Rect2(at + block, Vector2(10, 7)), STONE_DARK)
	ci.draw_circle(at + Vector2(-36, -80), 7.0, MOSS)
	ci.draw_circle(at + Vector2(-28, -82), 5.0, MOSS_LIGHT)
	ci.draw_circle(at + Vector2(36, -52), 6.0, MOSS)


static func _court(ci: CanvasItem, at: Vector2) -> void:
	var centre: Vector2 = at + Vector2(0, -30)
	_ellipse(ci, centre, 58.0, 24.0, STONE_DARK)
	_ellipse(ci, centre, 52.0, 20.0, WATER)
	_ellipse(ci, centre + Vector2(-8, -4), 30.0, 9.0, Color(WATER_LIGHT, 0.18))
	for i in range(14):
		var a: float = TAU * i / 14.0
		var p: Vector2 = centre + Vector2(cos(a) * 56.0, sin(a) * 23.0)
		ci.draw_rect(Rect2(p - Vector2(5, 3), Vector2(10, 6)), STONE if i % 3 else STONE_LIGHT)
	# Sunken columns, only their broken tops above the water.
	for column in [[Vector2(-30, -42), 26.0], [Vector2(26, -40), 18.0], [Vector2(36, -60), 34.0]]:
		var base: Vector2 = at + column[0] + Vector2(0, 14)
		ci.draw_rect(Rect2(base - Vector2(6, column[1]), Vector2(12, column[1])), STONE)
		ci.draw_rect(Rect2(base - Vector2(6, column[1]), Vector2(3, column[1])), STONE_LIGHT)
		_ellipse(ci, base, 9.0, 3.0, Color(WATER_LIGHT, 0.4))


static func _stair(ci: CanvasItem, at: Vector2) -> void:
	for i in range(6):
		var step := Rect2(at + Vector2(-48 + i * 14, -22 - i * 11), Vector2(70 - i * 6, 11))
		ci.draw_rect(Rect2(step.position + Vector2(0, 11), Vector2(step.size.x, 11 * (i + 1) - 11)), STONE_DARK)
		ci.draw_rect(step, STONE)
		ci.draw_line(step.position, step.position + Vector2(step.size.x, 0), STONE_LIGHT, 2.0)
	# The top has crumbled away: a jagged break and fallen blocks.
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(22, -88), at + Vector2(40, -96), at + Vector2(32, -80)]), STONE_DARK)
	for block in [Vector2(30, -14), Vector2(42, -10), Vector2(-52, -10)]:
		ci.draw_rect(Rect2(at + block, Vector2(9, 7)), STONE_DARK)
	ci.draw_circle(at + Vector2(-40, -26), 5.0, MOSS)


static func _cloister(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at + Vector2(-26, -70), Vector2(10, 52)), STONE)
	ci.draw_rect(Rect2(at + Vector2(16, -70), Vector2(10, 52)), STONE)
	ci.draw_arc(at + Vector2(0, -70), 21.0, PI, TAU, 18, STONE, 9.0, true)
	ci.draw_rect(Rect2(at + Vector2(-16, -68), Vector2(32, 50)), Color("15140f"))
	# Brambles: looping vines with thorns, and a few blood-red flowers.
	var rng := RandomNumberGenerator.new()
	rng.seed = 353
	for i in range(11):
		var centre: Vector2 = at + Vector2(rng.randf_range(-52, 52), rng.randf_range(-82, -18))
		var radius: float = rng.randf_range(10, 20)
		var start: float = rng.randf() * TAU
		ci.draw_arc(centre, radius, start, start + PI * 1.3, 14, THORN, 2.5, true)
		for k in range(4):
			var a: float = start + PI * 1.3 * k / 4.0
			var p: Vector2 = centre + Vector2(cos(a), sin(a)) * radius
			ci.draw_line(p, p + Vector2(cos(a), sin(a)) * 5.0, THORN.lightened(0.15), 1.5)
		if i % 2 == 0:
			ci.draw_circle(centre + Vector2(cos(start), sin(start)) * radius, 3.5, LEAF[i % 3])
	for flower in [Vector2(-38, -50), Vector2(30, -78), Vector2(44, -36)]:
		ci.draw_circle(at + flower, 3.0, Color("a8323a"))


static func _vault(ci: CanvasItem, at: Vector2) -> void:
	var base := Rect2(at + Vector2(-42, -54), Vector2(84, 40))
	ci.draw_rect(base, STONE)
	ci.draw_circle(at + Vector2(0, -54), 34.0, STONE)
	ci.draw_rect(Rect2(base.position + Vector2(0, -2), Vector2(base.size.x, 6)), STONE_LIGHT)
	ci.draw_arc(at + Vector2(0, -54), 34.0, PI, TAU, 24, STONE_LIGHT, 2.0, true)
	for x in [-36, -20, 20, 36]:
		ci.draw_line(at + Vector2(x, -48), at + Vector2(x, -16), STONE_DARK, 2.0)
	ci.draw_rect(Rect2(at + Vector2(-10, -40), Vector2(20, 26)), Color("0e0d10"))
	ci.draw_circle(at + Vector2(0, -40), 10.0, Color("0e0d10"))
	# The bell that gives the vault its echo, hung from a frame on the dome.
	ci.draw_line(at + Vector2(-9, -100), at + Vector2(-9, -86), WOOD_DARK, 3.0)
	ci.draw_line(at + Vector2(9, -100), at + Vector2(9, -86), WOOD_DARK, 3.0)
	ci.draw_line(at + Vector2(-12, -100), at + Vector2(12, -100), WOOD_DARK, 3.0)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -98), at + Vector2(4, -98), at + Vector2(8, -88),
		at + Vector2(-8, -88)]), BRONZE)
	for crystal in [[Vector2(18, -46), 8.0], [Vector2(-22, -40), 6.0], [Vector2(30, -18), 7.0]]:
		var p: Vector2 = at + crystal[0]
		var h: float = crystal[1]
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.4, 0), p + Vector2(0, -h), p + Vector2(h * 0.4, 0)]),
			Color("8fb8e0"))


static func _heart(ci: CanvasItem, at: Vector2) -> void:
	# Roots spread over the ground before the trunk rises.
	for root in [[Vector2(-70, -4), -0.3], [Vector2(-50, 10), 0.2], [Vector2(62, -2), 0.3], [Vector2(44, 12), -0.2],
			[Vector2(-20, 14), 0.1]]:
		var end: Vector2 = at + root[0]
		var mid: Vector2 = at.lerp(end, 0.5) + Vector2(0, -14 + root[1] * 20.0)
		ci.draw_polyline(PackedVector2Array([at + Vector2(0, -20), mid, end]), WOOD_DARK, 6.0, true)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-24, -14), at + Vector2(24, -14), at + Vector2(14, -70),
		at + Vector2(22, -96), at + Vector2(-20, -96), at + Vector2(-14, -70)]), WOOD)
	ci.draw_line(at + Vector2(-6, -18), at + Vector2(-4, -80), WOOD_DARK, 3.0)
	ci.draw_line(at + Vector2(10, -20), at + Vector2(6, -76), WOOD_DARK, 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for i in range(16):
		var p: Vector2 = at + Vector2(rng.randf_range(-66, 66), rng.randf_range(-136, -92))
		var r: float = rng.randf_range(18, 32)
		ci.draw_circle(p + Vector2(3, 6), r, Color(0, 0, 0, 0.25))
		ci.draw_circle(p, r, LEAF[i % LEAF.size()])
	for i in range(8):
		ci.draw_circle(at + Vector2(rng.randf_range(-56, 56), rng.randf_range(-136, -100)), rng.randf_range(6, 10),
			Color(MOSS_LIGHT, 0.45))
	ci.draw_circle(at + Vector2(0, -44), 7.0, Color("1a120a"))


static func _laboratory(ci: CanvasItem, at: Vector2) -> void:
	# A squat workshop annex beside a round tower with a glass-capped roof.
	var annex := Rect2(at + Vector2(-56, -42), Vector2(52, 32))
	ci.draw_rect(annex, STONE)
	ci.draw_colored_polygon(PackedVector2Array([annex.position + Vector2(-6, 0), annex.position + Vector2(annex.size.x + 4, 0),
		annex.position + Vector2(annex.size.x - 6, -16), annex.position + Vector2(4, -16)]), WOOD)
	ci.draw_rect(Rect2(at + Vector2(-42, -78), Vector2(10, 30)), STONE_DARK)
	ci.draw_rect(Rect2(at + Vector2(-35, -36), Vector2(14, 12)), Color("0f1a1c"))
	var tower := Rect2(at + Vector2(-8, -90), Vector2(30, 80))
	ci.draw_rect(tower, STONE)
	ci.draw_rect(Rect2(tower.position, Vector2(6, tower.size.y)), STONE_LIGHT)
	for y in [-70, -50, -30]:
		ci.draw_line(at + Vector2(-8, y), at + Vector2(22, y), STONE_DARK, 1.5)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-14, -90), at + Vector2(28, -90), at + Vector2(7, -118)]), WOOD_DARK)
	ci.draw_circle(at + Vector2(7, -104), 5.0, Color(LAB_GLOW, 0.8))
	for window in [Vector2(2, -72), Vector2(2, -52)]:
		ci.draw_rect(Rect2(at + window, Vector2(9, 12)), Color("0f1a1c"))
		ci.draw_rect(Rect2(at + window + Vector2(2, 2), Vector2(5, 8)), Color(LAB_GLOW, 0.75))
	# A gear on the annex wall marks it as a golemworks.
	var gear: Vector2 = at + Vector2(-48, -26)
	for i in range(8):
		var a: float = TAU * i / 8.0
		ci.draw_line(gear, gear + Vector2(cos(a), sin(a)) * 8.0, BRONZE, 3.0)
	ci.draw_circle(gear, 5.5, BRONZE)
	ci.draw_circle(gear, 2.0, STONE_DARK)
	# The cradle out front where new bodies are assembled.
	ci.draw_rect(Rect2(at + Vector2(-30, -14), Vector2(22, 6)), WOOD)
	ci.draw_line(at + Vector2(-30, -14), at + Vector2(-30, -6), WOOD_DARK, 2.0)
	ci.draw_line(at + Vector2(-8, -14), at + Vector2(-8, -6), WOOD_DARK, 2.0)


static func _shadow(ci: CanvasItem, at: Vector2, radius: float, alpha: float = 0.3) -> void:
	_ellipse(ci, at, radius, radius * 0.32, Color(0, 0, 0, alpha))


static func _ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a: float = TAU * i / 24.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(points, color)


static func _ring(ci: CanvasItem, centre: Vector2, radius: float, squash: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(21):
		var a: float = TAU * i / 20.0
		points.append(centre + Vector2(cos(a) * radius, sin(a) * radius * squash))
	ci.draw_polyline(points, color, 1.5, true)


static func _glow(ci: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	for k in [1.0, 0.7, 0.45]:
		ci.draw_circle(at, radius * k, Color(color, color.a * (1.2 - k)))
