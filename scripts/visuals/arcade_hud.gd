extends Control
## Original illustrated scoreboard and energy strip, drawn at a 1600x900 canvas.

const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
const Meters := preload("res://scripts/ui/hud_painter.gd")
const Scoreboard := preload("res://scripts/ui/scoreboard.gd")
const InventoryHud := preload("res://scripts/ui/item_inventory_hud.gd")
var character_name := "PIP"
var animation_name := "RUN"
var paused := false
var energy := 0.88
var charge := 0.0
var aiming := false
var charging := false
var sweet_lo := 0.80
var sweet_hi := 0.95
var _meters: Control
var _scoreboard: Control
var weapon_system: Node3D
var inventory: RefCounted
var boost_remaining := 0.0
var _inventory_hud: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_meters = Meters.new()
	add_child(_meters)
	_scoreboard = Scoreboard.new()
	add_child(_scoreboard)
	_inventory_hud=InventoryHud.new()
	add_child(_inventory_hud)


func _process(_delta: float) -> void:
	_inventory_hud.set("weapon_system",weapon_system)
	_inventory_hud.set("inventory",inventory)
	_inventory_hud.set("boost_remaining",boost_remaining)
	_meters.set("energy",energy)
	_meters.set("charge",charge)
	_meters.set("power_visible",aiming or charging)
	_meters.set("sweet_lo",sweet_lo)
	_meters.set("sweet_hi",sweet_hi)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var factor := view.y/900.0
	var width := view.x/factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	_text("SUNLINE PARK",Vector2(28,42),18,Color("fff5e4"),2)
	# Small brand plate leaves the arena and cast as the visual focus.
	_text("MEGA BATTLE",Vector2(width-188,40),23,Color("fff7e6"),3)
	_text("F O O T B A L L",Vector2(width-188,61),16,Color("e4caed"),2)
	_text("MOUSE LOOK    WASD MOVE    SHIFT SPRINT    SPACE HOP    RMB AIM    LMB SHOT / PASS    CTRL SWEEP",Vector2(28,864),14,Color("fff5e6"),2)
	_text("1-3 / SCROLL SLOTS    RMB AIM    LMB FIRE    F DROP    PGUP/DN ZOOM    ESC FREE/LOCK MOUSE    TAB CAST    G FACE    P PAUSE    B SHOP",Vector2(28,884),14,Color("fff5e6"),2)
	var pill := Rect2(width-250,831,222,45)
	draw_style_box(_pill_style(),pill)
	_text(character_name+" / "+animation_name,Vector2(width-233,860),22,Color("fff4dc"))
	if paused:
		_text("PAUSED",Vector2(width*0.5-37,130),22,Color("fff1d2"),3)


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
