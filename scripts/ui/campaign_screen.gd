extends Control
## Region map (one region at a time, stepped with < and >) plus the selected
## stage's scouting report: enemy builds, traits
## and first-clear rewards, so the player can plan a counter in the laboratory.

signal laboratory_requested
signal fight_requested(stage_id: String)
signal title_requested

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")
const CampaignMap = preload("res://scripts/ui/campaign_map.gd")

var catalog: RefCounted
var progression: RefCounted
var selected: String = ""
var _map: Control
var _map_holder: HBoxContainer
var _details: VBoxContainer
var _region_index: int = 0
var _region_name: Label
var _region_text: Label
var _region_count: Label
var _prev: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Style.backdrop(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := Style.vbox(10)
	margin.add_child(column)
	var bar := Style.hbox(12)
	column.add_child(bar)
	_prev = Style.button("<", func(): _step_region(-1))
	bar.add_child(_prev)
	var titles := Style.vbox(0)
	bar.add_child(titles)
	_region_name = Style.label("", 26, Style.GOLD)
	titles.add_child(_region_name)
	_region_count = Style.label("", 13, Style.MUTED)
	titles.add_child(_region_count)
	_next = Style.button(">", func(): _step_region(1))
	bar.add_child(_next)
	_region_text = Style.wrapped("", 14)
	_region_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_region_text)
	bar.add_child(_lab_button())
	bar.add_child(Style.button("Title", func(): title_requested.emit()))
	var body := Style.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_map_holder = Style.hbox(0)
	_map_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_map_holder)
	var side := Style.panel(14)
	side.custom_minimum_size.x = 410
	body.add_child(side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_details = Style.vbox(8)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_details)
	if selected.is_empty() or progression.stage_state(selected) == "locked":
		selected = _furthest_open(catalog.stages.keys())
	_show_region(int(catalog.stage_region[selected]))
	_select(selected)


## The last open stage of `ids` in campaign order, else the last one not locked,
## else the first: the place the player most likely wants to go next.
func _furthest_open(ids: Array) -> String:
	var open: String = ""
	var reached: String = ""
	for id in ids:
		var state: String = progression.stage_state(id)
		if state == "open":
			open = id
		elif state == "cleared":
			reached = id
	if not open.is_empty():
		return open
	return reached if not reached.is_empty() else ids[0]


## A region can be visited once any of its stages is open or cleared.
func _region_reached(index: int) -> bool:
	return catalog.regions()[index].stages.any(func(stage): return progression.stage_state(stage.id) != "locked")


func _step_region(step: int) -> void:
	var index: int = _region_index + step
	if index < 0 or index >= catalog.regions().size() or not _region_reached(index):
		return
	_show_region(index)
	_select(_furthest_open(catalog.regions()[index].stages.map(func(stage): return stage.id)))


func _show_region(index: int) -> void:
	_region_index = index
	var region: Dictionary = catalog.regions()[index]
	_region_name.text = region.name
	_region_text.text = region.text
	_region_count.text = "Region %d of %d" % [index + 1, catalog.regions().size()]
	_prev.disabled = index == 0
	_next.disabled = index + 1 >= catalog.regions().size() or not _region_reached(index + 1)
	if _map != null:
		_map.queue_free()
	_map = CampaignMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.stages = region.stages
	_map.laboratory = region.laboratory
	_map.terrain = region.terrain
	_map.golem_slots = int(catalog.num("team_size"))
	_map.core_ready = progression.can_build()
	for slot in range(progression.team.size()):
		_map.party_looks.append(GolemArt.look_for(catalog, progression.team[slot], Style.ALLY))
	for stage in region.stages:
		_map.states[stage.id] = progression.stage_state(stage.id)
	_map.stage_selected.connect(_select)
	_map.laboratory_selected.connect(func(): laboratory_requested.emit())
	_map_holder.add_child(_map)


func _select(stage_id: String) -> void:
	selected = stage_id
	_map.selected = stage_id
	for child in _details.get_children():
		child.queue_free()
	var stage: Dictionary = catalog.stages[stage_id]
	var state: String = progression.stage_state(stage_id)
	var heading := Style.hbox(8)
	heading.add_child(Style.label(stage.name, 24, Style.GOLD))
	if stage.get("boss", false):
		heading.add_child(Style.label("BOSS", 14, Style.BAD))
	if state == "cleared":
		heading.add_child(Style.label("CLEARED", 14, Style.GOOD))
	_details.add_child(heading)
	_details.add_child(Style.wrapped(stage.text, 15, Style.TEXT))
	_details.add_child(Style.label("Enemy team", 17, Style.MUTED))
	for golem in progression.enemy_team(stage):
		_details.add_child(_enemy_row(golem))
	var level: int = progression.stage_level(stage)
	var xp_factor: float = catalog.num("xp.repeat_win" if state == "cleared" else "xp.first_clear")
	_details.add_child(Style.wrapped("%s %d XP per Lv %d spirit; lower-level spirits earn more, higher-level less." % [
		"Replay for" if state == "cleared" else "Win for", progression.stage_xp(stage, level, xp_factor), level], 14))
	if state != "cleared" and stage.get("rewards", {}).is_empty():
		_details.add_child(Style.wrapped("No parts or spirits wait here: this fight is for experience.", 14))
	elif state != "cleared":
		_details.add_child(Style.label("First-clear rewards", 17, Style.MUTED))
		for kind in stage.rewards:
			for id in ([str(stage.rewards[kind])] if kind == "cores" else stage.rewards[kind]):
				var lines: Array = Style.reward_text(catalog, kind, id)
				_details.add_child(Style.wrapped(lines[0], 15, Style.GOLD))
				_details.add_child(Style.wrapped(lines[1], 13))
	var buttons := Style.hbox(10)
	buttons.add_child(_lab_button())
	var fight := Style.button("Fight!", func(): fight_requested.emit(selected), 20)
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fight)
	_details.add_child(buttons)
	_details.add_child(Style.wrapped(_team_line(), 13))
	if progression.can_build():
		_details.add_child(Style.wrapped("A golem core waits in the laboratory: build another golem before you set out.", 13, Style.GOLD))


func _enemy_row(golem: Dictionary) -> Control:
	var row := Style.hbox(8)
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(84, 92)
	preview.animated = true
	preview.setup(GolemArt.look_for(catalog, golem, Style.ENEMY), 0.62, -1.0)
	row.add_child(preview)
	var info := Style.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(Style.label("%s  Lv %d  %s" % [golem.name, golem.level, catalog.element_label(golem.element)], 15, Style.TEXT))
	var build: String = "%s %s / %s / %s. %s" % [catalog.part("materials", golem.material).name,
		catalog.part("frames", golem.frame).name.trim_suffix(" Frame"),
		catalog.part("arms", golem.arms).name, catalog.part("legs", golem.legs).name, Style.cell_name(golem.row, golem.lane)]
	info.add_child(Style.wrapped(build, 13))
	if not golem.reaction.is_empty():
		info.add_child(Style.wrapped("%s: %s" % [golem.reaction.name, golem.reaction.text], 12, catalog.element_color(golem.element)))
	var trait_def: Dictionary = catalog.spirit(golem.spirit)["trait"]
	info.add_child(Style.wrapped("%s: %s" % [trait_def.name, trait_def.text], 12))
	if not String(golem.sigil).is_empty():
		var sigil: Dictionary = catalog.part("sigils", golem.sigil)
		info.add_child(Style.wrapped("%s: %s" % [sigil.name, sigil.text], 12, Style.GOLD.darkened(0.15)))
	return row


func _team_line() -> String:
	var names: Array[String] = []
	for loadout in progression.team:
		var spirit: Dictionary = catalog.spirit(loadout.spirit)
		names.append("%s Lv %d" % [spirit.name, progression.spirits[loadout.spirit].level])
	return "Your golems (%d of %d built): %s" % [progression.team.size(), int(catalog.num("team_size")), ", ".join(names)]


func _lab_button() -> Button:
	var text: String = "Laboratory (core ready!)" if progression.can_build() else "Laboratory"
	return Style.button(text, func(): laboratory_requested.emit())
