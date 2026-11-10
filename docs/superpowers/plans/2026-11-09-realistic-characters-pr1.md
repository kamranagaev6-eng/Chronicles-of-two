# Realistic Characters (PR 1: character kit and the Vanguard) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scripted build that turns a text definition into an armoured, rigged Vanguard, and a
character kit in the game that animates it from the hero motor's state in place of the placeholder.

**Architecture:** Blender with MPFB, run with no window, builds a GLB and a manifest from
`art/characters/vanguard.json`. A Godot tool script writes the retarget import settings and a
post-import script finishes the scene. In the game, `CharacterKit` hands `HeroVisual` a `CharacterRig`;
each frame the rig asks the pure `HeroAnimDriver` for an `AnimPose` and its `CharacterAnimator` shows it
with a hand-advanced `AnimationTree`. Which clip plays, and where its hit frame sits, is a data table.

**Tech Stack:** Godot 4.7.2 (Forward+, D3D12), typed GDScript, GUT 9.7.1, PowerShell 7; Blender 5.2.3 LTS
with MPFB 2.0.18 at build time only.

**Spec:** `docs/superpowers/specs/2026-11-09-realistic-characters-design.md`. Read "Findings from the
test this design depends on" first. This plan covers the first of its three pull requests.

**Execution evidence (Codex, 9 Nov):** Task 1 tools verified without downloads; licence audit
12/12 passed. Baseline full GUT: 323 existing tests passed (plus the two new manifest tests red
before the build). Baseline arena screenshot: `tools/out/characters_pr1/arena_before.png`.
Baseline soak: host and guest exit 0, guest corrections 0; runner exit 1 for 143 pre-existing
typed-array errors in `arena.gd:_trigger_banter`. Logs:
`tools/out/runtime/83074981e50249e2a3a9ad233eda7432/` and
`tools/out/soak/runtime-7b099b49/`. Keep this existing narrative failure separate from character work.
Task 2 build exits 0: 40,428 triangles, 1.800 m. Both manifest tests pass (9 assertions);
Tasks 1 and 2 passed independent specification and code-quality reviews. Task 3 subsequently
registered the generated files. The latest combined workspace passed 374/374 GUT tests, scene
smoke, data validation and the licence ledger (`tools/out/characters_pr1/current_shared_suite.log`).
The latest quiet 3440×1440 Vanguard cost run added 1.479 ms, with little margin; a concurrent
run reported 1.523 ms and was marked invalid (`claude_task10/confirm.summary.txt`). The latest
60-second soak had both processes exit 0, but the runner failed on the existing arena banter error
and logged 14 guest corrections, versus zero in the initial baseline
(`tools/out/characters_pr1/current_shared_soak.log`). Human visual review and a clean soak remain
outstanding. Nothing committed.

**Prior art to port from:** `tools/out/character_test/` (ignored by git, present on this PC) holds the
pipeline test's working code. Every mechanism below was run there on 9 Nov:

| File | Proves |
| --- | --- |
| `scripts/build_human.py` | MPFB with no window; pieces cut from helper surfaces; merge; GLB export |
| `scripts/install_packs.py` | Installing an asset pack into MPFB |
| `godot/make_imports.gd`, `post_import.gd`, `probe_import.gd` | Bone maps and `.import` written by script; Basis Universal textures; external materials; post-import script; bone-parented props, all in a headless import |
| `godot/char_fix.gd` | Material fixes and the sword and shield socket placement |
| `godot/probe_tree.gd`, `probe_tree2.gd` | `AnimationTree` advanced by hand: exact `TimeSeek`, upper-body filter, blend space, reversed playback |
| `godot/measure_clips.gd` | The contact and speed numbers in Task 4 |
| `scripts/hall_shot.gd` | Building the Drowned Hall outside the arena and measuring frame cost |

## Global Constraints

- Godot **4.7.2** APIs only; static typing everywhere (`var x: int`, typed arrays and returns).
- **Presentation only.** No change to simulation, gameplay data, the network format or saves, and no new
  replicated state. Nothing here may touch `game/character/hero_motor.gd` or any `game/net` file.
- **No rig without a window.** `CharacterKit.enabled` defaults to false when the display server is
  `headless`; bots, the soak and GUT keep the placeholders unless a test sets it.
- **At most three skinned meshes per character** (`Body`, `Headgear`, `HairFull`), every mesh
  `GI_MODE_DISABLED`. The Vanguard has at most **60,000** triangles, weapons included.
- **Frame budget:** two heroes and ten enemies add at most **1.5 ms** on High at 3440×1440 on the owner's
  PC. Until all five characters exist, the cost sheet fills the twelve places with the ones that do.
- **Import settings** of character and clip GLBs are written only by
  `tools/characters/godot/write_imports.gd`, never by hand. No other `.import` file is edited.
- **Assets:** CC0 plus our own work. Every file under `/assets` gets a ledger row whose licence is `CC0`
  or `Original work` (the licence gate accepts nothing else).
- New CSVs use the **Keep File** importer: a sidecar of exactly `[remap]`, a blank line, `importer="keep"`.
- The model faces **+Z**. The simulation runs at **60** ticks a second. Godot drops a trailing `_Loop`
  from clip names on import (`Idle_Loop` is `Idle`).
- Tool scripts run with `-s` are compiled before the autoloads exist: they must not name `GameData`,
  `Settings` or any game class. Anything that needs those runs as a scene.
- **Shared files** (`game/presentation/hero_visual.gd`, `game/data/game_data.gd`, `AGENTS.md`,
  `README.md`, `docs/license_ledger.csv`, `docs/software_licenses.csv`, `OPUS_HANDOFF.md`): re-read
  the file immediately before editing, make small targeted `Edit` calls, never whole-file writes.
  `hero_visual.gd` is edited only after "Chronicle of Two master plan" agrees in `OPUS_HANDOFF.md` or
  the owner says to go ahead.
- **Git:** the checkout is shared and full of other sessions' uncommitted work. Do not commit unless the
  owner asks. If they do, use branch `characters/kit-vanguard` and stage only this plan's files. Each
  task ends with a checkpoint instead.
- **Test command:** `pwsh ./tools/run_tests.ps1 -Filter <script_name>` runs the import and the matching
  GUT scripts. Pass means a GUT summary with 0 failures and exit code 0.

## Review Focus

1. **A roster row whose model is missing or broken** (not built yet, or a Git LFS pointer instead of the
   file on the second PC): `hero_rig()` returns `null` with one warning and the placeholder is used.
   Test in Task 8.
2. **A hand-edited clip table:** an ability with no row, or a row naming a clip that does not exist.
   `ability_row()` falls back and never returns `null`; the animator keeps the previous pose and warns
   once instead of dropping to the rest pose. Tests in Tasks 4 and 7.
3. **Time that runs backwards or jumps** after a rollback: `action_tick` ahead of `tick`, or
   `tick_factor` outside 0 to 1. Elapsed time is clamped; the pose stays valid. Tests in Tasks 4 and 6.
4. **Two rigs of the same character at once** (both players pick the Vanguard): colour, action clip and
   headgear stay independent. Tests in Tasks 7 and 8.
5. **Absurd speeds** (a teleport frame, a knockback): the walk-cycle rate stays within its clamp and
   nothing becomes non-finite. Test in Task 7.

---

### Task 1: Character build tools

**Files:**
- Create: `tools/blender_path.ps1`, `tools/fetch_character_tools.ps1`, `tools/characters/blender/install_packs.py`
- Modify: `docs/software_licenses.csv` (two rows)

**Interfaces:**
- Produces: dot-sourcing `tools/blender_path.ps1` sets `$Blender` (the `blender.exe` path) and
  `$RepoRoot`; it throws when Blender is absent. `.engine/blender/blender-5.2.3-windows-x64/` holds a
  portable Blender with MPFB 2.0.18 and the MakeHuman system assets installed.

Pinned files, kept in `.engine/blender/downloads/` (all three are already there from the test):

| File | URL | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `blender-5.2.3-windows-x64.zip` | `https://download.blender.org/release/Blender5.2/blender-5.2.3-windows-x64.zip` | 405839452 | `723f08a4401502561eb763cdeacf8745b31e5f3f154d287d3830d97cf75dc2fb` |
| `add-on-mpfb-v2.0.18.zip` | `https://extensions.blender.org/download/sha256:c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad/add-on-mpfb-v2.0.18.zip` | 45956992 | `c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad` |
| `makehuman_system_assets_cc0.zip` | `https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip` | 280737770 | `b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107` |

- [x] **Step 1: Write `tools/blender_path.ps1`**, mirroring `tools/godot_path.ps1`: `$env:BLENDER` if
  it exists, else `.engine/blender/blender-5.2.3-windows-x64/blender.exe`, else throw
  `"Blender 5.2.3 not found. Run ./tools/fetch_character_tools.ps1."`.
- [x] **Step 2: Write `tools/fetch_character_tools.ps1`** (`#requires -Version 7.0`, parameter
  `[switch]$Confirmed`).
  - For each pinned file: present with a matching SHA-256 prints `verified <name>`. Missing or
    mismatched without `-Confirmed` prints the batch (name, URL, size) and exits 2 with
    `"Ask the owner to confirm this download batch, then run again with -Confirmed."`. With
    `-Confirmed` it downloads, checks the hash and fails on a mismatch.
  - Unzips Blender when `blender.exe` is absent and creates the empty folder `portable` beside it (this
    keeps Blender's settings and add-ons on D:).
  - Installs MPFB when `portable/extensions/user_default/mpfb` is absent:
    `& $Blender --command extension install-file -r user_default -e <zip>`.
  - Installs the pack when `portable/extensions/.user/user_default/mpfb/data/packs/makehuman_system_assets.json`
    is absent: `& $Blender --background --python tools/characters/blender/install_packs.py -- <zip>`.
  - Ends with `character tools ready: Blender 5.2.3, MPFB 2.0.18, makehuman_system_assets`.
- [x] **Step 3: Write `install_packs.py`** as a copy of `tools/out/character_test/scripts/install_packs.py`
  without its asset listing: it calls `AssetService.fix_and_extract_asset_pack_zip(zip, LocationService.get_user_data())`
  and exits non-zero on an error string.
- [x] **Step 4: Run it.** Run: `pwsh ./tools/fetch_character_tools.ps1`. Expected: three `verified`
  lines, the `character tools ready` line, exit code 0, and nothing downloaded.
- [x] **Step 5: Add the software rows** to `docs/software_licenses.csv`: `Blender`, version `5.2.3 LTS`,
  and `MPFB`, version `2.0.18`, each with location `.engine/blender/ (not committed)`. Take Blender's
  licence from `.engine/blender/blender-5.2.3-windows-x64/copyright.txt` and MPFB's from its
  `blender_manifest.toml` (`GPL-3.0-or-later`); note that MPFB's assets are CC0 and that neither tool
  ships with the game.
- [x] **Step 6: Check the ledger gate.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_license_audit`.
  Expected: PASS.
- [x] **Step 7: Checkpoint.** `git status --porcelain` shows the three new files and
  `docs/software_licenses.csv` modified (plus other sessions' changes, untouched).

---

### Task 2: The Vanguard's definition and Blender build

**Files:**
- Create: `art/.gdignore` (empty), `art/characters/vanguard.json`
- Create: `tools/characters/blender/build.py`, `body.py`, `outfit.py`, `props.py`, `export.py`
- Create: `tools/build_characters.ps1` (the Blender half; Task 3 adds the Godot half)
- Create (output): `assets/characters/vanguard/vanguard.glb`, `assets/characters/vanguard/vanguard.build.json`
- Test: `tests/unit/test_character_kit.gd`

**Interfaces:**
- Consumes: `$Blender` from Task 1.
- Produces: the GLB with nodes named exactly `Body`, `Headgear`, `HairFull` (skinned meshes), `Prop_Sword`
  and `Sig_Oathshield` (plain meshes, children of the armature, not parented to bones); material slots
  named `skin`, `eyes`, `hair`, `brows`, `lashes`, `steel_plate`, `leather`, `cloth`, `wood`,
  `accent_trim`; and the manifest:

```json
{"id": "vanguard", "definition_sha256": "<hex>", "built_height_m": 1.8,
 "triangles": {"Body": 0, "Headgear": 0, "HairFull": 0, "Prop_Sword": 0, "Sig_Oathshield": 0},
 "total_triangles": 0, "tools": {"blender": "5.2.3", "mpfb": "2.0.18"},
 "sockets": {"Prop_Sword": "right_hand_grip", "Sig_Oathshield": "left_forearm"}}
```

- [x] **Step 1: Write the failing manifest tests** in `tests/unit/test_character_kit.gd` (`extends GutTest`):

```gdscript
const DEFINITION := "res://art/characters/vanguard.json"
const MANIFEST := "res://assets/characters/vanguard/vanguard.build.json"


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary


func test_manifest_matches_its_definition() -> void:
	assert_eq(_manifest()["definition_sha256"], FileAccess.get_sha256(DEFINITION), "rebuild the Vanguard")


func test_manifest_is_within_budget() -> void:
	var m := _manifest()
	assert_lte(int(m["total_triangles"]), 60000)
	assert_almost_eq(float(m["built_height_m"]), 1.8, 0.01)
	for part: String in ["Body", "Headgear", "HairFull", "Prop_Sword", "Sig_Oathshield"]:
		assert_gt(int((m["triangles"] as Dictionary).get(part, 0)), 0, part)
	assert_eq((m["sockets"] as Dictionary)["Sig_Oathshield"], "left_forearm")
```

- [x] **Step 2: Run them and confirm they fail.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_kit`.
  Expected: FAIL (the manifest does not exist).
- [x] **Step 3: Write `art/characters/vanguard.json`** with these values:

```json
{
  "id": "vanguard",
  "height_m": 1.8,
  "body": {"gender": 1.0, "age": 0.6, "muscle": 0.85, "weight": 0.56, "proportions": 0.72, "height": 0.55,
           "race": {"asian": 0.0, "caucasian": 1.0, "african": 0.0}},
  "skin": "middleage_caucasian_male",
  "hair": "short02", "eyes": "low-poly", "eyebrows": "eyebrow001", "eyelashes": "eyelashes01",
  "shoes": "shoes04",
  "outfit": [
    {"name": "gambeson", "helper": "helper-tights", "bones": null, "cuts": [],
     "offset": 0.002, "thickness": 0.0, "material": "cloth", "tile_m": 0.25, "hides_body": true},
    {"name": "cuirass", "helper": "helper-tights", "bones": "torso",
     "cuts": [["z_above", "spine_01", 0.02], ["z_below", "neck_01", -0.035]],
     "offset": 0.016, "thickness": 0.006, "material": "steel_plate"},
    {"name": "belt", "helper": "helper-tights", "bones": "torso_and_thighs",
     "cuts": [["z_above", "spine_01", -0.055], ["z_below", "spine_01", 0.03]],
     "offset": 0.026, "thickness": 0.007, "material": "leather", "tile_m": 0.3},
    {"name": "kilt", "helper": "helper-skirt", "bones": null,
     "cuts": [["z_above", "calf_l", 0.16], ["z_below", "spine_01", -0.02]],
     "offset": 0.006, "thickness": 0.004, "material": "leather", "tile_m": 0.4},
    {"name": "tabard_back", "helper": "helper-tights", "bones": "torso",
     "cuts": [["y_behind", 0.0], ["x_inside", 0.12], ["z_above", "spine_01", 0.0], ["z_below", "spine_03", 0.0]],
     "offset": 0.024, "thickness": 0.003, "material": "accent_trim"},
    {"name": "pauldron", "sides": true, "helper": "helper-tights", "bones": ["clavicle", "upperarm"],
     "cuts": [["along_before", "upperarm", 0.5], ["x_outside", 0.085]],
     "offset": 0.03, "thickness": 0.006, "material": "steel_plate"},
    {"name": "bracer", "sides": true, "helper": "helper-tights", "bones": ["lowerarm"],
     "cuts": [["along_after", "lowerarm", 0.14], ["along_before", "lowerarm", 0.9]],
     "offset": 0.011, "thickness": 0.005, "material": "steel_plate"},
    {"name": "greave", "sides": true, "helper": "helper-tights", "bones": ["calf"],
     "cuts": [["along_after", "calf", 0.07], ["along_before", "calf", 0.86]],
     "offset": 0.012, "thickness": 0.005, "material": "steel_plate"},
    {"name": "helm", "layer": "headgear", "helper": "helper-hair", "bones": null, "cuts": [],
     "offset": 0.012, "thickness": 0.004, "material": "steel_plate"},
    {"name": "crest", "layer": "headgear", "helper": "helper-hair", "bones": null, "cuts": [["x_inside", 0.012]],
     "offset": 0.028, "thickness": 0.006, "material": "accent_trim"}
  ],
  "props": [
    {"name": "Prop_Sword", "generator": "arming_sword", "socket": "right_hand_grip", "length": 0.9},
    {"name": "Sig_Oathshield", "generator": "round_shield", "socket": "left_forearm", "radius": 0.37}
  ]
}
```

- [x] **Step 4: Write the Blender modules**, porting from `tools/out/character_test/scripts/build_human.py`.
  Import MPFB as `bl_ext.user_default.mpfb.services.*`. Blender space is Z up with the body facing -Y.
  - `body.py`: `build_body(definition: dict) -> tuple[Object, Object]` returns `(basemesh, rig)`. It
    fills `HumanService._create_default_human_info_dict()` from the definition (rig `game_engine`; skin,
    eyes and clothes material type `GAMEENGINE`; no teeth and no tongue; the `shoes` asset as the only
    MakeHuman clothing), calls `HumanService.deserialize_from_dict()` with `subdiv_levels` 0, then
    `TargetService.bake_targets(basemesh)`.
  - `outfit.py`: `make_piece(basemesh: Object, rig: Object, spec: dict, side: str | None) -> Object | None`
    and `delete_hidden_body(basemesh: Object, rig: Object) -> None`. `make_piece` is the test's function
    driven by a spec: copy the base mesh, keep vertices in the `helper` group whose strongest bone
    weight is in `bones`, apply the cuts with `bmesh.ops.bisect_plane`, push along normals by `offset`,
    box-map UVs at `tile_m` metres a tile (default 0.5), solidify by `thickness`. Rules:
    - `bones`: `null` keeps all; `"torso"` is `pelvis`, `spine_01`..`spine_03`, `neck_01`, both
      clavicles; `"torso_and_thighs"` adds both thighs; a list names bones, and with `"sides": true`
      the piece is built twice with `_l` and `_r` added to each bone and to the piece name.
    - Cuts keep one side of a plane: `z_above`/`z_below [bone, dz]` at the bone's head height plus `dz`;
      `along_after`/`along_before [bone, t]` at fraction `t` along the bone, across its axis;
      `x_outside`/`x_inside [x]` on the distance from the centre line (on the piece's own side when it
      has one); `y_behind [y]` keeps the back.
    - `delete_hidden_body` runs after `ExportService.bake_modifiers_remove_helpers(basemesh, bake_masks=True, bake_subdiv=False, remove_helpers=True)`
      when any piece has `hides_body`: it deletes body vertices lower than `neck_01` minus 0.05 m whose
      strongest bone is not the head, the neck, a hand or a finger.
  - `props.py`: `arming_sword(length: float) -> Object` and `round_shield(radius: float) -> Object`.
    Each returns one mesh at the origin, long axis or disc normal along +Z, in the sizes
    `char_fix.gd` uses (blade 0.05 × 0.011 m, guard 0.21 m, grip 0.2 m; disc 0.028 m thick, rim torus,
    boss radius 0.085 m), with slots `steel_plate`, `leather` and `wood`.
  - `export.py`: `finish(rig: Object, basemesh: Object, pieces: list, hair: Object, props: list, definition: dict, out_dir: str, definition_sha256: str) -> dict`.
    It joins the base mesh, the eyes, brows, lashes, shoes and every piece without a `layer` into `Body`;
    joins `headgear` pieces into `Headgear`; renames the hair `HairFull`; renames MPFB's material slots
    to `skin`, `eyes`, `hair`, `brows`, `lashes` and the shoes' slot to `leather`; scales everything so
    the height is `height_m`; exports `<out_dir>/<id>.glb` (`export_skins=True`, no animations, no shape
    keys, tangents on) and writes and returns the manifest.
  - `build.py`: `blender --background --python build.py -- <definition.json> <out_dir>`. It exits
    non-zero, naming the rule, when the total exceeds 60,000 triangles or a required name is missing.
- [x] **Step 5: Write `tools/build_characters.ps1`** (`#requires -Version 7.0`; parameters `[string]$Id`,
  `[switch]$All`, `[switch]$LedgerOnly`). For each id it runs the Blender build into
  `assets/characters/<id>/` and stops on a non-zero exit. (`-LedgerOnly` and the Godot steps come in
  Task 3.)
- [x] **Step 6: Build.** Run: `pwsh ./tools/build_characters.ps1 -Id vanguard`. Expected: exit code 0,
  the GLB and the manifest exist, and the build takes a few seconds.
- [x] **Step 7: Run the tests and confirm they pass.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_kit`.
  Expected: PASS, 2 tests.
- [x] **Step 8: Checkpoint.** New: `art/`, `tools/characters/blender/`, `tools/build_characters.ps1`,
  `assets/characters/vanguard/` and the test.

---

### Task 3: Import settings, materials and the clip files

**Files:**
- Create: `tools/characters/godot/write_imports.gd`
- Create: `game/characters/import/character_post_import.gd`, `game/characters/import/mpfb_bone_map.tres`,
  `game/characters/import/quaternius_bone_map.tres` (both written by `write_imports.gd` when absent)
- Create: `game/characters/materials/steel_plate.tres`, `leather.tres`, `cloth.tres`, `wood.tres`, `accent_trim.tres`
- Create (assets): `assets/animations/quaternius/UAL1_Standard.glb`, `UAL2_Standard.glb`, copied unchanged from
  `tools/out/character_test/ual1/…/Unreal-Godot/` and `…/ual2/…/Unreal-Godot/`; every `.import` sidecar
- Modify: `tools/build_characters.ps1` (the Godot steps and `-LedgerOnly`), `docs/license_ledger.csv`,
  `AGENTS.md` (the exception)
- Test: `tests/unit/test_character_kit.gd` (add cases)

**Interfaces:**
- Consumes: the GLB and manifest from Task 2.
- Produces: `load("res://assets/characters/vanguard/vanguard.glb")` is a `PackedScene` whose skeleton is
  `%GeneralSkeleton` with Godot's humanoid bone names and a T-pose rest; `Prop_Sword` and
  `Sig_Oathshield` sit under `BoneAttachment3D` nodes; the scene root has metadata `built_height_m`.
  `load("res://assets/animations/quaternius/UAL1_Standard.glb")` and `UAL2_Standard.glb` are
  `AnimationLibrary` resources with tracks on `%GeneralSkeleton`.

- [ ] **Step 1: Write the failing scene tests** (add to `test_character_kit.gd`):

```gdscript
const VANGUARD := "res://assets/characters/vanguard/vanguard.glb"


func _scene() -> Node3D:
	var scene: Node3D = (load(VANGUARD) as PackedScene).instantiate()
	add_child_autofree(scene)
	return scene


func test_skeleton_is_retargeted_to_a_t_pose() -> void:
	var sk := _scene().get_node("%GeneralSkeleton") as Skeleton3D
	assert_eq(sk.get_bone_count(), 53)
	for bone: String in ["Root", "Hips", "Spine", "UpperChest", "Head", "LeftUpperArm", "RightHand", "LeftToes"]:
		assert_ne(sk.find_bone(bone), -1, bone)
	var arm := sk.get_bone_global_rest(sk.find_bone("LeftLowerArm")).origin - sk.get_bone_global_rest(sk.find_bone("LeftUpperArm")).origin
	assert_lt(absf(arm.normalized().y), 0.15, "upper arm is level in the rest pose")
	var toes := sk.get_bone_global_rest(sk.find_bone("LeftToes")).origin
	assert_gt(toes.z, sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin.z, "faces +Z")


func test_meshes_follow_the_rules() -> void:
	var scene := _scene()
	var skinned: PackedStringArray = []
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		assert_eq(mi.gi_mode, GeometryInstance3D.GI_MODE_DISABLED, mi.name)
		if mi.skin != null:
			skinned.append(mi.name)
	skinned.sort()
	assert_eq(skinned, PackedStringArray(["Body", "HairFull", "Headgear"]))
	assert_almost_eq(float(scene.get_meta("built_height_m")), 1.8, 0.01)


func test_textures_are_compressed_with_mipmaps() -> void:
	var body := _scene().find_child("Body", true, false) as MeshInstance3D
	var checked := 0
	for s in body.mesh.get_surface_count():
		var mat := body.mesh.surface_get_material(s) as BaseMaterial3D
		if mat != null and mat.albedo_texture is PortableCompressedTexture2D:
			var img := mat.albedo_texture.get_image()
			assert_true(img.is_compressed() and img.has_mipmaps(), mat.resource_name)
			checked += 1
	assert_gt(checked, 0)


func test_outfit_and_skin_materials() -> void:
	var by_name := {}
	for n: Node in _scene().find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			by_name[mat.resource_name] = mat
	for slot: String in ["skin", "eyes", "hair", "brows", "lashes", "steel_plate", "leather", "cloth", "wood", "accent_trim"]:
		assert_has(by_name, slot)
	assert_eq((by_name["steel_plate"] as Material).resource_path, "res://game/characters/materials/steel_plate.tres")
	var skin := by_name["skin"] as BaseMaterial3D
	assert_eq(skin.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_true(skin.subsurf_scatter_enabled)
	assert_eq((by_name["hair"] as BaseMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)


func test_props_sit_on_their_bones() -> void:
	var scene := _scene()
	for pair: Array in [["Prop_Sword", "RightHand"], ["Sig_Oathshield", "LeftLowerArm"]]:
		var socket := scene.find_child(pair[0], true, false).get_parent() as BoneAttachment3D
		assert_not_null(socket, pair[0])
		assert_eq(socket.bone_name, pair[1])
```

- [ ] **Step 2: Run them and confirm they fail.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_kit`.
  Expected: the new tests FAIL (no skeleton named `GeneralSkeleton`, no socket).
- [ ] **Step 3: Write the five materials** as `StandardMaterial3D` `.tres` files with `resource_name`
  equal to the file name, `texture_filter` linear-mipmap-anisotropic, and `ext_resource` textures from
  `res://assets/textures/ambientcg/<Set>/<Set>_1K-JPG_<Map>.jpg` (Color, NormalGL, Roughness, and
  Metalness for metal; roughness and metallic read the red channel):

| File | Set | `albedo_color` | Notes |
| --- | --- | --- | --- |
| `steel_plate.tres` | `Metal021` | `Color(0.9, 0.92, 0.96)` | `metallic = 1.0` |
| `leather.tres` | `Leather030` | `Color(0.62, 0.5, 0.42)` | |
| `cloth.tres` | `Fabric086` | `Color(0.3, 0.32, 0.4)` | `cull_mode` disabled |
| `wood.tres` | `Planks037A` | `Color(0.8, 0.74, 0.68)` | |
| `accent_trim.tres` | `Fabric086` | `Color.WHITE` | The rig tints a copy per character |

- [ ] **Step 4: Write `character_post_import.gd`** (`@tool`, `extends EditorScenePostImport`,
  `func _post_import(scene: Node) -> Object`). It names no autoload and no game class. It:
  - reads the manifest beside `get_source_file()` and sets `scene.set_meta("built_height_m", …)`
  - sets every `GeometryInstance3D` to `GI_MODE_DISABLED`
  - sets materials by `resource_name`: `skin` opaque with subsurface scattering on (strength 0.3, skin
    mode), roughness 0.58, `normal_scale` 0.6; `hair`, `brows` and `lashes` alpha-scissor at 0.35 with
    alpha-to-coverage, cull disabled, roughness 0.55; `eyes` opaque, roughness 0.15
  - moves each prop in the manifest's `sockets` under a new `BoneAttachment3D` (owner set to the scene),
    placed from the rest pose exactly as `add_weapons` in `char_fix.gd` does: `right_hand_grip` on
    `RightHand`, blade toward +Z, flat level with the palm; `left_forearm` on `LeftLowerArm`, disc
    normal up, 60% of the way to the wrist and 0.075 m above the bone
  - calls `push_error` and returns `null` when there is no `GeneralSkeleton`, more than three skinned
    meshes, or a prop named in `sockets` is missing.
- [ ] **Step 5: Write `write_imports.gd`** (`extends SceneTree`), porting `make_imports.gd`. For every
  `res://assets/characters/*/*.glb` and `res://assets/animations/quaternius/*.glb` it loads the existing
  `.import` if there is one (so the `uid` survives), sets the keys below and saves:
  - Both: `_subresources.nodes["PATH:<skeleton path>"]["retarget/bone_map"]` (the bone map resource; the
    skeleton path is found by opening the GLB with `GLTFDocument`).
  - Characters: `importer = "scene"`; on the skeleton `retarget/rest_fixer/fix_silhouette/enable = true`;
    `gltf/embedded_image_handling = 2`; `animation/import = false`;
    `import_script/path = "res://game/characters/import/character_post_import.gd"`; and for each
    material slot with a file in `game/characters/materials/`,
    `_subresources.materials[<slot>] = {"use_external/enabled": true, "use_external/path": "<that file>"}`.
  - Clips: `importer = "animation_library"`; on the skeleton `retarget/remove_tracks/unmapped_bones = true`.
  - Bone maps are created when absent with `SkeletonProfileHumanoid`, mapping by lower-cased bone name:
    `Root: root`, `Hips: pelvis`, `Spine: spine_01`, `Chest: spine_02`, `UpperChest: spine_03`,
    `Neck: neck_01`, `Head: head`, and per side (`_l`, `_r`) `Shoulder: clavicle`, `UpperArm: upperarm`,
    `LowerArm: lowerarm`, `Hand: hand`, `ThumbMetacarpal/Proximal/Distal: thumb_01/02/03`,
    `Index|Middle|Ring Proximal/Intermediate/Distal: index|middle|ring_01/02/03`,
    `Little…: pinky_01/02/03`, `UpperLeg: thigh`, `LowerLeg: calf`, `Foot: foot`, `Toes: ball`.
    `LeftEye`, `RightEye` and `Jaw` stay unmapped.
- [ ] **Step 6: Extend `tools/build_characters.ps1`.** After the Blender builds:
  `& $Godot --headless --path $RepoRoot -s res://tools/characters/godot/write_imports.gd`, then
  `& $Godot --headless --path $RepoRoot --import`, failing on a non-zero exit or an `ERROR` line that
  names `assets/characters` or `assets/animations`. `-LedgerOnly` skips the builds and rewrites the
  ledger rows whose `asset_id` starts with `chr_` or `anm_` from the files on disk (id is the prefix
  plus the lower-cased file name with dots as underscores, as `fetch_textures.ps1` does for `acg_`):

| Files | `licence` | `author` | `source_url` | `edition` | `modifications` |
| --- | --- | --- | --- | --- | --- |
| `assets/characters/**` except manifests | `CC0` | `MakeHuman Community and the Chronicle of Two project` | `https://static.makehumancommunity.org/mpfb.html` | `MPFB 2.0.18, makehuman_system_assets` | `Body, skin and hair from MakeHuman core assets; outfit, headgear and weapons generated by tools/characters (original work)` |
| `assets/characters/**/*.build.json` | `Original work` | `Chronicle of Two project` | | | |
| `assets/animations/quaternius/**` | `CC0` | `Quaternius` | `https://quaternius.itch.io/universal-animation-library` (the `-2` page for UAL2) | `Standard` | `Unchanged` |
| `assets/animations/chronicle/**` | `CC0` | `Quaternius and the Chronicle of Two project` | `https://quaternius.itch.io/universal-animation-library` | `Standard` | `Slices, sequences and held poses built by tools/characters/godot/build_clips.gd` |

- [ ] **Step 7: Record the exception in `AGENTS.md`.** In the hard rule about `.import` files, after
  "change import settings only through the editor", add: `Exception: the .import files of character
  and animation GLBs under assets/characters and assets/animations are written by
  tools/characters/godot/write_imports.gd, never by hand.`
- [ ] **Step 8: Build, import and write the ledger.** Copy the two clip files into place, then run
  `pwsh ./tools/build_characters.ps1 -Id vanguard` and `pwsh ./tools/build_characters.ps1 -LedgerOnly`.
  Expected: exit code 0 both times.
- [ ] **Step 9: Run the tests and confirm they pass.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_kit`
  (7 tests PASS), then `-Filter test_scene_loads` and `-Filter test_license_audit` (PASS). If
  `test_textures_are_compressed_with_mipmaps` fails, stop and report to the owner: the spec rules out
  hand-editing an import to fix it.
- [ ] **Step 10: Checkpoint.** New: `tools/characters/godot/write_imports.gd`, `game/characters/import/`,
  `game/characters/materials/`, `assets/animations/quaternius/`, the `.import` sidecars. Modified:
  `tools/build_characters.ps1`, `docs/license_ledger.csv`, `AGENTS.md`, the test.

---

### Task 4: Clip tables and `ClipSet`

**Files:**
- Create: `data/tables/character_roster.csv`, `data/tables/character_clips.csv` and a Keep File sidecar for each
- Create: `game/characters/clip_set.gd`, `tools/characters/godot/measure_clips.gd`
- Modify: `game/data/game_data.gd` (two fields and two table loads beside `graphics_presets`)
- Test: `tests/unit/test_character_clips.gd`

**Interfaces:**
- Produces:
  - `GameData.character_roster: Dictionary` (`"<for_kind>|<for_id>"` → row) and
    `GameData.character_clips: Dictionary` (`StringName` clip set → `Array[Dictionary]` of rows)
  - `ClipSet.ClipRow` with `role: StringName`, `clip: StringName`, `start_s: float`, `contact_s: float`,
    `end_s: float`, `layer: StringName`, `loop: bool`, `speed_mps: float`
  - `static func ClipSet.for_set(clip_set: StringName) -> ClipSet` (`null` for an unknown set)
  - `func row(role: StringName) -> ClipRow` (`null` when absent)
  - `func base_row(role: StringName) -> ClipRow` (the `idle` row when absent)
  - `func ability_row(def: AbilityDefinition) -> ClipRow`: `ability:<id>`, then `delivery:<delivery>`,
    then `action_default`
  - `static func clip_time(row: ClipRow, windup_s: float, rest_s: float, elapsed_s: float) -> float`
  - `static func windup_rate(row: ClipRow, windup_s: float) -> float`
  - Layer names: `&"full"`, `&"upper"`, `&"upper_when_moving"`

- [ ] **Step 1: Write the two tables.** `character_roster.csv`:

```csv
for_kind,for_id,character,clip_set
class,vanguard,vanguard,vanguard
```

`character_clips.csv` (contact times are the peak hand speed measured on 9 Nov; speeds come from the
root-motion files):

```csv
clip_set,role,clip,start_s,contact_s,end_s,layer,loop,speed_mps,notes
vanguard,idle,ual1/Sword_Idle,0,0,1.67,full,1,0,
vanguard,walk,ual1/Walk,0,0,1.33,full,1,0.97,
vanguard,jog,ual1/Jog_Fwd,0,0,0.93,full,1,5.36,
vanguard,sprint,ual1/Sprint,0,0,0.67,full,1,8.25,
vanguard,block,ual2/Idle_Shield,0,0,2.5,upper_when_moving,1,0,
vanguard,dodge,ual1/Roll,0.45,1.0,1.47,full,0,0,contact marks the end of the tumble
vanguard,hit,ual1/Hit_Chest,0,0.05,0.33,upper,0,0,
vanguard,get_up,ual2/LayToIdle,0.37,0.37,1.53,full,0,0,plays in real time
vanguard,downed_idle,extra/Prone_Hold,0,0,0.5,full,1,0,
vanguard,downed_crawl,extra/Downed_Crawl,0,0,1.6,full,1,0.75,
vanguard,dead,ual1/Death01,0,0.93,2.4,full,0,0,held on its last frame
vanguard,finisher,extra/Finisher_Blow,0,0.38,0.9,full,0,0,
vanguard,action_default,ual2/Sword_Regular_A,0,0.25,0.43,upper_when_moving,0,0,
vanguard,ability:vanguard_sword_strike,ual2/Sword_Regular_A,0,0.25,0.43,upper_when_moving,0,0,
vanguard,ability:vanguard_cross_cut,ual2/Sword_Regular_B,0.05,0.27,0.53,upper_when_moving,0,0,
vanguard,ability:vanguard_overhead,ual2/Sword_Regular_C,0.25,0.65,1.2,full,0,0,
vanguard,ability:vanguard_shield_smash,ual2/Shield_OneShot,0,0.1,0.83,full,0,0,
vanguard,ability:oathshield_throw,ual2/OverhandThrow,0,0.28,0.7,full,0,0,
vanguard,ability:oathshield_recall,extra/Catch,0,0,0.3,upper,0,0,
vanguard,ability:judgment_cleave,ual1/Sword_Attack,0,0.4,1.0,full,0,0,
vanguard,ability:shield_rush,ual2/Shield_Dash,0,0.07,1.1,full,0,0,
vanguard,ability:radiant_aegis,ual2/Idle_Shield_Break,0,0.1,0.6,full,0,0,
vanguard,ability:lance_of_dawn,ual2/OverhandThrow,0,0.28,0.8,full,0,0,
vanguard,ability:leap_slam,extra/Leap_Slam,0,0.2,0.92,full,0,0,contact is the take-off
vanguard,ability:flask,ual2/Consume,0,0.6,1.0,upper,0,0,
vanguard,ability:shove,ual2/Melee_Hook,0.1,0.27,0.47,upper_when_moving,0,0,
```

- [ ] **Step 2: Write the failing tests** in `tests/unit/test_character_clips.gd`:

```gdscript
func _row(start: float, contact: float, end: float) -> ClipSet.ClipRow:
	var row := ClipSet.ClipRow.new()
	row.start_s = start
	row.contact_s = contact
	row.end_s = end
	return row


func test_contact_lands_when_the_active_window_opens() -> void:
	var row := _row(0.0, 0.25, 0.43)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.0), 0.0, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.05), 0.125, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.1), 0.25, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.225), 0.34, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 9.0), 0.43, 0.0001)


func test_degenerate_timings_stay_finite() -> void:
	var row := _row(0.1, 0.25, 0.43)
	assert_almost_eq(ClipSet.clip_time(row, 0.0, 0.25, 0.0), 0.25, 0.0001, "no windup starts at contact")
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.0, 0.2), 0.43, 0.0001, "no recovery ends at once")
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, -3.0), 0.1, 0.0001, "time before the start is clamped")
	assert_almost_eq(ClipSet.clip_time(_row(0.2, 0.2, 0.2), 0.0, 0.0, 0.0), 0.2, 0.0001)


func test_every_vanguard_move_has_its_own_row() -> void:
	var clips := ClipSet.for_set(&"vanguard")
	var c := GameData.class_def(&"vanguard")
	var ids: Array[StringName] = [c.heavy_attack, c.throw_ability, c.recall_ability, &"shove", &"flask"]
	ids.append_array(c.light_combo)
	ids.append_array(c.abilities)
	for id: StringName in ids:
		assert_eq(clips.ability_row(GameData.ability(id)).role, StringName("ability:%s" % id))
	for role: StringName in [&"idle", &"walk", &"jog", &"sprint", &"block", &"dodge", &"hit", &"get_up",
			&"downed_idle", &"downed_crawl", &"dead", &"finisher", &"action_default"]:
		assert_not_null(clips.row(role), str(role))


func test_windups_are_not_stretched_too_far() -> void:
	var clips := ClipSet.for_set(&"vanguard")
	for id: StringName in GameData.abilities:
		var def := GameData.ability(id)
		var row := clips.row(StringName("ability:%s" % id))
		if row != null and def.windup_ticks > 0:
			var rate := ClipSet.windup_rate(row, def.windup_ticks / 60.0)
			assert_between(rate, 0.4, 3.0, str(id))
	assert_between(ClipSet.windup_rate(clips.row(&"dodge"), GameData.rule(&"dodge_ticks") / 60.0), 0.4, 3.0)
	assert_between(ClipSet.windup_rate(clips.row(&"finisher"), GameData.rule(&"finisher_impact_ticks") / 60.0), 0.4, 3.0)


func test_missing_rows_fall_back_and_never_return_null() -> void:
	var clips := ClipSet.for_set(&"vanguard")
	var stray := AbilityDefinition.new()
	stray.id = &"not_in_the_table"
	stray.delivery = &"melee_arc"
	assert_eq(clips.ability_row(stray).role, &"action_default")
	assert_eq(clips.base_row(&"no_such_role").role, &"idle")
	assert_null(clips.row(&"no_such_role"))
	assert_null(ClipSet.for_set(&"no_such_set"))


func test_rows_have_ordered_times_and_known_layers() -> void:
	for row: Dictionary in GameData.character_clips[&"vanguard"]:
		assert_true(0.0 <= row["start_s"] and row["start_s"] <= row["contact_s"] and row["contact_s"] <= row["end_s"], str(row["role"]))
		assert_has([&"full", &"upper", &"upper_when_moving"], row["layer"])
		assert_eq(String(row["clip"]).split("/").size(), 2, str(row["role"]))
```

- [ ] **Step 3: Run them and confirm they fail.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_clips`.
  Expected: FAIL (`ClipSet` not declared).
- [ ] **Step 4: Load the tables.** In `game_data.gd` add the two dictionary fields beside
  `graphics_presets` and, after its loop in `_load_tables()`, load `character_roster.csv`
  (`for_kind`, `for_id`, `character`, `clip_set`, all `T.NAME`) and `character_clips.csv` (`clip_set`,
  `role`, `clip`, `layer` as `T.NAME`; `start_s`, `contact_s`, `end_s`, `speed_mps` as `T.FLOAT`; `loop`
  as `T.BOOL`; `notes` as `T.STRING`).
- [ ] **Step 5: Implement `clip_set.gd`** (`class_name ClipSet extends RefCounted`). The one algorithm
  the tests do not spell out:

```gdscript
static func clip_time(row: ClipRow, windup_s: float, rest_s: float, elapsed_s: float) -> float:
	var e := maxf(elapsed_s, 0.0)
	if windup_s > 0.0 and e <= windup_s:
		return lerpf(row.start_s, row.contact_s, e / windup_s)
	var after := e - maxf(windup_s, 0.0)
	return lerpf(row.contact_s, row.end_s, 1.0 if rest_s <= 0.0 else minf(1.0, after / rest_s))
```

  `windup_rate` is `(contact_s - start_s) / windup_s`.
- [ ] **Step 6: Write `measure_clips.gd`** as a port of `tools/out/character_test/godot/measure_clips.gd`
  that reads the committed libraries, for whoever adds rows later. It prints, per clip, its length and
  the time of peak right-hand and left-hand speed. It runs with `-s` and names no game class.
- [ ] **Step 7: Run the tests and confirm they pass.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_clips`.
  Expected: PASS, 6 tests. Then `-Filter test_scene_loads` (the Keep File check covers the new CSVs).
- [ ] **Step 8: Checkpoint.** `git diff game/data/game_data.gd` shows only the two fields and two loads,
  apart from changes other sessions already had there.

---

### Task 5: The extra clip library

**Files:**
- Create: `art/characters/clips_extra.json`, `tools/characters/godot/build_clips.gd`
- Create (output): `assets/animations/chronicle/extra.res`
- Modify: `tools/build_characters.ps1` (run `build_clips.gd` after the import, then `-LedgerOnly` covers it)
- Test: `tests/unit/test_character_clips.gd` (add cases)

**Interfaces:**
- Consumes: the two imported Quaternius libraries (Task 3).
- Produces: `load("res://assets/animations/chronicle/extra.res")` is an `AnimationLibrary` with clips
  `Prone_Hold`, `Downed_Crawl`, `Catch`, `Finisher_Blow` and `Leap_Slam`, tracks on `%GeneralSkeleton`.

- [ ] **Step 1: Write `clips_extra.json`:**

```json
{"clips": [
  {"name": "Prone_Hold", "op": "pose_loop", "from": "ual2/LayToIdle", "at": 0.0, "length": 0.5, "sway": []},
  {"name": "Downed_Crawl", "op": "pose_loop", "from": "ual2/LayToIdle", "at": 0.0, "length": 1.6, "sway": [
    {"bone": "LeftUpperArm", "axis": [1, 0, 0], "degrees": 22, "phase": 0.0},
    {"bone": "RightUpperArm", "axis": [1, 0, 0], "degrees": 22, "phase": 0.5},
    {"bone": "Spine", "axis": [0, 1, 0], "degrees": 6, "phase": 0.25}]},
  {"name": "Catch", "op": "pose_loop", "from": "ual2/OverhandThrow", "at": 0.45, "length": 0.3, "sway": []},
  {"name": "Finisher_Blow", "op": "slice", "from": "ual2/Sword_Heavy_Combo", "start": 0.0, "end": 0.9},
  {"name": "Leap_Slam", "op": "sequence", "crossfade": 0.05, "parts": [
    {"from": "ual1/Jump_Start", "start": 0.0, "end": 0.2},
    {"from": "ual1/Jump", "start": 0.0, "end": 0.42},
    {"from": "ual1/Jump_Land", "start": 0.1, "end": 0.4}]}
]}
```

- [ ] **Step 2: Write the failing tests** (add to `test_character_clips.gd`):

```gdscript
const LIBRARIES := {
	"ual1": "res://assets/animations/quaternius/UAL1_Standard.glb",
	"ual2": "res://assets/animations/quaternius/UAL2_Standard.glb",
	"extra": "res://assets/animations/chronicle/extra.res",
}


func test_extra_clips_have_their_lengths() -> void:
	var extra: AnimationLibrary = load(LIBRARIES["extra"])
	for pair: Array in [["Prone_Hold", 0.5], ["Downed_Crawl", 1.6], ["Catch", 0.3], ["Finisher_Blow", 0.9], ["Leap_Slam", 0.92]]:
		assert_almost_eq(extra.get_animation(pair[0]).length, pair[1], 0.02, pair[0])
	var crawl := extra.get_animation(&"Downed_Crawl")
	var arm := crawl.find_track(NodePath("%GeneralSkeleton:LeftUpperArm"), Animation.TYPE_ROTATION_3D)
	assert_false(crawl.rotation_track_interpolate(arm, 0.4).is_equal_approx(crawl.rotation_track_interpolate(arm, 1.2)), "the arm sways")
	assert_true(crawl.rotation_track_interpolate(arm, 0.0).is_equal_approx(crawl.rotation_track_interpolate(arm, 1.6)), "and loops")


func test_every_row_points_at_a_real_clip_within_its_length() -> void:
	var libs := {}
	for key: String in LIBRARIES:
		libs[key] = load(LIBRARIES[key]) as AnimationLibrary
	for row: Dictionary in GameData.character_clips[&"vanguard"]:
		var parts := String(row["clip"]).split("/")
		var lib := libs.get(parts[0]) as AnimationLibrary
		assert_true(lib != null and lib.has_animation(parts[1]), str(row["clip"]))
		if lib != null and lib.has_animation(parts[1]):
			assert_lte(float(row["end_s"]), lib.get_animation(parts[1]).length + 0.02, str(row["role"]))
```

- [ ] **Step 3: Run them and confirm they fail.** Expected: FAIL (`extra.res` does not exist).
- [ ] **Step 4: Implement `build_clips.gd`** (`extends SceneTree`, no game classes). Every operation
  works by sampling: for each of the 53 bone rotation tracks and the `Hips` position track, it reads the
  source clip at 30 samples a second and writes keys.
  - `slice`: samples `start` to `end`.
  - `sequence`: lays the parts end to end; over the first `crossfade` seconds of each later part it
    blends from the previous part's last pose.
  - `pose_loop`: holds the source pose at `at` for `length` seconds; each `sway` entry multiplies that
    bone's rotation by a turn about `axis` of `degrees × sin(2π × (t / length + phase))`, and the clip's
    loop mode is linear.
  It saves the library with `ResourceSaver.save()` and exits non-zero when a source clip is missing.
- [ ] **Step 5: Build and run the tests.** Run `pwsh ./tools/build_characters.ps1 -Id vanguard`, then
  `pwsh ./tools/build_characters.ps1 -LedgerOnly`, then `pwsh ./tools/run_tests.ps1 -Filter test_character_clips`.
  Expected: PASS, 8 tests; `-Filter test_license_audit` passes.
- [ ] **Step 6: Checkpoint.** New: the JSON, the script, `assets/animations/chronicle/`. Modified:
  `tools/build_characters.ps1`, `docs/license_ledger.csv`.

---

### Task 6: `AnimPose` and `HeroAnimDriver`

**Files:**
- Create: `game/characters/anim_pose.gd`, `game/characters/hero_anim_driver.gd`
- Test: `tests/unit/test_hero_anim_driver.gd`

**Interfaces:**
- Consumes: `ClipSet` (Task 4); `HeroMotor` fields `move_velocity`, `yaw`, `downed`, `dodge_ticks_left`,
  `dodge_start_tick`, `dodge_ticks`, `action_slot`, `action_tick`, `blocking`, `block_start_tick`, and
  `current_action_def()`; `NetProtocol.LIFE_ALIVE`, `LIFE_DOWNED`, `LIFE_FALLEN`; rules
  `finisher_impact_ticks` and `finisher_lock_ticks`.
- Produces:
  - `AnimPose` (`extends RefCounted`) with `locomotion: bool = true`, `speed_mps: float`,
    `move_angle: float` (radians from facing to movement, 0 is forward), `base_clip: StringName`,
    `base_time_s: float = -1.0` (0 or more pins the base clip to that time; negative lets it loop),
    `action_clip: StringName`, `action_time_s: float`, `action_upper: bool`, `overlay_clip: StringName`,
    `overlay_time_s: float`
  - `static func HeroAnimDriver.pose(motor: HeroMotor, life: int, tick: int, tick_factor: float, finisher_elapsed_s: float, clips: ClipSet) -> AnimPose`
    (`finisher_elapsed_s` is negative when no finisher is playing; the overlay fields are left for the rig)

- [ ] **Step 1: Write the failing tests.** Build motors with the helper the motor tests already have:

```gdscript
const MotorKit := preload("res://tests/unit/test_hero_motor.gd")

var motor: HeroMotor
var clips: ClipSet


func before_each() -> void:
	motor = MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	clips = ClipSet.for_set(&"vanguard")


func _act(ability_id: StringName, slot: int, started: int) -> void:
	motor.action_slot = slot
	motor.action_ability = GameData.ability_index(ability_id)
	motor.action_tick = started


func _pose(tick: int, factor: float = 0.0, life: int = NetProtocol.LIFE_ALIVE, finisher_s: float = -1.0) -> AnimPose:
	return HeroAnimDriver.pose(motor, life, tick, factor, finisher_s, clips)


func test_contact_frame_lands_on_the_active_tick() -> void:
	for case: Array in [[&"vanguard_sword_strike", GameTypes.ACT_BASIC, 6, &"ual2/Sword_Regular_A", 0.25],
			[&"vanguard_shield_smash", GameTypes.ACT_HEAVY, 14, &"ual2/Shield_OneShot", 0.1],
			[&"judgment_cleave", GameTypes.ACT_1, 10, &"ual1/Sword_Attack", 0.4],
			[&"oathshield_recall", GameTypes.ACT_THROW, 0, &"extra/Catch", 0.0]]:
		_act(case[0], case[1], 100)
		var p := _pose(100 + int(case[2]))
		assert_eq(p.action_clip, case[3])
		assert_almost_eq(p.action_time_s, float(case[4]), 0.0001, str(case[0]))


func test_time_between_ticks_uses_the_tick_factor() -> void:
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_almost_eq(_pose(103, 0.0).action_time_s, 0.125, 0.0001)
	assert_almost_eq(_pose(102, 0.5).action_time_s, 0.25 * 2.5 / 6.0, 0.0001)


func test_rollback_times_are_clamped() -> void:
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_almost_eq(_pose(90).action_time_s, 0.0, 0.0001, "an action that starts in the future shows its first frame")
	assert_almost_eq(_pose(103, 7.0).action_time_s, _pose(103, 1.0).action_time_s, 0.0001, "tick_factor is clamped to 1")


func test_a_throws_recovery_still_shows_the_throw() -> void:
	_act(&"oathshield_throw", GameTypes.ACT_THROW, 100)
	motor.weapon_out = true
	assert_eq(_pose(115).action_clip, &"ual2/OverhandThrow")


func test_rule_order() -> void:
	motor.blocking = true
	motor.block_start_tick = 100
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_eq(_pose(103).action_clip, &"ual2/Sword_Regular_A", "an action beats the block")
	motor.dodge_start_tick = 100
	motor.dodge_ticks_left = 9
	assert_eq(_pose(103).action_clip, &"ual1/Roll", "a dodge beats an action")
	assert_eq(_pose(103, 0.0, NetProtocol.LIFE_ALIVE, 0.2).action_clip, &"extra/Finisher_Blow", "a finisher beats a dodge")
	motor.downed = true
	var down := _pose(103, 0.0, NetProtocol.LIFE_DOWNED)
	assert_false(down.locomotion)
	assert_eq(down.base_clip, &"extra/Prone_Hold")
	assert_eq(down.action_clip, &"")
	var dead := _pose(103, 0.0, NetProtocol.LIFE_FALLEN)
	assert_eq(dead.base_clip, &"ual1/Death01")
	assert_almost_eq(dead.base_time_s, 2.4, 0.0001, "held on its last frame")


func test_dodge_and_finisher_timing() -> void:
	motor.dodge_start_tick = 100
	motor.dodge_ticks_left = 0
	assert_almost_eq(_pose(100 + motor.dodge_ticks).action_time_s, 1.0, 0.0001, "the tumble ends as the dodge does")
	assert_eq(_pose(100 + motor.dodge_ticks + 9).action_clip, &"ual1/Roll", "ten more ticks to stand up")
	assert_eq(_pose(100 + motor.dodge_ticks + 10).action_clip, &"")
	var impact_s := GameData.rule(&"finisher_impact_ticks") / 60.0
	assert_almost_eq(_pose(200, 0.0, NetProtocol.LIFE_ALIVE, impact_s).action_time_s, 0.38, 0.0001)


func test_block_and_layers() -> void:
	motor.blocking = true
	motor.block_start_tick = 100
	var still := _pose(130)
	assert_eq(still.action_clip, &"ual2/Idle_Shield")
	assert_false(still.action_upper)
	motor.move_velocity = Vector3(0, 0, 4.0)
	assert_true(_pose(130).action_upper, "upper body only while moving")
	motor.blocking = false
	_act(&"vanguard_overhead", GameTypes.ACT_BASIC, 100)
	assert_false(_pose(104).action_upper, "a full-body row stays full body while moving")
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_true(_pose(104).action_upper)


func test_locomotion_reads_speed_and_direction() -> void:
	motor.yaw = 0.0
	motor.move_velocity = Vector3(0, 0, 6.2)
	var forward := _pose(10)
	assert_true(forward.locomotion)
	assert_almost_eq(forward.speed_mps, 6.2, 0.0001)
	assert_almost_eq(forward.move_angle, 0.0, 0.0001)
	motor.move_velocity = Vector3(6.2, 0, 0)
	assert_almost_eq(_pose(10).move_angle, PI / 2.0, 0.0001)
	motor.move_velocity = Vector3(0, 3.0, -6.2)
	assert_almost_eq(absf(_pose(10).move_angle), PI, 0.0001)
	assert_almost_eq(_pose(10).speed_mps, 6.2, 0.0001, "vertical speed does not count")
```

- [ ] **Step 2: Run them and confirm they fail.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_hero_anim_driver`.
  Expected: FAIL (`HeroAnimDriver` not declared).
- [ ] **Step 3: Implement both files.** `pose()` is pure: no node access, no state. It takes the first
  rule that applies, in the spec's order ("Hero poses"):
  1. `life == LIFE_FALLEN`: base clip `dead`, pinned at its `end_s`, no action.
  2. `motor.downed` or `life == LIFE_DOWNED`: base clip `downed_crawl` when speed is above 0.2 m/s,
     else `downed_idle`; no action.
  3. `finisher_elapsed_s >= 0`: action `finisher`, full body, clip time from `clip_time()` with windup
     `finisher_impact_ticks / 60` and rest `(finisher_lock_ticks - finisher_impact_ticks) / 60`.
  4. `dodge_ticks_left > 0` or `tick - dodge_start_tick < dodge_ticks + 10`: action `dodge`, full body,
     windup `dodge_ticks / 60`, rest `10 / 60`, elapsed from `dodge_start_tick`.
  5. `action_slot >= 0` with a non-null `current_action_def()`: `ability_row(def)`; windup, active and
     recovery from the definition; upper body when the row's layer is `upper`, or `upper_when_moving`
     with speed above 0.5 m/s.
  6. `blocking`: action `block`, looping on time since `block_start_tick`; layer as in rule 5.
  7. Otherwise locomotion only.
  In every case `speed_mps` is the horizontal speed and `move_angle` is
  `wrapf(atan2(v.x, v.z) - motor.yaw, -PI, PI)`. Elapsed time is
  `(tick - start_tick + clampf(tick_factor, 0.0, 1.0)) / 60.0`.
- [ ] **Step 4: Run the tests and confirm they pass.** Expected: PASS, 8 tests.
- [ ] **Step 5: Checkpoint.** Two new files under `game/characters/` and the test.

---

### Task 7: `CharacterAnimator`

**Files:**
- Create: `game/characters/character_animator.gd`
- Test: `tests/unit/test_character_rig.gd`

**Interfaces:**
- Consumes: `AnimPose`, `ClipSet`, the Vanguard scene and the three libraries.
- Produces:
  - `class_name CharacterAnimator extends Node`
  - `func setup(skeleton: Skeleton3D, clips: ClipSet) -> void`
  - `func apply(pose: AnimPose, delta: float) -> void` (with `delta` 0 the pose holds)
  - `var last_locomotion_rate: float` (the walk-cycle playback rate last applied; negative is reversed)
  - `const LIBRARIES := {&"ual1": "res://assets/animations/quaternius/UAL1_Standard.glb", &"ual2": "res://assets/animations/quaternius/UAL2_Standard.glb", &"extra": "res://assets/animations/chronicle/extra.res"}`

The tree, built in code and owned by one rig (never shared, because the action clip is set on its nodes):

| Node | Type | Driven by |
| --- | --- | --- |
| `Loco` | `AnimationNodeBlendSpace1D`, `sync` on, a named point per cycle at its `speed_mps` (`idle` at 0) | `blend_position` = speed |
| `LocoScale` | `AnimationNodeTimeScale` over `Loco` | the rate; negative plays backwards |
| `Base`, `BaseSeek` | `AnimationNodeAnimation` under `AnimationNodeTimeSeek` | `pose.base_clip`, `base_time_s` |
| `BaseMix` | `AnimationNodeBlend2` (`LocoScale`, `BaseSeek`) | 0 for locomotion, 1 for a base clip, eased at 8 a second |
| `ActFull`, `ActFullSeek` | animation under a seek | a full-body action |
| `FullMix` | `Blend2` (`BaseMix`, `ActFullSeek`) | eased at 12 a second |
| `ActUpper`, `ActUpperSeek` | animation under a seek | an upper-body action |
| `UpperMix` | `Blend2` (`FullMix`, `ActUpperSeek`) with the upper-body filter | eased at 12 a second |
| `Over`, `OverSeek` | animation under a seek | `pose.overlay_clip` |
| `OverMix` | `Blend2` (`UpperMix`, `OverSeek`) with the same filter, wired to the output | 0.6 while an overlay plays |

The upper-body filter is `Spine`, `Chest`, `UpperChest`, `Neck`, `Head` and every shoulder, arm, hand
and finger bone, as paths `%GeneralSkeleton:<bone>`.

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_character_rig.gd`:

```gdscript
const VANGUARD := "res://assets/characters/vanguard/vanguard.glb"

var clips: ClipSet


func before_each() -> void:
	clips = ClipSet.for_set(&"vanguard")


func _animated() -> Array:
	var scene: Node3D = (load(VANGUARD) as PackedScene).instantiate()
	add_child_autofree(scene)
	var sk := scene.get_node("%GeneralSkeleton") as Skeleton3D
	var animator := CharacterAnimator.new()
	scene.add_child(animator)
	animator.setup(sk, clips)
	return [animator, sk]


func _sample(clip: StringName, bone: String, t: float) -> Quaternion:
	var parts := String(clip).split("/")
	var anim := (load(CharacterAnimator.LIBRARIES[StringName(parts[0])]) as AnimationLibrary).get_animation(parts[1])
	return anim.rotation_track_interpolate(anim.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D), t)


func _rot(sk: Skeleton3D, bone: String) -> Quaternion:
	return sk.get_bone_pose_rotation(sk.find_bone(bone))


## Apply the same pose a few times so the eased blends settle.
func _settle(animator: CharacterAnimator, pose: AnimPose) -> void:
	for i in 40:
		animator.apply(pose, 0.1)
	animator.apply(pose, 0.0)


func test_full_body_action_sits_at_its_exact_time() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	_settle(a[0], pose)
	for bone: String in ["RightUpperArm", "LeftUpperLeg"]:
		assert_almost_eq(rad_to_deg(_rot(a[1], bone).angle_to(_sample(&"ual2/Sword_Regular_A", bone, 0.25))), 0.0, 0.1, bone)


func test_upper_body_action_leaves_the_legs_to_the_walk() -> void:
	var a := _animated()
	var b := _animated()
	var pose := AnimPose.new()
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	pose.action_upper = true
	_settle(a[0], pose)
	_settle(b[0], AnimPose.new())
	assert_almost_eq(rad_to_deg(_rot(a[1], "RightUpperArm").angle_to(_sample(&"ual2/Sword_Regular_A", "RightUpperArm", 0.25))), 0.0, 0.1)
	assert_almost_eq(rad_to_deg(_rot(a[1], "LeftUpperLeg").angle_to(_rot(b[1], "LeftUpperLeg"))), 0.0, 0.1, "legs match a rig with no action")


func test_zero_delta_holds_the_pose() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.speed_mps = 5.36
	(a[0] as CharacterAnimator).apply(pose, 0.2)
	var before := _rot(a[1], "LeftUpperLeg")
	(a[0] as CharacterAnimator).apply(pose, 0.0)
	assert_true(before.is_equal_approx(_rot(a[1], "LeftUpperLeg")))


func test_pinned_base_clip() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.locomotion = false
	pose.base_clip = &"ual1/Death01"
	pose.base_time_s = 2.4
	_settle(a[0], pose)
	assert_almost_eq(rad_to_deg(_rot(a[1], "Spine").angle_to(_sample(&"ual1/Death01", "Spine", 2.4))), 0.0, 0.1)


func test_unknown_clip_keeps_the_previous_pose() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	_settle(a[0], pose)
	var before := _rot(a[1], "RightUpperArm")
	pose.action_clip = &"ual2/No_Such_Clip"
	(a[0] as CharacterAnimator).apply(pose, 0.016)
	assert_almost_eq(rad_to_deg(before.angle_to(_rot(a[1], "RightUpperArm"))), 0.0, 0.1, "not dropped to the rest pose")


func test_two_animators_do_not_share_clips() -> void:
	var a := _animated()
	var b := _animated()
	var swing := AnimPose.new()
	swing.action_clip = &"ual2/Sword_Regular_A"
	swing.action_time_s = 0.25
	var guard := AnimPose.new()
	guard.action_clip = &"ual2/Idle_Shield"
	guard.action_time_s = 0.5
	_settle(a[0], swing)
	_settle(b[0], guard)
	(a[0] as CharacterAnimator).apply(swing, 0.016)
	assert_almost_eq(rad_to_deg(_rot(a[1], "RightUpperArm").angle_to(_sample(&"ual2/Sword_Regular_A", "RightUpperArm", 0.25))), 0.0, 0.1)


func test_locomotion_rate_is_clamped_and_reverses() -> void:
	var a := _animated()
	var animator := a[0] as CharacterAnimator
	var pose := AnimPose.new()
	pose.speed_mps = 6.2
	animator.apply(pose, 0.016)
	assert_almost_eq(animator.last_locomotion_rate, 6.2 / 5.36, 0.01)
	pose.speed_mps = 400.0
	animator.apply(pose, 0.016)
	assert_almost_eq(animator.last_locomotion_rate, 1.5, 0.0001)
	pose.speed_mps = 6.2
	pose.move_angle = PI
	animator.apply(pose, 0.016)
	assert_lt(animator.last_locomotion_rate, 0.0, "moving backwards plays the cycle in reverse")
	for bone: String in ["Hips", "Spine", "LeftUpperLeg"]:
		assert_true(_rot(a[1], bone).is_finite(), bone)
```

- [ ] **Step 2: Run them and confirm they fail.** Run: `pwsh ./tools/run_tests.ps1 -Filter test_character_rig`.
  Expected: FAIL (`CharacterAnimator` not declared).
- [ ] **Step 3: Implement `character_animator.gd`**, porting the wiring from `probe_tree.gd` and
  `probe_tree2.gd`.
  - `setup()` adds an `AnimationTree` child with `callback_mode_process` manual, loads the three
    libraries into it, builds the tree above, and sets `loop_mode` linear on every clip whose row has
    `loop` set.
  - `apply()` sets the parameters, then calls `advance(delta)`. A seek node takes its clip to an exact
    time: set `seek_request` every frame for actions, overlays and pinned base clips. With `delta` 0 it
    returns before touching the tree.
  - A clip name the libraries do not have: `push_warning` once per name, and leave that layer's clip and
    weight as they were.
  - Rate: the cycle whose `speed_mps` is nearest below the speed leads; rate = speed over its
    `speed_mps`, clamped to 0.6..1.5, and 1 when speed is under 0.2 m/s.
  - Hip twist, applied to the skeleton straight after `advance()`: for `|move_angle|` up to 100° turn
    `Hips` about +Y by `move_angle` and `Spine` by its negative; beyond that, negate the rate and use
    `move_angle - sign(move_angle) × PI` instead.
- [ ] **Step 4: Run the tests and confirm they pass.** Expected: PASS, 7 tests.
- [ ] **Step 5: Checkpoint.** One new file and the test.

---

### Task 8: `CharacterRig` and `CharacterKit`

**Files:**
- Create: `game/characters/character_rig.gd`, `game/characters/character_kit.gd`
- Test: `tests/unit/test_character_rig.gd` and `tests/unit/test_character_kit.gd` (add cases)

**Interfaces:**
- Consumes: `CharacterAnimator`, `HeroAnimDriver`, `ClipSet`, `GameData.character_roster`.
- Produces:
  - `class_name CharacterRig extends Node3D` with `parts: Array[GeometryInstance3D]`,
    `skeleton: Skeleton3D`, `animator: CharacterAnimator`, `built_height: float`
  - `static func CharacterRig.create(scene: PackedScene, clip_set: StringName) -> CharacterRig` (`null`
    when the scene has no `GeneralSkeleton` or the clip set is unknown)
  - `func set_accent(color: Color) -> void`, `func set_signature_visible(shown: bool) -> void`,
    `func set_headgear_visible(shown: bool) -> void`
  - `func update_hero(motor: HeroMotor, life: int, tick: int, tick_factor: float, delta: float) -> void`
  - `func play_finisher(lock_ticks: int) -> void`, `func play_hit() -> void`
  - `class_name CharacterKit extends RefCounted` with `static var enabled: bool` (true unless the display
    server is `headless`), `static func has_hero(class_id: StringName) -> bool`,
    `static func hero_rig(class_id: StringName, accent: Color) -> CharacterRig`,
    `static func scene_path(character: StringName) -> String`
    (`"res://assets/characters/%s/%s.glb"`)

- [ ] **Step 1: Write the failing tests.** Add to `test_character_rig.gd`:

```gdscript
const MotorKit := preload("res://tests/unit/test_hero_motor.gd")
const GOLD := Color(0.95, 0.72, 0.25)
const VIOLET := Color(0.62, 0.42, 1.0)


func _rig() -> CharacterRig:
	var rig := CharacterRig.create(load(VANGUARD) as PackedScene, &"vanguard")
	add_child_autofree(rig)
	return rig


func _accent_color(rig: CharacterRig) -> Color:
	var body := rig.find_child("Body", true, false) as MeshInstance3D
	for s in body.mesh.get_surface_count():
		if body.mesh.surface_get_material(s).resource_name == "accent_trim":
			return (body.get_active_material(s) as BaseMaterial3D).albedo_color
	return Color.BLACK


func test_parts_cover_every_mesh() -> void:
	var rig := _rig()
	assert_eq(rig.parts.size(), rig.find_children("*", "GeometryInstance3D", true, false).size())
	assert_almost_eq(rig.built_height, 1.8, 0.01)


func test_signature_and_headgear_switch() -> void:
	var rig := _rig()
	var shield := rig.find_child("Sig_Oathshield", true, false) as Node3D
	var sword := rig.find_child("Prop_Sword", true, false) as Node3D
	rig.set_signature_visible(false)
	assert_false(shield.visible)
	assert_true(sword.visible, "only the signature weapon hides")
	rig.set_signature_visible(true)
	assert_true(shield.visible)
	var helm := rig.find_child("Headgear", true, false) as Node3D
	var hair := rig.find_child("HairFull", true, false) as Node3D
	assert_true(helm.visible and not hair.visible, "headgear is on by default")
	rig.set_headgear_visible(false)
	assert_true(hair.visible and not helm.visible)


func test_two_rigs_keep_their_own_colour() -> void:
	var a := _rig()
	var b := _rig()
	a.set_accent(GOLD)
	b.set_accent(VIOLET)
	assert_true(_accent_color(a).is_equal_approx(GOLD))
	assert_true(_accent_color(b).is_equal_approx(VIOLET))
	b.set_headgear_visible(false)
	assert_true((a.find_child("Headgear", true, false) as Node3D).visible)


func test_update_hero_drives_the_pose_and_the_thrown_shield() -> void:
	var rig := _rig()
	var motor := MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	var arm := rig.skeleton.find_bone("RightUpperArm")
	var rest := rig.skeleton.get_bone_rest(arm).basis.get_rotation_quaternion()
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.1)
	assert_false(rig.skeleton.get_bone_pose_rotation(arm).is_equal_approx(rest), "the idle is not the rest pose")
	motor.weapon_out = true
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 11, 0.0, 0.016)
	assert_false((rig.find_child("Sig_Oathshield", true, false) as Node3D).visible)


func test_hit_and_finisher_run_on_the_rigs_own_clock() -> void:
	var rig := _rig()
	var motor := MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.1)
	var head := rig.skeleton.find_bone("Head")
	var calm := rig.skeleton.get_bone_pose_rotation(head)
	rig.play_hit()
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.05)
	assert_false(calm.is_equal_approx(rig.skeleton.get_bone_pose_rotation(head)), "the hit overlay moves the head")
	rig.play_finisher(60)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.0)
	var frozen := rig.skeleton.get_bone_pose_rotation(head)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 40, 0.0, 0.0)
	assert_true(frozen.is_equal_approx(rig.skeleton.get_bone_pose_rotation(head)), "zero delta holds, as hit-stop needs")
```

  Add to `test_character_kit.gd`:

```gdscript
const GOLD := Color(0.95, 0.72, 0.25)


func after_each() -> void:
	CharacterKit.enabled = false
	GameData.character_roster.erase("class|ghost")


func test_no_rig_without_a_window_unless_asked() -> void:
	assert_false(CharacterKit.enabled, "GUT runs headless")
	assert_null(CharacterKit.hero_rig(&"vanguard", GOLD))


func test_kit_hands_out_rigs_and_survives_bad_rows() -> void:
	CharacterKit.enabled = true
	var rig := CharacterKit.hero_rig(&"vanguard", GOLD)
	assert_not_null(rig)
	if rig != null:
		add_child_autofree(rig)
	assert_true(CharacterKit.has_hero(&"vanguard"))
	assert_null(CharacterKit.hero_rig(&"riftweaver", GOLD), "no roster row yet: the placeholder is used")
	GameData.character_roster["class|ghost"] = {"for_kind": &"class", "for_id": &"ghost", "character": &"no_such_model", "clip_set": &"vanguard"}
	assert_null(CharacterKit.hero_rig(&"ghost", GOLD), "a missing model gives null, not a crash")
	GameData.character_roster["class|ghost"]["character"] = &"vanguard"
	GameData.character_roster["class|ghost"]["clip_set"] = &"no_such_set"
	assert_null(CharacterKit.hero_rig(&"ghost", GOLD), "an unknown clip set gives null")
	GameData.character_roster.erase("class|ghost")
	CharacterKit.enabled = false
```

- [ ] **Step 2: Run them and confirm they fail.** Run both filters. Expected: FAIL (`CharacterRig` and
  `CharacterKit` not declared).
- [ ] **Step 3: Implement `character_rig.gd`.**
  - `create()` instantiates the scene as the rig's child, collects `parts`, reads `built_height_m`,
    adds the animator, shows `Headgear` and hides `HairFull`.
  - `set_accent()` gives every surface whose material is `accent_trim` a copy of it, tinted, as a
    surface override on that mesh only.
  - Signature props are the nodes whose names begin with `Sig_`.
  - `update_hero()` advances the rig's own clock by `delta`, hides the signature props while
    `motor.weapon_out`, asks `HeroAnimDriver.pose()` (passing the time since `play_finisher()`, or -1
    once `lock_ticks / 60` seconds have passed), adds the `hit` row as the overlay while its time since
    `play_hit()` is under its length, and calls `animator.apply(pose, delta)`.
  - When `life` returns to `LIFE_ALIVE` after being downed, it shows `get_up` as a full-body action in
    real time from its `start_s` to its `end_s`.
- [ ] **Step 4: Implement `character_kit.gd`.** `hero_rig()` returns `null` when `enabled` is false,
  when the roster has no `class|<id>` row, when `ResourceLoader.exists()` is false for the scene path or
  the load is not a `PackedScene`, or when `CharacterRig.create()` returns `null`. Each of the last two
  cases warns once per character with `push_warning`. On success it calls `set_accent(accent)`.
- [ ] **Step 5: Run the tests and confirm they pass.** Expected: `test_character_rig` 12 tests,
  `test_character_kit` 9 tests, all PASS.
- [ ] **Step 6: Checkpoint.** Two new files and the two tests.

---

### Task 9: `HeroVisual` uses the rig

**Files:**
- Modify: `game/presentation/hero_visual.gd` (owned by "Chronicle of Two master plan")

**Interfaces:**
- Consumes: `CharacterKit.hero_rig()`, `CharacterRig.parts`, `update_hero()`, `play_hit()`, `play_finisher()`.
- Produces: with a window, a Vanguard hero is drawn and animated by its rig; every other hero, and every
  hero in a headless run, is the placeholder exactly as today.

- [ ] **Step 1: Get agreement.** Check `OPUS_HANDOFF.md` for a reply to the request in "Claim: realistic
  characters and animation". Without one, ask the owner before editing. Then re-read `hero_visual.gd`.
  Before changing it, take the "before" picture: run the command in Step 7 with the screenshot path
  `tools/out/characters_pr1/arena_before.png`.
- [ ] **Step 2: Add the field** below `var model: Node3D`:
  `var rig: CharacterRig  ## null when this class has no character or rigs are off`.
- [ ] **Step 3: Branch in `setup()`.** Replace the lines from `model = ProcMesh.build_hero(...)` through
  the `_signature_parts` loop with:

```gdscript
	rig = CharacterKit.hero_rig(hero.class_def.id, accent)
	if rig != null:
		model = rig
		add_child(model)
		parts.assign(rig.parts)
	else:
		model = ProcMesh.build_hero(hero.class_def.id, accent)
		add_child(model)
		body = model.get_node("Body")
		arm_l = body.get_node("ArmL")
		arm_r = body.get_node("ArmR")
		_collect(model)
		# The signature weapon disappears from the hand while it's thrown.
		for path: String in ["ArmL/Shield", "ArmL/ShieldBoss", "ArmR/Weapon/Orb"]:
			var n := body.get_node_or_null(path) as Node3D
			if n != null:
				_signature_parts.append(n)
```

- [ ] **Step 4: Branch in `_process()`.** Replace the single call `_animate(delta, m)` with:

```gdscript
	if rig != null:
		rig.update_hero(m, hero.stats.life, NetworkTime.tick, NetworkTime.tick_factor, delta)
		_ward.visible = m.blocking and hero.class_def.id != &"vanguard"
	else:
		_animate(delta, m)
```

- [ ] **Step 5: Forward the two moments.** At the end of `flash()` add `if rig != null: rig.play_hit()`
  (on two lines), and at the end of `play_finisher()` add `if rig != null: rig.play_finisher(lock_ticks)`.
- [ ] **Step 6: Run the whole suite.** Run: `pwsh ./tools/run_tests.ps1`. Expected: every test passes,
  including `test_scene_loads` (all scripts compile) and `test_crowd_playback`. If a test other
  sessions own was already failing before this edit, record it and leave it.
- [ ] **Step 7: See it in the real game.** Run:
  `& ./.engine/Godot_v4.7.2-stable_win64_console.exe --path . -- --solo --bot --profile=character_check --screenshot="$PWD/tools/out/characters_pr1/arena_after.png" --screenshot-after=14 --quit-after=16`.
  Expected: a `[shot] saved` line, no `SCRIPT ERROR`, and the screenshot shows the armoured Vanguard
  from the shoulder camera. Delete the `character_check` profile folder afterwards.
- [ ] **Step 8: Soak.** Run: `pwsh ./tools/soak.ps1 -Seconds 60`. Expected: both bots exit 0 and the
  guest's `[correction]` count is no worse than before (headless runs build no rig).
- [ ] **Step 9: Checkpoint.** `git diff game/presentation/hero_visual.gd` shows only the four changes
  above, apart from what the file already had.

---

### Task 10: The review scene and the cost gate

**Files:**
- Create: `game/characters/review/character_review.tscn`, `game/characters/review/character_review.gd`

**Interfaces:**
- Consumes: `CharacterKit`, `CharacterRig`, `ClipSet`, `AnimPose`; `ArenaBuilder.build(world, false)`,
  `SurfaceLayer.setup()`, `ArenaLayout.paint_surfaces()`, `RenderPipeline.setup()` as
  `tools/out/character_test/scripts/hall_shot.gd` uses them.
- Produces: `godot --path . res://game/characters/review/character_review.tscn -- --character=<id> --sheet=<turnaround|moves|cost> --out=<png>`.
  It sets `CharacterKit.enabled = true`, saves the picture, prints one `[characters]` line and quits.
  It always quits: a 120-second timer exits with code 3.

- [ ] **Step 1: Implement the three sheets.** The scene is a `Node3D` with the script; it reads its
  options with `Settings.arg()`.
  - `turnaround`: eight rigs in a row under plain light (one key light with shadows, one cool rim light,
    flat ambient), turned 0°, 40°, 180°, 215°, 180°, 150°, 20° and 200°, showing `idle`, `idle`, `idle`,
    `idle`, `jog`, the first light attack at contact, `block` and `dodge` at contact.
  - `moves`: one rig for every row of the character's clip set, in rows of eight, each frozen at its
    `contact_s` (loops at 30% of their length) with the role as a label above it.
  - `cost`: the Drowned Hall with twelve rigs, two jogging and ten cycling through the light attacks.
    With vsync off it averages frame time over 150 frames with the rigs hidden, then shown, and prints
    `[characters] sheet=cost empty_ms=<a> full_ms=<b> added_ms=<b-a>`. It exits with code 1 when
    `added_ms` is above 1.5.
- [ ] **Step 2: Run the two picture sheets.** Run, for `turnaround` and then `moves`:
  `& ./.engine/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 2400x1000 res://game/characters/review/character_review.tscn -- --character=vanguard --sheet=turnaround --out="$PWD/tools/out/characters_pr1/turnaround.png" --profile=character_check`.
  Expected: exit code 0 and both pictures saved. Look at them: no limb twisted, the sword in the right
  hand, the shield on the left forearm, and every label has a figure in a distinct pose.
- [ ] **Step 3: Run the cost sheet** at the owner's resolution:
  `& ./.engine/Godot_v4.7.2-stable_win64_console.exe --path . -f --resolution 3440x1440 res://game/characters/review/character_review.tscn -- --character=vanguard --sheet=cost --profile=character_check`.
  Expected: a `[characters] sheet=cost` line with `added_ms` at most 1.5 and exit code 0. If it is above
  1.5, stop and report the numbers to the owner; do not loosen the budget.
- [ ] **Step 4: Run `test_scene_loads`.** Expected: PASS (the scene loads off-tree and its script compiles).
- [ ] **Step 5: Checkpoint.** Two new files; three pictures and one cost line under `tools/out/characters_pr1/`.

---

### Task 11: Docs, verification and handoff

**Files:**
- Modify: `AGENTS.md` (layout rows and the command), `README.md` (under "Develop and test"),
  `OPUS_HANDOFF.md` (this work's claim section)

- [ ] **Step 1: `AGENTS.md`.** Add layout rows for `game/characters` ("Character kit: rigs, animation
  drivers, import settings, review scene"), `art/characters` ("Character and clip definitions; build
  inputs, not scanned by Godot") and `tools/characters` ("Blender and Godot scripts behind
  `build_characters.ps1`"), and under Commands:
  `./tools/build_characters.ps1 -All   # rebuild characters (needs ./tools/fetch_character_tools.ps1 once)`.
- [ ] **Step 2: `README.md`.** Under "Develop and test" add the build command and the review command
  from Task 10, one line each.
- [ ] **Step 3: Full checks.** Run `pwsh ./tools/run_tests.ps1` (all pass) and
  `pwsh ./tools/soak.ps1 -Seconds 60` (both bots exit 0).
- [ ] **Step 4: Before-and-after pictures.** Confirm `arena_before.png` and `arena_after.png` from
  Task 9 are both under `tools/out/characters_pr1/` and show the same view.
- [ ] **Step 5: Update `OPUS_HANDOFF.md`:** what landed, the files, the cost numbers, and what is left
  for the Riftweaver and the enemies.
- [ ] **Step 6: Hand over to the owner** with the turnaround and moves sheets, the before-and-after
  pictures, the cost line and the test summary, and ask for a solo arena run and a two-window run through
  `launch_two.ps1`. Visual changes need the owner's review (AGENTS.md). Do not commit or open a pull
  request unless the owner asks.
