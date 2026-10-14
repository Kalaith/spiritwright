extends Control
## The place a battle is fought: each region (and the Crucible) has its own sky,
## horizon and ground. Drawn once behind the battle view and again only on a
## resize; the moving weather lives in battle_weather.gd. Every shape comes from
## fixed tables or a fixed seed, so a scene is identical each time it is drawn.

const Horizons = preload("res://scripts/ui/battle_horizons.gd")
const Grounds = preload("res://scripts/ui/battle_grounds.gd")
const Style = preload("res://scripts/ui/style.gd")

## sky: [zenith, horizon]; far / near: silhouette layers; edge: rims and highlights;
## floor: [at the horizon, at the viewer]; patch: ground detail; haze: the light along the horizon.
const SCENES: Dictionary = {
	"ruins": {"sky": ["0b0e16", "222b3c"], "far": "171c28", "near": "232a38", "edge": "333c50",
		"floor": ["151a15", "20271c"], "patch": "26331f", "haze": "6f8f9f"},
	"fen": {"sky": ["081214", "21403a"], "far": "10221d", "near": "15241f", "edge": "2e4a40",
		"floor": ["0f1a16", "1a2b22"], "patch": "143038", "haze": "7fc8b0"},
	"steppe": {"sky": ["160a12", "7a2f1a"], "far": "3c1b16", "near": "24120f", "edge": "5a3020",
		"floor": ["1f1410", "33231a"], "patch": "3c2819", "haze": "ff8a4a"},
	"frost": {"sky": ["0a1222", "345077"], "far": "2b3f5c", "near": "1b283d", "edge": "dfeaf7",
		"floor": ["223246", "34485e"], "patch": "4b6280", "haze": "bfe4ff"},
	"storm": {"sky": ["08060f", "2c2648"], "far": "1d1931", "near": "141221", "edge": "3d3666",
		"floor": ["121119", "1e1d29"], "patch": "202a3a", "haze": "9d8cff"},
	"crucible": {"sky": ["0e0808", "35201a"], "far": "2a1b16", "near": "1d1310", "edge": "5a3a24",
		"floor": ["251b14", "3e2f22"], "patch": "4a3826", "haze": "ffb347"},
}

var scene: String = "ruins"


static func palette(scene_id: String) -> Dictionary:
	return SCENES.get(scene_id, SCENES.ruins)


## Where the sky meets the ground, and where the ground ends above the log.
static func horizon_for(area: Vector2) -> float:
	return 70.0 + (area.y - 220.0) * 0.25


static func floor_bottom_for(area: Vector2) -> float:
	return area.y - 150.0


## A scene and its weather behind a whole screen, dimmed by `dim` so panels read over it.
static func scenery(parent: Control, scene_id: String, dim: float) -> void:
	var Weather: GDScript = load("res://scripts/ui/battle_weather.gd")
	for layer in [new(), Weather.new()]:
		layer.scene = scene_id
		parent.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	paint(self, size, scene)


## The whole static scene onto any canvas item (the title and result screens borrow it).
static func paint(ci: CanvasItem, area: Vector2, scene_id: String) -> void:
	var pal: Dictionary = palette(scene_id)
	var horizon: float = horizon_for(area)
	gradient(ci, Rect2(0, 0, area.x, horizon), Color(pal.sky[0]), Color(pal.sky[1]))
	Horizons.draw(ci, area, horizon, scene_id, pal)
	gradient(ci, Rect2(0, horizon, area.x, area.y - horizon), Color(pal.floor[0]), Color(pal.floor[1]))
	Grounds.draw(ci, area, horizon, floor_bottom_for(area), scene_id, pal)
	# Light pooling where the sky meets the ground gives the scene its depth.
	var haze: Color = Color(pal.haze)
	gradient(ci, Rect2(0, horizon - 60.0, area.x, 60.0), Color(haze, 0.0), Color(haze, 0.1))
	gradient(ci, Rect2(0, horizon, area.x, 40.0), Color(haze, 0.08), Color(haze, 0.0))
	ci.draw_line(Vector2(0, horizon), Vector2(area.x, horizon), Color(pal.edge, 0.5), 2.0)
	vignette(ci, area)


## A vertical blend from `top` to `bottom` across a rectangle.
static func gradient(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))


## Darkened edges so the eye settles on the golems in the middle.
static func vignette(ci: CanvasItem, area: Vector2) -> void:
	var dark := Color(0, 0, 0, 0.5)
	var clear := Color(0, 0, 0, 0)
	var w: float = area.x * 0.16
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, area.y), Vector2(0, area.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	ci.draw_polygon(PackedVector2Array([Vector2(area.x - w, 0), Vector2(area.x, 0), area, Vector2(area.x - w, area.y)]),
		PackedColorArray([clear, dark, dark, clear]))
	gradient(ci, Rect2(0, 0, area.x, 70.0), Color(0, 0, 0, 0.45), clear)


static func ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * i / 20.0
		points.append(centre + Vector2(cos(angle) * rx, sin(angle) * ry))
	ci.draw_colored_polygon(points, color)


## A soft round glow; `strength` 1 is a gentle light, 2 a bright one.
static func glow(ci: CanvasItem, centre: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	Style.radial(ci, centre, radius, Color(color, clampf(0.4 * strength, 0.0, 1.0)))
