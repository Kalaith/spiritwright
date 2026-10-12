extends PanelContainer
## One golem in the workshop: pick the spirit, its row and every part, and
## see the resolved stats with where each number comes from.

signal changed(slot: int, key: String, value: String)

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

var catalog: RefCounted
var progression: RefCounted
var slot: int = 0


func _ready() -> void:
	add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.LINE, 10, 10))
	var loadout: Dictionary = progression.team[slot]
	var golem: Dictionary = progression.resolve_slot(slot)
	var column := Style.vbox(6)
	add_child(column)
	var head := Style.hbox(6)
	column.add_child(head)
	var title := Style.label("Golem %d" % (slot + 1), 18, Style.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var front: bool = loadout.row == "front"
	var row := Style.button("Front row" if front else "Back row",
		func(): changed.emit(slot, "row", "back" if front else "front"), 14)
	row.tooltip_text = "Melee attackers hit the front row first. Shield Arms in the front row protect the back row."
	head.add_child(row)
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(0, 128)
	preview.backdrop = Color("16151f")
	preview.setup(GolemArt.look_for(catalog, golem, Style.ALLY), 0.9)
	column.add_child(preview)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	_selector(grid, "Spirit", "spirit", _spirit_options(), loadout.spirit)
	_selector(grid, "Frame", "frame", _part_options("frames"), loadout.frame)
	_selector(grid, "Arms", "arms", _part_options("arms"), loadout.arms)
	_selector(grid, "Legs", "legs", _part_options("legs"), loadout.legs)
	var sigils: Array = [["", "None", "No sigil."]]
	sigils.append_array(_part_options("sigils"))
	_selector(grid, "Sigil", "sigil", sigils, loadout.sigil)
	column.add_child(_stats(golem))
	var pref: Dictionary = golem.preference
	if not pref.label.is_empty():
		var state: String = "ACTIVE " + Style.stat_line(pref.bonus) if pref.active else "inactive"
		column.add_child(Style.wrapped("%s: %s" % [pref.label, state], 13, Style.GOOD if pref.active else Style.MUTED))
		column.get_child(-1).tooltip_text = pref.text
		column.get_child(-1).mouse_filter = Control.MOUSE_FILTER_PASS
	var spirit: Dictionary = catalog.spirit(loadout.spirit)
	var notes: Array[String] = [
		catalog.part("arms", loadout.arms).text,
		catalog.part("legs", loadout.legs).text,
		"%s: %s" % [spirit["trait"].name, spirit["trait"].text],
	]
	if golem.awakened:
		notes.append("%s (awakened): %s" % [spirit.awakening.name, spirit.awakening.text])
	if not String(loadout.sigil).is_empty():
		notes.append(catalog.part("sigils", loadout.sigil).text)
	for note in notes:
		column.add_child(Style.wrapped("- " + note, 12))


func _selector(grid: GridContainer, label_text: String, key: String, options: Array, current: String) -> void:
	grid.add_child(Style.label(label_text, 14, Style.MUTED))
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 14)
	picker.fit_to_longest_item = false
	picker.clip_text = true
	for i in range(options.size()):
		picker.add_item(options[i][1], i)
		picker.set_item_tooltip(i, options[i][2])
		if options[i][0] == current:
			picker.select(i)
	picker.tooltip_text = options[max(0, picker.selected)][2]
	picker.item_selected.connect(func(index: int): changed.emit(slot, key, String(options[index][0])))
	grid.add_child(picker)


func _spirit_options() -> Array:
	var options: Array = []
	for id in catalog.player_spirit_ids:
		if progression.spirits.has(id):
			var spirit: Dictionary = catalog.spirit(id)
			options.append([id, "%s  Lv %d" % [spirit.name, progression.spirits[id].level],
				"%s %s (%s). %s" % [spirit.name, spirit.title, catalog.element_label(spirit.element), spirit.description]])
	return options


func _part_options(kind: String) -> Array:
	var options: Array = []
	for id in progression.unlocks[kind]:
		var part: Dictionary = catalog.part(kind, id)
		var stats: String = Style.stat_line(part.get("stats", {}))
		options.append([id, part.name, part.text + ("\n" + stats if not stats.is_empty() else "")])
	return options


func _stats(golem: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	for stat in Catalog.STATS:
		var value := Style.label("%s %d" % [Style.STAT_LABELS[stat], int(golem.stats[stat])], 15, Style.TEXT)
		value.mouse_filter = Control.MOUSE_FILTER_PASS
		var lines: Array[String] = []
		for source in golem.breakdown:
			if int(source.stats.get(stat, 0)) != 0:
				lines.append("%s: %+d" % [source.label, int(source.stats[stat])])
		value.tooltip_text = "\n".join(lines)
		grid.add_child(value)
	return grid
