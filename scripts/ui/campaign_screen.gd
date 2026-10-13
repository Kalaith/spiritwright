extends Control
## Region map (one region at a time, stepped with < and >) plus the selected
## stage's scouting report: enemy builds, traits
## and first-clear rewards, so the player can plan a counter in the laboratory.

signal laboratory_requested
signal fight_requested(stage_id: String)
signal title_requested
signal new_game_plus_requested
signal codex_requested
signal crucible_requested

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const CampaignMap = preload("res://scripts/ui/campaign_map.gd")
const CodexText = preload("res://scripts/ui/codex_text.gd")
const EnemyCard = preload("res://scripts/ui/enemy_card.gd")

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
	if progression.crucible_open():
		bar.add_child(Style.button("Crucible", func(): crucible_requested.emit()))
	bar.add_child(Style.button("Codex", func(): codex_requested.emit()))
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
	_region_count.text += "  -  Spirits %d of %d" % [progression.spirits.size(), catalog.player_spirit_ids.size()]
	if progression.cycle > 0:
		_region_count.text += "  -  New Game+ %d" % progression.cycle
	if not progression.crucible.title.is_empty():
		_region_count.text += "  -  " + catalog.crucible_index.titles[progression.crucible.title].name
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
	# On its own line: a boss's heading row is already as wide as the panel.
	var stage_challenges: Array = stage.get("challenges", [])
	if not stage_challenges.is_empty():
		var met: int = stage_challenges.filter(func(c): return c.id in progression.challenges).size()
		_details.add_child(Style.label("Challenges met %d of %d (listed below the rewards)" % [met, stage_challenges.size()], 14,
			Style.GOOD if met == stage_challenges.size() else Style.GOLD))
	_details.add_child(Style.wrapped(stage.text, 15, Style.TEXT))
	_details.add_child(Style.label("Enemy team", 17, Style.MUTED))
	for golem in progression.enemy_team(stage):
		_details.add_child(EnemyCard.make(catalog, golem))
	var level: int = progression.stage_level(stage)
	var xp_factor: float = catalog.num("xp.repeat_win" if state == "cleared" else "xp.first_clear")
	_details.add_child(Style.wrapped("%s %d XP per Lv %d spirit; lower-level spirits earn more, higher-level less." % [
		"Replay for" if state == "cleared" else "Win for", progression.stage_xp(stage, level, xp_factor), level], 14))
	var rewards: Array = _new_rewards(stage)
	if state != "cleared" and rewards.is_empty():
		_details.add_child(Style.wrapped("No new parts or spirits wait here: this fight is for experience.", 14))
	elif state != "cleared":
		_details.add_child(Style.label("First-clear rewards", 17, Style.MUTED))
		for reward in rewards:
			var lines: Array = Style.reward_text(catalog, reward[0], reward[1])
			_details.add_child(Style.wrapped(lines[0], 15, Style.GOLD))
			_details.add_child(Style.wrapped(lines[1], 13))
	var challenges: Array = stage.get("challenges", [])
	if not challenges.is_empty():
		var done: int = challenges.filter(func(c): return c.id in progression.challenges).size()
		_details.add_child(Style.label("Challenges  %d of %d  (any win counts)" % [done, challenges.size()], 17, Style.MUTED))
		for entry in challenges:
			_details.add_child(_challenge_row(entry))
	var buttons := Style.hbox(10)
	buttons.add_child(_lab_button())
	var fight := Style.button("Fight!", func(): fight_requested.emit(selected), 20)
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fight)
	_details.add_child(buttons)
	_details.add_child(Style.wrapped(_team_line(), 13))
	if progression.can_build():
		_details.add_child(Style.wrapped("A golem core waits in the laboratory: build another golem before you set out.", 13, Style.GOLD))
	if progression.campaign_complete():
		_details.add_child(_new_game_plus_offer())


func _challenge_row(entry: Dictionary) -> Control:
	var done: bool = entry.id in progression.challenges
	var box := Style.vbox(0)
	box.add_child(Style.wrapped(CodexText.challenge_line(entry, done), 14, CodexText.challenge_color(entry, done)))
	var reward: String = CodexText.reward_line(catalog, entry)
	if not reward.is_empty():
		box.add_child(Style.wrapped("    " + reward, 13, Style.MUTED if done else Style.GOLD))
	return box


## [kind, id] pairs a first clear would still give: in New Game+ most parts and
## spirits are already owned, and cores only fill empty cradles.
func _new_rewards(stage: Dictionary) -> Array:
	var rewards: Array = []
	for kind in stage.get("rewards", {}):
		if kind == "cores":
			var room: int = int(catalog.num("team_size")) - progression.team.size() - progression.cores
			if room > 0:
				rewards.append([kind, str(min(room, int(stage.rewards.cores)))])
			continue
		for id in stage.rewards[kind]:
			var owned: bool = progression.spirits.has(id) if kind == "spirits" else id in progression.unlocks[kind]
			if not owned:
				rewards.append([kind, id])
	return rewards


func _new_game_plus_offer() -> Control:
	var box := Style.vbox(6)
	box.add_child(HSeparator.new())
	var step: int = int(catalog.num("new_game_plus.level_step"))
	box.add_child(Style.label("New Game+ %d" % (progression.cycle + 1), 17, Style.GOLD))
	box.add_child(Style.wrapped("%s has fallen. Walk the road again from the Mossy Gate: your spirits, their levels, your parts and golems come with you, and every wild spirit stands %d levels stronger (up to Lv %d)." % [
		catalog.stages[catalog.finale_id].name, step, int(catalog.num("level_cap"))], 13))
	var confirm := Style.hbox(8)
	confirm.add_child(Style.label("Start over the map?", 14, Style.BAD))
	confirm.add_child(Style.button("Begin", func(): new_game_plus_requested.emit(), 15))
	confirm.add_child(Style.button("Not yet", func(): confirm.hide(), 15))
	confirm.hide()
	box.add_child(Style.button("Begin New Game+", func(): confirm.show(), 16))
	box.add_child(confirm)
	return box


func _team_line() -> String:
	var names: Array[String] = []
	for loadout in progression.team:
		var spirit: Dictionary = catalog.spirit(loadout.spirit)
		names.append("%s Lv %d" % [spirit.name, progression.spirits[loadout.spirit].level])
	return "Your golems (%d of %d built): %s" % [progression.team.size(), int(catalog.num("team_size")), ", ".join(names)]


func _lab_button() -> Button:
	var text: String = "Laboratory (core ready!)" if progression.can_build() else "Laboratory"
	return Style.button(text, func(): laboratory_requested.emit())
