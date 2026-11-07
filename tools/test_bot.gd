extends SceneTree
## Dev tool: headless AI test. The human stands still; the bot must
## win the ball, carry it and score on its own.

var main: Node
var frames := 0
var trace := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frames += 1

	if frames == 5:
		main.player.input = null
		main.kick.input = null
		main.player.global_position = Vector3(8, 1, 7)
		main.bot.kick.debug = true
		print("[bot] human disabled, letting the bot play")

	if frames % 60 == 0 and frames > 0:
		print("[bot] t=", snappedf(frames / 60.0, 0.1), "s",
			" bot=", main.bot.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
			" ball=", main.ball.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
			" score=", main.player_score, "-", main.bot_score,
			" bot_cd=", snappedf(main.bot.kick.cooldown_timer, 0.01))

	if frames >= 300 and frames <= 340:
		print("[trace] f=", frames,
			" ball=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" bvel=", main.ball.linear_velocity.snapped(Vector3(0.01, 0.01, 0.01)),
			" kick=", main.bot.input.kick,
			" charging=", main.bot.kick.charging,
			" charge=", snappedf(main.bot.kick.charge, 0.01),
			" cd=", snappedf(main.bot.kick.cooldown_timer, 0.01),
			" sleeping=", main.ball.sleeping)

	if main.bot.kick.cooldown_timer > 0.24:
		trace = 14
	if trace > 0:
		trace -= 1
		print("[after] f=", frames,
			" bpos=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)),
			" bvel=", main.ball.linear_velocity.snapped(Vector3(0.01, 0.01, 0.01)),
			" lock=", snappedf(main.bot.dribble_lock, 0.01))

	if frames == 1200:
		print("[bot] final score=", main.player_score, "-", main.bot_score)
		return true

	return false
