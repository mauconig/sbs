extends Node3D
## Shared pickups, football + two item slots, lock-on bazookas and physical blasts.

const Inventory := preload("res://scripts/items/item_inventory.gd")
const Pad := preload("res://scripts/items/pickup_pad.gd")
const Rocket := preload("res://scripts/items/item_projectile.gd")
const Field := preload("res://scripts/field_config.gd")
const Shapes := preload("res://scripts/visuals/shape_library.gd")
const ITEM_POSITIONS := [Vector3(-20,0,-24),Vector3(20,0,-24),Vector3(-20,0,24),Vector3(20,0,24)]
const BOOST_POSITIONS := [Vector3(-24,0,-6),Vector3(24,0,-6),Vector3(-24,0,6),Vector3(24,0,6)]
const BOOST_STAMINA := 25.0
const BOOST_DURATION := 2.5
const BOOST_MULTIPLIER := 1.2

var actors: Array[Node3D]=[]
var local_actor: Node3D
var ball: RigidBody3D
var aim_provider: Callable
var view_camera: Camera3D
var input_source: RefCounted
var ragdoll_receiver: Callable
var aiming := false
var locked_target: Node3D
var candidate: Node3D
var lock_progress := 0.0
const LOCK_TIME := 0.4
const LOCK_RANGE := 48.0
const LOCK_CONE := 16.0
var _was_fire_held := false
var _last_actor: Node3D
var _last_slot := -1
var _target_ring: MeshInstance3D
var _target_label: Label3D
var stamina_receiver: Callable
var disabled_checker: Callable
var ball_release_receiver: Callable
var spawners: Array[Node3D]=[]
var boost_pads: Array[Node3D]=[]
var dropped_items: Array[Node3D]=[]
var _inventories: Dictionary={}
var _boosts: Dictionary={}
var _teams: Dictionary={}
var _ai_targets: Dictionary={}
var _ai_timer := 0.7
var _enabled := true


func _ready() -> void:
	name="Items"
	var ring := TorusMesh.new()
	ring.inner_radius=0.68
	ring.outer_radius=0.78
	ring.rings=32
	ring.ring_segments=6
	_target_ring=Shapes.instance(self,ring,Shapes.material(Color("ffbf38"),0.5,true))
	_target_ring.top_level=true
	_target_ring.hide()
	_target_label=Label3D.new()
	_target_label.font=preload("res://assets/fonts/BarlowCondensed-Black.ttf")
	_target_label.font_size=36
	_target_label.pixel_size=0.006
	_target_label.outline_size=8
	_target_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_target_label.no_depth_test=false
	add_child(_target_label)
	_target_label.top_level=true
	_target_label.hide()
	for at in ITEM_POSITIONS:
		var pad := Pad.new()
		pad.name="ItemSpawner"
		pad.position=at
		pad.kind=Pad.Kind.ITEM
		pad.respawn_time=12.0
		add_child(pad)
		spawners.append(pad)
	for at in BOOST_POSITIONS:
		var pad := Pad.new()
		pad.name="SmallBoost"
		pad.position=at
		pad.rotation.y=PI if at.z>0 else 0.0
		pad.kind=Pad.Kind.BOOST
		pad.respawn_time=4.0
		add_child(pad)
		boost_pads.append(pad)


func register_actor(actor: Node3D, team: int) -> void:
	if actor in actors:
		return
	actors.append(actor)
	_inventories[actor.get_instance_id()]=Inventory.new()
	_boosts[actor.get_instance_id()]=0.0
	_teams[actor.get_instance_id()]=team


func inventory_for(actor: Node3D) -> RefCounted:
	return _inventories.get(actor.get_instance_id()) if actor!=null else null


func boost_remaining(actor: Node3D) -> float:
	return float(_boosts.get(actor.get_instance_id(),0.0)) if actor!=null else 0.0


func speed_multiplier_for(actor: Node3D) -> float:
	return BOOST_MULTIPLIER if boost_remaining(actor)>0.0 else 1.0


func set_active(active: bool) -> void:
	if not active:
		_clear_lock()
	for actor in actors:
		var visual := _visual(actor)
		if visual!=null and visual.ragdoll!=null:
			visual.ragdoll.set_suspended(not active)
	_enabled=active
	process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _input(event: InputEvent) -> void:
	if not _enabled or local_actor==null or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			inventory_for(local_actor).cycle(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := -1
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			slot=event.keycode-KEY_1
		elif event.keycode in [KEY_KP_1,KEY_KP_2,KEY_KP_3]:
			slot=event.keycode-KEY_KP_1
		if slot>=0:
			inventory_for(local_actor).select_slot(slot)
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_F:
			drop_selected(local_actor)
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_local_weapon(delta)
	_update_held_weapons()
	for actor in actors:
		var key := actor.get_instance_id()
		_boosts[key]=maxf(0.0,float(_boosts[key])-delta)
		if actor is CharacterBody3D:
			actor.set("pickup_speed_multiplier",speed_multiplier_for(actor))
	var all_pads: Array=spawners+boost_pads+dropped_items
	for pad in all_pads:
		if not is_instance_valid(pad) or pad.is_queued_for_deletion():
			continue
		pad.advance(delta)
		for actor in actors:
			if _disabled(actor) or actor.global_position.y>0.9 or not pad.available_for(actor):
				continue
			var flat := Vector2(actor.global_position.x-pad.global_position.x,actor.global_position.z-pad.global_position.z)
			if flat.length()> (1.05 if pad.kind==Pad.Kind.BOOST else 1.25):
				continue
			if try_collect(pad,actor):
				break
	for index in range(dropped_items.size()-1,-1,-1):
		if not is_instance_valid(dropped_items[index]):
			dropped_items.remove_at(index)
	_ai_timer-=delta
	if _ai_timer<=0.0:
		_ai_timer=0.7
		_update_ai_items()


func try_collect(pad: Node3D,actor: Node3D) -> bool:
	if not _enabled or not pad.available_for(actor) or _disabled(actor):
		return false
	if pad.kind==Pad.Kind.BOOST:
		if stamina_receiver.is_valid():
			stamina_receiver.call(actor,BOOST_STAMINA)
		else:
			actor.set("stamina",minf(float(actor.get("stamina_max")),float(actor.get("stamina"))+BOOST_STAMINA))
		_boosts[actor.get_instance_id()]=BOOST_DURATION
		_spark(actor.global_position+Vector3.UP*0.1,Color("22d0e6"),0.8)
	else:
		if not inventory_for(actor).add(pad.item_id):
			return false
		_spark(pad.global_position+Vector3.UP*0.2,Color("ffbf38"),0.8)
	pad.collect()
	return true


func _source() -> RefCounted:
	return local_actor.get("input") if local_actor is CharacterBody3D else input_source


func _visual(actor: Node3D) -> Node3D:
	return actor.get("_visual") if actor is CharacterBody3D else actor


func _update_local_weapon(delta: float) -> void:
	if local_actor==null:
		return
	var source := _source()
	var held: bool=source!=null and source.kick_held()
	var inventory=inventory_for(local_actor)
	if _last_actor!=local_actor or _last_slot!=inventory.selected:
		_clear_lock()
		_was_fire_held=held
		_last_actor=local_actor
		_last_slot=inventory.selected
	var input_allowed: bool=source!=null and (source.get("device")!= -1 or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	aiming=input_allowed and inventory.selected_item()==&"bazooka" and not _disabled(local_actor) and source.pass_aim_held()
	if not aiming:
		_clear_lock()
	else:
		var target := _find_target(local_actor)
		if target!=candidate:
			candidate=target
			lock_progress=0.0
			locked_target=null
		if candidate!=null:
			lock_progress=minf(1.0,lock_progress+delta/LOCK_TIME)
			if lock_progress>=1.0:
				locked_target=candidate
		if held and not _was_fire_held:
			use_selected(local_actor)
	_was_fire_held=held
	_target_ring.visible=aiming and is_instance_valid(candidate)
	_target_label.visible=_target_ring.visible
	if _target_ring.visible:
		var color := Color("22e6ce") if locked_target!=null else Color("ffbf38")
		_target_ring.global_position=candidate.global_position+Vector3.UP*0.04
		_target_ring.material_override.albedo_color=color
		_target_label.global_position=candidate.global_position+Vector3.UP*1.9
		_target_label.modulate=color
		_target_label.text="LOCKED" if locked_target!=null else "LOCKING %d%%" % int(lock_progress*100)


func _clear_lock() -> void:
	aiming=false
	candidate=null
	locked_target=null
	lock_progress=0.0
	if _target_ring!=null:
		_target_ring.hide()
		_target_label.hide()


func _aim_direction() -> Vector3:
	if view_camera!=null:
		return -view_camera.global_basis.z.normalized()
	return aim_provider.call() if aim_provider.is_valid() else -local_actor.global_basis.z


func _target_center(actor: Node3D) -> Vector3:
	return actor.global_position+Vector3.UP*0.7


func _valid_target(actor: Node3D,target: Node3D) -> bool:
	if not is_instance_valid(target) or target==actor or not target in actors or _disabled(target):
		return false
	if _teams[actor.get_instance_id()]==_teams[target.get_instance_id()]:
		return false
	var origin := _target_center(actor)
	var end := _target_center(target)
	if origin.distance_to(end)>LOCK_RANGE:
		return false
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1)).is_empty()


func _find_target(actor: Node3D) -> Node3D:
	var best: Node3D
	var best_dot := cos(deg_to_rad(LOCK_CONE))
	var origin := view_camera.global_position if view_camera!=null else _target_center(actor)
	var direction := _aim_direction()
	for target in actors:
		if not _valid_target(actor,target):
			continue
		var alignment := direction.dot((_target_center(target)-origin).normalized())
		if alignment>best_dot:
			best_dot=alignment
			best=target
	return best


func _update_held_weapons() -> void:
	for actor in actors:
		var visual := _visual(actor)
		if visual==null or visual.get("bazooka")==null:
			continue
		var equipped: bool=inventory_for(actor).selected_item()==&"bazooka" and not _disabled(actor)
		visual.bazooka.equipped=equipped
		var target: Node3D=locked_target if actor==local_actor else _ai_targets.get(actor.get_instance_id())
		visual.bazooka.aiming=equipped and (aiming if actor==local_actor else is_instance_valid(target))
		visual.bazooka.aim_direction=(_target_center(target)-_target_center(actor)).normalized() if is_instance_valid(target) else _aim_direction() if actor==local_actor else -actor.global_basis.z
		if actor is CharacterBody3D:
			actor.item_aiming=visual.bazooka.aiming
			actor.item_aim_direction=visual.bazooka.aim_direction


func use_selected(actor: Node3D, target: Node3D=null) -> bool:
	# No free fire: local mouse/controller input needs a completed live lock.
	if not _enabled or actor==null or _disabled(actor):
		return false
	if actor==local_actor:
		if not aiming or locked_target==null or (target!=null and target!=locked_target):
			return false
		target=locked_target
	if not _valid_target(actor,target):
		return false
	var inventory=inventory_for(actor)
	if inventory==null or inventory.selected_item()!=&"bazooka":
		return false
	var visual := _visual(actor)
	var origin := _target_center(actor)
	var launch: Vector3=visual.bazooka.muzzle_position() if visual!=null and visual.bazooka!=null else origin-actor.global_basis.z
	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,launch,1))
	if not wall.is_empty():
		return false
	var rocket := Rocket.new()
	rocket.system=self
	rocket.shooter=actor
	rocket.target=target
	rocket.direction=(_target_center(target)-launch).normalized()
	rocket.position=to_local(launch)
	add_child(rocket)
	if visual!=null:
		visual.bazooka.fire()
	inventory.take_selected()
	if actor==local_actor:
		_clear_lock()
	return true


func drop_selected(actor: Node3D) -> bool:
	if not _enabled or actor==null or _disabled(actor):
		return false
	var inventory=inventory_for(actor)
	if inventory==null or inventory.selected==0 or inventory.selected_item().is_empty():
		return false
	var drop := Pad.new()
	drop.name="DroppedItem"
	drop.kind=Pad.Kind.DROPPED
	drop.item_id=inventory.take_selected()
	drop.ignored_actor_id=actor.get_instance_id()
	drop.owner_lock=1.0
	drop.pickup_lock=0.25
	var at := actor.global_position
	for direction in [actor.global_basis.z,actor.global_basis.x,-actor.global_basis.x,-actor.global_basis.z]:
		at=actor.global_position+direction*1.8
		at.x=clampf(at.x,-Field.HALF_WIDTH+1.0,Field.HALF_WIDTH-1.0)
		at.z=clampf(at.z,-Field.HALF_LENGTH+1.0,Field.HALF_LENGTH-1.0)
		if Vector2(at.x-actor.global_position.x,at.z-actor.global_position.z).length()>1.4:
			break
	at.y=0.0
	drop.position=to_local(at)
	add_child(drop)
	dropped_items.append(drop)
	return true


func _disabled(actor: Node3D) -> bool:
	if disabled_checker.is_valid():
		return bool(disabled_checker.call(actor))
	if actor is CharacterBody3D:
		return float(actor.get("_keeper_recovery_timer"))>0.0 or float(actor.get("knocked_out"))>0.0 or float(actor.get("tackle_timer"))>0.0 or float(actor.get("tackle_recovery_timer"))>0.0 or float(actor.get("_dive_timer"))>0.0
	return false


func _update_ai_items() -> void:
	for actor in actors:
		if actor==local_actor or _disabled(actor) or not actor is CharacterBody3D:
			continue
		var inventory=inventory_for(actor)
		var key := actor.get_instance_id()
		if ball!=null and ball.carrier==actor:
			_ai_targets.erase(key)
			if inventory.selected!=0:
				inventory.selected=0
				inventory.changed.emit()
			continue
		if inventory.selected_item()==&"bazooka":
			var target: Node3D=_ai_targets.get(key)
			if _valid_target(actor,target):
				use_selected(actor,target)
			_ai_targets.erase(key)
			inventory.selected=0
			inventory.changed.emit()
		else:
			var index: int=inventory.slots.find(&"bazooka",1)
			if index<1:
				continue
			var best: Node3D
			var distance := 24.0
			for target in actors:
				var gap := actor.global_position.distance_to(target.global_position)
				if gap<distance and _valid_target(actor,target):
					best=target
					distance=gap
			if best!=null:
				_ai_targets[key]=best
				inventory.selected=index
				inventory.changed.emit()


func explode_at(at: Vector3,shooter: Node3D) -> void:
	_spark(at,Color("ffb923"),3.0)
	var carrier_hit := false
	for actor in actors:
		var offset: Vector3=actor.global_position+Vector3.UP*0.55-at
		if offset.length()>3.0:
			continue
		# Preserve the vertical component: a blast below an airborne target lifts it.
		var outward := offset.normalized() if offset.length()>0.1 else Vector3.UP
		var launch := (outward*15.0+Vector3.UP*7.0).limit_length(28.0)
		if actor is CharacterBody3D:
			launch=(launch+actor.velocity*0.25).limit_length(28.0)
		var accepted := false
		if ragdoll_receiver.is_valid():
			accepted=bool(ragdoll_receiver.call(actor,launch))
		elif actor.has_method("launch_ragdoll"):
			accepted=actor.launch_ragdoll(launch)
		if accepted and ball!=null and ball.carrier==actor:
			carrier_hit=true
	if ball!=null and (carrier_hit or ball.global_position.distance_to(at)<=3.0):
		var previous_owner: Node3D=ball.carrier
		ball.release_from(previous_owner)
		if previous_owner is CharacterBody3D:
			previous_owner.set("dribble_lock",0.4)
		if ball_release_receiver.is_valid():
			ball_release_receiver.call()
		var push := ball.global_position-at
		push.y=0.0
		if push.length_squared()<0.01:
			push= -shooter.global_basis.z if is_instance_valid(shooter) else Vector3.FORWARD
		ball.linear_velocity=push.normalized()*16.0+Vector3.UP*5.5
		ball.curve_strength=0.0
		ball.sleeping=false
	Juice.add_shake(0.35)


func _spark(at: Vector3,color: Color,radius: float) -> void:
	var effect := Node3D.new()
	effect.name="PickupEffect"
	effect.position=to_local(at)
	add_child(effect)
	var ring := TorusMesh.new()
	ring.inner_radius=0.8
	ring.outer_radius=1.0
	ring.rings=24
	ring.ring_segments=5
	if radius>=3.0:
		for index in 10:
			var direction := Vector3(cos(index*2.4),sin(index*1.7)*0.8+0.3,sin(index*2.4)).normalized()
			var spark := Shapes.ellipsoid(effect,Vector3.ZERO,Vector3.ONE*0.13,Shapes.material(color if index%2 else Color("fff3dc"),0.5,true))
			var burst := effect.create_tween().set_parallel(true)
			burst.tween_property(spark,"position",direction*1.6,0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			burst.tween_property(spark,"scale",Vector3.ZERO,0.3)
	var visual := Shapes.instance(effect,ring,Shapes.material(color,0.5,true))
	visual.scale=Vector3.ONE*0.12
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(visual,"scale",Vector3(radius,0.1,radius),0.3)
	tween.tween_property(visual,"position:y",0.3,0.3)
	tween.chain().tween_callback(effect.queue_free)


func reset_round() -> void:
	_ai_targets.clear()
	_clear_lock()
	for actor in actors:
		inventory_for(actor).clear()
		_boosts[actor.get_instance_id()]=0.0
		if actor is CharacterBody3D:
			actor.set("pickup_speed_multiplier",1.0)
	for pad in spawners+boost_pads:
		pad.reset_pad()
	for drop in dropped_items:
		if is_instance_valid(drop):
			drop.queue_free()
	dropped_items.clear()
	for child in get_children():
		if child.is_in_group("item_projectiles") or child.name.begins_with("PickupEffect"):
			child.queue_free()
