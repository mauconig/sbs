extends Control
## Original illustrated scoreboard and energy strip, drawn at a 1600x900 canvas.

const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
var character_name := "PIP"
var animation_name := "RUN"
var paused := false
var energy := 0.88
var _energy_texture: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0,Color("f63397"))
	gradient.set_color(1,Color("ffb923"))
	_energy_texture = GradientTexture2D.new()
	_energy_texture.gradient = gradient
	_energy_texture.width = 512
	_energy_texture.height = 8


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var factor := view.y/900.0
	var width := view.x/factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var ink := Color("292135")
	# Layered extrusion edges echo a chunky arcade cabinet.
	_panel(Vector2(25,23),Vector2(146,78),Color("463752"),Color("9981c5"),ink)
	_text("1:37",Vector2(48,80),55,Color("fff7df"))
	_panel(Vector2(181,23),Vector2(87,78),Color("fff4d9"),Color("00b8e9"),ink)
	_text("0",Vector2(212,81),58,Color("00b9ea"))
	_panel(Vector2(278,23),Vector2(87,78),Color("fff4d9"),Color("ef308e"),ink)
	_text("0",Vector2(309,81),58,Color("ee348f"))
	_text("THE LAVENDER DOME",Vector2(26,144),16,Color("fff5e4"),2)
	# Small brand plate leaves the arena and cast as the visual focus.
	_text("MEGA BATTLE",Vector2(width-188,40),23,Color("fff7e6"),3)
	_text("F O O T B A L L",Vector2(width-188,61),16,Color("e4caed"),2)
	var center := Vector2(width*0.5,824)
	var shadow := PackedVector2Array([center+Vector2(-157,7),center+Vector2(144,7),center+Vector2(154,-22),center+Vector2(-147,-22)])
	draw_colored_polygon(shadow,ink)
	var outer := PackedVector2Array([center+Vector2(-160,2),center+Vector2(140,2),center+Vector2(150,-27),center+Vector2(-150,-27)])
	draw_colored_polygon(outer,Color("fff8e4"))
	draw_texture_rect(_energy_texture,Rect2(center+Vector2(-131,-23),Vector2(267*energy,21)),false)
	draw_line(center+Vector2(8,-25),center+Vector2(0,0),Color("fff8e4"),3,true)
	var lightning := PackedVector2Array([Vector2(-145,-24),Vector2(-151,-10),Vector2(-145,-10),Vector2(-149,-1),Vector2(-136,-16),Vector2(-143,-16)])
	for index in lightning.size():
		lightning[index] += center
	draw_colored_polygon(lightning,Color("39ae64"))
	_text("MOUSE LOOK    WHEEL ZOOM    WASD MOVE    SPACE JUMP    LMB KICK    CTRL SWEEP",Vector2(28,864),14,Color("fff5e6"),2)
	_text("ESC FREE/LOCK MOUSE    TAB CAST    E FACE    P PAUSE    B SHOP",Vector2(28,884),14,Color("fff5e6"),2)
	var pill := Rect2(width-250,831,222,45)
	draw_style_box(_pill_style(),pill)
	_text(character_name+" / "+animation_name,Vector2(width-233,860),22,Color("fff4dc"))
	if paused:
		_text("PAUSED",Vector2(width*0.5-37,64),22,Color("fff1d2"),3)


func _panel(at: Vector2,dimensions: Vector2,face: Color,edge: Color,ink: Color) -> void:
	var extrusion := Vector2(-13,15)
	var back := PackedVector2Array([at,at+Vector2(dimensions.x,0),at+dimensions,at+Vector2(0,dimensions.y),at+Vector2(0,dimensions.y)+extrusion,at+extrusion])
	draw_colored_polygon(back,edge)
	draw_polyline(PackedVector2Array([at,at+extrusion,at+Vector2(0,dimensions.y)+extrusion,at+dimensions+extrusion,at+dimensions]),ink,3,true)
	draw_colored_polygon(PackedVector2Array([at,at+Vector2(dimensions.x,0),at+dimensions,at+Vector2(0,dimensions.y)]),face)
	draw_polyline(PackedVector2Array([at,at+Vector2(dimensions.x,0),at+dimensions,at+Vector2(0,dimensions.y),at]),ink,3,true)
	draw_line(at+Vector2(0,dimensions.y),at+Vector2(0,dimensions.y)+extrusion,ink,2,true)
	draw_line(at+Vector2(0,dimensions.y)+extrusion,at+dimensions+extrusion,ink,3,true)


func _text(value: String,at: Vector2,font_size: int,color: Color,outline: int = 0) -> void:
	if outline>0:
		draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,outline,Color("48304e"))
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)


func _pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18,0.1,0.27,0.82)
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_right = 10
	style.border_color = Color("c7a1d7")
	style.border_width_left = 2
	return style
