"""Author Cocoa on the actual head in Blender; keep an editable fitting scene.

blender --background art/characters/meshy_blank_buddy.blend \
    --python tools/art/author_cocoa_hair.py
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_cocoa_hair import export_hair

ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "assets/characters/models"
ART_FILE = ROOT / "art/characters/cocoa_hair_fit.blend"
OUTPUT = MODEL_DIR / "cocoa_hair_authored.glb"
GUIDES = ROOT / ".godot/validation/cocoa_face_guides.glb"
HEAD_CENTER = Vector((0.0, 0.0, 0.32))
SOURCE_SCALE = 0.88
SOURCE_POSITION = Vector((0.0, -0.015, 0.50))


def smooth(a, b, value):
    value = max(0.0, min(1.0, (value - a) / (b - a)))
    return value * value * (3.0 - 2.0 * value)


def native(point):
    """Head bone coordinates use Y up; the authoring scene uses Blender Z up."""
    return Vector((point.x, -point.z, point.y))


def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.62
    return result


# Read the original reference without altering its mesh, rig, or animation data.
skin = bpy.data.objects["Skin"]
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
head_bind = rig.data.bones["mixamorig:Head"].matrix_local.inverted()
head_vertices = [native(head_bind @ vertex.co) for vertex in skin.data.vertices]
head_faces = [tuple(face.vertices) for face in skin.data.polygons
              if min(head_vertices[i].z for i in face.vertices) > 0.015]
head_bvh = BVHTree.FromPolygons(head_vertices, head_faces, all_triangles=False)

scene = bpy.data.scenes.new("Cocoa — head fitting")
bpy.context.window.scene = scene
reference = bpy.data.collections.new("REFERENCE — actual head and facial guides")
scene.collection.children.link(reference)
hair_collection = bpy.data.collections.new("HAIR — edit the fit and fringe shape keys")
scene.collection.children.link(hair_collection)

head_mesh = bpy.data.meshes.new("OriginalHeadReference")
head_mesh.from_pydata(head_vertices, [], head_faces)
head_mesh.update()
head = bpy.data.objects.new("HeadReference — keep unchanged", head_mesh)
reference.objects.link(head)
head_mesh.materials.append(material("ReferenceSkin", (1.0, 0.50, 0.36, 1.0)))
head.hide_select = True

if GUIDES.exists():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(GUIDES))
    for obj in set(bpy.data.objects) - before:
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        reference.objects.link(obj)
        obj.hide_select = True

before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(MODEL_DIR / "cocoa_hair.fbx"))
imported = list(set(bpy.data.objects) - before)
hair = next(obj for obj in imported if obj.type == "MESH")
world_points = [hair.matrix_world @ vertex.co for vertex in hair.data.vertices]
hair.parent = None
hair.matrix_world.identity()
for collection in list(hair.users_collection):
    collection.objects.unlink(hair)
hair_collection.objects.link(hair)
hair.name = "CocoaHairSculpt"
hair.data.name = "Cocoa — original Meshy topology"
for vertex, point in zip(hair.data.vertices, world_points):
    vertex.co = point * SOURCE_SCALE + SOURCE_POSITION
for face in hair.data.polygons:
    face.use_smooth = True
for edge in hair.data.edges:
    edge.use_edge_sharp = False
if hair.data.has_custom_normals:
    hair.data.normals_split_custom_set([(0.0, 0.0, 0.0)] * len(hair.data.loops))
hair.data.materials.clear()
hair.data.materials.append(material("PlayerHair", (0.25, 0.105, 0.105, 1.0)))

hair.shape_key_add(name="Basis — original locks")
fit = hair.shape_key_add(name="Head fit — roots and hairline")
roots = hair.vertex_groups.new(name="Roots — conform only the base")
fringe_weights = []
for index, (vertex, source) in enumerate(zip(hair.data.vertices, world_points)):
    point = vertex.co.copy()
    radial = point - HEAD_CENTER
    direction = radial.normalized()
    hit, normal, _, _ = head_bvh.ray_cast(HEAD_CENTER, direction, 2.0)
    if hit is None:
        fit.data[index].co = point
        fringe_weights.append(0.0)
        continue
    head_radius = (hit - HEAD_CENTER).length
    distance = radial.length
    frontal = smooth(-0.14, 0.24, -point.y)
    hairline = 0.16 + 0.28 * frontal
    coverage = smooth(hairline - 0.025, hairline + 0.02, point.z)
    # The lower source volume lives inside the head. Only its intended roots
    # emerge as hair; the sculpted crown and outer locks retain their volume.
    if coverage > 0.0:
        fitted_radius = max(distance, head_radius + 0.022)
        point = point.lerp(HEAD_CENTER + direction * fitted_radius, coverage)
    else:
        point = HEAD_CENTER + direction * min(distance, max(0.05, head_radius - 0.025))
    fit.data[index].co = point
    weight = coverage * (1.0 - smooth(0.025, 0.095, distance - head_radius))
    if weight > 0.001:
        roots.add([index], weight, "REPLACE")
    # Keep one center forelock as an editable, independent sculpt adjustment.
    fringe = math.exp(-((source.x - 0.015) / 0.13) ** 2
                      - ((source.y + 0.32) / 0.15) ** 2
                      - ((source.z - 0.06) / 0.17) ** 2)
    fringe_weights.append(fringe)
fit.value = 1.0

fringe = hair.shape_key_add(name="Fringe — preserve the center point")
for index, weight in enumerate(fringe_weights):
    point = fit.data[index].co.copy()
    # The center point sits between the brows; the rest of the fringe stays high.
    point.z -= 0.075 * weight
    point.y -= 0.060 * weight
    fringe.data[index].co = point
fringe.relative_key = fit
fringe.value = 1.0

nape = hair.shape_key_add(name="Nape — soften the lower contour")
for index in range(len(hair.data.vertices)):
    point = fringe.data[index].co.copy()
    weight = smooth(0.08, 0.24, point.y) * (1.0 - smooth(0.22, 0.34, point.z))
    if weight > 0.001:
        contour = 0.175 + 0.035 * min(1.0, abs(point.x) / 0.35)
        contour -= 0.020 * math.exp(-(point.x / 0.11) ** 2)
        point.z += (contour - point.z) * weight
        direction = (point - HEAD_CENTER).normalized()
        hit, normal, _, _ = head_bvh.ray_cast(HEAD_CENTER, direction, 2.0)
        if hit is not None:
            point = point.lerp(hit + direction * 0.020, weight)
    nape.data[index].co = point
nape.relative_key = fringe
nape.value = 1.0

subdivision = hair.modifiers.new("Round the supplied locks", "SUBSURF")
subdivision.subdivision_type = "CATMULL_CLARK"
subdivision.levels = 1
subdivision.render_levels = 1
wrap = hair.modifiers.new("Fit the roots to the actual head", "SHRINKWRAP")
wrap.target = head
wrap.vertex_group = roots.name
wrap.wrap_method = "NEAREST_SURFACEPOINT"
wrap.wrap_mode = "OUTSIDE_SURFACE"
wrap.offset = 0.018

hair["source_fbx"] = "assets/characters/models/cocoa_hair.fbx"
hair["reference"] = "Original character head, in its head-bone coordinate frame"
hair["editing"] = "Edit Head fit and Fringe shape keys; preserve the Basis silhouette."
hair["export"] = "Only this hair mesh; Godot attaches it to mixamorig_Head."

counts = export_hair(hair, OUTPUT)

# Leave the reference scene comfortable to inspect and edit when opened.
scene.world = bpy.data.worlds.new("Hair fitting studio")
scene.world.color = (0.12, 0.10, 0.15)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.color_type = "MATERIAL"
            area.spaces.active.region_3d.view_location = Vector((0, 0, 0.42))
            area.spaces.active.region_3d.view_distance = 1.7
            area.spaces.active.region_3d.view_rotation = Vector((0, 1, -0.12)).to_track_quat("-Z", "Y")
ART_FILE.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ART_FILE))
print("COCOA_AUTHORED " + json.dumps({"blend": str(ART_FILE), "glb": str(OUTPUT),
                                      "source_vertices": len(hair.data.vertices),
                                      "export": counts}))
