extends Node3D
## Visual playground sharing pitch dimensions, pace and ball controls with local 2v2.
const CharacterScene := preload("res://scenes/visuals/character.tscn")
const StadiumScene := preload("res://scenes/visuals/stadium.tscn")
const BallScript := preload("res://scripts/ball.gd")
const HudScript := preload("res://scripts/visuals/arcade_hud.gd")
const Shapes := preload("res://scripts/visuals/shape_library.gd")
const SweepMotion := preload("res://scripts/sweep_motion.gd")
const MovementTuning := preload("res://scripts/movement_tuning.gd")
const KickControllerScript := preload("res://scripts/kick_controller.gd")
const InputHubScript := preload("res://scripts/input_hub.gd")
const OutfitStore := preload("res://scripts/visuals/outfit_store.gd")
const KitShop := preload("res://scripts/ui/kit_shop.gd")
const Field := preload("res://scripts/field_config.gd")
const DayStadium := preload("res://scripts/visuals/day_stadium.gd")
const ItemSystem := preload("res://scripts/items/item_system.gd")

@export var outfit_path := OutfitStore.SAVE_PATH

var walk_speed := MovementTuning.WALK_SPEED
var sprint_speed := MovementTuning.SPRINT_SPEED
var dive_speed := MovementTuning.DIVE_SPEED
var normal_jump_speed := MovementTuning.NORMAL_JUMP_SPEED

var characters: Array[Node3D] = []
var camera: Camera3D
var ball: RigidBody3D
var kick_controller: Node
var hud: Control
var shop: CanvasLayer
var items: Node3D
var _shop_was_paused := false
var _shop_mouse_mode := Input.MOUSE_MODE_CAPTURED
var dust: Array[CPUParticles3D] = []
var selected := 0
var paused := false
var presentation_time := 0.0
var _was_moving := false
var _action_timers: Array[float] = [0.0,0.0,0.0,0.0]
var _vertical_velocity: Array[float] = [0.0,0.0,0.0,0.0]
var _knockback_velocity: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var _dive_directions: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var _sweep_directions: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var _sweep_cooldowns: Array[float] = [0.0,0.0,0.0,0.0]
var _stamina: Array[float] = [100.0,100.0,100.0,100.0]
var _regen_timers: Array[float] = [0.0,0.0,0.0,0.0]
var _exhaust_timers: Array[float] = [0.0,0.0,0.0,0.0]
var _exhausted: Array[bool] = [false,false,false,false]
var _sprinting := false
var _capture_mode := false
var _carrier_index := -1
var _ball_pickup_lock := 0.0
var _carrier_last_position := Vector3.ZERO
var _celebration_clock := 0.0
var _ball_home := Vector3(-7.0,0.23,-Field.HALF_LENGTH+30.6)
var _camera_home := Vector3(-5.8,2.7,-Field.HALF_LENGTH+34.9)
var _target_home := Vector3(-5.6,1.2,-Field.HALF_LENGTH+26.2)
var _camera_yaw := 0.0
var _camera_pitch := 10.0
var _camera_distance := 8.72
var _camera_min_distance := 3.0
var _camera_max_distance := 14.0
var _camera_sensitivity := 0.0028
var _weapon_shoulder := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_lighting()
	add_child(StadiumScene.instantiate())
	_add_camera_blockers()
	_cast()
	ball = BallScript.new()
	ball.position = _ball_home
	add_child(ball)
	camera = Camera3D.new()
	camera.name = "ArcadeCamera"
	camera.fov = 68
	camera.near = 0.08
	camera.far = 400
	add_child(camera)
	camera.position = _camera_home
	camera.look_at(_target_home)
	kick_controller = KickControllerScript.new()
	kick_controller.name = "SandboxKickController"
	kick_controller.set("player",characters[selected])
	kick_controller.set("camera",camera)
	kick_controller.set("ball",ball)
	kick_controller.set("input",InputHubScript.new())
	kick_controller.set("use_aim_override",true)
	kick_controller.connect("kicked",_on_sandbox_kicked)
	kick_controller.connect("passed",_on_sandbox_kicked)
	add_child(kick_controller)
	_sync_pass_teammates()
	var layer := CanvasLayer.new()
	hud = HudScript.new()
	layer.add_child(hud)
	add_child(layer)
	var initial_offset := _camera_home-_target_home
	_camera_yaw = atan2(initial_offset.x,initial_offset.z)
	_camera_pitch = rad_to_deg(asin(initial_offset.y/initial_offset.length()))
	_camera_distance = initial_offset.length()
	for character in characters:
		dust.append(_make_dust(character))
	shop = KitShop.new()
	shop.set("save_path",outfit_path)
	shop.connect("opened",_on_shop_opened)
	shop.connect("closed",_on_shop_closed)
	add_child(shop)
	_build_items()


func _lighting() -> void:
	DayStadium.add_daylight(self)


func _cast() -> void:
	var positions: Array[Vector3] = [Vector3(-5.6,0,-Field.HALF_LENGTH+30.0),Vector3(-3.9,0,-Field.HALF_LENGTH+29.3),Vector3(0.0,0,-Field.HALF_LENGTH+26.2),Vector3(-8.3,0,-Field.HALF_LENGTH+25.5)]
	var names := ["Pip","Buddy2","Buddy3","Buddy4"]
	for index in 4:
		var character := CharacterScene.instantiate() as Node3D
		character.name = names[index]
		var look := OutfitStore.load_look(outfit_path) if index == 0 else load("res://assets/characters/pip.tres").duplicate() as Resource
		if index != 0:
			look.set("display_name",names[index].to_upper())
		character.set("look",look)
		character.set("sweep_duration_override",SweepMotion.TOTAL_TIME)
		character.set("sweep_motion_duration",SweepMotion.MOTION_TIME)
		character.set("jump_duration_override",MovementTuning.NORMAL_JUMP_DURATION)
		character.position = positions[index]
		character.rotation.y = [0.0,-0.25,PI+0.25,PI-0.2][index]
		character.set("animation",[0,1,2,0][index])
		character.set("phase_offset",[0.15,0.8,0.2,1.4][index])
		add_child(character)
		characters.append(character)
		character.ragdoll_finished.connect(_on_sandbox_ragdoll_finished.bind(index))


func _process(delta: float) -> void:
	items.local_actor=characters[selected]
	kick_controller.inventory=items.inventory_for(characters[selected])
	_ball_pickup_lock = maxf(0.0,_ball_pickup_lock-delta)
	if not paused:
		presentation_time += delta
	if not _capture_mode:
		_controls(delta)
		if not paused:
			_update_sandbox_ball(delta)
		if kick_controller != null:
			kick_controller.set("player",characters[selected])
			kick_controller.set("aim_override",_camera_aim_direction())
			_sync_pass_teammates()
		_update_camera(delta)
	for index in dust.size():
		dust[index].emitting = not paused and characters[index].get("animation")==1
	hud.set("character_name",characters[selected].get("look").display_name)
	hud.set("animation_name",["IDLE","RUN","JUMP","KICK","CHEER","SWEEP","WALK","CHARGE","DIVE","MOVING KICK","KNOCKDOWN"][characters[selected].get("animation")])
	hud.set("paused",paused and not _capture_mode and not bool(shop.get("is_open")))
	hud.set("energy",_stamina[selected]/MovementTuning.STAMINA_MAX)
	hud.set("aiming",kick_controller.get("aiming"))
	hud.set("charging",kick_controller.get("charging"))
	hud.set("charge",kick_controller.get("charge"))
	hud.set("sweet_lo",kick_controller.get("sweet_lo"))
	hud.set("sweet_hi",kick_controller.get("sweet_hi"))
	hud.set("inventory",items.inventory_for(characters[selected]))
	hud.set("boost_remaining",items.boost_remaining(characters[selected]))
	if not paused:
		var action: int = characters[selected].get("animation")
		_celebration_clock += delta*float(characters[selected].get("animation_speed"))
		if action==4 and _celebration_clock>1.2:
			_burst(characters[selected].position+Vector3.UP*2.4,Color("ffc64c"),12)
			_celebration_clock = 0.0


func _controls(delta: float) -> void:
	if paused:
		return
	for index in _action_timers.size():
		var actor := characters[index]
		if actor.ragdoll_active:
			actor.global_position=actor.ragdoll.follow_position()
			continue
		if _knockback_velocity[index].length_squared()>0.001:
			actor.position+=_knockback_velocity[index]*delta
			actor.position.x=clampf(actor.position.x,-Field.HALF_WIDTH+0.8,Field.HALF_WIDTH-0.8)
			actor.position.z=clampf(actor.position.z,-Field.HALF_LENGTH+0.8,Field.HALF_LENGTH-0.8)
			_knockback_velocity[index]=_knockback_velocity[index].move_toward(Vector3.ZERO,6.0*delta)
		_sweep_cooldowns[index] = maxf(0.0,_sweep_cooldowns[index]-delta)
		if _vertical_velocity[index] != 0.0 or actor.position.y > 0.0:
			_vertical_velocity[index] -= MovementTuning.GRAVITY*delta
			actor.position.y = maxf(0.0,actor.position.y+_vertical_velocity[index]*delta)
			if is_zero_approx(actor.position.y):
				_vertical_velocity[index] = 0.0
				_burst(actor.position+Vector3.UP*0.03,Color("d5eeb4"),6)
		if actor.get("animation") == 8 and _action_timers[index] > 0.0:
			var elapsed := MovementTuning.KEEPER_DIVE_DURATION-_action_timers[index]
			var speed := MovementTuning.KEEPER_DIVE_SPEED*(1.0-smoothstep(0.35,MovementTuning.KEEPER_DIVE_DURATION,elapsed))
			actor.position += _dive_directions[index]*speed*delta
			actor.position.x = clampf(actor.position.x,-Field.HALF_WIDTH+0.8,Field.HALF_WIDTH-0.8)
			actor.position.z = clampf(actor.position.z,-Field.HALF_LENGTH+0.8,Field.HALF_LENGTH-0.8)
		if actor.get("animation") == 5 and _action_timers[index] > 0.0:
			var elapsed := SweepMotion.TOTAL_TIME-_action_timers[index]
			var travel := SweepMotion.distance_at(elapsed+delta,sprint_speed)-SweepMotion.distance_at(elapsed,sprint_speed)
			actor.position += _sweep_directions[index]*travel
			actor.position.x = clampf(actor.position.x,-Field.HALF_WIDTH+0.8,Field.HALF_WIDTH-0.8)
			actor.position.z = clampf(actor.position.z,-Field.HALF_LENGTH+0.8,Field.HALF_LENGTH-0.8)
		if _action_timers[index] > 0.0:
			_action_timers[index] = maxf(0.0,_action_timers[index]-delta)
			if is_zero_approx(_action_timers[index]):
				characters[index].call("play",0)
				_knockback_velocity[index]=Vector3.ZERO
	var motion := _motion_input()
	var character := characters[selected]
	_sprinting = not character.ragdoll_active and motion.length()>0.1 and Input.is_key_pressed(KEY_SHIFT) and _stamina[selected]>0.0 and not _exhausted[selected] and not (character.get("animation") in [5,8,10] and _action_timers[selected]>0.0)
	_update_sandbox_stamina(delta)
	if character.ragdoll_active or (character.get("animation") in [5,8,10] and _action_timers[selected] > 0.0):
		return
	if motion.length()>0.1:
		var direction := _camera_move_direction(motion).normalized()
		character.position += direction*delta*(sprint_speed if _sprinting else walk_speed)*items.speed_multiplier_for(character)
		character.position.x = clampf(character.position.x,-Field.HALF_WIDTH+0.8,Field.HALF_WIDTH-0.8)
		character.position.z = clampf(character.position.z,-Field.HALF_LENGTH+0.8,Field.HALF_LENGTH-0.8)
		character.rotation.y = lerp_angle(character.rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*28))
		if _action_timers[selected] <= 0.0:
			character.call("play",1 if _sprinting else 6)
		_was_moving = true
	elif _was_moving:
		if _action_timers[selected] <= 0.0:
			character.call("play",0)
		_was_moving = false
	if kick_controller != null and (kick_controller.get("charging") or kick_controller.get("aiming")) and _carrier_index == selected:
		var aim := _camera_aim_direction()
		character.rotation.y = lerp_angle(character.rotation.y,atan2(-aim.x,-aim.z),1-exp(-delta*32.0))

	if items.aiming:
		var aim: Vector3=items._aim_direction()
		character.rotation.y=lerp_angle(character.rotation.y,atan2(-aim.x,-aim.z),1-exp(-delta*32.0))


func _start_action(value: int) -> void:
	if paused or characters[selected].ragdoll_active or _action_timers[selected] > 0.0:
		return
	if value == 3 and _carrier_index >= 0 and _carrier_index != selected:
		return
	if _carrier_index == selected and value in [2,5]:
		return
	var motion := _motion_input()
	if value == 5:
		if _sweep_cooldowns[selected]>0.0 or characters[selected].position.y>0.01:
			return
		_sweep_directions[selected] = _camera_move_direction(motion).normalized() if motion.length()>0.1 else -characters[selected].basis.z
		characters[selected].rotation.y = atan2(-_sweep_directions[selected].x,-_sweep_directions[selected].z)
		_sweep_cooldowns[selected] = SweepMotion.COOLDOWN
	if value == 2:
		var in_own_goal_area := Field.in_keeper_area(characters[selected].position,0 if selected<2 else 1)
		if in_own_goal_area and Input.is_key_pressed(KEY_SHIFT):
			value = 8
			var side := signf(motion.x) if absf(motion.x)>0.1 else signf(ball.position.x-characters[selected].position.x)
			if is_zero_approx(side):
				side = 1.0
			_dive_directions[selected] = Vector3(side,0.0,0.0)
			characters[selected].rotation.y = atan2(-_dive_directions[selected].x,-_dive_directions[selected].z)
			_vertical_velocity[selected] = MovementTuning.DIVE_JUMP_SPEED
		else:
			_vertical_velocity[selected] = normal_jump_speed
	elif value == 3 and motion.length()>0.1:
		value = 9
	characters[selected].call("play",value)
	_action_timers[selected] = characters[selected].call("animation_duration",value)
	if value == 8:
		_action_timers[selected] = minf(_action_timers[selected],MovementTuning.KEEPER_DIVE_DURATION)


func _motion_input() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))


func _sync_pass_teammates() -> void:
	var first := 0 if selected < 2 else 2
	kick_controller.set("teammates",[characters[first],characters[first+1]])


func _update_sandbox_stamina(delta: float) -> void:
	for index in characters.size():
		if _exhausted[index]:
			_exhaust_timers[index] = maxf(0.0,_exhaust_timers[index]-delta)
			if _exhaust_timers[index]<=0.0 and _stamina[index]>=MovementTuning.STAMINA_RESTART:
				_exhausted[index] = false
		if index==selected and _sprinting:
			_stamina[index] = maxf(0.0,_stamina[index]-MovementTuning.STAMINA_DRAIN*delta)
			_regen_timers[index] = MovementTuning.STAMINA_DELAY
			if _stamina[index]<=0.01:
				_exhausted[index] = true
				_exhaust_timers[index] = MovementTuning.EXHAUSTION_TIME
		elif _regen_timers[index]>0.0:
			_regen_timers[index] = maxf(0.0,_regen_timers[index]-delta)
		else:
			_stamina[index] = minf(MovementTuning.STAMINA_MAX,_stamina[index]+MovementTuning.STAMINA_REGEN*delta)


func _update_sandbox_ball(delta: float = 1.0/60.0) -> void:
	if _carrier_index >= 0:
		var carrier_actor := characters[_carrier_index]
		var carrier_velocity := (carrier_actor.global_position-_carrier_last_position)/maxf(delta,0.001)
		_carrier_last_position = carrier_actor.global_position
		var phase: float = carrier_actor.call("dribble_cycle")
		ball.drive_controlled(-carrier_actor.global_basis.z,carrier_actor.global_basis.x,carrier_velocity,phase,delta)
		return
	if _ball_pickup_lock > 0.0:
		return
	var closest_index := -1
	var closest_distance := 1.45
	for index in characters.size():
		if _item_actor_disabled(characters[index]):
			continue
		# A fast shot must not be magnetically picked up just by passing nearby.
		if ball.position.y>1.0 or ball.linear_velocity.length()>14.0:
			continue
		var distance := Vector2(characters[index].position.x-ball.position.x,characters[index].position.z-ball.position.z).length()
		if distance <= closest_distance:
			closest_index = index
			closest_distance = distance
	_carrier_index = closest_index
	if _carrier_index >= 0:
		ball.claim_by(characters[_carrier_index])
		_carrier_last_position = characters[_carrier_index].global_position
		_update_sandbox_ball(delta)


func _on_sandbox_kicked(_power: float, sweet: bool) -> void:
	if _carrier_index != selected:
		return
	_carrier_index = -1
	_ball_pickup_lock = 0.3
	var character := characters[selected]
	var moving := _motion_input().length() > 0.1
	var kick_animation := 9 if moving else 3
	character.call("play",kick_animation)
	_action_timers[selected] = character.call("animation_duration",kick_animation)
	_burst(ball.global_position,Color("ffc96f") if sweet else Color("ffdf8c"),10)


func _camera_move_direction(motion: Vector2) -> Vector3:
	# W is -Y in this prototype; map it to camera-forward (-Z), then orbit it.
	return Basis(Vector3.UP,_camera_yaw)*Vector3(motion.x,0.0,motion.y)


func _camera_aim_direction() -> Vector3:
	return Vector3(-sin(_camera_yaw),0.0,-cos(_camera_yaw)).normalized()


func _update_camera(delta: float) -> void:
	var character := characters[selected]
	var pivot := character.position+Vector3(0,1.2,0)
	_weapon_shoulder=lerpf(_weapon_shoulder,0.85 if items!=null and items.aiming else 0.0,1-exp(-delta*12.0))
	var target := pivot+Basis(Vector3.UP,_camera_yaw)*Vector3.RIGHT*_weapon_shoulder
	var orbit := Basis(Vector3.UP,_camera_yaw)*Basis(Vector3.RIGHT,deg_to_rad(-_camera_pitch))
	var desired := target+orbit*Vector3(0,0,_camera_distance)
	var safe_position := _camera_position_before_wall(pivot,desired)
	camera.position = safe_position
	camera.look_at(target)


func _camera_position_before_wall(origin: Vector3,desired: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(origin,desired,1<<4)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var ray := desired-origin
	var safe_length := maxf(origin.distance_to(hit.position)-0.35,0.55)
	return origin+ray.normalized()*safe_length


func _add_camera_blockers() -> void:
	# Invisible camera-only shell surfaces stop the orbit before the visible arena walls.
	for side in [-1.0,1.0]:
		_add_camera_blocker(Vector3(0.2,7.5,Field.LENGTH),Vector3(side*(Field.HALF_WIDTH-0.3),4.2,0))
	for end in [-1.0,1.0]:
		_add_camera_blocker(Vector3(Field.WIDTH+1.0,7.5,0.2),Vector3(0,4.2,end*(Field.HALF_LENGTH-0.3)))


func _add_camera_blocker(size: Vector3,at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CameraWallBlocker"
	body.collision_layer = 1<<4
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	if shop != null and shop.get("is_open"):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw = wrapf(_camera_yaw-event.relative.x*_camera_sensitivity,-PI,PI)
		_camera_pitch = clampf(_camera_pitch+event.relative.y*0.10,7.0,48.0)
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_PAGEUP:
				_camera_distance=maxf(_camera_min_distance,_camera_distance-0.6)
			KEY_PAGEDOWN:
				_camera_distance=minf(_camera_max_distance,_camera_distance+0.6)
			KEY_4,KEY_5:
				var action: int = event.keycode-KEY_1
				if action in [2,3]:
					_start_action(action)
				elif _action_timers[selected] <= 0.0:
					characters[selected].call("play",action)
			KEY_SPACE:
				_start_action(2)
			KEY_CTRL:
				_start_action(5)
			KEY_TAB:
				kick_controller.call("cancel_charge")
				selected = (selected+1)%characters.size()
				items.local_actor=characters[selected]
				kick_controller.inventory=items.inventory_for(characters[selected])
			KEY_P:
				_set_paused(not paused)
			KEY_G:
				characters[selected].call("apply_expression",(characters[selected].get("expression")+1)%5)
			KEY_F2:
				get_tree().reload_current_scene()
			KEY_F8:
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			KEY_F12:
				capture("res://docs/visual_preview.png")
func _set_paused(value: bool) -> void:
	paused = value
	if items!=null:
		items.set_active(not value)
	for character in characters:
		character.set("frozen",value)
	ball.freeze = value
	if kick_controller != null:
		if value:
			kick_controller.call("cancel_charge")
		kick_controller.set_physics_process(not value)


func open_shop() -> void:
	if shop.get("is_open"):
		return
	_shop_was_paused = paused
	_shop_mouse_mode = Input.mouse_mode
	shop.call("open_for",characters[selected].get("look"))


func _build_items() -> void:
	items=ItemSystem.new()
	items.ball=ball
	items.local_actor=characters[selected]
	items.view_camera=camera
	hud.weapon_system=items
	items.input_source=kick_controller.input
	items.aim_provider=_camera_aim_direction
	items.stamina_receiver=_item_restore_stamina
	items.disabled_checker=_item_actor_disabled
	items.ragdoll_receiver=_item_ragdoll
	items.ball_release_receiver=_item_release_ball
	add_child(items)
	for index in characters.size():
		items.register_actor(characters[index],0 if index<2 else 1)
	hud.set("inventory",items.inventory_for(characters[selected]))
	kick_controller.inventory=items.inventory_for(characters[selected])


func _item_restore_stamina(actor: Node3D,amount: float) -> void:
	var index := characters.find(actor)
	if index>=0:
		_stamina[index]=minf(MovementTuning.STAMINA_MAX,_stamina[index]+amount)


func _item_actor_disabled(actor: Node3D) -> bool:
	var index := characters.find(actor)
	return index<0 or actor.ragdoll_active or (actor.get("animation") in [5,8,10] and _action_timers[index]>0.0)


func _item_ragdoll(actor: Node3D,launch: Vector3) -> bool:
	var index := characters.find(actor)
	if index<0 or (_action_timers[index]>0.0 and actor.animation==10 and not actor.ragdoll_active):
		return false
	_action_timers[index]=0.0
	_vertical_velocity[index]=0.0
	_knockback_velocity[index]=Vector3.ZERO
	if index==selected:
		kick_controller.cancel_charge()
	actor.start_ragdoll(launch)
	return true


func _on_sandbox_ragdoll_finished(at: Vector3,index: int) -> void:
	characters[index].global_position=at
	_vertical_velocity[index]=0.0
	_knockback_velocity[index]=Vector3.ZERO
	_action_timers[index]=0.45
	characters[index].animation=10
	characters[index].restore_after_ragdoll()


func _item_release_ball() -> void:
	_carrier_index= -1
	_ball_pickup_lock=0.4


func _on_shop_opened() -> void:
	_set_paused(true)


func _on_shop_closed() -> void:
	kick_controller.call("cancel_charge")
	_set_paused(_shop_was_paused)
	Input.mouse_mode = _shop_mouse_mode


func _make_dust(character: Node3D) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 7
	particles.lifetime = 0.4
	particles.local_coords = false
	particles.position = Vector3(0,0.06,0.1)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.16
	particles.direction = Vector3.UP
	particles.spread = 45
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	particles.gravity = Vector3(0,0.3,0)
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.075
	var curve := Curve.new()
	curve.add_point(Vector2(0,0.8))
	curve.add_point(Vector2(0.3,1))
	curve.add_point(Vector2(1,0))
	particles.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = Shapes.material(Color("a6dca0"))
	particles.mesh = mesh
	character.add_child(particles)
	return particles


func _burst(at: Vector3,color: Color,count: int) -> void:
	for index in count:
		var node := Shapes.ellipsoid(self,at,Vector3.ONE*0.055,Shapes.material(color))
		var angle := TAU*index/count
		var tween := create_tween().set_parallel(true)
		tween.tween_property(node,"position",at+Vector3(cos(angle)*0.6,randf_range(0.2,0.6),sin(angle)*0.6),0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node,"scale",Vector3.ZERO,0.5)
		tween.chain().tween_callback(node.queue_free)


func stage_snapshot() -> void:
	_capture_mode = true
	_set_paused(true)
	characters[0].set("time",0.23)
	characters[1].set("time",0.23)
	characters[2].set("action_time",0.57)
	characters[3].set("time",0.2)
	for character in characters:
		character.call("_pose",0.0)
	hud.set("paused",false)
	ball.rotation = Vector3(0.35,0.22,-0.1)


func stage_portrait(index: int = 2) -> void:
	stage_snapshot()
	selected = index
	var actor := characters[index]
	actor.call("play",0)
	actor.call("apply_expression",2)
	actor.call("_pose",0.0)
	camera.position = actor.position-actor.basis.z*3.45+Vector3(0,1.55,0)
	camera.look_at(actor.position+Vector3(0,1.2,0))


func stage_lineup() -> void:
	stage_snapshot()
	for index in characters.size():
		var actor := characters[index]
		actor.position = Vector3(-2.7+index*1.8,0,-10)
		actor.rotation.y = PI
		actor.call("play",0)
		actor.call("apply_expression",[1,0,2,3][index])
		actor.call("_pose",0.0)
	camera.fov = 52
	camera.position = Vector3(0,2.0,-2.1)
	camera.look_at(Vector3(0,1.15,-10))
	ball.position = Vector3(-3.55,float(ball.get("radius")),-9)


func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("Visual capture: "+path)
