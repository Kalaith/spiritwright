extends Control
## The Codex: the whole collection at a glance. Spirits (found and still to
## find, and exactly how, each with a Journal page), every stage's challenges, the feats with this
## playthrough's record, and the Crucible's encounters and milestones, so the
## player always has several goals in view.

signal map_requested
signal stage_requested(stage_id: String)

const Style = preload("res://scripts/ui/style.gd")
const CodexText = preload("res://scripts/ui/codex_text.gd")
const SpiritCard = preload("res://scripts/ui/codex_spirit_card.gd")
const Journal = preload("res://scripts/ui/codex_journal.gd")
const Challenges = preload("res://scripts/core/challenges.gd")
const TABS: Array[String] = ["Spirits", "Challenges", "Feats", "Crucible"]

var catalog: RefCounted
var progression: RefCounted
var tab: String = "Spirits"
## The spirit whose Journal page is open in the Spirits tab, or "" for the grid.
var journal_id: String = ""
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons: Dictionary = {}
var _sources: Dictionary = {}
## The Spirits tab's card grid while it is on show.
var _spirit_grid: GridContainer


func _ready() -> void:
	_sources = Challenges.spirit_sources(catalog)
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
	bar.add_child(Style.label("Codex", 26, Style.GOLD))
	var summary := Style.wrapped(_summary(), 14, Style.TEXT)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(summary)
	for tab_name in TABS:
		var button := Style.button(tab_name, func(): _show(tab_name))
		_tab_buttons[tab_name] = button
		bar.add_child(button)
	bar.add_child(Style.button("Map", func(): map_requested.emit()))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = Style.vbox(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	resized.connect(func() -> void:
		if is_instance_valid(_spirit_grid):
			_spirit_grid.columns = _spirit_columns())
	_show(tab)


## "Spirits 9 of 27 (playing 9/16, challenges 0/8, extreme 0/3) ..."
func _summary() -> String:
	var found: Dictionary = {"play": [0, 0], "challenge": [0, 0], "extreme": [0, 0]}
	for id in catalog.player_spirit_ids:
		var tier: String = _sources[id][0].tier
		found[tier][1] += 1
		if progression.spirits.has(id):
			found[tier][0] += 1
	return "Spirits %d of %d  (by playing %d/%d, challenges %d/%d, extreme %d/%d).  Challenges %d of %d.  Feats %d of %d." % [
		progression.spirits.size(), catalog.player_spirit_ids.size(), found.play[0], found.play[1],
		found.challenge[0], found.challenge[1], found.extreme[0], found.extreme[1],
		progression.challenges.size(), catalog.challenges.size(), progression.feats.size(), catalog.feats.size()]


## Back (Esc or gamepad B) from a Journal page returns to the spirits, not the map.
func _unhandled_input(event: InputEvent) -> void:
	var back: bool = event.is_action_pressed("ui_cancel") or 		(event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back and not journal_id.is_empty():
		get_viewport().set_input_as_handled()
		_show("Spirits")


func _show(tab_name: String) -> void:
	_clear(tab_name)
	match tab_name:
		"Spirits":
			_spirits()
		"Challenges":
			_challenges()
		"Feats":
			_feats()
		"Crucible":
			_crucible()


## Spirit cards abreast: four at the standard size, fewer when a larger
## interface size leaves less room.
func _spirit_columns() -> int:
	return clampi(int((size.x - 40.0) / 300.0), 2, 4)


func _spirits() -> void:
	_content.add_child(Style.wrapped("Every spirit you meet can join you. Most come as you play; some only answer a challenge; a few only the hardest feats. Challenges and feats are met by any win that keeps their rules.", 14))
	var grid := GridContainer.new()
	grid.columns = _spirit_columns()
	_spirit_grid = grid
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for id in catalog.player_spirit_ids:
		var card := SpiritCard.new()
		card.catalog = catalog
		card.progression = progression
		card.spirit_id = id
		card.source = _sources[id][0]
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 290
		card.opened.connect(open_journal)
		grid.add_child(card)


## Empties the page for `tab_name` and lights its button.
func _clear(tab_name: String) -> void:
	tab = tab_name
	journal_id = ""
	for key in _tab_buttons:
		_tab_buttons[key].add_theme_color_override("font_color", Style.GOLD if key == tab_name else Style.TEXT)
	for child in _content.get_children():
		child.queue_free()
	_scroll.scroll_vertical = 0


## One spirit's Journal page, with the spirits before and after it a tap away.
func open_journal(id: String) -> void:
	_clear("Spirits")
	journal_id = id
	var ids: Array[String] = catalog.player_spirit_ids
	var at: int = ids.find(id)
	var bar := Style.hbox(10)
	_content.add_child(bar)
	bar.add_child(Style.button("< " + catalog.spirit(ids[at - 1]).name, func(): open_journal(ids[at - 1]), 15))
	bar.add_child(Style.button("All spirits", func(): _show("Spirits"), 15))
	bar.add_child(Style.button(catalog.spirit(ids[(at + 1) % ids.size()]).name + " >",
		func(): open_journal(ids[(at + 1) % ids.size()]), 15))
	var label := Style.label("Journal  %d of %d" % [at + 1, ids.size()], 14, Style.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(label)
	var page := Journal.new()
	page.catalog = catalog
	page.progression = progression
	page.spirit_id = id
	page.source = _sources[id][0]
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(page)


func _challenges() -> void:
	_content.add_child(Style.wrapped("Each stage holds challenges: win it while keeping their rules. They open from the first visit, and a replay with a new build counts. Meet every challenge in a region to master it and earn its sigil. Pick a stage name to go there.", 14))
	for region in catalog.regions():
		var ids: Array = Challenges.region_ids(region)
		var done: int = ids.filter(func(id): return id in progression.challenges).size()
		_content.add_child(Style.label("%s  %d of %d" % [region.name, done, ids.size()], 20, Style.GOLD))
		if region.has("mastery"):
			var mastered: bool = Challenges.mastered(region, progression.challenges)
			_content.add_child(Style.wrapped("%s %s: %s %s" % ["[x]" if mastered else "[ ]", region.mastery.name,
				region.mastery.text, CodexText.reward_line(catalog, region.mastery)], 14, Style.GOOD if mastered else Style.GOLD))
			for kind in region.mastery.rewards:
				for id in region.mastery.rewards[kind]:
					_content.add_child(Style.wrapped("    " + Style.reward_text(catalog, kind, id)[1], 13, Style.MUTED))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(grid)
		for stage in region.stages:
			grid.add_child(_stage_challenges(stage))


func _stage_challenges(stage: Dictionary) -> Control:
	var box := Style.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 440
	var state: String = progression.stage_state(stage.id)
	var link := Style.button(stage.name + ("" if state != "locked" else "  (not yet reached)"),
		func(): stage_requested.emit(stage.id), 15)
	link.flat = true
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.disabled = state == "locked"
	box.add_child(link)
	for entry in stage.get("challenges", []):
		var done: bool = entry.id in progression.challenges
		box.add_child(Style.wrapped(CodexText.challenge_line(entry, done), 13, CodexText.challenge_color(entry, done)))
		var reward: String = CodexText.reward_line(catalog, entry)
		if not reward.is_empty() and not done:
			box.add_child(Style.wrapped("    " + reward, 12, Style.GOLD))
	return box


func _feats() -> void:
	var record: Dictionary = progression.run
	var cleared: int = catalog.stages.keys().filter(func(id): return id in progression.cleared).size()
	var which: String = "your first playthrough" if progression.cycle == 0 else "New Game+ %d" % progression.cycle
	_content.add_child(Style.label("This playthrough: %s" % which, 20, Style.GOLD))
	_content.add_child(Style.wrapped("Stages cleared %d of %d.  Golems fallen %d.  Battles lost %d.  Most golems fielded in one battle %d." % [
		cleared, catalog.stages.size(), int(record.falls), int(record.losses), int(record.most_golems)], 15, Style.TEXT))
	_content.add_child(Style.wrapped("Feats are judged on a whole playthrough, the moment its last stage is cleared. A fallen golem or a lost battle counts against the record for the rest of that playthrough; once the Storm Crown falls, New Game+ on the map starts a fresh record with your whole collection and stronger wild spirits.", 14))
	var in_reach: Array = progression.feats_in_reach()
	for id in catalog.feats:
		var feat: Dictionary = catalog.feats[id]
		var panel := Style.panel(12)
		_content.add_child(panel)
		var box := Style.vbox(3)
		panel.add_child(box)
		var head := Style.hbox(10)
		box.add_child(head)
		head.add_child(Style.label(feat.name, 18, Style.TEXT))
		if feat.get("extreme", false):
			head.add_child(Style.label("EXTREME", 12, CodexText.TIER_COLORS.extreme))
		var status: Array = ["Out of reach this playthrough", Style.MUTED]
		if id in progression.feats:
			status = ["EARNED", Style.GOOD]
		elif id in in_reach:
			status = ["Still in reach this playthrough", Style.GOLD]
		elif progression.cycle < int(feat.rules.get("min_cycle", 0)):
			status = ["Needs New Game+", Style.MUTED]
		head.add_child(Style.label(status[0], 13, status[1]))
		box.add_child(Style.wrapped(feat.text, 14, Style.TEXT))
		var reward: String = CodexText.reward_line(catalog, feat)
		if not reward.is_empty():
			box.add_child(Style.wrapped(reward, 13, Style.GOLD))


## Every Crucible encounter as a Codex entry (its test and story once beaten,
## only its name before), and the milestones.
func _crucible() -> void:
	var record: RefCounted = progression.crucible
	if not progression.crucible_open():
		_content.add_child(Style.wrapped(catalog.crucible.unlock.text + " It pits one locked team against every boss in turn.", 15))
	var all: Array = catalog.crucible.encounters + catalog.crucible.finals
	_content.add_child(Style.label("Encounters beaten  %d of %d" % [record.seen.size(), all.size()], 20, Style.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for entry in all:
		var box := Style.vbox(2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size.x = 440
		var beaten: bool = entry.id in record.seen
		var kind: String = "Final" if entry.final else "Encounter"
		box.add_child(Style.label("%s %s  (%s, tests %s)" % ["[x]" if beaten else "[ ]", entry.name, kind, entry.test], 16,
			Style.GOOD if beaten else Style.TEXT))
		box.add_child(Style.wrapped(entry.text if beaten else "Beat it in the Crucible to record it here.", 13))
		grid.add_child(box)
	_content.add_child(Style.label("Milestones  %d of %d" % [record.milestones.size(), catalog.crucible_index.milestones.size()], 20, Style.GOLD))
	for id in catalog.crucible_index.milestones:
		var milestone: Dictionary = catalog.crucible_index.milestones[id]
		var done: bool = id in record.milestones
		_content.add_child(Style.wrapped("%s %s: %s %s" % ["[x]" if done else "[ ]", milestone.name, milestone.text,
			CodexText.reward_line(catalog, milestone)], 14, Style.GOOD if done else Style.TEXT))
