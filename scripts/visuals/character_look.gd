extends Resource
## Art controls shared by every character, independent of gameplay.

@export var display_name := "PIP":
	set(value):
		display_name = value
		emit_changed()
@export var model_scene: PackedScene
@export_enum("Curly", "Spiky", "Swept", "Quiff") var hairstyle := 3
@export var skin_color := Color(1, 0.66, 0.57, 1):
	set(value):
		skin_color = value
		emit_changed()
@export var hair := Color(0.25, 0.105, 0.105, 1)
@export var shirt_color := Color.WHITE:
	set(value):
		shirt_color = value
		emit_changed()
@export var accent := Color(1, 0.86, 0.96, 1)
@export var shorts_color := Color.WHITE:
	set(value):
		shorts_color = value
		emit_changed()
@export var socks_color := Color.WHITE:
	set(value):
		socks_color = value
		emit_changed()
@export var boots_color := Color.WHITE:
	set(value):
		boots_color = value
		emit_changed()
@export var number := "10":
	set(value):
		number = value
		emit_changed()
@export var print_color := Color("292135"):
	set(value):
		print_color = value
		emit_changed()
@export var shirt_secondary_color := Color("292135"):
	set(value):
		shirt_secondary_color = value
		emit_changed()
@export var shorts_secondary_color := Color("f63397"):
	set(value):
		shorts_secondary_color = value
		emit_changed()
@export var socks_secondary_color := Color("00b8e9"):
	set(value):
		socks_secondary_color = value
		emit_changed()
@export var boots_secondary_color := Color("f63397"):
	set(value):
		boots_secondary_color = value
		emit_changed()
@export_enum("Solid", "Stripes", "Hoops", "Split", "Diagonal") var shirt_pattern := 0:
	set(value):
		shirt_pattern = value
		emit_changed()
@export_enum("Solid", "Stripes", "Hoops", "Split", "Diagonal") var shorts_pattern := 0:
	set(value):
		shorts_pattern = value
		emit_changed()
@export_enum("Solid", "Stripes", "Hoops", "Split", "Diagonal") var socks_pattern := 0:
	set(value):
		socks_pattern = value
		emit_changed()
@export_enum("Solid", "Stripes", "Hoops", "Split", "Diagonal") var boots_pattern := 0:
	set(value):
		boots_pattern = value
		emit_changed()
@export var accessory := true
