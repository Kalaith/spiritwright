extends Control
## Owns the catalog and the persistent progression and swaps between screens:
## title, region map, golem laboratory, battle playback and results, the
## Codex and the Shifting Crucible. Also owns the player's settings, the
## settings page over any screen, and the background sound of each place.

const Catalog = preload("res://scripts/core/catalog.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const Style = preload("res://scripts/ui/style.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const CampaignScreen = preload("res://scripts/ui/campaign_screen.gd")
const LaboratoryScreen = preload("res://scripts/ui/laboratory_screen.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const ResultScreen = preload("res://scripts/ui/result_screen.gd")
const CodexScreen = preload("res://scripts/ui/codex_screen.gd")
const CrucibleScreen = preload("res://scripts/ui/crucible_screen.gd")
const Crucible = preload("res://scripts/core/crucible.gd")
const ScreenSwitcher = preload("res://addons/hatchery/ui/screen_switcher.gd")
const GameSettings = preload("res://scripts/ui/game_settings.gd")
const Ambience = preload("res://addons/hatchery/audio/ambience.gd")
const AmbienceBeds = preload("res://scripts/ui/ambience_beds.gd")

var catalog := Catalog.new()
var progression: Progression
## Swaps whole screens and remembers where Back (Esc or gamepad B) goes from each.
var screens: ScreenSwitcher = ScreenSwitcher.new(self) as ScreenSwitcher
## The screen on show.
var screen: Control:
	get:
		return screens.current as Control
var selected_stage: String = ""
var settings: GameSettings
var ambience: Ambience
## The settings page while it is open over the current screen.
var settings_page: Control
## What had focus when the settings page opened, to return to on close.
var _focus_before: Control


func _ready() -> void:
	screens.auto_focus = false
	theme = Style.make_theme()
	settings = GameSettings.new(get_tree())
	settings.load_and_apply()
	ambience = Ambience.new()
	ambience.bus = StringName(GameSettings.AMBIENCE_BUS)
	add_child(ambience)
	if not catalog.load_all():
		var error := Style.wrapped("Spiritwright could not load its data:\n" + "\n".join(catalog.errors), 16, Style.BAD)
		error.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(error)
		return
	progression = Progression.new(catalog)
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	screens.handle_back(event)


## Shows `next` with its Back target, and the background sound of `bed`
## (a battle scene or "workshop"; see ambience_beds.gd).
func _swap(next: Control, back: Callable, bed: String = "workshop") -> void:
	close_settings()
	screens.show(next, back)
	if next.has_signal("settings_requested"):
		next.connect("settings_requested", open_settings)
	ambience.play_bed(bed, AmbienceBeds.layers(bed))


func open_settings() -> void:
	if is_instance_valid(settings_page):
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	settings_page = settings.make_page()
	settings_page.close_requested.connect(close_settings)
	settings_page.applied.connect(_on_setting_applied)
	add_child(settings_page)
	settings_page.close_button.grab_focus.call_deferred()


func close_settings() -> void:
	if not is_instance_valid(settings_page):
		return
	settings_page.queue_free()
	settings_page = null
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus.call_deferred()


func _on_setting_applied(key: String) -> void:
	if key == "screen_shake" and screen is BattleView:
		screen.shake.enabled = settings.shake_enabled


func show_title(notice: String = "") -> void:
	var title := TitleScreen.new()
	title.has_save = progression.has_save()
	title.notice = notice
	title.continue_requested.connect(_continue)
	title.new_game_requested.connect(_new_game)
	_swap(title, Callable(), "ruins")


func _continue() -> void:
	if progression.load_game():
		show_map(progression.last_error)
	else:
		show_title(progression.last_error + " Start a new game to continue playing.")


func _new_game() -> void:
	# The old laboratory is kept beside the save as .previous before it is replaced.
	if not progression.storage.keep_previous():
		show_title(progression.storage.last_error)
		return
	progression.new_game()
	selected_stage = ""
	if not progression.save_game():
		push_warning(progression.last_error)
	show_map()


func show_map(_notice: String = "") -> void:
	var map := CampaignScreen.new()
	map.catalog = catalog
	map.progression = progression
	map.selected = selected_stage
	map.laboratory_requested.connect(func(): _laboratory_from(map))
	map.fight_requested.connect(start_battle)
	map.title_requested.connect(show_title)
	map.new_game_plus_requested.connect(_new_game_plus)
	map.codex_requested.connect(func(): _codex_from(map))
	map.crucible_requested.connect(func():
		selected_stage = map.selected
		show_crucible())
	_swap(map, show_title)


func _codex_from(map: Control) -> void:
	selected_stage = map.selected
	show_codex()


func show_codex() -> void:
	var codex := CodexScreen.new()
	codex.catalog = catalog
	codex.progression = progression
	codex.map_requested.connect(show_map)
	codex.stage_requested.connect(func(stage_id: String):
		selected_stage = stage_id
		show_map())
	_swap(codex, show_map)


func _new_game_plus() -> void:
	if not progression.start_new_game_plus():
		return
	selected_stage = ""
	if not progression.save_game():
		push_warning(progression.last_error)
	show_map()


func _laboratory_from(map: Control) -> void:
	selected_stage = map.selected
	show_laboratory()


func show_laboratory(from_crucible: bool = false) -> void:
	var laboratory := LaboratoryScreen.new()
	laboratory.catalog = catalog
	laboratory.progression = progression
	var back: Callable = show_crucible if from_crucible else show_map
	if from_crucible:
		laboratory.back_text = "Crucible"
	else:
		laboratory.stage_id = selected_stage
	laboratory.map_requested.connect(back)
	laboratory.fight_requested.connect(start_battle)
	_swap(laboratory, back)


func show_crucible() -> void:
	if not progression.crucible_open():
		show_map()
		return
	var crucible := CrucibleScreen.new()
	crucible.catalog = catalog
	crucible.progression = progression
	crucible.fight_requested.connect(start_crucible_battle)
	crucible.laboratory_requested.connect(func(): show_laboratory(true))
	crucible.map_requested.connect(show_map)
	_swap(crucible, show_map, "crucible")


## Fights the Crucible run's next encounter: the locked team and every enemy
## at the tier's level, with the step's own seed.
func start_crucible_battle() -> void:
	var run: Dictionary = progression.crucible.run
	if run.is_empty():
		return
	var index: int = int(run.next)
	var entry: Dictionary = catalog.crucible_encounters[run.sequence[index].encounter]
	var outcome: Dictionary = BattleSim.new().run(catalog, Crucible.player_team(catalog, run),
		Crucible.enemy_team(catalog, run.sequence[index], run.tier), Crucible.battle_seed(catalog, run, index))
	var view := BattleView.new()
	view.catalog = catalog
	view.stage = {"id": entry.id, "name": "%s (%d of %d)" % [entry.name, index + 1, run.sequence.size()]}
	view.scene = "crucible"
	view.outcome = outcome
	view.shake.enabled = settings.shake_enabled
	view.finished.connect(func(): _show_crucible_result(view.stage, outcome))
	_swap(view, func(): _show_crucible_result(view.stage, outcome), "crucible")


func _show_crucible_result(stage: Dictionary, outcome: Dictionary) -> void:
	var result := ResultScreen.new()
	result.catalog = catalog
	result.stage = stage
	result.outcome = outcome
	result.report = progression.apply_crucible(outcome.result)
	result.crucible = true
	result.scene = "crucible"
	result.back_text = "Crucible"
	var run: Dictionary = progression.crucible.run
	if not run.is_empty():
		result.next_name = catalog.crucible_encounters[run.sequence[int(run.next)].encounter].name
	if not progression.save_game():
		result.save_error = progression.last_error
	result.map_requested.connect(show_crucible)
	result.laboratory_requested.connect(func(): show_laboratory(true))
	result.next_requested.connect(start_crucible_battle)
	_swap(result, show_crucible, "crucible")


func start_battle(stage_id: String) -> void:
	if progression.stage_state(stage_id) == "locked":
		return
	selected_stage = stage_id
	var stage: Dictionary = catalog.stages[stage_id]
	var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), int(stage.seed))
	var view := BattleView.new()
	view.catalog = catalog
	view.stage = stage
	view.scene = catalog.region_of(stage_id).id
	view.outcome = outcome
	view.shake.enabled = settings.shake_enabled
	view.finished.connect(func(): _show_result(stage, outcome))
	_swap(view, func(): _show_result(stage, outcome), view.scene)


func _show_result(stage: Dictionary, outcome: Dictionary) -> void:
	var report: Dictionary = progression.apply_battle(stage, outcome.result, outcome.units)
	var result := ResultScreen.new()
	result.catalog = catalog
	result.stage = stage
	result.outcome = outcome
	result.report = report
	result.progression_challenges = progression.challenges
	result.scene = catalog.region_of(stage.id).id
	if not progression.save_game():
		result.save_error = progression.last_error
	result.map_requested.connect(show_map)
	result.laboratory_requested.connect(show_laboratory)
	result.retry_requested.connect(func(): start_battle(stage.id))
	_swap(result, show_map, result.scene)
