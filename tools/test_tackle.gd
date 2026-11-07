extends SceneTree
## Dev tool: headless tackle + knockdown test.

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
		main.bot_brain.set_physics_process(false)
		main.bot.input = null
		main.bot.global_position = Vector3(0, 1, 0)
		main.bot.facing = Vector3(0, 0, 1)
		main.bot.protection = 0.0
		main.player.reset_at(Vector3(0, 1, 2.2), Vector3(0, 0, -1))
		main.ball.reset_to(Vector3(0, 0.4, 1.1))
		input = ScriptedInput.new()
		main.player.input = input
		main.kick.input = input
		print("[test] set up: player z=2.2, bot z=0")

	if frames == 20:
		input.tackle = true
		print("[test] tackle pressed")

	if frames == 24:
		input.tackle = false

	if frames == 30:
		print("[test] after slide: player=", main.player.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" bot knocked=", snappedf(main.bot.knocked_out, 0.01),
			" bot vel=", main.bot.velocity.snapped(Vector3(0.01, 0.01, 0.01)),
			" ball=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" ball vel=", snappedf(main.ball.linear_velocity.length(), 0.01))

	if frames == 120:
		print("[test] recovery: bot knocked=", snappedf(main.bot.knocked_out, 0.01),
			" bot protection=", snappedf(main.bot.protection, 0.01),
			" player cooldown=", snappedf(main.player.tackle_cooldown_timer, 0.01))
		return true

	return false
