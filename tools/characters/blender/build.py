"""blender --background --python build.py -- <definition.json> <out_dir>."""
import hashlib
import json
import os
import sys
import traceback
import bpy

# The build scripts are source inputs; do not leave Python bytecode beside them.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_ext.user_default.mpfb.services.exportservice import ExportService
from body import build_body
from outfit import make_piece, delete_hidden_body
from props import arming_sword, round_shield
from export import finish


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    if len(args) != 2:
        raise ValueError("arguments rule: expected <definition.json> <out_dir>")
    with open(args[0], "rb") as stream:
        raw = stream.read()
    definition = json.loads(raw)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    basemesh, rig = build_body(definition)
    hair = next((obj for obj in rig.children_recursive if obj.get("character_slot") == "hair"), None)
    pieces = []
    for spec in definition["outfit"]:
        for side in ("l", "r") if spec.get("sides") else (None,):
            piece = make_piece(basemesh, rig, spec, side)
            if piece is None:
                raise ValueError(f"outfit rule: {spec['name']} ({side}) was cut to an empty mesh")
            pieces.append(piece)
    bpy.ops.object.select_all(action="DESELECT")
    basemesh.select_set(True)
    bpy.context.view_layer.objects.active = basemesh
    ExportService.bake_modifiers_remove_helpers(basemesh, bake_masks=True, bake_subdiv=False, remove_helpers=True)
    if any(piece.get("hides_body", False) for piece in definition["outfit"]):
        delete_hidden_body(basemesh, rig)
    props = []
    for spec in definition["props"]:
        if spec["generator"] == "arming_sword":
            prop = arming_sword(float(spec["length"]))
        elif spec["generator"] == "round_shield":
            prop = round_shield(float(spec["radius"]))
        else:
            raise ValueError(f"prop rule: unknown generator {spec['generator']}")
        prop.name = spec["name"]
        props.append(prop)
    manifest = finish(rig, basemesh, pieces, hair, props, definition, args[1], hashlib.sha256(raw).hexdigest())
    print(f"[characters] built {definition['id']} height_m={manifest['built_height_m']:.3f} triangles={manifest['total_triangles']}", flush=True)


try:
    main()
except Exception:
    traceback.print_exc()
    sys.exit(1)
