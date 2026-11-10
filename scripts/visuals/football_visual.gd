extends Node3D
## A curved truncated-icosahedron football with inset seams, not floating dots.
const Shapes := preload("res://scripts/visuals/shape_library.gd")
@export var radius := 0.36
var spin := Vector3(0.2,0.35,0.0)
var frozen := false


func _ready() -> void:
	var phi := (1.0+sqrt(5.0))*0.5
	var vertices: Array[Vector3] = []
	for a in [-1.0,1.0]:
		for b in [-phi,phi]:
			vertices.append(Vector3(0,a,b).normalized())
			vertices.append(Vector3(a,b,0).normalized())
			vertices.append(Vector3(b,0,a).normalized())
	var edge := vertices[0].distance_to(vertices[2])
	# Derive the shortest edge; this keeps topology independent of vertex order.
	edge = 10.0
	for a in vertices.size():
		for b in range(a+1,vertices.size()):
			edge = minf(edge,vertices[a].distance_to(vertices[b]))
	var dark := SurfaceTool.new()
	var white := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	white.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in vertices.size():
		var points: Array[Vector3] = []
		for b in vertices.size():
			if absf(vertices[a].distance_to(vertices[b])-edge)<0.01:
				points.append((vertices[a]*2+vertices[b]).normalized())
		_panel(dark,points,vertices[a])
	for a in vertices.size():
		for b in range(a+1,vertices.size()):
			for c in range(b+1,vertices.size()):
				if absf(vertices[a].distance_to(vertices[b])-edge)>0.01 or absf(vertices[a].distance_to(vertices[c])-edge)>0.01 or absf(vertices[b].distance_to(vertices[c])-edge)>0.01:
					continue
				var points: Array[Vector3] = [(vertices[a]*2+vertices[b]).normalized(),(vertices[b]*2+vertices[a]).normalized(),(vertices[b]*2+vertices[c]).normalized(),(vertices[c]*2+vertices[b]).normalized(),(vertices[c]*2+vertices[a]).normalized(),(vertices[a]*2+vertices[c]).normalized()]
				_panel(white,points,(vertices[a]+vertices[b]+vertices[c]).normalized())
	Shapes.instance(self,dark.commit(),Shapes.material(Color("25243d"),0.48))
	Shapes.instance(self,white.commit(),Shapes.material(Color("fffdf2"),0.42))
	Shapes.ellipsoid(self,Vector3.ZERO,Vector3.ONE*radius*0.95,Shapes.material(Color("4b475a"),0.7))


func _panel(st: SurfaceTool,points: Array[Vector3],normal: Vector3) -> void:
	var tangent := normal.cross(Vector3.UP).normalized()
	if tangent.length()<0.1:
		tangent = normal.cross(Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent).normalized()
	points.sort_custom(func(a: Vector3,b: Vector3) -> bool: return atan2(a.dot(bitangent),a.dot(tangent))<atan2(b.dot(bitangent),b.dot(tangent)))
	for index in points.size():
		var a := points[index].lerp(normal,0.025).normalized()
		var b := points[(index+1)%points.size()].lerp(normal,0.025).normalized()
		var middle := (a+b).normalized()
		for triangle in [[normal,a,middle],[normal,middle,b]]:
			_subdivide(st,triangle[0],triangle[1],triangle[2],3)


func _subdivide(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,depth: int) -> void:
	if depth==0:
		for point in [a,c,b]:
			st.set_normal(point)
			st.add_vertex(point*radius)
		return
	var ab := (a+b).normalized()
	var bc := (b+c).normalized()
	var ca := (c+a).normalized()
	_subdivide(st,a,ab,ca,depth-1)
	_subdivide(st,ab,b,bc,depth-1)
	_subdivide(st,ca,bc,c,depth-1)
	_subdivide(st,ab,bc,ca,depth-1)


func _process(delta: float) -> void:
	if not frozen:
		rotation += spin*delta
