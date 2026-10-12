extends Control
## Title: continue, start fresh (asks first when a save would be lost), and a
## short primer on what the player is doing.

signal continue_requested
signal new_game_requested

const Style = preload("res://scripts/ui/style.gd")
const GolemPreview = preload("res://scripts/ui/golem_preview.gd")

var has_save: bool = false
var notice: String = ""
var _confirm: HBoxContainer
var _new_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Style.backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := Style.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 620
	center.add_child(column)
	var golems := Style.hbox(0)
	golems.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(golems)
	for look in [
		{"frame": "strider", "arms": "hammer", "legs": "spider", "element_color": Color("ff7a3d"), "glyph": "F", "team_color": Style.ALLY},
		{"frame": "bulwark", "arms": "shield", "legs": "pillar", "element_color": Color("4fb6ff"), "glyph": "W", "team_color": Style.ALLY},
		{"frame": "conduit", "arms": "cannon", "legs": "pillar", "element_color": Color("9fe8c8"), "glyph": "A", "team_color": Style.ALLY},
	]:
		var preview := GolemPreview.new()
		preview.custom_minimum_size = Vector2(170, 170)
		preview.setup(look, 1.15)
		golems.add_child(preview)
	var title := Style.label("SPIRITWRIGHT", 54, Style.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var pitch := Style.wrapped("Collect spirits. Build them stone vessels. Arrange your team and watch the battle play out on its own: the fight is decided in the workshop.", 17, Style.MUTED)
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(pitch)
	var buttons := Style.vbox(10)
	buttons.custom_minimum_size.x = 320
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(buttons)
	if has_save:
		var resume := Style.button("Continue", func(): continue_requested.emit(), 22)
		buttons.add_child(resume)
		resume.call_deferred("grab_focus")
	_new_button = Style.button("New Game", _on_new_game, 18 if has_save else 22)
	buttons.add_child(_new_button)
	if not has_save:
		_new_button.call_deferred("grab_focus")
	_confirm = Style.hbox(10)
	_confirm.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.add_child(Style.label("Erase your workshop?", 15, Style.BAD))
	_confirm.add_child(Style.button("Erase and start", func(): new_game_requested.emit(), 15))
	_confirm.add_child(Style.button("Keep it", func(): _confirm.hide(), 15))
	_confirm.hide()
	column.add_child(_confirm)
	if not notice.is_empty():
		var note := Style.wrapped(notice, 14, Style.GOLD)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(note)
	var hint := Style.label("Mouse or touch to play. Esc goes back.", 13, Style.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _on_new_game() -> void:
	if has_save:
		_confirm.show()
	else:
		new_game_requested.emit()
