extends Node3D
## Shared outdoor stadium with match floor and regulation field markings.

const Field := preload("res://scripts/field_config.gd")
const DayStadium := preload("res://scripts/visuals/day_stadium.gd")
const HALF_LENGTH := Field.HALF_LENGTH
const HALF_WIDTH := Field.HALF_WIDTH
const WALL_HEIGHT := Field.WALL_HEIGHT
const WALL_THICKNESS := Field.WALL_THICKNESS
const GOAL_WIDTH := Field.GOAL_WIDTH

var _line: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_floor()
	_build_markings()
	add_child(DayStadium.new())


func _make_materials() -> void:
	_line = StandardMaterial3D.new()
	_line.albedo_color = Color("fffdf3")
	_line.roughness = 0.8


func _build_floor() -> void:
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://assets/materials/turf.gdshader")
	_add_static_box(Vector3(Field.WIDTH,0.4,Field.LENGTH+4.0),Vector3(0,-0.2,0),grass,0.1)


func _build_markings() -> void:
	_add_decal(Vector3(HALF_WIDTH * 2.0, 0.02, 0.12), Vector3(0, 0.02, 0))

	var circle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Field.CENTER_CIRCLE_RADIUS-0.06
	torus.outer_radius = Field.CENTER_CIRCLE_RADIUS+0.06
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
		_add_decal(Vector3(Field.WIDTH,0.02,0.12),Vector3(0,0.02,end*(HALF_LENGTH-0.06)))
		_add_decal(Vector3(0.12,0.02,Field.LENGTH),Vector3(end*(HALF_WIDTH-0.06),0.02,0))
		for box in [Vector2(Field.PENALTY_WIDTH,Field.PENALTY_DEPTH),Vector2(Field.GOAL_AREA_WIDTH,Field.GOAL_AREA_DEPTH)]:
			_add_decal(Vector3(box.x,0.02,0.12),Vector3(0,0.02,end*(HALF_LENGTH-box.y)))
			for side in [-1.0,1.0]:
				_add_decal(Vector3(0.12,0.02,box.y),Vector3(side*box.x*0.5,0.02,end*(HALF_LENGTH-box.y*0.5)))


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
