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
var _frame: StandardMaterial3D
var _panel: StandardMaterial3D
var _panel_alt: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_floor()
	_build_markings()
	_build_walls()
	_build_indoor_shell()
	_build_camera_barriers()


func _make_materials() -> void:
	_floor = StandardMaterial3D.new()
	_floor.albedo_color = Color(0.035, 0.32, 0.075)
	_floor.roughness = 0.9

	_floor_alt = StandardMaterial3D.new()
	_floor_alt.albedo_color = Color(0.045, 0.38, 0.09)
	_floor_alt.roughness = 0.9

	_line = StandardMaterial3D.new()
	_line.albedo_color = Color(0.92, 0.96, 1.0)
	_line.roughness = 0.7

	_wall = StandardMaterial3D.new()
	_wall.albedo_color = Color(0.23, 0.14, 0.36)
	_wall.roughness = 0.75

	_trim = StandardMaterial3D.new()
	_trim.albedo_color = Color(0.65, 0.18, 0.88)
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

	_frame = StandardMaterial3D.new()
	_frame.albedo_color = Color(0.28, 0.1, 0.42)
	_frame.roughness = 0.55
	_panel = StandardMaterial3D.new()
	_panel.albedo_color = Color(0.78, 0.72, 0.86)
	_panel.roughness = 0.86
	_panel_alt = StandardMaterial3D.new()
	_panel_alt.albedo_color = Color(0.88, 0.83, 0.92)
	_panel_alt.roughness = 0.86


func _build_floor() -> void:
	_add_static_box(
		Vector3(HALF_WIDTH * 2.0, 0.4, HALF_LENGTH * 2.0 + 4.0),
		Vector3(0, -0.2, 0),
		_floor,
		0.1
	)
	for i in 16:
		var stripe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(HALF_WIDTH * 2.0, 0.025, HALF_LENGTH * 0.125)
		stripe.mesh = mesh
		stripe.material_override = _floor_alt if i % 2 == 0 else _floor
		stripe.position = Vector3(0, 0.005, -HALF_LENGTH + HALF_LENGTH * 0.125 * (i + 0.5))
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


func _build_indoor_shell() -> void:
	# Pale modular wall panels above the low gameplay walls, framed in purple steel.
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -HALF_LENGTH + (i + 0.5) * HALF_LENGTH * 0.25
			_add_decal_box(Vector3(0.16, 8.5, 0.2), Vector3(side * 10.65, 6.85, z), _frame)
			_add_decal_box(Vector3(0.12, 0.14, HALF_LENGTH * 0.25 - 0.12), Vector3(side * 10.65, 2.8, z), _frame)
		for row in 3:
			_add_decal_box(Vector3(0.12, 0.12, HALF_LENGTH * 2.0), Vector3(side * 10.65, 3.8 + row * 2.4, 0), _frame)
		for i in 8:
			var z0 := -HALF_LENGTH + i * HALF_LENGTH * 0.25
			var z1 := z0 + HALF_LENGTH * 0.25
			_add_diagonal(Vector3(side * 10.65, 3.2, z0), Vector3(side * 10.65, 6.9, z1), 0.1, _frame)
			_add_diagonal(Vector3(side * 10.65, 6.9, z0), Vector3(side * 10.65, 3.2, z1), 0.1, _frame)
			var panel := MeshInstance3D.new()
			var panel_mesh := BoxMesh.new()
			panel_mesh.size = Vector3(0.08, 5.6, HALF_LENGTH * 0.25 - 0.2)
			panel.mesh = panel_mesh
			panel.material_override = _panel if i % 2 == 0 else _panel_alt
			panel.position = Vector3(side * 10.78, 6.2, (z0 + z1) * 0.5)
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(panel)
	# End walls and a high cross-braced roof complete the enclosed arena silhouette.
	for end in [-1.0, 1.0]:
		for i in 5:
			var x := -HALF_WIDTH + (i + 0.5) * HALF_WIDTH * 0.4
			_add_decal_box(Vector3(0.12, 8.5, 0.2), Vector3(x, 6.85, end * 18.3), _frame)
			var panel := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(HALF_WIDTH * 0.4 - 0.2, 5.6, 0.08)
			panel.mesh = mesh
			panel.material_override = _panel_alt
			panel.position = Vector3(x, 6.2, end * 18.5)
			add_child(panel)
		_add_decal_box(Vector3(HALF_WIDTH * 2.0, 0.15, 0.2), Vector3(0, 2.8, end * 18.3), _frame)
		_add_decal_box(Vector3(HALF_WIDTH * 2.0, 0.15, 0.2), Vector3(0, 10.9, end * 18.3), _frame)
	for x in range(-10, 11, 5):
		_add_decal_box(Vector3(0.16, 0.16, 38.0), Vector3(x, 10.8, 0), _frame)
	_add_decal_box(Vector3(22.0, 0.16, 0.16), Vector3(0, 10.8, -18.5), _frame)
	_add_decal_box(Vector3(22.0, 0.16, 0.16), Vector3(0, 10.8, 18.5), _frame)
	_add_decal_box(Vector3(21.8, 0.12, 37.0), Vector3(0, 11.4, 0), _panel_alt)


func _build_camera_barriers() -> void:
	# The decorative upper walls have no gameplay collision, but the chase camera
	# needs invisible blockers so it cannot orbit through those wall panels.
	for side in [-1.0, 1.0]:
		_add_camera_barrier(Vector3(0.18, 8.8, HALF_LENGTH * 2.0), Vector3(side * 10.68, 7.0, 0))
	for end in [-1.0, 1.0]:
		_add_camera_barrier(Vector3(HALF_WIDTH * 2.0 + 1.0, 8.8, 0.18), Vector3(0, 7.0, end * 18.18))


func _add_camera_barrier(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CameraWallBlocker"
	body.collision_layer = 1 << 4
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _add_diagonal(start: Vector3, finish: Vector3, thickness: float, material: Material) -> void:
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var delta := finish - start
	mesh.size = Vector3(thickness, thickness, delta.length())
	beam.mesh = mesh
	beam.material_override = material
	beam.position = (start + finish) * 0.5
	add_child(beam)
	beam.look_at(finish, Vector3.UP)


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
