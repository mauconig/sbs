extends SceneTree
## Dev tool: headless movement + dribble + stamina test.

const ScriptedInput := preload("res://tools/scripted_input.gd")

var main: Node
var input: RefCounted
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frames += 1

	if frames == 5:
		print("[test] physics engine = ", ProjectSettings.get_setting("physics/3d/physics_engine", "unset"))
		main.bot_brain.set_physics_process(false)
		main.bot.input = null
		main.bot.global_position = Vector3(8, 1, -14)
		input = ScriptedInput.new()
		main.player.input = input
		main.kick.input = input
		main.camera.input = input
		print("[test] start player=", main.player.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" ball=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)))

	if frames == 10:
		input.move = Vector2(0, 1)
		input.sprinting = true

	if frames % 20 == 0 and frames >= 20 and frames <= 120:
		var gap: float = main.ball.global_position.distance_to(main.player.global_position)
		print("[test] f=", frames,
			" player=", main.player.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" ball=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" gap=", snappedf(gap, 0.01),
			" stamina=", snappedf(main.player.stamina, 0.1))

	if frames == 130:
		input.move = Vector2.ZERO
		input.sprinting = false
		print("[test] stopped. dribbling check: gap=", snappedf(main.ball.global_position.distance_to(main.player.global_position), 0.01))

	if frames == 160:
		print("[test] trap check: gap=", snappedf(main.ball.global_position.distance_to(main.player.global_position), 0.01),
			" ball speed=", snappedf(main.ball.linear_velocity.length(), 0.01))
		input.kick = true

	if frames == 200:
		input.kick = false

	if frames == 220:
		print("[test] ball vel=", snappedf(main.ball.linear_velocity.length(), 0.01), " score=", main.player_score, " shots=", main.hud.shots)

	if frames == 250:
		return true

	return false
