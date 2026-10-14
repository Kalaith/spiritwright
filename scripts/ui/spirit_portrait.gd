extends Control
## A spirit's portrait (assets/spirits/<id>.png) fitted inside the control on
## a soft glow of its element. A spirit not yet found shows only as a dark
## silhouette. Portraits only ever show who a spirit is; they change nothing.

const Style = preload("res://scripts/ui/style.gd")
const FOLDER: String = "res://assets/spirits/"
## How dark a spirit not yet found is drawn: its shape, no colour.
const SILHOUETTE := Color(0.07, 0.06, 0.1, 0.85)
## The share of each edge left out: empty in every portrait, whose sizes stay
## true to each other (a sovereign fills its frame, a mote does not).
const MARGIN: float = 0.06

var spirit_id: String = ""
var found: bool = true
## The glow behind the spirit (its element's colour); clear for none.
var glow: Color = Color(0, 0, 0, 0)
## Mirror the art so the spirit faces left, as enemies do.
var flip: bool = false
var _texture: Texture2D


static func path_for(id: String) -> String:
	return FOLDER + id + ".png"


static func has_portrait(id: String) -> bool:
	return ResourceLoader.exists(path_for(id))


## A portrait sized `side` square, for cards and lists.
static func make(id: String, side: float, element_color: Color, is_found: bool = true) -> Control:
	var portrait: Control = load("res://scripts/ui/spirit_portrait.gd").new()
	portrait.spirit_id = id
	portrait.found = is_found
	portrait.glow = Color(element_color, 0.35) if is_found else Color(Style.MUTED, 0.12)
	portrait.custom_minimum_size = Vector2(side, side)
	return portrait


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_portrait(spirit_id):
		_texture = load(path_for(spirit_id)) as Texture2D
	else:
		push_warning("Spiritwright: no portrait for spirit " + spirit_id)


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var centre: Vector2 = size / 2.0
	if glow.a > 0.0:
		Style.radial(self, centre, side * 0.48, glow)
	if _texture == null:
		return
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	var rect := Rect2(centre - Vector2(side, side) / 2.0, Vector2(side, side))
	var art: Vector2 = _texture.get_size()
	var region := Rect2(art * MARGIN, art * (1.0 - 2.0 * MARGIN))
	draw_texture_rect_region(_texture, rect, region, Color.WHITE if found else SILHOUETTE)
	draw_set_transform(Vector2.ZERO)
