extends Control
## The Shifting Crucible: pick a Royale and a tier, scout every encounter of
## the gauntlet before you begin, lock in the laboratory team and fight the
## encounters in turn. One defeat ends the run; the records, milestones and
## everything in the collection stay.

signal fight_requested
signal laboratory_requested
signal map_requested

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")
const EnemyCard = preload("res://scripts/ui/enemy_card.gd")
const Milestones = preload("res://scripts/ui/crucible_milestones.gd")
const Crucible = preload("res://scripts/core/crucible.gd")

var catalog: RefCounted
var progression: RefCounted
var mode: String = "classic"
var tier: String = ""
var seed: int = 0
## The step shown in the side panel, or -1 for the records and milestones.
var selected: int = 0
var _left: VBoxContainer
var _details: VBoxContainer
var _status: Label


func _ready() -> void:
	_choose_setup()
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
	bar.add_child(Style.label("The Shifting Crucible", 26, Style.GOLD))
	_status = Style.wrapped("One team, locked in, against every boss in turn. Health resets between encounters; one defeat ends the run.", 14)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)
	bar.add_child(Style.button("Records", func(): _select(-1)))
	bar.add_child(Style.button("Laboratory", func(): laboratory_requested.emit()))
	bar.add_child(Style.button("Map", func(): map_requested.emit()))
	var body := Style.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left_scroll)
	# A gutter keeps the right-hand labels clear of the scroll bar.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 18)
	left_scroll.add_child(gutter)
	_left = Style.vbox(8)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(_left)
	var side := Style.panel(14)
	# The scouting panel gives up some width when a larger interface size leaves less.
	resized.connect(func() -> void: side.custom_minimum_size.x = 440 if size.x >= 1180 else 360)
	side.custom_minimum_size.x = 440 if size.x >= 1180 else 360
	body.add_child(side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_details = Style.vbox(8)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_details)
	_rebuild()


## A run under way fixes the Royale, tier and seed; otherwise the last run's
## are offered again, so a defeat can be met with a new team at once.
func _choose_setup() -> void:
	var run: Dictionary = progression.crucible.run
	var last: Dictionary = progression.crucible.last
	tier = catalog.crucible_index.tiers.keys()[0]
	if not run.is_empty():
		mode = run.mode
		tier = run.tier
		seed = int(run.seed)
		selected = int(run.next)
	elif not last.is_empty():
		mode = last.mode
		seed = int(last.seed)
		if Crucible.tier_open(catalog, last.tier, progression.crucible.milestones):
			tier = last.tier
		selected = int(last.get("fell_at", 0))
	if mode == "shifting" and seed == 0:
		seed = randi_range(1, Crucible.SEED_RANGE)


func _steps() -> Array:
	var run: Dictionary = progression.crucible.run
	return run.sequence if not run.is_empty() else Crucible.sequence(catalog, mode, seed)


func _rebuild() -> void:
	for child in _left.get_children():
		child.queue_free()
	var run: Dictionary = progression.crucible.run
	if run.is_empty():
		_left.add_child(_setup())
	else:
		_left.add_child(Style.label("%s  -  %s  -  encounter %d of %d" % [Crucible.MODE_NAMES[mode],
			catalog.crucible_index.tiers[tier].name, int(run.next) + 1, run.sequence.size()], 20, Style.GOLD))
	_left.add_child(Style.wrapped(catalog.crucible_index.tiers[tier].text, 13))
	_left.add_child(Style.label("The gauntlet (pick one to scout it)", 17, Style.MUTED))
	var steps: Array = _steps()
	for index in range(steps.size()):
		_left.add_child(_step_row(index, steps[index]))
	_left.add_child(_actions())
	_left.add_child(_record_line())
	_left.add_child(HSeparator.new())
	_left.add_child(_team_box())
	_show(clampi(selected, -1, steps.size() - 1))


func _setup() -> Control:
	var box := Style.vbox(6)
	var modes := Style.hbox(8)
	box.add_child(modes)
	modes.add_child(Style.label("Royale", 15, Style.MUTED))
	for id in Crucible.MODES:
		modes.add_child(_choice(Crucible.MODE_NAMES[id], id == mode, false, func(): _set_mode(id)))
	if mode == "shifting":
		modes.add_child(Style.label("Seed %d" % seed, 15, Style.TEXT))
		modes.add_child(Style.button("New seed", func():
			seed = randi_range(1, Crucible.SEED_RANGE)
			_rebuild(), 14))
	var tiers := Style.hbox(8)
	box.add_child(tiers)
	tiers.add_child(Style.label("Tier", 15, Style.MUTED))
	for id in catalog.crucible_index.tiers:
		var entry: Dictionary = catalog.crucible_index.tiers[id]
		var open: bool = Crucible.tier_open(catalog, id, progression.crucible.milestones)
		var button := _choice(entry.name, id == tier, not open, func():
			tier = id
			_rebuild())
		if not open:
			button.tooltip_text = "Opens with the milestone %s." % catalog.crucible_index.milestones[entry.requires].name
		tiers.add_child(button)
	var about: String = "The same six encounters and final every time." if mode == "classic" \
		else "The seed draws six of the %d encounters, their order, their courts and the final. Keep the seed to face the same gauntlet again." % catalog.crucible.encounters.size()
	box.add_child(Style.wrapped(about, 13))
	return box


func _choice(text: String, active: bool, locked: bool, callback: Callable) -> Button:
	var button := Style.button(text + ("  (locked)" if locked else ""), callback, 15)
	button.disabled = locked
	if active:
		button.add_theme_color_override("font_color", Style.GOLD)
	return button


func _set_mode(id: String) -> void:
	mode = id
	if mode == "shifting" and seed == 0:
		seed = randi_range(1, Crucible.SEED_RANGE)
	selected = 0
	_rebuild()


## "[x]" won, ">" next, "FELL" where the last run ended.
func _step_row(index: int, step: Dictionary) -> Control:
	var entry: Dictionary = catalog.crucible_encounters[step.encounter]
	var run: Dictionary = progression.crucible.run
	var last: Dictionary = progression.crucible.last
	var mark: Array = ["   ", Style.MUTED]
	if not run.is_empty():
		if index < int(run.next):
			mark = ["[x]", Style.GOOD]
		elif index == int(run.next):
			mark = [" > ", Style.GOLD]
	elif last.has("fell_at") and last.mode == mode and last.tier == tier and int(last.seed) == seed:
		if index < int(last.fell_at):
			mark = ["[x]", Style.GOOD]
		elif index == int(last.fell_at):
			mark = ["FELL", Style.BAD]
	var row := Style.hbox(8)
	var tag := Style.label(mark[0], 15, mark[1])
	tag.custom_minimum_size.x = 44
	row.add_child(tag)
	var label: String = "%d. %s" % [index + 1, entry.name] if not entry.final else "Final. %s" % entry.name
	var link := Style.button(label, func(): _select(index), 16)
	link.flat = true
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if index == selected:
		link.add_theme_color_override("font_color", Style.GOLD)
	row.add_child(link)
	row.add_child(Style.label("Tests: " + entry.test, 14, Style.MUTED))
	return row


func _team_box() -> Control:
	var run: Dictionary = progression.crucible.run
	var team: Array = progression.team if run.is_empty() else run.team
	var box := Style.vbox(4)
	var heading: String = "Your team, locked for this run" if not run.is_empty() \
		else "Your laboratory team (%d of %d golems) locks in when you begin" % [team.size(), int(catalog.num("team_size"))]
	box.add_child(Style.label(heading, 17, Style.MUTED))
	# The team wraps onto a second line rather than widening the column.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	box.add_child(row)
	for loadout in team:
		var cell := Style.vbox(0)
		var preview := GolemPreview.new()
		preview.custom_minimum_size = Vector2(96, 96)
		preview.animated = true
		preview.setup(GolemArt.look_for(catalog, loadout, Style.ALLY), 0.6)
		cell.add_child(preview)
		var name := Style.label(catalog.spirit(loadout.spirit).name, 13, Style.TEXT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name)
		cell.tooltip_text = "%s: %s / %s / %s, %s" % [catalog.spirit(loadout.spirit).name, catalog.part("frames", loadout.frame).name,
			catalog.part("arms", loadout.arms).name, catalog.part("legs", loadout.legs).name, Style.cell_name(loadout.row, int(loadout.lane))]
		row.add_child(cell)
	box.add_child(Style.wrapped("Every golem, yours and theirs, fights at the tier's level whatever its own. Crucible battles give no XP and cost nothing.", 12))
	return box


func _record_line() -> Control:
	var entry: Dictionary = progression.crucible.record(mode, tier)
	var steps: int = _steps().size()
	var text: String = "%s at %s: best %d of %d won, %d run(s), %d completed." % [Crucible.MODE_NAMES[mode],
		catalog.crucible_index.tiers[tier].name, int(entry.best), steps, int(entry.runs), int(entry.completions)]
	var last: Dictionary = progression.crucible.last
	if progression.crucible.run.is_empty() and last.has("fell_at"):
		var fell: Dictionary = catalog.crucible_encounters[Crucible.sequence(catalog, last.mode, int(last.seed))[int(last.fell_at)].encounter]
		text += " Your last run fell at %s (%d of %d): scout it, change the team in the laboratory and try again." % [
			fell.name, int(last.fell_at) + 1, steps]
	return Style.wrapped(text, 14, Style.TEXT)


func _actions() -> Control:
	var box := Style.vbox(6)
	var row := Style.hbox(10)
	box.add_child(row)
	var run: Dictionary = progression.crucible.run
	if run.is_empty():
		var begin := Style.button("Begin the %s" % Crucible.MODE_NAMES[mode], _begin, 20)
		begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(begin)
		return box
	var next: Dictionary = catalog.crucible_encounters[run.sequence[int(run.next)].encounter]
	var fight := Style.button("Fight: " + next.name, func(): fight_requested.emit(), 20)
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fight)
	var confirm := Style.hbox(8)
	confirm.add_child(Style.label("End this run here?", 14, Style.BAD))
	confirm.add_child(Style.button("End it", _abandon, 14))
	confirm.add_child(Style.button("Keep going", func(): confirm.hide(), 14))
	confirm.hide()
	row.add_child(Style.button("Abandon run", func(): confirm.show(), 15))
	box.add_child(confirm)
	fight.call_deferred("grab_focus")
	return box


func _begin() -> void:
	if not progression.start_crucible(mode, tier, seed):
		_status.text = "The run could not begin."
		return
	selected = 0
	_save("The team is locked in. Good luck.")
	_rebuild()


func _abandon() -> void:
	progression.crucible.abandon()
	_save("The run is over. The records keep how far it went.")
	_rebuild()


func _save(message: String) -> void:
	_status.text = message if progression.save_game() else progression.last_error


func _select(index: int) -> void:
	selected = index
	_rebuild()


## Shows step `index` in the side panel, or the records and milestones for -1.
func _show(index: int) -> void:
	selected = index
	for child in _details.get_children():
		child.queue_free()
	if index < 0:
		Milestones.fill(_details, catalog, progression, func(id: String):
			if progression.set_crucible_title(id):
				_save("Title chosen.")
			_show(-1))
		return
	var steps: Array = _steps()
	var step: Dictionary = steps[index]
	var entry: Dictionary = catalog.crucible_encounters[step.encounter]
	_details.add_child(Style.label(entry.name, 24, Style.GOLD))
	var where: String = "The final" if entry.final else "Encounter %d of %d" % [index + 1, steps.size()]
	var seen: String = "  -  beaten before" if step.encounter in progression.crucible.seen else ""
	_details.add_child(Style.label("%s  -  tests %s%s" % [where, entry.test, seen], 15, Style.MUTED))
	_details.add_child(Style.wrapped(entry.text, 15, Style.TEXT))
	_details.add_child(Style.label("Enemy team", 17, Style.MUTED))
	for golem in Crucible.enemy_team(catalog, step, tier):
		_details.add_child(EnemyCard.make(catalog, golem))
