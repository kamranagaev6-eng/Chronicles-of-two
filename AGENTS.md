# Chronicle of Two — agent rules

Private two-player action RPG in **Godot 4.7.2** (typed GDScript). The design source of truth is
`docs/design/master_plan.md`; milestone status lives in `docs/design/milestones.md`.
The owner's action-adventure direction (`docs/design/direction_action_adventure.md`) overrides the plan where they conflict.

## Hard rules

- Godot **4.7.2** and the pinned add-ons only: GUT 9.7.1 (`addons/gut`), netfox 1.35.3 (`addons/netfox`).
  Never Godot 3 APIs: KinematicBody → CharacterBody3D, Spatial → Node3D, yield → await,
  export → @export, onready → @onready, instance() → instantiate(), string connect() → signal.connect(callable).
- Static typing everywhere (`var x: int`, typed arrays, typed returns). Warnings for untyped code are errors in review.
- Every gameplay number lives in `/data` (CSV tables or `.tres` definitions) with a stable content ID and
  one source of truth per definition. Never keep the same definition in two formats.
- The host owns shared gameplay. Never apply damage, roll loot, change progression or write the campaign
  save on a client. Clients send commands; the host emits results.
- Prediction and replay code (`_rollback_tick`, `HeroMotor`) is free of side effects: no damage, no loot,
  no sounds, no spawning. Effects are emitted once, after the tick loop, by host systems.
- Network messages carry stable IDs and plain data (ints, floats, strings, arrays, dictionaries,
  PackedByteArray) — never Resources, scene paths, object instances or executable commands.
- Every system ships with tests run through `godot --headless` (GUT), plus the scene-load smoke test.
  Never change a test's expected values just to make it pass.
- Commit `.import` sidecar files (they are source configuration) but change import settings only through
  the editor. Data CSVs must use the **Keep File** importer. Never commit `.godot/`.
- Every file under `/assets` needs a row in `docs/license_ledger.csv` (CC0 or original work; anything else
  needs a written yes from the owners). Software/add-on licences go in `docs/software_licenses.csv`.
- One system per pull request; a human reviews every visual change.

## Layout

| Path | What lives there |
| --- | --- |
| `game/core` | Shared enums, tick math, pseudo-random distribution |
| `game/data` | Typed definition Resources and CSV loaders (`GameData` autoload) |
| `game/combat` | Damage formula, primers/Resonance, stagger, knockback, abilities, projectiles |
| `game/character` | Hero node, deterministic `HeroMotor`, input gathering, hero stats |
| `game/world` | Surface grid, Bond Tether, Waystones, props |
| `game/encounter` | Enemies, AI, Combat Director, flow fields, encounter waves |
| `game/net` | Session (host/join/pause/reconnect), message codecs, snapshots, net stats |
| `game/progression` | Campaign save store, migrations, transactions |
| `game/presentation` | Camera, HUD, hit feel, SFX, VFX, overlays |
| `game/scenes` | Boot menu, lobby, M1 arena, M0 asset test scene |
| `data/` | `tables/*.csv` (tabular data) and `abilities|classes|enemies|runes/*.tres` (definitions) |
| `tests/` | GUT tests (`unit/`, `integration/`) |
| `tools/` | Ledger checker, data validator, test runner, two-instance launcher, soak test |
| `docs/godot_api/` | Godot 4.7 class reference generated with `--doctool`: search it for real APIs |

## Commands (PowerShell, from the repo root)

```powershell
./tools/run_tests.ps1              # import, GUT, data validation, ledger check
./tools/launch_two.ps1             # host + guest windows on this PC
./tools/soak.ps1 -Seconds 60       # headless host + bot guest, reports corrections
```

The engine lives in `.engine/` (ignored by git and Godot). `tools/godot_path.ps1` resolves it.
