extends SceneTree
## Render and measure high jump, moving kick and a momentum-preserving dive.
## Use --fixed-fps 60 for frame-complete offline capture, not performance profiling.
const ScriptedInput := preload("res://tools/scripted_input.gd")
var scene: Node
var actor: Node3D
var body: Node3D
var input := ScriptedInput.new()
var gameplay := false
var frame := 0
var last_capture := -1
var folder := ""
var start_z := 0.0
var peak := 0.0
var support_pose := Quaternion.IDENTITY
var failures: Array[String] = []
var _move_held := false
var _sprint_held := false

func _initialize() -> void:
	gameplay = "--gameplay" in OS.get_cmdline_user_args()
	Engine.max_fps = 60
	DisplayServer.window_set_size(Vector2i(960,540))
	folder = "res://.godot/polish_"+("gameplay" if gameplay else "prototype")
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
			body = scene.player
			actor = body.get("_visual")
			body.input = input
			scene.kick.input = input
			scene.camera.input = input
			scene.bot_brain.set_physics_process(false)
			scene.bot.input = null
			scene.bot.position = Vector3(8,0.1,-12)
			scene.ball.position = Vector3(-8,0.4,-5)
			scene.hud.hide()
		else:
			scene.set("_capture_mode",true)
			actor = scene.characters[0]
			body = actor
			for index in range(1,4):
				scene.characters[index].visible = false
			scene.hud.hide()
		body.position = Vector3(0,0.02 if gameplay else 0.0,6)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if actor == null:
		return false
	if not gameplay:
		# Reassert held input across long offline renders and window focus changes.
		_key(KEY_W,_move_held)
		_key(KEY_SHIFT,_sprint_held)
		scene._controls(delta)
	var camera: Camera3D = scene.camera
	if gameplay:
		camera.set_physics_process(false)
	camera.position = Vector3(6,4,body.position.z+5)
	camera.look_at(Vector3(0,1.3,body.position.z))
	if frame == 25:
		_jump()
	if frame == 26 and gameplay:
		input.jump = false
	if frame>25 and frame<90:
		peak = maxf(peak,body.position.y)
	if frame == 53:
		_screenshot("high_jump")
	if frame == 90:
		_expect(peak>2.3,"Normal jump must reach at least 2.3 units")
		_expect(body.position.y<0.05,"Normal jump must land")
		_motion(true,false)
	if frame == 105:
		start_z = body.position.z
		if gameplay:
			body.play_kick_animation()
		else:
			scene._start_action(3)
	if frame == 112:
		_expect(actor.animation==9,"Moving kick must select the gait-based clip")
		var skeleton := actor.find_child("Skeleton3D",true,false) as Skeleton3D
		support_pose = skeleton.get_bone_pose_rotation(skeleton.find_bone("mixamorig_LeftUpLeg"))
	if frame == 123:
		var skeleton := actor.find_child("Skeleton3D",true,false) as Skeleton3D
		var current := skeleton.get_bone_pose_rotation(skeleton.find_bone("mixamorig_LeftUpLeg"))
		_expect(support_pose.angle_to(current)>0.1,"Support leg must keep stepping during moving kick")
		_expect(body.position.z<start_z-1.0,"Moving kick must retain horizontal movement")
		_expect(body.position.y<0.05,"Moving kick must remain on the pitch")
		_screenshot("moving_kick")
	if frame == 145:
		_motion(false,false)
	if frame == 160:
		body.position = Vector3(0,0.02 if gameplay else 0.0,10)
		_motion(true,true)
	if frame == 178:
		start_z = body.position.z
		_jump()
	if frame == 179:
		input.jump = false
		_motion(false,false)
	if frame == 198:
		_expect(actor.animation==8,"Sprint jump must select forward goalkeeper dive")
		_screenshot("forward_dive")
	if frame == 220:
		var distance := start_z-body.position.z
		_expect(distance>(12.0 if gameplay else 6.0),"Dive must preserve a strong forward impulse after movement is released")
		print("ACTION METRICS: mode=",("gameplay" if gameplay else "prototype")," jump_peak=",snappedf(peak,0.01)," dive_distance=",snappedf(distance,0.01))
	if frame == 240:
		_screenshot("dive_recovery")
	if frame == 255:
		_expect(body.position.y<0.05,"Dive must land on the pitch")
		_expect(actor.animation==0,"Dive must recover to idle")
		if failures.is_empty():
			print("ACTION POLISH PASS: high jump, planted moving kick, forward dive momentum and recovery")
			quit()
		else:
			for failure in failures:
				push_error(failure)
			quit(1)
	return false

func _motion(moving: bool,sprinting: bool) -> void:
	_move_held = moving
	_sprint_held = sprinting
	if gameplay:
		input.move = Vector2(0,1) if moving else Vector2.ZERO
		input.sprinting = sprinting
	else:
		_key(KEY_W,moving)
		_key(KEY_SHIFT,sprinting)

func _jump() -> void:
	if gameplay:
		input.jump = true
	else:
		scene._start_action(2)

func _key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _expect(condition: bool,message: String) -> void:
	if not condition:
		failures.append(message)

func _screenshot(state: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/polish_"+("gameplay_" if gameplay else "")+state+".png"))

func _record() -> void:
	if actor == null or frame-last_capture<2:
		return
	last_capture = frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+"/%04d.png"%frame))
