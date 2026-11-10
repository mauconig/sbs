extends RigidBody3D
## The ball. Simulates drag, bounce and a Magnus-style curve force.

const Ribbon := preload("res://scripts/ribbon.gd")
const TrailScript := preload("res://scripts/ball_trail.gd")

@export var radius := 0.22
@export var ball_mass := 0.44
@export var curve_decay := 5.0
@export var ground_friction := 6.0
@export var full_white := false

var curve_strength := 0.0
var carrier: Node3D
var _dribble_weight := 0.0
var _reset_pending := false
var _reset_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("ball")
	mass = ball_mass
	continuous_cd = true
	linear_damp = 0.04
	angular_damp = 0.35
	collision_layer = 4
	collision_mask = 1 | 2
	_build_visuals()
	_build_physics_material()


func _build_visuals() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _ball_material()
	add_child(instance)
	_add_panel_marks()

	var trail := TrailScript.new()
	add_child(trail)


func _build_physics_material() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = 0.55
	material.friction = 0.65
	physics_material_override = material


func _ball_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.97, 0.97, 1.0) if not full_white else Color(1, 1, 1)
	material.roughness = 0.42
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = Color(0.55, 0.75, 1.0)
	material.emission_energy_multiplier = 0.25
	return material


func _add_panel_marks() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.055, 0.045, 0.13)
	dark.roughness = 0.7
	var directions := [
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
		Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(1, -1, -1), Vector3(-1, -1, -1)
	]
	for direction in directions:
		var patch := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius * 0.24
		mesh.bottom_radius = radius * 0.24
		mesh.height = 0.008
		mesh.radial_segments = 5
		patch.mesh = mesh
		patch.material_override = dark
		var normal: Vector3 = direction.normalized()
		patch.position = normal * (radius + 0.002)
		patch.quaternion = Quaternion(Vector3.UP, normal)
		add_child(patch)


func _physics_process(delta: float) -> void:
	curve_strength = move_toward(curve_strength, 0.0, curve_decay * delta)
	var velocity := linear_velocity
	if absf(curve_strength) > 0.05 and velocity.length() > 2.0:
		var side := Vector3(-velocity.z, 0.0, velocity.x)
		if side.length() > 0.001:
			apply_central_force(side.normalized() * curve_strength)

	# Rolling resistance so the ball does not roll forever on the ground.
	if global_position.y < radius * 1.6:
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var speed := horizontal.length()
		if speed > 0.05:
			var factor := maxf(0.0, speed - ground_friction * delta) / speed
			linear_velocity.x *= factor
			linear_velocity.z *= factor


func reset_to(target: Vector3) -> void:
	release_from(carrier)
	_reset_pending = true
	_reset_position = target
	global_position = target
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	curve_strength = 0.0
	reset_physics_interpolation()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		var pose := state.transform
		pose.origin = _reset_position
		state.transform = pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false


func claim_by(player: Node3D) -> void:
	if carrier != player:
		release_from(carrier)
		_dribble_weight = 0.0
		carrier = player
		if player is PhysicsBody3D:
			add_collision_exception_with(player)
	curve_strength = 0.0
	freeze = false
	sleeping = false


func drive_controlled(direction: Vector3, right: Vector3, carrier_velocity: Vector3, gait_phase: float, delta: float) -> void:
	if carrier == null:
		return
	var travel := Vector3(carrier_velocity.x,0.0,carrier_velocity.z)
	var moving := clampf(travel.length()/3.0,0.0,1.0) if gait_phase >= 0.0 else 0.0
	_dribble_weight = lerpf(_dribble_weight,moving,1.0-exp(-delta*14.0))
	var cycle := maxf(gait_phase,0.0)
	var step_phase := fposmod(cycle*2.0,1.0)
	# A short push from each alternating foot, then let the feet catch the ball.
	var push := smoothstep(0.0,0.22,step_phase)*(1.0-smoothstep(0.22,1.0,step_phase))
	var reach := 0.66+0.38*push*_dribble_weight
	var side := lerpf(0.18,cos(cycle*TAU)*0.22,_dribble_weight)
	var target := carrier.global_position+direction*reach+right*side
	target.y = radius+0.008+push*0.025*_dribble_weight
	var error := target-global_position
	var desired := travel+Vector3(error.x,0.0,error.z)*16.0
	desired = desired.limit_length(maxf(2.0,travel.length()+6.0))
	var blend := 1.0-exp(-delta*26.0)
	linear_velocity.x = lerpf(linear_velocity.x,desired.x,blend)
	linear_velocity.z = lerpf(linear_velocity.z,desired.z,blend)
	linear_velocity.y = lerpf(linear_velocity.y,clampf(error.y*14.0,-2.0,1.2),blend)
	var rolling := (Vector3.UP.cross(Vector3(linear_velocity.x,0.0,linear_velocity.z))/radius).limit_length(36.0)
	angular_velocity = angular_velocity.lerp(rolling,1.0-exp(-delta*18.0))


func release_from(player: Node3D) -> void:
	if carrier == player:
		if player is PhysicsBody3D:
			remove_collision_exception_with(player)
		carrier = null
