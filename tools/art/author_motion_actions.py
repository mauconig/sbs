"""Author moving kick and forward dive on the existing Meshy skeleton."""
from math import radians
import bpy
from mathutils import Quaternion, Vector
from author_knockdown import build_knockdown_action


def build_motion_actions(rig, meshes, relaxed_basis):
    for track in rig.animation_data.nla_tracks:
        track.mute = True

    def activate(action):
        rig.animation_data.action = action
        if action.slots:
            rig.animation_data.action_slot = action.slots[0]

    def sample(action, frame):
        activate(action)
        bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame))
        bpy.context.view_layer.update()
        return {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}

    def apply_pose(pose):
        for bone in rig.pose.bones:
            bone.matrix_basis = pose[bone.name]
        bpy.context.view_layer.update()

    def key_pose(frame):
        for bone in rig.pose.bones:
            bone.keyframe_insert('location', frame=frame, group=bone.name)
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
            bone.keyframe_insert('scale', frame=frame, group=bone.name)

    def smooth(value):
        value = max(0, min(1, value))
        return value*value*(3-2*value)

    def ground_in_place(action):
        activate(action)
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        hips = rig.pose.bones['mixamorig:Hips']
        origin = hips.matrix.translation.copy()
        for frame in range(1, int(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            matrix = hips.matrix.copy()
            matrix.translation.x = origin.x
            matrix.translation.z = origin.z
            hips.matrix = matrix
            bpy.context.view_layer.update()
            graph = bpy.context.evaluated_depsgraph_get()
            lowest = min((evaluated.matrix_world @ vertex.co).z
                         for mesh in meshes
                         for evaluated in [mesh.evaluated_get(graph)]
                         for vertex in evaluated.data.vertices)
            correction = rig.matrix_world.inverted().to_3x3() @ Vector((0,0,0.008-lowest))
            matrix = hips.matrix.copy()
            matrix.translation += correction
            hips.matrix = matrix
            hips.keyframe_insert('location', frame=frame, group=hips.name)

    run = bpy.data.actions['Running']
    kick = bpy.data.actions['Kick_a_Soccer_Ball']
    # Select the striking leg from actual foot travel, rather than assuming
    # which leg the supplier used.
    reach = {'Left': -100, 'Right': -100}
    peak_frame = {'Left': 1,'Right': 1}
    for frame in range(1, 100, 3):
        sample(kick, float(frame))
        for side in reach:
            forward = rig.pose.bones[f'mixamorig:{side}Foot'].head.z-rig.pose.bones['mixamorig:Hips'].head.z
            if forward > reach[side]:
                reach[side] = forward
                peak_frame[side] = frame
    strike_side = max(reach, key=reach.get)
    moving_samples = []
    for frame in range(1, 62):
        phase = (frame-1)/60
        gait = sample(run, 1.0+(frame-1)%38)
        impact = peak_frame[strike_side]
        source_frame = 1.0+(impact-1)*min(1.0,phase/0.42) if phase<=0.42 else impact+(99-impact)*(phase-0.42)/0.58
        strike = sample(kick, source_frame)
        weight = smooth(phase/0.13)*(1-smooth((phase-0.65)/0.35))
        pose = {}
        for name in gait:
            leg = any(name == f'mixamorig:{strike_side}{part}'
                      for part in ['UpLeg','Leg','Foot','ToeBase','Toe_End'])
            upper = any(part in name for part in ['Spine','Arm','Hand'])
            amount = weight if leg else weight*0.35 if upper else 0
            pose[name] = gait[name].lerp(strike[name], amount)
        moving_samples.append(pose)
    moving = bpy.data.actions.new('Moving_Kick')
    activate(moving)
    for frame, pose in enumerate(moving_samples, 1):
        bpy.context.scene.frame_set(frame)
        apply_pose(pose)
        key_pose(frame)

    # Measure the imported gait contacts used by Godot's shared dribble timing.
    contacts = {}
    for gait_name in ['Running', 'Walking']:
        gait = bpy.data.actions[gait_name]
        activate(gait)
        start, end = map(int, gait.frame_range)
        samples = []
        for frame in range(start, end + 1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            samples.append((rig.pose.bones['mixamorig:LeftToeBase'].head.z, frame))
        contact = max(samples)[1]
        contacts[gait_name] = (contact - start) / max(1, end - start)
    print('DRIBBLE_CONTACT_PHASES', contacts, flush=True)
    # Sculpt the forward dive. Godot supplies the ballistic travel.
    rig.animation_data.action = None
    apply_pose(relaxed_basis)
    hips = rig.pose.bones['mixamorig:Hips']
    matrix = hips.matrix.copy()
    position = matrix.translation.copy()
    matrix = Quaternion((1,0,0),radians(80)).to_matrix().to_4x4() @ matrix
    matrix.translation = position
    hips.matrix = matrix
    bpy.context.view_layer.update()

    def aim(name, direction):
        bone = rig.pose.bones[name]
        position = bone.head.copy()
        rotation = (bone.tail-bone.head).normalized().rotation_difference(Vector(direction).normalized())
        matrix = rotation.to_matrix().to_4x4() @ bone.matrix
        matrix.translation = position
        bone.matrix = matrix
        bpy.context.view_layer.update()

    for side, sign in [('Left',1),('Right',-1)]:
        aim(f'mixamorig:{side}Arm',(sign*0.85,-0.15,0.80))
        aim(f'mixamorig:{side}ForeArm',(sign*0.10,-0.12,1.0))
        aim(f'mixamorig:{side}Hand',(sign*0.08,0.08,1.0))
        aim(f'mixamorig:{side}UpLeg',(sign*0.12,-0.12,-1.0))
        aim(f'mixamorig:{side}Leg',(sign*0.08,-0.30 if side=='Left' else -0.16,-1.0))
        aim(f'mixamorig:{side}Foot',(sign*0.08,-0.45,-0.85))
        # Keep the reaching hands outside the oversized head silhouette.
        rig.pose.bones[f'mixamorig:{side}Arm'].scale.y *= 1.30
        rig.pose.bones[f'mixamorig:{side}ForeArm'].scale.y *= 1.20
        bpy.context.view_layer.update()
    head = rig.pose.bones['mixamorig:Head']
    position = head.head.copy()
    matrix = Quaternion((1,0,0),radians(-22)).to_matrix().to_4x4() @ head.matrix
    matrix.translation = position
    head.matrix = matrix
    bpy.context.view_layer.update()
    dive_pose = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    dive = bpy.data.actions.new('Forward_Dive')
    activate(dive)
    for frame in range(1, 110, 3):
        phase = (frame-1)/108
        weight = smooth(phase/0.17)*(1-smooth((phase-0.63)/0.37))
        bpy.context.scene.frame_set(frame)
        apply_pose({name: relaxed_basis[name].lerp(dive_pose[name],weight) for name in relaxed_basis})
        key_pose(frame)

    # Grounding removes source vertical travel; lift and dive distance belong
    # to the controller in both the visual playground and playable sandbox.
    knockdown = build_knockdown_action(rig, relaxed_basis)
    for action in [kick,bpy.data.actions['Regular_Jump'],moving,dive,knockdown]:
        ground_in_place(action)
    for action in [moving,dive,knockdown]:
        activate(action)
        track = rig.animation_data.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name,1,action)
        strip.action_slot = rig.animation_data.action_slot
    rig.animation_data.action = None
    print('AUTHORED_MOTION',{'clips':[moving.name,dive.name,knockdown.name],'striking_leg':strike_side,'source_impact_frame':peak_frame[strike_side]},flush=True)
    return [moving.name,dive.name,knockdown.name]
