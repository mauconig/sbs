extends Node3D
## Native jointed physical bones: mesh deformation follows live physics bodies.
signal finished(position: Vector3)
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D]=[]
var active := false
var recovery_position := Vector3.ZERO
var _elapsed := 0.0
var _settled := 0.0
var _paused_velocities: Array[Vector3]=[]
var suspended := false
var _hips: PhysicalBone3D


func setup(target: Skeleton3D) -> void:
	skeleton=target
	simulator=PhysicalBoneSimulator3D.new()
	simulator.name="RagdollPhysics"
	skeleton.add_child(simulator)
	_segment("Hips","Spine",0.15,3.0)
	_segment("Spine2","Neck",0.15,3.0,Vector3(0,0,0.12))
	_segment("Head","HeadTop_End",0.34,2.0)
	for side in ["Left","Right"]:
		_segment(side+"Arm",side+"ForeArm",0.075,0.7)
		_segment(side+"ForeArm",side+"Hand",0.065,0.5)
		_segment(side+"UpLeg",side+"Leg",0.095,1.2)
		_segment(side+"Leg",side+"Foot",0.085,0.8)
		_segment(side+"Foot",side+"ToeBase",0.09,0.5)
	for a in bodies:
		for b in bodies:
			if a!=b:
				a.add_collision_exception_with(b)
	simulator.active=false
	set_physics_process(false)


func _segment(name_suffix: String,child_suffix: String,radius: float,mass: float,extra_center: Vector3=Vector3.ZERO) -> void:
	var index := skeleton.find_bone("mixamorig_"+name_suffix)
	var child := skeleton.find_bone("mixamorig_"+child_suffix)
	if index<0 or child<0:
		push_error("Ragdoll missing bone "+name_suffix)
		return
	var rest := skeleton.get_bone_global_rest(index)
	var end := skeleton.get_bone_global_rest(child).origin
	var local_end := rest.affine_inverse()*end
	var center := local_end*0.5+extra_center
	var body := PhysicalBone3D.new()
	body.name="Physical_"+name_suffix
	body.mass=mass
	body.friction=0.7
	body.bounce=0.08
	body.linear_damp=0.65
	body.angular_damp=1.2
	body.gravity_scale=26.0/9.8
	body.collision_layer=0
	body.collision_mask=1|2|4|32
	body.body_offset=Transform3D(Basis(Quaternion(Vector3.UP,local_end.normalized())),center)
	body.joint_offset=body.body_offset.affine_inverse()
	body.joint_type=PhysicalBone3D.JOINT_TYPE_NONE if name_suffix=="Hips" else PhysicalBone3D.JOINT_TYPE_CONE
	if name_suffix!="Hips":
		body.set("joint_constraints/swing_span",50.0 if "Arm" in name_suffix else 32.0)
		body.set("joint_constraints/twist_span",25.0)
	var shape: Shape3D
	if name_suffix=="Head":
		shape=SphereShape3D.new()
		shape.radius=radius
	else:
		shape=CapsuleShape3D.new()
		shape.radius=radius
		shape.height=maxf(radius*2.01,local_end.length()+radius*0.8)
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	body.set("bone_name",skeleton.get_bone_name(index))
	simulator.add_child(body)
	body.transform=rest*body.body_offset
	bodies.append(body)
	if name_suffix=="Hips":
		_hips=body


func start(velocity: Vector3) -> void:
	active=true
	_elapsed=0.0
	_settled=0.0
	simulator.active=true
	for body in bodies:
		body.collision_layer=32
	simulator.physical_bones_start_simulation()
	var tumble := Vector3.UP.cross(velocity).normalized()*5.0
	if tumble.length_squared()<0.1:
		tumble=Vector3.RIGHT*3.0
	for index in bodies.size():
		bodies[index].linear_velocity=velocity.limit_length(28.0)
		bodies[index].angular_velocity=tumble+Vector3.UP*(0.7 if index%2 else -0.7)
	set_physics_process(true)


func follow_position() -> Vector3:
	return _hips.global_position-Vector3.UP*0.45 if active else recovery_position


func _physics_process(delta: float) -> void:
	_elapsed+=delta
	var at := _hips.global_position
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.3,at-Vector3.UP*1.4,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var grounded: bool=not hit.is_empty() and hit.normal.y>0.6 and at.y-hit.position.y<0.9
	_settled=_settled+delta if grounded and _hips.linear_velocity.length()<2.0 else 0.0
	if _elapsed>1.6 and (_settled>0.35 or (_elapsed>6.0 and grounded)):
		recovery_position=Vector3(at.x,float(hit.position.y)+0.025,at.z)
		stop()
		finished.emit(recovery_position)


func set_suspended(value: bool) -> void:
	if not active or suspended==value:
		return
	suspended=value
	if value:
		_paused_velocities.clear()
		for body in bodies:
			_paused_velocities.append(body.linear_velocity)
			_paused_velocities.append(body.angular_velocity)
			PhysicsServer3D.body_set_mode(body.get_rid(),PhysicsServer3D.BODY_MODE_STATIC)
	else:
		for index in bodies.size():
			PhysicsServer3D.body_set_mode(bodies[index].get_rid(),PhysicsServer3D.BODY_MODE_RIGID)
			bodies[index].linear_velocity=_paused_velocities[index*2]
			bodies[index].angular_velocity=_paused_velocities[index*2+1]
	set_physics_process(not value)


func stop() -> void:
	if suspended:
		set_suspended(false)
	simulator.physical_bones_stop_simulation()
	simulator.active=false
	for body in bodies:
		body.collision_layer=0
		body.linear_velocity=Vector3.ZERO
		body.angular_velocity=Vector3.ZERO
	active=false
	set_physics_process(false)
