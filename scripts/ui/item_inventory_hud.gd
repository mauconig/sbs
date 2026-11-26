extends Control
## Permanent football slot plus two consumable slots.

const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
const INK := Color("292135")
const CREAM := Color("fff8e4")
var weapon_system: Node3D
var inventory: RefCounted
var boost_remaining := 0.0


func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var factor := maxf(view.y/900.0,0.01)
	var width := view.x/factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	if weapon_system!=null and weapon_system.aiming:
		var color := Color("22e6ce") if weapon_system.locked_target!=null else Color("ffbf38")
		var center := Vector2(width*0.5,450)
		for axis in [Vector2.RIGHT,Vector2.UP,-Vector2.RIGHT,-Vector2.UP]:
			draw_line(center+axis*7,center+axis*15,INK,5,true)
			draw_line(center+axis*7,center+axis*15,color,2,true)
		if weapon_system.candidate!=null and weapon_system.view_camera!=null:
			var camera: Camera3D=weapon_system.view_camera
			var at: Vector3=weapon_system.candidate.global_position+Vector3.UP*0.75
			if not camera.is_position_behind(at):
				var screen := camera.unproject_position(at)/factor
				var radius := clampf(500.0/camera.global_position.distance_to(at),18.0,48.0)
				draw_arc(screen,radius,0,TAU,48,INK,6,true)
				draw_arc(screen,radius,-PI/2,-PI/2+TAU*maxf(0.01,weapon_system.lock_progress),48,color,3,true)
		var hint := "LOCKED - LMB FIRE" if weapon_system.locked_target!=null else "HOLD AIM TO LOCK" if weapon_system.candidate!=null else "AIM AT AN OPPONENT"
		var text_size := FONT.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		_text(hint,center+Vector2(-text_size.x/2,65),16,color)
	var start := Vector2(width-352,704)
	if boost_remaining>0.0:
		_text("BOOST  %.1fs" % boost_remaining,start+Vector2(0,-34),19,Color("22d0e6"))
	_text("ITEMS",start+Vector2(0,-10),17,CREAM)
	for index in 3:
		var rect := Rect2(start+Vector2(index*108,0),Vector2(98,86))
		var selected: bool=inventory!=null and inventory.selected==index
		var style := StyleBoxFlat.new()
		style.bg_color=Color("463752") if selected else Color("262239")
		style.set_corner_radius_all(8)
		style.set_border_width_all(3 if selected else 2)
		style.border_color=CREAM if selected else Color("675778")
		style.shadow_color=INK
		style.shadow_size=0
		style.shadow_offset=Vector2(4,5)
		draw_style_box(style,rect)
		_text(str(index+1),rect.position+Vector2(8,18),14,Color("f63397") if selected else Color("b6a8c3"))
		var item: StringName=inventory.slots[index] if inventory!=null else &""
		if item==&"ball":
			_draw_ball(rect.position+Vector2(49,38))
			_text("FOOTBALL",rect.position+Vector2(16,75),17,CREAM)
		elif item==&"bazooka":
			_draw_bazooka(rect.position+Vector2(49,38))
			_text("BAZOOKA",rect.position+Vector2(17,75),17,CREAM)
		else:
			_text("—",rect.position+Vector2(37,46),28,Color("8e819e"))
		if selected:
			draw_rect(Rect2(rect.position+Vector2(12,82),Vector2(74,4)),Color("f63397"))
	_text("1-3 / SCROLL   RMB AIM   LMB FIRE   F DROP",start+Vector2(0,107),13,CREAM)


func _draw_ball(at: Vector2) -> void:
	draw_circle(at,18,CREAM)
	draw_arc(at,18,0,TAU,32,INK,2,true)
	var panel := PackedVector2Array()
	for index in 5:
		panel.append(at+Vector2.from_angle(-PI/2+TAU*index/5)*8)
	draw_colored_polygon(panel,INK)
	for index in 5:
		var direction := Vector2.from_angle(-PI/2+TAU*index/5)
		draw_line(at+direction*8,at+direction*17,INK,2,true)


func _draw_bazooka(at: Vector2) -> void:
	draw_line(at+Vector2(-25,7),at+Vector2(24,-9),CREAM,16,true)
	draw_line(at+Vector2(-20,5),at+Vector2(19,-7),Color("29354e"),11,true)
	draw_line(at+Vector2(-24,7),at+Vector2(-19,5),Color("f63397"),18,true)
	draw_line(at+Vector2(1,0),at+Vector2(5,13),CREAM,8,true)
	draw_line(at+Vector2(10,-12),at+Vector2(8,-18),Color("f63397"),6,true)


func _text(value: String,at: Vector2,size: int,color: Color) -> void:
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,2,INK)
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
