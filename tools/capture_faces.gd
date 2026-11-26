extends SceneTree
## Painted-face check in the shared stadium daylight: one character per expression.
## godot --path . --script tools/capture_faces.gd -- --output=res://.godot/validation/faces.png [--angle=35] [--blink]

const CharacterScene := preload("res://scenes/visuals/character.tscn")
const DayStadium := preload("res://scripts/visuals/day_stadium.gd")

var output := "res://.godot/validation/faces.png"
var angle := 0.0
var blink := false
var frames := 0
var actors: Array[Node3D] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--angle="):
			angle = float(argument.trim_prefix("--angle="))
		if argument == "--blink":
			blink = true
	_build.call_deferred()


func _build() -> void:
	root.size = Vector2i(1600, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	DayStadium.add_daylight(stage)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var turf := StandardMaterial3D.new()
	turf.albedo_color = Color("7cbf5a")
	turf.roughness = 1.0
	ground.material_override = turf
	stage.add_child(ground)
	for index in 5:
		var actor := CharacterScene.instantiate() as Node3D
		actor.set("expression", index)
		actor.position = Vector3((index - 2) * 1.25, 0, 0)
		actor.rotation.y = deg_to_rad(angle)
		stage.add_child(actor)
		actors.append(actor)
	var camera := Camera3D.new()
	camera.fov = 30
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.6, -6.6), Vector3(0, 1.05, 0))
	camera.current = true


func _process(_delta: float) -> bool:
	frames += 1
	for actor in actors:
		actor.set("time", 0.3)
		if blink:
			var face: Node = actor.get("face_paint")
			if face != null:
				face.call("set_blink", 0.05)
	if frames == 40:
		var image := root.get_texture().get_image()
		image.save_png(output)
		print("CAPTURE ", output)
		quit()
	return false
