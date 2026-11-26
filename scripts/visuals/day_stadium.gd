extends Node3D
## Shared outdoor stadium and transparent physical arena used by both modes.

const Field := preload("res://scripts/field_config.gd")
const Shapes := preload("res://scripts/visuals/shape_library.gd")
const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
var _batches: Dictionary = {}
var _cube := BoxMesh.new()
var _concrete: StandardMaterial3D
var _dark: StandardMaterial3D
var _cream: StandardMaterial3D
var _cyan: StandardMaterial3D
var _pink: StandardMaterial3D
var _purple: StandardMaterial3D
var _glass: ShaderMaterial


func _ready() -> void:
	name="DayStadium"
	_cube.size=Vector3.ONE
	_concrete=Shapes.material(Color("d4d7d4"))
	_dark=Shapes.material(Color("26354b"))
	_cream=Shapes.material(Color("fff4df"))
	_cyan=Shapes.material(Color("279ec0"))
	_pink=Shapes.material(Color("ca4b87"))
	_purple=Shapes.material(Color("58476b"))
	_make_glass()
	_build_enclosure()
	_build_stadium()
	_finish_batches()


## Soft "party game" daylight: warm sun, cool sky-blue shadows, gentle distance haze
## and chunky clouds. Shared by the match and the visual sandbox.
static func add_daylight(parent: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name="DaylightEnvironment"
	var environment := Environment.new()
	environment.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("4f9be0")
	sky_material.sky_horizon_color=Color("cfe6f5")
	sky_material.sky_curve=0.12
	sky_material.ground_bottom_color=Color("6f9a62")
	sky_material.ground_horizon_color=Color("bcd6c4")
	sky_material.sun_angle_max=20.0
	sky.sky_material=sky_material
	environment.sky=sky
	# Shadows are filled by the sky, so they read light and slightly blue.
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b9d3ec")
	environment.ambient_light_energy=0.62
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.08
	environment.tonemap_white=6.0
	# Distance haze softens the far stands toward the horizon colour.
	environment.fog_enabled=true
	environment.fog_mode=Environment.FOG_MODE_DEPTH
	environment.fog_light_color=Color("d4e6f3")
	environment.fog_light_energy=1.0
	environment.fog_density=0.55
	environment.fog_depth_begin=45.0
	environment.fog_depth_end=260.0
	environment.fog_depth_curve=1.6
	environment.fog_sky_affect=0.0
	environment.adjustment_enabled=true
	environment.adjustment_saturation=0.92
	environment.adjustment_contrast=0.97
	world.environment=environment
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name="AfternoonSun"
	sun.rotation_degrees=Vector3(-52,-35,0)
	sun.light_color=Color("ffe9cc")
	sun.light_energy=1.25
	sun.shadow_enabled=true
	sun.shadow_opacity=0.72
	sun.shadow_blur=2.0
	sun.light_angular_distance=2.0
	sun.directional_shadow_max_distance=120.0
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name="SkyFill"
	fill.rotation_degrees=Vector3(-30,145,0)
	fill.light_color=Color("a9cdf5")
	fill.light_energy=0.22
	parent.add_child(fill)
	parent.add_child(_build_clouds())


## Chunky clouds: clusters of flattened spheres around the stadium, high enough to
## clear the roofs from pitch level. One batched draw, no shadows, no fog.
static func _build_clouds() -> Node3D:
	var root := Node3D.new()
	root.name="SkyClouds"
	var shader := Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled;
varying vec3 world_normal;
void vertex() {
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    float up = clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 belly = vec3(0.80, 0.86, 0.95);
    vec3 top = vec3(1.0, 0.995, 0.98);
    vec3 color = mix(belly, top, smoothstep(0.30, 0.80, up));
    // A touch of warm sunlight on the sun-facing side.
    float sun = clamp(dot(world_normal, normalize(vec3(0.45, 0.70, 0.55))), 0.0, 1.0);
    ALBEDO = color + vec3(0.03, 0.02, 0.0) * sun;
}
"""
	var material := ShaderMaterial.new()
	material.shader=shader
	var sphere := SphereMesh.new()
	sphere.radius=1.0
	sphere.height=2.0
	sphere.radial_segments=18
	sphere.rings=10
	var rng := RandomNumberGenerator.new()
	rng.seed=20261114
	var poses: Array[Transform3D] = []
	var clusters := 11
	for cluster in clusters:
		var angle := TAU*float(cluster)/clusters+rng.randf_range(-0.18,0.18)
		var distance := rng.randf_range(112.0,138.0)
		var center := Vector3(sin(angle)*distance,rng.randf_range(52.0,74.0),cos(angle)*distance)
		var along := Vector3(cos(angle),0,-sin(angle))
		var size := rng.randf_range(10.0,14.0)
		var puffs := rng.randi_range(5,8)
		for puff in puffs:
			var t := (float(puff)/(puffs-1))*2.0-1.0
			var radius := size*(1.0-absf(t)*0.45)*rng.randf_range(0.85,1.1)
			var at := center+along*t*size*1.9+Vector3(0,(1.0-absf(t))*size*0.35,0)
			at+=Vector3(rng.randf_range(-1,1),rng.randf_range(-0.5,0.5),rng.randf_range(-1,1))*size*0.25
			var basis := Basis.from_scale(Vector3(radius*1.15,radius*0.82,radius))
			poses.append(Transform3D(basis,at))
	var multi := MultiMesh.new()
	multi.mesh=sphere
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.instance_count=poses.size()
	for index in poses.size():
		multi.set_instance_transform(index,poses[index])
	var instance := MultiMeshInstance3D.new()
	instance.name="CloudPuffs"
	instance.multimesh=multi
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return root


func _make_glass() -> void:
	_glass=ShaderMaterial.new()
	var shader := Shader.new()
	shader.code="""
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 5.0);
    ALBEDO = vec3(0.61, 0.85, 0.94);
    ALPHA = 0.012 + edge * 0.045;
}
"""
	_glass.shader=shader


func _build_enclosure() -> void:
	var height := Field.WALL_HEIGHT
	var thickness := Field.WALL_THICKNESS
	for side in [-1.0,1.0]:
		_wall(Vector3(thickness,height,Field.LENGTH+thickness*2),Vector3(side*(Field.HALF_WIDTH+thickness*0.5),height*0.5,0),Vector2(Field.LENGTH,height),PI*0.5)
		_box(Vector3(0.06,0.05,Field.LENGTH),Vector3(side*Field.HALF_WIDTH,0.06,0),_cream)
		_box(Vector3(0.035,0.035,Field.LENGTH),Vector3(side*Field.HALF_WIDTH,height,0),_cream)
	var segment := (Field.WIDTH-Field.GOAL_WIDTH)*0.5
	var header_height := height-Field.GOAL_HEIGHT
	for end in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			var x: float=side*(Field.GOAL_WIDTH*0.5+segment*0.5)
			_wall(Vector3(segment,height,thickness),Vector3(x,height*0.5,end*(Field.HALF_LENGTH+thickness*0.5)),Vector2(segment,height),0)
			_box(Vector3(segment,0.05,0.06),Vector3(x,0.06,end*Field.HALF_LENGTH),_cream)
		_wall(Vector3(Field.GOAL_WIDTH,header_height,thickness),Vector3(0,Field.GOAL_HEIGHT+header_height*0.5,end*(Field.HALF_LENGTH+thickness*0.5)),Vector2(Field.GOAL_WIDTH,header_height),0)
		_box(Vector3(Field.WIDTH,0.035,0.035),Vector3(0,height,end*Field.HALF_LENGTH),_cream)
		for side in [-1.0,1.0]:
			_box(Vector3(0.045,height,0.045),Vector3(side*Field.HALF_WIDTH,height*0.5,end*Field.HALF_LENGTH),_cream)


func _wall(size: Vector3, at: Vector3, panel_size: Vector2, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name="TransparentReboundWall"
	body.add_to_group("arena_rebound_walls")
	body.position=at
	body.collision_layer=1
	body.collision_mask=2|4
	var shape := BoxShape3D.new()
	shape.size=size
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	var physics := PhysicsMaterial.new()
	physics.bounce=0.20
	physics.friction=0.10
	body.physics_material_override=physics
	add_child(body)
	var mesh := QuadMesh.new()
	mesh.size=panel_size
	var panel := MeshInstance3D.new()
	panel.name="ClearArenaPanel"
	panel.mesh=mesh
	panel.material_override=_glass
	panel.position=at
	panel.rotation.y=yaw
	panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)


func _build_stadium() -> void:
	_box(Vector3(240,0.2,280),Vector3(0,-0.4,0),Shapes.material(Color("6c9d69")))
	_box(Vector3(Field.WIDTH+12,0.12,Field.LENGTH+12),Vector3(0,-0.10,0),_concrete)
	for side in [-1.0,1.0]:
		_stand(Vector3(side*(Field.HALF_WIDTH+6),0,0),Vector3(0,0,1),Vector3(side,0,0),Field.LENGTH+16,0 if side<0 else 1)
	for end in [-1.0,1.0]:
		_stand(Vector3(0,0,end*(Field.HALF_LENGTH+6)),Vector3(1,0,0),Vector3(0,0,end),Field.WIDTH+40,2 if end<0 else 3)
		_video_board(end)
	for x in [-Field.HALF_WIDTH-20,Field.HALF_WIDTH+20]:
		for z in [-Field.HALF_LENGTH-16,Field.HALF_LENGTH+16]:
			_box(Vector3(0.35,24,0.35),Vector3(x,12,z),_cream)
			_box(Vector3(4.4,1.2,0.35),Vector3(x,23.6,z),_dark)
			for light in 6:
				_box(Vector3(0.55,0.75,0.10),Vector3(x-1.75+light*0.7,23.6,z-0.23),_cream)


func _stand(origin: Vector3, along: Vector3, outward: Vector3, length: float, section: int) -> void:
	var columns := int(length/0.72)
	var facing := -outward
	var pose := Basis(Vector3.UP,atan2(-facing.x,-facing.z))
	for row in 18:
		var depth := row*0.95+(2.0 if row>=8 else 0.0)
		var y := 1.4+row*0.60+(1.0 if row>=8 else 0.0)
		var center := origin+outward*depth+Vector3.UP*(y-0.3)
		_block(Vector3(length,0.48,1.0),Transform3D(pose,center),_concrete)
		for column in columns:
			# Repeating aisles cut through the seating banks.
			if column%26 in [0,1,2]:
				continue
			var at := origin+outward*depth+along*((column+0.5)*0.72-length*0.5)+Vector3.UP*y
			var mat: Material=_cyan if ((column/26+section)%2)==0 else _pink
			if (column+row*2)%13==0:
				mat=_cream
			_block(Vector3(0.52,0.12,0.48),Transform3D(pose,at),mat)
			_block(Vector3(0.52,0.46,0.10),Transform3D(pose,at+outward*0.23+Vector3.UP*0.23),mat)
	var front := origin-outward*0.8+Vector3.UP*0.65
	_block(Vector3(length,1.15,0.25),Transform3D(pose,front),_dark)
	for index in int(length/8):
		var at := front+along*((index+0.5)*8-length*0.5)-outward*0.15
		_block(Vector3(6.7,0.15,0.035),Transform3D(pose,at),_cyan if index%2==0 else _pink)
	# Cantilever roof covers the seats, leaving the entire pitch open to daylight.
	var canopy := origin+outward*10+Vector3.UP*15.4
	_block(Vector3(length+1.0,0.32,17.0),Transform3D(pose,canopy),_cream)
	_block(Vector3(length+1.0,0.15,0.30),Transform3D(pose,canopy-outward*8.4-Vector3.UP*0.12),_purple)
	for index in range(int(length/10)+1):
		var at := origin+along*(-length*0.5+index*10)+outward*17.5+Vector3.UP*7.7
		_block(Vector3(0.3,15.4,0.3),Transform3D(pose,at),_purple)


func _video_board(end: float) -> void:
	var z := end*(Field.HALF_LENGTH+23)
	_box(Vector3(18,6,0.5),Vector3(0,19,z),_dark)
	_box(Vector3(18.3,0.25,0.6),Vector3(0,22.1,z),_purple)
	for side in [-1.0,1.0]:
		_box(Vector3(0.4,13,0.4),Vector3(side*7,12.5,z),_purple)
	var label := Label3D.new()
	label.text="MEGA BATTLE\nFOOTBALL"
	label.font=FONT
	label.font_size=112
	label.pixel_size=0.018
	label.modulate=Color("fff4df")
	label.outline_size=8
	label.position=Vector3(0,19,z-end*0.30)
	label.rotation.y=PI if end>0 else 0.0
	label.shaded=false
	add_child(label)


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	_block(size,Transform3D(Basis.IDENTITY,at),material)


func _block(size: Vector3, pose: Transform3D, material: Material) -> void:
	var key := material.get_instance_id()
	if not _batches.has(key):
		_batches[key]={"material":material,"poses":[]}
	pose.basis=pose.basis.scaled_local(size)
	_batches[key].poses.append(pose)


func _finish_batches() -> void:
	for batch in _batches.values():
		var multi := MultiMesh.new()
		multi.mesh=_cube
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.instance_count=batch.poses.size()
		for index in multi.instance_count:
			multi.set_instance_transform(index,batch.poses[index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh=multi
		instance.material_override=batch.material
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_batches.clear()
