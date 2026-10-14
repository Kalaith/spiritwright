extends Control
## After a battle: who did what (so the player can see why it went this way),
## experience and level-ups, and anything unlocked; or, after a Crucible
## encounter, how the run stands.

## Back to the map, or to the Crucible (see back_text).
signal map_requested
signal laboratory_requested
signal retry_requested
## The Crucible run's next encounter.
signal next_requested

const Style = preload("res://scripts/ui/style.gd")
const CodexText = preload("res://scripts/ui/codex_text.gd")
const CrucibleLines = preload("res://scripts/ui/crucible_result.gd")
const Backdrop = preload("res://scripts/ui/battle_backdrop.gd")

var catalog: RefCounted
var stage: Dictionary = {}
## The battle's scene, shown dimmed behind the report.
var scene: String = "ruins"
var outcome: Dictionary = {}
## Progression.apply_battle's report, or Progression.apply_crucible's when `crucible`.
var report: Dictionary = {}
var crucible: bool = false
var back_text: String = "Map"
## The Crucible run's next encounter, or "" once the run has ended.
var next_name: String = ""
## Ids of every challenge met so far, to list the ones still open on this stage.
var progression_challenges: Array = []
var save_error: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Backdrop.scenery(self, scene, 0.6)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Style.panel(20)
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	# Six golems a side make a long table: the panel scrolls rather than overflow.
	var outer := Style.vbox(10)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(860, 0)
	outer.add_child(scroll)
	var column := Style.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.resized.connect(func(): scroll.custom_minimum_size.y = min(column.size.y, get_viewport_rect().size.y - 140.0))
	var won: bool = outcome.result == "win"
	var heading := Style.hbox(14)
	column.add_child(heading)
	heading.add_child(Style.label({"win": "Victory", "loss": "Defeat"}.get(outcome.result, "Time up"), 34, Style.GOOD if won else Style.BAD))
	var sub := Style.label(_subtitle(), 17, Style.MUTED)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(sub)
	column.add_child(_why_table())
	column.add_child(Style.wrapped(_insight(), 15, Style.TEXT))
	column.add_child(HSeparator.new())
	if crucible:
		CrucibleLines.fill(column, catalog, report)
	else:
		_campaign_lines(column)
	if not save_error.is_empty():
		column.add_child(Style.wrapped(save_error, 14, Style.BAD))
	var buttons := Style.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	if not crucible:
		buttons.add_child(Style.button("Retry", func(): retry_requested.emit()))
	buttons.add_child(Style.button("Laboratory", func(): laboratory_requested.emit()))
	var back := Style.button(back_text, func(): map_requested.emit(), 18)
	buttons.add_child(back)
	var focus: Button = back
	if not next_name.is_empty():
		focus = Style.button("Next: " + next_name, func(): next_requested.emit(), 18)
		buttons.add_child(focus)
	outer.add_child(buttons)
	focus.call_deferred("grab_focus")


func _subtitle() -> String:
	if crucible:
		return CrucibleLines.subtitle(catalog, report)
	if report.first_clear:
		return stage.name + " cleared for the first time!"
	if outcome.result != "win":
		return stage.name + ": your spirits return to the laboratory, wiser for it."
	return stage.name


## Experience, level-ups, challenges, masteries, feats and unlocks from a campaign stage.
func _campaign_lines(column: VBoxContainer) -> void:
	for line in report.xp.filter(func(l): return not l.get("resting", false)):
		var spirit: Dictionary = catalog.spirit(line.spirit)
		var text: String = "%s  +%d XP" % [spirit.name, int(line.gained)]
		var color: Color = Style.TEXT
		if int(line.to) > int(line.from):
			var rises: String = Style.stat_line(line.rises)
			text += "   Level up! Lv %d to %d:  %s" % [int(line.from), int(line.to), rises if not rises.is_empty() else "growth builds toward the next rise"]
			color = Style.GOLD
		column.add_child(Style.label(text, 15, color))
		if line.awakened:
			column.add_child(Style.wrapped("%s awakens! %s: %s" % [spirit.name, spirit.awakening.name, spirit.awakening.text], 15, Style.GOLD))
	var grew: Array[String] = []
	for line in report.xp.filter(func(l): return l.get("resting", false) and int(l.to) > int(l.from)):
		grew.append("%s Lv %d%s" % [catalog.spirit(line.spirit).name, int(line.to), " (awakened!)" if line.awakened else ""])
	if not grew.is_empty():
		column.add_child(Style.wrapped("Resting spirits learned by watching: " + ", ".join(grew) + ".", 14, Style.GOLD.darkened(0.1)))
	for id in report.challenges:
		column.add_child(Style.wrapped("Challenge met!  " + CodexText.challenge_line(catalog.challenges[id], true), 17, Style.GOOD))
	for region in catalog.regions().filter(func(r): return r.id in report.get("masteries", [])):
		column.add_child(Style.wrapped("%s mastered!  %s: %s %s" % [region.name, region.mastery.name, region.mastery.text,
			CodexText.reward_line(catalog, region.mastery)], 18, Style.GOLD))
	for id in report.feats:
		column.add_child(Style.wrapped("Feat earned!  %s: %s" % [catalog.feats[id].name, catalog.feats[id].text], 18, Style.GOLD))
	for id in report.spoiled:
		column.add_child(Style.wrapped("%s is out of reach for the rest of this playthrough. New Game+ starts a fresh record." % catalog.feats[id].name, 14, Style.MUTED))
	var open: Array = stage.get("challenges", []).filter(func(c): return not c.id in progression_challenges)
	if not open.is_empty():
		column.add_child(Style.wrapped("Still open here: " + ", ".join(open.map(func(c): return c.name)) + ".", 14))
	for reward in report.rewards:
		var lines: Array = Style.reward_text(catalog, reward.kind, reward.id)
		column.add_child(Style.label("Unlocked  " + lines[0], 17, Style.GOLD))
		column.add_child(Style.wrapped(lines[1], 13))
	if report.first_clear and stage.has("clear_text"):
		column.add_child(Style.wrapped(stage.clear_text, 15, Style.GOLD))


func _why_table() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 3)
	for header in ["Golem", "Damage dealt", "Taken", "Mended", "Ward given", "Defeated", "Triggers"]:
		grid.add_child(Style.label(header, 13, Style.MUTED))
	for unit in outcome.units:
		var color: Color = Style.ALLY if unit.side == 0 else Style.ENEMY
		var name := Style.label(unit.label + ("" if unit.alive else "  (fell)"), 15, color)
		grid.add_child(name)
		for key in ["dealt", "taken", "healed", "shielded", "kills", "triggers"]:
			grid.add_child(Style.label(str(int(unit[key])), 15, Style.TEXT))
	return grid


## One plain sentence about what decided the fight.
func _insight() -> String:
	var best: Dictionary = {}
	for unit in outcome.units:
		if best.is_empty() or unit.dealt > best.dealt:
			best = unit
	var side: String = "Your" if best.side == 0 else "The enemy's"
	var text: String = "%s %s did the most damage (%d)." % [side, best.label, int(best.dealt)]
	if outcome.result == "win":
		return text
	var enemy_best: Dictionary = {}
	for unit in outcome.units:
		if unit.side == 1 and (enemy_best.is_empty() or unit.dealt > enemy_best.dealt):
			enemy_best = unit
	return text + " Consider a build that answers %s: protect what it hits, or reach and remove it first." % enemy_best.label
