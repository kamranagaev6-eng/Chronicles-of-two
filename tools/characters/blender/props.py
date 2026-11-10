"""Original parametric weapons, centred on their grip/socket with axes along +Z."""
import bpy
from bpy.types import Object
from outfit import material


def _finish_part(slot: str) -> Object:
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(slot))
    # UVs are supplied by Blender's primitives and survive the join.
    return obj


def _box(size: tuple, position: tuple, slot: str) -> Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=position)
    bpy.context.active_object.scale = size
    return _finish_part(slot)


def _join(parts: list[Object], name: str) -> Object:
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = parts[0]
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def arming_sword(length: float) -> Object:
    parts = [_box((0.05, 0.011, length), (0, 0, 0.12 + length / 2), "steel_plate"),
             _box((0.21, 0.032, 0.026), (0, 0, 0.108), "steel_plate")]
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.017, radius2=0.015, depth=0.2)
    parts.append(_finish_part("leather"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=(0, 0, -0.12))
    bpy.context.active_object.scale = (0.028, 0.028, 0.025)
    parts.append(_finish_part("steel_plate"))
    return _join(parts, "Prop_Sword")


def round_shield(radius: float) -> Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=0.028)
    parts = [_finish_part("wood")]
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=0.018,
                                   major_segments=48, minor_segments=10)
    parts.append(_finish_part("steel_plate"))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1.0, location=(0, 0, 0.012))
    bpy.context.active_object.scale = (0.085, 0.085, 0.05)
    parts.append(_finish_part("steel_plate"))
    for part in parts:
        for face in part.data.polygons:
            face.use_smooth = True
    return _join(parts, "Sig_Oathshield")
