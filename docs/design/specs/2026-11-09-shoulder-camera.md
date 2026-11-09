# Shoulder camera — design spec

Date: 9 Nov 2026 · Status: awaiting owner review · Part 1 of the God of War overhaul

## Why

The owners want Chronicle of Two to play "like God of War": weighty combat, an over-the-shoulder camera,
cinematic finishers and a throw-and-recall weapon, on top of AAA-style physics. That overhaul is split
into seven parts, each with its own spec, plan and pull request (AGENTS.md: one system per PR):

1. **Shoulder camera** (this spec)
2. Hits and deaths: real launch arcs and air juggles on the host, landing slams, killing-blow ragdolls, directional flinches, debris
3. Hero movement: strafing while locked on, turn rate, momentum, stairs
4. Throw-and-recall weapon (and the hold-to-aim zoom it needs)
5. Living characters: rigged CC0 models, bone ragdolls, spring-bone capes and hair, foot IK
6. Cinematic finishers (needs part 5)
7. Reactive world: breakables, physics props, pulls

The camera comes first because every later part is tuned from it: launch heights, ragdoll throw
distances, finisher camera moves and throw aiming.

## Goals

- A close third-person camera behind the right shoulder, turned with the mouse or right stick.
- Camera-relative movement, God of War-style camera aim with soft-lock, and an optional lock-on.
- Readable fights from a low camera: a centre reticle and off-screen threat arrows.
- Each player chooses their own camera. The existing top-down camera stays, unchanged, as an option
  until both owners have played the shoulder camera and decided.

## Non-goals

- No change to `HeroMotor`, rollback state, netfox input properties, the host, or any network message.
  The host keeps receiving a world-space `move` vector and a world-space `aim` point, and never knows
  which camera a player uses.
- No hold-to-aim zoom (part 4), no strafing animation or turn-rate changes (part 3), no hit or physics
  changes (part 2).
- The asset test scene keeps the top-down camera.

## Player-facing behaviour

### Camera

- Sits behind the right shoulder: 4.5 m back, 0.7 m right, pivot 1.6 m above the hero's feet, 65° FOV.
  Pitch is clamped between 40° up and 60° down. These are starting values in `rules.csv`, to be tuned in
  play; God of War sits closer, but two heroes and crowds need more awareness.
- Follows the hero with light smoothing and keeps the existing trauma shake and its per-player slider.
- When world geometry is between the pivot and the camera, the camera pulls in (a `SpringArm3D` against
  the World layer only). When it is closer than 1 m to the hero, the local hero's meshes fade out through
  `GeometryInstance3D.transparency`.
- Mouse motion turns the camera (sensitivity and invert-Y are per-player settings). The right stick
  turns it at a base rate scaled by the same sensitivity.

### Movement and facing

- WASD and the left stick move relative to the camera's yaw. The rotation happens on the player's own PC
  before the input is sent, so `move` stays world-space.
- Facing is unchanged from today: the motor faces the movement direction, and faces the action
  direction (from `aim`) while acting.

### Aim

The reticle ray runs from the camera through the screen centre. `aim` resolves in this order, first
match wins:

1. The lock-on target's centre, while locked on.
2. The enemy whose capsule (definition `radius` and `height`) the reticle ray passes through, nearest first.
3. Soft-lock, when the aim assist is on (default on): the best enemy within 25° of the camera's flat
   forward and within 14 m, scored `angle × 10 + distance` as today's controller assist.
4. The reticle ray's hit on the World layer, or the point 30 m along the ray.

Enemy picking uses the positions the presentation already shows (`Presentation`'s enemy visuals), not
physics bodies. On the guest, enemies exist only as snapshot visuals with no colliders, so a physics
raycast would behave differently on the two PCs. Dead enemies, props and non-attacking dummies are
excluded, as `enemy_positions()` does today.

The aim-assist checkbox label changes from "Aim assistance (controller)" to "Aim assistance (soft-lock)",
since it now also governs the shoulder camera.

### Lock-on

- **Lock-on** (middle mouse / R3) toggles. Acquiring picks the visible, in-line-of-sight enemy within
  20 m with the smallest angle from the reticle (ties: nearest).
- While locked, the camera's yaw is steered to keep the target framed ahead of the hero; vertical input
  still adjusts pitch. Camera-relative movement then circles the target naturally.
- **Switching:** while locked, horizontal mouse motion accumulates; past 60 px it switches to the nearest
  enemy on that side of the screen and resets. The accumulator clears after 0.25 s without motion. A right
  stick flick past 0.8 does the same, once per flick.
- **Breaking:** if the target dies or despawns (generation change), lock moves to the nearest enemy
  within 10 m of the hero, otherwise it releases. It also releases beyond 25 m or after 2 s out of line
  of sight.
- Lock-on state lives only in the local camera rig. Only the resulting `aim` point is sent.

### Readability

- **Reticle:** a small centre dot that becomes a ring while over an enemy or locked on. Shoulder mode only.
- **Threat arrows:** for each live enemy telegraph whose shape covers the local hero's position
  (`Presentation.telegraph_threatens()`) while the enemy is off-screen or behind the camera, an arrow sits
  on a ring around the screen centre, pointing toward that enemy. Colour by the enemy's `attack_kind`
  group (melee, ranged, heavy). The pulse speeds up as the telegraph's remaining ticks run out. The
  screen-edge maths reuses the partner arrow's approach, including the behind-camera flip. Both modes
  show threat arrows.
- Ground telegraphs, the partner arrow and the telegraph-emphasis assist are unchanged.

### Controls

| Action | Keyboard and mouse | Controller | Change |
| --- | --- | --- | --- |
| Lock-on (new) | Middle mouse | R3 | New action `lock_on` |
| Ping | Z | D-pad down | Loses middle mouse |
| Bond action | T | L3 | Was R3 |
| Turn camera (shoulder) | Mouse | Right stick | Right stick reuses the `aim_*` actions |

Defaults change only. Saved custom bindings are kept as they are. Every action stays rebindable, and the
F1 help lists the new action automatically from `Settings.ACTION_LABELS`.

### Mouse capture

In shoulder mode the mouse is captured during play and released while any of these is true: the pause
panel, help, or loadout panel is visible; the window is unfocused. The arena checks this each frame via
`Hud.wants_mouse()` and the rig applies it. Top-down mode never captures the mouse.

### Settings

New per-player options in the boot menu's Settings panel: camera mode (Shoulder by default, Top-down),
mouse sensitivity (0.25–3.0, default 1.0) and invert Y (off). Settings live only in the boot menu today,
so a camera-mode change applies the next time the arena loads; sensitivity and invert Y apply at once.

## Architecture

```
GameCamera (Node3D, new base)           shared: camera, target, trauma shake, snap_to()
├── CameraRig (existing, top-down)      move_yaw() = 0, aim_point() = today's cursor/stick logic
└── ThirdPersonRig (new)                orbit, spring arm, reticle aim, soft-lock, lock-on
CameraMath (RefCounted, new, static)    all decisions as pure functions, unit-tested headless
```

### `GameCamera` — `game/presentation/game_camera.gd`

- `camera: Camera3D`, `target: Node3D`, `trauma: float`
- `add_trauma(amount: float) -> void`, `snap_to(pos: Vector3) -> void` (moved up from `CameraRig`)
- `move_yaw() -> float`: yaw that camera-relative "forward" maps to; 0 means world axes
- `aim_point(origin: Vector3, move: Vector2) -> Vector3`: world aim point for this tick
- `wants_captured_mouse() -> bool`
- Subclasses compose their position, then call the shared `_apply_shake()`.

### `CameraRig` (top-down) — `game/presentation/camera_rig.gd`

Extends `GameCamera`. Behaviour is identical to today. The cursor-to-ground-plane maths, stick aim,
move-direction fallback and controller assist move here from `HeroInput._compute_aim()` and
`_assisted()` without changing their results. `aim_source` stays for its cursor lead.

### `ThirdPersonRig` — `game/presentation/third_person_rig.gd`

Extends `GameCamera`. Owns yaw, pitch, the `SpringArm3D`, the reticle state and lock-on state. It reads
mouse motion in `_unhandled_input` and the right stick in `_process`. It gets targets from
`Presentation.enemy_targets()` and line of sight from a World-layer `PhysicsRayQueryParameters3D`
(World geometry exists on both PCs). It exposes `locked_target_id() -> int` and
`reticle_over_enemy() -> bool` for the HUD.

### `CameraMath` — `game/presentation/camera_math.gd`

Static, side-effect-free functions. They take plain values (`Target` objects with id, generation, centre,
radius, height and attack kind) and never touch nodes or physics:

- `camera_relative(move: Vector2, yaw: float) -> Vector2`
- `orbit_offset(yaw: float, pitch: float, distance: float, shoulder: float) -> Vector3`
- `clamp_pitch(pitch: float, min_deg: float, max_deg: float) -> float`
- `ray_capsule_hit(origin: Vector3, dir: Vector3, t: Target) -> float` (distance, or -1)
- `pick_under_reticle(origin: Vector3, dir: Vector3, targets: Array) -> int`
- `soft_lock(origin: Vector3, forward: Vector3, targets: Array, max_angle: float, max_range: float) -> int`
- `resolve_aim(lock: Variant, reticle: Variant, soft: Variant, ray_point: Vector3) -> Vector3`
- `acquire_lock(forward: Vector3, origin: Vector3, targets: Array, max_range: float) -> int` (caller pre-filters visibility)
- `switch_lock(current: int, side: int, cam_basis: Basis, origin: Vector3, targets: Array) -> int`
- `lock_should_release(dist: float, unseen_s: float, break_dist: float, unseen_limit_s: float) -> bool`
- `threat_arrow(screen_pos: Vector2, behind: bool, viewport: Vector2, radius: float) -> Vector2`

### Changes to existing code

- `HeroInput`: `camera: Camera3D` becomes `rig: GameCamera`. `_gather()` sets
  `move = CameraMath.camera_relative(raw_move, rig.move_yaw())` and `aim = rig.aim_point(origin, move)`.
  Bots still bypass this. `INPUT_PROPERTIES` and the netfox contract do not change.
- `Presentation`: adds `enemy_targets() -> Array[CameraMath.Target]`; `camera_rig` is typed `GameCamera`.
- `Arena`: builds `ThirdPersonRig` or `CameraRig` from `Settings.option("camera_mode")`, passes the rig to
  the local `HeroInput`, applies mouse capture each frame, and routes `lock_on` presses to the rig.
  `arena.camera()` keeps returning the active `Camera3D`, so the partner arrow keeps working.
- `Hud`: adds `wants_mouse() -> bool`, the reticle and the threat-arrow layer.
- `HeroVisual`: adds `set_fade(amount: float)` for the near-camera fade.
- `Settings`: new defaults (`camera_mode`, `mouse_sensitivity`, `invert_y`), the `lock_on` action and the
  ping and bond default changes.
- `boot.gd`: the three new settings controls and the assist label change.

## Data

New rows in `data/tables/rules.csv`, beside the existing camera rows:

| key | value | unit |
| --- | --- | --- |
| `camera_tp_distance_m` | 4.5 | m |
| `camera_tp_shoulder_m` | 0.7 | m |
| `camera_tp_pivot_height_m` | 1.6 | m |
| `camera_tp_fov_deg` | 65 | deg |
| `camera_tp_pitch_up_deg` | 40 | deg |
| `camera_tp_pitch_down_deg` | 60 | deg |
| `camera_tp_mouse_deg_per_px` | 0.15 | deg |
| `camera_tp_stick_deg_s` | 180 | deg/s |
| `camera_tp_fade_m` | 1.0 | m |
| `aim_ray_max_m` | 30 | m |
| `softlock_angle_deg` | 25 | deg |
| `softlock_range_m` | 14 | m |
| `lockon_range_m` | 20 | m |
| `lockon_break_m` | 25 | m |
| `lockon_unseen_s` | 2 | s |
| `lockon_retarget_m` | 10 | m |
| `lockon_switch_px` | 60 | px |
| `lockon_switch_reset_s` | 0.25 | s |
| `lockon_stick_flick` | 0.8 | fraction |

The top-down assist's 25° and 14 m become `softlock_angle_deg` and `softlock_range_m`, so there's one
source for both cameras. This changes the content hash, so both PCs must update together.

## Edge cases

- **Headless or no camera** (soak bots, `--bot`): bots bypass the rig as today. If a non-bot `HeroInput`
  has no rig, `move` passes through unrotated and `aim` falls back to the movement direction.
- **Hero downed or dead:** the camera keeps following; lock-on releases.
- **Shared pause, loadout, help:** mouse released and camera input ignored; lock-on persists.
- **Reconnect / arena reload:** the rig is rebuilt from settings; lock-on starts empty.
- **Target id reused by a respawn:** lock-on keys on id and generation, so a new spawn never inherits it.
- **Camera inside geometry at spawn:** the spring arm resolves on the first frame; `snap_to` skips smoothing.

## Testing

Unit (GUT, headless, `tests/unit/test_camera_math.gd`):
- `camera_relative`: yaw 0 is identity; yaw 90° maps W to world −X; length is preserved.
- Pitch clamp at both limits; `orbit_offset` puts the camera behind and right of the pivot.
- `ray_capsule_hit`: hits through the centre, misses beside, respects height, picks the nearest of two.
- `soft_lock`: in-cone beats out-of-cone, range limit, the existing scoring.
- `resolve_aim`: each priority level wins over the ones below it.
- Lock-on: acquire picks the smallest angle within range; switching picks the nearest on the requested
  side and stays put when there's none; release at the break distance and the unseen limit.
- `threat_arrow`: on-screen inputs aren't drawn; the behind-camera flip; the arrow stays inside the margin.

Integration (`tests/integration/`):
- The arena instantiates and runs ticks in both camera modes.
- Top-down regression: `CameraRig.aim_point` returns what today's `HeroInput._compute_aim` returns on the
  headless fallback path, and `move` passes through unchanged at yaw 0.
- The scene-load smoke test covers the new scripts. Data validation covers the new rules.

Soak: `./tools/soak.ps1 -Seconds 60` reports no increase in guest corrections (bots bypass the camera, so
any change would mean the input contract moved).

Manual (required by AGENTS.md before this counts as done): both owners play the shoulder camera on their
own PCs with mouse and controller: lock-on, switching, wall pull-in, the fade, threat arrows from behind,
the Riftweaver hitting what's under the reticle, and menus releasing the mouse.

## Docs

- `master_plan.md`: replace "Each PC has its own camera at about 50° pitch with a cursor offset" with the
  per-player shoulder/top-down choice.
- `milestones.md`: add the God of War overhaul parts.
- `README.md`: controls table (lock-on, ping, bond, camera).
- `OPUS_HANDOFF.md`: note the `HeroInput` and `Settings` changes for the other agents.

## Acceptance

- Both modes are playable. Top-down aims and moves exactly as before; its only visible change is the
  threat arrows.
- No network message, input property or motor state changes. The soak is unchanged.
- All new decisions live in `CameraMath` with passing unit tests, and the full `./tools/run_tests.ps1` passes.
- Both owners have played it and signed off.
