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
	global_position = target
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	curve_strength = 0.0
	reset_physics_interpolation()
