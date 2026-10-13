extends RefCounted
## The result screen's words after a Crucible encounter (see
## Progression.apply_crucible): how the run stands, the record, and any
## milestone met with what it brings.

const Style = preload("res://scripts/ui/style.gd")
const Crucible = preload("res://scripts/core/crucible.gd")


static func subtitle(catalog: RefCounted, report: Dictionary) -> String:
	var entry: Dictionary = catalog.crucible_encounters[report.encounter]
	if report.complete:
		return "%s falls: the %s is complete!" % [entry.name, Crucible.MODE_NAMES[report.mode]]
	if report.won:
		return "%s falls (%d of %d)." % [entry.name, int(report.index) + 1, int(report.steps)]
	return "%s ends the run at %d of %d." % [entry.name, int(report.index) + 1, int(report.steps)]


static func fill(column: VBoxContainer, catalog: RefCounted, report: Dictionary) -> void:
	var tier: String = catalog.crucible_index.tiers[report.tier].name
	var royale: String = "%s at %s" % [Crucible.MODE_NAMES[report.mode], tier]
	if report.complete:
		column.add_child(Style.wrapped("One team answered every test. The winning team is kept in the Crucible's records.", 17, Style.GOLD))
	elif report.won:
		column.add_child(Style.wrapped("Your golems are mended and stand ready for the next encounter, the team still locked.", 15, Style.TEXT))
	else:
		var entry: Dictionary = catalog.crucible_encounters[report.encounter]
		column.add_child(Style.wrapped("This encounter tests %s. Scout it in the Crucible, change the team in the laboratory, and begin again from the first encounter: your spirits, parts and levels are all as they were." % entry.test.to_lower(), 15, Style.TEXT))
	var best: String = "%s: best %d of %d won." % [royale, int(report.best), int(report.steps)]
	if report.new_best:
		best += " A new best!"
	column.add_child(Style.label(best, 15, Style.GOLD if report.new_best else Style.MUTED))
	for id in report.milestones:
		var milestone: Dictionary = catalog.crucible_index.milestones[id]
		column.add_child(Style.wrapped("Milestone!  %s: %s" % [milestone.name, milestone.text], 18, Style.GOLD))
	for reward in report.rewards:
		var lines: Array = Style.reward_text(catalog, reward.kind, reward.id)
		column.add_child(Style.label("Unlocked  " + lines[0], 17, Style.GOLD))
		column.add_child(Style.wrapped(lines[1], 13))
