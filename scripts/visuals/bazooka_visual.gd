extends Node3D
## Supplied Meshy launcher, with a skeletal grip and procedural fire recoil.
const Shapes := preload("res://scripts/visuals/shape_library.gd")
const Pose := preload("res://scripts/visuals/bazooka_pose.gd")
const Launcher := preload("res://scenes/visuals/meshy_bazooka.tscn")
var character: Node3D
var equipped := false
var aiming := false
var aim_direction := Vector3.FORWARD
var recoil_amount := 0.0
var _fire_time := 0.0
var _gun: Node3D
var _modifier: SkeletonModifier3D
var _flash: MeshInstance3D
var _trigger: Marker3D
var _support: Marker3D
var _muzzle: Marker3D


func setup(actor: Node3D,skeleton: Skeleton3D) -> void:
	character=actor
	_gun=Launcher.instantiate() as Node3D
	add_child(_gun)
	_trigger=_gun.get_node("TriggerGrip") as Marker3D
	_support=_gun.get_node("SupportGrip") as Marker3D
	_muzzle=_gun.get_node("Muzzle") as Marker3D
	_flash=Shapes.ellipsoid(_gun,_muzzle.position+Vector3(0,0,-0.08),Vector3(0.22,0.22,0.28),Shapes.material(Color("ffcf56"),0.5,true))
	_flash.hide()
	_modifier=Pose.new()
	_modifier.weapon=self
	skeleton.add_child(_modifier)
	visible=false


func fire() -> void:
	_fire_time=0.32
	visible=true


func _process(delta: float) -> void:
	_fire_time=maxf(0.0,_fire_time-delta)
	recoil_amount=sin(clampf(_fire_time/0.32,0.0,1.0)*PI)
	visible=(equipped or _fire_time>0.0) and not character.get("ragdoll_active")
	_modifier.active=visible
	var pitch := 0.10 if aiming else -0.22
	if aiming:
		pitch=clampf(atan2(aim_direction.y,Vector2(aim_direction.x,aim_direction.z).length()),-0.45,0.75)
	_gun.position=Vector3(0.26,0.90,-0.18+recoil_amount*0.12)
	_gun.rotation.x=pitch+recoil_amount*0.16
	_flash.visible=_fire_time>0.25


func trigger_position() -> Vector3:
	return _trigger.global_position


func support_position() -> Vector3:
	return _support.global_position


func muzzle_position() -> Vector3:
	return _muzzle.global_position
