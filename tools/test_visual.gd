extends SceneTree
## Exercises animation phases and presentation controls inside the real scene.
var scene: Node
var frames := 0


func _initialize() -> void:
	scene = load("res://scenes/visual_prototype.tscn").instantiate()
	root.add_child(scene)


func _process(_delta: float) -> bool:
	frames += 1
	if frames!=4:
		return false
	assert(scene.characters.size()==4,"Four cast members must be present")
	var default_actor: Node3D = scene.characters[0]
	assert(default_actor.get("_authored_model"),"The default character must use the authored Blender asset")
	assert(default_actor.get("_animation_player") != null,"The default model must load its skeleton animations")
	assert(not default_actor.get("_run_animation").is_empty(),"The default model must expose its Running clip")
	for animation_key in ["_walk_animation","_jump_animation","_kick_animation","_slide_animation","_charge_animation","_dive_animation","_moving_kick_animation","_knockdown_animation"]:
		assert(not String(default_actor.get(animation_key)).is_empty(),"Missing imported clip: "+animation_key)
	default_actor.set("frozen",true)
	default_actor.set("time",0.0)
	default_actor.set("phase_offset",0.0)
	default_actor.call("play",0)
	default_actor.call("_pose",0.0)
	assert(default_actor._animation_player.is_playing(),"The default model must have an idle animation")
	assert(default_actor._animation_player.current_animation==default_actor.get("_idle_animation"),"The relaxed idle pose must be selected at rest")
	var model_bounds := _model_bounds(default_actor,default_actor)
	var largest_model_axis := maxf(model_bounds.size.x,maxf(model_bounds.size.y,model_bounds.size.z))
	assert(largest_model_axis>1.7 and largest_model_axis<1.9,"Default model must be 25% smaller")
	for actor in scene.characters:
		assert(actor.get("_skeletal_model"),"Every character must use the current Meshy model")
	for actor in scene.characters:
		actor.frozen = true
		for action in 6:
			actor.play(action)
			for sample in [0.0,0.16,0.45,0.65,1.1,1.5]:
				actor.time = sample
				actor.action_time = sample
				actor._pose(0.0)
				assert(actor.rig.transform.is_finite(),"Animation produced an invalid transform")
				assert(actor.rig.scale.y>0.5,"Animation squash collapsed the rig")
		actor.play(2)
		actor.action_time = 0.15
		actor._pose(0.0)
		if not actor.get("_skeletal_model"):
			assert(actor.rig.scale.y<1.0,"Procedural jump needs anticipation")
		actor.action_time = 0.6
		actor._pose(0.0)
		if actor.get("_skeletal_model"):
			assert(is_zero_approx(actor.rig.position.y),"Imported jump must not receive a second procedural lift")
		else:
			assert(actor.rig.position.y>0.7,"Procedural jump needs a readable midair pose")
		actor.play(3)
		actor.action_time = 0.52
		actor._pose(0.0)
		if actor.right_leg != null:
			assert(actor.right_leg.rotation.x>1.0,"Kick needs a clear follow-through")
		actor.apply_expression(2)
		actor.play(4)
		actor._pose(0.0)
		assert(actor._face_expression==4,"Celebration must change the face")
		actor.play(0)
		actor._pose(0.0)
		assert(actor._face_expression==2,"Selected face must return after cheering")
	default_actor.play(1)
	default_actor._pose(0.0)
	assert(default_actor._animation_player.is_playing(),"The supplied running animation must play")
	assert(default_actor._animation_player.current_animation==default_actor.get("_run_animation"),"The Running clip must be selected")
	assert(default_actor._animation_player.get_animation(default_actor.get("_run_animation")).loop_mode==Animation.LOOP_LINEAR,"Running must loop instead of ending in a T-pose")
	for pose_and_clip in [[2,"_jump_animation"],[3,"_kick_animation"],[5,"_slide_animation"],[6,"_walk_animation"],[7,"_charge_animation"],[8,"_dive_animation"],[9,"_moving_kick_animation"],[10,"_knockdown_animation"]]:
		default_actor.play(pose_and_clip[0])
		default_actor._pose(0.0)
		assert(default_actor._animation_player.current_animation==default_actor.get(pose_and_clip[1]),"Pose must select its matching imported clip: "+pose_and_clip[1])
	_key(KEY_TAB)
	assert(scene.selected==1,"Tab must select the next cast member")
	_key(KEY_CTRL)
	assert(scene.characters[1].animation==5,"Ctrl must show the sweep pose")
	_key(KEY_SPACE)
	assert(scene.characters[1].animation==5,"Jump must not interrupt an active sweep")
	scene._controls(2.0)
	_key(KEY_SPACE)
	assert(scene.characters[1].animation==2,"Space must show the jump")
	_key(KEY_P)
	assert(scene.paused,"P must pause the presentation")
	_key(KEY_P)
	assert(not scene.paused,"P must resume the presentation")
	scene.stage_lineup()
	assert(scene.camera.global_transform.is_finite(),"Lineup camera is invalid")
	print("VISUAL PASS: four smaller Meshy instances, all action clips, cast selection, Ctrl sweep, Space jump, pause, lineup camera")
	# Explicit cleanup also catches leaked scene ownership in the new visual code.
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
	return false


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	scene._unhandled_input(event)


func _model_bounds(node: Node3D, reference: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_boxes(node,reference,boxes)
	assert(not boxes.is_empty(),"Character has no visible geometry")
	var result := boxes[0]
	for box in boxes:
		result = result.merge(box)
	return result


func _collect_boxes(node: Node3D, reference: Node3D, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D:
		var transform := reference.global_transform.affine_inverse()*node.global_transform
		boxes.append(transform*node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect_boxes(child,reference,boxes)
