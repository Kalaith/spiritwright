extends PanelContainer
## An empty cradle in the laboratory: a golem not yet built. With a golem core
## on the bench it offers to build one; otherwise it says where cores are found.

signal build_requested

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")

var catalog: RefCounted
var progression: RefCounted
var slot: int = 0
var ready_to_build: bool = false


func _ready() -> void:
	var border: Color = Style.GOLD.darkened(0.2) if ready_to_build else Style.LINE
	add_theme_stylebox_override("panel", Style.box(Color(Style.PANEL, 0.6), border, 10, 10))
	var column := Style.vbox(8)
	add_child(column)
	column.add_child(Style.label("Golem %d" % (slot + 1), 18, Style.GOLD if ready_to_build else Style.MUTED))
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(0, 128)
	preview.backdrop = Color("16151f")
	preview.alpha = 0.55 if ready_to_build else 0.18
	preview.animated = ready_to_build
	var frame: Dictionary = {"spirit": progression.team[0].spirit, "frame": progression.unlocks.frames[0],
		"arms": progression.unlocks.arms[0], "legs": progression.unlocks.legs[0], "material": progression.unlocks.materials[0]}
	var look: Dictionary = GolemArt.look_for(catalog, frame, Style.MUTED)
	look.element_color = Style.GOLD if ready_to_build else Style.LINE
	look.glyph = ""
	look.reaction = ""
	preview.setup(look, 0.9)
	column.add_child(preview)
	if ready_to_build:
		var spirit: Dictionary = catalog.spirit(progression.resting_spirits()[0])
		column.add_child(Style.wrapped("A golem core hums on the workbench. Build a body and %s wakes in it; change its spirit and parts once it stands." % spirit.name, 14, Style.TEXT))
		var build := Style.button("Build golem (uses 1 core)", func(): build_requested.emit(), 18)
		column.add_child(build)
	else:
		column.add_child(Style.wrapped("An empty cradle. A golem core would bring a body to life here.", 14, Style.TEXT))
		column.add_child(Style.wrapped(_where_cores_are(), 13))


func _where_cores_are() -> String:
	var places: Array[String] = []
	for stage in catalog.stages.values():
		if int(stage.get("rewards", {}).get("cores", 0)) > 0 and not stage.id in progression.cleared:
			places.append(stage.name)
	if places.is_empty():
		return "No more golem cores lie anywhere on the map."
	return "Cores lie in: " + ", ".join(places) + ". Clear it to bring one back."
