extends Node3D
## A goal with posts, a grid net and a detection area.
## The net opens toward local +Z; rotate the node for the other end.

signal scored

const Field := preload("res://scripts/field_config.gd")
const WIDTH := Field.GOAL_WIDTH
const HEIGHT := Field.GOAL_HEIGHT
const DEPTH := Field.GOAL_DEPTH

var _cooldown := 0.0


func _ready() -> void:
	_build_frame()
	_build_net()
	_build_backstop()
	_build_detector()


func _build_frame() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1.0, 0.24, 0.08)
	white.roughness = 0.35
	white.metallic = 0.05

	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.09
		mesh.bottom_radius = 0.09
		mesh.height = HEIGHT
		post.mesh = mesh
		post.material_override = white
		post.position = Vector3(side * WIDTH * 0.5, HEIGHT * 0.5, 0)
		add_child(post)
		_add_frame_collider(Vector3(side * WIDTH * 0.5, HEIGHT * 0.5, 0), Vector3(0.22, HEIGHT, 0.22))

	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(WIDTH + 0.18, 0.18, 0.18)
	bar.mesh = bar_mesh
	bar.material_override = white
	bar.position = Vector3(0, HEIGHT, 0)
	add_child(bar)
	_add_frame_collider(Vector3(0, HEIGHT, 0), Vector3(WIDTH + 0.2, 0.22, 0.22))


func _add_frame_collider(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 4
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _build_net() -> void:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
uniform vec4 net_color : source_color = vec4(0.85, 0.92, 1.0, 0.55);
uniform vec2 cells = vec2(20.0, 9.0);
void fragment() {
	vec2 g = fract(UV * cells);
	float line = max(step(0.86, g.x), step(0.86, g.y));
	ALBEDO = net_color.rgb;
	ALPHA = line * net_color.a;
}
"""
	material.shader = shader

	var back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(WIDTH, HEIGHT)
	back.mesh = back_mesh
	back.material_override = material
	back.position = Vector3(0, HEIGHT * 0.5, -DEPTH)
	add_child(back)

	for side in [-1.0, 1.0]:
		var side_net := MeshInstance3D.new()
		var side_mesh := QuadMesh.new()
		side_mesh.size = Vector2(DEPTH, HEIGHT)
		side_net.mesh = side_mesh
		side_net.material_override = material
		side_net.position = Vector3(side * WIDTH * 0.5, HEIGHT * 0.5, -DEPTH * 0.5)
		side_net.rotation_degrees.y = 90.0
		add_child(side_net)

	var top := MeshInstance3D.new()
	var top_mesh := QuadMesh.new()
	top_mesh.size = Vector2(WIDTH, DEPTH)
	top.mesh = top_mesh
	top.material_override = material
	top.position = Vector3(0, HEIGHT, -DEPTH * 0.5)
	top.rotation_degrees.x = -90.0
	add_child(top)


func _build_backstop() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, 1.2, -DEPTH - 0.1)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH + 0.4, HEIGHT + 0.4, 0.2)
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _build_detector() -> void:
	var area := Area3D.new()
	area.position = Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5)
	area.collision_layer = 8
	area.collision_mask = 4
	area.monitoring = true

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH - 0.2, HEIGHT - 0.2, DEPTH)
	collider.shape = shape
	area.add_child(collider)
	area.body_entered.connect(_on_body_entered)
	add_child(area)


func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if body is RigidBody3D and body.is_in_group("ball"):
		_cooldown = 1.0
		scored.emit()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func preview_crossing(from: Vector3, to: Vector3) -> Dictionary:
	## Returns the first clean front-plane crossing inside this goal aperture.
	var local_from := global_transform.affine_inverse() * from
	var local_to := global_transform.affine_inverse() * to
	if local_from.z <= 0.0 or local_to.z > 0.0 or is_equal_approx(local_from.z, local_to.z):
		return {}
	var ratio := local_from.z / (local_from.z - local_to.z)
	var hit := local_from.lerp(local_to, ratio)
	if absf(hit.x) > WIDTH * 0.5 - 0.33 or hit.y < 0.22 or hit.y > HEIGHT - 0.33:
		return {}
	return {"position": global_transform * hit, "ratio": ratio}
