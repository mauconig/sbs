extends CharacterBody3D
## Arcade footballer: camera-relative movement, generous stamina,
## magnetic dribbling and knockdown recovery.

const InputHub := preload("res://scripts/input_hub.gd")

@export_group("Movement")
@export var walk_speed := 8.0
@export var sprint_speed := 11.5
@export var acceleration := 70.0
@export var deceleration := 45.0
@export var turn_speed := 16.0
@export var gravity := 26.0

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

@export_group("Look")
@export var body_color := Color(0.18, 0.62, 1.0)

var input: RefCounted
var camera: Node3D
var ball: RigidBody3D
var kick: Node

var stamina := 100.0
var sprinting := false
var exhausted := false
var exhaust_timer := 0.0
var regen_timer := 0.0
var dribble_lock := 0.0

var facing := Vector3(0.0, 0.0, -1.0)
var knocked_out := 0.0
var _move_intent := Vector3.ZERO


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
	add_child(torso)

	var hips := MeshInstance3D.new()
	var hips_mesh := BoxMesh.new()
	hips_mesh.size = Vector3(0.5, 0.26, 0.42)
	hips.mesh = hips_mesh
	hips.material_override = shorts
	hips.position = Vector3(0.0, 0.42, 0.0)
	add_child(hips)

	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.17, 0.42, 0.19)
		leg.mesh = leg_mesh
		leg.material_override = skin
		leg.position = Vector3(0.14 * side, 0.2, 0.0)
		add_child(leg)

		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.19, 0.12, 0.34)
		boot.mesh = boot_mesh
		boot.material_override = dark
		boot.position = Vector3(0.14 * side, 0.06, -0.05)
		add_child(boot)

		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.085
		arm_mesh.height = 0.52
		arm.mesh = arm_mesh
		arm.material_override = skin
		arm.position = Vector3(0.33 * side, 0.88, 0.0)
		arm.rotation_degrees.z = -14.0 * side
		add_child(arm)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.33
	sphere.height = 0.66
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(0.0, 1.42, 0.0)
	add_child(head)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.44, 0.14, 0.12)
	visor.mesh = visor_mesh
	visor.material_override = dark
	visor.position = Vector3(0.0, 1.44, -0.28)
	add_child(visor)


func _physics_process(delta: float) -> void:
	knocked_out = maxf(0.0, knocked_out - delta)

	var move: Vector2 = input.move_vector() if input else Vector2.ZERO
	var yaw: float = camera.yaw if camera else 0.0
	var direction := Basis(Vector3.UP, yaw) * Vector3(move.x, 0.0, -move.y)
	if direction.length() > 0.001:
		direction = direction.normalized()

	var charging: bool = kick != null and kick.charging
	if charging:
		direction.x = 0.0
		if direction.length() > 0.001:
			direction = direction.normalized()

	var can_sprint := stamina > sprint_min_stamina and not exhausted
	sprinting = input != null and input.sprint_held() and direction.length() > 0.1 and can_sprint

	var target_speed := sprint_speed if sprinting else walk_speed
	if charging:
		target_speed *= 0.55
	if knocked_out > 0.0:
		target_speed = 0.0

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
	if knocked_out > 0.0:
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

	var target := global_position + facing * 0.55
	var error := Vector3(target.x - ball_pos.x, 0.0, target.z - ball_pos.z)
	var desired := _move_intent + error * 7.0
	desired = desired.limit_length(maxf(2.0, _move_intent.length() * 1.25))

	var blend := clampf(delta * dribble_grip, 0.0, 1.0)
	ball.linear_velocity.x = lerpf(ball_velocity.x, desired.x, blend)
	ball.linear_velocity.z = lerpf(ball_velocity.z, desired.z, blend)
