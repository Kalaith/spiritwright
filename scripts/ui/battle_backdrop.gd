extends RefCounted
## The Ancient Ruins behind a battle: a dim sky, broken columns and arches on
## the horizon, and a mossy flagstone floor in perspective. Every shape comes
## from fixed tables so the scene is identical each time it is drawn.

const SKY_TOP := Color("0d1018")
const SKY_LOW := Color("1a2130")
const RUIN := Color("232a38")
const RUIN_EDGE := Color("2e3647")
const FLOOR := Color("1d2219")
const FLOOR_FAR := Color("161b16")
const SEAM := Color(1, 1, 1, 0.045)
const MOSS := Color("232f1d")
## [x as a fraction of the width, width, height, broken-top tilt]
const COLUMNS: Array = [[0.05, 34, 120, 8], [0.17, 26, 70, -6], [0.31, 30, 140, 0], [0.44, 22, 52, 10],
	[0.58, 28, 96, -9], [0.7, 34, 150, 0], [0.83, 24, 64, 7], [0.95, 30, 110, -5]]
## [left column index, right column index]: arches spring from the shorter column.
const ARCHES: Array = [[0, 1], [6, 7]]
## [x fraction, depth fraction, radius x, radius y]
const MOSS_PATCHES: Array = [[0.12, 0.25, 70, 12], [0.36, 0.6, 90, 16], [0.62, 0.35, 60, 10],
	[0.86, 0.75, 110, 18], [0.22, 0.9, 80, 14], [0.75, 0.1, 50, 8]]


static func draw(ci: CanvasItem, size: Vector2, horizon: float, floor_bottom: float) -> void:
	var bands: int = 8
	for i in range(bands):
		var y0: float = horizon * i / bands
		ci.draw_rect(Rect2(0, y0, size.x, horizon / bands + 1.0), SKY_TOP.lerp(SKY_LOW, float(i) / (bands - 1)))
	_ruins(ci, size, horizon)
	ci.draw_rect(Rect2(0, horizon, size.x, size.y - horizon), FLOOR)
	var depth: float = floor_bottom - horizon
	# Floor darkens toward the horizon.
	for i in range(6):
		var y: float = horizon + depth * i / 12.0
		ci.draw_rect(Rect2(0, y, size.x, depth / 12.0 + 1.0), FLOOR_FAR.lerp(FLOOR, i / 6.0))
	for patch in MOSS_PATCHES:
		_ellipse(ci, Vector2(size.x * patch[0], horizon + depth * patch[1]), patch[2], patch[3], MOSS)
	# Flagstones: rows widen toward the viewer, joints converge on a vanishing point.
	var vanish := Vector2(size.x / 2.0, horizon - depth * 1.4)
	for i in range(1, 10):
		var y: float = horizon + pow(i / 9.0, 1.6) * depth
		ci.draw_line(Vector2(0, y), Vector2(size.x, y), SEAM, 1.0)
	for i in range(-12, 13):
		var foot := Vector2(size.x / 2.0 + i * 120.0, floor_bottom)
		var top: Vector2 = vanish.lerp(foot, (horizon - vanish.y) / (floor_bottom - vanish.y))
		ci.draw_line(top, foot, SEAM, 1.0)
	ci.draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color(RUIN_EDGE, 0.8), 2.0)


static func _ruins(ci: CanvasItem, size: Vector2, horizon: float) -> void:
	for arch in ARCHES:
		var left: Array = COLUMNS[arch[0]]
		var right: Array = COLUMNS[arch[1]]
		var x0: float = size.x * left[0]
		var x1: float = size.x * right[0]
		var top: float = horizon - min(left[2], right[2]) + 6.0
		var centre := Vector2((x0 + x1) / 2.0, top)
		ci.draw_arc(centre, (x1 - x0) / 2.0, PI, TAU, 40, RUIN, 22.0, true)
		ci.draw_arc(centre, (x1 - x0) / 2.0 + 11.0, PI + 0.05, TAU - 0.05, 40, RUIN_EDGE, 2.0, true)
	for column in COLUMNS:
		var x: float = size.x * column[0]
		var w: float = column[1]
		var h: float = column[2]
		var tilt: float = column[3]
		var shape := PackedVector2Array([Vector2(x - w / 2.0, horizon), Vector2(x + w / 2.0, horizon),
			Vector2(x + w / 2.0, horizon - h + tilt), Vector2(x - w / 2.0, horizon - h - tilt)])
		ci.draw_colored_polygon(shape, RUIN)
		ci.draw_line(shape[3], shape[0], RUIN_EDGE, 2.0)
		ci.draw_line(shape[2], shape[3], RUIN_EDGE, 2.0)
		# Fluting and a base block.
		ci.draw_line(Vector2(x - w / 6.0, horizon - 8), Vector2(x - w / 6.0, horizon - h + 14), Color(RUIN_EDGE, 0.6), 1.0)
		ci.draw_line(Vector2(x + w / 6.0, horizon - 8), Vector2(x + w / 6.0, horizon - h + 14), Color(RUIN_EDGE, 0.6), 1.0)
		ci.draw_rect(Rect2(x - w / 2.0 - 5.0, horizon - 10.0, w + 10.0, 10.0), RUIN_EDGE)
		# Ivy trailing down the column.
		for k in range(int(h / 22.0)):
			var at := Vector2(x + (w / 3.0) * sin(k * 1.9 + x), horizon - h + 10.0 + k * 20.0)
			ci.draw_circle(at, 4.0, MOSS)


static func _ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(18):
		var angle: float = TAU * i / 18.0
		points.append(centre + Vector2(cos(angle) * rx, sin(angle) * ry))
	ci.draw_colored_polygon(points, color)
