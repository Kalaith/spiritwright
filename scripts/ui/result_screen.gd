extends Control
## After a battle: who did what (so the player can see why it went this way),
## experience and level-ups, and anything unlocked.

signal map_requested
signal laboratory_requested
signal retry_requested

const Style = preload("res://scripts/ui/style.gd")

var catalog: RefCounted
var stage: Dictionary = {}
var outcome: Dictionary = {}
var report: Dictionary = {}
var save_error: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Style.backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Style.panel(20)
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var column := Style.vbox(10)
	panel.add_child(column)
	var won: bool = outcome.result == "win"
	var heading := Style.hbox(14)
	column.add_child(heading)
	heading.add_child(Style.label({"win": "Victory", "loss": "Defeat"}.get(outcome.result, "Time up"), 34, Style.GOOD if won else Style.BAD))
	var subtitle: String = stage.name
	if report.first_clear:
		subtitle += " cleared for the first time!"
	elif not won:
		subtitle += ": your spirits return to the laboratory, wiser for it."
	var sub := Style.label(subtitle, 17, Style.MUTED)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(sub)
	column.add_child(_why_table())
	column.add_child(Style.wrapped(_insight(), 15, Style.TEXT))
	column.add_child(HSeparator.new())
	for line in report.xp:
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
	for reward in report.rewards:
		var lines: Array = Style.reward_text(catalog, reward.kind, reward.id)
		column.add_child(Style.label("Unlocked  " + lines[0], 17, Style.GOLD))
		column.add_child(Style.wrapped(lines[1], 13))
	if report.first_clear and stage.has("clear_text"):
		column.add_child(Style.wrapped(stage.clear_text, 15, Style.GOLD))
	if not save_error.is_empty():
		column.add_child(Style.wrapped(save_error, 14, Style.BAD))
	var buttons := Style.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_child(Style.button("Retry", func(): retry_requested.emit()))
	buttons.add_child(Style.button("Laboratory", func(): laboratory_requested.emit()))
	var map := Style.button("Map", func(): map_requested.emit(), 18)
	buttons.add_child(map)
	column.add_child(buttons)
	map.call_deferred("grab_focus")


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
