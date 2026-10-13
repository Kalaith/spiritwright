extends RefCounted
## Procedural side-view golems assembled from their parts at runtime. Every
## part keeps a fixed silhouette and anchor so any combination reads clearly;
## the material sets the palette and surface (stone cracks, wood grain, ice
## sheen, bronze rivets, crystal facets). Origin is the point between the feet;
## `facing` is 1 (right) or -1 (left). The element shows as the glowing core
## and eyes plus its letter, not by colour alone. Element reactions add an
## animated aura drawn by golem_fx.gd.

const GolemFx = preload("res://scripts/ui/golem_fx.gd")
const GolemParts = preload("res://scripts/ui/golem_parts.gd")
const OUTLINE := Color("17151e")
## base: main surface; trim: joints, bands and rims; fill_alpha: translucency.
const MATERIALS: Dictionary = {
	"stone": {"base": Color("8f877a"), "trim": Color("625b52"), "fill_alpha": 1.0},
	"wood": {"base": Color("8e5c35"), "trim": Color("573620"), "fill_alpha": 1.0},
	"ice": {"base": Color("a9dcf0"), "trim": Color("5f9fc4"), "fill_alpha": 0.84},
	"bronze": {"base": Color("caa24a"), "trim": Color("7c5a22"), "fill_alpha": 1.0},
	"crystal": {"base": Color("b996e8"), "trim": Color("6f52a8"), "fill_alpha": 0.86},
	"bogwood": {"base": Color("5a5238"), "trim": Color("342f20"), "fill_alpha": 1.0},
	"obsidian": {"base": Color("463c58"), "trim": Color("241e30"), "fill_alpha": 1.0},
	"fulgurite": {"base": Color("d6c48e"), "trim": Color("8a7646"), "fill_alpha": 1.0},
}
const HIP_Y: float = -34.0
const SHOULDER_Y: Dictionary = {"bulwark": -84.0, "strider": -86.0, "conduit": -80.0, "colossus": -96.0}
## Torso quads (bottom-left, bottom-right, top-right, top-left) that surface
## detail is laid out in, so grain and cracks always stay on the body.
const TORSO: Dictionary = {
	"bulwark": [Vector2(-28, -38), Vector2(28, -38), Vector2(33, -84), Vector2(-33, -84)],
	"strider": [Vector2(-13, -38), Vector2(12, -38), Vector2(23, -82), Vector2(-6, -87)],
	"conduit": [Vector2(-17, -45), Vector2(17, -45), Vector2(17, -79), Vector2(-17, -79)],
	"colossus": [Vector2(-34, -38), Vector2(34, -38), Vector2(41, -96), Vector2(-41, -96)],
}
const HEAD: Dictionary = {"bulwark": Vector2(0, -102), "strider": Vector2(13, -102), "conduit": Vector2(0, -104),
	"colossus": Vector2(0, -116)}

var ci: CanvasItem
var origin: Vector2
var s: float
var f: float
var alpha: float
var material: String
var base: Color
var trim: Color
var fill_alpha: float
var element: Color
var time: float
var frame: String
var torso: Array
## Vertical offset for everything above the hips: a slow idle breath.
var lift: float = 0.0


## look: {frame, arms, legs, material, reaction, element_color, team_color, glyph}
## opts: {flash, alpha, shadow, time}
static func draw(canvas: CanvasItem, at: Vector2, scale: float, facing: float, look: Dictionary, opts: Dictionary = {}) -> void:
	var art: RefCounted = load("res://scripts/ui/golem_art.gd").new()
	art.ci = canvas
	art.origin = at
	art.s = scale
	art.f = facing
	art.alpha = float(opts.get("alpha", 1.0))
	art.time = float(opts.get("time", 0.0))
	art.material = String(look.get("material", "stone"))
	var palette: Dictionary = MATERIALS.get(art.material, MATERIALS.stone)
	var flash: float = clampf(float(opts.get("flash", 0.0)), 0.0, 1.0)
	art.base = palette.base.lerp(Color.WHITE, flash)
	art.trim = palette.trim.lerp(Color.WHITE, flash)
	art.fill_alpha = lerpf(palette.fill_alpha, 1.0, flash)
	art.element = look.get("element_color", Color.WHITE)
	art._paint(look, opts)


func _p(x: float, y: float) -> Vector2:
	return origin + Vector2(x * f, y + lift) * s


func _c(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


## A filled, outlined convex shape lit from the upper front: each vertex is
## lightened or darkened by where it sits relative to the shape's centre.
func _poly(points: Array, color: Color, translucent: bool = true) -> void:
	var packed := PackedVector2Array()
	var colors := PackedColorArray()
	var centre := Vector2.ZERO
	for point in points:
		centre += point
	centre /= float(points.size())
	var fill: Color = Color(color, color.a * (fill_alpha if translucent else 1.0))
	for point in points:
		packed.append(_p(point.x, point.y))
		var d: Vector2 = point - centre
		var light: float = clampf((-d.y * 0.7 + d.x * 0.3) / 30.0, -1.0, 1.0)
		colors.append(_c(fill.lightened(light * 0.25) if light > 0.0 else fill.darkened(-light * 0.3)))
	ci.draw_polygon(packed, colors)
	packed.append(packed[0])
	ci.draw_polyline(packed, _c(OUTLINE), 2.0 * s, true)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	_poly([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], color)


func _circle(x: float, y: float, r: float, color: Color, outline: bool = true) -> void:
	var points: Array = []
	for i in range(20):
		var angle: float = TAU * i / 20.0
		points.append(Vector2(x + cos(angle) * r, y + sin(angle) * r))
	if outline:
		_poly(points, color)
	else:
		ci.draw_circle(_p(x, y), r * s, _c(color))


## A limb: outlined bar with a thin highlight along its upper edge.
func _line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	ci.draw_line(_p(a.x, a.y), _p(b.x, b.y), _c(OUTLINE), (width + 3.0) * s, true)
	ci.draw_line(_p(a.x, a.y), _p(b.x, b.y), _c(Color(color, fill_alpha)), width * s, true)
	var normal: Vector2 = (b - a).orthogonal().normalized() * width * 0.22
	if normal.y > 0.0:
		normal = -normal
	ci.draw_line(_p(a.x + normal.x, a.y + normal.y), _p(b.x + normal.x, b.y + normal.y),
		_c(Color(color.lightened(0.3), 0.7)), max(1.0, width * 0.3) * s, true)


## A thin unoutlined mark (grain, cracks, seams) in body coordinates.
func _mark(points: Array, color: Color, width: float = 1.5) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(_p(point.x, point.y))
	ci.draw_polyline(packed, _c(color), width * s, true)


## A soft light: stacked discs, faint at the rim and strongest at the centre.
## `color.a` is the opacity at the centre.
func glow(at: Vector2, radius: float, color: Color) -> void:
	for i in range(10):
		var k: float = 1.0 - i / 10.0
		ci.draw_circle(_p(at.x, at.y), radius * k * s, _c(Color(color, color.a / 10.0)))


## Bilinear point inside a quad (bottom-left, bottom-right, top-right, top-left).
static func quad(q: Array, u: float, v: float) -> Vector2:
	return q[0].lerp(q[1], u).lerp(q[3].lerp(q[2], u), v)


func _paint(look: Dictionary, opts: Dictionary) -> void:
	var team: Color = look.get("team_color", Color.WHITE)
	if opts.get("shadow", true):
		var shadow := PackedVector2Array()
		for i in range(20):
			var angle: float = TAU * i / 20.0
			shadow.append(origin + Vector2(cos(angle) * 46.0, sin(angle) * 10.0) * s)
		ci.draw_colored_polygon(shadow, Color(team.r, team.g, team.b, 0.28 * alpha))
		shadow.append(shadow[0])
		ci.draw_polyline(shadow, Color(team.r, team.g, team.b, 0.8 * alpha), 2.0 * s, true)
	frame = String(look.get("frame", "bulwark"))
	torso = TORSO[frame]
	var arms: String = look.get("arms", "hammer")
	var reaction: String = String(look.get("reaction", ""))
	var breath: float = sin(time * 2.2 + origin.x * 0.013)
	lift = 0.0
	_legs(String(look.get("legs", "pillar")))
	lift = breath * 1.3
	GolemFx.draw(self, reaction, false)
	_back_arm(arms)
	_body()
	_core(String(look.get("glyph", "")))
	_front_arm(arms)
	GolemFx.draw(self, reaction, true)
	lift = 0.0


func _legs(kind: String) -> void:
	if GolemParts.legs(self, kind):
		return
	var dark: Color = base.darkened(0.2)
	if kind == "spider":
		for side in [-1.0, 1.0]:
			for spread in [0.6, 1.0]:
				var hip := Vector2(10.0 * side * spread, HIP_Y + 4.0)
				var knee := Vector2(34.0 * side * spread, HIP_Y - 10.0)
				var foot := Vector2(42.0 * side * spread, 0.0)
				_line(hip, knee, 5.0, dark)
				_line(knee, foot, 4.0, dark)
				_circle(knee.x, knee.y, 3.8, trim)
				_poly([foot + Vector2(-3, -6), foot + Vector2(3, -6), foot], trim)
		_rect(-14, HIP_Y - 2, 28, 10, trim)
		return
	for x in [-20.0, 6.0]:
		_rect(x, HIP_Y + 6.0, 14.0, -HIP_Y - 14.0, dark)
		_rect(x - 2.0, HIP_Y + 2.0, 18.0, 6.0, trim)
		_rect(x - 4.0, -9.0, 22.0, 9.0, trim)
		_mark([Vector2(x + 4.0, HIP_Y + 10.0), Vector2(x + 4.0, -12.0)], base.lightened(0.15), 1.2)


func _body() -> void:
	match frame:
		"colossus":
			GolemParts.colossus(self)
		"strider":
			_rect(-12, HIP_Y - 4, 24, 8, trim)
			_poly(TORSO.strider, base)
			_texture(TORSO.strider)
			_poly([Vector2(-8, -88), Vector2(26, -84), Vector2(22, -78), Vector2(-6, -80)], trim)
			_head(Rect2(2, -113, 22, 21), Vector2(12, -106))
		"conduit":
			_rect(-10, HIP_Y - 6, 20, 10, trim)
			_circle(0, -62, 26, base)
			_texture(TORSO.conduit)
			for i in range(3):
				var swing: float = 0.5 + 0.15 * sin(time * 1.6 + i * 2.1)
				ci.draw_arc(_p(0, -62), (34.0 + i * 4.0) * s, -swing, PI + swing, 28,
					_c(Color(element, 0.55 - i * 0.15)), 2.5 * s, true)
			_head(Rect2(-11, -115, 22, 21), Vector2(2, -107))
		_:
			_rect(-26, HIP_Y - 4, 52, 9, trim)
			_poly([Vector2(-30, HIP_Y), Vector2(30, HIP_Y), Vector2(36, -88), Vector2(-36, -88)], base)
			_texture(TORSO.bulwark)
			_poly([Vector2(-44, -84), Vector2(-40, -98), Vector2(-20, -98), Vector2(-18, -80)], base.lightened(0.05))
			_poly([Vector2(18, -80), Vector2(20, -98), Vector2(40, -98), Vector2(44, -84)], base.lightened(0.05))
			_mark([Vector2(-40, -90), Vector2(-21, -90)], trim, 2.0)
			_mark([Vector2(21, -90), Vector2(40, -90)], trim, 2.0)
			_head(Rect2(-12, -114, 24, 22), Vector2(1, -106))


## The head is a block of the material with a glowing slit where the spirit
## looks out, in its element's colour.
func _head(box: Rect2, eye: Vector2) -> void:
	_rect(box.position.x, box.position.y, box.size.x, box.size.y, base.lightened(0.06))
	_mark([Vector2(box.position.x + 2, box.end.y - 3), Vector2(box.end.x - 2, box.end.y - 3)], trim, 2.0)
	var glow: float = 0.75 + 0.25 * sin(time * 3.0)
	glow(Vector2(eye.x + 4, eye.y + 2), 9.0, Color(element, 0.45 * glow))
	_poly([Vector2(eye.x - 2, eye.y), Vector2(eye.x + 11, eye.y), Vector2(eye.x + 11, eye.y + 5), Vector2(eye.x - 2, eye.y + 5)],
		element.lerp(Color.WHITE, 0.35), false)


## Surface detail that tells the material apart at a glance.
func _texture(q: Array) -> void:
	var dark: Color = Color(trim.darkened(0.2), 0.8)
	var light: Color = Color(base.lightened(0.45), 0.75)
	match material:
		"wood", "bogwood":
			for v in [0.15, 0.36, 0.62, 0.84]:
				var grain: Array = []
				for i in range(9):
					var u: float = 0.06 + i * 0.11
					grain.append(quad(q, u, v + 0.035 * sin(u * 9.0 + v * 7.0)))
				_mark(grain, dark, 1.4)
			var knot: Vector2 = quad(q, 0.74, 0.5)
			ci.draw_arc(_p(knot.x, knot.y), 3.5 * s, 0, TAU, 12, _c(dark), 1.5 * s, true)
			_mark([quad(q, 0.33, 0.0), quad(q, 0.33, 1.0)], Color(dark, 0.45), 1.0)
		"ice":
			_mark([quad(q, 0.1, 0.55), quad(q, 0.3, 0.95)], light, 2.5)
			_mark([quad(q, 0.12, 0.3), quad(q, 0.22, 0.48)], light, 1.5)
			_mark([quad(q, 0.55, 0.0), quad(q, 0.7, 0.4), quad(q, 0.95, 0.55)], Color(Color.WHITE, 0.35), 1.2)
			_mark([quad(q, 0.7, 0.4), quad(q, 0.62, 0.95)], Color(Color.WHITE, 0.3), 1.2)
		"bronze":
			_mark([quad(q, 0.0, 0.82), quad(q, 1.0, 0.82)], dark, 2.0)
			_mark([quad(q, 0.04, 0.88), quad(q, 0.96, 0.88)], light, 1.2)
			for uv in [Vector2(0.08, 0.08), Vector2(0.92, 0.08), Vector2(0.08, 0.7), Vector2(0.92, 0.7)]:
				var rivet: Vector2 = quad(q, uv.x, uv.y)
				ci.draw_circle(_p(rivet.x, rivet.y), 2.2 * s, _c(base.lightened(0.4)))
				ci.draw_arc(_p(rivet.x, rivet.y), 2.2 * s, 0, TAU, 8, _c(dark), 1.0 * s, true)
			_mark([quad(q, 0.22, 0.08), quad(q, 0.3, 0.76)], Color(Color.WHITE, 0.45), 3.0)
			for uv in [Vector2(0.2, 0.35), Vector2(0.78, 0.25)]:
				var spot: Vector2 = quad(q, uv.x, uv.y)
				ci.draw_circle(_p(spot.x, spot.y), 3.2 * s, _c(Color("5fae94", 0.55)))
		"obsidian":
			_mark([quad(q, 0.15, 0.1), quad(q, 0.3, 0.9)], Color(Color.WHITE, 0.35), 2.5)
			_mark([quad(q, 0.62, 0.2), quad(q, 0.72, 0.55)], Color(Color.WHITE, 0.25), 1.5)
			_mark([quad(q, 0.0, 0.4), quad(q, 0.5, 0.62), quad(q, 1.0, 0.45)], dark, 1.2)
		"fulgurite":
			var vein: Array = []
			for i in range(7):
				vein.append(quad(q, 0.2 + (0.25 if i % 2 == 0 else 0.0) + i * 0.06, 0.05 + i * 0.15))
			_mark(vein, Color(Color("fff2a8"), 0.5 + 0.4 * sin(time * 6.0)), 1.8)
			_mark([quad(q, 0.0, 0.7), quad(q, 1.0, 0.7)], dark, 1.5)
		"crystal":
			var tip: Vector2 = quad(q, 0.5, 1.15)
			for u in [0.0, 0.3, 0.7, 1.0]:
				_mark([quad(q, u, 0.0), quad(q, 0.5, 0.5), tip], Color(base.lightened(0.5), 0.45), 1.2)
			for i in range(3):
				var twinkle: float = maxf(0.0, sin(time * 2.5 + i * 2.3))
				var at: Vector2 = quad(q, [0.18, 0.82, 0.35][i], [0.8, 0.6, 0.18][i])
				var r: float = 2.0 + twinkle * 3.0
				_mark([at + Vector2(-r, 0), at + Vector2(r, 0)], Color(Color.WHITE, twinkle), 1.2)
				_mark([at + Vector2(0, -r), at + Vector2(0, r)], Color(Color.WHITE, twinkle), 1.2)
		_:
			_mark([quad(q, 0.15, 0.95), quad(q, 0.25, 0.75), quad(q, 0.18, 0.6), quad(q, 0.27, 0.45)], dark, 1.5)
			_mark([quad(q, 0.92, 0.2), quad(q, 0.8, 0.32), quad(q, 0.84, 0.42)], dark, 1.5)
			_mark([quad(q, 0.0, 0.5), quad(q, 0.12, 0.5)], dark, 1.2)
			_mark([quad(q, 0.88, 0.62), quad(q, 1.0, 0.62)], dark, 1.2)


func _core(glyph: String) -> void:
	var y: float = -62.0 if frame == "conduit" else -60.0
	var pulse: float = 0.5 + 0.5 * sin(time * 2.6)
	glow(Vector2(0, y), 15.0 + pulse * 4.0, Color(element, 0.45 + pulse * 0.15))
	_circle(0, y, 10, trim)
	ci.draw_circle(_p(0, y), 8.0 * s, _c(element))
	ci.draw_circle(_p(-2.5, y - 2.5), 3.0 * s, _c(Color(element.lerp(Color.WHITE, 0.7), 0.8)))
	if glyph.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var size: int = int(13 * s)
	var width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, _p(0, y) + Vector2(-width / 2.0, size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _c(OUTLINE))


func _back_arm(arms: String) -> void:
	if arms == "cannon":
		return
	var shoulder := Vector2(-18.0, SHOULDER_Y[frame] + 6.0)
	var elbow := Vector2(-24.0, SHOULDER_Y[frame] + 24.0)
	var dark: Color = base.darkened(0.35)
	_line(shoulder, elbow, 7.0, dark)
	_line(elbow, Vector2(-22.0, SHOULDER_Y[frame] + 40.0), 6.0, dark)
	_circle(elbow.x, elbow.y, 4.0, trim.darkened(0.2))


func _front_arm(arms: String) -> void:
	var sy: float = SHOULDER_Y[frame]
	if GolemParts.front_arm(self, arms, sy):
		return
	match arms:
		"shield":
			_line(Vector2(18, sy + 4), Vector2(34, sy + 26), 7.0, base.darkened(0.1))
			_poly([Vector2(31, sy - 12), Vector2(52, sy - 5), Vector2(52, sy + 46), Vector2(31, sy + 58)], trim)
			_poly([Vector2(35, sy - 6), Vector2(48, sy - 1), Vector2(48, sy + 42), Vector2(35, sy + 51)], base.lightened(0.08))
			_poly([Vector2(41.5, sy + 10), Vector2(46, sy + 22), Vector2(41.5, sy + 34), Vector2(37, sy + 22)],
				element.lerp(Color.WHITE, 0.2), false)
		"cannon":
			_rect(2, sy, 20, 20, trim)
			_poly([Vector2(18, sy + 3), Vector2(62, sy + 4), Vector2(62, sy + 18), Vector2(18, sy + 19)], base)
			for x in [30.0, 44.0]:
				_rect(x, sy + 1, 5, 20, trim)
			_rect(60, sy, 9, 22, trim.darkened(0.15))
			var charge: float = 0.6 + 0.4 * sin(time * 4.0)
			glow(Vector2(70, sy + 11), 7.0 + charge * 4.0, Color(element, 0.6 * charge))
			ci.draw_circle(_p(70, sy + 11), 4.0 * s, _c(element.lerp(Color.WHITE, 0.4)))
		_:
			var hand := Vector2(40, sy + 30)
			_line(Vector2(18, sy + 4), Vector2(28, sy + 20), 8.0, base.darkened(0.1))
			_line(Vector2(28, sy + 20), hand, 7.0, base.darkened(0.1))
			_circle(28, sy + 20, 4.5, trim)
			_line(hand + Vector2(-2, 6), Vector2(47, sy - 12), 4.0, Color("5b4a3a"))
			_poly([Vector2(33, sy - 28), Vector2(61, sy - 26), Vector2(61, sy - 6), Vector2(33, sy - 8)], base.lightened(0.1))
			_rect(43, sy - 29, 6, 24, trim)
			_circle(hand.x, hand.y, 5.0, trim)


## Builds the `look` for any loadout or resolved golem (both carry these keys).
static func look_for(catalog: RefCounted, golem: Dictionary, team: Color) -> Dictionary:
	var element: String = String(catalog.spirit(String(golem.spirit)).element)
	var reaction: Dictionary = catalog.reaction(String(golem.material), element)
	return {
		"frame": golem.frame, "arms": golem.arms, "legs": golem.legs, "material": golem.material,
		"reaction": String(reaction.get("id", "")), "team_color": team,
		"element_color": catalog.element_color(element), "glyph": catalog.element_glyph(element),
	}
