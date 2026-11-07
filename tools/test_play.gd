extends SceneTree
## Dev tool: headless gameplay smoke test.
## Usage: godot --headless --path . --script tools/test_play.gd

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frames += 1

	if frames == 5:
		for child in main.get_children():
			if child.name == "FarGoal" or child.name == "NearGoal":
				child.scored.connect(func(): print("[test] GOAL signal from ", child.name))
		main.bot_brain.set_physics_process(false)
		main.bot.input = null
		main.bot.global_position = Vector3(8, 1, -14)
		print("[test] ball resting y=", snappedf(main.ball.global_position.y, 0.001))

	if frames == 10:
		main.player.reset_at(Vector3(0, 1, 1.6), Vector3(0, 0, -1))
		main.kick.charging = true
		main.kick.charge = 1.0
		main.kick._release()
		print("[test] kicked from 17.6m out")

	if frames == 90:
		print("[test] flight end ball=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)), " score=", main.player_score)

	if frames == 120:
		main.ball.reset_to(Vector3(0.0, 1.2, -16.6))
		print("[test] teleported ball into goal area")

	if frames == 130:
		print("[test] score=", main.player_score, " pending=", snappedf(main._pending_reset, 0.01), " banner=", main.hud._banner.text)

	if frames == 260:
		print("[test] after reset ball=", main.ball.global_position.snapped(Vector3(0.01, 0.01, 0.01)), " player z=", snappedf(main.player.global_position.z, 0.01))
		return true

	return false
