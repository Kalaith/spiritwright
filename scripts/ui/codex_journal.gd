extends HBoxContainer
## One spirit's Journal page in the Codex: its portrait, who it is, its stats
## from Lv 1 and how they grow, its trait and awakening, and the bodies and
## materials it favours. A spirit not yet found shows only its silhouette and
## how to bring it in; the rest is written once it joins.

const Style = preload("res://scripts/ui/style.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Builds = preload("res://scripts/core/builds.gd")
const CodexText = preload("res://scripts/ui/codex_text.gd")
const SpiritPortrait = preload("res://scripts/ui/spirit_portrait.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")
## Body parts a temperament's tags are matched against, with their headings.
const TAGGED_KINDS: Dictionary = {"frames": "Frames", "arms": "Arms", "legs": "Legs"}

var catalog: RefCounted
var progression: RefCounted
var spirit_id: String = ""
## Challenges.spirit_sources entry: {tier, kind, id}.
var source: Dictionary = {}
var _spirit: Dictionary = {}
var _owned: bool = false
var _color: Color = Style.TEXT


func _ready() -> void:
	_spirit = catalog.spirit(spirit_id)
	_owned = progression.spirits.has(spirit_id)
	_color = catalog.element_color(_spirit.element)
	add_theme_constant_override("separation", 18)
	add_child(_identity())
	var pages := Style.vbox(8)
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(pages)
	if not _owned:
		pages.add_child(_heading("Not yet found"))
		pages.add_child(Style.wrapped(CodexText.source_text(catalog, source), 15, Style.TEXT))
		pages.add_child(Style.wrapped("The rest of this page is written once it joins you: its stats, its trait and awakening, and the bodies it favours.", 14))
		return
	pages.add_child(Style.wrapped(String(_spirit.description), 16, Style.TEXT))
	pages.add_child(_heading("Stats"))
	pages.add_child(_stat_table())
	pages.add_child(_heading("Trait and awakening"))
	_traits(pages)
	pages.add_child(_heading("Favoured build"))
	_favoured(pages)


## The left column: portrait, name, element and temperament, level, and how it joins.
func _identity() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, _color.darkened(0.4) if _owned else Style.LINE, 12, 12))
	panel.custom_minimum_size.x = 320
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := Style.vbox(4)
	panel.add_child(column)
	column.add_child(SpiritPortrait.make(spirit_id, 290, _color, _owned))
	column.add_child(Style.label(_spirit.name, 26, _color if _owned else Style.MUTED))
	column.add_child(Style.wrapped(String(_spirit.title), 15))
	var temperament: Dictionary = catalog.temperaments[_spirit.temperament]
	column.add_child(Style.label("%s  -  %s" % [catalog.element_label(_spirit.element), temperament.label], 15,
		_color.lerp(Style.TEXT, 0.4) if _owned else Style.MUTED))
	column.add_child(Style.label(CodexText.TIER_LABELS[source.tier], 12, CodexText.TIER_COLORS[source.tier]))
	if not _owned:
		return panel
	var entry: Dictionary = progression.spirits[spirit_id]
	column.add_child(Style.label("Lv %d  (%d/%d XP)" % [int(entry.level), int(entry.xp), progression.xp_to_next(int(entry.level))],
		15, Style.GOOD))
	column.add_child(Style.wrapped(CodexText.source_text(catalog, source), 12))
	var loadout: Dictionary = _golem()
	if loadout.is_empty():
		column.add_child(Style.label("Resting: no golem holds it.", 13, Style.MUTED))
		return panel
	column.add_child(Style.label("Its golem now", 14, Style.GOLD))
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(0, 120)
	preview.backdrop = Color("16151f")
	preview.setup(GolemArt.look_for(catalog, loadout, Style.ALLY), 0.8)
	column.add_child(preview)
	column.add_child(Style.wrapped("%s %s / %s / %s. %s" % [catalog.part("materials", loadout.material).name,
		catalog.part("frames", loadout.frame).name.trim_suffix(" Frame"), catalog.part("arms", loadout.arms).name,
		catalog.part("legs", loadout.legs).name, Style.cell_name(loadout.row, int(loadout.lane))], 12))
	return panel


func _golem() -> Dictionary:
	for loadout in progression.team:
		if loadout.spirit == spirit_id:
			return loadout
	return {}


func _heading(text: String) -> Label:
	var heading := Style.label(text, 19, Style.GOLD)
	heading.custom_minimum_size.y = 30
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return heading


## Lv 1, its growth rates, where it stands now and where it will at the awakening level.
func _stat_table() -> Control:
	var level: int = int(progression.spirits[spirit_id].level)
	var awaken: int = int(catalog.num("awaken_level"))
	var rows: Array = [["At Lv 1", Builds.spirit_stats(catalog, _spirit, 1), ""],
		["Growth", _spirit.growth, "%"],
		["Now, Lv %d" % level, Builds.spirit_stats(catalog, _spirit, level), ""]]
	if level < awaken:
		rows.append(["At Lv %d" % awaken, Builds.spirit_stats(catalog, _spirit, awaken), ""])
	var grid := GridContainer.new()
	grid.columns = Catalog.STATS.size() + 1
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 3)
	grid.add_child(Style.label("", 14))
	for stat in Catalog.STATS:
		grid.add_child(Style.label(Style.STAT_LABELS[stat], 14, Style.MUTED))
	for row in rows:
		grid.add_child(Style.label(row[0], 14, Style.MUTED))
		for stat in Catalog.STATS:
			grid.add_child(Style.label("%d%s" % [int(row[1][stat]), row[2]], 15, Style.TEXT if row[2].is_empty() else _strength(int(row[1][stat]))))
	var box := Style.vbox(4)
	box.add_child(grid)
	box.add_child(Style.wrapped("Growth is smoothed, not rolled: every level adds the rate to a running total and each 100 is +1 (+%d for HP). The body it wears adds the rest." % int(catalog.num("growth.hp_per_point")), 12))
	return box


## Growth rates shaded so the spirit's strengths stand out.
func _strength(rate: int) -> Color:
	if rate >= 55:
		return Style.GOOD
	if rate <= 25:
		return Style.MUTED
	return Style.TEXT


func _traits(pages: VBoxContainer) -> void:
	var trait_def: Dictionary = _spirit["trait"]
	pages.add_child(Style.wrapped("%s: %s" % [trait_def.name, trait_def.text], 15, Style.TEXT))
	var awakening: Dictionary = _spirit.awakening
	var awaken: int = int(catalog.num("awaken_level"))
	if Builds.awakened(catalog, _spirit, int(progression.spirits[spirit_id].level)):
		pages.add_child(Style.wrapped("Awakened - %s: %s" % [awakening.name, awakening.text], 15, Style.GOLD))
	else:
		pages.add_child(Style.wrapped("Awakens at Lv %d - %s: %s" % [awaken, awakening.name, awakening.text], 15))


## What its temperament, its trait and its element favour. Favour only ever
## adds: any spirit can wear any body.
func _favoured(pages: VBoxContainer) -> void:
	var temperament: Dictionary = catalog.temperaments[_spirit.temperament]
	pages.add_child(Style.wrapped("%s: %s  (%s)" % [temperament.label, temperament.text, Style.stat_line(temperament.bonus)], 15, Style.TEXT))
	for tag in temperament.get("prefers_tags", []):
		for kind in TAGGED_KINDS:
			var names: Array[String] = []
			for id in catalog.part_order[kind]:
				if tag in catalog.part(kind, id).get("tags", []):
					names.append(_part_name(kind, id))
			if not names.is_empty():
				pages.add_child(Style.wrapped("    %s (%s): %s" % [TAGGED_KINDS[kind], tag, ", ".join(names)], 14))
	var trait_def: Dictionary = _spirit["trait"]
	var by_frame: Dictionary = trait_def.get("by_frame", {})
	for frame_id in by_frame:
		pages.add_child(Style.wrapped("%s favours %s: %s" % [trait_def.name, _part_name("frames", frame_id),
			Style.stat_line(by_frame[frame_id])], 14, Style.TEXT))
	if not trait_def.get("front_row", {}).is_empty():
		pages.add_child(Style.wrapped("%s favours the front row: %s" % [trait_def.name, Style.stat_line(trait_def.front_row)], 14, Style.TEXT))
	_materials(pages)
	pages.add_child(Style.wrapped("Parts marked (not yet found) still wait somewhere on the map.", 12))


## Every material that reacts with its element; unfound ones stay unnamed.
func _materials(pages: VBoxContainer) -> void:
	var hidden: int = 0
	var lines: Array[String] = []
	for material_id in catalog.part_order.materials:
		var reaction: Dictionary = catalog.reaction(material_id, _spirit.element)
		if reaction.is_empty():
			continue
		if material_id in progression.unlocks.materials:
			lines.append("    %s - %s: %s" % [catalog.part("materials", material_id).name, reaction.name, reaction.text])
		else:
			hidden += 1
	if lines.is_empty() and hidden == 0:
		return
	pages.add_child(Style.wrapped("Materials that answer %s:" % catalog.element_label(_spirit.element), 15, _color.lerp(Style.TEXT, 0.35)))
	for line in lines:
		pages.add_child(Style.wrapped(line, 14))
	if hidden > 0:
		pages.add_child(Style.wrapped("    %d more not yet found." % hidden, 14))


func _part_name(kind: String, id: String) -> String:
	var name: String = String(catalog.part(kind, id).name).trim_suffix(" Frame").trim_suffix(" Arms").trim_suffix(" Legs")
	return name if id in progression.unlocks[kind] else name + " (not yet found)"
