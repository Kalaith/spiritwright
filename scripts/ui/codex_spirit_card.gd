extends PanelContainer
## One spirit in the Codex: how it looks, who it is, whether it has joined
## and, if not, exactly how to bring it in. Tapping it opens its Journal page.

signal opened(spirit_id: String)

const Style = preload("res://scripts/ui/style.gd")
const SpiritPortrait = preload("res://scripts/ui/spirit_portrait.gd")
const CodexText = preload("res://scripts/ui/codex_text.gd")

var catalog: RefCounted
var progression: RefCounted
var spirit_id: String = ""
## Challenges.spirit_sources entry: {tier, kind, id}.
var source: Dictionary = {}
## Where a press began, so a drag that scrolls the Codex does not open a page.
var _press_at: Vector2 = Vector2.INF


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
	var element_color: Color = catalog.element_color(spirit.element)
	top.add_child(SpiritPortrait.make(spirit_id, 96, element_color, owned))
	var info := Style.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
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

	column.add_child(Style.label("Tap for its journal", 11, Style.MUTED))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Open %s's journal page." % spirit.name


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_at = event.position
	elif _press_at.distance_to(event.position) < 12.0:
		_press_at = Vector2.INF
		opened.emit(spirit_id)
