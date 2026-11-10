extends Node
## Simple, beatable 1v1 opponent: chase, carry the ball at the goal, shoot
## with a direct call, and slide tackle when the human has the ball.

@export var think_interval := 0.16
@export var think_jitter := 0.06
@export var shoot_range := 14.0
@export var tackle_range := 2.1
@export var tackle_chance := 0.45
@export var aim_error_radians := 0.10
@export var attack_z := 16.0
@export var own_z := -16.0

var body: CharacterBody3D
var opponent: Node3D
var ball: RigidBody3D
var input: RefCounted

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


func _physics_process(delta: float) -> void:
	if body == null or ball == null or opponent == null or input == null:
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
	if body.knocked_out > 0.0 or body.tackle_timer > 0.0 or body.tackle_recovery_timer > 0.0:
		input.move = Vector2.ZERO
		return

	var ball_pos := ball.global_position
	var my_ball := _flat_distance(body.global_position, ball_pos)
	var opp_ball := _flat_distance(opponent.global_position, ball_pos)

	if ball.carrier == body:
		_attack(ball_pos)
	elif ball.carrier == opponent:
		_defend(opponent.global_position)
	elif my_ball < 1.5 and _ball_in_front(ball_pos):
		_attack(ball_pos)
	elif opp_ball < 1.7:
		_defend(opponent.global_position)
	else:
		_chase(ball_pos)


func _ball_in_front(ball_position: Vector3) -> bool:
	var to_ball := ball_position - body.global_position
	to_ball.y = 0.0
	if to_ball.length() < 0.3:
		return true
	return body.facing.dot(to_ball.normalized()) > 0.1


func _attack(ball_position: Vector3) -> void:
	var goal := Vector3(0.0, 0.0, attack_z)
	var to_goal := goal - ball_position
	to_goal.y = 0.0
	if to_goal.length() < 0.01:
		return

	_drive_through_ball(ball_position)
	input.sprint = _flat_distance(body.global_position, ball_position) > 2.2

	var distance := _flat_distance(body.global_position, goal)
	if distance < shoot_range and body.kick and body.kick.cooldown_timer <= 0.0:
		_shoot(ball_position, distance)


func _shoot(ball_position: Vector3, distance: float) -> void:
	var goal := Vector3(0.0, 0.0, attack_z)
	var aim := goal - ball_position
	aim.y = 0.0
	if aim.length() < 0.01:
		return
	_aim_offset = randf_range(-aim_error_radians, aim_error_radians)
	aim = aim.normalized().rotated(Vector3.UP, _aim_offset)

	var ratio := clampf(distance / 20.0, 0.45, 0.95)
	body.kick.force_kick(ratio, aim, 0.0)


func _defend(opponent_position: Vector3) -> void:
	var to_opponent := opponent_position - body.global_position
	to_opponent.y = 0.0
	var distance := to_opponent.length()
	if distance < 0.01:
		return

	input.move = _to_input(to_opponent.normalized())
	input.sprint = distance > 3.0

	if distance < tackle_range and body.tackle_cooldown_timer <= 0.0:
		if randf() < tackle_chance:
			input.tackle = true
			_tackle_hold = 0.12


func _chase(ball_position: Vector3) -> void:
	var to_ball := ball_position - body.global_position
	to_ball.y = 0.0
	var distance := to_ball.length()
	if distance < 0.01:
		return
	input.move = _to_input(to_ball.normalized())
	input.sprint = distance > 2.5


func _drive_through_ball(ball_position: Vector3) -> void:
	var goal := Vector3(0.0, 0.0, attack_z)
	var to_goal := goal - ball_position
	to_goal.y = 0.0
	if to_goal.length() < 0.01:
		input.move = Vector2.ZERO
		return
	var target := ball_position + to_goal.normalized() * 1.6
	var direction := target - body.global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		input.move = Vector2.ZERO
		return
	input.move = _to_input(direction.normalized())


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _to_input(direction: Vector3) -> Vector2:
	return Vector2(direction.x, -direction.z).normalized()
