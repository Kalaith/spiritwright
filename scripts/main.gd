extends Control
## Owns the catalog and the persistent progression and swaps between screens:
## title, region map, golem laboratory, battle playback and results.

const Catalog = preload("res://scripts/core/catalog.gd")
const Progression = preload("res://scripts/core/progression.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const Style = preload("res://scripts/ui/style.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const CampaignScreen = preload("res://scripts/ui/campaign_screen.gd")
const LaboratoryScreen = preload("res://scripts/ui/laboratory_screen.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const ResultScreen = preload("res://scripts/ui/result_screen.gd")

var catalog := Catalog.new()
var progression: Progression
var screen: Control
var selected_stage: String = ""
var _back: Callable = Callable()


func _ready() -> void:
	theme = Style.make_theme()
	if not catalog.load_all():
		var error := Style.wrapped("Spiritwright could not load its data:\n" + "\n".join(catalog.errors), 16, Style.BAD)
		error.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(error)
		return
	progression = Progression.new(catalog)
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _back.is_valid():
		get_viewport().set_input_as_handled()
		_back.call()


func _swap(next: Control, back: Callable) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	screen = next
	_back = back
	add_child(next)


func show_title(notice: String = "") -> void:
	var title := TitleScreen.new()
	title.has_save = progression.has_save()
	title.notice = notice
	title.continue_requested.connect(_continue)
	title.new_game_requested.connect(_new_game)
	_swap(title, Callable())


func _continue() -> void:
	if progression.load_game():
		show_map(progression.last_error)
	else:
		show_title(progression.last_error + " Start a new game to continue playing.")


func _new_game() -> void:
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
	_swap(map, show_title)


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


func show_laboratory() -> void:
	var laboratory := LaboratoryScreen.new()
	laboratory.catalog = catalog
	laboratory.progression = progression
	laboratory.stage_id = selected_stage
	laboratory.map_requested.connect(show_map)
	laboratory.fight_requested.connect(start_battle)
	_swap(laboratory, show_map)


func start_battle(stage_id: String) -> void:
	if progression.stage_state(stage_id) == "locked":
		return
	selected_stage = stage_id
	var stage: Dictionary = catalog.stages[stage_id]
	var outcome: Dictionary = BattleSim.new().run(catalog, progression.resolved_team(), progression.enemy_team(stage), int(stage.seed))
	var view := BattleView.new()
	view.catalog = catalog
	view.stage = stage
	view.outcome = outcome
	view.finished.connect(func(): _show_result(stage, outcome))
	_swap(view, func(): _show_result(stage, outcome))


func _show_result(stage: Dictionary, outcome: Dictionary) -> void:
	var report: Dictionary = progression.apply_battle(stage, outcome.result, outcome.units)
	var result := ResultScreen.new()
	result.catalog = catalog
	result.stage = stage
	result.outcome = outcome
	result.report = report
	if not progression.save_game():
		result.save_error = progression.last_error
	result.map_requested.connect(show_map)
	result.laboratory_requested.connect(show_laboratory)
	result.retry_requested.connect(func(): start_battle(stage.id))
	_swap(result, show_map)
