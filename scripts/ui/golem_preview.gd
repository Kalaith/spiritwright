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
		# A little stage: light from above, a pool of it on the floor under the golem.
		var top: Color = backdrop.lightened(0.06)
		var low: Color = backdrop.darkened(0.35)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, low, low]))
		var feet := Vector2(size.x / 2.0, size.y - 14.0 * art_scale)
		var pool: PackedVector2Array = PackedVector2Array()
		for i in range(20):
			var a: float = TAU * i / 20.0
			pool.append(feet + Vector2(cos(a) * size.x * 0.32, sin(a) * 16.0 * art_scale))
		draw_colored_polygon(pool, Color(1, 1, 1, 0.04))
	if look.is_empty():
		return
	# A tall frame shrinks just enough that its head stays inside the control.
	var height: float = GolemArt.HEIGHT.get(String(look.get("frame", "")), 120.0) + 16.0
	var fit: float = minf(art_scale, (size.y - 2.0) / height)
	GolemArt.draw(self, Vector2(size.x / 2.0, size.y - 14.0 * fit), fit, facing, look,
		{"time": Time.get_ticks_msec() / 1000.0 if animated else 0.0, "alpha": alpha})
