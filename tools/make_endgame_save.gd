extends SceneTree
## Writes an end-game save for testing: every stage of the first playthrough
## won in campaign order through the real progression rules (XP, rewards,
## cores and golems as they come), so the Storm Crown has fallen, New Game+
## and the Crucible are open, and a six-golem team stands ready. The existing
## save, if any, is kept once as spiritwright_save.before_endgame.json (never
## overwritten by a later run). Run with the
## same project so it lands in the same user:// folder Run.ps1 uses:
##   godot --headless --path . --script res://tools/make_endgame_save.gd

const Catalog = preload("res://scripts/core/catalog.gd")
const Progression = preload("res://scripts/core/progression.gd")


func _init() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		push_error(", ".join(catalog.errors))
		quit(1)
		return
	var progression := Progression.new(catalog)
	var backup_path: String = progression.save_path.get_basename() + ".before_endgame.json"
	if FileAccess.file_exists(progression.save_path) and not FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(progression.save_path, backup_path)
		print("Kept the old save as ", ProjectSettings.globalize_path(backup_path))
	progression.new_game()
	for stage in catalog.stages.values():
		progression.apply_battle(stage, "win")
		while progression.build_golem():
			pass
	var team: Array = [["odo", "bulwark", "aegis", "tower", "stone", "stoneskin", "front:1"],
		["briar", "bulwark", "shield", "tower", "wood", "thorn_crest", "front:0"],
		["pyra", "strider", "spear", "pillar", "obsidian", "ember_sigil", "front:2"],
		["volta", "conduit", "storm_staff", "stilts", "fulgurite", "storm_coil", "back:1"],
		["neris", "conduit", "lantern", "pillar", "ice", "mending", "back:0"],
		["sefa", "conduit", "cannon", "stilts", "crystal", "hex_eye", "back:2"]]
	for slot in range(team.size()):
		var build: Array = team[slot]
		for pair in [["spirit", build[0]], ["frame", build[1]], ["arms", build[2]], ["legs", build[3]],
				["material", build[4]], ["sigil", build[5]], ["cell", build[6]]]:
			# Fall back to no sigil if this save has not unlocked one.
			if not progression.set_slot(slot, pair[0], pair[1]) and pair[0] == "sigil":
				progression.set_slot(slot, "sigil", "")
	if not progression.save_game():
		push_error(progression.last_error)
		quit(1)
		return
	var levels: Array = progression.team.map(func(l): return "%s Lv %d" % [l.spirit, progression.spirits[l.spirit].level])
	print("End-game save written to ", ProjectSettings.globalize_path(progression.save_path))
	print("Crucible open: ", progression.crucible_open(), ". Spirits: ", progression.spirits.size(), ". Team: ", ", ".join(levels))
	quit()
