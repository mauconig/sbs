extends SceneTree
## Deterministic pose sequence for art review; PNGs stay in the Godot cache.
var scene: Node
var frame := -4
var active := -1
var folder := "res://.godot/visual_motion_frames"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(640,640))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = load("res://scenes/visual_prototype.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_save_frame)


func _process(_delta: float) -> bool:
	frame += 1
	if frame<0:
		return false
	if frame==0:
		scene.stage_portrait(0)
		for index in range(1,scene.characters.size()):
			scene.characters[index].visible = false
	if frame==288:
		scene.queue_free()
		return false
	if frame>=289:
		print("MOTION CAPTURE: 288 frames at 30 samples/second in ",folder)
		quit()
		return false
	var action := int(floor(frame/48.0))
	var actor: Node = scene.characters[0]
	if action!=active:
		actor.play(action)
		active = action
	var phase := (frame%48)/30.0
	actor.time = phase
	actor.action_time = phase
	actor._pose(0.0)
	return false


func _save_frame() -> void:
	if frame>=0 and frame<288:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+"/%03d.png"%frame))
