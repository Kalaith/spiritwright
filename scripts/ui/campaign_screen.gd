extends Control
## Region map plus the selected stage's scouting report: enemy builds, traits
## and first-clear rewards, so the player can plan a counter in the workshop.

signal workshop_requested
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
var _details: VBoxContainer


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
	var region: Dictionary = catalog.region()
	var bar := Style.hbox(12)
	column.add_child(bar)
	bar.add_child(Style.label(region.name, 26, Style.GOLD))
	var blurb := Style.wrapped(region.text, 14)
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blurb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(blurb)
	bar.add_child(Style.button("Workshop", func(): workshop_requested.emit()))
	bar.add_child(Style.button("Title", func(): title_requested.emit()))
	var body := Style.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_map = CampaignMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.stages = region.stages
	for stage in region.stages:
		_map.states[stage.id] = progression.stage_state(stage.id)
	_map.stage_selected.connect(_select)
	body.add_child(_map)
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
		selected = _first_open(region)
	_select(selected)


func _first_open(region: Dictionary) -> String:
	for stage in region.stages:
		if progression.stage_state(stage.id) == "open":
			return stage.id
	return region.stages[-1].id


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
	if state == "cleared":
		_details.add_child(Style.wrapped("Replay for %d XP per spirit." % int(catalog.num("xp.repeat_win")), 14))
	elif stage.get("rewards", {}).is_empty():
		_details.add_child(Style.wrapped("Defeat the Warden to free the Ancient Ruins.", 14, Style.GOLD))
	else:
		_details.add_child(Style.label("First-clear rewards", 17, Style.MUTED))
		for kind in stage.rewards:
			for id in stage.rewards[kind]:
				var lines: Array = Style.reward_text(catalog, kind, id)
				_details.add_child(Style.wrapped(lines[0], 15, Style.GOLD))
				_details.add_child(Style.wrapped(lines[1], 13))
	var buttons := Style.hbox(10)
	buttons.add_child(Style.button("Workshop", func(): workshop_requested.emit()))
	var fight := Style.button("Fight!", func(): fight_requested.emit(selected), 20)
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fight)
	_details.add_child(buttons)
	_details.add_child(Style.wrapped(_team_line(), 13))


func _enemy_row(golem: Dictionary) -> Control:
	var row := Style.hbox(8)
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(84, 92)
	preview.setup(GolemArt.look_for(catalog, golem, Style.ENEMY), 0.62, -1.0)
	row.add_child(preview)
	var info := Style.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(Style.label("%s  Lv %d  %s" % [golem.name, golem.level, catalog.element_label(golem.element)], 15, Style.TEXT))
	var build: String = "%s / %s / %s, %s row" % [
		catalog.part("frames", golem.frame).name.trim_suffix(" Frame"),
		catalog.part("arms", golem.arms).name, catalog.part("legs", golem.legs).name, golem.row]
	info.add_child(Style.wrapped(build, 13))
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
	return "Your team: " + ", ".join(names)
