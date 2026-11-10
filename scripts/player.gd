extends CharacterBody3D
const SweepMotion := preload("res://scripts/sweep_motion.gd")
const MovementTuning := preload("res://scripts/movement_tuning.gd")
## Arcade footballer: movement, stamina, magnetic dribbling, slide tackles
## and knockdown recovery. Works for both human and AI input sources.

@export_group("Movement")
@export var walk_speed := MovementTuning.WALK_SPEED
@export var sprint_speed := MovementTuning.SPRINT_SPEED
@export var acceleration := MovementTuning.ACCELERATION
@export var deceleration := MovementTuning.DECELERATION
@export var turn_speed := 32.0
@export var gravity := MovementTuning.GRAVITY
@export var jump_speed := MovementTuning.NORMAL_JUMP_SPEED
@export var dive_speed := MovementTuning.DIVE_SPEED
@export var dive_jump_speed := MovementTuning.DIVE_JUMP_SPEED
@export var dive_duration := 0.9
@export var speed_multiplier := 1.0

@export_group("Stamina")
@export var stamina_max := 100.0
@export var stamina_drain := 14.0
@export var stamina_regen := 25.0
@export var stamina_delay := 0.5
@export var sprint_min_stamina := 10.0
@export var exhaustion_time := 1.2

@export_group("Dribbling")
@export var dribble_radius := 1.45
@export var dribble_speed_limit := 14.0
@export var dribble_grip := 22.0

@export_group("Tackle")
@export var tackle_duration := SweepMotion.MOTION_TIME
@export var tackle_recovery := SweepMotion.RECOVERY_TIME
@export var tackle_cooldown := SweepMotion.COOLDOWN
@export var tackle_radius := 1.55
@export var tackle_knockback := 9.0
@export var tackle_ball_push := 8.0

@export_group("Look")
@export var body_color := Color(0.18, 0.62, 1.0)
@export var visual_scene: PackedScene = preload("res://scenes/visuals/character.tscn")
@export var character_look: Resource = preload("res://assets/characters/pip.tres")

var input: RefCounted
var camera: Node3D
var ball: RigidBody3D
var kick: Node
var opponent: Node3D

var stamina := 100.0
var sprinting := false
var exhausted := false
var exhaust_timer := 0.0
var regen_timer := 0.0
var dribble_lock := 0.0

var facing := Vector3(0.0, 0.0, -1.0)
var knocked_out := 0.0
var protection := 0.0
var camera_relative := true

var tackle_timer := 0.0
var tackle_recovery_timer := 0.0
var tackle_cooldown_timer := 0.0

var _move_intent := Vector3.ZERO
var _tackle_dir := Vector3.ZERO
var _tackle_hit := false
var _tackle_ball_hit := false
var _was_tackle_held := false
var _was_jump_held := false
var _visual: Node3D
var _leg_pivots: Array[Node3D] = []
var _arm_pivots: Array[Node3D] = []
var _run_phase := 0.0
var _visual_action_animation := 0
var _visual_action_timer := 0.0
var _dive_timer := 0.0
var _dive_direction := Vector3.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	_build_visuals()


func _build_visuals() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.27
	shape.height = 1.1625
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.585, 0.0)
	add_child(collider)
	if visual_scene != null:
		var actor := visual_scene.instantiate() as Node3D
		actor.set("look",character_look)
		actor.set("sweep_duration_override",tackle_duration+tackle_recovery)
		actor.set("sweep_motion_duration",tackle_duration)
		actor.set("jump_duration_override",2.0*jump_speed/gravity)
		actor.set("dive_duration",dive_duration)
		actor.name = "Visual"
		actor.scale = Vector3.ONE*0.8
		add_child(actor)
		actor.set("frozen",true)
		actor.call("play",0)
		actor.call("_pose",0.0)
		# The gameplay controller owns limb timing, jumping and knockdown here.
		actor.set_process(false)
		_visual = actor
		for pivot in [actor.get("left_leg"),actor.get("right_leg")]:
			if pivot is Node3D:
				_leg_pivots.append(pivot)
		for pivot in [actor.get("left_arm"),actor.get("right_arm")]:
			if pivot is Node3D:
				_arm_pivots.append(pivot)
		return

	push_error("Player requires the current character visual scene")


func _physics_process(delta: float) -> void:
	protection = maxf(0.0, protection - delta)
	tackle_cooldown_timer = maxf(0.0, tackle_cooldown_timer - delta)
	var jump_held: bool = input != null and input.jump_held()
	var jump_pressed := jump_held and not _was_jump_held
	_was_jump_held = jump_held
	_update_visual(delta)

	if knocked_out > 0.0:
		_update_knocked(delta)
		_drive_owned_ball(delta)
		return
	if _dive_timer > 0.0:
		_update_dive(delta)
		_drive_owned_ball(delta)
		return

	if tackle_timer > 0.0:
		_update_tackle(delta)
		_drive_owned_ball(delta)
		return

	if tackle_recovery_timer > 0.0:
		tackle_recovery_timer = maxf(0.0,tackle_recovery_timer-delta)
		velocity.x = 0.0
		velocity.z = 0.0
		_brake(delta)
		_drive_owned_ball(delta)
		_was_tackle_held = input != null and input.tackle_held()
		return

	var move: Vector2 = input.move_vector() if input else Vector2.ZERO
	var direction := Vector3(move.x, 0.0, -move.y)
	if camera_relative:
		var yaw: float = camera.yaw if camera else 0.0
		direction = Basis(Vector3.UP, yaw) * direction
	if direction.length() > 0.001:
		direction = direction.normalized()

	var held: bool = input != null and input.tackle_held()
	var pressed: bool = held and not _was_tackle_held
	_was_tackle_held = held
	var carrying_ball: bool = ball != null and ball.carrier == self
	if pressed and not carrying_ball and tackle_cooldown_timer <= 0.0 and is_on_floor():
		_start_tackle()
		return
	if jump_pressed and not carrying_ball and is_on_floor():
		if input != null and input.sprint_held() and direction.length()>0.1 and Vector2(velocity.x,velocity.z).length()>walk_speed*0.7:
			_start_dive(direction)
			_update_dive(delta)
			return
		velocity.y = jump_speed
		_visual_action_timer = 0.0

	var charging: bool = kick != null and kick.charging
	if charging:
		direction.x = 0.0
		if direction.length() > 0.001:
			direction = direction.normalized()

	var can_sprint := stamina > sprint_min_stamina and not exhausted
	sprinting = input != null and input.sprint_held() and direction.length() > 0.1 and can_sprint

	var target_speed := (sprint_speed if sprinting else walk_speed) * speed_multiplier
	if charging:
		target_speed *= 0.55

	var target := direction * target_speed
	_move_intent = target
	var rate := acceleration if direction.length() > 0.1 else deceleration
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	if is_on_floor():
		if velocity.y <= 0.0:
			velocity.y = -0.1
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_check_head_on_steal()

	_update_facing(direction, delta, charging)
	_update_stamina(delta)
	_update_dribble(delta)


func _update_facing(direction: Vector3, delta: float, charging: bool) -> void:
	var wanted := facing
	if charging and kick != null:
		wanted = kick.aim_dir()
	elif direction.length() > 0.1:
		wanted = direction
	wanted.y = 0.0
	if wanted.length() < 0.01:
		return
	facing = facing.slerp(wanted.normalized(), clampf(delta * turn_speed, 0.0, 1.0)).normalized()
	rotation.y = atan2(-facing.x, -facing.z)


func _update_stamina(delta: float) -> void:
	if exhausted:
		exhaust_timer -= delta
		if exhaust_timer <= 0.0:
			exhausted = false

	if sprinting and Vector2(velocity.x, velocity.z).length() > 1.0:
		stamina = maxf(0.0, stamina - stamina_drain * delta)
		regen_timer = stamina_delay
		if stamina <= 0.01:
			exhausted = true
			exhaust_timer = exhaustion_time
	elif regen_timer > 0.0:
		regen_timer -= delta
	elif stamina < stamina_max:
		stamina = minf(stamina_max, stamina + stamina_regen * delta)


func _update_dribble(delta: float) -> void:
	if ball == null:
		return
	if ball.carrier != null and ball.carrier != self:
		return
	if ball.carrier == self:
		_drive_owned_ball(delta)
		return
	if dribble_lock > 0.0:
		dribble_lock -= delta
		return

	var ball_pos := ball.global_position
	var flat := Vector3(ball_pos.x - global_position.x, 0.0, ball_pos.z - global_position.z)
	if flat.length() > dribble_radius:
		return

	var ball_velocity := ball.linear_velocity
	var actual_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var relative := (Vector3(ball_velocity.x, 0.0, ball_velocity.z) - actual_velocity).length()
	if relative > dribble_speed_limit:
		return
	ball.claim_by(self)
	_drive_owned_ball(delta)


func _drive_owned_ball(delta: float) -> void:
	if ball == null or ball.carrier != self:
		return
	var phase: float = _visual.call("dribble_cycle") if _visual != null else -1.0
	ball.drive_controlled(facing,global_basis.x,velocity,phase,delta)


# --- Tackling -------------------------------------------------------------


func _start_tackle() -> void:
	_tackle_dir = facing
	if camera_relative and camera:
		_tackle_dir = Vector3(-sin(camera.yaw), 0.0, -cos(camera.yaw))
	_tackle_dir.y = 0.0
	if _tackle_dir.length() < 0.01:
		_tackle_dir = Vector3(0.0, 0.0, -1.0)
	_tackle_dir = _tackle_dir.normalized()
	facing = _tackle_dir
	rotation.y = atan2(-facing.x,-facing.z)

	tackle_timer = tackle_duration
	_visual_action_animation = 5
	_visual_action_timer = _visual.call("animation_duration",5) if _visual != null and _visual.has_method("animation_duration") else tackle_duration+tackle_recovery
	tackle_cooldown_timer = tackle_cooldown
	_tackle_hit = false
	_tackle_ball_hit = false
	dribble_lock = 0.1
	if kick:
		kick.charging = false


func _update_tackle(delta: float) -> void:
	var previous := tackle_duration-tackle_timer
	tackle_timer = maxf(0.0,tackle_timer-delta)
	var elapsed := tackle_duration-tackle_timer
	var speed := (SweepMotion.distance_at(elapsed,sprint_speed*speed_multiplier)-SweepMotion.distance_at(previous,sprint_speed*speed_multiplier))/maxf(delta,0.0001)

	var previous_position := global_position
	velocity.x = _tackle_dir.x * speed
	velocity.z = _tackle_dir.z * speed
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	_check_tackle_hit(previous_position)
	_push_ball_on_tackle()

	_was_tackle_held = input != null and input.tackle_held()
	if tackle_timer <= 0.0:
		tackle_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		tackle_recovery_timer = tackle_recovery


func _check_tackle_hit(previous_position: Vector3) -> void:
	if _tackle_hit or opponent == null:
		return
	# Check the whole sweep step, so a fast burst cannot skip over a target
	# between physics frames.
	var segment_start := Vector2(previous_position.x,previous_position.z)
	var segment_end := Vector2(global_position.x,global_position.z)
	var target_position := Vector2(opponent.global_position.x,opponent.global_position.z)
	var segment := segment_end-segment_start
	var segment_length_squared := segment.length_squared()
	var closest_fraction := clampf((target_position-segment_start).dot(segment)/segment_length_squared,0.0,1.0) if segment_length_squared>0.0001 else 1.0
	var closest_point := segment_start+segment*closest_fraction
	var from_contact := target_position-closest_point
	if from_contact.length() > tackle_radius:
		return

	_tackle_hit = true
	var push_direction := Vector3(from_contact.x,0.0,from_contact.y)
	if push_direction.length()<0.01:
		push_direction = _tackle_dir
	if opponent.has_method("knockdown"):
		opponent.knockdown(push_direction.normalized(), tackle_knockback, 1.7)
	if ball != null and ball.carrier == opponent:
		# The tackle hit is the possession check; the ball may already have rolled
		# away from the carrier's feet during this same sweep frame.
		_claim_ball_after_steal()
		opponent.dribble_lock = 0.0
		_tackle_ball_hit = true
	Juice.add_shake(0.75)
	Juice.hitstop(0.05)


func _push_ball_on_tackle() -> void:
	if _tackle_ball_hit or ball == null:
		return
	if ball.carrier == self:
		return
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	if to_ball.length() > 1.15:
		return
	_tackle_ball_hit = true
	if ball.carrier == null or ball.carrier == opponent:
		_claim_ball_after_steal()
		if opponent != null:
			opponent.dribble_lock = 0.0
		return
	ball.linear_velocity = _tackle_dir * tackle_ball_push + Vector3.UP * 1.5


func _claim_ball_after_steal() -> void:
	ball.claim_by(self)
	var target := global_position + facing * 0.78 + global_basis.x * 0.22
	target.y = ball.radius + 0.02
	ball.global_position = target
	ball.linear_velocity = Vector3(velocity.x,0.0,velocity.z)
	ball.reset_physics_interpolation()


func _check_head_on_steal() -> void:
	if opponent == null or ball == null or ball.carrier != opponent:
		return
	for index in get_slide_collision_count():
		if get_slide_collision(index).get_collider() != opponent:
			continue
		var to_opponent := opponent.global_position - global_position
		to_opponent.y = 0.0
		if to_opponent.length() < 0.01:
			return
		var approach := Vector3(_move_intent.x,0.0,_move_intent.z)
		if approach.length() < 0.01 or approach.normalized().dot(to_opponent.normalized()) < 0.6:
			return
		var opponent_facing: Vector3 = opponent.get("facing")
		if opponent_facing.dot(-to_opponent.normalized()) < 0.25:
			return
		facing = approach.normalized()
		rotation.y = atan2(-facing.x,-facing.z)
		_claim_ball_after_steal()
		opponent.dribble_lock = 0.0
		return


# --- Knockdowns -----------------------------------------------------------


func knockdown(direction: Vector3, force: float, duration: float = 1.7) -> void:
	if knocked_out > 0.0 or protection > 0.0:
		return
	knocked_out = duration
	_dive_timer = 0.0
	_visual_action_timer = 0.0
	var pushed := Vector3(direction.x, 0.0, direction.z)
	if pushed.length() < 0.01:
		pushed = -facing
	facing = -pushed.normalized()
	rotation.y = atan2(-facing.x,-facing.z)
	if _visual != null:
		_visual.set("knockdown_duration",duration)
	velocity = pushed.normalized() * force + Vector3.UP * 2.4
	tackle_timer = 0.0
	tackle_recovery_timer = 0.0
	if kick:
		kick.charging = false
		kick.charge = 0.0


func _update_knocked(delta: float) -> void:
	knocked_out -= delta
	velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	_was_tackle_held = input != null and input.tackle_held()
	if knocked_out <= 0.0:
		knocked_out = 0.0
		protection = 1.0


func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	_visual_action_timer = maxf(0.0,_visual_action_timer-delta)
	var tilt := 0.0
	var drop := 0.0
	if tackle_timer > 0.0 and not (_visual.get("_skeletal_model") == true):
		tilt = -38.0
		drop = -0.28
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving_amount := clampf(horizontal_speed / maxf(walk_speed, 0.01), 0.0, 1.0)
	var active_run := knocked_out <= 0.0 and tackle_timer <= 0.0 and tackle_recovery_timer <= 0.0
	if _visual.has_method("play"):
		var visual_animation := 0
		if knocked_out > 0.0:
			visual_animation = 10
		elif _visual_action_timer > 0.0:
			visual_animation = _visual_action_animation
		elif tackle_timer > 0.0:
			visual_animation = 5
		elif kick != null and kick.charging:
			visual_animation = 7
		elif knocked_out <= 0.0 and not is_on_floor():
			visual_animation = 2
		elif active_run and moving_amount > 0.05 and is_on_floor():
			visual_animation = 1 if sprinting else 6
		_visual.call("play",visual_animation)
	if _visual.has_method("advance_animation"):
		_visual.call("advance_animation",delta)
	if active_run and moving_amount > 0.05 and is_on_floor():
		_run_phase += delta * lerpf(11.0, 20.0, clampf(horizontal_speed / sprint_speed, 0.0, 1.0))
	var airborne := not is_on_floor() and knocked_out <= 0.0 and tackle_timer <= 0.0
	var stride := sin(_run_phase) * 0.62 * moving_amount if active_run and is_on_floor() else 0.0
	var arm_stride := -sin(_run_phase) * 0.48 * moving_amount if active_run and is_on_floor() else 0.0
	for index in _leg_pivots.size():
		var target_leg := stride if index == 0 else -stride
		if airborne:
			target_leg = 0.32
		_leg_pivots[index].rotation.x = lerp_angle(_leg_pivots[index].rotation.x, target_leg, clampf(delta * 12.0, 0.0, 1.0))
	for index in _arm_pivots.size():
		var target_arm := arm_stride if index == 0 else -arm_stride
		_arm_pivots[index].rotation.x = lerp_angle(_arm_pivots[index].rotation.x, target_arm, clampf(delta * 12.0, 0.0, 1.0))
	if active_run and is_on_floor() and not (_visual.get("_skeletal_model") == true):
		drop += absf(sin(_run_phase * 2.0)) * 0.045 * moving_amount
	var pick := 1.0 - exp(-delta * 14.0)
	_visual.rotation_degrees.x = lerpf(_visual.rotation_degrees.x, tilt, pick)
	_visual.position.y = lerpf(_visual.position.y, drop, pick)


func play_kick_animation() -> void:
	if _dive_timer>0.0 or not is_on_floor():
		return
	_visual_action_animation = 9 if Vector2(velocity.x,velocity.z).length()>1.0 else 3
	_visual_action_timer = _visual.call("animation_duration",_visual_action_animation) if _visual != null and _visual.has_method("animation_duration") else 0.5


func _start_dive(direction: Vector3) -> void:
	_dive_timer = dive_duration
	_dive_direction = direction.normalized()
	_visual_action_animation = 8
	_visual_action_timer = dive_duration
	facing = _dive_direction
	rotation.y = atan2(-facing.x,-facing.z)
	velocity = _dive_direction*dive_speed+Vector3.UP*dive_jump_speed
	if kick != null:
		kick.charging = false


func _update_dive(delta: float) -> void:
	_dive_timer = maxf(0.0,_dive_timer-delta)
	var elapsed := dive_duration-_dive_timer
	var speed := dive_speed*(1.0-smoothstep(0.60,dive_duration,elapsed))
	velocity.x = _dive_direction.x*speed
	velocity.z = _dive_direction.z*speed
	if is_on_floor() and velocity.y<=0.0:
		velocity.y = -0.1
	else:
		velocity.y -= gravity*delta
	move_and_slide()


func _brake(delta: float) -> void:
	_move_intent = Vector3.ZERO
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func reset_at(position: Vector3, look: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	_dive_timer = 0.0
	_visual_action_timer = 0.0
	stamina = stamina_max
	exhausted = false
	exhaust_timer = 0.0
	knocked_out = 0.0
	protection = 1.0
	tackle_timer = 0.0
	tackle_recovery_timer = 0.0
	tackle_cooldown_timer = 0.0
	dribble_lock = 0.0
	facing = Vector3(look.x, 0.0, look.z).normalized()
	rotation.y = atan2(-facing.x, -facing.z)
	if kick:
		kick.charging = false
		kick.charge = 0.0
	if _visual:
		_visual.rotation_degrees.x = 0.0
		_visual.position.y = 0.0
