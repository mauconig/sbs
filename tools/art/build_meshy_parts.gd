extends SceneTree
## Fit the supplied grin and extract the supplied launcher from its static holder.
## godot --headless --path . --script res://tools/art/build_meshy_parts.gd

const MODELS := "res://assets/characters/models/"
const MOUTH_PIVOT := Vector3(0, 0.095, 0)
const MOUTH_SCALE := 21.0
var _head: TriangleMesh
var _face_depths: Dictionary = {}


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	_head = _head_surface()
	_build_mouth()
	_build_launcher()
	quit()


func _head_surface() -> TriangleMesh:
	var body := (load(MODELS + "meshy_blank_buddy.glb") as PackedScene).instantiate()
	var skin := body.find_child("Skin", true, false) as MeshInstance3D
	var bind := Transform3D.IDENTITY
	var found := false
	for index in skin.skin.get_bind_count():
		if skin.skin.get_bind_name(index) == "mixamorig_Head":
			bind = skin.skin.get_bind_pose(index)
			found = true
	assert(found, "The face parts require the original head bind pose")
	var head_mesh := ArrayMesh.new()
	for index in skin.mesh.get_surface_count():
		var source := skin.mesh.surface_get_arrays(index)
		var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		for vertex in points.size():
			points[vertex] = bind * points[vertex]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
		head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var triangles := head_mesh.generate_triangle_mesh()
	body.free()
	return triangles


func _material(label: String, color: Color, roughness: float = 0.58) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.12
	return material


func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	surface.set_smooth_group(0)
	return surface


func _build_mouth() -> void:
	var source := (load(MODELS + "big_grin_mouth.fbx") as PackedScene).instantiate()
	var visual := source.find_child("geometry_0", true, false) as MeshInstance3D
	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surfaces: Array[SurfaceTool] = [
		_surface(_material("GrinLips", Color("df747d"))),
		_surface(_material("GrinTeeth", Color("fff8e9"))),
		_surface(_material("GrinCreases", Color("a04c60")))
	]
	# Follow the existing inner contour of this supplied grin, retaining its teeth.
	var inner := PackedVector2Array([
		Vector2(-0.405, 0.07), Vector2(-0.386, 0.138), Vector2(-0.326, 0.176),
		Vector2(-0.275, 0.16), Vector2(-0.2, 0.13), Vector2(0, 0.11),
		Vector2(0.2, 0.13), Vector2(0.275, 0.16), Vector2(0.326, 0.176),
		Vector2(0.386, 0.138), Vector2(0.405, 0.07), Vector2(0.395, -0.02),
		Vector2(0.36, -0.09), Vector2(0.28, -0.145), Vector2(0.15, -0.175),
		Vector2(0, -0.19), Vector2(-0.15, -0.175), Vector2(-0.28, -0.145),
		Vector2(-0.36, -0.09), Vector2(-0.395, -0.02)
	])
	for triangle in range(0, indices.size(), 3):
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		var center := (a + b + c) / 3.0
		var region := 0
		if Geometry2D.is_point_in_polygon(Vector2(center.x, center.z) * 100.0, inner):
			region = 1 if center.y < -0.00021 else 2
		_emit_mouth(surfaces[region], a, b, c)
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		surface.generate_normals()
		surface.index()
		surface.commit(mesh)
	_save_mesh(mesh, MODELS + "big_grin_fitted.res")
	var mouth := Node3D.new()
	mouth.name = "MeshyBigGrin"
	mouth.position = MOUTH_PIVOT
	mouth.set_meta("source_asset", MODELS + "big_grin_mouth.fbx")
	var fitted := MeshInstance3D.new()
	fitted.name = "MouthGeometry"
	fitted.mesh = load(MODELS + "big_grin_fitted.res")
	mouth.add_child(fitted)
	fitted.owner = mouth
	_save_scene(mouth, "res://scenes/visuals/default_mouth.tscn")
	source.free()


func _emit_mouth(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var edges := Vector3(a.distance_squared_to(b), b.distance_squared_to(c), c.distance_squared_to(a))
	if maxf(edges.x, maxf(edges.y, edges.z)) > 0.001 * 0.001:
		if edges.x >= edges.y and edges.x >= edges.z:
			_emit_mouth(surface, a, (a + b) * 0.5, c)
			_emit_mouth(surface, (a + b) * 0.5, b, c)
		elif edges.y >= edges.z:
			_emit_mouth(surface, a, b, (b + c) * 0.5)
			_emit_mouth(surface, a, (b + c) * 0.5, c)
		else:
			_emit_mouth(surface, a, b, (c + a) * 0.5)
			_emit_mouth(surface, (c + a) * 0.5, b, c)
		return
	for point: Vector3 in [a, b, c]:
		var planar := Vector2(point.x * MOUTH_SCALE, point.z * MOUTH_SCALE + MOUTH_PIVOT.y)
		if not _face_depths.has(planar):
			var hit := _head.intersect_ray(Vector3(planar.x, planar.y, 1), Vector3(0, 0, -1))
			assert(not hit.is_empty(), "The grin must fit entirely on the head")
			_face_depths[planar] = (hit.position as Vector3).z
		var relief := (0.000383 - point.y) * MOUTH_SCALE * 0.45 + 0.003
		surface.add_vertex(Vector3(planar.x, planar.y, float(_face_depths[planar]) + relief) - MOUTH_PIVOT)


func _build_launcher() -> void:
	var source := (load(MODELS + "bazooka_holder.fbx") as PackedScene).instantiate()
	var visual := source.find_child("geometry_0", true, false) as MeshInstance3D
	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parts := _components(vertices, indices)
	var labels: PackedInt32Array = parts.labels
	var counts: Array = parts.counts
	var centers: Array[Vector3] = []
	var bounds: Array[AABB] = []
	for index in counts.size():
		centers.append(Vector3.ZERO)
		bounds.append(AABB())
	var seen: Dictionary = {}
	var initialized: Dictionary = {}
	for index in vertices.size():
		var point := vertices[index]
		var label := labels[index]
		if seen.has(point):
			continue
		seen[point] = true
		centers[label] += point
		if not initialized.has(label):
			bounds[label] = AABB(point, Vector3.ZERO)
			initialized[label] = true
		else:
			bounds[label] = bounds[label].expand(point)
	# Counts use welded positions; compute centroids from the matching unique set.
	var unique_counts: Array[int] = []
	unique_counts.resize(counts.size())
	seen.clear()
	for index in vertices.size():
		if not seen.has(vertices[index]):
			seen[vertices[index]] = true
			unique_counts[labels[index]] += 1
	for label in centers.size():
		centers[label] /= float(unique_counts[label])
	var body: int = counts.find(counts.max())
	var kept: Array[int] = []
	for label in counts.size():
		# The holder's two ears are separate from its body; neither is weapon geometry.
		if label != body and not (centers[label].y > 0.0005 and centers[label].z > 0.0013):
			kept.append(label)
	var barrel := kept[0]
	for label in kept:
		if counts[label] > counts[barrel]:
			barrel = label
	var barrel_center := _source_to_world(centers[barrel])
	var xx := 0.0
	var xz := 0.0
	var zz := 0.0
	for index in vertices.size():
		if labels[index] != barrel:
			continue
		var point := _source_to_world(vertices[index]) - barrel_center
		xx += point.x * point.x
		xz += point.x * point.z
		zz += point.z * point.z
	var angle := 0.5 * atan2(2.0 * xz, xx - zz)
	var forward := Vector3(cos(angle), 0, sin(angle))
	if forward.z < 0:
		forward = -forward
	var right := forward.cross(Vector3.UP)
	var frame := Basis(right, Vector3.UP, -forward)
	var low := INF
	var high := -INF
	for index in vertices.size():
		if labels[index] == barrel:
			var distance := _source_to_world(vertices[index]).dot(forward)
			low = minf(low, distance)
			high = maxf(high, distance)
	var scale_factor := 1.05 / (high - low)
	var origin := barrel_center + forward * ((low + high) * 0.5 - barrel_center.dot(forward))
	var barrel_material := ShaderMaterial.new()
	barrel_material.resource_name = "LauncherBody"
	barrel_material.shader = preload("res://assets/materials/bazooka_surface.gdshader")
	var materials: Array[Material] = [
		barrel_material,
		_material("LauncherTrim", Color("fff3dc")),
		_material("LauncherAccent", Color("ed3c92"))
	]
	var surfaces: Array[SurfaceTool] = []
	for material in materials:
		surfaces.append(_surface(material))
	var grip_label := -1
	var grip_low := 0.0
	for label in kept:
		if bounds[label].position.z < grip_low:
			grip_low = bounds[label].position.z
			grip_label = label
	for triangle in range(0, indices.size(), 3):
		var label := labels[indices[triangle]]
		if label not in kept:
			continue
		var points: Array[Vector3] = []
		for corner in 3:
			points.append(frame.inverse() * (_source_to_world(vertices[indices[triangle + corner]]) - origin) * scale_factor)
		var region := 0
		if label != barrel:
			region = 0 if label == grip_label else 1 if counts[label] > 100 else 2
		for point in points:
			surfaces[region].add_vertex(point)
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		surface.generate_normals()
		surface.index()
		surface.commit(mesh)
	_save_mesh(mesh, MODELS + "meshy_bazooka.res")
	var launcher := Node3D.new()
	launcher.name = "MeshyBazooka"
	launcher.set_meta("source_asset", MODELS + "bazooka_holder.fbx")
	var fitted := MeshInstance3D.new()
	fitted.name = "SuppliedLauncher"
	fitted.mesh = load(MODELS + "meshy_bazooka.res")
	launcher.add_child(fitted)
	fitted.owner = launcher
	var grip := frame.inverse() * (_source_to_world(bounds[grip_label].get_center()) - origin) * scale_factor
	_marker(launcher, "TriggerGrip", grip)
	_marker(launcher, "SupportGrip", Vector3(-0.12, -0.10, -0.08))
	_marker(launcher, "Muzzle", Vector3(0, 0, -0.57))
	_save_scene(launcher, "res://scenes/visuals/meshy_bazooka.tscn")
	print("MESHY_LAUNCHER extracted parts=", kept.size(), " forward=", forward, " grip=", grip)
	source.free()


func _source_to_world(point: Vector3) -> Vector3:
	return Vector3(point.x, point.z, -point.y) * 100.0


func _marker(parent: Node3D, label: String, position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = position
	parent.add_child(marker)
	marker.owner = parent


func _save_mesh(mesh: Mesh, path: String) -> void:
	var error := ResourceSaver.save(mesh, path)
	assert(error == OK, "Could not save " + path)


func _save_scene(node: Node3D, path: String) -> void:
	var scene := PackedScene.new()
	var error := scene.pack(node)
	assert(error == OK)
	error = ResourceSaver.save(scene, path)
	assert(error == OK, "Could not save " + path)
	node.free()
	print("MESHY_PART_BUILT ", path)


func _components(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var unique: Dictionary = {}
	var welded := PackedInt32Array()
	var neighbors: Array = []
	for point in vertices:
		var key := Vector3i(roundi(point.x * 1000000), roundi(point.y * 1000000), roundi(point.z * 1000000))
		if not unique.has(key):
			unique[key] = neighbors.size()
			neighbors.append([])
		welded.append(unique[key])
	for triangle in range(0, indices.size(), 3):
		for edge in 3:
			var a := welded[indices[triangle + edge]]
			var b := welded[indices[triangle + (edge + 1) % 3]]
			neighbors[a].append(b)
			neighbors[b].append(a)
	var groups := PackedInt32Array()
	groups.resize(neighbors.size())
	groups.fill(-1)
	var counts: Array[int] = []
	for start in neighbors.size():
		if groups[start] >= 0:
			continue
		var pending: Array[int] = [start]
		groups[start] = counts.size()
		var count := 0
		while not pending.is_empty():
			var current: int = pending.pop_back()
			count += 1
			for neighbor in neighbors[current]:
				if groups[neighbor] < 0:
					groups[neighbor] = counts.size()
					pending.append(neighbor)
		counts.append(count)
	var labels := PackedInt32Array()
	for vertex in welded:
		labels.append(groups[vertex])
	return {"labels": labels, "counts": counts}
