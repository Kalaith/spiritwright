extends RefCounted
## Silhouettes for the later parts (arms, legs and the Colossus frame), drawn
## through the golem_art instance so they share its origin, facing, scale and
## palette. Each function returns false when it does not know the part, and
## golem_art falls back to its own drawing.

const WOOD := Color("5b4a3a")
const STEEL := Color("c9ccd6")
## Matches golem_art.HIP_Y.
const HIP_Y: float = -34.0


## The torso, shoulder pads and head of the Colossus frame.
static func colossus(art: RefCounted) -> void:
	art._rect(-34, HIP_Y - 6, 68, 11, art.trim)
	art._poly([Vector2(-36, HIP_Y), Vector2(36, HIP_Y), Vector2(44, -98), Vector2(-44, -98)], art.base)
	art._texture(art.torso)
	for x in [-1.0, 1.0]:
		art._poly([Vector2(54 * x, -92), Vector2(50 * x, -112), Vector2(24 * x, -112), Vector2(22 * x, -92)], art.base.lightened(0.05))
		art._mark([Vector2(50 * x, -104), Vector2(25 * x, -104)], art.trim, 2.5)
	for y in [-56.0, -78.0]:
		art._mark([Vector2(-38, y), Vector2(38, y)], Color(art.trim, 0.7), 2.0)
	art._head(Rect2(-13, -128, 26, 22), Vector2(1, -120))


static func front_arm(art: RefCounted, arms: String, sy: float) -> bool:
	var dark: Color = art.base.darkened(0.1)
	match arms:
		"spear":
			_arm(art, sy, Vector2(36, sy + 22), dark)
			art._line(Vector2(6, sy + 34), Vector2(84, sy + 8), 4.0, WOOD)
			art._poly([Vector2(82, sy + 2), Vector2(100, sy + 3), Vector2(85, sy + 15)], STEEL)
			art._circle(36, sy + 22, 5.0, art.trim)
		"lantern":
			_arm(art, sy, Vector2(38, sy + 20), dark)
			art._line(Vector2(38, sy + 20), Vector2(44, sy + 36), 2.0, art.trim)
			var flicker: float = 0.7 + 0.3 * sin(art.time * 5.0)
			art.glow(Vector2(45, sy + 48), 18.0, Color(art.element, 0.55 * flicker))
			art._rect(37, sy + 36, 16, 22, art.trim)
			art._rect(40, sy + 40, 10, 14, art.element.lerp(Color.WHITE, 0.5 * flicker))
			art._poly([Vector2(35, sy + 36), Vector2(55, sy + 36), Vector2(45, sy + 30)], art.trim)
		"flail":
			_arm(art, sy, Vector2(36, sy + 24), dark)
			art._line(Vector2(36, sy + 24), Vector2(50, sy + 8), 4.0, WOOD)
			var swing: float = sin(art.time * 2.4) * 8.0
			var ball := Vector2(70, sy + 30 + swing)
			art._mark([Vector2(50, sy + 8), Vector2(58, sy + 14 + swing * 0.3), Vector2(64, sy + 22 + swing * 0.6), ball], art.trim.darkened(0.3), 2.0)
			for i in range(6):
				var angle: float = TAU * i / 6.0
				art._poly([ball + Vector2(cos(angle - 0.3), sin(angle - 0.3)) * 9.0,
					ball + Vector2(cos(angle), sin(angle)) * 15.0, ball + Vector2(cos(angle + 0.3), sin(angle + 0.3)) * 9.0], STEEL)
			art._circle(ball.x, ball.y, 10.0, art.trim)
		"twin_blades":
			_arm(art, sy, Vector2(38, sy + 26), dark)
			art._poly([Vector2(36, sy + 22), Vector2(70, sy - 2), Vector2(74, sy + 2), Vector2(40, sy + 30)], STEEL)
			art._poly([Vector2(36, sy + 26), Vector2(72, sy + 34), Vector2(70, sy + 40), Vector2(36, sy + 32)], STEEL.darkened(0.15))
			art._circle(38, sy + 26, 5.0, art.trim)
		"storm_staff":
			_arm(art, sy, Vector2(36, sy + 22), dark)
			art._line(Vector2(34, sy + 62), Vector2(40, sy - 34), 4.0, WOOD)
			var pulse: float = 0.6 + 0.4 * sin(art.time * 4.5)
			art.glow(Vector2(41, sy - 42), 12.0 + pulse * 5.0, Color(art.element, 0.65 * pulse))
			art._circle(41, sy - 42, 7.0, art.element.lerp(Color.WHITE, 0.3))
			art._mark([Vector2(41, sy - 50), Vector2(47, sy - 58), Vector2(43, sy - 60), Vector2(50, sy - 70)], Color(Color.WHITE, pulse), 1.5)
			art._circle(36, sy + 22, 5.0, art.trim)
		"scythe":
			_arm(art, sy, Vector2(36, sy + 24), dark)
			art._line(Vector2(28, sy + 58), Vector2(46, sy - 34), 4.0, WOOD)
			art._poly([Vector2(44, sy - 36), Vector2(80, sy - 26), Vector2(92, sy - 6), Vector2(76, sy - 18), Vector2(46, sy - 26)], STEEL)
			art._circle(36, sy + 24, 5.0, art.trim)
		"bow":
			_arm(art, sy, Vector2(40, sy + 20), dark)
			var top := Vector2(44, sy - 22)
			var bottom := Vector2(44, sy + 62)
			var points: Array = []
			for i in range(9):
				var t: float = i / 8.0
				points.append(top.lerp(bottom, t) + Vector2(sin(t * PI) * 16.0, 0))
			for i in range(points.size() - 1):
				art._line(points[i], points[i + 1], 4.0, WOOD)
			art._mark([top, bottom], Color("e8e2d0"), 1.2)
			art._circle(40, sy + 20, 5.0, art.trim)
		"aegis":
			art._line(Vector2(18, sy + 4), Vector2(32, sy + 24), 7.0, dark)
			art._poly([Vector2(30, sy - 24), Vector2(56, sy - 18), Vector2(56, sy + 64), Vector2(30, sy + 72)], art.trim)
			art._poly([Vector2(34, sy - 18), Vector2(52, sy - 13), Vector2(52, sy + 59), Vector2(34, sy + 65)], art.base.lightened(0.1))
			art._mark([Vector2(43, sy - 12), Vector2(43, sy + 60)], art.trim, 2.5)
			art._mark([Vector2(35, sy + 22), Vector2(51, sy + 22)], art.trim, 2.5)
			art.glow(Vector2(43, sy + 22), 9.0, Color(art.element, 0.5))
		_:
			return false
	return true


static func _arm(art: RefCounted, sy: float, hand: Vector2, color: Color) -> void:
	var elbow := Vector2(28, sy + 20)
	art._line(Vector2(18, sy + 4), elbow, 8.0, color)
	art._line(elbow, hand, 7.0, color)
	art._circle(elbow.x, elbow.y, 4.5, art.trim)


static func legs(art: RefCounted, kind: String) -> bool:
	var dark: Color = art.base.darkened(0.2)
	var hip: float = HIP_Y
	match kind:
		"stilts":
			for x in [-14.0, 12.0]:
				art._line(Vector2(x, hip + 4), Vector2(x - 2, -16), 5.0, dark)
				art._line(Vector2(x - 2, -16), Vector2(x - 4, 0), 3.0, WOOD)
				art._circle(x - 2, -16, 3.5, art.trim)
				art._rect(x - 9, -3, 10, 3, WOOD)
			art._mark([Vector2(-15, -10), Vector2(9, -10)], WOOD, 2.0)
			art._rect(-16, hip - 2, 32, 8, art.trim)
		"treads":
			art._rect(-10, hip, 20, 14, dark)
			art._poly([Vector2(-36, -20), Vector2(36, -20), Vector2(42, -10), Vector2(36, 0), Vector2(-36, 0), Vector2(-42, -10)], art.trim.darkened(0.25))
			var roll: float = fmod(art.time * 12.0, 10.0)
			for i in range(8):
				var x: float = -36.0 + fmod(i * 10.0 + roll, 72.0)
				art._mark([Vector2(x, -20), Vector2(x, -17)], art.base.lightened(0.2), 2.0)
			for x in [-24.0, 0.0, 24.0]:
				art._circle(x, -10, 6.0, art.base)
				art._circle(x, -10, 2.0, art.trim)
		"skates":
			for x in [-18.0, 6.0]:
				art._rect(x, hip + 6.0, 11.0, -hip - 12.0, dark)
				art._rect(x - 2.0, hip + 2.0, 15.0, 6.0, art.trim)
				art._rect(x - 3.0, -8.0, 18.0, 6.0, art.trim)
				art._line(Vector2(x - 6.0, 1.0), Vector2(x + 18.0, 1.0), 2.0, STEEL)
				art._mark([Vector2(x + 18.0, 1.0), Vector2(x + 20.0, -3.0)], STEEL, 2.0)
		_:
			return false
	return true
