extends Control
## Shared illustrated stamina strip and vertical power meter for both modes.

const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
const INK := Color("292135")
const CREAM := Color("fff8e4")

var energy := 1.0
var charge := 0.0
var power_visible := false
var sweet_lo := 0.80
var sweet_hi := 0.95
var _energy_texture: GradientTexture2D
var _power_texture: GradientTexture2D


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
	_power_texture = GradientTexture2D.new()
	_power_texture.gradient = gradient
	_power_texture.width = 8
	_power_texture.height = 256
	_power_texture.fill_from = Vector2(0,1)
	_power_texture.fill_to = Vector2(0,0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var factor := maxf(view.y/900.0,0.01)
	var width := view.x/factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	_draw_stamina(width)
	if power_visible:
		_draw_power(width)


func _draw_stamina(width: float) -> void:
	# Preserve the playground's shape, colours and bottom-center position.
	var center := Vector2(width*0.5,824)
	var shadow := PackedVector2Array([center+Vector2(-157,7),center+Vector2(144,7),center+Vector2(154,-22),center+Vector2(-147,-22)])
	draw_colored_polygon(shadow,INK)
	var outer := PackedVector2Array([center+Vector2(-160,2),center+Vector2(140,2),center+Vector2(150,-27),center+Vector2(-150,-27)])
	draw_colored_polygon(outer,CREAM)
	draw_texture_rect(_energy_texture,Rect2(center+Vector2(-131,-23),Vector2(267*clampf(energy,0.0,1.0),21)),false)
	draw_line(center+Vector2(8,-25),center+Vector2(0,0),CREAM,3,true)
	var lightning := PackedVector2Array([Vector2(-145,-24),Vector2(-151,-10),Vector2(-145,-10),Vector2(-149,-1),Vector2(-136,-16),Vector2(-143,-16)])
	for index in lightning.size():
		lightning[index] += center
	draw_colored_polygon(lightning,Color("39ae64"))


func power_rect(width: float) -> Rect2:
	# Match the stamina strip's 900-pixel design height.
	return Rect2(Vector2(width*0.5+116.0,365.0),Vector2(20.0,170.0))


func _draw_power(width: float) -> void:
	var meter := power_rect(width)
	var at := meter.position
	var height := meter.size.y
	var outer := PackedVector2Array([at+Vector2(-4,0),at+Vector2(24,-6),at+Vector2(24,height),at+Vector2(-4,height+6)])
	var shadow := PackedVector2Array()
	for point in outer:
		shadow.append(point+Vector2(5,5))
	draw_colored_polygon(shadow,INK)
	draw_colored_polygon(outer,CREAM)
	var rail := Rect2(at+Vector2(0,5),Vector2(20,height-10))
	draw_rect(rail,INK)
	var fill := clampf(charge,0.0,1.0)
	var filled_height := rail.size.y*fill
	if filled_height>0.0:
		var destination := Rect2(Vector2(rail.position.x,rail.end.y-filled_height),Vector2(rail.size.x,filled_height))
		var source := Rect2(Vector2(0,256.0*(1.0-fill)),Vector2(8,256.0*fill))
		draw_texture_rect_region(_power_texture,destination,source)
	# Segments and a sweet-spot bracket keep timing readable at gameplay distance.
	for step in range(1,8):
		var y := rail.end.y-rail.size.y*step/8.0
		draw_line(Vector2(rail.position.x,y),Vector2(rail.end.x,y),Color(0.15,0.10,0.2,0.35),2,true)
	var band_top := rail.end.y-rail.size.y*sweet_hi
	var band_bottom := rail.end.y-rail.size.y*sweet_lo
	var sweet := fill>=sweet_lo and fill<=sweet_hi
	var highlight := Color("aafa6b") if sweet else CREAM
	draw_line(Vector2(rail.end.x+3,band_top),Vector2(rail.end.x+3,band_bottom),highlight,3,true)
	for y in [band_top,band_bottom]:
		draw_line(Vector2(rail.end.x-3,y),Vector2(rail.end.x+5,y),highlight,2,true)
	var marker_y := rail.end.y-filled_height
	draw_colored_polygon(PackedVector2Array([Vector2(at.x-8,marker_y),Vector2(at.x-14,marker_y-4),Vector2(at.x-14,marker_y+4)]),CREAM)
	draw_string(FONT,at+Vector2(-6,-15),"POWER",HORIZONTAL_ALIGNMENT_LEFT,-1,15,CREAM)
