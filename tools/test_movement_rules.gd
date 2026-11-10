extends Node
## Verifies shared movement tuning, ball-carrier action locks and sandbox pickups.

const MainScene := preload("res://scenes/main.tscn")
const PreviewScene := preload("res://scenes/visual_prototype.tscn")
const ScriptedInput := preload("res://tools/scripted_input.gd")
const MovementTuning := preload("res://scripts/movement_tuning.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var old_jump_height := 12.0 * 12.0 / (2.0 * MovementTuning.GRAVITY)
	var new_jump_height := MovementTuning.NORMAL_JUMP_SPEED * MovementTuning.NORMAL_JUMP_SPEED / (2.0 * MovementTuning.GRAVITY)
	assert(is_equal_approx(new_jump_height / old_jump_height, 0.6), "Normal jump apex must be 40% lower")
	assert(is_equal_approx(MovementTuning.DIVE_JUMP_SPEED, 8.0), "Goalkeeper dive lift remains unchanged")

	await _test_match_rules()
	await _test_sandbox_rules()
	print("MOVEMENT RULES PASS: shared pace, 40% lower jump, carrier locks, kick release, sandbox pickup and follow")
	get_tree().quit()


func _test_match_rules() -> void:
	var old_jump_height := 12.0 * 12.0 / (2.0 * MovementTuning.GRAVITY)
	var new_jump_height := MovementTuning.NORMAL_JUMP_SPEED * MovementTuning.NORMAL_JUMP_SPEED / (2.0 * MovementTuning.GRAVITY)
	var main := MainScene.instantiate()
	get_tree().root.add_child(main)
	await _physics_step()
	main.bot_brain.set_physics_process(false)
	main.bot.position = Vector3(8.0, 0.02, -10.0)
	var scripted := ScriptedInput.new()
	main.player.input = scripted
	main.kick.input = scripted
	main.player.reset_at(Vector3(0.0, 0.02, 7.0), Vector3(0.0, 0.0, -1.0))
	main.ball.claim_by(main.player)
	main.player._claim_ball_after_steal()
	assert(is_equal_approx(main.player.walk_speed, MovementTuning.WALK_SPEED), "Match walk speed must use shared tuning")
	assert(is_equal_approx(main.player.sprint_speed, MovementTuning.SPRINT_SPEED), "Match sprint speed must use shared tuning")
	assert(is_equal_approx(main.player.dive_speed, MovementTuning.DIVE_SPEED), "Match dive speed must use shared tuning")
	assert(is_equal_approx(main.player.jump_speed, MovementTuning.NORMAL_JUMP_SPEED), "Match jump must use reduced impulse")

	scripted.move = Vector2(0.0, 1.0)
	scripted.sprinting = true
	for _frame in 24:
		await _physics_step()
	scripted.jump = true
	scripted.tackle = true
	await _physics_step()
	assert(main.ball.carrier == main.player, "Match possession must remain with its carrier")
	assert(is_zero_approx(main.player.tackle_timer), "Carrier must not start a sweep")
	assert(is_zero_approx(main.player._dive_timer), "Carrier must not start a sprint dive")
	assert(main.player.velocity.y < 1.0, "Carrier must not jump")

	scripted.move = Vector2.ZERO
	scripted.sprinting = false
	scripted.jump = false
	scripted.tackle = false
	main.ball.release_from(main.player)
	main.player.dribble_lock = 0.3
	main.ball.reset_to(main.player.global_position + Vector3(0.0,0.26,3.0))
	await _physics_step()
	assert(main.ball.carrier == null, "Kicked ball must remain released during the dribble lock")
	scripted.jump = true
	await _physics_step()
	assert(main.player.velocity.y > MovementTuning.NORMAL_JUMP_SPEED * 0.8, "Jump must be available once possession is released")
	scripted.jump = false
	var ground_y: float = main.player.global_position.y
	var measured_height := 0.0
	for frame in 90:
		await _physics_step()
		measured_height = maxf(measured_height, main.player.global_position.y - ground_y)
		if frame > 8 and main.player.is_on_floor():
			break
	assert(measured_height > new_jump_height * 0.92 and measured_height < new_jump_height * 1.12, "Measured match jump height must match the 40% reduction")
	assert(is_equal_approx(main.player.dive_jump_speed, MovementTuning.DIVE_JUMP_SPEED), "Match dive lift must remain unchanged")
	scripted.tackle = true
	await _physics_step()
	assert(main.player.tackle_timer > 0.0, "Sweep must be available after releasing the ball")
	main.queue_free()
	await get_tree().process_frame


func _test_sandbox_rules() -> void:
	var preview := PreviewScene.instantiate()
	get_tree().root.add_child(preview)
	await get_tree().process_frame
	var actor: Node3D = preview.characters[preview.selected]
	actor.position = Vector3(preview.ball.position.x,0.0,preview.ball.position.z+0.7)
	actor.rotation.y = 0.0
	actor.call("play",0)
	preview._update_sandbox_ball()
	assert(preview._carrier_index == preview.selected, "Sandbox player must pick up the ball by approaching it")
	for unused in 20:
		await _physics_step()
	assert(preview.ball.position.distance_to(actor.position) < 1.2, "Sandbox ball must settle within foot reach")
	assert(preview.ball.position.y >= preview.ball.radius-0.01, "Sandbox ball must stay above the physical pitch")
	assert(is_equal_approx(preview.walk_speed, MovementTuning.WALK_SPEED), "Sandbox walk speed must use shared tuning")
	assert(is_equal_approx(preview.sprint_speed, MovementTuning.SPRINT_SPEED), "Sandbox sprint speed must use shared tuning")

	actor.call("play", 0)
	preview._start_action(2)
	assert(is_zero_approx(preview._vertical_velocity[preview.selected]), "Sandbox carrier must not jump")
	preview._start_action(5)
	assert(actor.get("animation") != 5, "Sandbox carrier must not sweep")
	var sandbox_input := ScriptedInput.new()
	preview.kick_controller.input = sandbox_input
	sandbox_input.kick = true
	for unused in 22:
		await _physics_step()
	assert(preview.kick_controller.charging and preview.kick_controller._preview.visible,"Sandbox must show the shared shot preview while charging")
	sandbox_input.kick = false
	await _physics_step()
	assert(preview._carrier_index == -1, "Sandbox kick must release possession")
	assert(preview.ball.linear_velocity.length() > 5.0,"Sandbox kick must launch the physical ball")
	for unused in 22:
		await _physics_step()
	preview.ball.reset_to(actor.position-actor.basis.z*0.7+Vector3.UP*0.23)
	for unused in 10:
		await _physics_step()
	assert(preview._carrier_index == preview.selected, "Released sandbox ball must be playable and recoverable")
	assert(is_equal_approx(preview.dive_speed, MovementTuning.DIVE_SPEED), "Sandbox dive speed must share match tuning")
	preview._carrier_index = -1
	preview._ball_pickup_lock = 10.0
	preview.ball.reset_to(Vector3(8.0,0.23,8.0))
	preview._action_timers[preview.selected] = 0.0
	preview._vertical_velocity[preview.selected] = 0.0
	actor.position.y = 0.0
	actor.call("play",0)
	preview._start_action(2)
	assert(is_equal_approx(preview._vertical_velocity[preview.selected],MovementTuning.NORMAL_JUMP_SPEED), "Sandbox jump must use the reduced shared impulse")
	var old_jump_height := 12.0 * 12.0 / (2.0 * MovementTuning.GRAVITY)
	var new_jump_height := MovementTuning.NORMAL_JUMP_SPEED * MovementTuning.NORMAL_JUMP_SPEED / (2.0 * MovementTuning.GRAVITY)
	var measured_height := 0.0
	for frame in 90:
		preview._controls(1.0/60.0)
		measured_height = maxf(measured_height,actor.position.y)
		if frame > 8 and is_zero_approx(preview._vertical_velocity[preview.selected]):
			break
	assert(measured_height > new_jump_height * 0.92 and measured_height < new_jump_height * 1.12, "Measured sandbox jump height must match the 40% reduction")
	preview.queue_free()
	await get_tree().process_frame


func _physics_step() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
