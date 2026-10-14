extends RefCounted
## Procedural side-view golems assembled from their parts at runtime. Every
## part keeps a fixed silhouette and anchor so any combination reads clearly;
## the material sets the palette and surface (stone cracks, wood grain, ice
## sheen, bronze rivets, crystal facets). Origin is the point between the feet;
## `facing` is 1 (right) or -1 (left). The element shows as the glowing core
## and eyes plus its letter, not by colour alone. Element reactions add an
## animated aura drawn by golem_fx.gd.

const GolemFx = preload("res://scripts/ui/golem_fx.gd")
const GolemFrames = preload("res://scripts/ui/golem_frames.gd")
const GolemLegs = preload("res://scripts/ui/golem_legs.gd")
const GolemParts = preload("res://scripts/ui/golem_parts.gd")
const Style = preload("res://scripts/ui/style.gd")
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
## How far each frame's head (crest, antenna or crown) rises above the feet.
const HEIGHT: Dictionary = {"bulwark": 117.0, "strider": 122.0, "conduit": 124.0, "colossus": 140.0}
## Torso quads (bottom-left, bottom-right, top-right, top-left) that surface
## detail is laid out in, so grain and cracks always stay on the body.
const TORSO: Dictionary = {
	"bulwark": [Vector2(-28, -38), Vector2(28, -38), Vector2(33, -84), Vector2(-33, -84)],
	"strider": [Vector2(-13, -38), Vector2(12, -38), Vector2(23, -82), Vector2(-6, -87)],
	"conduit": [Vector2(-17, -45), Vector2(17, -45), Vector2(17, -79), Vector2(-17, -79)],
	"colossus": [Vector2(-34, -38), Vector2(34, -38), Vector2(41, -96), Vector2(-41, -96)],
}

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
## A Crucible vessel finish: trim recoloured and a halo round the core (alpha 0 for none).
var finish: Color = Color(0, 0, 0, 0)
var time: float
var frame: String
var torso: Array
## Vertical offset for everything above the hips: a slow idle breath.
var lift: float = 0.0


## look: {frame, arms, legs, material, reaction, element_color, team_color, glyph, finish_color (optional)}
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
	art.finish = look.get("finish_color", Color(0, 0, 0, 0))
	if art.finish.a > 0.0:
		art.trim = art.trim.lerp(art.finish, 0.7)
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


## A soft light fading smoothly from the centre to nothing at the rim.
## `color.a` is the opacity at the centre.
func glow(at: Vector2, radius: float, color: Color) -> void:
	Style.radial(ci, _p(at.x, at.y), radius * s, _c(color))


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
		# A darker contact shadow right under the feet, so the golem stands on the ground.
		Style.radial(ci, origin, 34.0 * s, Color(0, 0, 0, 0.45 * alpha), Vector2(1.0, 0.2))
	frame = String(look.get("frame", "bulwark"))
	torso = TORSO[frame]
	var arms: String = look.get("arms", "hammer")
	var reaction: String = String(look.get("reaction", ""))
	var breath: float = sin(time * 2.2 + origin.x * 0.013)
	lift = 0.0
	GolemLegs.draw(self, String(look.get("legs", "pillar")))
	lift = breath * 1.3
	GolemFx.draw(self, reaction, false)
	GolemParts.back_arm(self, arms, SHOULDER_Y[frame])
	GolemFrames.body(self)
	_core(String(look.get("glyph", "")))
	GolemParts.front_arm(self, arms, SHOULDER_Y[frame])
	GolemFx.draw(self, reaction, true)
	lift = 0.0


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
	if finish.a > 0.0:
		glow(Vector2(0, y), 30.0 + pulse * 6.0, Color(finish, 0.4))
	glow(Vector2(0, y), 15.0 + pulse * 4.0, Color(element, 0.45 + pulse * 0.15))
	# The socket the spirit sits in: a trim ring set into the body with four clasps.
	for angle in [0.25, 0.75, 1.25, 1.75]:
		var dir := Vector2(cos(angle * PI), sin(angle * PI))
		_poly([Vector2(0, y) + dir * 9.0 + dir.orthogonal() * 3.0, Vector2(0, y) + dir * 14.0,
			Vector2(0, y) + dir * 9.0 - dir.orthogonal() * 3.0], trim.darkened(0.1), false)
	_circle(0, y, 10.5, trim)
	ci.draw_arc(_p(0, y), 9.5 * s, PI * 1.1, PI * 1.6, 8, _c(Color(trim.lightened(0.45), 0.8)), 1.2 * s, true)
	ci.draw_circle(_p(0, y), 8.0 * s, _c(element))
	ci.draw_circle(_p(-2.5, y - 2.5), 3.0 * s, _c(Color(element.lerp(Color.WHITE, 0.7), 0.8)))
	if glyph.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var size: int = int(13 * s)
	var width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, _p(0, y) + Vector2(-width / 2.0, size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _c(OUTLINE))


## Builds the `look` for any loadout or resolved golem (both carry these keys).
static func look_for(catalog: RefCounted, golem: Dictionary, team: Color) -> Dictionary:
	var element: String = String(catalog.spirit(String(golem.spirit)).element)
	var reaction: Dictionary = catalog.reaction(String(golem.material), element)
	var look: Dictionary = {
		"frame": golem.frame, "arms": golem.arms, "legs": golem.legs, "material": golem.material,
		"reaction": String(reaction.get("id", "")), "team_color": team,
		"element_color": catalog.element_color(element), "glyph": catalog.element_glyph(element),
	}
	var finish: Dictionary = catalog.crucible_index.finishes.get(String(golem.get("finish", "")), {})
	if not finish.is_empty():
		look["finish_color"] = Color(String(finish.color))
	return look
