extends Camera3D
## Third-person chase camera. Mouse or right stick orbits, the camera
## springs after the player and leads slightly into their velocity.

@export var distance := 8.2
@export var follow_lag := 0.12
@export var mouse_sensitivity := 0.0028
@export var stick_yaw_speed := 2.8
@export var stick_pitch_speed := 1.8
@export var min_pitch := 6.0
@export var max_pitch := 44.0
@export var min_distance := 6.0
@export var max_distance := 16.0
@export var shoulder_offset := 0.9
@export_flags_3d_physics var collision_mask := 1 | (1 << 4)
@export var collision_margin := 0.35

var yaw := 0.0
@export var pitch := 20.0
var target: Node3D
var input: RefCounted

var _pivot := Vector3.ZERO


func _ready() -> void:
	fov = 68.0
	near = 0.08
	far = 220.0
	if target:
		_pivot = target.global_position + Vector3(0.0, 1.5, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		pitch = clampf(pitch + event.relative.y * 0.10, min_pitch, max_pitch)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.6, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.6, min_distance, max_distance)


func _physics_process(delta: float) -> void:
	if input:
		var stick: Vector2 = input.look_vector()
		if stick != Vector2.ZERO:
			yaw = wrapf(yaw - stick.x * stick_yaw_speed * delta, -PI, PI)
			pitch = clampf(pitch + stick.y * stick_pitch_speed * delta, min_pitch, max_pitch)

	if target:
		var lead := Vector3.ZERO
		if target is CharacterBody3D:
			lead = target.velocity * 0.12
		var desired := target.global_position + Vector3(0.0, 1.5, 0.0) + lead
		_pivot = _pivot.lerp(desired, 1.0 - exp(-delta / maxf(follow_lag, 0.001)))

	var rotation_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	var shoulder := rotation_basis.x * shoulder_offset
	var desired_position := _pivot + rotation_basis * Vector3(0.0, 0.0, distance) + shoulder
	global_position = _position_before_obstacle(_pivot, desired_position)
	look_at(_pivot + shoulder, Vector3.UP)

	var shake: float = Juice.shake
	h_offset = randf_range(-1.0, 1.0) * shake * 0.35
	v_offset = randf_range(-1.0, 1.0) * shake * 0.35


func _position_before_obstacle(origin: Vector3, desired: Vector3) -> Vector3:
	if not is_inside_tree() or collision_mask == 0:
		return desired
	var query := PhysicsRayQueryParameters3D.create(origin, desired, collision_mask)
	query.collide_with_areas = false
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var ray := desired - origin
	var safe_length := maxf(float(origin.distance_to(hit.position)) - collision_margin, 0.12)
	return origin + ray.normalized() * safe_length
