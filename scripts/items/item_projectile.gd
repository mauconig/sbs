extends Node3D
## Locked homing missile with swept contacts, including airborne targets.

const Shapes := preload("res://scripts/visuals/shape_library.gd")
var system
var shooter: Node3D
var target: Node3D
var lifetime := 8.0
var turn_speed := 9.0
var direction := Vector3.FORWARD
var speed := 25.0
var travelled := 0.0
var _flame: MeshInstance3D


func _ready() -> void:
	add_to_group("item_projectiles")
	var body := CylinderMesh.new()
	body.top_radius=0.13
	body.bottom_radius=0.13
	body.height=0.62
	body.radial_segments=12
	var body_visual := Shapes.instance(self,body,Shapes.material(Color("fff8e4")))
	body_visual.rotation.x=PI*0.5
	var nose := CylinderMesh.new()
	nose.top_radius=0.0
	nose.bottom_radius=0.14
	nose.height=0.28
	nose.radial_segments=12
	var nose_visual := Shapes.instance(self,nose,Shapes.material(Color("f63397")),Vector3(0,0,-0.43))
	nose_visual.rotation.x= -PI*0.5
	for side in [-1.0,1.0]:
		var fin := BoxMesh.new()
		fin.size=Vector3(0.20,0.045,0.25)
		Shapes.instance(self,fin,Shapes.material(Color("f63397")),Vector3(side*0.16,0,0.25))
	_flame=Shapes.ellipsoid(self,Vector3(0,0,0.47),Vector3(0.08,0.08,0.23),Shapes.material(Color("ffb923"),0.5,true))
	look_at(global_position+direction,Vector3.FORWARD if absf(direction.y)>0.99 else Vector3.UP)
	var smoke := CPUParticles3D.new()
	smoke.amount=12
	smoke.lifetime=0.30
	smoke.local_coords=false
	smoke.position.z=0.38
	smoke.direction=Vector3.UP
	smoke.spread=25.0
	smoke.gravity=Vector3.ZERO
	smoke.initial_velocity_min=0.15
	smoke.initial_velocity_max=0.35
	smoke.scale_amount_min=0.04
	smoke.scale_amount_max=0.09
	var shrink := Curve.new()
	shrink.add_point(Vector2(0,1))
	shrink.add_point(Vector2(1,0))
	smoke.scale_amount_curve=shrink
	var puff := SphereMesh.new()
	puff.radial_segments=8
	puff.rings=4
	puff.material=Shapes.material(Color("ffe6b8"),0.7,true)
	smoke.mesh=puff
	add_child(smoke)


func _physics_process(delta: float) -> void:
	var start := global_position
	lifetime-=delta
	if lifetime<=0.0 or not is_instance_valid(target):
		queue_free()
		return
	var desired := (target.global_position+Vector3.UP*0.7-start).normalized()
	if desired.length_squared()>0.01:
		direction=direction.slerp(desired,minf(1.0,turn_speed*delta)).normalized()
	var motion := direction*speed*delta
	var finish := start+motion
	var query := PhysicsRayQueryParameters3D.create(start,finish,1|2|4|32)
	if shooter is CollisionObject3D:
		query.exclude=[shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var contact: Vector3=hit.position if not hit.is_empty() else finish
	var impacted := not hit.is_empty()
	# Visual playground actors have no CharacterBody3D; use the swept segment.
	for actor in system.actors:
		if actor==shooter or not is_instance_valid(actor):
			continue
		var center: Vector3=actor.global_position+Vector3.UP*0.65
		var closest := Geometry3D.get_closest_point_to_segment(center,start,contact)
		if center.distance_to(closest)<0.58:
			contact=closest
			impacted=true
	if system.ball!=null:
		var ball_center: Vector3=system.ball.global_position
		var closest := Geometry3D.get_closest_point_to_segment(ball_center,start,contact)
		if ball_center.distance_to(closest)<float(system.ball.radius)+0.14:
			contact=closest
			impacted=true
	global_position=contact
	travelled+=start.distance_to(contact)
	_flame.scale.z=0.9+sin(travelled*9.0)*0.25
	if direction.length_squared()>0.01:
		look_at(global_position+direction,Vector3.FORWARD if absf(direction.y)>0.99 else Vector3.UP)
	if impacted:
		system.explode_at(contact,shooter)
		queue_free()
