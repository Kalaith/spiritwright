extends "res://tools/checks/check_module.gd"
## The player's settings and the background sound: preferences round-trip and
## tolerate older files, the interface size maps onto its range, and every
## place a screen can show has an ambience bed.

const GameSettings = preload("res://scripts/ui/game_settings.gd")
const AmbienceBeds = preload("res://scripts/ui/ambience_beds.gd")
const Backdrop = preload("res://scripts/ui/battle_backdrop.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func check_settings_round_trip():
	var path: String = Expect.scratch_path("settings_check.json")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var settings := GameSettings.new(tree, path)
	settings.load_and_apply()
	for key in GameSettings.DEFAULTS:
		_check("default %s is accepted" % key, settings.store.accepts_value(key, GameSettings.DEFAULTS[key]))
	_check("the default interface size is 100%", is_equal_approx(settings.ui_scale(), 1.0))
	_check("shake starts on", settings.shake_enabled)
	settings.store.set_value("ui_scale", 1.0)
	settings.store.set_value("screen_shake", false)
	settings.store.set_value("ambience", 0.25)
	_check("settings save", settings.store.save_settings(), settings.store.last_error)
	var again := GameSettings.new(tree, path)
	again.load_and_apply()
	_check("the largest size is 125%", is_equal_approx(again.ui_scale(), GameSettings.SCALE_MAX))
	_check("shake stays off", not again.shake_enabled)
	_check("background volume persists", is_equal_approx(float(again.store.values.ambience), 0.25))
	# An older file without the newer keys keeps its values and defaults the rest.
	var older := FileAccess.open(path, FileAccess.WRITE)
	older.store_string(JSON.stringify({"schema": 1, "values": {"master": 0.3}}))
	older.close()
	var old := GameSettings.new(tree, path)
	old.load_and_apply()
	_check("an older file loads", is_equal_approx(float(old.store.values.master), 0.3) and old.shake_enabled)
	_check("the page offers every setting", _page_keys() == GameSettings.DEFAULTS.keys().size())
	settings.store.set_value("ui_scale", GameSettings.DEFAULTS.ui_scale)
	settings.apply("ui_scale")
	return verdict()


func check_every_place_has_a_bed():
	var places: Array = Backdrop.SCENES.keys()
	places.append("workshop")
	for place in places:
		var layers: Array = AmbienceBeds.layers(place)
		_check("%s has a bed" % place, AmbienceBeds.BEDS.has(place) and not layers.is_empty())
		for layer in layers:
			var stream: AudioStreamWAV = layer.stream
			_check("%s layers loop" % place, stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
			_check("%s layers sit under the mix" % place, float(layer.db) < -10.0)
	_check("a bed is made once", AmbienceBeds.layers("ruins") == AmbienceBeds.layers("ruins"))
	_check("an unknown place falls back to the workshop", AmbienceBeds.layers("nowhere") == AmbienceBeds.layers("workshop"))
	return verdict()


func _page_keys() -> int:
	var count: int = 0
	for section in GameSettings.SECTIONS:
		count += section.get("sliders", []).size() + section.get("toggles", []).size()
	return count
