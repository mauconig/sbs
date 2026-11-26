extends Node3D
## Shared animated mystery-box spawner, small cyan pad and dropped pickup.

const Shapes := preload("res://scripts/visuals/shape_library.gd")
const FONT := preload("res://assets/fonts/BarlowCondensed-Black.ttf")
enum Kind {ITEM,BOOST,DROPPED}
var kind := Kind.ITEM
var item_id: StringName=&"bazooka"
var respawn_time := 12.0
var cooldown := 0.0
var ignored_actor_id := 0
var owner_lock := 0.0
var pickup_lock := 0.0
var lifetime := 30.0
var _time := 0.0
var _body: Node3D
var _ring: MeshInstance3D
var _label: Label3D
var _active_material: StandardMaterial3D
var _inactive_material: StandardMaterial3D


func _ready() -> void:
	var color := Color("22d0e6") if kind==Kind.BOOST else Color("ffbf38")
	_active_material=Shapes.material(color,0.45,true)
	_inactive_material=Shapes.material(Color("3e4654"),0.8)
	var disk := CylinderMesh.new()
	disk.top_radius=0.78 if kind==Kind.BOOST else 1.0
	disk.bottom_radius=disk.top_radius
	disk.height=0.07
	disk.radial_segments=32
	Shapes.instance(self,disk,Shapes.material(Color("26354b")),Vector3(0,0.045,0))
	var ring := TorusMesh.new()
	ring.inner_radius=0.61 if kind==Kind.BOOST else 0.86
	ring.outer_radius=0.75 if kind==Kind.BOOST else 1.0
	ring.rings=40
	ring.ring_segments=6
	_ring=Shapes.instance(self,ring,_active_material,Vector3(0,0.10,0))
	_body=Node3D.new()
	add_child(_body)
	if kind==Kind.BOOST:
		for side in [-1.0,1.0]:
			var chevron := BoxMesh.new()
			chevron.size=Vector3(0.12,0.035,0.48)
			var arm := Shapes.instance(_body,chevron,Shapes.material(Color("fff8e4"),0.6,true),Vector3(side*0.14,0.11,0))
			arm.rotation.y=side*PI*0.25
	else:
		var cube := BoxMesh.new()
		cube.size=Vector3.ONE*0.66
		Shapes.instance(_body,cube,_active_material)
		for axis in 3:
			for a in [-1.0,1.0]:
				for b in [-1.0,1.0]:
					var edge := BoxMesh.new()
					var size := Vector3.ONE*0.035
					size[axis]=0.70
					edge.size=size
					var at := Vector3.ZERO
					at[(axis+1)%3]=a*0.335
					at[(axis+2)%3]=b*0.335
					Shapes.instance(_body,edge,Shapes.material(Color("654127")),at)
		for side in [-1.0,1.0]:
			var mark := Label3D.new()
			mark.text="?" if kind==Kind.ITEM else "B"
			mark.font=FONT
			mark.font_size=100
			mark.pixel_size=0.006
			mark.position=Vector3(0,0,side*0.34)
			mark.rotation.y=0.0 if side>0 else PI
			mark.modulate=Color("fff8e4")
			mark.outline_modulate=Color("654127")
			mark.outline_size=10
			mark.shaded=false
			_body.add_child(mark)
		var top_mark := Label3D.new()
		top_mark.text="?" if kind==Kind.ITEM else "B"
		top_mark.font=FONT
		top_mark.font_size=100
		top_mark.pixel_size=0.006
		top_mark.position.y=0.34
		top_mark.rotation.x= -PI*0.5
		top_mark.modulate=Color("fff8e4")
		top_mark.outline_modulate=Color("654127")
		top_mark.outline_size=10
		top_mark.shaded=false
		_body.add_child(top_mark)
	_label=Label3D.new()
	_label.font=FONT
	_label.font_size=48
	_label.pixel_size=0.012
	_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y=0.65
	_label.shaded=false
	_label.modulate=color
	_label.outline_modulate=Color("26354b")
	_label.outline_size=8
	add_child(_label)


func _process(delta: float) -> void:
	_time+=delta
	_body.visible=cooldown<=0.0
	_ring.material_override=_active_material if cooldown<=0.0 else _inactive_material
	_label.text=str(int(ceil(cooldown))) if cooldown>0.0 else ""
	if kind!=Kind.BOOST:
		_body.position.y=0.95+sin(_time*2.2)*0.12
		_body.rotation.y=_time*0.7
		_body.rotation.z=sin(_time)*0.08


func advance(delta: float) -> void:
	cooldown=maxf(0.0,cooldown-delta)
	owner_lock=maxf(0.0,owner_lock-delta)
	pickup_lock=maxf(0.0,pickup_lock-delta)
	if kind==Kind.DROPPED:
		lifetime-=delta
		if lifetime<=0.0:
			queue_free()


func available_for(actor: Node3D) -> bool:
	return cooldown<=0.0 and pickup_lock<=0.0 and not (owner_lock>0.0 and actor.get_instance_id()==ignored_actor_id)


func collect() -> void:
	if kind==Kind.DROPPED:
		queue_free()
	else:
		cooldown=respawn_time


func reset_pad() -> void:
	cooldown=0.0
