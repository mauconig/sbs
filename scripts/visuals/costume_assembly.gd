extends Node3D
## Swappable fitted head and foot meshes, driven by the original animation rig.
const DEFAULT_HAIR := preload("res://scenes/visuals/default_hair.tscn")
const DEFAULT_CLEATS := preload("res://scenes/visuals/default_cleats.tscn")

var hair_attachment: BoneAttachment3D
var cleat_attachments: Array[BoneAttachment3D] = []
var hair: Node3D
var cleats: Array[Node3D] = []


func setup(skeleton: Skeleton3D, model: Node3D, look: Resource) -> void:
	hair_attachment = _attach(skeleton, "mixamorig_Head", "CocoaHairAttachment")
	if hair_attachment != null:
		var scene := look.get("hair_scene") as PackedScene
		hair = (scene if scene != null else DEFAULT_HAIR).instantiate() as Node3D
		hair_attachment.add_child(hair)
	var scene := look.get("cleats_scene") as PackedScene
	var pair := (scene if scene != null else DEFAULT_CLEATS).instantiate()
	for side in ["Left", "Right"]:
		var shoe := pair.get_node_or_null(side + "Cleat") as Node3D
		var ankle := _attach(skeleton, "mixamorig_" + side + "Foot", side + "FootCleatAttachment")
		if shoe == null or ankle == null:
			push_error("The cleat scene must contain LeftCleat and RightCleat")
			continue
		shoe.owner = null
		for child in shoe.find_children("*", "", true, false):
			child.owner = null
		pair.remove_child(shoe)
		ankle.add_child(shoe)
		cleats.append(shoe)
		cleat_attachments.append(ankle)
	pair.free()
	if cleats.size() == 2:
		var original := model.find_child("Boots", true, false) as MeshInstance3D
		if original != null:
			original.hide()


func _attach(skeleton: Skeleton3D, bone: String, label: String) -> BoneAttachment3D:
	if skeleton.find_bone(bone) < 0:
		push_error("Missing wearable bone: " + bone)
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = label
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment
