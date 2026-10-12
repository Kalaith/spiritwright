extends SceneTree
## Drives the real game through every screen and saves a PNG of each, using a
## throwaway save file. Needs a rendering window (not --headless):
##   godot --path . --script res://tools/capture.gd -- <output dir>

var main: Control
var out_dir: String = "user://captures"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.progression.save_path = "user://capture_save.json"
	await _frames(10)
	await _shot("01_title")
	main._new_game()
	await _frames(10)
	await _shot("02_map")
	main.selected_stage = "ruins_gate"
	main.show_laboratory()
	await _frames(10)
	await _shot("03_laboratory")
	main.start_battle("ruins_gate")
	for i in range(4):
		await _seconds(1.6)
		await _shot("04_battle_%d" % i)
	main.screen._skip()
	await _frames(5)
	await _shot("05_battle_end")
	main.screen.finished.emit()
	await _frames(10)
	await _shot("06_result")
	# The gate's golem core waits in the laboratory.
	main.selected_stage = "ruins_court"
	main.show_map()
	await _seconds(1.0)
	await _shot("06b_map_core_ready")
	main.show_laboratory()
	await _frames(10)
	await _shot("06c_laboratory_core_ready")
	main.screen._on_build()
	await _frames(10)
	await _shot("06d_laboratory_built")
	# A later stage with more systems on screen.
	for id in ["ruins_court", "ruins_stair", "ruins_vault"]:
		main.progression.apply_battle(main.catalog.stages[id], "win")
	while main.progression.build_golem():
		pass
	main.selected_stage = "ruins_heart"
	main.show_map()
	await _seconds(2.5)
	await _shot("07_map_late")
	main.show_laboratory()
	await _frames(10)
	await _shot("08_laboratory_late")
	main.start_battle("ruins_heart")
	await _seconds(6.0)
	await _shot("09_boss_battle")
	# The newer spirits, one win away from awakening.
	main.progression.apply_battle(main.catalog.stages["ruins_cloister"], "win")
	main.progression.apply_battle(main.catalog.stages["ruins_vault"], "win")
	var builds: Array = [["briar", "bulwark", "shield", "pillar", "front", "wood"],
		["sefa", "conduit", "cannon", "pillar", "back", "crystal"], ["volta", "conduit", "cannon", "spider", "back", "bronze"]]
	for slot in range(builds.size()):
		var build: Array = builds[slot]
		main.progression.team[slot] = {"spirit": build[0], "frame": build[1], "arms": build[2],
			"legs": build[3], "material": build[5], "sigil": "", "row": build[4]}
		main.progression.spirits[build[0]].level = 4
		main.progression.spirits[build[0]].xp = 90
	main.start_battle("ruins_stair")
	await _seconds(7.0)
	await _shot("10_spirits_battle")
	main.screen._skip()
	main.screen.finished.emit()
	await _frames(10)
	await _shot("11_spirits_result")
	main.show_laboratory()
	await _frames(10)
	await _shot("12_laboratory_materials")
	# Every later region, partway through: two stages cleared, the rest open or fogged.
	var regions: Array = main.catalog.regions()
	for index in range(1, regions.size()):
		for stage in regions[index - 1].stages:
			if not stage.id in main.progression.cleared:
				main.progression.cleared.append(stage.id)
		for stage in regions[index].stages.slice(0, 2):
			main.progression.cleared.append(stage.id)
		main.selected_stage = regions[index].stages[2].id
		main.show_map()
		await _seconds(2.0)
		await _shot("14_region_%d_%s" % [index + 1, regions[index].id])
	main.start_battle(regions[1].stages[2].id)
	await _seconds(6.0)
	await _shot("15_fen_battle")
	await _gallery()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(main.progression.save_path + suffix)
	quit()


## Every material in every frame, then every element reaction, side by side.
func _gallery() -> void:
	var GolemArt: GDScript = load("res://scripts/ui/golem_art.gd")
	var GolemPreview: GDScript = load("res://scripts/ui/golem_preview.gd")
	var catalog: RefCounted = main.catalog
	var sheet := ColorRect.new()
	sheet.color = Color("16151f")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(10, 10)
	sheet.add_child(grid)
	var looks: Array = []
	var builds: Array = [["bulwark", "shield", "pillar"], ["strider", "hammer", "spider"], ["conduit", "cannon", "pillar"]]
	for id in catalog.part_order.materials:
		var reactions: Dictionary = catalog.part("materials", id).reactions
		var plain: String = catalog.player_spirit_ids.filter(func(s): return not reactions.has(catalog.spirit(s).element))[0]
		for build in builds:
			looks.append([plain, id, build])
	for id in catalog.part_order.materials:
		var reactions: Dictionary = catalog.part("materials", id).reactions
		for element in reactions:
			var spirit: String = catalog.player_spirit_ids.filter(func(s): return catalog.spirit(s).element == element)[0]
			looks.append([spirit, id, builds[looks.size() % 3]])
	for entry in looks:
		var golem: Dictionary = {"spirit": entry[0], "material": entry[1], "frame": entry[2][0], "arms": entry[2][1], "legs": entry[2][2]}
		var cell := VBoxContainer.new()
		var preview: Control = GolemPreview.new()
		preview.custom_minimum_size = Vector2(208, 150)
		preview.animated = true
		preview.setup(GolemArt.look_for(catalog, golem, Color("4cc9c0")), 1.05)
		cell.add_child(preview)
		var reaction: Dictionary = catalog.reaction(entry[1], catalog.spirit(entry[0]).element)
		var caption := Label.new()
		caption.text = "%s %s" % [catalog.part("materials", entry[1]).name, reaction.get("name", "")]
		caption.add_theme_font_size_override("font_size", 12)
		cell.add_child(caption)
		grid.add_child(cell)
	await _seconds(0.7)
	await _shot("13_material_gallery")
	sheet.queue_free()


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	print("captured ", name)
