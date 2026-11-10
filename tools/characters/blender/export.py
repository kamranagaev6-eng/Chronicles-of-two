"""Merge to three skinned meshes, normalise height and export the build contract."""
import json
import os
import bmesh
import bpy
from bpy.types import Object
from mathutils import Matrix

REQUIRED = {"Body", "Headgear", "HairFull", "Prop_Sword", "Sig_Oathshield"}


def _join(parts: list[Object], active: Object, name: str) -> Object:
    if not parts:
        raise ValueError(f"required-name rule: no mesh for {name}")
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = active
    if len(parts) > 1:
        bpy.ops.object.join()
    active.name = name
    return active


def finish(rig: Object, basemesh: Object, pieces: list, hair: Object, props: list,
           definition: dict, out_dir: str, definition_sha256: str) -> dict:
    if hair is None:
        raise ValueError("required-name rule: HairFull is absent")
    headgear = [piece for piece in pieces if piece.get("character_layer") == "headgear"]
    body_parts = [obj for obj in rig.children_recursive if obj.type == "MESH" and
                  obj not in headgear and obj != hair and obj not in props]
    body = _join(body_parts, basemesh, "Body")
    helm = _join(headgear, headgear[0] if headgear else None, "Headgear")
    hair.name = "HairFull"
    character_meshes = [body, helm, hair]
    bpy.context.view_layer.update()
    heights = [(obj.matrix_world @ vertex.co).z for obj in character_meshes for vertex in obj.data.vertices]
    source_height = max(heights) - min(heights)
    if source_height <= 0:
        raise ValueError("height rule: character has no positive height")
    scale = float(definition["height_m"]) / source_height
    # Scaling the root scales the rest skeleton, all skins and unbound props together.
    # Props are exported without bone parenting; Godot attaches them after retargeting.
    for prop in props:
        prop.parent = rig
        prop.matrix_parent_inverse = Matrix.Identity(4)
    rig.scale *= scale
    rig.location.z -= min(heights) * scale
    bpy.context.view_layer.update()
    meshes = character_meshes + props
    # Tangents require triangles, including solidified cut boundaries and primitive caps.
    for obj in meshes:
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
        mesh.to_mesh(obj.data)
        mesh.free()
    triangles = {obj.name: sum(len(face.vertices) - 2 for face in obj.data.polygons) for obj in meshes}
    missing = REQUIRED - triangles.keys()
    if missing:
        raise ValueError(f"required-name rule: missing {', '.join(sorted(missing))}")
    total = sum(triangles.values())
    if total > 60000:
        raise ValueError(f"triangle-budget rule: {total} exceeds 60000")
    for name, count in triangles.items():
        if count <= 0:
            raise ValueError(f"required-mesh rule: {name} has no triangles")
    os.makedirs(out_dir, exist_ok=True)
    target = os.path.join(out_dir, definition["id"] + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=target, export_format="GLB", use_selection=True,
                              export_apply=False, export_skins=True, export_animations=False,
                              export_morph=False, export_tangents=True, export_yup=True,
                              export_image_format="AUTO", export_materials="EXPORT")
    built_heights = [(obj.matrix_world @ vertex.co).z for obj in character_meshes for vertex in obj.data.vertices]
    manifest = {
        "id": definition["id"], "definition_sha256": definition_sha256,
        "built_height_m": max(built_heights) - min(built_heights),
        "triangles": triangles, "total_triangles": total,
        "tools": {"blender": ".".join(str(part) for part in bpy.app.version), "mpfb": "2.0.18"},
        "sockets": {prop["name"]: prop["socket"] for prop in definition["props"]},
    }
    with open(os.path.join(out_dir, definition["id"] + ".build.json"), "w", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    return manifest
