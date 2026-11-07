extends Control
## Draws the charge meter, sweet-spot band and stamina bar.

var hud


func _draw() -> void:
	if hud == null:
		return

	var view := get_viewport_rect().size

	var bar_width := 460.0
	var bar_height := 24.0
	var bar_x := view.x * 0.5 - bar_width * 0.5
	var bar_y := view.y - 96.0

	draw_rect(Rect2(bar_x - 6.0, bar_y - 6.0, bar_width + 12.0, bar_height + 12.0), Color(0, 0, 0, 0.45))

	var zone_start: float = hud.sweet_lo
	var zone_end: float = hud.sweet_hi
	draw_rect(
		Rect2(bar_x + bar_width * zone_start, bar_y, bar_width * (zone_end - zone_start), bar_height),
		Color(1.0, 0.8, 0.2, 0.30)
	)

	var fill_color := Color(0.92, 0.96, 1.0, 0.9)
	if hud.sweet_hit:
		fill_color = Color(1.0, 0.84, 0.22, 1.0)
	elif hud.charge > zone_end:
		fill_color = Color(1.0, 0.45, 0.35, 0.95)
	draw_rect(Rect2(bar_x, bar_y, bar_width * clampf(hud.charge, 0.0, 1.0), bar_height), fill_color)

	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(1, 1, 1, 0.45), false, 2.0)

	for tick: float in [0.25, 0.5, 0.75]:
		var tick_x: float = bar_x + bar_width * tick
		draw_line(Vector2(tick_x, bar_y), Vector2(tick_x, bar_y + bar_height), Color(1, 1, 1, 0.18), 1.0)

	var stamina_width := 300.0
	var stamina_x := view.x * 0.5 - stamina_width * 0.5
	var stamina_y := bar_y + bar_height + 18.0
	draw_rect(Rect2(stamina_x, stamina_y, stamina_width, 8.0), Color(0, 0, 0, 0.45))

	var stamina_color := Color(0.35, 0.9, 0.62)
	if hud.exhausted:
		stamina_color = Color(1.0, 0.4, 0.35)
	elif hud.sprinting:
		stamina_color = Color(1.0, 0.85, 0.35)
	var ratio := clampf(hud.stamina / maxf(hud.stamina_max, 1.0), 0.0, 1.0)
	draw_rect(Rect2(stamina_x, stamina_y, stamina_width * ratio, 8.0), stamina_color)
