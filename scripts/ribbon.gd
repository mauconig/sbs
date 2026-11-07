extends RefCounted
## Builds an immediate-mode ribbon strip from a list of world points.


static func build(
	mesh: ImmediateMesh,
	points: Array,
	width: float,
	color_near: Color,
	color_far: Color,
	camera_position: Vector3
) -> void:
	mesh.clear_surfaces()
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var last := maxi(points.size() - 1, 1)
	for i in points.size():
		var point: Vector3 = points[i]
		var before: Vector3 = points[maxi(i - 1, 0)]
		var after: Vector3 = points[mini(i + 1, points.size() - 1)]
		var direction := after - before
		if direction.length() < 0.0001:
			direction = Vector3.FORWARD
		var to_camera := camera_position - point
		var side := direction.cross(to_camera)
		if side.length() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized() * width
		var t := float(i) / float(last)
		var color := color_near.lerp(color_far, t)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(point - side)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(point + side)
	mesh.surface_end()
