extends Node3D
## Swappable Meshy mouth fitted to the same head bone as the default eyes.
const DEFAULT_MOUTH := preload("res://scenes/visuals/default_mouth.tscn")

var attachment: BoneAttachment3D
var asset: Node3D


func setup(skeleton: Skeleton3D, source: PackedScene) -> void:
	var index := skeleton.find_bone("mixamorig_Head")
	if index < 0:
		push_error("The default mouth requires a mixamorig_Head bone")
		return
	attachment = BoneAttachment3D.new()
	attachment.name = "DefaultMouthAttachment"
	attachment.bone_name = skeleton.get_bone_name(index)
	attachment.set_meta("character_face_part", true)
	skeleton.add_child(attachment)
	asset = (source if source != null else DEFAULT_MOUTH).instantiate() as Node3D
	attachment.add_child(asset)
