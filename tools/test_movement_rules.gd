extends Node
## Verifies 2v2 setup, shared pitch pace, hop, possession locks and keeper action.

const MainScene := preload("res://scenes/main.tscn")
const PreviewScene := preload("res://scenes/visual_prototype.tscn")
const ScriptedInput := preload("res://tools/scripted_input.gd")
const MovementTuning := preload("res://scripts/movement_tuning.gd")
const Field := preload("res://scripts/field_config.gd")
const InputHub := preload("res://scripts/input_hub.gd")
var _failed := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_held_modifier_input()
	var hop_height := MovementTuning.NORMAL_JUMP_SPEED**2/(2.0*MovementTuning.GRAVITY)
	_require(absf(hop_height-0.6)<0.01,"Normal hop must reach about 0.6 m")
	_require(MovementTuning.WALK_SPEED<8.0 and MovementTuning.SPRINT_SPEED<=10.0,"Movement should use human-scale football speeds")
	_require(Field.LENGTH/MovementTuning.SPRINT_SPEED>10.0,"A full pitch sprint must take over ten seconds even without fatigue")
	_require(is_equal_approx(Field.LENGTH,94.0) and is_equal_approx(Field.WIDTH,60.0),"Shared pitch uses Rematch's reported 94 by 60 metres")
	_require(is_equal_approx(Field.GOAL_WIDTH,8.0) and is_equal_approx(Field.GOAL_HEIGHT,3.5),"Shared goals are 8 by 3.5 metres")
	await _test_match_rules()
	await _test_aimed_shots()
	await _test_rising_shots()
	await _test_sandbox_dimensions()
	if not _failed:
		print("FOOTBALL PACE PASS: 94x60 pitch, held pass targeting/cancellation, short sprint budget, 2v2 and keeper saves")
	get_tree().quit(1 if _failed else 0)


func _test_held_modifier_input() -> void:
	var hub := InputHub.new()
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index=MOUSE_BUTTON_RIGHT
	mouse_event.pressed=true
	Input.parse_input_event(mouse_event)
	Input.flush_buffered_events()
	_require(hub.pass_aim_held(),"Pressing RMB must hold the pass modifier")
	mouse_event=mouse_event.duplicate()
	mouse_event.pressed=false
	Input.parse_input_event(mouse_event)
	Input.flush_buffered_events()
	_require(not hub.pass_aim_held(),"Releasing RMB must release the pass modifier")
	hub.device=0
	var trigger := InputEventJoypadMotion.new()
	trigger.device=0
	trigger.axis=JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value=1.0
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()
	_require(hub.pass_aim_held(),"Left trigger holds the same pass modifier on controller")
	trigger=trigger.duplicate()
	trigger.axis_value=0.0
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()
	_require(not hub.pass_aim_held(),"Releasing left trigger must exit pass aim")


func _test_match_rules() -> void:
	var hop_height := MovementTuning.NORMAL_JUMP_SPEED**2/(2.0*MovementTuning.GRAVITY)
	var main := MainScene.instantiate()
	get_tree().root.add_child(main)
	await _physics_step()
	for brain in main.ai_brains:
		brain.set_physics_process(false)
	_require(main.teammates.size()==2 and main.opponents.size()==2,"Match must have 2v2 teams")
	_require(is_equal_approx(main.player.walk_speed,MovementTuning.WALK_SPEED),"Match walk speed uses shared tuning")
	_require(is_equal_approx(main.player.sprint_speed,MovementTuning.SPRINT_SPEED),"Match sprint speed uses shared tuning")
	_require(is_equal_approx(main.ally.walk_speed,main.player.walk_speed),"AI ally movement speed matches player")
	var scripted := ScriptedInput.new()
	main.player.input = scripted
	main.kick.input = scripted
	main.player.reset_at(Vector3(0.0,0.02,12.0),Vector3(0,0,-1))
	main.ball.claim_by(main.player)
	scripted.sprinting = true
	scripted.jump = true
	scripted.tackle = true
	await _physics_step()
	_require(main.ball.carrier==main.player,"Possession remains with its carrier")
	_require(is_zero_approx(main.player.tackle_timer),"Carrier cannot sweep")
	_require(is_zero_approx(main.player._dive_timer),"Carrier cannot dive")
	_require(main.player.velocity.y<1.0,"Carrier cannot hop")

	scripted.jump=false
	scripted.tackle=false
	scripted.sprinting=false
	await _physics_step()
	main.ball.release_from(main.player)
	main.player.reset_at(Vector3(0.0,0.02,Field.HALF_LENGTH-6.0),Vector3(0,0,-1))
	main.ball.reset_to(main.player.global_position+Vector3(0.1,0.82,0.25))
	scripted.move=Vector2(1,0)
	scripted.sprinting=true
	scripted.jump=true
	await _physics_step()
	_require(main.player._keeper_dive,"Sprint + Space in own goal area must start a keeper dive")
	_require(main.player._dive_direction.x>0.9 and main.player._dive_direction.z>0.0 and main.player._dive_direction.z<0.2,"A/D selects the side with slight ball-path assistance")
	_require(main.ball.carrier==main.player,"Clean goalkeeper contact catches the ball")
	_require(main.player.dive_speed==MovementTuning.DIVE_SPEED,"Normal running and sweep tuning stays intact")
	main.ball.release_from(main.player)
	scripted.jump=false
	scripted.sprinting=false
	scripted.move=Vector2.ZERO
	await _physics_step()
	main.player.reset_at(Vector3(0.0,0.02,Field.HALF_LENGTH-6.0),Vector3(0,0,-1))
	main.ball.reset_to(Vector3(14.0,0.24,Field.HALF_LENGTH-6.0))
	await _physics_step()
	scripted.move=Vector2(1,0)
	scripted.sprinting=true
	scripted.jump=true
	await _physics_step()
	_require(main.player._keeper_dive and main.ball.carrier==null,"A miss remains a dive without granting possession")
	for _frame in 42:
		await _physics_step()
	_require(main.player._keeper_recovery_timer>0.0,"A missed keeper dive has recovery time")
	scripted.jump=false
	scripted.sprinting=false
	scripted.move=Vector2.ZERO
	main.player.position = Vector3(0.0,0.02,10.0)
	main.ally.position = Vector3(0.0,0.02,7.0)
	main.bot.position = Vector3(10.0,0.02,-12.0)
	main.enemy_second.position = Vector3(-10.0,0.02,-14.0)
	main.player.facing=Vector3(0,0,-1)
	main.camera.global_position=Vector3(0.0,4.0,18.0)
	main.camera.look_at(main.ally.global_position+Vector3.UP*0.8)
	main.ball.reset_to(Vector3(0.0,0.22,9.25))
	main.ball.claim_by(main.player)
	scripted.pass_aim=true
	main.kick._physics_process(1.0/60.0)
	_require(main.kick.pass_aiming,"Pass aim is active while the modifier is held")
	_require(main.kick.pass_target==main.ally and main.kick._pass_target_ring.visible,"The receiver is highlighted without a center crosshair")
	scripted.pass_aim=false
	main.kick._physics_process(1.0/60.0)
	_require(not main.kick.pass_aiming and not main.kick._pass_target_ring.visible,"Releasing RMB hides the ring immediately; aim is not a toggle")
	scripted.pass_aim=true
	main.kick._physics_process(1.0/60.0)
	scripted.kick=true
	main.kick._physics_process(0.15)
	scripted.pass_aim=false
	main.kick._physics_process(1.0/60.0)
	_require(main.kick.charging,"Releasing aim preserves a charged pass")
	scripted.kick=false
	main.kick._physics_process(1.0/60.0)
	_require(main.ball.carrier==null and is_zero_approx(main.ball.linear_velocity.y),"Releasing LMB after RMB sends the stored pass")
	main.ball.reset_to(main.player.global_position+Vector3(0,0.22,-0.75))
	main.ball.claim_by(main.player)
	main.kick.cancel_charge()
	main.kick.cooldown_timer=0.0
	main.ally.position=Vector3(2.0,0.02,4.0)
	main.kick.use_aim_override=true
	main.kick.aim_override=Vector3(0,0,-1)
	scripted.pass_aim=true
	main.kick._physics_process(1.0/60.0)
	_require(main.kick.pass_target==main.ally,"Off-center teammates are selectable in the aim cone")
	var farther_mate := Node3D.new()
	main.add_child(farther_mate)
	farther_mate.position=Vector3(4.0,0.02,-2.0)
	main.kick.teammates.append(farther_mate)
	main.kick._physics_process(1.0/60.0)
	_require(main.kick.pass_target==main.ally,"The nearer receiver wins among aligned teammates")
	main.kick.teammates.erase(farther_mate)
	farther_mate.queue_free()
	main.kick.aim_override=Vector3(0,0,1)
	main.kick._physics_process(1.0/60.0)
	scripted.kick=true
	main.kick._physics_process(0.1)
	scripted.kick=false
	main.kick._physics_process(1.0/60.0)
	_require(main.ball.carrier==null and main.ball.linear_velocity.z>0.0,"Aiming away from teammates permits a shot")
	main.ball.reset_to(main.player.global_position+Vector3(0,0.22,-0.75))
	main.ball.claim_by(main.player)
	main.kick.cancel_charge()
	main.kick.cooldown_timer=0.0
	main.kick.aim_override=Vector3(0,0,-1)
	main.kick._physics_process(1.0/60.0)
	scripted.kick=true
	main.kick._physics_process(0.1)
	main.kick.charge=0.5
	scripted.kick=false
	main.kick._physics_process(1.0/60.0)
	_require(main.ball.carrier==null,"Charged pass releases possession")
	_require(is_zero_approx(main.ball.linear_velocity.y),"Pass stays ground oriented")
	main.ally.input.move=Vector2.ZERO
	main.ball.reset_to(main.ally.global_position+Vector3(0.0,0.22,-0.7))
	for _frame in 4:
		await _physics_step()
	_require(main.ball.carrier==main.ally,"A teammate controls a received pass")
	main.ball.reset_to(Vector3(0.0,0.22,-Field.HALF_LENGTH+12.0))
	main.kick.aim_override=Vector3(0,0,-1)
	main.kick.charge=0.87
	var clean_path: Array=main.kick.preview_points()
	_require(clean_path.size()>3,"Shot preview predicts a full trajectory")
	_require(main.kick.preview_goal,"Clear shot preview marks a goal crossing")
	main.ball.reset_to(Vector3(Field.GOAL_WIDTH*0.5-0.2,0.3,-Field.HALF_LENGTH+12.0))
	var frame_path: Array=main.kick.preview_points()
	_require(main.kick.preview_impact,"Shot preview stops at a goalpost impact")
	_require(not main.kick.preview_goal,"A frame collision is not marked as a goal")
	main.player.global_position=Vector3(0.0,0.0,1.0)
	main.player._tackle_hit=false
	main.bot.protection=0.0
	main.bot.knocked_out=0.0
	main.bot.global_position=Vector3(0.0,hop_height,0.0)
	main.player._check_tackle_hit(Vector3(0.0,0.0,2.0))
	_require(is_zero_approx(main.bot.knocked_out),"A hop at its apex clears the sweep through height")
	main.bot.global_position.y=hop_height-0.2
	main.player._check_tackle_hit(Vector3(0.0,0.0,2.0))
	_require(main.bot.knocked_out>0.0,"A low or late hop remains vulnerable to the sweep")
	# The tackle intentionally triggered real-time cosmetic hit-stop. Isolate the
	# simulation clock before measuring a sprint budget in fixed-step headless runs.
	Juice._hitstop_until=0
	Engine.time_scale=1.0
	main.ball.reset_to(Vector3(-20.0,0.22,0.0))
	main.player.reset_at(Vector3(18.0,0.02,32.0),Vector3(0,0,-1))
	scripted.pass_aim=false
	scripted.move=Vector2(0,1)
	scripted.sprinting=true
	for _frame in 234:
		await _physics_step()
	_require(main.player.exhausted and main.player.stamina<1.0,"Continuous sprint must actually exhaust its budget in under four seconds")
	_require(not main.player.sprinting and main.player.velocity.length()<=main.player.walk_speed+0.2,"An exhausted player returns to running rather than pulsing sprint")
	_require(main.player.global_position.z> -5.0,"A short sprint cannot cross the pitch")
	scripted.sprinting=false
	scripted.move=Vector2.ZERO
	for _frame in 30:
		await _physics_step()
	_require(main.player.stamina<1.0,"Stamina has a regeneration delay after sprint ends")
	for _frame in 170:
		await _physics_step()
	_require(main.player.stamina>=MovementTuning.STAMINA_RESTART and not main.player.exhausted,"Stamina recovers and unlocks sprint after the recovery threshold")
	_require(Field.in_keeper_area(Vector3(0,0,-Field.HALF_LENGTH+6.0),1),"Far-end keeper area follows the resized goal")
	_require(not Field.in_keeper_area(Vector3(0,0,18.0),0),"Old keeper positions now perform a normal hop")
	main.player_score=3
	main.bot_score=2
	main._physics_process(0.0)
	main.hud._process(0.0)
	_require(main.hud._scoreboard.blue_score==3 and main.hud._scoreboard.pink_score==2,"Centered scoreboard displays live team scores")
	main.set_physics_process(false)
	for actor in [main.player,main.ally,main.bot,main.enemy_second]:
		actor.set_physics_process(false)
	for controller in [main.kick]+main.ai_kicks:
		controller.set_physics_process(false)
	await _test_enclosure(main,main.ball)
	main.queue_free()
	await get_tree().process_frame


func _test_aimed_shots() -> void:
	var main := MainScene.instantiate()
	get_tree().root.add_child(main)
	await _physics_step()
	for brain in main.ai_brains:
		brain.set_physics_process(false)
	for actor in [main.ally,main.bot,main.enemy_second]:
		actor.set_physics_process(false)
	main.ally.position=Vector3(-25,0,-10)
	main.bot.position=Vector3(-25,0,-30)
	main.enemy_second.position=Vector3(25,0,-30)
	var scripted := ScriptedInput.new()
	main.player.input=scripted
	main.kick.input=scripted
	main.kick.use_aim_override=true
	main.kick.aim_override=Vector3.FORWARD
	main.player.reset_at(Vector3(10,0.02,0),Vector3.FORWARD)
	main.ball.reset_to(Vector3(10,0.23,-0.75))
	await _physics_step()
	main.ball.claim_by(main.player)
	scripted.pass_aim=true
	main.kick._physics_process(1.0/60.0)
	_require(main.kick.aiming and not main.kick.pass_aiming,"RMB aims shots when no teammate is selected")
	_require(main.kick._preview.visible and not main.kick.charging,"RMB shows the trajectory before LMB is pressed")
	scripted.kick=true
	main.kick._physics_process(0.3)
	var previous_charge: float = main.kick.charge
	scripted.pass_aim=false
	main.kick._physics_process(1.0/60.0)
	main.kick.aim_override=Vector3.RIGHT
	main.kick._physics_process(1.0/60.0)
	_require(main.kick.charging and main.kick.charge>previous_charge,"Releasing RMB keeps LMB charging")
	_require(main.kick.aim_dir().dot(Vector3.FORWARD)>0.999,"A charge retains its direction when RMB is released and the camera moves")
	_require(not main.kick._preview.visible,"The parabola disappears when RMB is released, even while charging")
	main.kick.charge=1.0
	scripted.kick=false
	main.kick._physics_process(1.0/60.0)
	_require(main.ball.carrier==null and main.ball.linear_velocity.z< -38.0 and absf(main.ball.linear_velocity.x)<0.01,"LMB release fires full power in the retained direction")
	var launched_at: Vector3 = main.ball.position
	for _frame in 45:
		await _physics_step()
	var travel: float = launched_at.z-main.ball.position.z
	_require(travel>25.0,"A fully charged shot must physically travel over 25 metres in 0.75 seconds")
	print("SHOT POWER CHECK travel_0.75s=",snappedf(travel,0.01)," metres")
	main.player.reset_at(Vector3(0,0.02,-Field.HALF_LENGTH+3.0),Vector3.FORWARD)
	main.ball.reset_to(main.player.position+Vector3(0,0.23,-0.75))
	main.kick.aim_override=Vector3.FORWARD
	await _physics_step()
	main.ball.claim_by(main.player)
	var score_before: int = main.player_score
	_require(main.kick.force_kick(1.0,Vector3.FORWARD),"Close-range full-power shot must launch")
	for _frame in 12:
		await _physics_step()
	_require(main.player_score>score_before,"A shot about two metres from goal must enter the net")
	main.player.reset_at(Vector3(18,0.02,0),Vector3.FORWARD)
	main.ball.reset_to(Vector3(18,0.23,-0.75))
	await _physics_step()
	main.ball.claim_by(main.player)
	main.kick.cooldown_timer=0.0
	scripted.pass_aim=false
	scripted.kick=true
	main.kick._physics_process(0.1)
	_require(main.kick.charging and not main.kick._preview.visible,"LMB alone charges without drawing the parabola")
	var painter = main.hud._painter
	_require(painter.get_script()==preload("res://scripts/ui/hud_painter.gd"),"Match uses the shared playground meter renderer")
	var power_rect: Rect2 = painter.power_rect(1600.0)
	_require(power_rect.size.y>power_rect.size.x*4.0 and power_rect.position.x>800.0,"Power meter is vertical and offset right of center")
	main.queue_free()
	await get_tree().process_frame


func _test_sandbox_dimensions() -> void:
	var sandbox := PreviewScene.instantiate()
	get_tree().root.add_child(sandbox)
	await get_tree().process_frame
	_require(is_equal_approx(sandbox.walk_speed,MovementTuning.WALK_SPEED),"Sandbox walk speed uses shared tuning")
	_require(is_equal_approx(sandbox.sprint_speed,MovementTuning.SPRINT_SPEED),"Sandbox sprint speed uses shared tuning")
	_require(sandbox.kick_controller.teammates.size()==2,"Sandbox uses the same held teammate passing system")
	_require(sandbox.hud._meters.get_script()==preload("res://scripts/ui/hud_painter.gd"),"Playground shares the exact stamina and power renderer with matches")
	for _frame in 235:
		sandbox._sprinting=sandbox._stamina[0]>0.0 and not sandbox._exhausted[0]
		sandbox._update_sandbox_stamina(1.0/60.0)
	_require(sandbox._exhausted[0] and sandbox._stamina[0]<1.0,"Sandbox uses the same finite sprint budget")
	_require(is_equal_approx(Field.LENGTH,94.0) and is_equal_approx(Field.WIDTH,60.0),"Sandbox uses shared pitch dimensions")
	sandbox.set_process(false)
	sandbox.characters[0].position=Vector3.ZERO
	sandbox.characters[1].position=Vector3(-2,0,-6)
	sandbox.camera.position=Vector3(0,4,8)
	sandbox.camera.look_at(sandbox.characters[1].position+Vector3.UP)
	sandbox.ball.reset_to(Vector3(0,0.23,-0.75))
	await _physics_step()
	sandbox._carrier_index=0
	sandbox.ball.claim_by(sandbox.characters[0])
	var scripted := ScriptedInput.new()
	scripted.pass_aim=true
	sandbox.kick_controller.input=scripted
	sandbox.kick_controller.aim_override=Vector3.FORWARD
	sandbox.kick_controller._physics_process(1.0/60.0)
	_require(sandbox.kick_controller.pass_target==sandbox.characters[1],"Sandbox selects the aimed teammate with the shared controller")
	scripted.kick=true
	sandbox.kick_controller._physics_process(0.1)
	scripted.kick=false
	sandbox.kick_controller._physics_process(1.0/60.0)
	_require(sandbox._carrier_index==-1 and sandbox.ball.carrier==null,"Sandbox passing releases both possession states")
	_require(sandbox._ball_pickup_lock>0.0 and sandbox.ball.linear_velocity.z<0.0,"Sandbox plays the pass and prevents immediate pickup")
	for ratio in [0.65,1.0]:
		sandbox.ball.reset_to(Vector3(0,0.23,-0.75))
		await _physics_step()
		sandbox._carrier_index=0
		sandbox.ball.claim_by(sandbox.characters[0])
		var expected: Vector3 = sandbox.kick_controller.shot_velocity(ratio,Vector3.FORWARD)
		_require(sandbox.kick_controller.force_kick(ratio,Vector3.FORWARD),"Sandbox must launch both controlled and full-power shots")
		_require(sandbox.ball.linear_velocity.is_equal_approx(expected),"Sandbox uses the same rising launch calculation as the match")
	sandbox.kick_controller.set_physics_process(false)
	await _test_enclosure(sandbox,sandbox.ball)
	sandbox.queue_free()
	await get_tree().process_frame


func _test_rising_shots() -> void:
	var main := MainScene.instantiate()
	get_tree().root.add_child(main)
	await _physics_step()
	main.set_physics_process(false)
	main.kick.set_physics_process(false)
	for brain in main.ai_brains:
		brain.set_physics_process(false)
	for actor in [main.player,main.ally,main.bot,main.enemy_second]:
		actor.set_physics_process(false)
	main.ally.position=Vector3(-25,0,0)
	main.bot.position=Vector3(-25,0,-30)
	main.enemy_second.position=Vector3(25,0,-30)
	main.kick.use_aim_override=true
	main.kick.aim_override=Vector3.FORWARD
	var medium: Dictionary = await _sample_power_shot(main,0.65)
	_require(medium.preview_goal and medium.scored,"A 65% shot from about 14 m must be predicted and recorded as a goal")
	_require(medium.crossing_height>0.22 and medium.crossing_height<Field.GOAL_HEIGHT-0.22,"Medium power must cross safely below the bar")
	var full: Dictionary = await _sample_power_shot(main,1.0)
	_require(not full.preview_goal and not full.scored,"Full power from about 14 m must miss high in physics and preview")
	_require(full.preview_impact and full.rebounded and full.contact_height>Field.GOAL_HEIGHT+0.22,"A full-power high miss must rebound off the transparent wall above the goal")
	_require(full.launch_speed>medium.launch_speed and is_equal_approx(full.launch_speed,40.0),"Full power retains the strongest 40 m/s launch")
	for step in 101:
		_require(main.kick.shot_speed(step/100.0)<=full.launch_speed+0.001,"No intermediate charge may exceed maximum shot speed")
	var frame: Dictionary = await _sample_power_shot(main,0.93)
	_require(frame.preview_impact and not frame.preview_goal and frame.rebounded,"The trajectory must distinguish a physical crossbar hit from goals and high misses")
	print("RISING SHOT CHECK distance=14.5m medium_y=",snappedf(float(medium.crossing_height),0.01)," high_wall_y=",snappedf(float(full.contact_height),0.01)," crossbar_rebound=",frame.rebounded)
	main.queue_free()
	await get_tree().process_frame


func _sample_power_shot(main: Node, ratio: float) -> Dictionary:
	Juice._hitstop_until=0
	Engine.time_scale=1.0
	main._pending_reset=0.0
	main.get_node("FarGoal")._cooldown=0.0
	var start := Vector3(0,0.23,-Field.HALF_LENGTH+14.5)
	main.player.reset_at(start+Vector3(0,-0.21,0.75),Vector3.FORWARD)
	main.ball.reset_to(start)
	await _physics_step()
	main.ball.claim_by(main.player)
	main.kick.preview_points(ratio)
	var result := {"preview_goal":main.kick.preview_goal,"preview_impact":main.kick.preview_impact,"crossing_height":-1.0,"contact_height":-1.0,"rebounded":false,"scored":false,"launch_speed":0.0}
	var score_before: int = main.player_score
	_require(main.kick.force_kick(ratio,Vector3.FORWARD),"The rising shot test must launch")
	result.launch_speed=main.ball.linear_velocity.length()
	for _frame in 90:
		var before: Vector3 = main.ball.position
		await _physics_step()
		var after: Vector3 = main.ball.position
		if before.z> -Field.HALF_LENGTH and after.z<= -Field.HALF_LENGTH:
			var fraction := (-Field.HALF_LENGTH-before.z)/(after.z-before.z)
			result.crossing_height=lerpf(before.y,after.y,fraction)
			break
		if main.ball.linear_velocity.z>1.0:
			result.rebounded=true
			result.contact_height=after.y
			break
	result.scored=main.player_score>score_before
	return result


func _test_enclosure(scene: Node3D, ball: RigidBody3D) -> void:
	Juice._hitstop_until=0
	Engine.time_scale=1.0
	var walls := get_tree().get_nodes_in_group("arena_rebound_walls")
	_require(walls.size()==8,"Both arenas use the same eight solid transparent wall sections")
	var space := scene.get_world_3d().direct_space_state
	for sign_value in [-1.0,1.0]:
		var cases := [
			[Vector3(sign_value*(Field.HALF_WIDTH-2),6,0),Vector3(sign_value,0,0)],
			[Vector3(10,6,sign_value*(Field.HALF_LENGTH-2)),Vector3(0,0,sign_value)],
			[Vector3(0,6,sign_value*(Field.HALF_LENGTH-2)),Vector3(0,0,sign_value)],
			[Vector3(sign_value*(Field.HALF_WIDTH-2),6,Field.HALF_LENGTH-2),Vector3(sign_value,0,1).normalized()]
		]
		for pair in cases:
			ball.reset_to(pair[0])
			await _physics_step()
			for _flush in 3:
				if not ball.get("_reset_pending"):
					break
				await _physics_step()
			var direction: Vector3=pair[1]
			ball.linear_velocity=direction*22.0
			var bounced := false
			for _frame in 24:
				await _physics_step()
				if ball.linear_velocity.dot(direction)< -1.0:
					bounced=true
					break
			_require(bounced,"Ball must rebound from arena wall at %s heading %s; ended at %s with velocity %s" % [pair[0],direction,ball.position,ball.linear_velocity])
			_require(absf(ball.position.x)<=Field.HALF_WIDTH and absf(ball.position.z)<=Field.HALF_LENGTH,"A rebound must keep the ball inside the arena")
		var start := Vector3(0,1,sign_value*(Field.HALF_LENGTH-1))
		var finish := Vector3(0,1,sign_value*(Field.HALF_LENGTH+0.1))
		var query := PhysicsRayQueryParameters3D.create(start,finish,1)
		query.exclude=[ball.get_rid()]
		_require(space.intersect_ray(query).is_empty(),"Transparent walls must preserve the low goal opening")
	print("ENCLOSURE CHECK: eight clear wall sections, both ends, high rebounds, corners and open goal mouths")


func _physics_step() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed=true
		push_error(message)
		get_tree().quit(1)
