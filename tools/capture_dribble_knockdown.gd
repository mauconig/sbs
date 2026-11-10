extends Node
## Exercise real possession and sweep contact, inspect the skinned mesh, and record frames.
const ScriptedInput := preload("res://tools/scripted_input.gd")
var _frame := 0
var _label: Label
var _failures: Array[String] = []
var _folder := "res://.godot/dribble_knockdown_frames"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_size(Vector2i(960,540))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_folder))
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(22,18)
	_label.add_theme_font_size_override("font_size",24)
	_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x",2)
	_label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(_label)
	add_child(layer)
	var match_scene: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	match_scene.bot_brain.set_physics_process(false)
	match_scene.camera.set_physics_process(false)
	match_scene.hud.hide()
	match_scene.player.camera_relative = false
	var input := ScriptedInput.new()
	match_scene.player.input = input
	match_scene.kick.input = input
	match_scene.bot.input = null
	match_scene.bot.position = Vector3(8,0.05,0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for sprinting: bool in [false,true]:
		match_scene.player.reset_at(Vector3(0,0.04,8),Vector3.FORWARD)
		input.move = Vector2.ZERO
		for unused in 8:
			await _step()
		match_scene.ball.freeze = true
		match_scene.ball.reset_to(Vector3(0.18,0.23,7.3))
		await _step()
		match_scene.ball.claim_by(match_scene.player)
		input.move = Vector2(0,1)
		input.sprinting = sprinting
		var forward_offsets: Array[float] = []
		var side_offsets: Array[float] = []
		for tick in 46:
			_label.text = "1v1 / "+("SPRINT TOUCHES" if sprinting else "WALK TOUCHES")
			_follow(match_scene.camera,match_scene.player)
			await _step()
			if tick > 10:
				var relative: Vector3 = match_scene.ball.global_position-match_scene.player.global_position
				forward_offsets.append(relative.dot(match_scene.player.facing))
				side_offsets.append(relative.dot(match_scene.player.global_basis.x))
			_expect(match_scene.ball.carrier == match_scene.player,"Dribbling lost possession")
			if tick%2 == 0:
				_record()
		_expect(forward_offsets.max()-forward_offsets.min()>0.10,"The ball needs visible roll-ahead and catch-up between touches")
		_expect(forward_offsets.max()<1.55,"A dribbling touch must remain within playing reach")
		_expect(side_offsets.max()-side_offsets.min()>0.10,"Touches must alternate between the feet")
		_expect(match_scene.ball.angular_velocity.length()>2.0,"The carried ball must roll")
		var expected_speed: float = match_scene.player.sprint_speed if sprinting else match_scene.player.walk_speed
		_expect(absf(Vector2(match_scene.player.velocity.x,match_scene.player.velocity.z).length()-expected_speed)<0.05,"The ball must not block or slow its carrier")
		print("DRIBBLE ","sprint" if sprinting else "walk"," reach=",forward_offsets.min(),"..",forward_offsets.max()," side=",side_offsets.min(),"..",side_offsets.max())
	_expect(match_scene.player in match_scene.ball.get_collision_exceptions(),"The ball must not collide with its carrier's capsule")
	_expect(match_scene.kick.force_kick(0.6,Vector3.FORWARD),"Footstep dribbling must preserve match kicking")
	await _step()
	_expect(match_scene.ball.carrier==null and match_scene.player not in match_scene.ball.get_collision_exceptions(),"Kicking must restore collision and release the ball")
	input.move = Vector2.ZERO
	input.sprinting = false
	match_scene.player.reset_at(Vector3(0,0.04,3),Vector3.FORWARD)
	match_scene.bot.reset_at(Vector3(0,0.04,1.85),Vector3.BACK)
	match_scene.bot.protection = 0.0
	match_scene.ball.reset_to(Vector3(0.2,0.23,2.5))
	match_scene.ball.claim_by(match_scene.bot)
	for unused in 12:
		await _step()
	input.tackle = true
	await _step()
	input.tackle = false
	var lowest := INF
	var knockdown_frames := 0
	for tick in 130:
		_label.text = "SWEEP / IMPACT, BRACE, GET UP"
		_follow(match_scene.camera,match_scene.bot)
		await _step()
		if match_scene.bot.knocked_out>0:
			knockdown_frames += 1
			lowest = minf(lowest,_mesh_floor(match_scene.bot.get("_visual")))
		if tick%2 == 0:
			_record()
	_expect(knockdown_frames>75,"A real sweep must trigger the complete victim reaction")
	_expect(lowest>=-0.015,"The knocked player went below the turf: "+str(lowest))
	_expect(match_scene.bot.knocked_out<=0.0,"The victim must recover control")
	_expect(match_scene.ball.carrier==match_scene.player,"A valid sweep must still transfer possession to the sweeper")
	_expect(is_zero_approx(match_scene.bot.get("_visual").rotation.x),"Knockdown must not rotate the whole visual around the feet")
	print("KNOCKDOWN minimum skinned mesh world Y=",lowest," sampled frames=",knockdown_frames)
	match_scene.queue_free()
	await get_tree().process_frame
	var sandbox: Node = load("res://scenes/visual_prototype.tscn").instantiate()
	get_tree().root.add_child(sandbox)
	sandbox.set("_capture_mode",true)
	sandbox.hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var actor: Node3D = sandbox.characters[0]
	actor.position = Vector3(0,0,7)
	actor.rotation = Vector3.ZERO
	actor.call("play",6)
	for index in range(1,4):
		sandbox.characters[index].hide()
		sandbox.characters[index].position = Vector3(100+index*5,0,0)
	sandbox.ball.reset_to(Vector3(0.18,0.23,6.3))
	sandbox.ball.claim_by(actor)
	sandbox.set("_carrier_index",0)
	sandbox.set("_carrier_last_position",actor.position)
	var sandbox_offsets: Array[float] = []
	for tick in 55:
		_label.text = "SANDBOX / SHARED FOOTSTEP DRIBBLE"
		actor.position.z -= sandbox.walk_speed/60.0
		sandbox.call("_update_sandbox_ball",1.0/60.0)
		_follow(sandbox.camera,actor)
		await _step()
		if tick>10:
			sandbox_offsets.append((sandbox.ball.global_position-actor.global_position).dot(Vector3.FORWARD))
		_expect(sandbox.ball.global_position.y>=0.19,"Sandbox physics ball fell through the pitch")
		if tick%2 == 0:
			_record()
	_expect(sandbox_offsets.max()-sandbox_offsets.min()>0.10,"Sandbox must show the same rolling touches")
	actor.call("play",0)
	for unused in 30:
		sandbox.call("_update_sandbox_ball",1.0/60.0)
		await _step()
	_expect(sandbox.ball.linear_velocity.length()<0.6,"Idle ball must settle at the player's feet")
	_expect(sandbox.kick_controller.force_kick(0.7,Vector3.FORWARD),"A dribbled sandbox ball must still be kickable")
	for unused in 25:
		sandbox.call("_update_sandbox_ball",1.0/60.0)
		await _step()
	_expect(sandbox.ball.carrier==null,"Kicking must release possession")
	_expect(sandbox.ball.global_position.y>=0.19,"A loose shot must remain above the sandbox pitch")
	print("SANDBOX dribble reach=",sandbox_offsets.min(),"..",sandbox_offsets.max(),"; idle settle and shot release checked")
	if _failures.is_empty():
		print("DRIBBLE AND KNOCKDOWN PASS: real possession, footstep touches in both modes, sweep contact, skinned grounding and recovery")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _step() -> void:
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw


func _follow(camera: Camera3D, target: Node3D) -> void:
	camera.global_position = target.global_position+Vector3(2.1,1.25,2.6)
	camera.look_at(target.global_position+Vector3(0,0.55,-0.35))


func _record() -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_folder+"/%04d.png"%_frame))
	_frame += 1


func _mesh_floor(visual: Node3D) -> float:
	var minimum := INF
	for node in visual.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		var mesh := instance.bake_mesh_from_current_skeleton_pose()
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				minimum = minf(minimum,(instance.global_transform*vertex).y)
	return minimum


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
		push_error(message)
