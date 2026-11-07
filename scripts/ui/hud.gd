extends CanvasLayer
## Sandbox HUD: charge meter with sweet spot, stamina bar, counters, banners.

const PainterScript := preload("res://scripts/ui/hud_painter.gd")

var charge := 0.0
var sweet_lo := 0.80
var sweet_hi := 0.95
var sweet_hit := false
var stamina := 100.0
var stamina_max := 100.0
var sprinting := false
var exhausted := false
var goals := 0
var shots := 0
var best_goal_distance := 0.0

var _painter: Control
var _stats: Label
var _banner: Label
var _hint: Label
var _banner_tween: Tween


func _ready() -> void:
	layer = 10

	_painter = PainterScript.new()
	_painter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painter.set("hud", self)
	add_child(_painter)

	_stats = _make_label(26, Color(0.95, 0.97, 1.0))
	_stats.position = Vector2(34, 26)
	add_child(_stats)

	_banner = _make_label(104, Color(1.0, 0.85, 0.3))
	_banner.modulate.a = 0.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)

	_hint = _make_label(15, Color(0.62, 0.72, 0.86))
	_hint.text = "WASD run  ·  SHIFT sprint  ·  hold LMB to charge, A/D curves  ·  R reset  ·  ESC mouse"
	_hint.position = Vector2(34, 0)
	add_child(_hint)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func show_banner(text: String, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	_banner.text = text
	_banner.modulate = Color(color.r, color.g, color.b, 1.0)
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.55)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.45)


func _process(_delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	_stats.text = "%d GOALS    %d SHOTS" % [goals, shots]

	_banner.size = _banner.get_minimum_size()
	_banner.position = Vector2(view.x * 0.5 - _banner.size.x * 0.5, view.y * 0.2)

	_hint.size = _hint.get_minimum_size()
	_hint.position = Vector2(34, view.y - 42)

	_painter.queue_redraw()
