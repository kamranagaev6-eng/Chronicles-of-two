"""Cut original armour from MPFB's already weighted helper surfaces."""
import bmesh
import bpy
from bpy.types import Material, Object
from mathutils import Vector

TORSO_BONES = {"pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"}
MATERIALS = {
    "steel_plate": ((0.55, 0.56, 0.58), 1.0, 0.42),
    "leather": ((0.2, 0.13, 0.08), 0.0, 0.6),
    "cloth": ((0.1, 0.11, 0.14), 0.0, 0.9),
    "wood": ((0.3, 0.2, 0.1), 0.0, 0.8),
    "accent_trim": ((1.0, 1.0, 1.0), 0.0, 0.75),
}


def material(name: str) -> Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        color, metallic, roughness = MATERIALS[name]
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*color, 1.0)
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness
    return mat


def dominant(weights, index_to_bone: dict) -> str | None:
    best, best_weight = None, 0.0
    for index, weight in weights.items():
        name = index_to_bone.get(index)
        if name is not None and weight > best_weight:
            best, best_weight = name, weight
    return best


def _cut_planes(rig: Object, cuts: list, side: str | None) -> list:
    bones = rig.data.bones
    sign = 1.0 if side is None or bones[f"upperarm_{side}"].head_local.x > 0 else -1.0
    planes = []
    for cut in cuts:
        kind = cut[0]
        if kind in ("z_above", "z_below"):
            point = Vector((0, 0, bones[cut[1]].head_local.z + cut[2]))
            planes.append((point, Vector((0, 0, 1 if kind == "z_above" else -1))))
        elif kind in ("along_after", "along_before"):
            bone_name = cut[1] + (f"_{side}" if side else "")
            bone = bones[bone_name]
            axis = (bone.tail_local - bone.head_local).normalized()
            planes.append((bone.head_local.lerp(bone.tail_local, cut[2]),
                           axis if kind == "along_after" else -axis))
        elif kind == "x_inside":
            if side:
                planes.append((Vector((sign * cut[1], 0, 0)), Vector((-sign, 0, 0))))
            else:
                planes.extend([(Vector((cut[1], 0, 0)), Vector((-1, 0, 0))),
                               (Vector((-cut[1], 0, 0)), Vector((1, 0, 0)))])
        elif kind == "x_outside":
            if side is None:
                raise ValueError("outfit cut rule: x_outside needs a side")
            planes.append((Vector((sign * cut[1], 0, 0)), Vector((sign, 0, 0))))
        elif kind == "y_behind":
            planes.append((Vector((0, cut[1], 0)), Vector((0, 1, 0))))
        else:
            raise ValueError(f"outfit cut rule: unknown cut {kind}")
    return planes


def make_piece(basemesh: Object, rig: Object, spec: dict, side: str | None) -> Object | None:
    allowed = spec.get("bones")
    if allowed == "torso":
        allowed = TORSO_BONES
    elif allowed == "torso_and_thighs":
        allowed = TORSO_BONES | {"thigh_l", "thigh_r"}
    elif isinstance(allowed, list):
        allowed = {name + (f"_{side}" if side else "") for name in allowed}
    elif allowed is not None:
        raise ValueError(f"outfit bone rule: unknown selector {allowed}")
    obj = basemesh.copy()
    obj.data = basemesh.data.copy()
    obj.name = spec["name"] + (f"_{side}" if side else "")
    obj["character_layer"] = spec.get("layer", "body")
    for collection in basemesh.users_collection:
        collection.objects.link(obj)
    for modifier in list(obj.modifiers):
        if modifier.type != "ARMATURE":
            obj.modifiers.remove(modifier)
    index_to_bone = {g.index: g.name for g in obj.vertex_groups if g.name in rig.data.bones}
    helper_index = obj.vertex_groups[spec["helper"]].index
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.verts.layers.deform.verify()
    doomed = [v for v in bm.verts if v[layer].get(helper_index, 0.0) <= 0.0 or
              (allowed is not None and dominant(v[layer], index_to_bone) not in allowed)]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    for point, normal in _cut_planes(rig, spec["cuts"], side):
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                              dist=0.0001, plane_co=point, plane_no=normal, clear_inner=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if not bm.faces:
        bm.free()
        bpy.data.objects.remove(obj, do_unlink=True)
        return None
    bm.normal_update()
    for vertex in bm.verts:
        vertex.co += vertex.normal * spec["offset"]
    bm.normal_update()
    uv = bm.loops.layers.uv.verify()
    tile_m = spec.get("tile_m", 0.5)
    if tile_m <= 0:
        raise ValueError("outfit UV rule: tile_m must be positive")
    for face in bm.faces:
        axis = max(range(3), key=lambda index: abs(face.normal[index]))
        a, b = ((1, 2), (0, 2), (0, 1))[axis]
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co[a] / tile_m, loop.vert.co[b] / tile_m)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material(spec["material"]))
    for face in obj.data.polygons:
        face.material_index = 0
        face.use_smooth = True
    if spec["thickness"] > 0:
        modifier = obj.modifiers.new("Thickness", "SOLIDIFY")
        modifier.thickness = spec["thickness"]
        modifier.offset = 1.0
        modifier.use_rim = True
        modifier.use_even_offset = True
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        while obj.modifiers[0].name != modifier.name:
            bpy.ops.object.modifier_move_up(modifier=modifier.name)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def delete_hidden_body(basemesh: Object, rig: Object) -> None:
    keep = {"head", "neck_01"} | {f"hand_{side}" for side in ("l", "r")}
    keep |= {f"{finger}_0{index}_{side}" for finger in ("thumb", "index", "middle", "ring", "pinky")
             for index in (1, 2, 3) for side in ("l", "r")}
    index_to_bone = {g.index: g.name for g in basemesh.vertex_groups if g.name in rig.data.bones}
    height = rig.data.bones["neck_01"].head_local.z - 0.05
    bm = bmesh.new()
    bm.from_mesh(basemesh.data)
    layer = bm.verts.layers.deform.verify()
    doomed = [v for v in bm.verts if v.co.z < height and dominant(v[layer], index_to_bone) not in keep]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(basemesh.data)
    bm.free()
