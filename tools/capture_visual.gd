extends SceneTree
## Rendered screenshot and measured frame timings. Runs with a real renderer.
## godot --path . --script tools/capture_visual.gd -- --output=docs/visual_preview.png

var scene: Node
var frames := 0
var timings: Array[float] = []
var last_tick := 0
var output := "res://docs/visual_preview.png"
var close_up := false
var portrait_index := 2
var lineup := false
var profile_seconds := 0.0
var profile_started := 0
var saved := false


func _initialize() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument=="--close-up":
			close_up = true
		if argument.begins_with("--portrait-index="):
			portrait_index = clampi(int(argument.trim_prefix("--portrait-index=")),0,3)
		if argument=="--lineup":
			lineup = true
		if argument.begins_with("--profile-seconds="):
			profile_seconds = float(argument.trim_prefix("--profile-seconds="))
	scene = load("res://scenes/visual_prototype.tscn").instantiate()
	root.add_child(scene)
	last_tick = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	frames += 1
	var now := Time.get_ticks_usec()
	if frames>90:
		timings.append((now-last_tick)/1000.0)
	if frames==90:
		profile_started = now
	last_tick = now
	if frames==180:
		if lineup:
			scene.stage_lineup()
			for actor in scene.characters:
				var player := actor.get("_animation_player") as AnimationPlayer
				if player != null:
					player.play(actor.get("_idle_animation"),0.0)
					player.seek(0.0,true)
		elif close_up:
			scene.stage_portrait(portrait_index)
			for index in scene.characters.size():
				if index != portrait_index:
					scene.characters[index].visible = false
		elif profile_seconds<=0:
			scene.stage_snapshot()
	if frames>=210 and not saved and (now-profile_started)/1000000.0>=profile_seconds:
		saved = true
		if profile_seconds>0 and not close_up and not lineup:
			scene.stage_snapshot()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		timings.sort()
		print("CAPTURE ",output)
		print("PROFILE adapter=",RenderingServer.get_video_adapter_name()," renderer=",RenderingServer.get_current_rendering_method()," resolution=",root.size)
		print("PROFILE median_ms=",snappedf(timings[timings.size()/2],0.01)," p95_ms=",snappedf(timings[int(timings.size()*0.95)],0.01)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if profile_seconds>0:
			var report := {"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"width":root.size.x,"height":root.size.y,"samples":timings.size(),"median_ms":snappedf(timings[timings.size()/2],0.01),"p95_ms":snappedf(timings[int(timings.size()*0.95)],0.01),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"note":"Measured with the four animated characters and VSync off. This GPU is not an integrated GPU; laptop performance remains unverified."}
			var file := FileAccess.open("res://docs/visual_profile.json",FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  "))
		quit()
	return false
