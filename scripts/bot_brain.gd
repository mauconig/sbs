extends Node
const Field := preload("res://scripts/field_config.gd")
## Compact team AI: one chaser, one support/cover role, tackles, shots and keeper saves.

@export var think_interval := 0.14
@export var think_jitter := 0.05
@export var shoot_range := 18.0
@export var tackle_range := 2.1
@export var tackle_chance := 0.5
@export var aim_error_radians := 0.08
@export var attack_z := Field.HALF_LENGTH
@export var own_z := -Field.HALF_LENGTH

var body: CharacterBody3D
var ball: RigidBody3D
var input: RefCounted
var teammates: Array = []
var opponents: Array = []
var team_id := 1

var _think := 0.0
var _tackle_hold := 0.0
var _aim_offset := 0.0


func reset() -> void:
	_think = 0.0
	_tackle_hold = 0.0
	_aim_offset = 0.0
	if input:
		input.move = Vector2.ZERO
		input.kick = false
		input.tackle = false
		input.jump = false
		input.sprint = false


func _physics_process(delta: float) -> void:
	if body == null or ball == null or input == null:
		return
	if _tackle_hold > 0.0:
		_tackle_hold -= delta
		if _tackle_hold <= 0.0:
			input.tackle = false
	_think -= delta
	if _think <= 0.0:
		_think = think_interval + randf() * think_jitter
		_decide()


func _decide() -> void:
	input.jump = false
	input.kick = false
	if body.knocked_out > 0.0 or body.tackle_timer > 0.0 or body.tackle_recovery_timer > 0.0:
		input.move = Vector2.ZERO
		return
	if _try_keeper_save():
		return
	var carrier: Node3D = ball.carrier
	if carrier == body:
		_attack(ball.global_position)
		return
	if carrier != null and int(carrier.get("team_id")) == team_id:
		_support(carrier.global_position)
		return
	if carrier != null:
		if _is_nearest_teammate(carrier.global_position):
			_defend(carrier)
		else:
			_cover_goal(carrier.global_position)
		return
	if _is_nearest_teammate(ball.global_position):
		_chase(ball.global_position)
	else:
		_support(ball.global_position)


func _try_keeper_save() -> bool:
	if ball.carrier != null or ball.linear_velocity.z * signf(own_z) < 1.5:
		return false
	var own_line := absf(own_z)
	var toward_goal := (ball.global_position.z * signf(own_z)) > own_line - 12.0
	var incoming_x := ball.global_position.x
	if absf(ball.linear_velocity.z) > 0.1:
		incoming_x += ball.linear_velocity.x * clampf((own_z-ball.global_position.z)/ball.linear_velocity.z,0.0,0.8)
	var is_closest_keeper := true
	for mate in teammates:
		if mate == body:
			continue
		if mate.knocked_out > 0.0:
			continue
		if mate.global_position.distance_squared_to(Vector3(incoming_x,0,own_z)) < body.global_position.distance_squared_to(Vector3(incoming_x,0,own_z)):
			is_closest_keeper = false
	if not toward_goal or not is_closest_keeper:
		return false
	var in_keeper_zone := Field.in_keeper_area(body.global_position,team_id)
	if not in_keeper_zone:
		var prepare := Vector3(clampf(incoming_x,-7.0,7.0),0.0,own_z-signf(own_z)*5.0)-body.global_position
		prepare.y = 0.0
		input.move = _to_input(prepare.normalized())
		input.sprint = prepare.length()>1.0
		return true
	var delta_x := incoming_x-body.global_position.x
	input.move = Vector2(signf(delta_x),0.0)
	input.sprint = true
	input.jump = true
	return true


func _is_nearest_teammate(target: Vector3) -> bool:
	var own_distance := body.global_position.distance_squared_to(target)
	for mate in teammates:
		if mate == body or mate == null or mate.knocked_out > 0.0:
			continue
		if mate.global_position.distance_squared_to(target) < own_distance:
			return false
	return true


func _attack(ball_position: Vector3) -> void:
	var goal := Vector3(randf_range(-1.2,1.2),0.0,attack_z)
	_drive_through_ball(ball_position,goal)
	input.sprint = _flat_distance(body.global_position,ball_position) > 2.2
	var distance := _flat_distance(ball_position,goal)
	if distance < shoot_range and body.kick.cooldown_timer <= 0.0:
		_shoot(ball_position,goal,distance)


func _shoot(ball_position: Vector3, goal: Vector3, distance: float) -> void:
	var aim := goal-ball_position
	aim.y = 0.0
	if aim.length() < 0.01:
		return
	_aim_offset = randf_range(-aim_error_radians,aim_error_radians)
	aim = aim.normalized().rotated(Vector3.UP,_aim_offset)
	body.kick.force_kick(clampf(distance/27.0,0.4,0.95),aim,0.0)


func _support(ball_position: Vector3) -> void:
	var attack_sign := -1.0 if team_id == 0 else 1.0
	var lane := -1.0 if body.global_position.x < ball_position.x else 1.0
	var target := Vector3(clampf(ball_position.x+lane*9.0,-Field.HALF_WIDTH+3.0,Field.HALF_WIDTH-3.0),0.0,clampf(ball_position.z+attack_sign*8.0,-Field.HALF_LENGTH+4.0,Field.HALF_LENGTH-4.0))
	var direction := target-body.global_position
	direction.y = 0.0
	input.move = _to_input(direction.normalized()) if direction.length()>0.2 else Vector2.ZERO
	input.sprint = direction.length()>5.0


func _cover_goal(ball_position: Vector3) -> void:
	var goal := Vector3(clampf(ball_position.x*0.35,-7.0,7.0),0.0,own_z-signf(own_z)*6.0)
	var direction := goal-body.global_position
	direction.y = 0.0
	input.move = _to_input(direction.normalized()) if direction.length()>0.25 else Vector2.ZERO
	input.sprint = direction.length()>6.0
	var carrier: Node3D = ball.carrier
	if carrier != null and body.global_position.distance_to(carrier.global_position)<tackle_range and body.tackle_cooldown_timer<=0.0 and randf()<tackle_chance:
		input.tackle = true
		_tackle_hold = 0.12


func _defend(carrier: Node3D) -> void:
	var direction := carrier.global_position-body.global_position
	direction.y = 0.0
	input.move = _to_input(direction.normalized()) if direction.length()>0.01 else Vector2.ZERO
	input.sprint = direction.length()>3.0
	if direction.length()<tackle_range and body.tackle_cooldown_timer<=0.0 and randf()<tackle_chance:
		input.tackle = true
		_tackle_hold = 0.12


func _chase(ball_position: Vector3) -> void:
	var direction := ball_position-body.global_position
	direction.y = 0.0
	input.move = _to_input(direction.normalized()) if direction.length()>0.01 else Vector2.ZERO
	input.sprint = direction.length()>2.5


func _drive_through_ball(ball_position: Vector3, goal: Vector3) -> void:
	var to_goal := goal-ball_position
	to_goal.y = 0.0
	var target := ball_position+to_goal.normalized()*1.6
	var direction := target-body.global_position
	direction.y = 0.0
	input.move = _to_input(direction.normalized()) if direction.length()>0.01 else Vector2.ZERO


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()


func _to_input(direction: Vector3) -> Vector2:
	return Vector2(direction.x,-direction.z).normalized()
