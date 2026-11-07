extends Node3D
## Charge-and-release kicking with a sweet spot, loft, curve and a
## world-space trajectory preview.

signal kicked(power: float, sweet: bool)

@export var charge_time := 0.75
@export var min_speed := 7.0
@export var max_speed := 24.0
@export var sweet_lo := 0.80
@export var sweet_hi := 0.95
@export var kick_range := 2.0
@export var kick_dot := -0.1
@export var loft_deg := 11.0
@export var loft_gain_deg := 4.0
@export var cooldown := 0.25
@export var curve_max := 7.0

var player: CharacterBody3D
var camera: Node3D
var ball: RigidBody3D
var input: RefCounted

var charging := false
var charge := 0.0
var curve := 0.0
var sweet_hit := false
var cooldown_timer := 0.0

var _was_held := false
var _preview: MultiMeshInstance3D
var _beads := MultiMesh.new()
var _landing: MeshInstance3D
var _landing_material: StandardMaterial3D


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


func aim_dir() -> Vector3:
	var yaw: float = camera.yaw if camera else 0.0
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()


func _physics_process(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	if input == null:
		return

	var held: bool = input.kick_held()
	if held and not _was_held and cooldown_timer <= 0.0 and not charging:
		charging = true
		charge = 0.0
		curve = 0.0
		sweet_hit = false

	if held and charging:
		charge = minf(1.0, charge + delta / charge_time)
		var move: Vector2 = input.move_vector()
		curve = clampf(move.x, -1.0, 1.0)

	if not held and _was_held and charging:
		_release()

	_was_held = held

	if charging:
		_preview.visible = true
		_update_preview()
	else:
		_preview.visible = false
		_landing.visible = false


func _release() -> void:
	charging = false
	_preview.visible = false
	if ball == null or player == null:
		return

	var aim := aim_dir()
	var to_ball := ball.global_position - player.global_position
	var flat := Vector3(to_ball.x, 0.0, to_ball.z)
	if flat.length() > kick_range:
		return
	if flat.length() > 0.001 and flat.normalized().dot(aim) < kick_dot:
		return

	cooldown_timer = cooldown
	var t := charge
	var power := lerpf(min_speed, max_speed, pow(t, 0.85))
	sweet_hit = t >= sweet_lo and t <= sweet_hi
	if sweet_hit:
		power *= 1.15

	var loft := deg_to_rad(loft_deg + loft_gain_deg * t)
	var direction := (aim * cos(loft) + Vector3.UP * sin(loft)).normalized()

	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.apply_central_impulse(direction * power * ball.mass)
	ball.curve_strength = curve * curve_max * (0.35 + t)
	ball.angular_velocity = Vector3(curve * 6.0, -curve * 10.0, 0.0)

	player.dribble_lock = 0.3
	kicked.emit(power, sweet_hit)

	if sweet_hit:
		Juice.hitstop(0.06, 0.05)
		Juice.add_shake(0.55)
	elif t > 0.55:
		Juice.add_shake(0.14)

	charge = 0.0
	curve = 0.0


func preview_points() -> Array:
	var start := Vector3.ZERO
	var aim := aim_dir()
	if ball != null:
		start = ball.global_position
	elif player != null:
		start = player.global_position + aim * 0.6 + Vector3.UP * 0.2

	var t := charge
	var power := lerpf(min_speed, max_speed, pow(t, 0.85))
	if t >= sweet_lo and t <= sweet_hi:
		power *= 1.15
	var loft := deg_to_rad(loft_deg + loft_gain_deg * t)
	var direction := (aim * cos(loft) + Vector3.UP * sin(loft)).normalized()

	var points: Array = [start]
	var position := start
	var velocity := direction * power
	var step := 0.045
	var lateral := curve * curve_max * (0.35 + t)
	for i in 30:
		velocity += Vector3.DOWN * 20.0 * step
		var side := Vector3(-velocity.z, 0.0, velocity.x)
		if side.length() > 0.001:
			velocity += side.normalized() * lateral * step
		position += velocity * step
		points.append(position)
		if i > 2 and position.y < 0.08:
			break
	return points


func _update_preview() -> void:
	var points := preview_points()
	if points.size() < 2:
		_landing.visible = false
		return

	var in_sweet := charge >= sweet_lo and charge <= sweet_hi
	var near := Color(1.0, 0.85, 0.25) if in_sweet else Color(0.85, 0.95, 1.0)
	var far := Color(1.0, 0.55, 0.1) if in_sweet else Color(0.25, 0.55, 1.0)

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
	_landing_material.albedo_color = Color(1.0, 0.85, 0.25, 0.85) if in_sweet else Color(0.75, 0.9, 1.0, 0.6)
