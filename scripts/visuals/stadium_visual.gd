extends Node3D
## Batched modular stadium: one MultiMesh per mesh/material combination.
const Shapes := preload("res://scripts/visuals/shape_library.gd")

var _batches: Dictionary = {}
var _cube := BoxMesh.new()
var _bolt_mesh := SphereMesh.new()
var _purple: StandardMaterial3D
var _purple_light: StandardMaterial3D
var _panel: StandardMaterial3D
var _panel_alt: StandardMaterial3D
var _cream: StandardMaterial3D
var _navy: StandardMaterial3D
var _orange: StandardMaterial3D
var _lamp: StandardMaterial3D


func _ready() -> void:
	_cube.size = Vector3.ONE
	_bolt_mesh.radius = 1.0
	_bolt_mesh.height = 2.0
	_bolt_mesh.radial_segments = 8
	_bolt_mesh.rings = 4
	_purple = Shapes.material(Color("684087"))
	_purple_light = Shapes.material(Color("8c68a1"))
	_panel = Shapes.material(Color("b9adc6"))
	_panel_alt = Shapes.material(Color("afa0bd"))
	_cream = Shapes.material(Color("fff9e9"))
	_navy = Shapes.material(Color("423052"))
	_orange = Shapes.material(Color("f45c2d"),0.4)
	_lamp = Shapes.material(Color("fff1e0"),0.5,true)
	_pitch()
	_physics_shell()
	_shell()
	_goals()
	_details()
	_finish_batches()


func _physics_shell() -> void:
	# The sandbox uses the same physical ball as the match, including loose shots.
	_solid_box(Vector3(24.6,0.3,38.4),Vector3(0,-0.15,0))
	for side in [-1.0,1.0]:
		_solid_box(Vector3(0.3,2.0,38.4),Vector3(side*12.3,1.0,0))
		_solid_box(Vector3(24.6,2.0,0.3),Vector3(0,1.0,side*19.2))


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
	_box(Vector3(24,0.16,38),Vector3(0,-0.08,0),grass)
	var line_mat := Shapes.material(Color("fffdf3"),0.8)
	for side in [-1.0,1.0]:
		_box(Vector3(0.075,0.018,33),Vector3(side*11.3,0.018,0),line_mat)
		_box(Vector3(22.6,0.018,0.075),Vector3(0,0.018,side*16.5),line_mat)
		# Deep penalty boxes and smaller goal boxes.
		for box in [Vector2(10,5.2),Vector2(6.7,2.1)]:
			_box(Vector3(box.x,0.018,0.075),Vector3(0,0.018,side*(16.5-box.y)),line_mat)
			for edge in [-1.0,1.0]:
				_box(Vector3(0.075,0.018,box.y),Vector3(edge*box.x*0.5,0.018,side*(16.5-box.y*0.5)),line_mat)
	_box(Vector3(22.6,0.018,0.075),Vector3(0,0.018,0),line_mat)
	var circle := TorusMesh.new()
	circle.inner_radius = 2.95
	circle.outer_radius = 3.035
	circle.rings = 96
	circle.ring_segments = 8
	Shapes.instance(self,circle,line_mat,Vector3(0,0.014,0))
	for spot_z in [-11.6,0.0,11.6]:
		_piece(_bolt_mesh,line_mat,Transform3D(Basis.IDENTITY.scaled(Vector3(0.11,0.012,0.11)),Vector3(0,0.02,spot_z)))


func _shell() -> void:
	# The low padded perimeter keeps all of the high wall architecture visible.
	for side in [-1.0,1.0]:
		_box(Vector3(0.35,0.45,38.4),Vector3(side*12.3,0.22,0),_panel)
		_box(Vector3(0.42,0.08,38.4),Vector3(side*12.3,0.47,0),_purple_light)
		for bay in 5:
			var z := -19.2 + bay*7.68
			_wall_bay(Vector3(side*12.6,0,z),-PI*0.5,7.68,side)
	for end in [-1.0,1.0]:
		for bay in 4:
			var x := -12.8+bay*6.4
			_wall_bay(Vector3(x,0,end*19.2),0.0,6.4,-end)
		_box(Vector3(25.6,0.45,0.35),Vector3(0,0.22,end*19.15),_panel)
	# Pale ceiling panels with a clearly visible purple beam grid underneath.
	for column in 4:
		for row in 5:
			_box(Vector3(6.28,0.12,7.55),Vector3(-9.6+column*6.4,7.85,-15.36+row*7.68),_panel if (row+column)%2 else _panel_alt)
	for x in [-12.8,-6.4,0.0,6.4,12.8]:
		_box(Vector3(0.28,0.32,38.8),Vector3(x,7.7,0),_purple)
	for z in [-19.2,-11.52,-3.84,3.84,11.52,19.2]:
		_box(Vector3(25.6,0.32,0.28),Vector3(0,7.7,z),_purple)
		# Hanging light bars are geometry, not dozens of expensive shadow lights.
		for x in [-7.5,7.5]:
			_box(Vector3(3.3,0.18,0.65),Vector3(x,7.35,z+0.5),_navy)
			_box(Vector3(3.0,0.04,0.43),Vector3(x,7.24,z+0.5),_lamp)


func _wall_bay(origin: Vector3, yaw: float, width: float, face_sign: float) -> void:
	var wall_basis := Basis(Vector3.UP,yaw)
	for row in 2:
		var center := origin+wall_basis*Vector3(width*0.5,2.45 if row==0 else 6.1,0)
		_block_transform(Vector3(width-0.12,4.1 if row==0 else 3.0,0.15),Transform3D(wall_basis,center),_panel if row==0 else _panel_alt)
		for x in [0.35,width-0.35]:
			for y in ([0.65,4.25] if row==0 else [4.75,7.35]):
				var at := origin+wall_basis*Vector3(x,y,face_sign*0.12)
				_piece(_bolt_mesh,_purple_light,Transform3D(wall_basis.scaled(Vector3(0.06,0.06,0.035)),at))
	for x in [0.0,width]:
		_block_transform(Vector3(0.27,7.7,0.32),Transform3D(wall_basis,origin+wall_basis*Vector3(x,3.85,0)),_purple)
	for y in [0.7,4.55,7.65]:
		_block_transform(Vector3(width,0.27,0.33),Transform3D(wall_basis,origin+wall_basis*Vector3(width*0.5,y,0)),_purple)
	for pair in [Vector2(0.0,1.0),Vector2(1.0,0.0)]:
		var a := origin+wall_basis*Vector3(0.08+pair.x*(width-0.16),0.8,face_sign*0.18)
		var b := origin+wall_basis*Vector3(0.08+pair.y*(width-0.16),4.45,face_sign*0.18)
		_beam(a,b,0.095,_purple)
		var top_a := origin+wall_basis*Vector3(0.08+pair.x*(width-0.16),4.65,face_sign*0.18)
		var top_b := origin+wall_basis*Vector3(0.08+pair.y*(width-0.16),7.55,face_sign*0.18)
		_beam(top_a,top_b,0.08,_purple)
	for x in [0.0,width]:
		for y in [0.75,4.55,7.65]:
			_block_transform(Vector3(0.52,0.52,0.38),Transform3D(wall_basis,origin+wall_basis*Vector3(x,y,0)),_purple_light)


func _goals() -> void:
	for end in [-1.0,1.0]:
		var z: float = end*16.5
		var back_z: float = z+end*1.45
		for side in [-1.0,1.0]:
			_cylinder(Vector3(side*3.25,0.03,z),Vector3(side*3.25,2.75,z),0.13,_orange)
			Shapes.ellipsoid(self,Vector3(side*3.25,2.75,z),Vector3.ONE*0.14,_orange)
			_cylinder(Vector3(side*3.25,2.75,z),Vector3(side*3.25,2.5,back_z),0.065,_orange)
		_cylinder(Vector3(-3.25,2.75,z),Vector3(3.25,2.75,z),0.13,_orange)
		# Real mesh net openings keep the silhouette clean without transparency.
		for index in 27:
			var x := -3.2+index*(6.4/26.0)
			_box(Vector3(0.026,2.48,0.026),Vector3(x,1.24,back_z),_cream)
			_beam(Vector3(x,2.72,z),Vector3(x,2.48,back_z),0.026,_cream)
		for index in 12:
			var y := 0.05+index*0.22
			_box(Vector3(6.4,0.026,0.026),Vector3(0,y,back_z),_cream)
			for side in [-1.0,1.0]:
				_box(Vector3(0.026,0.026,1.45),Vector3(side*3.2,y,(z+back_z)*0.5),_cream)
		for index in 7:
			for side in [-1.0,1.0]:
				_box(Vector3(0.026,2.48,0.026),Vector3(side*3.2,1.24,lerpf(z,back_z,index/6.0)),_cream)


func _details() -> void:
	# Doors, wall lamps, speakers and restrained original arena branding.
	var aqua := Shapes.material(Color("87d6dc"),0.45)
	for end in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			var x: float = side*8.5
			_box(Vector3(2.0,2.9,0.15),Vector3(x,1.45,end*19.03),_purple)
			_box(Vector3(1.83,2.74,0.16),Vector3(x,1.4,end*18.93),aqua)
			_box(Vector3(0.055,2.7,0.18),Vector3(x,1.4,end*18.81),_purple_light)
			_box(Vector3(3.7,0.5,0.22),Vector3(x,3.65,end*18.88),_purple_light)
			_box(Vector3(3.3,0.21,0.24),Vector3(x,3.65,end*18.74),_lamp)
			for speaker_side in [-1.0,1.0]:
				_box(Vector3(0.4,0.48,0.28),Vector3(x+speaker_side*2.15,3.7,end*18.9),_navy)
	var arena_sign := Shapes.number(self,"THE LAVENDER DOME",Vector3(-8.5,5.7,-18.97),Color("fff0d3"),true,56,0.005)
	arena_sign.shaded = false
	var sub := Shapes.number(self,"PLAY LOUD. PLAY TOGETHER.",Vector3(-8.5,5.35,-18.96),Color("9681ad"),true,32,0.004)
	sub.shaded = false
	for x in [-6.4,6.4]:
		_piece(_bolt_mesh,Shapes.material(Color("ffc359"),0.5,true),Transform3D(Basis.IDENTITY.scaled(Vector3(0.085,0.085,0.045)),Vector3(x,0.72,-18.94)))
	for side in [-1.0,1.0]:
		_box(Vector3(0.05,0.09,33),Vector3(side*12.08,0.36,0),Shapes.material(Color("a2b8ff"),0.8,true))
		for index in 5:
			_box(Vector3(0.3,0.6,0.5),Vector3(side*11.95,0.3,-15.5+index*7.6),_orange)


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
