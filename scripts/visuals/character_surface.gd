extends RefCounted
## Shared illustrated material response for the authored default character.

const SurfaceShader := preload("res://assets/materials/character_surface.gdshader")
static func apply(node: Node, look: Resource, print_texture: Texture2D = null) -> void:
	_apply_parts(node,look,{},print_texture)


static func _apply_parts(node: Node, look: Resource, materials: Dictionary, print_texture: Texture2D) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var label := source.resource_name
			# Legs are a separate mesh, with the very same material as head/arms.
			if "Leg" in label:
				label = "PlayerSkin"
			if materials.has(label):
				if node.get_surface_override_material(surface) != materials[label]:
					node.set_surface_override_material(surface,materials[label])
				continue
			var material := node.get_surface_override_material(surface) as ShaderMaterial
			if material == null or material.shader != SurfaceShader:
				material = ShaderMaterial.new()
				material.shader = SurfaceShader
			material.set_shader_parameter("color_atlas",source.albedo_texture)
			material.set_shader_parameter("base_color",source.albedo_color)
			material.set_shader_parameter("skin",1.0 if "Skin" in label else 0.0)
			material.set_shader_parameter("shirt",1.0 if "Shirt" in label else 0.0)
			material.set_shader_parameter("skin_color",look.skin_color)
			material.set_shader_parameter("shirt_color",look.shirt_color)
			material.set_shader_parameter("shorts_color",look.shorts_color)
			material.set_shader_parameter("socks_color",look.socks_color)
			material.set_shader_parameter("boots_color",look.boots_color)
			material.set_shader_parameter("shorts",1.0 if "Shorts" in label else 0.0)
			material.set_shader_parameter("socks",1.0 if "Socks" in label else 0.0)
			material.set_shader_parameter("boots",1.0 if "Boots" in label else 0.0)
			material.set_shader_parameter("pattern_mode",0)
			for part in ["shirt","shorts","socks","boots"]:
				if part.to_lower() in label.to_lower():
					material.set_shader_parameter("pattern_mode",look.get(part+"_pattern"))
					material.set_shader_parameter("pattern_color",look.get(part+"_secondary_color"))
			material.set_shader_parameter("has_shirt_print",print_texture != null)
			material.set_shader_parameter("shirt_print",print_texture)
			material.set_shader_parameter("print_color",look.print_color)
			material.set_shader_parameter("hair",1.0 if "Hair" in label else 0.0)
			material.set_shader_parameter("gloss",0.055 if "Gold" in label else 0.42 if "Hair" in label else 0.004)
			materials[label] = material
			if node.get_surface_override_material(surface) != material:
				node.set_surface_override_material(surface,material)
	for child in node.get_children():
		_apply_parts(child,look,materials,print_texture)
