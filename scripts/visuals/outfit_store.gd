extends RefCounted
## One local outfit, shared by the sandbox and the human player in 1v1.

const SAVE_PATH := "user://player_outfit.cfg"
const BASE_LOOK := preload("res://assets/characters/pip.tres")
const KEYS := ["display_name","number","skin_color","print_color",
	"shirt_color","shorts_color","socks_color","boots_color",
	"shirt_secondary_color","shorts_secondary_color","socks_secondary_color","boots_secondary_color",
	"shirt_pattern","shorts_pattern","socks_pattern","boots_pattern"]


static func load_look(path: String = SAVE_PATH) -> Resource:
	var look := BASE_LOOK.duplicate() as Resource
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return look
	for key in KEYS:
		var value: Variant = config.get_value("outfit",key,look.get(key))
		if typeof(value) != typeof(look.get(key)):
			continue
		if key.ends_with("_pattern"):
			value = clampi(value,0,4)
		look.set(key,value)
	normalize_identity(look)
	return look


static func normalize_identity(look: Resource) -> void:
	var player_name := String(look.get("display_name")).strip_edges().left(12).to_upper()
	look.set("display_name",player_name if not player_name.is_empty() else "PIP")
	var digits := ""
	for character in String(look.get("number")):
		if character in "0123456789" and digits.length() < 2:
			digits += character
	look.set("number",digits if not digits.is_empty() else "10")


static func save_look(look: Resource, path: String = SAVE_PATH) -> Error:
	normalize_identity(look)
	var config := ConfigFile.new()
	for key in KEYS:
		config.set_value("outfit",key,look.get(key))
	return config.save(path)


static func copy_into(source: Resource, target: Resource) -> void:
	for key in KEYS:
		target.set(key,source.get(key))
