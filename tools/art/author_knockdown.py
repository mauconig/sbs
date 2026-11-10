"""Sculpt an impact, back fall, brace and get-up on the supplied Meshy rig."""
from math import radians
import bpy
from mathutils import Quaternion, Vector


def build_knockdown_action(rig, relaxed_basis):
    rig.animation_data.action = None

    def reset():
        for bone in rig.pose.bones:
            bone.matrix_basis = relaxed_basis[bone.name]
        bpy.context.view_layer.update()

    def aim(name, direction):
        bone = rig.pose.bones['mixamorig:' + name]
        matrix = bone.matrix.copy()
        rotation = (bone.tail - bone.head).normalized().rotation_difference(Vector(direction).normalized())
        position = matrix.translation.copy()
        matrix = rotation.to_matrix().to_4x4() @ matrix
        matrix.translation = position
        bone.matrix = matrix
        bpy.context.view_layer.update()

    def pose(lean=0, roll=0, posture='rest'):
        reset()
        hips = rig.pose.bones['mixamorig:Hips']
        position = hips.matrix.translation.copy()
        matrix = (Quaternion((0, 0, 1), radians(roll)) @ Quaternion((1, 0, 0), radians(lean))).to_matrix().to_4x4() @ hips.matrix
        matrix.translation = position
        hips.matrix = matrix
        bpy.context.view_layer.update()
        if posture != 'rest':
            for side, sign in [('Left', 1), ('Right', -1)]:
                if posture == 'impact':
                    aim(side+'Arm', (sign*.8, -.35, .35))
                    aim(side+'ForeArm', (sign*.3, .25, .9))
                elif posture in ['floor', 'side']:
                    aim(side+'Arm', (sign*.9, -.35, .15))
                    aim(side+'ForeArm', (sign*.2, -.65, .65))
                    aim(side+'UpLeg', (sign*.15, .55 if side == 'Left' else .2, .9))
                    aim(side+'Leg', (sign*.1, -.65, .7))
                    aim(side+'Foot', (sign*.1, -.15, .95))
                elif posture == 'crouch':
                    aim(side+'Arm', (sign*.35, -.7, .6))
                    aim(side+'ForeArm', (sign*.12, -.85, .4))
                    aim(side+'UpLeg', (sign*.2, -.5, .7))
                    aim(side+'Leg', (sign*.08, -.9, -.3))
                    aim(side+'Foot', (sign*.05, -.1, .95))
        return {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}

    keys = [
        (0.00, pose()),
        (0.08, pose(-18, -10, 'impact')),
        (0.25, pose(-86, -8, 'floor')),
        (0.34, pose(-91, -5, 'floor')),
        (0.54, pose(-88, -5, 'floor')),
        (0.69, pose(-58, 32, 'side')),
        (0.85, pose(22, 0, 'crouch')),
        (1.00, pose()),
    ]
    action = bpy.data.actions.new('Knockdown')
    rig.animation_data.action = action
    for frame in range(1, 104):
        phase = (frame - 1) / 102
        before, after = next(((a, b) for a, b in zip(keys, keys[1:]) if a[0] <= phase <= b[0]), (keys[-2], keys[-1]))
        weight = (phase - before[0]) / (after[0] - before[0])
        weight = weight * weight * (3 - 2 * weight)
        bpy.context.scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.matrix_basis = before[1][bone.name].lerp(after[1][bone.name], weight)
        bpy.context.view_layer.update()
        for bone in rig.pose.bones:
            bone.keyframe_insert('location', frame=frame, group=bone.name)
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
            bone.keyframe_insert('scale', frame=frame, group=bone.name)
    return action
