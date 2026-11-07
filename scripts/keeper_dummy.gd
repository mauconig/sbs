extends CharacterBody3D
## Sandbox-only training keeper. Slides along the goal line and blocks.
## Never spawns in real matches.

@export var min_x := -1.6
@export var max_x := 1.6
@export var speed := 7.5
@export var reaction := 6.5

var ball: RigidBody3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_build_visuals()


func _build_visuals() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0, 0.75, 0)
	add_child(collider)

	var jersey := StandardMaterial3D.new()
	jersey.albedo_color = Color(1.0, 0.72, 0.12)
	jersey.roughness = 0.55

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.31
	capsule.height = 1.15
	body.mesh = capsule
	body.material_override = jersey
	body.position = Vector3(0, 0.65, 0)
	add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	head.mesh = sphere
	head.material_override = jersey
	head.position = Vector3(0, 1.45, 0)
	add_child(head)

	var glove_material := StandardMaterial3D.new()
	glove_material.albedo_color = Color(0.95, 0.95, 1.0)
	for side in [-1.0, 1.0]:
		var glove := MeshInstance3D.new()
		var glove_mesh := SphereMesh.new()
		glove_mesh.radius = 0.17
		glove_mesh.height = 0.34
		glove.mesh = glove_mesh
		glove.material_override = glove_material
		glove.position = Vector3(side * 0.42, 0.85, 0)
		add_child(glove)


func _physics_process(_delta: float) -> void:
	var target_x := 0.0
	if ball:
		target_x = clampf(ball.global_position.x * 0.95, min_x, max_x)

	var delta_x := target_x - global_position.x
	velocity.x = clampf(delta_x * reaction, -speed, speed)
	velocity.z = 0.0
	velocity.y = 0.0
	move_and_slide()
