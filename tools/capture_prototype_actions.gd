extends SceneTree
## Exercise real held movement through jumps and a grounded slide; save proof.
var scene: Node
var frame := 0
var actor: Node3D
var start_z := 0.0
var failures: Array[String] = []

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(960,540))
	scene = load("res://scenes/visual_prototype.tscn").instantiate()
	root.add_child(scene)

func _physics_process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		scene.set("_capture_mode",true)
		actor = scene.characters[0]
		actor.position = Vector3(0,0,2)
		for index in range(1,4):
			scene.characters[index].visible = false
		scene.hud.hide()
		_key(KEY_W,true)
	if actor == null:
		return false
	scene._controls(delta)
	var camera: Camera3D = scene.camera
	camera.position = actor.position+Vector3(3.7,2.0,3.5)
	camera.look_at(actor.position+Vector3(0,0.9,0))
	if frame == 15:
		_expect(actor.animation==6,"Held W must select walking")
		start_z = actor.position.z
		_action(KEY_SPACE)
	if frame == 35:
		_expect(actor.animation==2,"Walking input must preserve jump")
		_expect(actor.position.z<start_z-0.5,"Jump must keep travelling while walking")
		_capture("jump_walk")
	if frame == 80:
		_expect(actor.animation==6,"Landing must resume walking")
		_key(KEY_SHIFT,true)
	if frame == 90:
		_expect(actor.animation==1,"Shift movement must select running")
		_action(KEY_SPACE)
		start_z = actor.position.z
	if frame == 110:
		_expect(actor.animation==8,"Running jump must select the forward dive")
		_expect(actor.position.z<start_z-1.0,"Running jump must retain forward travel")
		_capture("jump_run")
		_key(KEY_W,false)
		_key(KEY_SHIFT,false)
	if frame == 111:
		_expect(actor.animation==8,"Releasing movement must not cancel the dive")
	if frame == 155:
		_expect(actor.animation==0,"Landing without movement must return to idle")
		_action(KEY_CTRL)
	if frame == 177:
		_expect(actor.animation==5,"Sweep must remain active through its slide")
		_capture("sweep")
	if frame == 215:
		_expect(actor.animation==0,"Sweep must recover to idle")
		if failures.is_empty():
			print("PROTOTYPE ACTIONS PASS: jump while walking/running, release in air, landing, sweep recovery")
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

func _action(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	scene._unhandled_input(event)

func _expect(condition: bool,message: String) -> void:
	if not condition:
		failures.append(message)

func _capture(state: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/action_"+state+".png"))
