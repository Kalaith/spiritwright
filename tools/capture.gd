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
	main.show_workshop()
	await _frames(10)
	await _shot("03_workshop")
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
	# A later stage with more systems on screen.
	for id in ["ruins_court", "ruins_stair", "ruins_vault"]:
		main.progression.apply_battle(main.catalog.stages[id], "win")
	main.selected_stage = "ruins_heart"
	main.show_map()
	await _frames(10)
	await _shot("07_map_late")
	main.show_workshop()
	await _frames(10)
	await _shot("08_workshop_late")
	main.start_battle("ruins_heart")
	await _seconds(6.0)
	await _shot("09_boss_battle")
	# The newer spirits, one win away from awakening.
	main.progression.apply_battle(main.catalog.stages["ruins_cloister"], "win")
	var builds: Array = [["briar", "bulwark", "shield", "pillar", "front"],
		["sefa", "conduit", "cannon", "pillar", "back"], ["volta", "conduit", "cannon", "spider", "back"]]
	for slot in range(builds.size()):
		var build: Array = builds[slot]
		main.progression.team[slot] = {"spirit": build[0], "frame": build[1], "arms": build[2],
			"legs": build[3], "sigil": "", "row": build[4]}
		main.progression.spirits[build[0]].level = 4
		main.progression.spirits[build[0]].xp = 90
	main.start_battle("ruins_stair")
	await _seconds(7.0)
	await _shot("10_spirits_battle")
	main.screen._skip()
	main.screen.finished.emit()
	await _frames(10)
	await _shot("11_spirits_result")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(main.progression.save_path + suffix)
	quit()


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
