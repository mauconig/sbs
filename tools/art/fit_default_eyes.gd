extends SceneTree
## Rebuilds the default eye scene from the supplied Meshy FBX, fitted to the head.
## Run: godot --headless --path . --script res://tools/art/fit_default_eyes.gd

const SOURCE := "res://assets/characters/models/suspicious_stare_eyes.fbx"
const BODY := "res://assets/characters/models/meshy_blank_buddy.glb"
const MESH_OUTPUT := "res://assets/characters/models/suspicious_stare_fitted.res"
const BROW_OUTPUT := "res://assets/characters/models/suspicious_stare_brows.res"
const SCENE_OUTPUT := "res://scenes/visuals/default_eyes.tscn"
const FIT_SCALE := 58.0
const PIVOT := Vector3(0.0, 0.28, 0.0)
const BROW_SCALE := Vector2(0.90, 0.80)
const BROW_LIFT := 0.035
const MAX_FIT_EDGE := 0.0005


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var source := (load(SOURCE) as PackedScene).instantiate()
	var body := (load(BODY) as PackedScene).instantiate()
	var imported := source.find_child("geometry_0", true, false) as MeshInstance3D
	var skin := body.find_child("Skin", true, false) as MeshInstance3D
	assert(imported != null and skin != null, "The eye source and body skin must exist")
	var bind := Transform3D.IDENTITY
	var found_head := false
	for index in skin.skin.get_bind_count():
		if skin.skin.get_bind_name(index) == "mixamorig_Head":
			bind = skin.skin.get_bind_pose(index)
			found_head = true
	assert(found_head, "The eye fit requires the head's inverse bind matrix")
	var head_mesh := ArrayMesh.new()
	for surface in skin.mesh.get_surface_count():
		var original := skin.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		for index in points.size():
			points[index] = bind * points[index]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_INDEX] = original[Mesh.ARRAY_INDEX]
		head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var head_triangles := head_mesh.generate_triangle_mesh()
	var arrays := imported.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var components := _components(vertices, indices)
	var labels: PackedInt32Array = components.labels
	var counts: Array = components.counts
	var bounds: Array[AABB] = []
	for component in counts.size():
		bounds.append(AABB())
	var started: Dictionary = {}
	for index in vertices.size():
		var label := labels[index]
		if not started.has(label):
			bounds[label] = AABB(vertices[index], Vector3.ZERO)
			started[label] = true
		else:
			bounds[label] = bounds[label].expand(vertices[index])
	var materials: Array[StandardMaterial3D] = []
	for spec in [["Sclera", Color("fff9ff")], ["Iris", Color("7344bd")], ["Brows", Color("30223c")]]:
		var material := StandardMaterial3D.new()
		material.resource_name = spec[0]
		material.albedo_color = spec[1]
		material.roughness = 0.64 if spec[0] == "Brows" else 0.48
		material.metallic_specular = 0.12
		materials.append(material)
	var surfaces: Array[SurfaceTool] = []
	var face_counts := [0, 0, 0]
	for material in materials:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		surface.set_smooth_group(0)
		surfaces.append(surface)
	var fitted: Dictionary = {}
	for triangle in range(0, indices.size(), 3):
		var label := labels[indices[triangle]]
		var region := 2 if counts[label] < 120 else 0
		var center := bounds[label].get_center()
		# The supplied model already has an inset circular iris inside each rim.
		# Its inner loop is separated from the outer rim by a clear radial gap.
		if region == 0:
			var inner_radius := minf(bounds[label].size.x, bounds[label].size.z) * 0.45
			var inside := true
			for corner in 3:
				var point := vertices[indices[triangle + corner]]
				if Vector2(point.x - center.x, point.z - center.z).length() > inner_radius:
					inside = false
			if inside:
				region = 1
		face_counts[region] += 1
		_emit_fitted_triangle(surfaces[region], vertices[indices[triangle]], vertices[indices[triangle + 1]], vertices[indices[triangle + 2]], center, region == 2, head_triangles, fitted)
	var mesh := ArrayMesh.new()
	var brow_mesh := ArrayMesh.new()
	for index in surfaces.size():
		var surface := surfaces[index]
		surface.generate_normals()
		surface.index()
		surface.commit(brow_mesh if index == 2 else mesh)
	assert(face_counts[1] > 0, "The supplied iris faces must be retained")
	assert(ResourceSaver.save(mesh, MESH_OUTPUT) == OK)
	assert(ResourceSaver.save(brow_mesh, BROW_OUTPUT) == OK)
	var eyes := Node3D.new()
	eyes.name = "MeshySuspiciousEyes"
	eyes.position = PIVOT
	eyes.set_meta("source_asset", SOURCE)
	var visual := MeshInstance3D.new()
	visual.name = "EyeSurfaces"
	visual.mesh = load(MESH_OUTPUT)
	eyes.add_child(visual)
	visual.owner = eyes
	var brow_visual := MeshInstance3D.new()
	brow_visual.name = "Eyebrows"
	brow_visual.mesh = load(BROW_OUTPUT)
	eyes.add_child(brow_visual)
	brow_visual.owner = eyes
	var scene := PackedScene.new()
	assert(scene.pack(eyes) == OK)
	assert(ResourceSaver.save(scene, SCENE_OUTPUT) == OK)
	print("DEFAULT_EYES_FITTED faces sclera/iris/brows=", face_counts, " scene=", SCENE_OUTPUT)
	eyes.free()
	source.free()
	body.free()
	quit()


func _emit_fitted_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, brow: bool, head: TriangleMesh, fitted: Dictionary) -> void:
	# Large flat brow triangles cut into a convex forehead even when their
	# corners touch the skin. Add detail before projecting the entire surface.
	var edges := Vector3(a.distance_squared_to(b), b.distance_squared_to(c), c.distance_squared_to(a))
	if maxf(edges.x, maxf(edges.y, edges.z)) > MAX_FIT_EDGE * MAX_FIT_EDGE:
		if edges.x >= edges.y and edges.x >= edges.z:
			var midpoint := (a + b) * 0.5
			_emit_fitted_triangle(surface, a, midpoint, c, center, brow, head, fitted)
			_emit_fitted_triangle(surface, midpoint, b, c, center, brow, head, fitted)
		elif edges.y >= edges.z:
			var midpoint := (b + c) * 0.5
			_emit_fitted_triangle(surface, a, b, midpoint, center, brow, head, fitted)
			_emit_fitted_triangle(surface, a, midpoint, c, center, brow, head, fitted)
		else:
			var midpoint := (c + a) * 0.5
			_emit_fitted_triangle(surface, a, b, midpoint, center, brow, head, fitted)
			_emit_fitted_triangle(surface, midpoint, b, c, center, brow, head, fitted)
		return
	for point in [a, b, c]:
		var planar := Vector2(point.x, point.z) * FIT_SCALE + Vector2(0, PIVOT.y)
		if brow:
			var brow_center := Vector2(center.x, center.z) * FIT_SCALE + Vector2(0, PIVOT.y)
			planar = brow_center + (planar - brow_center) * BROW_SCALE + Vector2(0, BROW_LIFT)
		if not fitted.has(planar):
			var hit := head.intersect_ray(Vector3(planar.x, planar.y, 1), Vector3(0, 0, -1))
			assert(not hit.is_empty(), "An eye vertex missed the head surface")
			fitted[planar] = (hit.position as Vector3).z
		var relief: float = (0.000305 - point.y) * FIT_SCALE * (0.25 if brow else 0.5) + 0.004
		surface.add_vertex(Vector3(planar.x, planar.y, float(fitted[planar]) + relief) - PIVOT)


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
			var current := pending.pop_back() as int
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
