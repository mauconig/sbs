extends MeshInstance3D
## Speed trail behind the ball. Built as a world-space ribbon.

const Ribbon := preload("res://scripts/ribbon.gd")

const MAX_POINTS := 20
const WIDTH := 0.07
const MIN_SPEED := 7.5

var _points: Array[Vector3] = []
var _mesh := ImmediateMesh.new()
var _body: RigidBody3D


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material


func _process(_delta: float) -> void:
	if _body == null:
		return
	global_transform = Transform3D.IDENTITY

	var speed := _body.linear_velocity.length()
	if speed > MIN_SPEED:
		_points.push_back(_body.global_position)
		while _points.size() > MAX_POINTS:
			_points.pop_front()
	elif _points.size() > 0:
		_points.pop_front()

	var camera := get_viewport().get_camera_3d()
	var camera_position := camera.global_position if camera else Vector3.ZERO
	Ribbon.build(
		_mesh,
		_points,
		WIDTH,
		Color(0.95, 0.85, 0.55, 0.55),
		Color(0.4, 0.7, 1.0, 0.0),
		camera_position
	)
