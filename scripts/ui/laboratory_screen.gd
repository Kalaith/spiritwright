extends Control
## The golem laboratory: a card for every golem built so far, an empty cradle
## for each one still to come (built by spending a golem core) and the spirit
## roster. Every change goes through Progression (which validates it) and is
## saved immediately.

signal map_requested
signal fight_requested(stage_id: String)

const Style = preload("res://scripts/ui/style.gd")
const SlotCard = preload("res://scripts/ui/slot_card.gd")
const CradleCard = preload("res://scripts/ui/cradle_card.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

var catalog: RefCounted
var progression: RefCounted
var stage_id: String = ""
var _cards: HBoxContainer
var _roster: VBoxContainer
var _status: Label


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
	bar.add_child(Style.label("Golem Laboratory", 26, Style.GOLD))
	_status = Style.wrapped("Hover a stat to see where it comes from. Changes save automatically.", 14)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)
	bar.add_child(Style.button("Map", func(): map_requested.emit()))
	if not stage_id.is_empty():
		bar.add_child(Style.button("Fight: " + catalog.stages[stage_id].name, func(): fight_requested.emit(stage_id), 18))
	var body := Style.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(card_scroll)
	_cards = Style.hbox(10)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(_cards)
	var side := Style.panel(12)
	side.custom_minimum_size.x = 330
	body.add_child(side)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(roster_scroll)
	_roster = Style.vbox(10)
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(_roster)
	_rebuild()


func _rebuild() -> void:
	for child in _cards.get_children():
		child.queue_free()
	for slot in range(progression.team.size()):
		var card := SlotCard.new()
		card.catalog = catalog
		card.progression = progression
		card.slot = slot
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 270
		card.changed.connect(_on_changed)
		_cards.add_child(card)
	var slots: int = int(catalog.num("team_size"))
	for slot in range(progression.team.size(), slots):
		var cradle := CradleCard.new()
		cradle.catalog = catalog
		cradle.progression = progression
		cradle.slot = slot
		cradle.ready_to_build = progression.can_build() and slot - progression.team.size() < progression.cores
		cradle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cradle.custom_minimum_size.x = 270
		cradle.build_requested.connect(_on_build)
		_cards.add_child(cradle)
	for child in _roster.get_children():
		child.queue_free()
	_roster.add_child(Style.label("Spirits", 20, Style.GOLD))
	for id in catalog.player_spirit_ids:
		if progression.spirits.has(id):
			_roster.add_child(_roster_entry(id))
	var locked: int = catalog.player_spirit_ids.size() - progression.spirits.size()
	if locked > 0:
		_roster.add_child(Style.wrapped("%d more spirit(s) wait somewhere in the ruins." % locked, 13))


func _on_changed(slot: int, key: String, value: String) -> void:
	if not progression.set_slot(slot, key, value):
		_status.text = "That choice is not available."
		return
	if progression.save_game():
		_status.text = "Saved."
	else:
		_status.text = progression.last_error
	_rebuild()


func _on_build() -> void:
	if not progression.build_golem():
		_status.text = "There is no golem core to build with."
		return
	var spirit: Dictionary = catalog.spirit(progression.team[-1].spirit)
	_status.text = "Golem %d stands! %s wakes in its new body." % [progression.team.size(), spirit.name]
	if not progression.save_game():
		_status.text = progression.last_error
	_rebuild()


func _roster_entry(id: String) -> Control:
	var spirit: Dictionary = catalog.spirit(id)
	var entry: Dictionary = progression.spirits[id]
	var box := Style.vbox(2)
	var in_team: bool = progression.team.any(func(l): return l.spirit == id)
	var head := Style.hbox(6)
	var name_label := Style.label("%s %s" % [spirit.name, spirit.title], 16, Style.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(Style.label("IN A GOLEM" if in_team else "resting", 12, Style.GOOD if in_team else Style.MUTED))
	box.add_child(head)
	var element_color: Color = catalog.element_color(spirit.element)
	var temperament: Dictionary = catalog.temperaments[spirit.temperament]
	box.add_child(Style.label("%s  -  %s  -  Lv %d  (%d/%d XP)" % [catalog.element_label(spirit.element),
		temperament.label, entry.level, entry.xp, progression.xp_to_next(int(entry.level))], 13, element_color))
	var growth: Array[String] = []
	for stat in Catalog.STATS:
		growth.append("%s %d%%" % [Style.STAT_LABELS[stat], int(spirit.growth[stat])])
	var growth_label := Style.wrapped("Growth: " + "  ".join(growth), 12)
	growth_label.tooltip_text = "Chance-like rates, smoothed: every level adds the rate to a running total and each 100 is +1 (HP gains %d)." % int(catalog.num("growth.hp_per_point"))
	growth_label.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(growth_label)
	box.add_child(Style.wrapped("%s: %s" % [spirit["trait"].name, spirit["trait"].text], 12, Style.TEXT))
	var awakening: Dictionary = spirit.awakening
	var awaken_level: int = int(catalog.num("awaken_level"))
	if int(entry.level) >= awaken_level:
		box.add_child(Style.wrapped("Awakened - %s: %s" % [awakening.name, awakening.text], 12, Style.GOLD))
	else:
		box.add_child(Style.wrapped("Awakens at Lv %d - %s: %s" % [awaken_level, awakening.name, awakening.text], 12))
	box.add_child(Style.wrapped("Prefers: " + temperament.text, 12))
	var reactions: Array[String] = []
	var hidden: int = 0
	for material_id in catalog.part_order.materials:
		var reaction: Dictionary = catalog.reaction(material_id, spirit.element)
		if reaction.is_empty():
			continue
		if material_id in progression.unlocks.materials:
			reactions.append("%s (%s)" % [catalog.part("materials", material_id).name, reaction.name])
		else:
			hidden += 1
	if hidden > 0:
		reactions.append("%d material(s) not yet found" % hidden)
	if not reactions.is_empty():
		box.add_child(Style.wrapped("Reacts with: " + ", ".join(reactions), 12, element_color.lerp(Style.TEXT, 0.35)))
	box.add_child(HSeparator.new())
	return box
