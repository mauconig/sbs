extends CanvasLayer
## Local outfit editor. Draft changes stay on the preview until Equip is pressed.

signal opened
signal closed
signal equipped(look: Resource)

const Store := preload("res://scripts/visuals/outfit_store.gd")
const CharacterScene := preload("res://scenes/visuals/character.tscn")
const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
const INK := Color("201a30")
const MUTED := Color("aaa3bc")
const PINK := Color("fa4d9b")
const CREAM := Color("fff3dd")
const PARTS := ["shirt","shorts","socks","boots"]
const PART_NAMES := ["JERSEY","SHORTS","SOCKS","CLEATS"]
const PATTERNS := ["SOLID","STRIPES","HOOPS","SPLIT","DIAGONAL"]
const SWATCHES := ["ffffff","fff1d6","f3c448","ff903d","f5438c","c642e5","6c50da","283b70",
	"171e32","6a728f","00bbdb","5cdbbf","39b75a","cf3d50","853c57","bf9be6"]

class PatternTile extends Button:
	var pattern_index := 0
	var primary := Color.WHITE
	var secondary := Color("292135")
	func _draw() -> void:
		var rect := Rect2(11,(size.y-20)*0.5,32,20)
		draw_rect(rect,primary)
		match pattern_index:
			1:
				for index in 3:
					draw_rect(Rect2(rect.position+Vector2(index*11,0),Vector2(5,20)),secondary)
			2:
				for index in 2:
					draw_rect(Rect2(rect.position+Vector2(0,3+index*10),Vector2(32,4)),secondary)
			3:
				draw_rect(Rect2(rect.position+Vector2(16,0),Vector2(16,20)),secondary)
			4:
				draw_colored_polygon(PackedVector2Array([rect.position+Vector2(0,15),rect.position+Vector2(20,0),rect.position+Vector2(32,0),rect.position+Vector2(5,20),rect.position+Vector2(0,20)]),secondary)

var is_open := false
var draft: Resource
var preview_actor: Node3D
var selected_part := "shirt"
var save_path := Store.SAVE_PATH
var _target: Resource
var _root: Control
var _drawer: Control
var _panel: PanelContainer
var _launcher: Button
var _viewport: SubViewport
var _part_buttons: Array[Button] = []
var _pattern_buttons: Array[Button] = []
var _primary: ColorPickerButton
var _secondary: ColorPickerButton
var _name_field: LineEdit
var _number_field: LineEdit
var _ink: ColorPickerButton
var _part_title: Label
var _status: Label
var _syncing := false


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 19
	_root.theme = theme
	add_child(_root)
	_launcher = _button("SHOP   /   B",PINK)
	_launcher.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_launcher.position = Vector2(-196,102)
	_launcher.size = Vector2(168,52)
	_launcher.tooltip_text = "Customize your kit · B"
	_root.add_child(_launcher)
	_launcher.pressed.connect(func():
		if not is_open:
			get_parent().call("open_shop"))
	_build_drawer()
	_drawer.hide()
	preview_actor.process_mode = Node.PROCESS_MODE_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_viewport().size_changed.connect(_layout)
	_layout()


func _style(color: Color, border: Color = Color("4d405c"), radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _button(text_value: String, fill: Color = Color("342b44")) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal",_style(fill))
	button.add_theme_stylebox_override("hover",_style(fill.lightened(0.14),PINK))
	button.add_theme_stylebox_override("pressed",_style(Color("56405f"),PINK))
	button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),CREAM))
	button.add_theme_color_override("font_color",CREAM)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _label(text_value: String, font_size: int = 17, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	parent.add_child(box)
	return box


func _hbox(parent: Node, separation: int = 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	parent.add_child(box)
	return box


func _build_drawer() -> void:
	_drawer = Control.new()
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_drawer)
	var dim := ColorRect.new()
	dim.color = Color(0.045,0.025,0.085,0.48)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_shop())
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",_style(INK,Color("a16dc3"),0))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_drawer.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	_panel.add_child(margin)
	var layout := _vbox(margin,16)
	var header := _hbox(layout)
	var heading := _vbox(header,0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_label("SANDBOX  /  SHOP",14,PINK))
	heading.add_child(_label("THE KIT ROOM",38,CREAM))
	heading.add_child(_label("YOUR PLAYER. YOUR COLOURS.",17))
	var exit_button := _button("×")
	exit_button.custom_minimum_size = Vector2(42,42)
	exit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	exit_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	exit_button.text = "X"
	exit_button.pressed.connect(close_shop)
	header.add_child(exit_button)
	layout.add_child(HSeparator.new())
	var columns := _hbox(layout,14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var category_column := _vbox(columns,8)
	category_column.custom_minimum_size.x = 92
	category_column.add_child(_label("CATEGORIES",12,PINK))
	for entry in [["FACE",false],["HAIR",false],["KIT",true],["EXTRAS",false],["BADGE",false]]:
		var category: String = entry[0]
		var available: bool = entry[1]
		var button := _button(category if available else category+"\nSOON",PINK if available else Color("342b44"))
		button.custom_minimum_size = Vector2(92,55)
		button.add_theme_font_size_override("font_size",15)
		if available:
			button.tooltip_text = "Customize your kit"
		else:
			button.disabled = true
			button.add_theme_stylebox_override("normal",_style(Color("342b44")))
			button.add_theme_stylebox_override("disabled",_style(Color("342b44"),Color("4d405c")))
			button.add_theme_color_override("font_disabled_color",MUTED)
		category_column.add_child(button)
	var preview_column := _vbox(columns,12)
	preview_column.custom_minimum_size.x = 270
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.add_child(_label("360°  /  LIVE PREVIEW",14,PINK))
	_build_preview(preview_column)
	var views := _hbox(preview_column,6)
	for entry in [["FRONT",PI],["BACK",0.0],["TURN",PI*0.5]]:
		var button := _button(entry[0])
		var angle: float = entry[1]
		button.pressed.connect(func(): preview_actor.rotation.y = angle)
		views.add_child(button)
	var rotate_hint := _label("DRAG THE PLAYER TO ROTATE",13)
	rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(rotate_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.x = 366
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var editor := _vbox(scroll,8)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(_label("KIT  /  JERSEY",14,PINK))
	editor.add_child(_label("YOUR COLORS",22,CREAM))
	var tabs := _hbox(editor,4)
	for index in PARTS.size():
		var button := _button(PART_NAMES[index])
		button.add_theme_font_size_override("font_size",16)
		button.pressed.connect(select_part.bind(PARTS[index]))
		tabs.add_child(button)
		_part_buttons.append(button)
	_part_title = _label("JERSEY",24,CREAM)
	editor.add_child(_part_title)
	var colours := _hbox(editor,12)
	_primary = _colour_picker(colours,"PRIMARY",_set_primary)
	_secondary = _colour_picker(colours,"ACCENT",_set_secondary)
	editor.add_child(_label("QUICK PRIMARY COLOURS",13))
	var swatches := GridContainer.new()
	swatches.columns = 8
	swatches.add_theme_constant_override("h_separation",8)
	swatches.add_theme_constant_override("v_separation",8)
	editor.add_child(swatches)
	for hex in SWATCHES:
		var button := _button("")
		button.custom_minimum_size = Vector2(34,28)
		button.add_theme_stylebox_override("normal",_style(Color(hex),Color("6a5c77"),5))
		button.add_theme_stylebox_override("hover",_style(Color(hex),CREAM,5))
		button.tooltip_text = "#"+hex.to_upper()
		button.pressed.connect(_set_primary.bind(Color(hex)))
		swatches.add_child(button)
	editor.add_child(_label("PATTERN",13))
	var patterns := GridContainer.new()
	patterns.columns = 2
	patterns.add_theme_constant_override("h_separation",8)
	patterns.add_theme_constant_override("v_separation",7)
	editor.add_child(patterns)
	for index in PATTERNS.size():
		var button := PatternTile.new()
		button.pattern_index = index
		button.text = "        "+PATTERNS[index]
		button.custom_minimum_size = Vector2(166,34)
		button.add_theme_font_size_override("font_size",16)
		button.add_theme_stylebox_override("normal",_style(Color("342b44")))
		button.add_theme_stylebox_override("hover",_style(Color("493951"),PINK))
		button.add_theme_color_override("font_color",CREAM)
		button.pressed.connect(_set_pattern.bind(index))
		patterns.add_child(button)
		_pattern_buttons.append(button)
	editor.add_child(_label("QUICK KITS",13))
	var presets := _hbox(editor,6)
	for preset in ["HOME","AWAY","NEON"]:
		var button := _button(preset)
		button.pressed.connect(_apply_preset.bind(preset))
		presets.add_child(button)
	editor.add_child(HSeparator.new())
	editor.add_child(_label("PLAYER ID",14,PINK))
	var identity := _hbox(editor,12)
	_name_field = _field(identity,"SHIRT NAME",12,226)
	_number_field = _field(identity,"NUMBER",2,92)
	_name_field.text_changed.connect(_name_changed)
	_number_field.text_changed.connect(_number_changed)
	_ink = _colour_picker(editor,"NAME & NUMBER INK",func(color: Color):
		if not _syncing:
			draft.set("print_color",color))
	_status = _label("PREVIEW CHANGES · EQUIP TO SAVE",14)
	layout.add_child(_status)
	var equip := _button("EQUIP & RETURN   →",PINK)
	equip.custom_minimum_size.y = 52
	equip.add_theme_font_size_override("font_size",24)
	equip.pressed.connect(equip_outfit)
	layout.add_child(equip)
	layout.add_child(_label("SAVED ON THIS DEVICE  ·  SANDBOX + 1v1",13))


func _build_preview(parent: Control) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(294,390)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(294,420)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	container.add_child(_viewport)
	var stage := Node3D.new()
	_viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("30273e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	world.environment = environment
	stage.add_child(world)
	var pedestal := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.64
	cylinder.bottom_radius = 0.73
	cylinder.height = 0.09
	pedestal.mesh = cylinder
	pedestal.position.y = -0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("705186")
	pedestal.material_override = material
	stage.add_child(pedestal)
	preview_actor = CharacterScene.instantiate() as Node3D
	draft = Store.BASE_LOOK.duplicate() as Resource
	preview_actor.set("look",draft)
	preview_actor.set("animation",0)
	preview_actor.rotation.y = -0.25
	stage.add_child(preview_actor)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.24,3.4)
	camera.fov = 36
	stage.add_child(camera)
	camera.look_at(Vector3(0,0.9,0))
	camera.current = true
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			preview_actor.rotation.y += event.relative.x*0.012)


func _colour_picker(parent: Node, caption: String, callback: Callable) -> ColorPickerButton:
	var box := _vbox(parent,4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label(caption,13))
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(134,40)
	picker.edit_alpha = false
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_stylebox_override("normal",_style(Color("342b44")))
	picker.color_changed.connect(callback)
	box.add_child(picker)
	return picker


func _field(parent: Node, caption: String, max_length: int, width: float) -> LineEdit:
	var box := _vbox(parent,4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label(caption,13))
	var field := LineEdit.new()
	field.max_length = max_length
	field.custom_minimum_size = Vector2(width,42)
	field.add_theme_stylebox_override("normal",_style(Color("342b44")))
	field.add_theme_stylebox_override("focus",_style(Color("342b44"),PINK))
	field.add_theme_font_size_override("font_size",22)
	field.add_theme_color_override("font_color",CREAM)
	box.add_child(field)
	return field


func _layout() -> void:
	_panel.offset_left = -minf(840,get_viewport().get_visible_rect().size.x)
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0


func open_for(look: Resource) -> void:
	if is_open:
		return
	_target = look
	Store.copy_into(look,draft)
	_syncing = true
	_name_field.text = draft.get("display_name")
	_number_field.text = draft.get("number")
	_ink.color = draft.get("print_color")
	_syncing = false
	select_part("shirt")
	_status.text = "PREVIEW CHANGES · EQUIP TO SAVE"
	preview_actor.rotation.y = -0.25
	preview_actor.process_mode = Node.PROCESS_MODE_INHERIT
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	is_open = true
	_drawer.show()
	_launcher.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()


func close_shop() -> void:
	if not is_open:
		return
	is_open = false
	for picker in [_primary,_secondary,_ink]:
		picker.get_popup().hide()
	_drawer.hide()
	_launcher.show()
	preview_actor.process_mode = Node.PROCESS_MODE_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func select_part(part: String) -> void:
	selected_part = part
	_syncing = true
	_primary.color = draft.get(part+"_color")
	_secondary.color = draft.get(part+"_secondary_color")
	_part_title.text = PART_NAMES[PARTS.find(part)]
	for index in PARTS.size():
		_part_buttons[index].add_theme_stylebox_override("normal",_style(PINK if PARTS[index] == part else Color("342b44")))
	for index in _pattern_buttons.size():
		var button := _pattern_buttons[index] as PatternTile
		button.primary = _primary.color
		button.secondary = _secondary.color
		button.add_theme_stylebox_override("normal",_style(Color("57405d") if index == int(draft.get(part+"_pattern")) else Color("342b44"),PINK if index == int(draft.get(part+"_pattern")) else Color("4d405c")))
		button.queue_redraw()
	_syncing = false


func _set_primary(color: Color) -> void:
	if not _syncing:
		draft.set(selected_part+"_color",color)
		select_part(selected_part)


func _set_secondary(color: Color) -> void:
	if not _syncing:
		draft.set(selected_part+"_secondary_color",color)
		select_part(selected_part)


func _set_pattern(index: int) -> void:
	draft.set(selected_part+"_pattern",index)
	select_part(selected_part)


func _name_changed(value: String) -> void:
	if not _syncing:
		draft.set("display_name",value.to_upper())


func _number_changed(value: String) -> void:
	if _syncing:
		return
	var digits := ""
	for character in value:
		if character in "0123456789":
			digits += character
	_number_field.text = digits
	_number_field.caret_column = digits.length()
	draft.set("number",digits)


func _apply_preset(preset: String) -> void:
	var colours := [Color("f5438c"),Color("fff1d6"),Color("283b70"),Color.WHITE,Color("f5438c")]
	if preset == "AWAY":
		colours = [Color("00bbdb"),Color("283b70"),Color("283b70"),Color("00bbdb"),Color("fff1d6")]
	elif preset == "NEON":
		colours = [Color("cfef49"),Color("171e32"),Color("171e32"),Color("cfef49"),Color("c642e5")]
	draft.set("shirt_color",colours[0])
	draft.set("shirt_secondary_color",colours[1])
	draft.set("shirt_pattern",1 if preset == "HOME" else 4 if preset == "NEON" else 3)
	draft.set("shorts_color",colours[2])
	draft.set("shorts_pattern",0)
	draft.set("socks_color",colours[3])
	draft.set("socks_pattern",2)
	draft.set("socks_secondary_color",colours[0])
	draft.set("boots_color",colours[4])
	draft.set("boots_pattern",0)
	draft.set("print_color",Color("171e32") if preset != "AWAY" else Color.WHITE)
	_ink.color = draft.get("print_color")
	select_part(selected_part)


func equip_outfit() -> void:
	if Store.save_look(draft,save_path) != OK:
		_status.text = "COULD NOT SAVE THE OUTFIT. TRY AGAIN."
		return
	Store.copy_into(draft,_target)
	equipped.emit(_target)
	close_shop()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if event.keycode == KEY_B and not focus is LineEdit:
		if is_open:
			close_shop()
		else:
			get_parent().call("open_shop")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and is_open:
		close_shop()
		get_viewport().set_input_as_handled()
