extends SceneTree
## Render the actual sandbox shop; --demo previews a kit without saving it.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var output := "user://kit_shop_preview.png"
	var demo := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument == "--demo":
			demo = true
	var scene := load("res://scenes/visual_prototype.tscn").instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	scene.call("open_shop")
	var shop: Node = scene.get("shop")
	if demo:
		shop.call("_apply_preset","HOME")
		shop.get("_name_field").text = "RIVERA"
		shop.get("_number_field").text = "07"
		shop.call("_name_changed","RIVERA")
		shop.call("_number_changed","07")
	for frame in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	print("SHOP_CAPTURE ",output," result=",result)
	scene.queue_free()
	quit(result)
