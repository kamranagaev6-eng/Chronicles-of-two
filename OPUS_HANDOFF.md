# Codex handoff for Opus

The owner asked Codex to implement alongside Opus. The changes below are complete, integrated and available for Opus to maintain. This shared file is the coordination channel; there is no direct messaging connection to the external Claude session.

## Snapshot playback and networking

- `game/net/snapshot_buffer.gd` is the single interpolation implementation. The temporary CrowdSnapshotBuffer file was removed when the concurrent implementations were consolidated.
- The arena's existing interface remains: `push(tick, entities, local_tick)`, `render_tick(local_tick)`, `sample(render_tick)`, `depth(render_tick)`, `clear()`, and `interp_ticks`. `depth()` returns retained history count. `sample_host_tick()` accepts an already synchronized host clock.
- Timing and retained capacity derive from existing data rules: `sim_tickrate`, `enemy_snapshot_hz`, `interpolation_buffer_s`. Arrival offsets are averaged over that bounded window.
- Duplicate/stale/malformed snapshots leave valid history intact. Tick rollover is handled. Position/yaw interpolation never blends different spawn generations or kinds. Discrete state, spawning and despawning advance at their snapshot timestamp. Empty full snapshots clear the crowd. Input and output objects cannot mutate history.
- `game/net/crowd_codec.gd` keeps the existing wire version/format and adds strict framing, ID uniqueness, field-range and finite-number validation.
- `game/presentation/presentation.gd` replaces visuals when spawn generation changes, and clears the old lifetime's telegraph and predicted-contact cache. The regression test reproduced an old enemy's hit-stop freezing a new spawn at the wrong position, and now passes.
- `game/net/net_stats.gd` fully resets session measurements and partial bandwidth windows, rejects invalid samples, safely ignores offline/unconnected peers, and preserves actual elapsed-time bandwidth accounting.

New coverage for this work: 9 codec tests, 25 buffer tests, 3 arena/presentation integration tests, and 10 network-stat tests. Existing gameplay test expectations were not changed.

## Earlier validation/tooling contribution

- `tools/run_tests.ps1`: pinned engine/add-on checks; isolated test profiles; process timeouts; engine-diagnostic checks even when exit code is zero; unique fresh JUnit evidence; per-run logs. It preserves the caller environment and shared GUT configuration.
- `tools/license_audit.gd`, `tools/check_ledger.gd`, and 12 licence tests: every file beneath assets is covered, including sidecars and hidden files; duplicate/stale entries and missing metadata fail; software licence records are checked separately.
- `tests/integration/test_scene_loads.gd`: authored resources and imported content load, scenes instantiate off-tree, all game scripts compile, the main scene exists, and data CSVs use Keep File.
- `tools/README.md`: commands and validation limits.
- Seven runner process controls and a real no-matching-tests GUT run verified that error/timeout/missing-report paths fail.

## Verified results — 2026-11-09

Full command executed:

```powershell
./tools/run_tests.ps1 -AllowUnavailableCertificateStore -TimeoutSeconds 45
```

- **148/148 GUT tests pass; 1,026 assertions.**
- Import, scene/resource smoke checks, data validation, and asset/software ledger checks pass.
- Data: 12 abilities, 2 classes, 4 enemies, 6 runes, 104 rules; content hash prefix `c6ab80d55a5c06b3`.
- Complete logs/report: `tools/out/runtime/c84c6ee97b4f465bbf46934c30b27db2/`.
- An isolated 60-second loopback host + guest bot run on port 24721 completed with both processes exiting 0 and no non-environment engine/script errors. It exercised 154 hits, 23 kills, 5 Resonances and 1 arena victory. The guest retained four crowd snapshots; displayed bandwidth at shutdown was about 18–21 KiB/s each way.
- Soak logs: `tools/out/codex-network-soak/ee4d95ba4dd24b07a825720f01660d56/`. Profiles/checkpoints are isolated beneath this ignored directory, separate from real saves.
- Generated `.gd.uid` sidecars are present for new scripts/tests. No changes to the Word plan or gameplay data were needed.

This workspace sandbox reports exactly `ERROR: Failed to read the root certificate store.`. The test runner's explicit `-AllowUnavailableCertificateStore` option excludes only that diagnostic; the isolated soak used the same narrow exception. Other engine errors still fail. Normal verification should leave the option off when certificate-store access works.

## Remaining review gates

- Human review of enemy respawn presentation is still required by AGENTS.md.
- The soak was local loopback, not evidence for 80/150 ms WAN latency targets or the two-PC performance budget.
- Off-tree smoke tests do not replace rendered boot, GPU shader, or manual input/visual checks.
- The earlier missing boot scene and stale shader ledger failures have been resolved by Opus's later work.


---

## Opus claim: M2 Sunken Crypt encounter slice (started 2026-11-09 01:15)

The owner approved Opus starting this slice. Opus is editing these files until this section says done:

- `game/world/`, `game/scenes/arena/`, `game/scenes/lobby/`, `game/encounter/`, `game/combat/`, `game/character/`, `game/presentation/`
- `data/abilities/`, `data/classes/`, `data/tables/{rules,encounter_waves,expedition_rooms,surface_reactions}.csv`
- `data/runes/{echo,lingering,resonant,kinship,attune,tethered}.tres` and `game/data/defs/rune_definition.gd` (adding runtime fields)
- `data/enemies/{bellkeeper,drowned_abbess}.tres` (tuning for the bell and flood mechanics)
- `game/core/game_types.gd` (adding the water element), `game/net/net_session.gd`, `game/net/net_protocol.gd` (append-only events)

Not touching: `tools/`, tests written by others, `game/net/{snapshot_buffer,crowd_codec,net_stats}.gd`, `docs/design/milestones.md`.

---

## Owner direction change (2026-11-09, recorded by Opus)

The owner wants an action-adventure feel in the spirit of God of War: over-the-shoulder camera, weighty
melee with finishers, throw-and-recall signature weapons, and exploration with puzzles and story. All
content stays original. The full direction is in `docs/design/direction_action_adventure.md`; where it
conflicts with `master_plan.md`, it wins. Please build your slices toward it (for example: banter that
fires during traversal, Chronicle pages as collectibles, loot that suits the new weapons).

Opus is implementing the camera, controls, light combos, heavy attack (replacing the shove), block and
parry, finishers and the throw-and-recall weapons now, then resuming the Sunken Crypt with throw puzzles.
The Opus claim above extends to `game/autoload/settings.gd` (new default bindings).

---

## Photoscan textures and materials (session "Realistic asset textures", 2026-11-09)

The owner approved CC0 photoscanned textures with layered weathering. This session maintains:

- `assets/textures/ambientcg/*`: 10 ambientCG CC0 sets at 1K. `tools/fetch_textures.ps1` downloads them and keeps only the maps used; `-LedgerOnly` rewrites their rows in `docs/license_ledger.csv` (asset ids start `acg_`), including the `.import` sidecars.
- `game/presentation/material_kit.gd` and `game/presentation/materials/*.tres`: build new visuals with `MaterialKit.surface(kind, tint, overrides)`, `MaterialKit.trim(accent)` and `MaterialKit.skin(color)` rather than flat colours. Ask here for a new surface kind.
- `game/presentation/shaders/pbr_triplanar.gdshader` and `ground_surface.gdshader`.
- Only the material lines in `proc_mesh.gd`, `arena_builder.gd`, `surface_layer.gd` and the `asset_test.gd` floor. The camera, combat, hero and enemy visuals, `presentation.gd`, `hud.gd` and the lighting/Environment in `arena_builder._lights()` belong to other sessions.
- Review scenes: `game/scenes/asset_test/arena_showcase.tscn` (the real Drowned Hall with every surface painted and the whole cast posed, fixed cameras 1-5 via `--showcase-camera=N`, independent of the gameplay camera) and `texture_gallery.tscn` (every material on a sphere; opening it in the editor marks new textures as 3D so they get mipmaps). The wall set is now Bricks113A (ashlar); Bricks108B was removed. `ArenaBuilder.pbr_material()` is no longer called, so it can go.
