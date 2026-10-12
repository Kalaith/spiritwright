extends Control
## Draws one golem standing on the bottom-centre of the control.

const GolemArt = preload("res://scripts/ui/golem_art.gd")

var look: Dictionary = {}
var facing: float = 1.0
var art_scale: float = 1.0
var backdrop: Color = Color(0, 0, 0, 0)
## Below 1 the golem is a faint outline, as for a body not yet built.
var alpha: float = 1.0
## Redraw every frame so material sparkle and reaction auras move.
var animated: bool = false


func _process(_delta: float) -> void:
	if animated and is_visible_in_tree():
		queue_redraw()


func setup(new_look: Dictionary, new_scale: float, new_facing: float = 1.0) -> void:
	look = new_look
	art_scale = new_scale
	facing = new_facing
	queue_redraw()


func _draw() -> void:
	if backdrop.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), backdrop)
	if look.is_empty():
		return
	GolemArt.draw(self, Vector2(size.x / 2.0, size.y - 14.0 * art_scale), art_scale, facing, look,
		{"time": Time.get_ticks_msec() / 1000.0 if animated else 0.0, "alpha": alpha})
