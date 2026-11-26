extends SkeletonModifier3D
## Analytic two-arm grip over locomotion; recoil moves the hands and chest.
var weapon


func _process_modification() -> void:
	if weapon==null or not weapon.visible:
		return
	var skeleton := get_skeleton()
	var spine := skeleton.find_bone("mixamorig_Spine1")
	if spine>=0 and weapon.recoil_amount>0.0:
		var axis: Vector3=skeleton.global_basis.inverse()*weapon.character.global_basis.x.normalized()
		skeleton.set_bone_pose_rotation(spine,Quaternion(axis.normalized(),weapon.recoil_amount*0.08)*skeleton.get_bone_pose_rotation(spine))
	_arm(skeleton,"Right",weapon.trigger_position())
	_arm(skeleton,"Left",weapon.support_position())


func _arm(skeleton: Skeleton3D,side: String,target_world: Vector3) -> void:
	var upper := skeleton.find_bone("mixamorig_"+side+"Arm")
	var lower := skeleton.find_bone("mixamorig_"+side+"ForeArm")
	var hand := skeleton.find_bone("mixamorig_"+side+"Hand")
	if upper<0 or lower<0 or hand<0:
		return
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var c := skeleton.get_bone_global_pose(hand).origin
	var target := skeleton.to_local(target_world)
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var reach := target-a
	var distance := clampf(reach.length(),absf(first-second)+0.005,first+second-0.003)
	var forward := reach.normalized()
	var pole_world: Vector3=weapon.character.global_basis.x*(-1.0 if side=="Left" else 1.0)-Vector3.UP*0.8
	var pole := skeleton.global_basis.inverse()*pole_world
	pole=(pole-forward*pole.dot(forward)).normalized()
	var along := (first*first+distance*distance-second*second)/(2.0*distance)
	var height := sqrt(maxf(0.0,first*first-along*along))
	var elbow := a+forward*along+pole*height
	_turn(skeleton,upper,lower,elbow)
	skeleton.force_update_all_bone_transforms()
	_turn(skeleton,lower,hand,a+forward*distance)


func _turn(skeleton: Skeleton3D,index: int,child: int,target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(index)
	var before := skeleton.get_bone_global_pose(child).origin-pose.origin
	var after := target-pose.origin
	if before.length_squared()<0.00001 or after.length_squared()<0.00001:
		return
	pose.basis=Basis(Quaternion(before.normalized(),after.normalized()))*pose.basis
	var parent := skeleton.get_bone_parent(index)
	var local_basis := skeleton.get_bone_global_pose(parent).basis.inverse()*pose.basis if parent>=0 else pose.basis
	skeleton.set_bone_pose_rotation(index,local_basis.get_rotation_quaternion())
