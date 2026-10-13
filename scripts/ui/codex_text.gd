extends RefCounted
## Words for the Codex, shared by the map, the result screen and the Codex
## itself: how a spirit joins, and one line per challenge or feat.

const Style = preload("res://scripts/ui/style.gd")

const TIER_LABELS: Dictionary = {"play": "FOUND BY PLAYING", "challenge": "CHALLENGE", "extreme": "EXTREME"}
const TIER_COLORS: Dictionary = {"play": Style.ALLY, "challenge": Style.GOLD, "extreme": Style.BAD}


## How a spirit joins, from one Challenges.spirit_sources entry.
static func source_text(catalog: RefCounted, source: Dictionary) -> String:
	match String(source.kind):
		"start":
			return "With you from the start."
		"stage":
			var stage: Dictionary = catalog.stages[source.id]
			return "Joins when you first clear %s (%s)." % [stage.name, catalog.region_of(stage.id).name]
		"challenge":
			var entry: Dictionary = catalog.challenges[source.id]
			return "Challenge at %s - %s: %s" % [catalog.stages[catalog.challenge_stage[source.id]].name, entry.name, entry.text]
		"feat":
			var feat: Dictionary = catalog.feats[source.id]
			return "Feat - %s: %s" % [feat.name, feat.text]
		"crucible":
			var milestone: Dictionary = catalog.crucible_index.milestones[source.id]
			return "Crucible - %s: %s" % [milestone.name, milestone.text]
	return ""


## "[x] Cold Hearth: Win without a Fire spirit." ASCII only, for the web font.
static func challenge_line(entry: Dictionary, done: bool) -> String:
	return "%s %s%s: %s" % ["[x]" if done else "[ ]", entry.name, " (extreme)" if entry.get("extreme", false) else "", entry.text]


## "Recruits Cinder Mote the Flicker." for an entry that brings a spirit, else "".
static func reward_line(catalog: RefCounted, entry: Dictionary) -> String:
	var names: Array[String] = []
	for kind in entry.get("rewards", {}):
		for id in entry.rewards[kind]:
			names.append(Style.reward_text(catalog, kind, id)[0].trim_prefix("New spirit: "))
	if names.is_empty():
		return ""
	var only_spirits: bool = entry.rewards.keys() == ["spirits"]
	return ("Recruits " if only_spirits else "Rewards: ") + ", ".join(names) + "."


static func challenge_color(entry: Dictionary, done: bool) -> Color:
	if done:
		return Style.GOOD
	return TIER_COLORS.extreme if entry.get("extreme", false) else Style.TEXT
