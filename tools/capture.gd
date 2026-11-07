extends SceneTree
## Dev tool: stages a 1v1 screenshot (player charging, bot defending) and quits.
## Usage: godot --path . --script tools/capture.gd

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
		main.bot.reset_at(Vector3(1.4, 1, 0.6), Vector3(0, 0, 1))
		main.player.reset_at(Vector3(-0.6, 1, 4.2), Vector3(0, 0, -1))
		main.ball.reset_to(Vector3(-0.2, 0.22, 2.9))
		main.hud._banner.modulate.a = 0.0
		input = ScriptedInput.new()
		main.player.input = input
		main.kick.input = input
		input.kick = true

	if frames == 45:
		main.kick.charge = 0.87

	if frames == 46:
		var image := root.get_texture().get_image()
		image.save_png("res://docs/screenshot.png")
		print("[capture] charge=", snappedf(main.kick.charge, 0.01))
		return true

	return false
