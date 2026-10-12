extends RefCounted
## Procedural side-view golems assembled from their parts at runtime. Every
## part keeps a fixed silhouette and anchor so any combination reads clearly.
## Origin is the point between the feet; `facing` is 1 (right) or -1 (left).
## The element shows as the glowing core plus its letter, not by colour alone.

const OUTLINE := Color("17151e")
const FRAME_COLORS: Dictionary = {
	"bulwark": Color("8a8274"), "strider": Color("8d93a6"), "conduit": Color("77709a"),
}
const HIP_Y: float = -34.0
const SHOULDER_Y: Dictionary = {"bulwark": -84.0, "strider": -86.0, "conduit": -80.0}

var ci: CanvasItem
var origin: Vector2
var s: float
var f: float
var stone: Color
var alpha: float


## look: {frame, arms, legs, element_color, team_color, glyph}; opts: {flash, alpha, shadow}
static func draw(canvas: CanvasItem, at: Vector2, scale: float, facing: float, look: Dictionary, opts: Dictionary = {}) -> void:
	var art: RefCounted = load("res://scripts/ui/golem_art.gd").new()
	art.ci = canvas
	art.origin = at
	art.s = scale
	art.f = facing
	art.alpha = float(opts.get("alpha", 1.0))
	var base: Color = FRAME_COLORS.get(look.get("frame", ""), Color("8a8274"))
	art.stone = base.lerp(Color.WHITE, clampf(float(opts.get("flash", 0.0)), 0.0, 1.0))
	art._paint(look, opts)


func _p(x: float, y: float) -> Vector2:
	return origin + Vector2(x * f, y) * s


func _c(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(_p(point.x, point.y))
	ci.draw_colored_polygon(packed, _c(color))
	packed.append(packed[0])
	ci.draw_polyline(packed, _c(OUTLINE), 2.0 * s, true)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	_poly([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], color)


func _circle(x: float, y: float, r: float, color: Color, outline: bool = true) -> void:
	ci.draw_circle(_p(x, y), r * s, _c(color))
	if outline:
		ci.draw_arc(_p(x, y), r * s, 0, TAU, 24, _c(OUTLINE), 2.0 * s, true)


func _line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	ci.draw_line(_p(a.x, a.y), _p(b.x, b.y), _c(OUTLINE), (width + 3.0) * s, true)
	ci.draw_line(_p(a.x, a.y), _p(b.x, b.y), _c(color), width * s, true)


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
	var frame: String = look.get("frame", "bulwark")
	var arms: String = look.get("arms", "hammer")
	_back_arm(frame, arms)
	_legs(String(look.get("legs", "pillar")))
	_body(frame)
	_core(frame, look.get("element_color", Color.WHITE), String(look.get("glyph", "")))
	_front_arm(frame, arms)


func _legs(kind: String) -> void:
	var dark: Color = stone.darkened(0.25)
	if kind == "spider":
		for side in [-1.0, 1.0]:
			for spread in [0.6, 1.0]:
				var hip := Vector2(10.0 * side * spread, HIP_Y + 4.0)
				var knee := Vector2(34.0 * side * spread, HIP_Y - 10.0)
				var foot := Vector2(42.0 * side * spread, 0.0)
				_line(hip, knee, 5.0, dark)
				_line(knee, foot, 4.0, dark)
				_circle(knee.x, knee.y, 3.5, stone)
		return
	for x in [-20.0, 6.0]:
		_rect(x, HIP_Y + 2.0, 14.0, -HIP_Y - 8.0, dark)
		_rect(x - 4.0, -8.0, 22.0, 8.0, stone.darkened(0.1))


func _body(frame: String) -> void:
	match frame:
		"strider":
			_poly([Vector2(-16, HIP_Y), Vector2(14, HIP_Y), Vector2(26, -84), Vector2(-8, -90)], stone)
			_rect(2, -112, 22, 20, stone.lightened(0.08))
			_rect(12, -106, 12, 5, Color("f6e8b0"))
		"conduit":
			_rect(-10, HIP_Y - 6, 20, 10, stone.darkened(0.15))
			_circle(0, -62, 26, stone)
			ci.draw_arc(_p(0, -62), 36.0 * s, -0.5, PI + 0.5, 28, _c(stone.lightened(0.35)), 3.0 * s, true)
			_circle(0, -104, 11, stone.lightened(0.08))
			_rect(2, -107, 9, 4, Color("f6e8b0"))
		_:
			_poly([Vector2(-30, HIP_Y), Vector2(30, HIP_Y), Vector2(36, -88), Vector2(-36, -88)], stone)
			_rect(-40, -94, 20, 16, stone.lightened(0.06))
			_rect(20, -94, 20, 16, stone.lightened(0.06))
			_rect(-12, -112, 24, 20, stone.lightened(0.08))
			_rect(0, -105, 12, 5, Color("f6e8b0"))


func _core(frame: String, color: Color, glyph: String) -> void:
	var y: float = -62.0 if frame == "conduit" else -60.0
	ci.draw_circle(_p(0, y), 16.0 * s, _c(Color(color.r, color.g, color.b, 0.3)))
	_circle(0, y, 10, color)
	if glyph.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var size: int = int(13 * s)
	var width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, _p(0, y) + Vector2(-width / 2.0, size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _c(OUTLINE))


func _back_arm(frame: String, arms: String) -> void:
	if arms == "cannon":
		return
	var shoulder := Vector2(-18.0, SHOULDER_Y[frame] + 6.0)
	_line(shoulder, Vector2(-26.0, SHOULDER_Y[frame] + 36.0), 7.0, stone.darkened(0.35))


func _front_arm(frame: String, arms: String) -> void:
	var sy: float = SHOULDER_Y[frame]
	match arms:
		"shield":
			_line(Vector2(18, sy + 4), Vector2(34, sy + 26), 7.0, stone.darkened(0.1))
			_poly([Vector2(32, sy - 10), Vector2(50, sy - 4), Vector2(50, sy + 48), Vector2(32, sy + 56)], Color("6f7a86"))
			_circle(41, sy + 22, 6, Color("c9d3dd"))
		"cannon":
			_rect(4, sy + 2, 18, 18, stone.darkened(0.1))
			_rect(18, sy + 4, 46, 14, Color("5d5872"))
			_rect(60, sy + 1, 8, 20, Color("4a4560"))
			ci.draw_circle(_p(68, sy + 11), 4.0 * s, _c(Color("f6e8b0")))
		_:
			var hand := Vector2(40, sy + 30)
			_line(Vector2(18, sy + 4), hand, 8.0, stone.darkened(0.1))
			_line(hand, Vector2(46, sy - 10), 4.0, Color("5b4a3a"))
			_rect(34, sy - 26, 26, 18, Color("5d5a66"))


## Builds the `look` for any loadout or resolved golem (both carry these keys).
static func look_for(catalog: RefCounted, golem: Dictionary, team: Color) -> Dictionary:
	var element: String = String(catalog.spirit(String(golem.spirit)).element)
	return {
		"frame": golem.frame, "arms": golem.arms, "legs": golem.legs, "team_color": team,
		"element_color": catalog.element_color(element), "glyph": catalog.element_glyph(element),
	}
