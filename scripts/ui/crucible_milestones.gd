extends RefCounted
## The Crucible's records and rewards, for the Crucible screen's side panel:
## each Royale's record at each tier, the milestones with what they bring, the
## title to wear on the map, and the vessel finishes earned.

const Style = preload("res://scripts/ui/style.gd")
const Crucible = preload("res://scripts/core/crucible.gd")


## Fills `box`. `on_title` is called with a title id ("" for none) when one is chosen.
static func fill(box: VBoxContainer, catalog: RefCounted, progression: RefCounted, on_title: Callable) -> void:
	var record: RefCounted = progression.crucible
	var steps: int = int(catalog.crucible.encounters_per_run) + 1
	box.add_child(Style.label("Records", 22, Style.GOLD))
	for mode in Crucible.MODES:
		for tier_id in catalog.crucible_index.tiers:
			var entry: Dictionary = record.record(mode, tier_id)
			var line: String = "%s, %s:  " % [Crucible.MODE_NAMES[mode], catalog.crucible_index.tiers[tier_id].name]
			if int(entry.runs) == 0:
				line += "not yet attempted"
			else:
				line += "best %d of %d won, %d run(s), %d completed" % [int(entry.best), steps, int(entry.runs), int(entry.completions)]
			box.add_child(Style.wrapped(line, 14, Style.GOOD if int(entry.completions) > 0 else Style.TEXT))
			for team in entry.teams.slice(0, 2):
				box.add_child(Style.wrapped("    Won with: " + _team_text(catalog, team.golems), 12))
	box.add_child(HSeparator.new())
	box.add_child(Style.label("Milestones  %d of %d" % [record.milestones.size(), catalog.crucible_index.milestones.size()], 22, Style.GOLD))
	for id in catalog.crucible_index.milestones:
		var milestone: Dictionary = catalog.crucible_index.milestones[id]
		var done: bool = id in record.milestones
		box.add_child(Style.wrapped("%s %s: %s" % ["[x]" if done else "[ ]", milestone.name, milestone.text], 15,
			Style.GOOD if done else Style.TEXT))
		var names: Array = []
		for kind in milestone.rewards:
			for reward in milestone.rewards[kind]:
				names.append(Style.reward_text(catalog, kind, reward)[0])
		box.add_child(Style.wrapped("    " + ", ".join(names), 12, Style.MUTED if done else Style.GOLD))
	box.add_child(HSeparator.new())
	box.add_child(Style.label("Title", 22, Style.GOLD))
	var titles: Array = Crucible.unlocked(catalog, record.milestones, "titles")
	if titles.is_empty():
		box.add_child(Style.wrapped("Milestones bring titles to wear on the map.", 13))
	else:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
		box.add_child(row)
		for id in [""] + titles:
			var text: String = "None" if id == "" else catalog.crucible_index.titles[id].name
			var button := Style.button(text, func(): on_title.call(id), 14)
			if id == record.title:
				button.add_theme_color_override("font_color", Style.GOLD)
			row.add_child(button)
	box.add_child(Style.label("Vessel finishes", 22, Style.GOLD))
	var finishes: Array = Crucible.unlocked(catalog, record.milestones, "finishes")
	if finishes.is_empty():
		box.add_child(Style.wrapped("Milestones bring vessel finishes: looks for any golem, chosen on its card in the laboratory. They never change a fight.", 13))
	for id in finishes:
		var finish: Dictionary = catalog.crucible_index.finishes[id]
		box.add_child(Style.wrapped("%s: %s" % [finish.name, finish.text], 13, Color(String(finish.color))))


static func _team_text(catalog: RefCounted, golems: Array) -> String:
	return ", ".join(golems.map(func(l): return "%s (%s/%s)" % [catalog.spirit(l.spirit).name,
		catalog.part("arms", l.arms).name.trim_suffix(" Arms"), catalog.part("legs", l.legs).name.trim_suffix(" Legs")]))
