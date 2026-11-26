extends Node3D
## The supplied Meshy eyes, fitted to the animated head; no overlay eyeballs.
const DEFAULT_EYES := preload("res://scenes/visuals/default_eyes.tscn")

var eye_scene: PackedScene
var eye_color := Color("7344bd")
var attachment: BoneAttachment3D
var asset: Node3D
var _eye_surfaces: Node3D
var _iris_material: StandardMaterial3D
var _base_scale := Vector3.ONE


func setup(skeleton: Skeleton3D, source: PackedScene, color: Color) -> void:
	eye_scene = source if source != null else DEFAULT_EYES
	eye_color = color
	var head_index := skeleton.find_bone("mixamorig_Head")
	if head_index < 0:
		push_error("The default eye mesh requires a mixamorig_Head bone")
		return
	attachment = BoneAttachment3D.new()
	attachment.name = "DefaultEyesAttachment"
	attachment.set_meta("character_face_part", true)
	attachment.bone_name = skeleton.get_bone_name(head_index)
	skeleton.add_child(attachment)
	asset = eye_scene.instantiate() as Node3D
	_eye_surfaces = asset.find_child("EyeSurfaces", true, false) as Node3D
	if _eye_surfaces != null:
		_base_scale = _eye_surfaces.scale
	attachment.add_child(asset)
	# Duplicate only the iris material so customization never changes other players.
	for visual in asset.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := visual as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material != null and material.resource_name == "Iris":
				_iris_material = material.duplicate() as StandardMaterial3D
				_iris_material.albedo_color = eye_color
				mesh_instance.set_surface_override_material(surface, _iris_material)


func set_blink(amount: float) -> void:
	if _eye_surfaces != null:
		_eye_surfaces.scale = Vector3(_base_scale.x, _base_scale.y * maxf(amount, 0.05), _base_scale.z)


func set_eye_color(color: Color) -> void:
	eye_color = color
	if _iris_material != null:
		_iris_material.albedo_color = eye_color
