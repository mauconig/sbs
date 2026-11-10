"""Combine the supplied Meshy base mesh and its Mixamo animation set.

The source FBXs remain untouched under assets/characters/meshy_blank_buddy.
This script writes a Godot-ready GLB with separate skinned clothing/body parts.
Run with Blender 5.2:
  blender --background --python tools/art/import_meshy_blank_buddy.py
"""

from pathlib import Path
from math import sin, tau
import sys

import bpy
import bmesh
from mathutils import Quaternion, Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from author_motion_actions import build_motion_actions


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets" / "characters" / "meshy_blank_buddy" / (
    "Meshy_AI_Blank_Buddy_20261109_animated_mixamo_without_skin_60fps_Running"
)
MODEL_FBX = SOURCE_DIR / "Meshy_AI_Blank_Buddy_20261109_character_mixamo.fbx"
ANIMATION_DIR = ROOT / "assets" / "characters" / "meshy_blank_buddy" / "extra_animations"
OUTPUT = ROOT / "assets" / "characters" / "models" / "meshy_blank_buddy.glb"


def import_fbx(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    return list(set(bpy.context.scene.objects) - before)


def find_exposed_leg_faces(mesh: bpy.types.Object) -> set[int]:
    """Follow the sculpted inner cuff loops, rather than slicing across the shorts."""
    # The FBX duplicates vertices at flat-shaded faces. Weld only an analysis
    # copy so adjacency is available without changing the original skin weights.
    proxy = bmesh.new()
    proxy.from_mesh(mesh.data)
    source_index = proxy.faces.layers.int.new("original_polygon")
    for face in proxy.faces:
        face[source_index] = face.index
    bmesh.ops.remove_doubles(proxy, verts=list(proxy.verts), dist=0.00001)
    proxy.normal_update()
    lower_faces = {face for face in proxy.faces if 0.20 <= face.calc_center_median().y < 0.46}
    cuff_faces = {
        face for face in lower_faces
        if 0.35 < face.calc_center_median().y < 0.43 and face.normal.y < -0.55
    }
    leg_faces = {face for face in lower_faces if face.calc_center_median().y < 0.35}
    pending = list(leg_faces)
    while pending:
        face = pending.pop()
        for edge in face.edges:
            for neighbor in edge.link_faces:
                if neighbor in lower_faces and neighbor not in cuff_faces and neighbor not in leg_faces:
                    leg_faces.add(neighbor)
                    pending.append(neighbor)
    if not leg_faces or max(face.calc_center_median().y for face in leg_faces) > 0.425:
        raise RuntimeError("Could not isolate the thighs from the sculpted shorts cuffs")

    boundary = {
        edge for face in leg_faces for edge in face.edges
        if any(neighbor in cuff_faces for neighbor in edge.link_faces)
    }
    adjacency = {}
    for edge in boundary:
        a, b = edge.verts
        adjacency.setdefault(a, set()).add(b)
        adjacency.setdefault(b, set()).add(a)
    if not adjacency or any(len(neighbors) != 2 for neighbors in adjacency.values()):
        raise RuntimeError("The shorts/thigh boundary must form closed cuff loops")
    remaining = set(adjacency)
    loops = []
    while remaining:
        start = remaining.pop()
        loop = {start}
        pending_vertices = [start]
        while pending_vertices:
            for neighbor in adjacency[pending_vertices.pop()]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    loop.add(neighbor)
                    pending_vertices.append(neighbor)
        loops.append(loop)
    if len(loops) != 2:
        raise RuntimeError(f"Expected two individual shorts cuffs, found {len(loops)}")
    result = {face[source_index] for face in leg_faces}
    print("SHORTS_HEM", {"loops": len(loops), "seam_vertices": len(adjacency), "leg_faces": len(result)}, flush=True)
    proxy.free()
    return result


def assign_base_character_materials(mesh: bpy.types.Object) -> list[bpy.types.Object]:
    """Cut clean garment seams and separate parts, retaining the original rig."""
    names = ("PlayerSkin", "PlayerShirt", "PlayerShorts", "PlayerLeg", "PlayerSocks", "PlayerBoots")
    materials = []
    for name in names:
        material = bpy.data.materials.new(name)
        material.diffuse_color = (1.0, 1.0, 1.0, 1.0)
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is not None:
            principled.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
            principled.inputs["Roughness"].default_value = 0.62
        materials.append(material)
    mesh.data.materials.clear()
    for material in materials:
        mesh.data.materials.append(material)
    leg_region = names.index("PlayerLeg")
    for polygon_index in find_exposed_leg_faces(mesh):
        mesh.data.polygons[polygon_index].material_index = leg_region

    # Face-centre assignment alone leaves triangle-shaped teeth at every hem.
    # Bisect the actual faces first. BMesh interpolates their deform weights,
    # so adjacent parts retain identical positions throughout every animation.
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    for axis, cuts in ((1, (0.20, 0.31, 0.62, 0.76, 0.98, 1.02)),
                       (0, (-0.44, -0.31, 0.31, 0.44))):
        normal = Vector((0, 0, 0))
        normal[axis] = 1.0
        for position in cuts:
            point = Vector((0, 0, 0))
            point[axis] = position
            bmesh.ops.bisect_plane(
                bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                dist=0.000001, plane_co=point, plane_no=normal,
                clear_inner=False, clear_outer=False,
            )
    bm.normal_update()
    # Export four normalized influences consistently before duplicating seams.
    # Doing this once ensures both copies of a seam animate identically.
    deform_layer = bm.verts.layers.deform.active
    if deform_layer is None:
        raise RuntimeError("The supplied model has no deform weights")
    for vertex in bm.verts:
        weights = vertex[deform_layer]
        influences = sorted(weights.items(), key=lambda item: (-item[1], item[0]))[:4]
        total = sum(weight for _, weight in influences)
        if total <= 0.00001:
            raise RuntimeError("A garment seam lost its deform weights")
        for group in list(weights.keys()):
            del weights[group]
        for group, weight in influences:
            weights[group] = weight / total
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()

    for face in mesh.data.polygons:
        center = face.center
        if center.y < 0.20:
            region = "PlayerBoots"
        elif center.y < 0.31:
            region = "PlayerSocks"
        elif face.material_index == leg_region:
            region = "PlayerLeg"
        elif center.y < 0.62:
            region = "PlayerShorts"
        elif (center.y < 1.02 and abs(center.x) < 0.31) or (
            0.76 < center.y < 0.98 and 0.31 < abs(center.x) < 0.44
        ):
            region = "PlayerShirt"
        else:
            region = "PlayerSkin"
        face.material_index = names.index(region)

    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = list(bpy.context.selected_objects)
    part_names = {"PlayerSkin": "Skin", "PlayerShirt": "Shirt", "PlayerShorts": "Shorts",
                  "PlayerLeg": "Legs", "PlayerSocks": "Socks", "PlayerBoots": "Boots"}
    for part in parts:
        material_index = part.data.polygons[0].material_index
        material = part.data.materials[material_index]
        part.name = part_names[material.name]
        part.data.name = part.name + "Mesh"
        part.data.materials.clear()
        part.data.materials.append(material)
        for face in part.data.polygons:
            face.material_index = 0
        # Stable rest-space UVs deform with the rig: patterns never slide, and
        # the second map restricts dynamic name/number lettering to the back.
        fabric_uv = part.data.uv_layers.new(name="FabricUV")
        print_uv = part.data.uv_layers.new(name="ShirtPrintUV")
        ranges = {"Shirt": (0.62, 1.02, 0.88), "Shorts": (0.36, 0.62, 0.72),
                  "Socks": (0.20, 0.31, 0.34), "Boots": (0.0, 0.20, 0.48)}
        low, high, width = ranges.get(part.name, (0.0, 1.7, 1.44))
        for face in part.data.polygons:
            is_back = part.name == "Shirt" and face.normal.z < -0.25 and abs(face.center.x) < 0.31
            for loop_index in face.loop_indices:
                vertex = part.data.vertices[part.data.loops[loop_index].vertex_index].co
                x = vertex.x
                if part.name in {"Socks", "Boots"}:
                    x -= 0.17 if x > 0 else -0.17
                fabric_uv.data[loop_index].uv = (0.5 + x / width, (vertex.y-low)/(high-low))
                print_uv.data[loop_index].uv = (
                    (0.5 - vertex.x/0.56, (vertex.y-0.64)/0.34) if is_back else (-2.0, -2.0)
                )
        part.data.uv_layers.active_index = 0
        if any(sum(group.weight for group in vertex.groups) < 0.00001 for vertex in part.data.vertices):
            raise RuntimeError(f"The separated {part.name} has vertices without skin weights")
    print("CHARACTER_PARTS", [(part.name, len(part.data.vertices)) for part in parts], flush=True)
    return parts


bpy.ops.wm.read_factory_settings(use_empty=True)
model_objects = import_fbx(MODEL_FBX)
model_armatures = [obj for obj in model_objects if obj.type == "ARMATURE"]
model_meshes = [obj for obj in model_objects if obj.type == "MESH"]
if len(model_armatures) != 1 or not model_meshes:
    raise RuntimeError("Expected one rig and at least one mesh in the character FBX")
model_armature = model_armatures[0]
model_meshes = [part for mesh in model_meshes for part in assign_base_character_materials(mesh)]
model_objects = [obj for obj in model_objects if obj.type != "MESH"] + model_meshes

model_bones = set(model_armature.data.bones.keys())
model_armature.animation_data_create()
animation_names = []
animation_files = sorted(ANIMATION_DIR.glob("*.fbx"))
if not animation_files:
    raise RuntimeError(f"No animation FBXs found in {ANIMATION_DIR}")

# Keep the original neutral pose as a named source clip for runtime idle setup.
rest_action = model_armature.animation_data.action
if rest_action is not None:
    rest_action.name = "rest"
    rest_track = model_armature.animation_data.nla_tracks.new()
    rest_track.name = "rest"
    rest_strip = rest_track.strips.new("rest", 1, rest_action)
    if hasattr(rest_strip, "action_slot"):
        rest_strip.action_slot = model_armature.animation_data.action_slot

for animation_path in animation_files:
    animation_objects = import_fbx(animation_path)
    animation_armatures = [obj for obj in animation_objects if obj.type == "ARMATURE"]
    if len(animation_armatures) != 1:
        raise RuntimeError(f"Expected one animation rig in {animation_path.name}")
    animation_armature = animation_armatures[0]
    action = animation_armature.animation_data.action if animation_armature.animation_data else None
    if action is None:
        raise RuntimeError(f"No animation action found in {animation_path.name}")

    animation_bones = set(animation_armature.data.bones.keys())
    if model_bones != animation_bones:
        raise RuntimeError(
            f"The rig in {animation_path.name} differs from the character: "
            f"missing={sorted(model_bones-animation_bones)}, "
            f"extra={sorted(animation_bones-model_bones)}"
        )

    # FBX imports a duplicate Mixamo rig per clip. Put the action on its own
    # NLA track on the character rig so the glTF exporter writes every clip.
    animation_name = animation_path.stem.split("_60fps_", 1)[-1]
    action.name = animation_name
    model_armature.animation_data.action = action
    source_slot = animation_armature.animation_data.action_slot
    if hasattr(animation_armature.animation_data, "action_slot"):
        model_armature.animation_data.action_slot = source_slot
    track = model_armature.animation_data.nla_tracks.new()
    track.name = animation_name
    strip = track.strips.new(animation_name, 1, action)
    if hasattr(strip, "action_slot"):
        strip.action_slot = source_slot
    for obj in animation_objects:
        if obj != animation_armature:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(animation_armature, do_unlink=True)
    animation_names.append(animation_name)

if "Running" not in animation_names:
    raise RuntimeError("The animation set must include Running")
model_armature.animation_data.action = None

# The supplied slide carries almost two metres of root motion. Controllers
# own travel in Godot: bake this clip in place and correct the actual skinned
# surface against the ground on every source frame, including the get-up.
for track in model_armature.animation_data.nla_tracks:
    track.mute = True
slide = bpy.data.actions["slide_right"]
model_armature.animation_data.action = slide
model_armature.animation_data.action_slot = slide.slots[0]
hips = model_armature.pose.bones["mixamorig:Hips"]
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
origin = hips.matrix.translation.copy()
for frame in range(1, int(slide.frame_range[1]) + 1):
    bpy.context.scene.frame_set(frame)
    matrix = hips.matrix.copy()
    matrix.translation.x = origin.x
    matrix.translation.z = origin.z
    hips.matrix = matrix
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lowest = min(
        (evaluated.matrix_world @ vertex.co).z
        for mesh in model_meshes
        for evaluated in [mesh.evaluated_get(depsgraph)]
        for vertex in evaluated.data.vertices
    )
    correction = model_armature.matrix_world.inverted().to_3x3() @ Vector((0, 0, 0.008-lowest))
    matrix = hips.matrix.copy()
    matrix.translation += correction
    hips.matrix = matrix
    hips.keyframe_insert("location", frame=frame, group=hips.name)
model_armature.animation_data.action = None

# Author a real skeletal idle on the supplied mesh. Keep its bind pose and
# existing action data intact; only this new clip lowers the arms to the sides.
for track in model_armature.animation_data.nla_tracks:
    track.mute = True
idle = bpy.data.actions.new("Idle")
model_armature.animation_data.action = idle
bpy.context.scene.render.fps = 60
for bone in model_armature.pose.bones:
    bone.matrix_basis.identity()
    bone.rotation_mode = "QUATERNION"
bpy.context.view_layer.update()

def aim_bone(name: str, direction: Vector) -> None:
    bone = model_armature.pose.bones[name]
    matrix = bone.matrix.copy()
    rotation = (bone.tail - bone.head).normalized().rotation_difference(direction.normalized())
    matrix = rotation.to_matrix().to_4x4() @ matrix
    matrix.translation = bone.head
    bone.matrix = matrix
    bpy.context.view_layer.update()

for side, sign in [("Left", 1), ("Right", -1)]:
    # In the FBX armature's coordinates +Y is up and +Z is forward.
    aim_bone(f"mixamorig:{side}Arm", Vector((sign * 0.21, -0.975, 0.07)))
    aim_bone(f"mixamorig:{side}ForeArm", Vector((sign * 0.07, -0.98, 0.18)))
    aim_bone(f"mixamorig:{side}Hand", Vector((sign * 0.055, -0.99, 0.12)))
relaxed_basis = {bone.name: bone.matrix_basis.copy() for bone in model_armature.pose.bones}

for frame in range(1, 146, 12):
    phase = tau * (frame - 1) / 144
    bpy.context.scene.frame_set(frame)
    for bone in model_armature.pose.bones:
        bone.matrix_basis = relaxed_basis[bone.name]
    # Small chest breath, a relaxed neck and alternating shoulder motion.
    for name, axis, angle in [
        ("mixamorig:Spine1", (1, 0, 0), 0.012 * sin(phase)),
        ("mixamorig:Spine2", (0, 0, 1), 0.009 * sin(phase)),
        ("mixamorig:Neck", (0, 1, 0), 0.018 * sin(phase)),
        ("mixamorig:LeftArm", (1, 0, 0), 0.015 * sin(phase)),
        ("mixamorig:RightArm", (1, 0, 0), -0.012 * sin(phase)),
    ]:
        bone = model_armature.pose.bones[name]
        bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion(axis, angle)
    for bone in model_armature.pose.bones:
        bone.keyframe_insert("location", frame=frame, group=bone.name)
        bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
        bone.keyframe_insert("scale", frame=frame, group=bone.name)

idle_track = model_armature.animation_data.nla_tracks.new()
idle_track.name = "Idle"
idle_strip = idle_track.strips.new("Idle", 1, idle)
idle_strip.action_slot = model_armature.animation_data.action_slot
model_armature.animation_data.action = None
animation_names.extend(build_motion_actions(model_armature,model_meshes,relaxed_basis))
for track in model_armature.animation_data.nla_tracks:
    track.mute = False
animation_names.append("Idle")

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in model_objects:
    if bpy.data.objects.get(obj.name) is not None:
        obj.select_set(True)
bpy.context.view_layer.objects.active = model_armature
# Save the editable source as well as the game asset.
blend_output = ROOT / "art" / "characters" / "meshy_blank_buddy.blend"
blend_output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(blend_output))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_skins=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_apply=True,
)

print(
    "MESHY_GLTF_EXPORT",
    {
        "output": str(OUTPUT),
        "meshes": [obj.name for obj in model_meshes],
        "armature": model_armature.name,
        "bones": len(model_bones),
        "animations": animation_names,
        "frame_ranges": {
            action.name: tuple(action.frame_range)
            for action in bpy.data.actions
            if action.name in animation_names
        },
    },
    flush=True,
)
