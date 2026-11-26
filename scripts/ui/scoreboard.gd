extends Control
## Shared centered score / clock + mode / score layout, in the playground's style.

const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
const INK := Color("292135")
const CREAM := Color("fff7df")
var blue_score := 0
var pink_score := 0
var time_seconds := 97.0
var mode_label := "2V2"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var factor := maxf(size.y/900.0,0.01)
	var center := size.x/factor*0.5
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var tray := StyleBoxFlat.new()
	tray.bg_color=Color("241d32")
	tray.set_corner_radius_all(12)
	tray.shadow_color=Color(0.08,0.04,0.12,0.30)
	tray.shadow_size=5
	tray.shadow_offset=Vector2(0,4)
	draw_style_box(tray,Rect2(center-144,14,288,88))
	var blue := Rect2(center-123,27,56,57)
	var middle := Rect2(center-61,24,122,63)
	var pink := Rect2(center+67,27,56,57)
	_panel(blue,Color("00b8e9"),Color("0876ba"))
	_panel(middle,Color("463752"),Color("9981c5"))
	_panel(pink,Color("ef308e"),Color("b71366"))
	_text_center(str(blue_score),blue,42,69,CREAM)
	_text_center(str(pink_score),pink,42,69,CREAM)
	var seconds := maxi(0,int(ceil(time_seconds)))
	_text_center("%d:%02d" % [seconds/60,seconds%60],middle,33,56,CREAM)
	_text_center(mode_label,middle,15,76,Color("dfcde8"))


func _panel(rect: Rect2,face: Color,edge: Color) -> void:
	var a := rect.position
	var b := rect.end
	var offset := Vector2(-6,7)
	draw_colored_polygon(PackedVector2Array([a,a+offset,Vector2(a.x,b.y)+offset,b+offset,b]),edge)
	draw_polyline(PackedVector2Array([a,a+offset,Vector2(a.x,b.y)+offset,b+offset,b]),INK,2.5,true)
	draw_rect(rect,face)
	draw_rect(rect,INK,false,2.5)
	draw_line(Vector2(a.x,b.y),Vector2(a.x,b.y)+offset,INK,2.5,true)


func _text_center(value: String,rect: Rect2,font_size: int,baseline: float,color: Color) -> void:
	var width := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var at := Vector2(rect.get_center().x-width*0.5,baseline)
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,INK)
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
