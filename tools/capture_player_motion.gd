extends SceneTree
## Render the actual playable scene and measure normal/sprint movement.
const ScriptedInput := preload("res://tools/scripted_input.gd")
const MovementTuning := preload("res://scripts/movement_tuning.gd")
var scene: Node
var input := ScriptedInput.new()
var frame := 0
var walk_speed := 0.0
var sprint_speed := 0.0
var run_position := 0.0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(960,540))
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)

func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		scene.player.input = input
		scene.kick.input = input
		scene.camera.input = input
		scene.bot_brain.set_physics_process(false)
		scene.bot.input = null
		scene.bot.position = Vector3(8,0.1,-10)
		scene.ball.position = Vector3(-8,0.4,0)
		scene.hud.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if frame == 60:
		_capture("idle")
	if frame == 65:
		input.move = Vector2(0,1)
	if frame == 90:
		walk_speed = Vector2(scene.player.velocity.x,scene.player.velocity.z).length()
		_capture("walk")
	if frame == 95:
		input.sprinting = true
	if frame == 100:
		run_position = scene.player.get("_visual").get("_animation_player").current_animation_position
	if frame == 115:
		var player: AnimationPlayer = scene.player.get("_visual").get("_animation_player")
		var advanced := fposmod(player.current_animation_position-run_position,player.current_animation_length)
		print("ANIMATION CLOCK: 0.25 seconds real time advances clip by ",snappedf(advanced,0.001)," seconds")
		if absf(advanced-0.5)>0.035:
			push_error("Imported animation clock did not advance at 2x speed")
			quit(1)
	if frame == 120:
		sprint_speed = Vector2(scene.player.velocity.x,scene.player.velocity.z).length()
		_capture("sprint")
	if frame == 125:
		print("PLAYER MOTION: walk=",walk_speed," sprint=",sprint_speed," animation_speed=",scene.player.get("_visual").get("_animation_player").speed_scale)
		if absf(walk_speed-MovementTuning.WALK_SPEED)>0.01 or absf(sprint_speed-MovementTuning.SPRINT_SPEED)>0.01:
			push_error("Player movement did not reach shared walk/sprint tuning")
			quit(1)
		input.move = Vector2.ZERO
		input.sprinting = false
		scene.player.reset_at(Vector3(0,0.02,9),Vector3(0,0,-1))
	if frame == 140:
		input.move = Vector2(0,1)
	if frame == 155:
		input.jump = true
	if frame == 156:
		input.jump = false
	if frame == 170:
		if scene.player.position.y<0.5 or scene.player.get("_visual").animation!=2:
			push_error("Moving gameplay jump failed")
			quit(1)
		_capture("jump")
		input.move = Vector2.ZERO
	if frame == 230:
		scene.player.reset_at(Vector3(0,0.02,7),Vector3(0,0,-1))
	if frame == 240:
		input.tackle = true
	if frame == 241:
		input.tackle = false
	if frame == 251:
		var visual: Node3D = scene.player.get("_visual")
		if visual.animation!=5 or absf(visual.rotation.x)>0.01 or absf(visual.position.y)>0.01:
			push_error("Gameplay sweep received an extra floating transform")
			quit(1)
		_capture("sweep")
	if frame == 285:
		if scene.player.get("_visual").animation!=0:
			push_error("Gameplay sweep did not recover to idle")
			quit(1)
		else:
			print("GAMEPLAY ACTIONS PASS: moving jump, grounded sweep, recovery")
			quit()
	return false

func _capture(state: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/meshy_game_"+state+".png"))
