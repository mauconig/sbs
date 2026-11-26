extends SceneTree
## Build an ankle-bound pair from the supplied shoe.
## Hair is authored in Blender; export_cocoa_hair.py preserves the edited fit.
## godot --headless --path . --script res://tools/art/build_meshy_wearables.gd

const MODELS := "res://assets/characters/models/"


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	_build_cleats()
	quit()


func _source_to_world(point: Vector3) -> Vector3:
	return Vector3(point.x, point.z, -point.y) * 100.0


func _material(label: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = Color.WHITE
	material.roughness = 0.64
	return material


func _finish_mesh(surface: SurfaceTool, path: String) -> ArrayMesh:
	surface.generate_normals()
	surface.index()
	var mesh := surface.commit()
	var error := ResourceSaver.save(mesh, path)
	assert(error == OK, "Could not save " + path)
	return load(path) as ArrayMesh


func _save_scene(node: Node3D, path: String) -> void:
	var scene := PackedScene.new()
	var error := scene.pack(node)
	assert(error == OK)
	error = ResourceSaver.save(scene, path)
	assert(error == OK, "Could not save " + path)
	node.free()
	print("WEARABLE_BUILT ", path)


func _build_cleats() -> void:
	var source := (load(MODELS + "neon_cleat.fbx") as PackedScene).instantiate()
	var visual := source.find_child("geometry_0", true, false) as MeshInstance3D
	var source_arrays := visual.mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
	var oriented := PackedVector3Array()
	var rotation := Basis(Vector3.UP, PI * 0.5)
	for vertex in source_vertices:
		oriented.append(rotation * _source_to_world(vertex))
	var source_bounds := AABB(oriented[0], Vector3.ZERO)
	for vertex in oriented:
		source_bounds = source_bounds.expand(vertex)
	var body := (load(MODELS + "meshy_blank_buddy.glb") as PackedScene).instantiate()
	var old_boots := body.find_child("Boots", true, false) as MeshInstance3D
	var old_arrays := old_boots.mesh.surface_get_arrays(0)
	var rest_vertices: PackedVector3Array = old_arrays[Mesh.ARRAY_VERTEX]
	var pair := Node3D.new()
	pair.name = "NeonCleats"
	pair.set_meta("source_asset", MODELS + "neon_cleat.fbx")
	for side in ["Left", "Right"]:
		var sign_x := 1.0 if side == "Left" else -1.0
		var rest_bounds := AABB()
		var first := true
		for vertex in rest_vertices:
			if vertex.x * sign_x <= 0:
				continue
			rest_bounds = AABB(vertex, Vector3.ZERO) if first else rest_bounds.expand(vertex)
			first = false
		assert(not first, "Both original foot volumes must exist")
		var bind := Transform3D.IDENTITY
		var found := false
		for index in old_boots.skin.get_bind_count():
			if old_boots.skin.get_bind_name(index) == "mixamorig_" + side + "Foot":
				bind = old_boots.skin.get_bind_pose(index)
				found = true
		assert(found, "The replacement shoe requires the original foot bind")
		# Keep the sole at the original ground height and leave the socks exposed.
		var target_bounds := rest_bounds
		target_bounds.size.y = 0.245
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_material("PlayerBootsCleat"))
		surface.set_smooth_group(0)
		for triangle in range(0, indices.size(), 3):
			for corner in ([0, 1, 2] if side == "Left" else [0, 2, 1]):
				var vertex := oriented[indices[triangle + corner]]
				var normalized := (vertex - source_bounds.position) / source_bounds.size
				var mirrored := normalized
				if side == "Right":
					mirrored.x = 1.0 - mirrored.x
				var rest_point := target_bounds.position + mirrored * target_bounds.size
				# Local shoe coordinates allow continuous sole/lace colors across
				# triangle boundaries, while the existing shop patterns use UV.
				surface.set_color(Color(normalized.x, normalized.y, normalized.z, 1))
				surface.set_uv(Vector2(atan2(normalized.z - 0.5, normalized.x - 0.5) / TAU + 0.5, normalized.y))
				surface.add_vertex(bind * rest_point)
		var mesh := _finish_mesh(surface, MODELS + "neon_cleat_" + side.to_lower() + ".res")
		var shoe := Node3D.new()
		shoe.name = side + "Cleat"
		pair.add_child(shoe)
		shoe.owner = pair
		var fitted := MeshInstance3D.new()
		fitted.name = "CleatGeometry"
		fitted.mesh = mesh
		shoe.add_child(fitted)
		fitted.owner = pair
	_save_scene(pair, "res://scenes/visuals/default_cleats.tscn")
	source.free()
	body.free()
