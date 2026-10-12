extends RefCounted
## Landmarks for the regions beyond the Ancient Ruins: fen bridges and stilt
## huts, watchtowers and kilns, crystal spires, camps, standing stones and snowy
## peaks. Same contract as map_landmarks.gd: `at` is the marker's centre and the
## illustration rises above it. Any region may use any landmark.

const STONE := Color("50535b")
const STONE_LIGHT := Color("70747d")
const STONE_DARK := Color("2c2e34")
const WOOD := Color("5a3d24")
const WOOD_DARK := Color("3a2716")
const WOOD_LIGHT := Color("7a5634")
const WATER := Color("1d4f6a")
const WATER_LIGHT := Color("6fb4d4")
const REED := Color("6b7a3a")
const CLOTH := Color("8a4a3a")
const CLOTH_LIGHT := Color("b0684e")
const EMBER := Color(1.0, 0.55, 0.2)
const CRYSTAL := Color("8fb8e0")
const CRYSTAL_DARK := Color("4f6f9a")
const SNOW := Color("dfe8ef")
const RUNE := Color("7fd3c8")


static func draw(ci: CanvasItem, kind: String, at: Vector2) -> void:
	match kind:
		"bridge": _bridge(ci, at)
		"hut": _hut(ci, at)
		"tower": _tower(ci, at)
		"kiln": _kiln(ci, at)
		"spire": _spire(ci, at)
		"camp": _camp(ci, at)
		"monolith": _monolith(ci, at)
		"peak": _peak(ci, at)


static func draw_live(ci: CanvasItem, kind: String, at: Vector2, time: float) -> void:
	match kind:
		"bridge":
			for i in range(3):
				var t: float = fposmod(time * 0.5 + i / 3.0, 1.0)
				var p: Vector2 = at + Vector2(-50 + t * 100.0, -12 + i * 4)
				ci.draw_line(p, p + Vector2(8, 0), Color(WATER_LIGHT, 0.6 * sin(t * PI)), 2.0, true)
		"hut", "camp":
			var origin: Vector2 = at + (Vector2(18, -86) if kind == "hut" else Vector2(0, -24))
			for i in range(4):
				var t: float = fposmod(time * 0.3 + i * 0.25, 1.0)
				var p: Vector2 = origin + Vector2(sin(time + i) * 3.0 + t * 8.0, -t * 30.0)
				ci.draw_circle(p, 3.0 + t * 6.0, Color(0.7, 0.7, 0.75, 0.22 * (1.0 - t)))
			if kind == "camp":
				var flicker: float = 0.7 + 0.3 * sin(time * 9.0) * sin(time * 2.3)
				_glow(ci, at + Vector2(0, -16), 9.0 * flicker, Color(EMBER, 0.55))
		"tower":
			var flicker: float = 0.75 + 0.25 * sin(time * 6.0)
			_glow(ci, at + Vector2(0, -102), 8.0, Color(EMBER, 0.5 * flicker))
		"kiln":
			var pulse: float = 0.6 + 0.4 * sin(time * 3.0)
			_glow(ci, at + Vector2(0, -28), 12.0, Color(EMBER, 0.45 * pulse))
			for i in range(5):
				var t: float = fposmod(time * 0.6 + i * 0.2, 1.0)
				var p: Vector2 = at + Vector2(14 + sin(time * 2.0 + i) * 4.0, -96 - t * 30.0)
				ci.draw_circle(p, 1.8, Color(EMBER, 1.0 - t))
		"spire":
			var glint: float = 0.5 + 0.5 * sin(time * 2.6)
			_glow(ci, at + Vector2(0, -92), 6.0 + glint * 4.0, Color(CRYSTAL, 0.4 + 0.3 * glint))
		"monolith":
			var pulse: float = 0.5 + 0.5 * sin(time * 1.5)
			for x in [-30.0, 0.0, 30.0]:
				_glow(ci, at + Vector2(x, -44 - (14.0 if x == 0.0 else 0.0)), 5.0, Color(RUNE, 0.3 + 0.4 * pulse))
		"peak":
			for i in range(6):
				var t: float = fposmod(time * 0.2 + i / 6.0, 1.0)
				var p: Vector2 = at + Vector2(-50 + i * 20 + sin(time + i) * 6.0, -120 + t * 110.0)
				ci.draw_circle(p, 1.6, Color(SNOW, 0.8 * sin(t * PI)))


## A plank bridge over a strip of dark water, rope rails sagging between posts.
static func _bridge(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-70, -24), at + Vector2(70, -28), at + Vector2(74, -2),
		at + Vector2(-72, 2)]), WATER)
	for i in range(11):
		var x: float = -50 + i * 10.0
		var y: float = -30 - 10.0 * sin(PI * i / 10.0)
		ci.draw_rect(Rect2(at + Vector2(x, y), Vector2(8, 14)), WOOD if i % 2 else WOOD_LIGHT)
	for side in [-1.0, 1.0]:
		var posts: Array = [Vector2(-52, -44), Vector2(0, -56), Vector2(52, -44)]
		var rail := PackedVector2Array()
		for post in posts:
			var p: Vector2 = at + post + Vector2(0, side * 6.0)
			ci.draw_line(p, p + Vector2(0, 22), WOOD_DARK, 3.0)
			rail.append(p)
		ci.draw_polyline(rail, Color("8a7a5a"), 1.5, true)
	for reed in [Vector2(-66, -20), Vector2(-60, -16), Vector2(62, -24), Vector2(68, -18)]:
		ci.draw_line(at + reed, at + reed + Vector2(2, -22), REED, 2.0)


## A reed-thatched hut standing on stilts above the fen.
static func _hut(ci: CanvasItem, at: Vector2) -> void:
	for x in [-30, -10, 10, 30]:
		ci.draw_line(at + Vector2(x, -10), at + Vector2(x, -42), WOOD_DARK, 4.0)
	ci.draw_rect(Rect2(at + Vector2(-40, -46), Vector2(80, 6)), WOOD)
	ci.draw_rect(Rect2(at + Vector2(-30, -76), Vector2(60, 30)), WOOD_LIGHT)
	ci.draw_rect(Rect2(at + Vector2(-8, -68), Vector2(14, 22)), Color("15120d"))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-42, -74), at + Vector2(42, -74), at + Vector2(0, -104)]), REED)
	for i in range(6):
		ci.draw_line(at + Vector2(-34 + i * 14, -76), at + Vector2(-4 + i * 2, -100), REED.darkened(0.25), 1.5)
	ci.draw_rect(Rect2(at + Vector2(14, -94), Vector2(8, 12)), STONE_DARK)
	ci.draw_line(at + Vector2(-48, -10), at + Vector2(-34, -44), WOOD, 3.0)


## A narrow stone watchtower with a beacon on top.
static func _tower(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-22, -12), at + Vector2(22, -12), at + Vector2(16, -94),
		at + Vector2(-16, -94)]), STONE)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-22, -12), at + Vector2(-14, -12), at + Vector2(-10, -94),
		at + Vector2(-16, -94)]), STONE_LIGHT)
	for y in [-34, -56, -78]:
		ci.draw_line(at + Vector2(-20, y), at + Vector2(20, y), STONE_DARK, 1.5)
	ci.draw_rect(Rect2(at + Vector2(-22, -100), Vector2(44, 8)), STONE_DARK)
	for x in [-22, -8, 6]:
		ci.draw_rect(Rect2(at + Vector2(x, -108), Vector2(8, 8)), STONE)
	ci.draw_rect(Rect2(at + Vector2(-5, -70), Vector2(10, 14)), Color("15120d"))
	ci.draw_rect(Rect2(at + Vector2(-6, -30), Vector2(12, 18)), Color("15120d"))


## A domed clay kiln with a tall chimney, its mouth glowing.
static func _kiln(ci: CanvasItem, at: Vector2) -> void:
	var clay := Color("7a4a32")
	ci.draw_circle(at + Vector2(0, -26), 34.0, clay)
	ci.draw_rect(Rect2(at + Vector2(-34, -26), Vector2(68, 16)), clay)
	ci.draw_arc(at + Vector2(0, -26), 34.0, PI * 1.1, PI * 1.5, 12, clay.lightened(0.2), 3.0, true)
	ci.draw_rect(Rect2(at + Vector2(6, -96), Vector2(16, 50)), clay.darkened(0.15))
	ci.draw_rect(Rect2(at + Vector2(4, -100), Vector2(20, 6)), STONE_DARK)
	ci.draw_circle(at + Vector2(0, -22), 12.0, Color("1a0d08"))
	ci.draw_rect(Rect2(at + Vector2(-12, -22), Vector2(24, 12)), Color("1a0d08"))
	ci.draw_circle(at + Vector2(0, -16), 7.0, Color(EMBER, 0.85))
	for pile in [Vector2(-50, -12), Vector2(-44, -18), Vector2(40, -12)]:
		ci.draw_rect(Rect2(at + pile, Vector2(14, 5)), WOOD)


## Jagged crystal shards growing from a rock outcrop.
static func _spire(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-46, -8), at + Vector2(46, -8), at + Vector2(30, -30),
		at + Vector2(-34, -28)]), STONE_DARK)
	for shard in [[Vector2(0, -28), 14.0, 72.0, 0.0], [Vector2(-22, -26), 9.0, 44.0, -0.35],
			[Vector2(22, -26), 10.0, 50.0, 0.3], [Vector2(-36, -16), 6.0, 24.0, -0.6], [Vector2(36, -16), 6.0, 28.0, 0.55]]:
		var base: Vector2 = at + shard[0]
		var tip: Vector2 = base + Vector2(0, -shard[2]).rotated(shard[3])
		var side: Vector2 = Vector2(shard[1], 0).rotated(shard[3])
		ci.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), CRYSTAL_DARK)
		ci.draw_colored_polygon(PackedVector2Array([base - side * 0.2, tip, base + side]), CRYSTAL)


## Two hide tents around a campfire ring.
static func _camp(ci: CanvasItem, at: Vector2) -> void:
	for tent in [[Vector2(-34, -10), 30.0], [Vector2(34, -18), 24.0]]:
		var base: Vector2 = at + tent[0]
		var w: float = tent[1]
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(w, 0), base + Vector2(0, -w * 1.5)]), CLOTH)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.2, 0),
			base + Vector2(0, -w * 1.5)]), CLOTH_LIGHT)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(6, 0), base + Vector2(0, -w * 0.7)]),
			Color("15120d"))
		ci.draw_line(base + Vector2(0, -w * 1.5), base + Vector2(-4, -w * 1.5 - 8), WOOD_DARK, 2.0)
	for i in range(8):
		var a: float = TAU * i / 8.0
		ci.draw_circle(at + Vector2(0, -12) + Vector2(cos(a) * 11.0, sin(a) * 4.0), 3.0, STONE)
	ci.draw_line(at + Vector2(-6, -12), at + Vector2(6, -16), WOOD, 3.0)
	ci.draw_line(at + Vector2(-6, -16), at + Vector2(6, -12), WOOD_DARK, 3.0)


## A ring of standing stones carved with runes.
static func _monolith(ci: CanvasItem, at: Vector2) -> void:
	for stone in [[Vector2(-30, -14), 16.0, 52.0], [Vector2(0, -20), 20.0, 74.0], [Vector2(30, -14), 16.0, 56.0],
			[Vector2(-52, -6), 12.0, 30.0], [Vector2(52, -6), 12.0, 34.0]]:
		var base: Vector2 = at + stone[0]
		var w: float = stone[1]
		var h: float = stone[2]
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w / 2.0, 0), base + Vector2(w / 2.0, 0),
			base + Vector2(w * 0.38, -h), base + Vector2(-w * 0.3, -h - 4.0)]), STONE)
		ci.draw_line(base + Vector2(-w / 2.0, 0), base + Vector2(-w * 0.3, -h - 4.0), STONE_LIGHT, 2.0)
	ci.draw_line(at + Vector2(-38, -66), at + Vector2(38, -70), STONE_DARK, 9.0)
	ci.draw_line(at + Vector2(-38, -70), at + Vector2(38, -74), STONE, 5.0)


## A snow-capped crag with a pass cut below it.
static func _peak(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-70, -6), at + Vector2(-10, -112), at + Vector2(14, -84),
		at + Vector2(30, -100), at + Vector2(72, -6)]), STONE)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-70, -6), at + Vector2(-10, -112), at + Vector2(-18, -6)]),
		STONE_LIGHT.darkened(0.1))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-30, -76), at + Vector2(-10, -112), at + Vector2(6, -90),
		at + Vector2(-6, -84), at + Vector2(-16, -90)]), SNOW)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(20, -88), at + Vector2(30, -100), at + Vector2(42, -80),
		at + Vector2(32, -84)]), SNOW)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-16, -6), at + Vector2(16, -6), at + Vector2(6, -34),
		at + Vector2(-6, -34)]), STONE_DARK)


static func _glow(ci: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	for k in [1.0, 0.7, 0.45]:
		ci.draw_circle(at, radius * k, Color(color, color.a * (1.2 - k)))
