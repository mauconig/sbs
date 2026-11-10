from pathlib import Path
import bpy
root = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root / 'art/characters/meshy_blank_buddy.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
for track in rig.animation_data.nla_tracks:
    track.mute = True
for name in ['slide_right','Kick_a_Soccer_Ball','Moving_Kick','Regular_Jump','Forward_Dive','Knockdown']:
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    heights = []
    origins = []
    for frame in range(1, int(action.frame_range[1])+1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        points = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
        hips = rig.matrix_world @ rig.pose.bones['mixamorig:Hips'].head
        height = min(p.z for p in points)
        heights.append(height)
        origins.append(hips)
        if abs(height-0.008)>0.001:
            raise RuntimeError(f'{name} loses baseline contact at frame {frame}: {height}')
    if max((point-origins[0]).xy.length for point in origins)>0.001:
        raise RuntimeError(f'{name} still contains horizontal root travel')
    print('ACTION CONTACT PASS',name,len(heights),'frames, baseline surface height range',min(heights),max(heights),'metres')
