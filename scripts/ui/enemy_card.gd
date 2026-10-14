extends RefCounted
## One enemy golem for a scouting report: its body, the spirit inside, level,
## element, build, cell, reaction, trait and sigil. Shared by the campaign map and the Crucible.

const Style = preload("res://scripts/ui/style.gd")
const GolemArt = preload("res://scripts/ui/golem_art.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")
const SpiritPortrait = preload("res://scripts/ui/spirit_portrait.gd")


## `golem` is a resolved golem (Builds.resolve).
static func make(catalog: RefCounted, golem: Dictionary) -> Control:
	var row := Style.hbox(8)
	var preview := GolemPreview.new()
	preview.custom_minimum_size = Vector2(84, 92)
	preview.animated = true
	preview.setup(GolemArt.look_for(catalog, golem, Style.ENEMY), 0.62, -1.0)
	row.add_child(preview)
	var portrait: Control = SpiritPortrait.make(golem.spirit, 56, catalog.element_color(golem.element))
	portrait.flip = true
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var info := Style.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(Style.label("%s  Lv %d  %s" % [golem.name, golem.level, catalog.element_label(golem.element)], 15, Style.TEXT))
	var build: String = "%s %s / %s / %s. %s" % [catalog.part("materials", golem.material).name,
		catalog.part("frames", golem.frame).name.trim_suffix(" Frame"),
		catalog.part("arms", golem.arms).name, catalog.part("legs", golem.legs).name, Style.cell_name(golem.row, golem.lane)]
	info.add_child(Style.wrapped(build, 13))
	if not golem.reaction.is_empty():
		info.add_child(Style.wrapped("%s: %s" % [golem.reaction.name, golem.reaction.text], 12, catalog.element_color(golem.element)))
	var trait_def: Dictionary = catalog.spirit(golem.spirit)["trait"]
	info.add_child(Style.wrapped("%s: %s" % [trait_def.name, trait_def.text], 12))
	if not String(golem.sigil).is_empty():
		var sigil: Dictionary = catalog.part("sigils", golem.sigil)
		info.add_child(Style.wrapped("%s: %s" % [sigil.name, sigil.text], 12, Style.GOLD.darkened(0.15)))
	return row
