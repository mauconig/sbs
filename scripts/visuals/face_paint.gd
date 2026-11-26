extends Node
## Paints the eyes, brows and mouth directly on the skin material.
## No extra face meshes: the skin shader draws the face in head-bone space, and this
## node keeps that space in sync with the animated (or ragdolled) head every pose update.

const SurfaceShader := preload("res://assets/materials/character_surface.gdshader")

var skeleton: Skeleton3D
var skin_mesh: MeshInstance3D
var head_bone := -1
var expression := 2
var blink := 1.0
var eye_color := Color("7344bd")


func setup(target_skeleton: Skeleton3D, model: Node, color: Color) -> void:
	skeleton = target_skeleton
	eye_color = color
	head_bone = skeleton.find_bone("mixamorig_Head")
	if head_bone < 0:
		push_error("The painted face requires a mixamorig_Head bone")
		return
	skin_mesh = model.find_child("Skin", true, false) as MeshInstance3D
	if skin_mesh == null:
		push_error("The painted face requires the body's Skin mesh")
		return
	if skeleton.has_signal("skeleton_updated"):
		skeleton.skeleton_updated.connect(_sync)
	refresh()


## Re-applies every face parameter, e.g. after the surface materials were rebuilt.
func refresh() -> void:
	var material := _material()
	if material == null:
		return
	material.set_shader_parameter("face_enabled", true)
	material.set_shader_parameter("face_expression", expression)
	material.set_shader_parameter("face_blink", blink)
	material.set_shader_parameter("eye_color", eye_color)
	_sync()


func set_expression(value: int) -> void:
	expression = value
	var material := _material()
	if material != null:
		material.set_shader_parameter("face_expression", expression)


func set_blink(amount: float) -> void:
	if is_equal_approx(amount, blink):
		return
	blink = amount
	var material := _material()
	if material != null:
		material.set_shader_parameter("face_blink", blink)


func set_eye_color(color: Color) -> void:
	eye_color = color
	var material := _material()
	if material != null:
		material.set_shader_parameter("eye_color", eye_color)


func _process(_delta: float) -> void:
	# Fallback for poses changed outside the skeleton's update signal (ragdoll, tools).
	_sync()


func _sync() -> void:
	if skeleton == null or head_bone < 0 or not skeleton.is_inside_tree():
		return
	var material := _material()
	if material == null:
		return
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(head_bone)
	material.set_shader_parameter("head_from_world", Projection(head.affine_inverse()))


func _material() -> ShaderMaterial:
	if skin_mesh == null or skin_mesh.mesh == null:
		return null
	var material := skin_mesh.get_surface_override_material(0) as ShaderMaterial
	if material == null or material.shader != SurfaceShader:
		return null
	return material
