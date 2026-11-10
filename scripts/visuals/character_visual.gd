extends Node3D
const MovementTuning := preload("res://scripts/movement_tuning.gd")
## The current Meshy character with reusable skeletal action playback.
## Every animation is cosmetic; this scene has no football or network rules.

const AuthoredSurface := preload("res://scripts/visuals/character_surface.gd")
const ShirtPrint := preload("res://scripts/visuals/shirt_print.gd")

@export var look: Resource
@export_enum("Idle", "Run", "Jump", "Kick", "Celebrate", "Sweep", "Walk", "Charge", "Dive", "MovingKick", "Knockdown") var animation := 0
@export_enum("Neutral", "Happy", "Determined", "Surprised", "Celebrating") var expression := 2
@export var phase_offset := 0.0
@export_range(0.1, 4.0) var animation_speed := 2.0
@export_range(0.25, 2.0) var model_scale := 1.05
## Optional gameplay window; fit the complete slide and get-up inside it.
@export var sweep_duration_override := 0.0
@export var sweep_motion_duration := 0.48
@export var jump_duration_override := MovementTuning.NORMAL_JUMP_DURATION
@export var dive_duration := 0.9
@export var knockdown_duration := 1.7

var rig: Node3D
var head: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var brows: Array[Node3D] = []
var eyes: Array[Node3D] = []
var _eye_rest_scales: Array[Vector3] = []
var mouth: Node3D
var time := 0.0
var action_time := 0.0
var frozen := false
var _previous_animation := -1
var _face_expression := -1
var _authored_model := false
var _skeletal_model := false
var _animation_player: AnimationPlayer
var _model_root: Node3D
var _shirt_print: SubViewport
var _run_animation := ""
var _walk_animation := ""
var _jump_animation := ""
var _kick_animation := ""
var _slide_animation := ""
var _charge_animation := ""
var _idle_animation := ""
var _dive_animation := ""
var _moving_kick_animation := ""
var _knockdown_animation := ""


func _ready() -> void:
	if look == null:
		look = load("res://assets/characters/pip.tres")
	look.changed.connect(_refresh_surface)
	var authored_scene := look.get("model_scene") as PackedScene
	if authored_scene != null:
		_load_authored_model(authored_scene)
		apply_expression(expression)
		return
	push_error("Character look must provide the current authored model_scene")


func _refresh_surface() -> void:
	if is_instance_valid(_model_root):
		_shirt_print.call("set_identity",look.display_name,look.number)
		AuthoredSurface.apply(_model_root,look,_shirt_print.get_texture())


func _load_authored_model(scene: PackedScene) -> void:
	var motion_rig := Node3D.new()
	motion_rig.name = "ModelMotionRig"
	add_child(motion_rig)
	var model := scene.instantiate() as Node3D
	_model_root = model
	motion_rig.add_child(model)
	# The Meshy FBX faces Blender's +Y axis; rotate it to this project's -Z front.
	model.rotation.y = PI
	model.scale = Vector3.ONE * model_scale
	_shirt_print = ShirtPrint.new()
	add_child(_shirt_print)
	_refresh_surface()
	_authored_model = true
	_skeletal_model = model.find_child("Skeleton3D",true,false) != null
	rig = model.find_child("AnimationRig",true,false) as Node3D
	if rig == null:
		# Imported skeletal assets animate their Skeleton3D; use the instance root
		# for simple whole-body poses such as jumping and knockdown.
		rig = motion_rig
	_animation_player = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if _animation_player != null:
		var rest_animation: Animation
		for animation_name in _animation_player.get_animation_list():
			var normalized_name := animation_name.to_lower()
			if "running" in normalized_name or normalized_name == "run":
				_run_animation = animation_name
			elif "walking" in normalized_name or normalized_name == "walk":
				_walk_animation = animation_name
			elif "regular_jump" in normalized_name or normalized_name == "jump":
				_jump_animation = animation_name
			elif "kick_a_soccer_ball" in normalized_name or "kick" == normalized_name:
				_kick_animation = animation_name
			elif normalized_name == "moving_kick":
				_moving_kick_animation = animation_name
			elif normalized_name == "forward_dive":
				_dive_animation = animation_name
			elif normalized_name == "knockdown":
				_knockdown_animation = animation_name
			elif "slide_right" in normalized_name or "sweep" == normalized_name:
				_slide_animation = animation_name
			elif "forward_charge" in normalized_name or "charge" == normalized_name:
				_charge_animation = animation_name
			elif "rest" in normalized_name:
				rest_animation = _animation_player.get_animation(animation_name)
			elif normalized_name == "idle":
				_idle_animation = animation_name
			if normalized_name in ["idle", "running", "walking", "standard_forward_charge_inplace"]:
				_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		if _idle_animation.is_empty() and rest_animation != null:
			_create_idle_animation(rest_animation)
	head = model.find_child("HeadAndExpression",true,false) as Node3D
	left_leg = model.find_child("LeftLeg",true,false) as Node3D
	right_leg = model.find_child("RightLeg",true,false) as Node3D
	left_arm = model.find_child("LeftArm",true,false) as Node3D
	right_arm = model.find_child("RightArm",true,false) as Node3D
	for face_node_name in ["BrowLeft","BrowRight"]:
		var brow := model.find_child(face_node_name,true,false) as Node3D
		if brow != null:
			brows.append(brow)
	for face_node_name in ["EyeLeft","EyeRight"]:
		var eye := model.find_child(face_node_name,true,false) as Node3D
		if eye != null:
			eyes.append(eye)
	for eye in eyes:
		_eye_rest_scales.append(eye.scale)
	mouth = model.find_child("Mouth",true,false) as Node3D


func apply_expression(value: int) -> void:
	expression = value
	_face_expression = value
	for index in brows.size():
		var side := -1.0 if index == 0 else 1.0
		brows[index].rotation.z = side * (0.35 if _authored_model and value==2 else 0.19 if value == 2 else -0.1)
		var brow_height := 0.18 if _authored_model else 0.17 if look.hairstyle==0 else 0.23
		brows[index].position.y = 0.29 if value == 3 else brow_height
		eyes[index].rotation.z = side*0.1 if value==2 else 0.0
	if mouth == null:
		return
	mouth.scale = Vector3(1.0,1.0,1.0)
	if value == 0:
		mouth.scale.y = 0.4
	elif value == 1 or value == 4:
		mouth.scale = Vector3(1.2,1.4,1)
	elif value == 3:
		mouth.scale = Vector3(0.65,1.65,1)
	elif value == 2:
		mouth.scale = Vector3.ONE if _authored_model else Vector3(0.95,0.65,1)


func play(value: int) -> void:
	if animation == value:
		return
	animation = value
	action_time = 0.0
	_previous_animation = value
	# The M2 controller disables this node's _process() and drives its pose
	# directly, so start the imported clip here as well as from _pose().
	_play_model_animation()


func _create_idle_animation(source: Animation) -> void:
	var idle := source.duplicate() as Animation
	idle.resource_name = "Pip_Idle"
	idle.length = 2.4
	idle.loop_mode = Animation.LOOP_LINEAR
	for track in idle.get_track_count():
		var path := String(idle.track_get_path(track))
		if idle.track_get_key_count(track) == 0:
			continue
		if idle.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var rest_rotation: Quaternion = idle.track_get_key_value(track,0)
			if "mixamorig_LeftArm" in path or "mixamorig_RightArm" in path:
				# Legacy fallback; Meshy uses its Blender-authored Idle clip.
				var relaxed_rotation := rest_rotation * Quaternion(Vector3.RIGHT,1.4)
				idle.track_set_key_value(track,0,relaxed_rotation)
				idle.track_insert_key(track,idle.length*0.5,relaxed_rotation*Quaternion(Vector3.RIGHT,0.06))
				idle.track_insert_key(track,idle.length,relaxed_rotation)
	var library := _animation_player.get_animation_library("")
	if library.add_animation("Idle",idle) == OK:
		_idle_animation = "Idle"


func _play_model_animation() -> void:
	if _animation_player == null:
		return
	_animation_player.speed_scale = animation_speed
	if animation == 5 and sweep_duration_override > 0.0 and not _slide_animation.is_empty():
		# Reach the end of the slide when travel stops; play the get-up at rest.
		var length := _animation_player.get_animation(_slide_animation).length
		var elapsed := action_time/maxf(animation_speed,0.1)
		_animation_player.speed_scale = length*0.6/sweep_motion_duration if elapsed<sweep_motion_duration else length*0.4/maxf(0.01,sweep_duration_override-sweep_motion_duration)
	elif animation == 2 and jump_duration_override > 0.0 and not _jump_animation.is_empty():
		_animation_player.speed_scale = _animation_player.get_animation(_jump_animation).length / jump_duration_override
	elif animation == 8 and not _dive_animation.is_empty():
		_animation_player.speed_scale = _animation_player.get_animation(_dive_animation).length / dive_duration
	elif animation == 10 and not _knockdown_animation.is_empty():
		_animation_player.speed_scale = _animation_player.get_animation(_knockdown_animation).length / knockdown_duration
	var target := _idle_animation
	match animation:
		1:
			target = _run_animation
		2:
			target = _jump_animation
		3:
			target = _kick_animation
		5:
			target = _slide_animation
		6:
			target = _walk_animation
		7:
			target = _charge_animation
		8:
			target = _dive_animation
		9:
			target = _moving_kick_animation
		10:
			target = _knockdown_animation
	if target.is_empty():
		target = _idle_animation
	if target.is_empty():
		return
	if _animation_player.current_animation != target:
		_animation_player.play(target,0.10)
	elif not _animation_player.is_playing() and _animation_player.get_animation(target).loop_mode != Animation.LOOP_NONE:
		_animation_player.play(target)


func animation_duration(value: int) -> float:
	if value == 10:
		return knockdown_duration
	if value == 2:
		return jump_duration_override
	if value == 8:
		return dive_duration
	if value == 5 and sweep_duration_override > 0.0:
		return sweep_duration_override
	if _animation_player == null:
		return (1.55 if value == 2 else 1.65 if value == 3 else 1.0) / maxf(animation_speed,0.1)
	var target := _moving_kick_animation if value == 9 else _kick_animation if value == 3 else _slide_animation if value == 5 else ""
	return (_animation_player.get_animation(target).length if not target.is_empty() else 1.0) / maxf(animation_speed,0.1)


func dribble_cycle() -> float:
	if _animation_player == null or animation not in [1,6]:
		return -1.0
	var target := _run_animation if animation == 1 else _walk_animation
	if target.is_empty() or _animation_player.current_animation != target:
		return -1.0
	# Contact phases measured from the imported left toe's forward-most position.
	var contact := 0.2105263 if animation == 1 else 0.1935484
	return fposmod(_animation_player.current_animation_position/_animation_player.current_animation_length-contact,1.0)


func _process(delta: float) -> void:
	if not frozen:
		advance_animation(delta)
	else:
		_pose(delta)
		if _animation_player != null:
			_animation_player.speed_scale = 0.0


func advance_animation(delta: float) -> void:
	time += delta * animation_speed
	action_time += delta * animation_speed
	_pose(delta)


func _pose(_delta: float) -> void:
	if _previous_animation != animation:
		action_time = 0.0
		_previous_animation = animation
	var t := time + phase_offset
	var legs := Vector2.ZERO
	var arms := Vector2.ZERO
	var lift := 0.0
	var lean := 0.0
	var roll := 0.0
	var arm_spread := 0.55 if _authored_model else 0.32
	var squash := Vector3.ONE
	match animation:
		0:
			# Keep the blank base visibly alive at gameplay distance: a slow breath,
			# gentle weight shift and soft head/shoulder sway rather than a frozen rest pose.
			var breath := sin(t*2.4)
			lift = breath*0.055
			roll = sin(t*1.3)*0.04
			lean = sin(t*1.1)*0.025
			squash = Vector3(1.0+breath*0.006,1.0+breath*0.012,1.0+breath*0.006)
			arms = Vector2(sin(t*1.7)*0.07,-sin(t*1.7)*0.07)
			if _authored_model and _idle_animation == "Idle":
				# The authored skeleton supplies the breath. Keep both feet planted.
				lift = 0.0
				roll = 0.0
				lean = 0.0
				squash = Vector3.ONE
		1:
			var wave := sin(t*11.0)
			legs = Vector2(wave,-wave)*0.85
			arms = Vector2(-wave,wave)*0.67
			lift = absf(cos(t*11.0))*0.075
			lean = -0.12
			roll = wave*0.045
		2:
			var cycle := fmod(action_time,1.55)
			if cycle < 0.18:
				var anticipation := sin(cycle/0.18*PI*0.5)
				squash = Vector3(1+anticipation*0.07,1-anticipation*0.12,1+anticipation*0.07)
			elif cycle < 1.05:
				var u := (cycle-0.18)/0.87
				lift = sin(u*PI)*0.85
				legs = Vector2(0.48,-0.34)
				arms = Vector2(-1.8,-1.8)
			else:
				var settle := sin((cycle-1.05)/0.5*PI)*0.09
				squash = Vector3(1+settle,1-settle,1+settle)
		3:
			var cycle := fmod(action_time,1.65)
			var angle := -0.7*smoothstep(0.0,0.35,cycle)
			angle = lerpf(angle,1.35,smoothstep(0.35,0.52,cycle))
			angle = lerpf(angle,0.0,smoothstep(0.6,1.15,cycle))
			legs = Vector2(-0.08,angle)
			arms = Vector2(-angle*0.4,angle*0.4)
			roll = angle*0.06
		4:
			lift = maxf(0.0,sin(t*6))*0.22
			arms = Vector2(-2.55,-2.55)
			legs = Vector2(sin(t*6)*0.2,-sin(t*6)*0.2)
			arm_spread = 0.35
			roll = sin(t*6)*0.06
		5:
			lean = 0.7
			lift = -0.3
			legs = Vector2(1.2,0.9)
			arms = Vector2(-0.5,-0.2)
			arm_spread = 0.4
		8:
			lean = -1.25*sin(clampf(action_time/(dive_duration*animation_speed),0,1)*PI)
			arms = Vector2(-2.4,-2.4)
			legs = Vector2(0.2,-0.1)
		9:
			var kick_phase := clampf(action_time,0,1)
			legs = Vector2(sin(t*11)*0.6,sin(kick_phase*PI)*1.3)
			arms = Vector2(-sin(t*11),sin(t*11))*0.5
	if _skeletal_model and animation in [2,3,5,8,9,10]:
		# Skeletal actions supply the pose; controllers own height and travel.
		# Extra whole-body tilts/lifts detach planted action poses from the ground.
		# A small contact margin also covers interpolation from the preceding gait.
		lift = 0.012 if animation == 10 else 0.0
		lean = 0.0
		roll = 0.0
		squash = Vector3.ONE
	var desired_expression := 4 if animation == 4 else expression
	if _face_expression != desired_expression:
		# Keep the selected expression when returning from a celebration.
		var selected := expression
		apply_expression(desired_expression)
		expression = selected
	_play_model_animation()
	if rig == null:
		return
	rig.position.y = lift
	rig.scale = squash
	rig.rotation = Vector3(lean,0,roll)
	if left_leg != null:
		left_leg.rotation.x = legs.x
	if right_leg != null:
		right_leg.rotation.x = legs.y
	if left_arm != null:
		left_arm.rotation = Vector3(arms.x,0,-arm_spread)
	if right_arm != null:
		right_arm.rotation = Vector3(arms.y,0,arm_spread)
	if head != null:
		head.rotation = Vector3(sin(t*1.4)*0.015,sin(t*0.9)*0.04,0)
	# Small asynchronous blinks keep the idle faces alive.
	var blink_time := fmod(t,4.7)
	var blink := 1.0 - sin(clampf((blink_time-4.48)/0.17,0.0,1.0)*PI)*0.92 if blink_time>4.48 else 1.0
	for index in eyes.size():
		eyes[index].scale.y = _eye_rest_scales[index].y*blink*(0.98 if _authored_model and _face_expression==2 else 0.87 if _face_expression==2 else 1.08 if _face_expression==3 else 1.0)
