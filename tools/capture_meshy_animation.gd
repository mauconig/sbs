extends SceneTree
## Captures Pip idling and running in the actual arena for visual review.
var scene: Node
var actor: Node3D
var elapsed := 0.0
var next_capture := 0.0
var frame := 0
var stage := 0
var stage_time := 0.0
var stage_ids := [0, 6, 1, 2, 3, 5, 7]
var stage_durations := [1.4, 1.4, 1.4, 1.7, 1.7, 1.7, 1.4]
var folder := "res://.godot/meshy_motion_frames"


func _initialize() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(960,540))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = load("res://scenes/visual_prototype.tscn").instantiate()
	root.add_child(scene)
	_setup.call_deferred()


func _setup() -> void:
	await process_frame
	scene.set("_capture_mode",true)
	scene.call("_set_paused",false)
	actor = scene.characters[0] as Node3D
	for index in range(1,scene.characters.size()):
		scene.characters[index].visible = false
	actor.set("frozen",false)
	actor.call("play",0)
	actor.call("_pose",0.0)
	RenderingServer.frame_post_draw.connect(_capture_frame)


func _process(delta: float) -> bool:
	if actor == null:
		return false
	elapsed += delta
	stage_time += delta
	if stage<stage_ids.size()-1 and stage_time>=stage_durations[stage]:
		stage += 1
		stage_time = 0.0
		actor.call("play",stage_ids[stage])
	if stage==stage_ids.size()-1 and stage_time>=stage_durations[stage]:
		print("MESHY MOTION CAPTURE: idle, walk, run, jump, kick, slide and charge, frames=",frame)
		quit()
	return false


func _capture_frame() -> void:
	if elapsed<next_capture:
		return
	var path := "%s/%03d.png"%[folder,frame]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	frame += 1
	next_capture += 1.0/15.0
