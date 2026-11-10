extends SubViewport
## A small dynamic name/number texture. UV2 keeps the print on the skinned back.

const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
var _player_name: Label
var _number: Label


func _ready() -> void:
	size = Vector2i(512,512)
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	_player_name = _label(Rect2(12,20,488,84),64)
	_number = _label(Rect2(8,96,496,394),350)


func _label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color.WHITE)
	add_child(label)
	return label


func set_identity(player_name: String, shirt_number: String) -> void:
	var clean_name := player_name.strip_edges().left(12).to_upper()
	if _player_name.text == clean_name and _number.text == shirt_number:
		return
	_player_name.text = clean_name
	_number.text = shirt_number
	render_target_update_mode = SubViewport.UPDATE_ONCE
