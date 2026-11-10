extends RefCounted
## Shared sculpted mesh and material library for the visual prototype.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func material(color: Color, roughness: float = 0.72, unshaded: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(roughness) + str(unshaded)
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic_specular = 0.32
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = result
	return result


static func sphere() -> SphereMesh:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 24
		mesh.rings = 14
		_meshes["sphere"] = mesh
	return _meshes["sphere"]


static func ellipsoid(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var node := instance(parent, sphere(), mat, at)
	node.scale = dimensions
	return node


static func instance(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node


static func contour(rings: Array[Vector3], exponent: float = 1.0, segments: int = 40, offsets: Array[Vector2] = []) -> ArrayMesh:
	# Each ring specifies horizontal radius, height and depth. A superellipse
	# cross section creates soft, designed cheek / shoe / jersey contours.
	var key := str(rings) + str(exponent) + str(segments) + str(offsets)
	if _meshes.has(key):
		return _meshes[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in rings.size():
		for col in segments + 1:
			var angle := TAU * float(col) / segments
			var point := _ring_point(rings[row], angle, exponent)
			var offset := offsets[row] if offsets.size() == rings.size() else Vector2.ZERO
			point += Vector3(offset.x, 0.0, offset.y)
			vertices.append(point)
			var before := _ring_point(rings[maxi(0, row - 1)], angle, exponent)
			var after := _ring_point(rings[mini(rings.size() - 1, row + 1)], angle, exponent)
			var tangent := _ring_point(rings[row], angle + 0.01, exponent) - _ring_point(rings[row], angle - 0.01, exponent)
			var normal := (after - before).cross(tangent).normalized()
			normals.append(normal)
			uvs.append(Vector2(float(col) / segments, float(row) / (rings.size() - 1)))
	for row in rings.size() - 1:
		for col in segments:
			var a := row * (segments + 1) + col
			var b := a + segments + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	return mesh


static func _ring_point(ring: Vector3, angle: float, exponent: float) -> Vector3:
	var c := cos(angle)
	var s := sin(angle)
	return Vector3(ring.x * signf(c) * pow(absf(c), exponent), ring.y, ring.z * signf(s) * pow(absf(s), exponent))


static func strand(parent: Node3D, points: Array[Vector3], radii: Array[Vector2], mat: Material) -> MeshInstance3D:
	# A swept lock of hair, brow or trim, with an independently controlled taper.
	var smooth_points: Array[Vector3] = []
	var smooth_radii: Array[Vector2] = []
	for index in points.size()-1:
		for step in 5:
			var weight := step/5.0
			smooth_points.append(points[index].cubic_interpolate(points[index+1],points[maxi(0,index-1)],points[mini(points.size()-1,index+2)],weight))
			smooth_radii.append(radii[index].lerp(radii[index+1],weight))
	smooth_points.append(points[-1])
	smooth_radii.append(radii[-1])
	points = smooth_points
	radii = smooth_radii
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 14
	var vertices: Array[Vector3] = []
	for row in points.size():
		var tangent := points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]
		var up := Vector3.UP if absf(tangent.normalized().dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		var x := tangent.normalized().cross(up).normalized()
		var y := x.cross(tangent.normalized()).normalized()
		for col in sides:
			var angle := TAU * float(col) / sides
			vertices.append(points[row] + x * cos(angle) * radii[row].x + y * sin(angle) * radii[row].y)
	for row in points.size() - 1:
		for col in sides:
			var a := row * sides + col
			var b := row * sides + (col + 1) % sides
			var c := a + sides
			var d := b + sides
			for index in [a, b, c, b, d, c]:
				st.add_vertex(vertices[index])
	st.generate_normals()
	return instance(parent, st.commit(), mat)


static func number(parent: Node3D, text: String, at: Vector3, color: Color, back: bool = false, font_size: int = 86, pixel_size: float = 0.0035) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/BarlowCondensed-Black.ttf")
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = true
	label.double_sided = false
	label.position = at
	if not back:
		label.rotation.y = PI
	parent.add_child(label)
	return label
