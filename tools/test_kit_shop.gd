extends SceneTree
## Full outfit flow with an isolated save, never the real player's outfit.

const Store := preload("res://scripts/visuals/outfit_store.gd")
var _path := "user://test_kit_shop_"+str(OS.get_process_id())+".cfg"
var _scenes: Array[Node] = []


func _initialize() -> void:
	_verify.call_deferred()


func _sandbox() -> Node3D:
	var scene := load("res://scenes/visual_prototype.tscn").instantiate() as Node3D
	scene.set("outfit_path",_path)
	root.add_child(scene)
	_scenes.append(scene)
	return scene


func _verify() -> void:
	var scene := _sandbox()
	await process_frame
	var actor: Node3D = scene.get("characters")[0]
	var original := actor.get("look") as Resource
	var original_shirt: Color = original.get("shirt_color")
	scene.call("open_shop")
	var shop: Node = scene.get("shop")
	assert(shop.get("is_open"))
	assert(scene.get("paused") and scene.get("ball").freeze)
	assert(not scene.get("kick_controller").is_physics_processing())
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var draft := shop.get("draft") as Resource
	for part in ["shirt","shorts","socks","boots"]:
		shop.call("select_part",part)
		shop.call("_set_primary",Color("1368ad"))
		shop.call("_set_secondary",Color("f1d95b"))
		shop.call("_set_pattern",4)
		var mesh_name: String = {"shirt":"Shirt","shorts":"Shorts","socks":"Socks","boots":"Boots"}[part]
		var mesh := shop.get("preview_actor").find_child(mesh_name,true,false) as MeshInstance3D
		var material := mesh.get_active_material(0) as ShaderMaterial
		assert(material.get_shader_parameter("pattern_mode") == 4,"Pattern did not reach "+part)
		assert(draft.get(part+"_color").is_equal_approx(Color("1368ad")))
	assert(original.get("shirt_color").is_equal_approx(original_shirt),"Draft edited the equipped kit")
	shop.call("_name_changed","RIVERA")
	shop.call("_number_changed","0a7")
	assert(draft.get("number") == "07")
	var preview := shop.get("preview_actor") as Node3D
	var lettering := preview.get("_shirt_print") as SubViewport
	assert(lettering.get("_player_name").text == "RIVERA")
	assert(lettering.get("_number").text == "07")
	var skin := (preview.find_child("Skin",true,false) as MeshInstance3D).get_active_material(0)
	assert(skin == (preview.find_child("Legs",true,false) as MeshInstance3D).get_active_material(0))
	assert(skin.get_shader_parameter("pattern_mode") == 0,"Uniform pattern affected the skin")
	var shirt_mesh := preview.find_child("Shirt",true,false) as MeshInstance3D
	var arrays := shirt_mesh.mesh.surface_get_arrays(0)
	assert(not arrays[Mesh.ARRAY_TEX_UV].is_empty(),"Fabric UVs missing")
	assert(not arrays[Mesh.ARRAY_TEX_UV2].is_empty(),"Shirt print UVs missing")
	var valid_uv := false
	var excluded_uv := false
	for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
		valid_uv = valid_uv or (uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1)
		excluded_uv = excluded_uv or uv.x < 0
	assert(valid_uv and excluded_uv,"Shirt print must cover the back and exclude the front")
	shop.get("_name_field").grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	shop.call("_input",key)
	assert(shop.get("is_open"),"Typing B in the name closed the shop")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	shop.call("close_shop")
	assert(not scene.get("paused") and scene.get("kick_controller").is_physics_processing())
	scene.get("kick_controller").call("_physics_process",0.016)
	assert(not scene.get("kick_controller").get("charging"),"Closing the shop while clicking started a shot")
	var release := mouse.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	assert(not FileAccess.file_exists(_path),"Cancel saved the draft")
	scene.call("open_shop")
	shop.call("_apply_preset","HOME")
	shop.call("_name_changed","RIVERA")
	shop.call("_number_changed","07")
	shop.call("equip_outfit")
	assert(not shop.get("is_open") and not scene.get("paused"))
	assert(original.get("display_name") == "RIVERA" and original.get("number") == "07")
	assert(FileAccess.file_exists(_path))
	var saved := Store.load_look(_path)
	assert(saved.get("shirt_pattern") == 1 and saved.get("number") == "07")
	assert(saved.get("shirt_color").is_equal_approx(original.get("shirt_color")))
	var restored := _sandbox()
	var restored_look: Resource = restored.get("characters")[0].get("look")
	assert(restored_look.get("display_name") == "RIVERA")
	assert(restored_look.get("shirt_pattern") == 1)
	var match_scene := load("res://scenes/main.tscn").instantiate() as Node3D
	match_scene.set("outfit_path",_path)
	root.add_child(match_scene)
	_scenes.append(match_scene)
	var match_look: Resource = match_scene.get("player").get("character_look")
	assert(match_look.get("display_name") == "RIVERA" and match_look.get("number") == "07")
	assert(match_look.get("shirt_color").is_equal_approx(saved.get("shirt_color")))
	assert(match_scene.get("bot").get("character_look").get("display_name") != "RIVERA","Outfit changed the opponent")
	_finish.call_deferred()


func _finish() -> void:
	await RenderingServer.frame_post_draw
	for scene in _scenes:
		scene.queue_free()
	_scenes.clear()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	print("KIT_SHOP_OK draft/cancel/equip, patterns on four parts, live identity, skin link, isolated save, sandbox reload and 1v1")
	quit()
