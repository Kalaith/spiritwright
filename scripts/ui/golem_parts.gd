extends RefCounted
## Every set of arms, drawn through the golem_art instance so they share its
## origin, facing, scale and palette. The back arm is a plain limb behind the
## body; the front arm carries the weapon and a shoulder plate over its joint.

const WOOD := Color("5b4a3a")
const STEEL := Color("c9ccd6")


static func back_arm(art: RefCounted, arms: String, sy: float) -> void:
	if arms == "cannon":
		return
	var shoulder := Vector2(-18.0, sy + 6.0)
	var elbow := Vector2(-24.0, sy + 24.0)
	var hand := Vector2(-22.0, sy + 40.0)
	var dark: Color = art.base.darkened(0.35)
	art._line(shoulder, elbow, 7.0, dark)
	art._line(elbow, hand, 6.0, dark)
	art._circle(elbow.x, elbow.y, 4.0, art.trim.darkened(0.2))
	art._rect(hand.x - 4.5, hand.y - 1.0, 9.0, 8.0, art.trim.darkened(0.25))


static func front_arm(art: RefCounted, arms: String, sy: float) -> void:
	var dark: Color = art.base.darkened(0.1)
	match arms:
		"shield":
			art._line(Vector2(18, sy + 4), Vector2(34, sy + 26), 7.0, dark)
			art._poly([Vector2(31, sy - 12), Vector2(52, sy - 5), Vector2(52, sy + 46), Vector2(31, sy + 58)], art.trim)
			art._poly([Vector2(35, sy - 6), Vector2(48, sy - 1), Vector2(48, sy + 42), Vector2(35, sy + 51)], art.base.lightened(0.08))
			art._mark([Vector2(37, sy - 2), Vector2(37, sy + 47)], Color(art.base.lightened(0.45), 0.7), 1.5)
			art._poly([Vector2(41.5, sy + 10), Vector2(46, sy + 22), Vector2(41.5, sy + 34), Vector2(37, sy + 22)],
				art.element.lerp(Color.WHITE, 0.2), false)
			art.glow(Vector2(41.5, sy + 22), 8.0, Color(art.element, 0.35))
		"cannon":
			art._rect(2, sy, 20, 20, art.trim)
			art._poly([Vector2(18, sy + 3), Vector2(62, sy + 4), Vector2(62, sy + 18), Vector2(18, sy + 19)], art.base)
			art._mark([Vector2(20, sy + 6), Vector2(60, sy + 6.5)], Color(art.base.lightened(0.45), 0.7), 1.5)
			art._mark([Vector2(20, sy + 16.5), Vector2(60, sy + 16)], Color(art.trim.darkened(0.3), 0.6), 2.0)
			for x in [30.0, 44.0]:
				art._rect(x, sy + 1, 5, 20, art.trim)
			art._rect(60, sy, 9, 22, art.trim.darkened(0.15))
			var charge: float = 0.6 + 0.4 * sin(art.time * 4.0)
			art.glow(Vector2(70, sy + 11), 7.0 + charge * 4.0, Color(art.element, 0.6 * charge))
			art.ci.draw_circle(art._p(70, sy + 11), 4.0 * art.s, art._c(art.element.lerp(Color.WHITE, 0.4)))
			_pad(art, sy)
			return
		"spear":
			_arm(art, sy, Vector2(36, sy + 22), dark)
			art._line(Vector2(6, sy + 34), Vector2(84, sy + 8), 4.0, WOOD)
			art._poly([Vector2(82, sy + 2), Vector2(100, sy + 3), Vector2(85, sy + 15)], STEEL)
			art._mark([Vector2(84, sy + 4), Vector2(97, sy + 3.5)], Color(Color.WHITE, 0.7), 1.0)
			_fist(art, Vector2(36, sy + 22))
		"lantern":
			_arm(art, sy, Vector2(38, sy + 20), dark)
			art._line(Vector2(38, sy + 20), Vector2(44, sy + 36), 2.0, art.trim)
			var flicker: float = 0.7 + 0.3 * sin(art.time * 5.0)
			art.glow(Vector2(45, sy + 48), 18.0, Color(art.element, 0.55 * flicker))
			art._rect(37, sy + 36, 16, 22, art.trim)
			art._rect(40, sy + 40, 10, 14, art.element.lerp(Color.WHITE, 0.5 * flicker))
			art._mark([Vector2(45, sy + 40), Vector2(45, sy + 54)], art.trim, 1.5)
			art._poly([Vector2(35, sy + 36), Vector2(55, sy + 36), Vector2(45, sy + 30)], art.trim)
			_fist(art, Vector2(38, sy + 20))
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
			art.ci.draw_circle(art._p(ball.x - 3, ball.y - 3), 2.5 * art.s, art._c(Color(Color.WHITE, 0.45)))
			_fist(art, Vector2(36, sy + 24))
		"twin_blades":
			_arm(art, sy, Vector2(38, sy + 26), dark)
			art._poly([Vector2(36, sy + 22), Vector2(70, sy - 2), Vector2(74, sy + 2), Vector2(40, sy + 30)], STEEL)
			art._poly([Vector2(36, sy + 26), Vector2(72, sy + 34), Vector2(70, sy + 40), Vector2(36, sy + 32)], STEEL.darkened(0.15))
			art._mark([Vector2(42, sy + 22), Vector2(68, sy + 3)], Color(Color.WHITE, 0.7), 1.0)
			_fist(art, Vector2(38, sy + 26))
		"storm_staff":
			_arm(art, sy, Vector2(36, sy + 22), dark)
			art._line(Vector2(34, sy + 62), Vector2(40, sy - 34), 4.0, WOOD)
			var pulse: float = 0.6 + 0.4 * sin(art.time * 4.5)
			art.glow(Vector2(41, sy - 42), 12.0 + pulse * 5.0, Color(art.element, 0.65 * pulse))
			art._poly([Vector2(36, sy - 34), Vector2(46, sy - 34), Vector2(48, sy - 46), Vector2(41, sy - 38), Vector2(34, sy - 46)], art.trim)
			art._circle(41, sy - 42, 7.0, art.element.lerp(Color.WHITE, 0.3))
			art._mark([Vector2(41, sy - 50), Vector2(47, sy - 58), Vector2(43, sy - 60), Vector2(50, sy - 70)], Color(Color.WHITE, pulse), 1.5)
			_fist(art, Vector2(36, sy + 22))
		"scythe":
			_arm(art, sy, Vector2(36, sy + 24), dark)
			art._line(Vector2(28, sy + 58), Vector2(46, sy - 34), 4.0, WOOD)
			art._poly([Vector2(44, sy - 36), Vector2(80, sy - 26), Vector2(92, sy - 6), Vector2(76, sy - 18), Vector2(46, sy - 26)], STEEL)
			art._mark([Vector2(50, sy - 33), Vector2(78, sy - 25), Vector2(88, sy - 10)], Color(Color.WHITE, 0.7), 1.0)
			_fist(art, Vector2(36, sy + 24))
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
			_fist(art, Vector2(40, sy + 20))
		"aegis":
			art._line(Vector2(18, sy + 4), Vector2(32, sy + 24), 7.0, dark)
			art._poly([Vector2(30, sy - 24), Vector2(56, sy - 18), Vector2(56, sy + 64), Vector2(30, sy + 72)], art.trim)
			art._poly([Vector2(34, sy - 18), Vector2(52, sy - 13), Vector2(52, sy + 59), Vector2(34, sy + 65)], art.base.lightened(0.1))
			art._mark([Vector2(36, sy - 14), Vector2(36, sy + 62)], Color(art.base.lightened(0.45), 0.7), 1.5)
			art._mark([Vector2(43, sy - 12), Vector2(43, sy + 60)], art.trim, 2.5)
			art._mark([Vector2(35, sy + 22), Vector2(51, sy + 22)], art.trim, 2.5)
			art.glow(Vector2(43, sy + 22), 9.0, Color(art.element, 0.5))
		_:
			_hammer(art, sy, dark)
	_pad(art, sy)


## A two-handed maul: banded haft, a heavy head with a bright striking face
## and a spike behind.
static func _hammer(art: RefCounted, sy: float, dark: Color) -> void:
	var hand := Vector2(40, sy + 30)
	art._line(Vector2(18, sy + 4), Vector2(28, sy + 20), 8.0, dark)
	art._line(Vector2(28, sy + 20), hand, 7.0, dark)
	art._circle(28, sy + 20, 4.5, art.trim)
	art._line(hand + Vector2(-2, 6), Vector2(47, sy - 12), 4.0, WOOD)
	art._poly([Vector2(33, sy - 23), Vector2(29, sy - 17), Vector2(33, sy - 12)], STEEL.darkened(0.2))
	art._poly([Vector2(33, sy - 28), Vector2(61, sy - 26), Vector2(63, sy - 17), Vector2(61, sy - 6), Vector2(33, sy - 8)], art.base.lightened(0.1))
	art._mark([Vector2(35, sy - 25), Vector2(59, sy - 23.5)], Color(art.base.lightened(0.5), 0.7), 1.5)
	art._rect(58, sy - 26, 5, 20, STEEL)
	art._rect(43, sy - 29, 6, 24, art.trim)
	_fist(art, hand)


static func _arm(art: RefCounted, sy: float, hand: Vector2, color: Color) -> void:
	var elbow := Vector2(28, sy + 20)
	art._line(Vector2(18, sy + 4), elbow, 8.0, color)
	art._line(elbow, hand, 7.0, color)
	art._circle(elbow.x, elbow.y, 4.5, art.trim)


## A blocky fist closed round a grip.
static func _fist(art: RefCounted, at: Vector2) -> void:
	art._poly([at + Vector2(-5, -5), at + Vector2(5, -5), at + Vector2(6, 4), at + Vector2(-4, 6)], art.trim)
	art._mark([at + Vector2(-3, -3.5), at + Vector2(4, -3.5)], Color(art.trim.lightened(0.4), 0.8), 1.0)


## The plate over the front shoulder joint.
static func _pad(art: RefCounted, sy: float) -> void:
	var points: Array = []
	for i in range(8):
		var angle: float = PI + PI * i / 7.0
		points.append(Vector2(18.0 + cos(angle) * 8.5, sy + 5.0 + sin(angle) * 7.5))
	points.append(Vector2(25, sy + 10))
	points.append(Vector2(11, sy + 10))
	art._poly(points, art.trim.lightened(0.08))
	art._mark([Vector2(12.5, sy + 1.5), Vector2(18, sy - 1.0), Vector2(23.5, sy + 1.5)], Color(art.trim.lightened(0.5), 0.8), 1.5)
	art.ci.draw_circle(art._p(18, sy + 5), 1.6 * art.s, art._c(art.trim.lightened(0.35)))
