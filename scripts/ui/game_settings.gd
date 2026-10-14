extends RefCounted
## The player's preferences (sound, window, UI size, screen shake) kept in
## user://settings.json, apart from the laboratory's save, and pushed to the
## engine whenever one changes. Opens the toolkit's settings page over any
## screen.

const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const SettingsPanel = preload("res://addons/hatchery/ui/settings_panel.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")
const Levels = preload("res://addons/hatchery/audio/levels.gd")
const UiKit = preload("res://addons/hatchery/ui/ui_kit.gd")

const AMBIENCE_BUS: String = "Ambience"
## The UI size slider runs from 75 % to 125 %; its middle is 100 %.
const SCALE_MIN: float = 0.75
const SCALE_MAX: float = 1.25
const DEFAULTS: Dictionary = {
	"master": 0.8, "ambience": 0.7, "muted": false,
	"fullscreen": false, "ui_scale": 0.5, "screen_shake": true,
}
const SECTIONS: Array = [
	{"title": "Sound", "sliders": ["master", "ambience"], "toggles": ["muted"]},
	{"title": "Display", "sliders": ["ui_scale"], "toggles": ["fullscreen", "screen_shake"]},
]
const WORDS: Dictionary = {
	"setting_master": "Master volume", "setting_ambience": "Background sound", "setting_muted": "Mute all sound",
	"setting_fullscreen": "Full screen", "setting_ui_scale": "Interface size", "setting_screen_shake": "Screen shake",
}

var store: SettingsStore
var tree: SceneTree
var shake_enabled: bool:
	get:
		return bool(store.values.screen_shake)


func _init(scene_tree: SceneTree, path: String = "user://settings.json") -> void:
	tree = scene_tree
	store = SettingsStore.new(DEFAULTS, path)
	Levels.ensure_bus(AMBIENCE_BUS)


func load_and_apply() -> void:
	store.load_settings()
	apply_all()


func apply_all() -> void:
	for key in DEFAULTS:
		apply(key)


## Pushes one changed value to the engine ("" applies everything).
func apply(key: String) -> void:
	match key:
		"":
			apply_all()
		"master", "ambience", "muted":
			Levels.apply_buses(store.values, {"Master": "master", AMBIENCE_BUS: "ambience"}, "muted")
		"fullscreen":
			Display.set_fullscreen(bool(store.values.fullscreen))
		"ui_scale":
			Display.set_ui_scale(tree, ui_scale())


func ui_scale() -> float:
	return Display.scale_from_fraction(float(store.values.ui_scale), SCALE_MIN, SCALE_MAX)


## The settings page, ready to add over the current screen. A browser can
## leave full screen on its own (Esc), so the toggle starts from the window.
func make_page() -> Control:
	if not Display.is_headless():
		store.values.fullscreen = Display.is_fullscreen()
	var page := SettingsPanel.new()
	page.store = store
	page.ui = UiKit.new()
	page.sections = SECTIONS
	page.panel_size = Vector2(680, 600)
	page.commit_on_release = ["ui_scale"]
	page.text = func(word: String, english: String) -> String: return WORDS.get(word, english)
	page.slider_text = func(word: String, value: float) -> String:
		if word == "ui_scale":
			return "%d%%" % roundi(Display.scale_from_fraction(value, SCALE_MIN, SCALE_MAX) * 100.0)
		return "%d%%" % roundi(value * 100.0)
	page.applied.connect(apply)
	return page
