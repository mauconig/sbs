extends SceneTree
## Dev tool: boots the sandbox, walks the player at the ball, starts charging
## a kick, then saves a screenshot and quits.
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
		input = ScriptedInput.new()
		main.player.input = input
		main.kick.input = input
		main.camera.input = input
		input.move = Vector2(0, 1)

	if frames == 44:
		input.move = Vector2.ZERO
		main.ball.reset_to(
			main.player.global_position
			+ main.player.facing * 1.0
			+ main.player.global_basis.x * 0.55
			+ Vector3.UP * 0.22
		)

	if frames == 50:
		main.camera.yaw = 0.22
		input.kick = true

	if frames == 86:
		main.kick.charge = 0.87

	if frames == 90:
		var image := root.get_texture().get_image()
		image.save_png("res://docs/screenshot.png")
		print("[capture] charge=", snappedf(main.kick.charge, 0.01), " ball=", main.ball.global_position)
		return true

	return false
