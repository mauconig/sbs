extends RefCounted
## Rebuilds flat-shaded imported meshes with smooth, area-weighted normals.
## The Meshy body ships every triangle with its own normal, which reads as faceting
## once the characters receive real scene light. Everything else (UVs, UV2 print
## coordinates, vertex colours, bones and weights) is kept unchanged.

static var _cache: Dictionary = {}


static func apply(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh is ArrayMesh:
			instance.mesh = smoothed(instance.mesh as ArrayMesh)


static func smoothed(source: ArrayMesh) -> ArrayMesh:
	var key := source.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	if source.get_blend_shape_count() > 0:
		# Blend shapes would need matching normal deltas; leave such meshes alone.
		_cache[key] = source
		return source
	var result := ArrayMesh.new()
	result.resource_name = source.resource_name
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		if source.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(arrays)
		var flags := source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		result.surface_set_material(surface, source.surface_get_material(surface))
		result.surface_set_name(surface, source.surface_get_name(surface))
	_cache[key] = result
	return result


static func _smooth_normals(arrays: Array) -> PackedVector3Array:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(points.size())
		for index in points.size():
			indices[index] = index
	# Vertices that share a position share one normal.
	var groups := PackedInt32Array()
	groups.resize(points.size())
	var lookup: Dictionary = {}
	for index in points.size():
		var position := points[index].snapped(Vector3.ONE * 0.00005)
		if not lookup.has(position):
			lookup[position] = lookup.size()
		groups[index] = lookup[position]
	var sums := PackedVector3Array()
	sums.resize(lookup.size())
	for corner in range(0, indices.size() - 2, 3):
		var a := indices[corner]
		var b := indices[corner + 1]
		var c := indices[corner + 2]
		# Unnormalized cross product: larger triangles count more.
		var face := (points[c] - points[a]).cross(points[b] - points[a])
		sums[groups[a]] += face
		sums[groups[b]] += face
		sums[groups[c]] += face
	var original: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normals := PackedVector3Array()
	normals.resize(points.size())
	for index in points.size():
		var normal := sums[groups[index]]
		if normal.length_squared() < 1e-20:
			normals[index] = original[index] if index < original.size() else Vector3.UP
			continue
		normal = normal.normalized()
		# Keep the imported winding convention (Godot uses clockwise front faces).
		if index < original.size() and normal.dot(original[index]) < 0.0:
			normal = -normal
		normals[index] = normal
	return normals
