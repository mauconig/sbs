extends SceneTree
## Neutral studio turnaround rendered by Godot, showing the actual default asset.
## godot --path . --script tools/capture_character.gd -- --output=docs/default_character_turnaround.png

var stage: Node3D
var actors: Array[Node3D] = []
var frames := 0
var output := "res://docs/default_character_turnaround.png"
var action := 0
var sample := 0.0
var four_views := false
var parts_palette := false
var lower_body := false


func _initialize() -> void:
	_build_stage.call_deferred()


func _build_stage() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--action="):
			action = int(argument.trim_prefix("--action="))
		if argument.begins_with("--sample="):
			sample = float(argument.trim_prefix("--sample="))
		if argument=="--four-views":
			four_views = true
		if argument=="--parts-palette":
			parts_palette = true
		if argument=="--lower-body":
			lower_body = true
	if four_views:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
		root.content_scale_size = Vector2i(1774,887)
		DisplayServer.window_set_size(Vector2i(1774,887))
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8851cf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.45
	environment.ambient_light_sky_contribution = 0.0
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38,145,0)
	key.light_energy = 0.35
	key.light_color = Color("fff5ee")
	key.shadow_enabled = true
	key.shadow_opacity = 0.27
	key.shadow_blur = 4.0
	key.light_angular_distance = 12
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22,-35,0)
	fill.light_energy = 0.12
	fill.light_color = Color("dce4ff")
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/materials/character_stage.gdshader")
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	for index in (4 if four_views else 2):
		var actor := load("res://scenes/visuals/character.tscn").instantiate() as Node3D
		if parts_palette:
			var palette := actor.get("look").duplicate() as Resource
			palette.shirt_color = Color("edf2ff")
			palette.shorts_color = Color("283b70")
			palette.socks_color = Color("44c3d5")
			palette.boots_color = Color("e24a82")
			actor.set("look",palette)
		actor.position.x = [2.04,0.62,-0.83,-2.25][index] if four_views else (0.55 if index==0 else -0.55) if lower_body else 1.28 if index==0 else -1.28
		actor.rotation.y = [0.0,-PI/2,PI,PI/2][index] if four_views else 0.0 if index==0 else PI
		stage.add_child(actor)
		actor.set("frozen",false)
		actor.call("play",action)
		actor.set("time",sample)
		actor.set("action_time",sample)
		actor.call("_pose",0.0)
		var player := actor.get("_animation_player") as AnimationPlayer
		if player != null:
			actor.set("frozen",true)
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.seek(sample,true)
		actors.append(actor)
		var shadow := MeshInstance3D.new()
		var shadow_plane := PlaneMesh.new()
		shadow_plane.size = Vector2(1.1,1.0)
		shadow.mesh = shadow_plane
		shadow.position = Vector3(actor.position.x,0.003,0)
		var shadow_material := ShaderMaterial.new()
		var shadow_shader := Shader.new()
		shadow_shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment() { ALBEDO = vec3(0.22,0.10,0.39); ALPHA = (1.0-smoothstep(0.72,1.0,length(UV*2.0-1.0)))*0.4; }"
		shadow_material.shader = shadow_shader
		shadow.material_override = shadow_material
		stage.add_child(shadow)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.05 if four_views else 2.8
	stage.add_child(camera)
	camera.position = Vector3(0,2.25,-8)
	if four_views:
		camera.position.y = 2.18
	camera.look_at(Vector3(0,1.18 if four_views else 1.25,0))
	if lower_body:
		camera.size = 0.95
		camera.position = Vector3(0,0.68,-8)
		camera.look_at(Vector3(0,0.44,0))
	camera.current = true
	RenderingServer.frame_post_draw.connect(_capture)


func _process(_delta: float) -> bool:
	frames += 1
	return false


func _capture() -> void:
	if frames < 50:
		return
	RenderingServer.frame_post_draw.disconnect(_capture)
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	print("CHARACTER_CAPTURE ",output," result=",result)
	stage.queue_free()
	quit(result)
