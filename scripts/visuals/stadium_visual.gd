extends Node3D
## Batched modular stadium: one MultiMesh per mesh/material combination.
const Shapes := preload("res://scripts/visuals/shape_library.gd")
const Field := preload("res://scripts/field_config.gd")
const DayStadium := preload("res://scripts/visuals/day_stadium.gd")
const HALF_LENGTH := Field.HALF_LENGTH
const HALF_WIDTH := Field.HALF_WIDTH

var _batches: Dictionary = {}
var _cube := BoxMesh.new()
var _bolt_mesh := SphereMesh.new()
var _cream: StandardMaterial3D
var _orange: StandardMaterial3D


func _ready() -> void:
	_cube.size = Vector3.ONE
	_bolt_mesh.radius = 1.0
	_bolt_mesh.height = 2.0
	_bolt_mesh.radial_segments = 8
	_bolt_mesh.rings = 4
	_cream = Shapes.material(Color("fff9e9"))
	_orange = Shapes.material(Color("f45c2d"),0.4)
	_pitch()
	_physics_shell()
	add_child(DayStadium.new())
	_goals()
	_finish_batches()


func _physics_shell() -> void:
	_solid_box(Vector3(Field.WIDTH,0.3,Field.LENGTH+Field.GOAL_DEPTH*2.0),Vector3(0,-0.15,0))
	for end in [-1.0,1.0]:
		_add_goal_colliders(end)


func _add_goal_colliders(end_sign: float) -> void:
	var z := end_sign * HALF_LENGTH
	for side in [-1.0, 1.0]:
		_solid_box(Vector3(0.22,Field.GOAL_HEIGHT,0.22),Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT*0.5,z))
		_solid_box(Vector3(0.12,Field.GOAL_HEIGHT,Field.GOAL_DEPTH),Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT*0.5,z+end_sign*Field.GOAL_DEPTH*0.5))
	_solid_box(Vector3(Field.GOAL_WIDTH+0.22,0.22,0.22),Vector3(0,Field.GOAL_HEIGHT,z))
	_solid_box(Vector3(Field.GOAL_WIDTH,Field.GOAL_HEIGHT,0.2),Vector3(0,Field.GOAL_HEIGHT*0.5,z+end_sign*Field.GOAL_DEPTH))


func _solid_box(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 4
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _pitch() -> void:
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://assets/materials/turf.gdshader")
	_box(Vector3(Field.WIDTH,0.16,Field.LENGTH+Field.GOAL_DEPTH*2.0),Vector3(0,-0.08,0),grass)
	var line_mat := Shapes.material(Color("fffdf3"),0.8)
	for side in [-1.0,1.0]:
		_box(Vector3(0.075,0.018,Field.LENGTH),Vector3(side*(HALF_WIDTH-0.06),0.018,0),line_mat)
		_box(Vector3(Field.WIDTH,0.018,0.075),Vector3(0,0.018,side*(HALF_LENGTH-0.06)),line_mat)
		# Deep penalty boxes and smaller goal boxes.
		for box in [Vector2(Field.PENALTY_WIDTH,Field.PENALTY_DEPTH),Vector2(Field.GOAL_AREA_WIDTH,Field.GOAL_AREA_DEPTH)]:
			_box(Vector3(box.x,0.018,0.075),Vector3(0,0.018,side*(HALF_LENGTH-box.y)),line_mat)
			for edge in [-1.0,1.0]:
				_box(Vector3(0.075,0.018,box.y),Vector3(edge*box.x*0.5,0.018,side*(HALF_LENGTH-box.y*0.5)),line_mat)
	_box(Vector3(Field.WIDTH,0.018,0.075),Vector3(0,0.018,0),line_mat)
	var circle := TorusMesh.new()
	circle.inner_radius = Field.CENTER_CIRCLE_RADIUS-0.04
	circle.outer_radius = Field.CENTER_CIRCLE_RADIUS+0.04
	circle.rings = 96
	circle.ring_segments = 8
	Shapes.instance(self,circle,line_mat,Vector3(0,0.014,0))
	for spot_z in [-HALF_LENGTH+9.0,0.0,HALF_LENGTH-9.0]:
		_piece(_bolt_mesh,line_mat,Transform3D(Basis.IDENTITY.scaled(Vector3(0.11,0.012,0.11)),Vector3(0,0.02,spot_z)))


func _goals() -> void:
	for end in [-1.0,1.0]:
		var z: float = end*HALF_LENGTH
		var back_z: float = z+end*Field.GOAL_DEPTH
		for side in [-1.0,1.0]:
			_cylinder(Vector3(side*Field.GOAL_WIDTH*0.5,0.03,z),Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT,z),0.13,_orange)
			Shapes.ellipsoid(self,Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT,z),Vector3.ONE*0.14,_orange)
			_cylinder(Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT,z),Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT-0.25,back_z),0.065,_orange)
		_cylinder(Vector3(-Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT,z),Vector3(Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT,z),0.13,_orange)
		# Real mesh net openings keep the silhouette clean without transparency.
		for index in 33:
			var x := -Field.GOAL_WIDTH*0.5+index*(Field.GOAL_WIDTH/32.0)
			_box(Vector3(0.026,Field.GOAL_HEIGHT-0.08,0.026),Vector3(x,Field.GOAL_HEIGHT*0.5,back_z),_cream)
			_beam(Vector3(x,Field.GOAL_HEIGHT-0.08,z),Vector3(x,Field.GOAL_HEIGHT-0.3,back_z),0.026,_cream)
		for index in 15:
			var y := 0.05+index*0.24
			_box(Vector3(Field.GOAL_WIDTH,0.026,0.026),Vector3(0,y,back_z),_cream)
			for side in [-1.0,1.0]:
				_box(Vector3(0.026,0.026,Field.GOAL_DEPTH),Vector3(side*Field.GOAL_WIDTH*0.5,y,(z+back_z)*0.5),_cream)
		for index in 7:
			for side in [-1.0,1.0]:
				_box(Vector3(0.026,Field.GOAL_HEIGHT-0.08,0.026),Vector3(side*Field.GOAL_WIDTH*0.5,Field.GOAL_HEIGHT*0.5,lerpf(z,back_z,index/6.0)),_cream)


func _cylinder(a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	var node := Shapes.instance(self,mesh,mat,(a+b)*0.5)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())


func _beam(a: Vector3,b: Vector3,width: float,mat: Material) -> void:
	var beam_basis := Basis.looking_at((b-a).normalized(),Vector3.UP)
	_block_transform(Vector3(width,width,a.distance_to(b)),Transform3D(beam_basis,(a+b)*0.5),mat)


func _box(dimensions: Vector3,at: Vector3,mat: Material) -> void:
	_block_transform(dimensions,Transform3D(Basis.IDENTITY,at),mat)


func _block_transform(dimensions: Vector3,pose: Transform3D,mat: Material) -> void:
	pose.basis = pose.basis.scaled_local(dimensions)
	_piece(_cube,mat,pose)


func _piece(mesh: Mesh,mat: Material,pose: Transform3D) -> void:
	var key := str(mesh.get_instance_id())+":"+str(mat.get_instance_id())
	if not _batches.has(key):
		_batches[key] = {"mesh":mesh,"material":mat,"poses":[]}
	_batches[key].poses.append(pose)


func _finish_batches() -> void:
	for batch in _batches.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch.mesh
		multi.instance_count = batch.poses.size()
		for index in batch.poses.size():
			multi.set_instance_transform(index,batch.poses[index])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = batch.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	_batches.clear()
