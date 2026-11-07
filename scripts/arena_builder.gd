extends Node3D
## Builds the walled pitch: floor, markings, walls, trim, bleachers.

const HALF_LENGTH := 16.0
const HALF_WIDTH := 10.0
const WALL_HEIGHT := 2.6
const WALL_THICKNESS := 0.4
const GOAL_WIDTH := 5.0

var _floor: StandardMaterial3D
var _floor_alt: StandardMaterial3D
var _line: StandardMaterial3D
var _wall: StandardMaterial3D
var _trim: StandardMaterial3D
var _dark: StandardMaterial3D
var _dark_alt: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_floor()
	_build_markings()
	_build_walls()
	_build_bleachers()


func _make_materials() -> void:
	_floor = StandardMaterial3D.new()
	_floor.albedo_color = Color(0.13, 0.37, 0.22)
	_floor.roughness = 0.9

	_floor_alt = StandardMaterial3D.new()
	_floor_alt.albedo_color = Color(0.16, 0.43, 0.26)
	_floor_alt.roughness = 0.9

	_line = StandardMaterial3D.new()
	_line.albedo_color = Color(0.92, 0.96, 1.0)
	_line.roughness = 0.7
	_line.emission_enabled = true
	_line.emission = Color(0.5, 0.65, 0.9)
	_line.emission_energy_multiplier = 0.15

	_wall = StandardMaterial3D.new()
	_wall.albedo_color = Color(0.13, 0.16, 0.23)
	_wall.roughness = 0.75

	_trim = StandardMaterial3D.new()
	_trim.albedo_color = Color(0.15, 0.6, 0.85)
	_trim.emission_enabled = true
	_trim.emission = Color(0.1, 0.55, 0.9)
	_trim.emission_energy_multiplier = 1.1
	_trim.roughness = 0.4

	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.07, 0.09, 0.13)
	_dark.roughness = 0.9

	_dark_alt = StandardMaterial3D.new()
	_dark_alt.albedo_color = Color(0.1, 0.13, 0.19)
	_dark_alt.roughness = 0.9


func _build_floor() -> void:
	_add_static_box(Vector3(HALF_WIDTH * 2.0, 0.4, HALF_LENGTH * 2.0), Vector3(0, -0.2, 0), _floor, 0.1)
	for i in 8:
		var stripe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(HALF_WIDTH * 2.0, 0.02, HALF_LENGTH * 0.25)
		stripe.mesh = mesh
		stripe.material_override = _floor_alt if i % 2 == 0 else _floor
		stripe.position = Vector3(0, 0.005, -HALF_LENGTH + HALF_LENGTH * 0.25 * (i + 0.5))
		add_child(stripe)


func _build_markings() -> void:
	_add_decal(Vector3(HALF_WIDTH * 2.0, 0.02, 0.12), Vector3(0, 0.02, 0))

	var circle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.94
	torus.outer_radius = 3.06
	torus.rings = 48
	torus.ring_segments = 6
	circle.mesh = torus
	circle.material_override = _line
	circle.position = Vector3(0, 0.02, 0)
	add_child(circle)

	var dot := MeshInstance3D.new()
	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = 0.12
	dot_mesh.bottom_radius = 0.12
	dot_mesh.height = 0.02
	dot_mesh.radial_segments = 16
	dot.mesh = dot_mesh
	dot.material_override = _line
	dot.position = Vector3(0, 0.02, 0)
	add_child(dot)

	for end in [-1.0, 1.0]:
		var z_center: float = end * (HALF_LENGTH - 4.0)
		_add_decal(Vector3(9.0, 0.02, 0.12), Vector3(0, 0.02, z_center))
		for side in [-1.0, 1.0]:
			_add_decal(
				Vector3(0.12, 0.02, 4.0),
				Vector3(side * 4.5, 0.02, z_center + end * 2.0)
			)


func _build_walls() -> void:
	var wall_z := HALF_LENGTH + WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		_add_static_box(
			Vector3(WALL_THICKNESS, WALL_HEIGHT, HALF_LENGTH * 2.0),
			Vector3(side * (HALF_WIDTH + WALL_THICKNESS * 0.5), WALL_HEIGHT * 0.5, 0),
			_wall,
			0.55
		)
		_add_trim(
			Vector3(0.55, 0.1, HALF_LENGTH * 2.0),
			Vector3(side * (HALF_WIDTH + WALL_THICKNESS * 0.5), WALL_HEIGHT, 0)
		)

	var segment_width := HALF_WIDTH - GOAL_WIDTH * 0.5
	var segment_x := GOAL_WIDTH * 0.5 + segment_width * 0.5
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_add_static_box(
				Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS),
				Vector3(side * segment_x, WALL_HEIGHT * 0.5, end * wall_z),
				_wall,
				0.55
			)
			_add_trim(
				Vector3(segment_width, 0.1, 0.55),
				Vector3(side * segment_x, WALL_HEIGHT, end * wall_z)
			)

		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.16
		post_mesh.bottom_radius = 0.16
		post_mesh.height = WALL_HEIGHT
		post.mesh = post_mesh
		post.material_override = _trim
		post.position = Vector3(GOAL_WIDTH * 0.5, WALL_HEIGHT * 0.5, end * (HALF_LENGTH + 0.05))
		add_child(post)
		var post2 := post.duplicate() as MeshInstance3D
		post2.position.x = -GOAL_WIDTH * 0.5
		add_child(post2)


func _build_bleachers() -> void:
	var length := HALF_LENGTH * 2.0 + 4.0
	for side in [-1.0, 1.0]:
		_add_decal_box(
			Vector3(4.0, 1.4, length),
			Vector3(side * (HALF_WIDTH + 3.2), 0.7, 0),
			_dark
		)
		_add_decal_box(
			Vector3(3.6, 2.6, length),
			Vector3(side * (HALF_WIDTH + 5.6), 1.3, 0),
			_dark_alt
		)


func _add_static_box(size: Vector3, position: Vector3, material: Material, bounce: float) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	add_child(visual)

	var body := StaticBody3D.new()
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var physics := PhysicsMaterial.new()
	physics.bounce = bounce
	physics.friction = 0.5
	body.physics_material_override = physics
	add_child(body)


func _add_decal(size: Vector3, position: Vector3) -> void:
	_add_decal_box(size, position, _line)


func _add_decal_box(size: Vector3, position: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func _add_trim(size: Vector3, position: Vector3) -> void:
	_add_decal_box(size, position, _trim)
