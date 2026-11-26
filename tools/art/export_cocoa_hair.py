"""Export the edited Cocoa scene without rebuilding or changing its sculpt.

blender --background art/characters/cocoa_hair_fit.blend \
    --python tools/art/export_cocoa_hair.py
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/characters/models/cocoa_hair_authored.glb"


def export_hair(hair, output=OUTPUT):
    """Bake the current fit keys and root modifiers, exporting only the hair."""
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    bpy.context.view_layer.objects.active = hair
    bpy.context.view_layer.update()
    evaluated = hair.evaluated_get(bpy.context.evaluated_depsgraph_get())
    source = evaluated.data
    # Rebuild clean normals rather than carrying the FBX's hard corner data
    # into the rounded sculpt. The editable source remains untouched.
    mesh = bpy.data.meshes.new("CocoaHair — smooth export")
    mesh.from_pydata([vertex.co.copy() for vertex in source.vertices], [],
                     [tuple(face.vertices) for face in source.polygons])
    for material in source.materials:
        mesh.materials.append(material)
    for face, original in zip(mesh.polygons, source.polygons):
        face.use_smooth = True
        face.material_index = original.material_index
    mesh.update()
    baked = bpy.data.objects.new("CocoaHairMesh", mesh)
    bpy.context.scene.collection.objects.link(baked)
    baked.select_set(True)
    bpy.context.view_layer.objects.active = baked
    counts = {"vertices": len(mesh.vertices), "triangles": sum(len(face.vertices) - 2 for face in mesh.polygons)}
    try:
        bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                                  use_active_scene=True, export_animations=False, export_morph=False)
    finally:
        bpy.data.objects.remove(baked, do_unlink=True)
        bpy.data.meshes.remove(mesh)
        hair.select_set(True)
        bpy.context.view_layer.objects.active = hair
    return counts


if __name__ == "__main__":
    hair = bpy.data.objects.get("CocoaHairSculpt")
    if hair is None:
        raise RuntimeError("Open art/characters/cocoa_hair_fit.blend before exporting")
    print("COCOA_EXPORTED", export_hair(hair))
