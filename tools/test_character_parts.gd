extends SceneTree
## Verify modular parts, live skin changes, per-player isolation and skeletal playback.

var _actors: Array[Node3D] = []


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	for index in 2:
		var actor := load("res://scenes/visuals/character.tscn").instantiate() as Node3D
		actor.set("look",actor.get("look").duplicate())
		root.add_child(actor)
		_actors.append(actor)
	await process_frame
	var actor := _actors[0]
	var parts := {}
	for part_name in ["Skin","Shirt","Shorts","Legs","Socks","Boots"]:
		var part := actor.find_child(part_name,true,false) as MeshInstance3D
		assert(part != null,"Missing separate mesh: " + part_name)
		assert(part.skin != null and part.skin.get_bind_count() > 0,part_name + " lost its skin bindings")
		assert(part.get_node_or_null(part.skeleton) is Skeleton3D,part_name + " lost its skeleton")
		parts[part_name] = part
	assert(parts.Skin.get_active_material(0) == parts.Legs.get_active_material(0),"Legs must share the skin material")
	assert(parts.Shirt.get_active_material(0) != parts.Shorts.get_active_material(0),"Clothing materials must be separate")
	# The supplied shorts have sloped, sculpted cuffs. Their true inner edges
	# must stay on the garment; a flat height split exposes a skin-colored cuff.
	var model_root := actor.get("_model_root") as Node3D
	var model_space := model_root.get_parent() as Node3D
	var model_scale: float = actor.get("model_scale")
	var shorts_positions := {}
	var shorts_arrays: Array = parts.Shorts.mesh.surface_get_arrays(0)
	var leg_arrays: Array = parts.Legs.mesh.surface_get_arrays(0)
	var shorts_transform: Transform3D = model_space.global_transform.affine_inverse()*parts.Shorts.global_transform
	var leg_transform: Transform3D = model_space.global_transform.affine_inverse()*parts.Legs.global_transform
	for vertex: Vector3 in shorts_arrays[Mesh.ARRAY_VERTEX]:
		shorts_positions[(shorts_transform*vertex/model_scale).snapped(Vector3.ONE*0.00001)] = true
	var seam := {}
	for vertex: Vector3 in leg_arrays[Mesh.ARRAY_VERTEX]:
		var point := (leg_transform*vertex/model_scale).snapped(Vector3.ONE*0.00001)
		if shorts_positions.has(point):
			seam[point] = true
	assert(seam.size() >= 30,"Shorts and thighs lost their shared sculpted cuff edges")
	# Use a geometric plane check: imported bind-pose axes differ from world
	# axes, but the two mirrored cuff contours must not form one flat slice.
	var points := seam.keys()
	var a: Vector3 = points[0]
	var b := a
	for point: Vector3 in points:
		if point.distance_squared_to(a) > b.distance_squared_to(a):
			b = point
	var normal := Vector3.ZERO
	for point: Vector3 in points:
		var candidate := (b-a).cross(point-a)
		if candidate.length_squared() > normal.length_squared():
			normal = candidate
	normal = normal.normalized()
	var contour_depth := 0.0
	for point: Vector3 in points:
		contour_depth = maxf(contour_depth,absf(normal.dot(point-a)))
	assert(contour_depth > 0.012,"Shorts must end on their sculpted cuff contours, not a single flat color band")
	var look := actor.get("look") as Resource
	var original_skin := parts.Skin.get_active_material(0) as ShaderMaterial
	for property in look.get_property_list():
		assert(property.name != "leg_color","Leg color must always come from the skin setting")
	look.set("skin_color",Color("785040"))
	var skin := parts.Skin.get_active_material(0) as ShaderMaterial
	assert(skin == original_skin,"Live color edits must preserve the existing material")
	assert(skin == parts.Legs.get_active_material(0),"Skin changes must keep legs linked")
	assert(skin.get_shader_parameter("skin_color").is_equal_approx(look.get("skin_color")),"Live skin change was not applied")
	var other_skin := (_actors[1].find_child("Skin",true,false) as MeshInstance3D).get_active_material(0) as ShaderMaterial
	assert(not other_skin.get_shader_parameter("skin_color").is_equal_approx(look.get("skin_color")),"A player's color changed another player")
	look.set("shirt_color",Color("2366bb"))
	var shirt := parts.Shirt.get_active_material(0) as ShaderMaterial
	var shorts := parts.Shorts.get_active_material(0) as ShaderMaterial
	assert(shirt.get_shader_parameter("shirt_color").is_equal_approx(look.get("shirt_color")),"Shirt did not update")
	assert(shorts.get_shader_parameter("shorts_color").is_equal_approx(Color.WHITE),"Shirt changes affected shorts")
	actor.call("play",1)
	var player := actor.get("_animation_player") as AnimationPlayer
	var skeleton := parts.Legs.get_node(parts.Legs.skeleton) as Skeleton3D
	player.seek(0.05,true)
	var poses: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_global_pose(bone))
	player.seek(0.25,true)
	var moved := false
	for bone in skeleton.get_bone_count():
		moved = moved or not poses[bone].is_equal_approx(skeleton.get_bone_global_pose(bone))
	assert(moved,"Separated parts no longer receive running animation")
	_finish.call_deferred()


func _finish() -> void:
	await RenderingServer.frame_post_draw
	for instance in _actors:
		instance.queue_free()
	_actors.clear()
	await process_frame
	await process_frame
	print("CHARACTER_PARTS_OK six separate meshes; shared live skin color; independent clothing; running animation")
	quit()
