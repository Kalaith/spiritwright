extends RefCounted
## Shared palette, theme and small widget helpers. UI text is ASCII only: the
## web build's default font has no arrows, bullets or multiplication signs.

const BG := Color("12111a")
const PANEL := Color("1d1b28")
const PANEL_LIGHT := Color("2a2738")
const LINE := Color("3b3750")
const TEXT := Color("ece6f5")
const MUTED := Color("a49cb8")
const GOLD := Color("e8c170")
const GOOD := Color("7fd38b")
const BAD := Color("ef6f6c")
const ALLY := Color("4cc9c0")
const ENEMY := Color("e0605a")
const STAT_LABELS: Dictionary = {"hp": "HP", "str": "STR", "mag": "MAG", "spd": "SPD", "def": "DEF", "res": "RES"}
const STATUS_COLORS: Dictionary = {
	"burn": Color("ff7a3d"), "soaked": Color("4fb6ff"), "ward": Color("e8e2ff"),
	"stun": Color("f2d34f"), "taunt": Color("e0605a"), "regen": Color("7fd35a"), "haste": Color("9fe8c8"),
	"weaken": Color("b68ad8"), "expose": Color("ff9fb0"), "slow": Color("8fc8ff"),
}
const STATUS_LABELS: Dictionary = {
	"burn": "BURN", "soaked": "SOAK", "ward": "WARD", "stun": "STUN", "taunt": "TAUNT", "regen": "REGEN",
	"weaken": "WEAK", "expose": "EXPOSED",
}


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, box(PANEL_LIGHT, LINE, 6, 8))
		theme.set_stylebox("hover", kind, box(Color("383449"), GOLD.darkened(0.3), 6, 8))
		theme.set_stylebox("pressed", kind, box(Color("443e58"), GOLD, 6, 8))
		theme.set_stylebox("disabled", kind, box(Color("1f1d29"), Color("2c293a"), 6, 8))
		theme.set_stylebox("focus", kind, box(Color(0, 0, 0, 0), GOLD.darkened(0.1), 6, 8))
		theme.set_color("font_color", kind, TEXT)
		theme.set_color("font_hover_color", kind, Color.WHITE)
		theme.set_color("font_pressed_color", kind, GOLD)
		theme.set_color("font_disabled_color", kind, Color("6d6680"))
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 10, 12))
	theme.set_stylebox("panel", "PopupMenu", box(PANEL, LINE, 6, 6))
	theme.set_stylebox("panel", "TooltipPanel", box(Color("0d0c13"), GOLD.darkened(0.4), 6, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("hover", "PopupMenu", box(PANEL_LIGHT, PANEL_LIGHT, 4, 4))
	theme.set_stylebox("background", "ProgressBar", box(Color("0d0c13"), LINE, 4, 0))
	theme.set_stylebox("fill", "ProgressBar", box(GOLD.darkened(0.2), GOLD.darkened(0.2), 4, 0))
	return theme


static func box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	return style


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func wrapped(text: String, size: int = 14, color: Color = MUTED) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 40
	return node


static func button(text: String, callback: Callable, size: int = 16) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.pressed.connect(callback)
	return node


static func panel(margin: int = 12) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(PANEL, LINE, 10, margin))
	return node


static func vbox(separation: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


## "Front, lane 2": lanes count from the top of the battlefield.
static func cell_name(row: String, lane: int) -> String:
	return "%s, lane %d" % [row.capitalize(), lane + 1]


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


static func stat_line(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat in STAT_LABELS:
		if stats.has(stat) and int(stats[stat]) != 0:
			parts.append("%s %s%d" % [STAT_LABELS[stat], "+" if int(stats[stat]) > 0 else "", int(stats[stat])])
	return ", ".join(parts)


## A soft round light: full `color` at the centre, nearly half by half the
## radius, nothing at the rim. Smooth gradients, so no rings show.
static func radial(ci: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	var mid := Color(color, color.a * 0.45)
	var clear := Color(color, 0.0)
	for i in range(16):
		var a := Vector2(cos(TAU * i / 16.0), sin(TAU * i / 16.0))
		var b := Vector2(cos(TAU * (i + 1) / 16.0), sin(TAU * (i + 1) / 16.0))
		ci.draw_polygon(PackedVector2Array([centre, centre + a * radius * 0.5, centre + b * radius * 0.5]),
			PackedColorArray([color, mid, mid]))
		ci.draw_polygon(PackedVector2Array([centre + a * radius * 0.5, centre + a * radius, centre + b * radius,
			centre + b * radius * 0.5]), PackedColorArray([mid, clear, clear, mid]))


## Fills a full-rect screen background so each screen owns its backdrop.
static func backdrop(parent: Control, color: Color = BG) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	# A soft pool of light high in the middle, falling off to dark corners.
	var light := GradientTexture2D.new()
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.3)
	light.fill_to = Vector2(1.15, 1.1)
	light.gradient = Gradient.new()
	light.gradient.set_color(0, Color(color.lightened(0.07), 1.0))
	light.gradient.set_color(1, Color(color.darkened(0.45), 1.0))
	var glow := TextureRect.new()
	glow.texture = light
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)


## "Spirit: Sefa the Zephra" / "Arms: Spirit Cannon" plus what it does.
static func reward_text(catalog: RefCounted, kind: String, id: String) -> Array:
	if kind == "cores":
		var count: int = int(id)
		return ["Golem core" if count == 1 else "%d golem cores" % count,
			"Take it to the Golem Laboratory to build a new golem for a resting spirit."]
	if kind == "spirits":
		var spirit: Dictionary = catalog.spirit(id)
		return ["New spirit: %s %s" % [spirit.name, spirit.get("title", "")], String(spirit.get("description", ""))]
	if kind == "titles":
		return ["Title: %s" % catalog.crucible_index.titles[id].name, "Choose it in the Crucible's milestones to wear it on the map."]
	if kind == "finishes":
		var finish: Dictionary = catalog.crucible_index.finishes[id]
		return ["Vessel finish: %s" % finish.name, "%s Any golem can wear it: pick it on the golem's card in the laboratory." % finish.text]
	var part: Dictionary = catalog.part(kind, id)
	var kinds: Dictionary = {"frames": "Frame", "arms": "Arms", "legs": "Legs", "sigils": "Sigil", "materials": "Material"}
	var text: String = material_text(catalog, part) if kind == "materials" else String(part.get("text", ""))
	return ["%s: %s" % [kinds.get(kind, kind), part.name], text]


## A material's description, stats and every element it reacts with.
static func material_text(catalog: RefCounted, material: Dictionary) -> String:
	var lines: Array[String] = [String(material.text) + " " + stat_line(material.get("stats", {}))]
	var reactions: Dictionary = material.get("reactions", {})
	for element in reactions:
		lines.append("With %s: %s - %s" % [catalog.element_label(element), reactions[element].name, reactions[element].text])
	return "
".join(lines)
