extends PanelContainer
## One spirit in the Codex: how it looks, who it is, whether it has joined
## and, if not, exactly how to bring it in.

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")
const CodexText = preload("res://scripts/ui/codex_text.gd")

var catalog: RefCounted
var progression: RefCounted
var spirit_id: String = ""
## Challenges.spirit_sources entry: {tier, kind, id}.
var source: Dictionary = {}


func _ready() -> void:
	var owned: bool = progression.spirits.has(spirit_id)
	var spirit: Dictionary = catalog.spirit(spirit_id)
	var tier_color: Color = CodexText.TIER_COLORS[source.tier]
	add_theme_stylebox_override("panel", Style.box(Style.PANEL if owned else Color(Style.PANEL, 0.55),
		tier_color.darkened(0.35) if owned else Style.LINE, 10, 10))
	var column := Style.vbox(4)
	add_child(column)
	var top := Style.hbox(8)
	column.add_child(top)
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(84, 96)
	preview.alpha = 1.0 if owned else 0.3
	preview.setup(GolemArt.look_for(catalog, _look_loadout(), Style.ALLY if owned else Style.MUTED), 0.6)
	top.add_child(preview)
	var info := Style.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var element_color: Color = catalog.element_color(spirit.element)
	info.add_child(Style.label(spirit.name, 17, element_color if owned else Style.MUTED))
	info.add_child(Style.wrapped(String(spirit.title), 12))
	info.add_child(Style.label("%s - %s" % [catalog.element_label(spirit.element), catalog.temperaments[spirit.temperament].label], 13,
		element_color.lerp(Style.TEXT, 0.4) if owned else Style.MUTED))
	if owned:
		info.add_child(Style.label("Lv %d" % int(progression.spirits[spirit_id].level), 14, Style.GOOD))
	else:
		info.add_child(Style.label("Not yet found", 13, Style.MUTED))
	column.add_child(Style.label(CodexText.TIER_LABELS[source.tier], 12, tier_color))
	if owned:
		column.add_child(Style.wrapped("%s. Awakens: %s." % [spirit["trait"].name, spirit.awakening.name], 12, Style.TEXT))
		column.add_child(Style.wrapped(String(spirit.description), 12))
	else:
		column.add_child(Style.wrapped(CodexText.source_text(catalog, source), 12, Style.TEXT))


## The body the card shows: the spirit's own golem if it has one, else how it
## stands in the wild, else a plain stone bulwark.
func _look_loadout() -> Dictionary:
	for loadout in progression.team:
		if loadout.spirit == spirit_id:
			return loadout
	for stage in catalog.stages.values():
		for enemy in stage.enemies:
			if enemy.spirit == spirit_id:
				return enemy
	return {"spirit": spirit_id, "frame": "bulwark", "arms": "shield", "legs": "pillar", "material": "stone"}
