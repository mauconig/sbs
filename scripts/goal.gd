extends Node3D
## A goal with posts, a grid net and a detection area.
## The net opens toward local +Z; rotate the node for the other end.

signal scored

const WIDTH := 5.0
const HEIGHT := 2.2
const DEPTH := 1.4

var _cooldown := 0.0


func _ready() -> void:
	_build_frame()
	_build_net()
	_build_backstop()
	_build_detector()


func _build_frame() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.97, 1.0)
	white.roughness = 0.35
	white.metallic = 0.4

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

	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(WIDTH + 0.18, 0.18, 0.18)
	bar.mesh = bar_mesh
	bar.material_override = white
	bar.position = Vector3(0, HEIGHT, 0)
	add_child(bar)


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
