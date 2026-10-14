extends RefCounted
## The torso and head of each frame, drawn through the golem_art instance so
## they share its origin, facing, scale and palette. Every frame has its own
## head: the Bulwark a browed helm, the Strider a forward wedge, the Conduit a
## dome with a lens and the Colossus a crowned helm. The spirit looks out
## through a glowing eye in its element's colour.

## Matches golem_art.HIP_Y.
const HIP_Y: float = -34.0


static func body(art: RefCounted) -> void:
	match art.frame:
		"colossus":
			art._rect(-34, HIP_Y - 6, 68, 11, art.trim)
			art._poly([Vector2(-36, HIP_Y), Vector2(36, HIP_Y), Vector2(44, -98), Vector2(-44, -98)], art.base)
			art._texture(art.torso)
			for y in [-56.0, -78.0]:
				art._mark([Vector2(-38, y), Vector2(38, y)], Color(art.trim, 0.7), 2.0)
			_shade(art, [Vector2(-36, HIP_Y), Vector2(36, HIP_Y), Vector2(44, -98), Vector2(-44, -98)])
			for x in [-1.0, 1.0]:
				_pad(art, [Vector2(54 * x, -92), Vector2(50 * x, -112), Vector2(24 * x, -112), Vector2(22 * x, -92)])
			_colossus_head(art)
		"strider":
			art._rect(-12, HIP_Y - 4, 24, 8, art.trim)
			art._poly(art.torso, art.base)
			art._texture(art.torso)
			_shade(art, art.torso)
			art._poly([Vector2(-8, -88), Vector2(26, -84), Vector2(22, -78), Vector2(-6, -80)], art.trim)
			art._mark([Vector2(-5, -86), Vector2(23, -83)], Color(art.trim.lightened(0.35), 0.8), 1.2)
			_strider_head(art)
		"conduit":
			art._rect(-10, HIP_Y - 6, 20, 10, art.trim)
			art._circle(0, -62, 26, art.base)
			art._texture(art.torso)
			# The orb: a highlight on its upper front, a shadow underneath.
			art.ci.draw_arc(art._p(0, -62), 22.0 * art.s, PI * 1.15, PI * 1.6, 12,
				art._c(Color(art.base.lightened(0.5), 0.6)), 3.0 * art.s, true)
			art.ci.draw_arc(art._p(0, -62), 22.0 * art.s, PI * 0.15, PI * 0.85, 12,
				art._c(Color(art.trim.darkened(0.3), 0.45)), 4.0 * art.s, true)
			for i in range(3):
				var swing: float = 0.5 + 0.15 * sin(art.time * 1.6 + i * 2.1)
				art.ci.draw_arc(art._p(0, -62), (34.0 + i * 4.0) * art.s, -swing, PI + swing, 28,
					art._c(Color(art.element, 0.55 - i * 0.15)), 2.5 * art.s, true)
			_conduit_head(art)
		_:
			var hull: Array = [Vector2(-30, HIP_Y), Vector2(30, HIP_Y), Vector2(36, -88), Vector2(-36, -88)]
			art._rect(-26, HIP_Y - 4, 52, 9, art.trim)
			art._poly(hull, art.base)
			art._texture(art.torso)
			_shade(art, hull)
			_pad(art, [Vector2(-44, -84), Vector2(-40, -98), Vector2(-20, -98), Vector2(-18, -80)])
			_pad(art, [Vector2(18, -80), Vector2(20, -98), Vector2(40, -98), Vector2(44, -84)])
			_bulwark_head(art)


## Light catching the top edge of a hull and shadow pooling at its waist.
## `q` is bottom-left, bottom-right, top-right, top-left.
static func _shade(art: RefCounted, q: Array) -> void:
	var dark: Color = Color(art.trim.darkened(0.5), 0.4)
	var clear: Color = Color(dark, 0.0)
	var points := PackedVector2Array()
	for point in [q[0], q[1], art.quad(q, 1.0, 0.38), art.quad(q, 0.0, 0.38)]:
		points.append(art._p(point.x, point.y))
	art.ci.draw_polygon(points, PackedColorArray([art._c(dark), art._c(dark), art._c(clear), art._c(clear)]))
	var rim: Color = Color(art.base.lightened(0.45), 0.7)
	art._mark([q[3] + Vector2(3, 2.5), q[2] + Vector2(-3, 2.5)], rim, 2.0)


## A shoulder plate with a trim band and a lit upper edge.
static func _pad(art: RefCounted, points: Array) -> void:
	art._poly(points, art.base.lightened(0.05))
	var top_a: Vector2 = points[1]
	var top_b: Vector2 = points[2]
	art._mark([points[0].lerp(top_a, 0.45), points[3].lerp(top_b, 0.45)], art.trim, 2.5)
	art._mark([top_a + Vector2(0, 2), top_b + Vector2(0, 2)], Color(art.base.lightened(0.45), 0.7), 1.5)


## The spirit's eye: a soft glow round a bright slit (or a round lens).
static func _eye(art: RefCounted, at: Vector2, width: float, lens: bool = false) -> void:
	var pulse: float = 0.75 + 0.25 * sin(art.time * 3.0)
	var bright: Color = art.element.lerp(Color.WHITE, 0.35)
	if lens:
		art.glow(at, 11.0, Color(art.element, 0.5 * pulse))
		art._circle(at.x, at.y, 5.0, art.trim)
		art.ci.draw_circle(art._p(at.x, at.y), 3.5 * art.s, art._c(bright))
		art.ci.draw_circle(art._p(at.x + 1.2, at.y - 1.2), 1.2 * art.s, art._c(Color.WHITE))
		return
	art.glow(Vector2(at.x + width / 2.0, at.y + 2.0), 9.0, Color(art.element, 0.45 * pulse))
	art._poly([at, Vector2(at.x + width, at.y), Vector2(at.x + width - 1.0, at.y + 4.5), Vector2(at.x + 1.0, at.y + 4.5)],
		bright, false)
	art._mark([Vector2(at.x + 2.0, at.y + 1.2), Vector2(at.x + width - 3.0, at.y + 1.2)], Color(Color.WHITE, 0.8), 1.0)


static func _bulwark_head(art: RefCounted) -> void:
	var helm: Color = art.base.lightened(0.06)
	art._rect(-7, -94, 14, 6, art.trim)
	art._poly([Vector2(-13, -92), Vector2(13, -92), Vector2(14, -107), Vector2(8, -116), Vector2(-8, -116), Vector2(-14, -107)], helm)
	art._mark([Vector2(-9, -113), Vector2(7, -113)], Color(art.base.lightened(0.45), 0.7), 1.5)
	art._poly([Vector2(-6, -109), Vector2(16, -109), Vector2(16, -104), Vector2(-6, -105)], art.trim)
	_eye(art, Vector2(1, -102), 12.0)
	for x in [-10.0, -6.0]:
		art._mark([Vector2(x, -100), Vector2(x, -95)], art.trim.darkened(0.2), 1.5)


static func _strider_head(art: RefCounted) -> void:
	art._poly([Vector2(2, -112), Vector2(-8, -121), Vector2(-4, -108)], art.trim)
	art._poly([Vector2(1, -92), Vector2(19, -92), Vector2(27, -100), Vector2(22, -111), Vector2(4, -114), Vector2(-1, -104)],
		art.base.lightened(0.06))
	art._mark([Vector2(6, -111), Vector2(20, -109)], Color(art.base.lightened(0.45), 0.7), 1.5)
	art._mark([Vector2(4, -96), Vector2(23, -96)], art.trim, 2.0)
	_eye(art, Vector2(11, -106), 13.0)


static func _conduit_head(art: RefCounted) -> void:
	art._rect(-5, -94, 10, 8, art.trim)
	var dome: Array = []
	for i in range(11):
		var angle: float = PI + PI * i / 10.0
		dome.append(Vector2(cos(angle) * 13.0, -97.0 + sin(angle) * 14.0))
	art._poly(dome, art.base.lightened(0.06))
	art._mark([Vector2(-12, -97), Vector2(12, -97)], art.trim, 2.5)
	art._line(Vector2(-3, -110), Vector2(-7, -120), 2.0, art.trim)
	var bead: float = 0.6 + 0.4 * sin(art.time * 3.5)
	art.glow(Vector2(-7, -121), 6.0, Color(art.element, 0.6 * bead))
	art.ci.draw_circle(art._p(-7, -121), 2.2 * art.s, art._c(art.element.lerp(Color.WHITE, 0.4)))
	art.ci.draw_arc(art._p(0, -97), 10.0 * art.s, PI * 1.2, PI * 1.5, 8, art._c(Color(art.base.lightened(0.5), 0.7)), 1.5 * art.s, true)
	_eye(art, Vector2(5, -103), 0.0, true)


static func _colossus_head(art: RefCounted) -> void:
	for x in [-1.0, 1.0]:
		art._poly([Vector2(14 * x, -120), Vector2(26 * x, -126), Vector2(30 * x, -138), Vector2(20 * x, -128), Vector2(14 * x, -126)], art.trim)
	art._rect(-9, -108, 18, 6, art.trim)
	art._poly([Vector2(-15, -105), Vector2(15, -105), Vector2(16, -121), Vector2(10, -130), Vector2(-10, -130), Vector2(-16, -121)],
		art.base.lightened(0.06))
	for x in [-7.0, 0.0, 7.0]:
		art._poly([Vector2(x - 3.5, -129), Vector2(x, -136 - (3.0 if x == 0.0 else 0.0)), Vector2(x + 3.5, -129)], art.trim.lightened(0.1))
	art._mark([Vector2(-11, -127), Vector2(9, -127)], Color(art.base.lightened(0.45), 0.7), 1.5)
	art._poly([Vector2(-8, -123), Vector2(17, -123), Vector2(17, -118), Vector2(-8, -119)], art.trim)
	_eye(art, Vector2(2, -116), 13.0)
	art._mark([Vector2(-12, -109), Vector2(12, -109)], art.trim.darkened(0.15), 2.0)
