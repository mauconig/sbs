extends CharacterBody3D
## Arcade footballer: movement, stamina, magnetic dribbling, slide tackles
## and knockdown recovery. Works for both human and AI input sources.

@export_group("Movement")
@export var walk_speed := 8.0
@export var sprint_speed := 11.5
@export var acceleration := 70.0
@export var deceleration := 45.0
@export var turn_speed := 16.0
@export var gravity := 26.0
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
@export var dribble_speed_limit := 7.0
@export var dribble_grip := 11.0

@export_group("Tackle")
@export var tackle_speed := 13.5
@export var tackle_duration := 0.45
@export var tackle_recovery := 0.55
@export var tackle_cooldown := 1.1
@export var tackle_radius := 1.55
@export var tackle_knockback := 9.0
@export var tackle_ball_push := 8.0

@export_group("Look")
@export var body_color := Color(0.18, 0.62, 1.0)

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
var _visual: Node3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	_build_visuals()


func _build_visuals() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.55
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.78, 0.0)
	add_child(collider)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var jersey := StandardMaterial3D.new()
	jersey.albedo_color = body_color
	jersey.roughness = 0.5

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.96, 0.79, 0.64)
	skin.roughness = 0.7

	var shorts := StandardMaterial3D.new()
	shorts.albedo_color = Color(0.95, 0.96, 1.0)
	shorts.roughness = 0.6

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.13)
	dark.roughness = 0.4

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 0.9
	torso.mesh = capsule
	torso.material_override = jersey
	torso.position = Vector3(0.0, 0.78, 0.0)
	_visual.add_child(torso)

	var hips := MeshInstance3D.new()
	var hips_mesh := BoxMesh.new()
	hips_mesh.size = Vector3(0.5, 0.26, 0.42)
	hips.mesh = hips_mesh
	hips.material_override = shorts
	hips.position = Vector3(0.0, 0.42, 0.0)
	_visual.add_child(hips)

	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.17, 0.42, 0.19)
		leg.mesh = leg_mesh
		leg.material_override = skin
		leg.position = Vector3(0.14 * side, 0.2, 0.0)
		_visual.add_child(leg)

		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.19, 0.12, 0.34)
		boot.mesh = boot_mesh
		boot.material_override = dark
		boot.position = Vector3(0.14 * side, 0.06, -0.05)
		_visual.add_child(boot)

		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.085
		arm_mesh.height = 0.52
		arm.mesh = arm_mesh
		arm.material_override = skin
		arm.position = Vector3(0.33 * side, 0.88, 0.0)
		arm.rotation_degrees.z = -14.0 * side
		_visual.add_child(arm)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.33
	sphere.height = 0.66
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(0.0, 1.42, 0.0)
	_visual.add_child(head)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.44, 0.14, 0.12)
	visor.mesh = visor_mesh
	visor.material_override = dark
	visor.position = Vector3(0.0, 1.44, -0.28)
	_visual.add_child(visor)


func _physics_process(delta: float) -> void:
	protection = maxf(0.0, protection - delta)
	tackle_cooldown_timer = maxf(0.0, tackle_cooldown_timer - delta)
	_update_visual(delta)

	if knocked_out > 0.0:
		_update_knocked(delta)
		return

	if tackle_timer > 0.0:
		_update_tackle(delta)
		return

	if tackle_recovery_timer > 0.0:
		tackle_recovery_timer -= delta
		_brake(delta)
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
	if pressed and tackle_cooldown_timer <= 0.0:
		_start_tackle()
		return

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
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta

	move_and_slide()

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

	var target := global_position + facing * 0.78 + global_basis.x * 0.22
	var error := Vector3(target.x - ball_pos.x, 0.0, target.z - ball_pos.z)
	var desired := _move_intent + error * 7.0
	desired = desired.limit_length(maxf(2.0, _move_intent.length() * 1.25))

	var blend := clampf(delta * dribble_grip, 0.0, 1.0)
	ball.linear_velocity.x = lerpf(ball_velocity.x, desired.x, blend)
	ball.linear_velocity.z = lerpf(ball_velocity.z, desired.z, blend)


# --- Tackling -------------------------------------------------------------


func _start_tackle() -> void:
	_tackle_dir = facing
	if camera_relative and camera:
		_tackle_dir = Vector3(-sin(camera.yaw), 0.0, -cos(camera.yaw))
	_tackle_dir.y = 0.0
	if _tackle_dir.length() < 0.01:
		_tackle_dir = Vector3(0.0, 0.0, -1.0)
	_tackle_dir = _tackle_dir.normalized()

	tackle_timer = tackle_duration
	tackle_cooldown_timer = tackle_cooldown
	_tackle_hit = false
	_tackle_ball_hit = false
	dribble_lock = 0.1
	if kick:
		kick.charging = false


func _update_tackle(delta: float) -> void:
	tackle_timer -= delta
	var t := clampf(tackle_timer / tackle_duration, 0.0, 1.0)
	var speed := lerpf(2.5, tackle_speed, t)

	velocity.x = _tackle_dir.x * speed
	velocity.z = _tackle_dir.z * speed
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	_check_tackle_hit()
	_push_ball_on_tackle()

	_was_tackle_held = input != null and input.tackle_held()
	if tackle_timer <= 0.0:
		tackle_timer = 0.0
		tackle_recovery_timer = tackle_recovery


func _check_tackle_hit() -> void:
	if _tackle_hit or opponent == null:
		return
	var to_opponent := opponent.global_position - global_position
	to_opponent.y = 0.0
	if to_opponent.length() > tackle_radius:
		return

	_tackle_hit = true
	if opponent.has_method("knockdown"):
		opponent.knockdown(to_opponent.normalized(), tackle_knockback, 1.7)
	Juice.add_shake(0.75)
	Juice.hitstop(0.05)


func _push_ball_on_tackle() -> void:
	if _tackle_ball_hit or ball == null:
		return
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	if to_ball.length() > 1.15:
		return
	_tackle_ball_hit = true
	ball.linear_velocity = _tackle_dir * tackle_ball_push + Vector3.UP * 1.5


# --- Knockdowns -----------------------------------------------------------


func knockdown(direction: Vector3, force: float, duration: float = 1.7) -> void:
	if knocked_out > 0.0 or protection > 0.0:
		return
	knocked_out = duration
	var pushed := Vector3(direction.x, 0.0, direction.z)
	if pushed.length() < 0.01:
		pushed = -facing
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
	var tilt := 0.0
	var drop := 0.0
	if knocked_out > 0.0:
		tilt = -86.0
		drop = -0.05
	elif tackle_timer > 0.0:
		tilt = -38.0
		drop = -0.28
	var pick := 1.0 - exp(-delta * 14.0)
	_visual.rotation_degrees.x = lerpf(_visual.rotation_degrees.x, tilt, pick)
	_visual.position.y = lerpf(_visual.position.y, drop, pick)


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
