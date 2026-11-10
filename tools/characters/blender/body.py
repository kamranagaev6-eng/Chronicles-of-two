"""Build the MakeHuman core body; Blender and MPFB are build-time dependencies only."""
import bpy
from bpy.types import Object
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.objectservice import ObjectService
from bl_ext.user_default.mpfb.services.targetservice import TargetService


def build_body(definition: dict) -> tuple[Object, Object]:
    info = HumanService._create_default_human_info_dict()
    info["name"] = definition["id"]
    info["phenotype"].update(definition["body"])
    info["rig"] = "game_engine"
    skin = definition["skin"]
    info["skin_mhmat"] = f"{skin}/{skin}.mhmat"
    info["skin_material_type"] = "GAMEENGINE"
    info["eyes_material_type"] = "GAMEENGINE"
    info["clothes_material_type"] = "GAMEENGINE"
    for part in ("eyes", "hair", "eyebrows", "eyelashes"):
        asset = definition[part]
        info[part] = f"{asset}/{asset}.mhclo" if asset else ""
    info["teeth"] = ""
    info["tongue"] = ""
    shoes = definition["shoes"]
    info["clothes"] = [f"{shoes}/{shoes}.mhclo"] if shoes else []
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    basemesh = HumanService.deserialize_from_dict(info, settings)
    rig = ObjectService.find_object_of_type_amongst_nearest_relatives(basemesh, "Skeleton")
    if rig is None:
        raise ValueError("body rule: MPFB did not produce a game_engine skeleton")
    bpy.ops.object.select_all(action="DESELECT")
    basemesh.select_set(True)
    bpy.context.view_layer.objects.active = basemesh
    TargetService.bake_targets(basemesh)
    # Material names are the stable contract with the Godot import script.
    for obj in rig.children_recursive:
        if obj.type != "MESH":
            continue
        slot = "skin" if obj == basemesh else None
        for key, name in (("eyes", "eyes"), ("hair", "hair"), ("eyebrows", "brows"),
                          ("eyelashes", "lashes"), ("shoes", "leather")):
            asset = definition[key]
            if asset and asset in obj.name:
                slot = name
                break
        if slot:
            obj["character_slot"] = slot
            for mat in obj.data.materials:
                mat.name = slot
    return basemesh, rig
