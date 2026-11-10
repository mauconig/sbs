extends SceneTree
## Verifies actual bone/body movement and looping in four process-disabled models.
var actors: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var skeletons: Array[Skeleton3D] = []
var idle_chest_samples: Array[Quaternion] = []
var run_leg_samples: Array[Quaternion] = []
var failure := ""
var frames := 0


func _initialize() -> void:
	for _index in 4:
		var actor := load("res://scenes/visuals/character.tscn").instantiate() as Node3D
		actor.set("look",load("res://assets/characters/pip.tres"))
		actor.set("frozen",true)
		root.add_child(actor)
		actors.append(actor)


func _process(_delta: float) -> bool:
	frames += 1
	if frames>1:
		for actor in actors:
			actor.call("advance_animation",_delta)
	if frames==1:
		for actor in actors:
			var skeleton := actor.find_child("Skeleton3D",true,false) as Skeleton3D
			var player := actor.get("_animation_player") as AnimationPlayer
			skeletons.append(skeleton)
			players.append(player)
			actor.call("play",0)
			actor.call("_pose",0.0)
			# Mirror player.gd: it disables the visual node's own process callback.
			actor.set_process(false)
	if frames==2:
		for index in actors.size():
			_expect(not actors[index].get("_idle_animation").is_empty(),"Each instance must have an idle clip")
			_expect(players[index].is_playing(),"Idle must start at rest")
			_expect(players[index].current_animation==actors[index].get("_idle_animation"),"Rest must select idle")
			_expect(is_equal_approx(players[index].speed_scale,2.0),"Imported clips must play at twice their original speed")
			var skeleton := skeletons[index]
			idle_chest_samples.append(skeleton.get_bone_pose_rotation(skeleton.find_bone("mixamorig_Spine1")))
	if frames==30:
		for index in actors.size():
			var skeleton := skeletons[index]
			var chest := skeleton.get_bone_pose_rotation(skeleton.find_bone("mixamorig_Spine1"))
			_expect(idle_chest_samples[index].angle_to(chest)>0.001,"Idle must animate the chest after the player controller disables process")
			_expect(is_zero_approx((actors[index].get("rig") as Node3D).position.y),"Idle feet must remain planted")
			for side in ["Left","Right"]:
				var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+side+"Arm")).origin)
				var wrist := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+side+"Hand")).origin)
				_expect(shoulder.y-wrist.y>0.25,"Idle arms must hang down beside the body")
				_expect(absf(wrist.z-shoulder.z)<0.15,"Idle arms must not point forward")
	if frames==140:
		for index in actors.size():
			_expect(players[index].is_playing(),"Idle must continue after a full loop")
			actors[index].call("play",1)
			actors[index].call("_pose",0.0)
	if frames==150:
		for skeleton in skeletons:
			var leg := skeleton.find_bone("mixamorig_LeftUpLeg")
			run_leg_samples.append(skeleton.get_bone_pose_rotation(leg))
	if frames==160:
		for index in actors.size():
			var leg := skeletons[index].find_bone("mixamorig_LeftUpLeg")
			var current_leg := skeletons[index].get_bone_pose_rotation(leg)
			_expect(absf(run_leg_samples[index].dot(current_leg))<0.999,"Running must move the actual leg bones")
	if frames==280:
		for index in actors.size():
			_expect(players[index].is_playing(),"Running must continue through multiple loops")
			_expect(players[index].current_animation==actors[index].get("_run_animation"),"Movement must select the supplied Running clip")
		if failure.is_empty():
			print("MESHY ANIMATION PASS: relaxed arms, planted feet, skeletal breathing, running bone motion and 2x playback in four process-disabled instances")
		else:
			push_error("MESHY ANIMATION FAIL: "+failure)
			quit(1)
			return false
		quit()
	return false


func _expect(condition: bool,message: String) -> void:
	if not condition and failure.is_empty():
		failure = message
