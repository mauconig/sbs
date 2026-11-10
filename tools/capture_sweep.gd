extends SceneTree
## Compare actual sprint and sweep travel, then hold movement through recovery.
## godot --fixed-fps 60 --path . --script res://tools/capture_sweep.gd [-- --gameplay]
const Sweep := preload("res://scripts/sweep_motion.gd")
const ScriptedInput := preload("res://tools/scripted_input.gd")
var scene: Node
var sweeper: Node3D
var runner: Node3D
var input := ScriptedInput.new()
var runner_input := ScriptedInput.new()
var gameplay := false
var frame := 0
var start_z := 0.0
var locked_position := Vector3.ZERO
var sweep_distance := 0.0
var run_distance := 0.0
var failures: Array[String] = []
var folder := ""
var last_capture := -1
var status: Label

func _initialize() -> void:
	gameplay = "--gameplay" in OS.get_cmdline_user_args()
	Engine.max_fps = 60
	DisplayServer.window_set_size(Vector2i(960,540))
	folder = "res://.godot/sweep_"+("gameplay" if gameplay else "prototype")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var cache := DirAccess.open(folder)
	for filename in cache.get_files():
		if filename.ends_with(".png") and filename.get_basename().is_valid_int():
			cache.remove(filename)
	scene = load("res://scenes/main.tscn" if gameplay else "res://scenes/visual_prototype.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_record)

func _physics_process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		if gameplay:
			sweeper = scene.player
			runner = scene.bot
			scene.bot_brain.set_physics_process(false)
			sweeper.input = input
			runner.input = runner_input
			runner.speed_multiplier = 1.0
			sweeper.opponent = null
			runner.opponent = null
			scene.kick.input = input
			scene.bot_kick.input = runner_input
			scene.ball.position = Vector3(-8,0.4,-12)
			scene.hud.hide()
			scene.camera.set_physics_process(false)
			input.move = Vector2(0,1)
			input.sprinting = true
			runner_input.move = Vector2(0,1)
			runner_input.sprinting = true
		else:
			scene.set("_capture_mode",true)
			sweeper = scene.characters[0]
			runner = scene.characters[1]
			scene.characters[2].hide()
			scene.characters[3].hide()
			scene.hud.hide()
			runner.play(1)
		sweeper.position = Vector3(-1.5,0.02 if gameplay else 0.0,10)
		runner.position = Vector3(1.5,0.02 if gameplay else 0.0,10)
		sweeper.rotation.y = 0.0
		runner.rotation.y = 0.0
		_tag(sweeper,"SWEEP",Color("ffc862"))
		_tag(runner,"SPRINT",Color("70e4ff"))
		var layer := CanvasLayer.new()
		status = Label.new()
		status.position = Vector2(25,20)
		status.add_theme_font_size_override("font_size",25)
		status.add_theme_color_override("font_shadow_color",Color.BLACK)
		status.add_theme_constant_override("shadow_offset_x",2)
		status.add_theme_constant_override("shadow_offset_y",2)
		layer.add_child(status)
		root.add_child(layer)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sweeper == null:
		return false
	if not gameplay:
		_key(KEY_W,true)
		_key(KEY_SHIFT,true)
		scene._controls(delta)
		runner.position.z -= 8.4*delta
	var camera: Camera3D = scene.camera
	var group_z := (sweeper.position.z+runner.position.z)*0.5
	camera.position = Vector3(7.5,5.5,clampf(group_z+8,-8,14))
	camera.look_at(Vector3(0,0.7,group_z))
	if frame == 30:
		sweeper.position.z = 10
		runner.position.z = 10
		start_z = 10
		if gameplay:
			input.tackle = true
		else:
			scene._start_action(5)
	if frame == 31:
		input.tackle = false
	var elapsed := maxf(0.0,(frame-30)/60.0)
	status.text = "SWEEP: "+("BURST" if elapsed<Sweep.BURST_TIME else "BRAKING" if elapsed<Sweep.MOTION_TIME else "LOCKED RECOVERY" if elapsed<Sweep.TOTAL_TIME else "MOVEMENT RESTORED")+"   |   SPRINT: held throughout"
	if frame == 45:
		_expect(sweeper.position.z<runner.position.z-0.5,"Sweep burst must beat sprint")
		_screenshot("burst")
	if frame == 60:
		sweep_distance = start_z-sweeper.position.z
		run_distance = start_z-runner.position.z
		_expect(sweep_distance>run_distance*1.2,"Sweep must gain more ground than sprint before recovery")
		_screenshot("stop")
	if frame == 65:
		locked_position = sweeper.position
	if frame == 70:
		if gameplay:
			input.jump = true
			input.tackle = true
		else:
			scene._start_action(2)
			scene._start_action(5)
	if frame == 72:
		input.jump = false
		input.tackle = false
	if frame == 85:
		_expect(sweeper.position.distance_to(locked_position)<0.01,"Held movement, jump and sweep must not escape planted recovery")
		_screenshot("recovery")
	if frame == 100:
		_expect(sweeper.position.z<locked_position.z-0.2,"Movement must return after recovery")
	if frame == 110:
		print("SWEEP METRICS: mode=",("gameplay" if gameplay else "prototype")," sweep=",snappedf(sweep_distance,0.01)," sprint=",snappedf(run_distance,0.01)," locked_seconds=",Sweep.RECOVERY_TIME)
		if failures.is_empty():
			print("SWEEP PASS: burst beats sprint, braking ends at rest, recovery ignores held input, movement resumes")
			quit()
		else:
			for failure in failures:
				push_error(failure)
			quit(1)
	return false

func _key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _tag(actor: Node3D,title: String,color: Color) -> void:
	var label := Label3D.new()
	label.text = title
	label.position.y = 2.0 if not gameplay else 1.65
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = color
	actor.add_child(label)

func _expect(condition: bool,message: String) -> void:
	if not condition:
		failures.append(message)

func _screenshot(state: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/sweep_"+("gameplay_" if gameplay else "")+state+".png"))

func _record() -> void:
	if sweeper==null or frame-last_capture<2:
		return
	last_capture = frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+"/%04d.png"%frame))
