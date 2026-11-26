extends Node3D
## Charge-and-release kicking with a sweet spot, loft, curve and a
## world-space trajectory preview.

signal kicked(power: float, sweet: bool)
signal passed(power: float, sweet: bool)

@export var charge_time := 0.75
@export var min_speed := 8.0
@export var max_speed := 40.0
@export var sweet_lo := 0.80
@export var sweet_hi := 0.95
@export var kick_range := 2.0
@export var kick_dot := -0.1
@export var loft_deg := 4.0
@export var loft_gain_deg := 13.0
@export var cooldown := 0.25
@export var curve_max := 7.0
@export var debug := false
@export var pass_aim_angle := 38.0
@export_range(0.0,1.0) var aim_preview_charge := 0.65

var player: Node3D
var camera: Node3D
var ball: RigidBody3D
var input: RefCounted
var inventory: RefCounted
var teammates: Array = []
var team_id := 0

var use_aim_override := false
var aim_override := Vector3.ZERO
var show_preview := true

var charging := false
var charge := 0.0
var curve := 0.0
var sweet_hit := false
var cooldown_timer := 0.0
var pass_aiming := false
var aiming := false
var pass_target: Node3D
var preview_goal := false
var preview_impact := false

var _was_held := false
var _charge_is_pass := false
var _aim_locked := false
var _locked_aim := Vector3.FORWARD
var _last_aim := Vector3.FORWARD
var _locked_pass_target: Node3D
var _preview: MultiMeshInstance3D
var _beads := MultiMesh.new()
var _landing: MeshInstance3D
var _landing_material: StandardMaterial3D
var _pass_target_ring: MeshInstance3D


func _ready() -> void:
	var bead := SphereMesh.new()
	bead.radius = 0.11
	bead.height = 0.22
	bead.radial_segments = 8
	bead.rings = 4

	_beads.transform_format = MultiMesh.TRANSFORM_3D
	_beads.use_colors = true
	_beads.mesh = bead

	_preview = MultiMeshInstance3D.new()
	_preview.multimesh = _beads
	_preview.top_level = true
	_preview.visible = false
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview.material_override = material
	add_child(_preview)

	_landing_material = StandardMaterial3D.new()
	_landing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_landing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_landing_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	_landing = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.30
	ring.outer_radius = 0.40
	_landing.mesh = ring
	_landing.top_level = true
	_landing.visible = false
	_landing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_landing.material_override = _landing_material
	add_child(_landing)
	_pass_target_ring = MeshInstance3D.new()
	var target_ring_mesh := TorusMesh.new()
	target_ring_mesh.inner_radius = 0.62
	target_ring_mesh.outer_radius = 0.76
	target_ring_mesh.ring_segments = 6
	_pass_target_ring.mesh = target_ring_mesh
	_pass_target_ring.top_level = true
	_pass_target_ring.visible = false
	_pass_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var target_material := StandardMaterial3D.new()
	target_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_material.albedo_color = Color(0.35,1.0,0.42)
	target_material.emission_enabled = true
	target_material.emission = Color(0.2,1.0,0.28)
	_pass_target_ring.material_override = target_material
	add_child(_pass_target_ring)


func aim_dir() -> Vector3:
	if _aim_locked:
		return _locked_aim
	return _live_aim_dir()


func _live_aim_dir() -> Vector3:
	if use_aim_override and aim_override.length() > 0.01:
		var flat := Vector3(aim_override.x, 0.0, aim_override.z)
		return flat.normalized()
	var yaw: float = camera.yaw if camera else 0.0
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()


func cancel_charge() -> void:
	charging = false
	charge = 0.0
	curve = 0.0
	pass_aiming = false
	aiming = false
	_charge_is_pass = false
	_aim_locked = false
	_locked_pass_target = null
	pass_target = null
	_was_held = input.kick_held() if input != null else false
	if _preview != null:
		_preview.hide()
	if _landing != null:
		_landing.hide()
	if _pass_target_ring != null:
		_pass_target_ring.hide()


func _physics_process(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	if inventory!=null and inventory.selected!=0:
		cancel_charge()
		return
	if input == null:
		return

	if player != null and (bool(_player_value("ragdoll_active", false)) or float(_player_value("knocked_out", 0.0)) > 0.0 or float(_player_value("tackle_timer", 0.0)) > 0.0):
		cancel_charge()
		return
	var has_ball: bool = ball != null and player != null and ball.carrier == player
	var modifier: bool = input.pass_aim_held() if input.has_method("pass_aim_held") else false
	var loose_in_reach := ball != null and player != null and ball.carrier == null and player.global_position.distance_to(ball.global_position) <= kick_range
	var wants_aim := modifier and (has_ball or loose_in_reach)
	var held: bool = input.kick_held()
	if aiming and not wants_aim:
		# RMB only controls live aim/preview. An existing charge keeps its direction.
		if charging:
			_locked_aim = _last_aim
			_locked_pass_target = pass_target if _charge_is_pass else null
			_aim_locked = true
	if wants_aim:
		_aim_locked = false
		_last_aim = _live_aim_dir()
	aiming = wants_aim
	# Once a shot is charging, moving past a teammate must not turn it into a pass.
	pass_target = _select_pass_target() if aiming and has_ball and (not charging or _charge_is_pass) else null
	if not aiming and charging and _charge_is_pass and is_instance_valid(_locked_pass_target):
		pass_target = _locked_pass_target
	pass_aiming = aiming and pass_target != null
	_pass_target_ring.visible = pass_aiming
	if pass_target != null:
		_pass_target_ring.global_position = pass_target.global_position+Vector3.UP*0.035

	if held and not _was_held and cooldown_timer <= 0.0 and not charging:
		charging = true
		charge = 0.0
		curve = 0.0
		sweet_hit = false
		_charge_is_pass = pass_aiming
		_aim_locked = false
		_locked_pass_target = null

	if held and charging:
		charge = minf(1.0, charge + delta / charge_time)
		if _charge_is_pass:
			curve = 0.0
		elif not _aim_locked:
			var move: Vector2 = input.move_vector()
			curve = clampf(move.x, -1.0, 1.0)

	if not held and _was_held and charging:
		_release()

	_was_held = held

	if aiming and show_preview and not pass_aiming and not (charging and _charge_is_pass) and cooldown_timer<=0.0:
		_preview.visible = true
		_update_preview()
	else:
		_preview.visible = false
		_landing.visible = false


func _release() -> void:
	var aim := aim_dir()
	var released_charge := charge
	var released_curve := curve
	charge = 0.0
	curve = 0.0
	_aim_locked = false
	_locked_pass_target = null
	charging = false
	_preview.visible = false
	if ball == null or player == null:
		return
	if _charge_is_pass:
		if pass_target != null and is_instance_valid(pass_target):
			force_pass(pass_target,released_charge)
		charge = 0.0
		curve = 0.0
		_charge_is_pass = false
		return

	var to_ball := ball.global_position - player.global_position
	var flat := Vector3(to_ball.x, 0.0, to_ball.z)
	if flat.length() > kick_range:
		if debug:
			print("[kick] reject: range=", snappedf(flat.length(), 0.01))
		return
	if ball.carrier != player and flat.length() > 0.001 and flat.normalized().dot(aim) < kick_dot:
		if debug:
			print("[kick] reject: cone dot=", snappedf(flat.normalized().dot(aim), 0.01))
		return

	force_kick(released_charge, aim, released_curve)
	charge = 0.0
	curve = 0.0


func force_kick(power_ratio: float, direction: Vector3, curve_amount: float = 0.0) -> bool:
	## Applies a kick immediately. Used by the AI, which does not charge.
	if ball == null or player == null or (inventory!=null and inventory.selected!=0):
		return false
	if ball.carrier != null and ball.carrier != player:
		return false

	var to_ball := ball.global_position - player.global_position
	var flat := Vector3(to_ball.x, 0.0, to_ball.z)
	if flat.length() > kick_range:
		return false

	var aim := Vector3(direction.x, 0.0, direction.z)
	if aim.length() < 0.001:
		aim = aim_dir()
	aim = aim.normalized()

	var t := clampf(power_ratio, 0.0, 1.0)
	var power := shot_speed(t)
	sweet_hit = t >= sweet_lo and t <= sweet_hi

	ball.release_from(player)
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = shot_velocity(t,aim)
	ball.angular_velocity = Vector3(curve_amount * 6.0, -curve_amount * 10.0, 0.0)
	ball.curve_strength = curve_amount * curve_max * (0.35 + t)

	cooldown_timer = cooldown
	if _has_player_property("dribble_lock"):
		player.set("dribble_lock", 0.3)
	kicked.emit(power, sweet_hit)

	if sweet_hit:
		Juice.hitstop(0.06, 0.05)
		Juice.add_shake(0.55)
	elif t > 0.55:
		Juice.add_shake(0.14)

	if debug:
		print("[kick] t=", snappedf(t, 0.01),
			" power=", snappedf(power, 0.01),
			" aim=", aim.snapped(Vector3(0.01, 0.01, 0.01)),
			" after=", ball.linear_velocity.snapped(Vector3(0.01, 0.01, 0.01)),
			" player=", player.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" ball=", ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)))
	return true


func shot_speed(power_ratio: float) -> float:
	var ratio := clampf(power_ratio,0.0,1.0)
	var speed := lerpf(min_speed,max_speed,pow(ratio,0.85))
	if ratio>=sweet_lo and ratio<=sweet_hi:
		speed = minf(max_speed,speed*1.08)
	return speed


func shot_velocity(power_ratio: float, direction: Vector3) -> Vector3:
	## One launch calculation for gameplay and preview. Harder shots rise higher.
	var ratio := clampf(power_ratio,0.0,1.0)
	var aim := Vector3(direction.x,0.0,direction.z)
	if aim.length_squared()<0.0001:
		aim = aim_dir()
	aim = aim.normalized()
	var loft := deg_to_rad(loft_deg+loft_gain_deg*ratio*ratio)
	return (aim*cos(loft)+Vector3.UP*sin(loft))*shot_speed(ratio)


func force_pass(target: Node3D, power_ratio: float) -> bool:
	if inventory!=null and inventory.selected!=0:
		return false
	if target == null or not is_instance_valid(target) or ball == null or player == null or ball.carrier != player:
		return false
	var ratio := clampf(power_ratio,0.0,1.0)
	var speed := lerpf(9.0,22.0,pow(ratio,0.85))
	var travel_time := clampf(player.global_position.distance_to(target.global_position)/speed,0.15,1.0)
	var target_velocity: Vector3 = target.get("velocity") if target.get("velocity") is Vector3 else Vector3.ZERO
	var predicted := target.global_position+Vector3(target_velocity.x,0.0,target_velocity.z)*travel_time*0.65
	var aim := predicted-ball.global_position
	aim.y = 0.0
	if aim.length() < 0.1:
		return false
	ball.release_from(player)
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = aim.normalized()*speed
	ball.angular_velocity = Vector3.ZERO
	ball.curve_strength = 0.0
	cooldown_timer = cooldown
	if _has_player_property("dribble_lock"):
		player.set("dribble_lock",0.28)
	passed.emit(speed,false)
	return true


func _select_pass_target() -> Node3D:
	if camera == null:
		return null
	var forward := aim_dir()
	var best: Node3D
	var best_angle := deg_to_rad(pass_aim_angle)
	var best_distance := INF
	for mate in teammates:
		if mate == null or not is_instance_valid(mate) or mate == player:
			continue
		var offset: Vector3 = mate.global_position-player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.1 or camera.is_position_behind(mate.global_position):
			continue
		var angle := forward.angle_to(offset.normalized())
		if angle > deg_to_rad(pass_aim_angle):
			continue
		# Aim selects the lane; among nearly aligned receivers, choose the closer one.
		if best != null and (angle > best_angle+deg_to_rad(5.0) or (absf(angle-best_angle)<=deg_to_rad(5.0) and distance>=best_distance)):
			continue
		var query := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.8,mate.global_position+Vector3.UP*0.8,1)
		query.exclude = [ball.get_rid()]
		if player is CollisionObject3D:
			query.exclude.append(player.get_rid())
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != mate:
			continue
		best = mate
		best_distance = distance
		best_angle = angle
	return best


func _has_player_property(property_name: StringName) -> bool:
	if player == null:
		return false
	for property_info: Dictionary in player.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return true
	return false


func _player_value(property_name: StringName, fallback: Variant) -> Variant:
	if _has_player_property(property_name):
		return player.get(property_name)
	return fallback


func preview_points(power_ratio: float = -1.0) -> Array:
	var start := Vector3.ZERO
	var aim := aim_dir()
	if ball != null:
		start = ball.global_position
	elif player != null:
		start = player.global_position + aim * 0.6 + Vector3.UP * 0.2

	var t := charge if power_ratio<0.0 else clampf(power_ratio,0.0,1.0)

	var points: Array = [start]
	preview_goal = false
	preview_impact = false
	var shot_position := start
	var velocity := shot_velocity(t,aim)
	var step := 0.035
	var lateral_force := curve * curve_max * (0.35 + t)
	var curve_decay: float = ball.curve_decay if ball != null else 5.0
	var ball_mass: float = ball.ball_mass if ball != null else 0.44
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var shape := SphereShape3D.new()
	shape.radius = ball.radius if ball != null else 0.22
	for i in 60:
		velocity += Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8)) * step
		var side := Vector3(-velocity.z, 0.0, velocity.x)
		if side.length() > 0.001:
			velocity += side.normalized() * (lateral_force / maxf(ball_mass,0.01)) * step
		lateral_force = move_toward(lateral_force,0.0,curve_decay*step)
		var motion := velocity*step
		var next_position := shot_position+motion
		for goal in get_tree().get_nodes_in_group("preview_goals") if is_inside_tree() else []:
			var crossing: Dictionary = goal.preview_crossing(shot_position,next_position)
			if not crossing.is_empty():
				points.append(crossing.position)
				preview_goal = true
				return points
		if space != null:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY,shot_position)
			query.motion = motion
			query.collision_mask = 1
			query.exclude = [ball.get_rid()] if ball != null else []
			if player is CollisionObject3D:
				query.exclude.append(player.get_rid())
			var cast: PackedFloat32Array = space.cast_motion(query)
			if cast.size()>=2 and cast[0]<0.999:
				shot_position += motion*cast[0]
				points.append(shot_position)
				preview_impact = true
				return points
		shot_position = next_position
		points.append(shot_position)
		if i > 2 and shot_position.y < 0.08:
			break
	return points


func _update_preview() -> void:
	var display_charge := charge if charging else aim_preview_charge
	var points := preview_points(display_charge)
	if points.size() < 2:
		_landing.visible = false
		return

	var in_sweet := display_charge >= sweet_lo and display_charge <= sweet_hi
	var near := Color(0.3,1.0,0.45) if preview_goal else (Color(1.0,0.85,0.25) if in_sweet else Color(0.85,0.95,1.0))
	var far := Color(0.2,0.95,0.35) if preview_goal else (Color(1.0,0.55,0.1) if in_sweet else Color(0.25,0.55,1.0))

	var count := 0
	for i in range(1, points.size(), 2):
		count += 1
	_beads.instance_count = count
	var index := 0
	for i in range(1, points.size(), 2):
		var point: Vector3 = points[i]
		_beads.set_instance_transform(index, Transform3D(Basis(), point))
		var t := float(index) / float(maxi(count - 1, 1))
		_beads.set_instance_color(index, near.lerp(far, t))
		index += 1

	var landing: Vector3 = points[points.size() - 1]
	_landing.global_position = Vector3(landing.x, maxf(landing.y, 0.03), landing.z)
	_landing.visible = true
	_landing_material.albedo_color = Color(0.25,1.0,0.4,0.9) if preview_goal else (Color(1.0,0.85,0.25,0.85) if in_sweet else Color(0.75,0.9,1.0,0.6))
