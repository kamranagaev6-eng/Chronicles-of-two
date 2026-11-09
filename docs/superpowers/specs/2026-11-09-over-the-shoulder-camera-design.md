# Over-the-shoulder camera and controls — design

Date: 2026-11-09 · Status: approved in conversation, awaiting written-spec review

## Context: the visual overhaul this belongs to

The owner asked for "AAA graphics" and settled the direction through brainstorming:

- **Photoreal**, replacing the master plan's stylized "Ember Storybook" look.
- **Inspired by the qualities of God of War**: a cinematic realistic look, weighty combat, a close
  over-the-shoulder camera, and epic set pieces and bosses. Inspiration only: the world, heroes, enemies
  and art stay Chronicle of Two's own.
- **Asset policy unchanged**: CC0 plus our own work. Realistic characters will come from Blender + MPFB
  (MakeHuman, CC0 output) later.

The overhaul is split into sub-projects, each with its own spec, plan and review:

1. **Over-the-shoulder camera and controls** (this spec), prototyped on the current graybox.
2. Render pipeline and photoreal Drowned Hall, built for the close camera (taller rooms, ceilings, detail).
3. Realistic characters and animation.
4. Combat feel and VFX.
5. Set pieces and bosses, with the M2 Sunken Crypt encounter work.

The camera comes first because it decides what the environment must look like.

## Goal

Replace the fixed top-down camera (about 50° pitch, cursor aim on the ground plane) with a close
third-person camera behind the hero's right shoulder, with free aim through a crosshair and a lock-on.
The top-down camera is removed, not kept as an option.

## Non-goals

- No new art, lighting or materials. The graybox stays, so looking up shows the dark void above the
  3.2 m walls until sub-project 2.
- No change to the Combat Director or any host-side rule about which enemies may attack. If hits from
  behind feel unfair in playtest, that is a separate follow-up.
- No change to the network message format, snapshots, the bot or host combat.
- No backpedal speed penalty, camera-distance slider or cinematic camera moves.

## How it plays

### Camera

- Pivot 1.55 m above the hero's feet, 0.55 m to the right; boom length 3.6 m.
- Mouse or right stick orbits the camera. Pitch is limited from 40° looking down to 25° looking up.
- A `SpringArm3D` pulls the camera in when walls or props are in the way. It collides with the World (1)
  and Props (4) layers only, never heroes or enemies.
- Default vertical field of view 58°. Godot keeps height, so the 3440×1440 ultrawide gets extra width.
  (The chat summary said "65°"; 58° vertical is about 90° horizontal at 16:9 and is the starting value.
  The FOV slider and data row make it a playtest decision.)
- Trauma-based shake stays, with the existing per-player slider.
- The mouse is captured only while the game window has focus and no pause, loadout or help panel is
  open. This keeps `launch_two.ps1` usable with two windows on one PC.

### Moving

- WASD and the left stick are camera-relative: forward runs where the camera looks.
- Not locked on: the hero faces the way they run, and turns to the aim when an action starts (the
  existing motor rule).
- Locked on: the hero strafes, facing the target, unless an action or dodge sets the facing.

### Aiming

- A small crosshair sits at screen centre; actions aim at the point under it.
- The aim ray starts at the camera, passes through screen centre and reaches at most 40 m. It is
  resolved on the local PC by taking the nearest of:
  - a physics ray against World and Props, and
  - an analytic sphere test (radius 0.6 m, at each enemy's centre of mass) against the enemies the
    presentation shows. Analytic because the guest has no enemy physics bodies; host and guest must
    aim the same way.
  - With no hit, the point 40 m along the ray, projected onto the floor plane at the hero's height.
- Ground-targeted spells (Glacial Spire) land on the floor point under the crosshair; range clamps stay
  as they are in the motor and ability code.
- The controller's soft aim assist (`HeroInput._assisted`) still applies to crosshair aim when not
  locked on.

### Lock-on

- Lock-on picks the enemy closest to the crosshair inside a 30° half-angle cone and within 20 m.
- While locked:
  - The camera eases its yaw toward the target (turn rate 8 per second) and its pitch toward 15°
    looking down.
  - The aim point is the target's centre of mass.
  - The crosshair is replaced by a reticle on the target.
- A sideways look input of at least 6° within 0.2 s switches to the next target on that side, ordered by
  angle around the camera. With no candidate on that side, the lock stays on the current target (no
  wrap-around).
- The lock breaks:
  - when the target dies or despawns,
  - when its spawn generation changes,
  - beyond 26 m,
  - or when the button is pressed again.
- Lock-on runs only on the local PC. The host sees only the resulting aim point and the strafe bit.

### Controls (all rebindable)

| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Look | mouse | right stick |
| Lock-on (new) | middle mouse | R3 |
| Ping | Z (loses middle mouse) | D-pad down |
| Bond action | T | L3 (moves from R3) |

Bindings a player has already saved are kept as they are.

### Readability for a close camera

- **Off-screen threat chevrons.** While an enemy telegraph is active within 15 m of the local hero and its
  centre is outside the view or behind the camera, a red-orange chevron points to it from the screen
  edge, growing as the telegraph fills.
- **Partner marker.** The existing off-screen partner arrow (`Hud._draw_arrow`) stays, using the shared
  edge-placement helper.
- **Telegraph rims.** Every floor telegraph gets a 0.35 m glowing wall along its outline (circle, cone
  or line), fading upward, so it reads from a low angle. Telegraph colour and draw priority are unchanged.

### New settings (per player, `options.json`)

| Option | Default | Range |
| --- | --- | --- |
| `mouse_sensitivity` | 1.0 | 0.2–3.0 |
| `stick_sensitivity` | 1.0 | 0.2–3.0 |
| `invert_y` | false | — |
| `fov` | 58 | 45–75 |

They appear in the boot menu's Settings panel.

## How it's built

The rule that keeps this safe: **everything camera-related runs on the local PC and still produces the
two values `HeroInput` sends today**, a world-space `move` and a world-space `aim` point. The host never
reads a camera (the master plan's rule that host gameplay never depends on a camera).

### Components

| Unit | Kind | Responsibility |
| --- | --- | --- |
| `game/presentation/camera_rig.gd` `CameraRig` | rewritten | Orbit state (yaw, pitch), `SpringArm3D` collision, shoulder offset, lock-on framing, trauma shake. Public: `target`, `snap_to()`, `add_trauma()` (unchanged signature), `look(delta_yaw, delta_pitch)`, `yaw()`, `centre_ray() -> [origin, dir]`, `lock_target_position()`. Drops `aim_source` and the cursor lead. |
| `game/presentation/camera_math.gd` `CameraMath` | new, static, pure | `camera_relative_move(raw: Vector2, yaw: float) -> Vector2`, `clamp_pitch()`, `apply_invert()`, `framing_yaw(from, to) -> float`. |
| `game/character/lock_on.gd` `LockOn` | new, RefCounted, pure | Holds the locked key (entity id + spawn generation). `pick(candidates, ray_origin, ray_dir) -> key`, `switch(candidates, side) -> key`, `should_break(candidates, hero_pos) -> bool`, `feed_look(delta_yaw_deg, now_s) -> side` (flick detection). Candidates are plain data: key → centre-of-mass position. |
| `game/presentation/screen_edge.gd` `ScreenEdge` | new, static, pure | Edge placement for an off-screen or behind-camera point, extracted from `Hud._draw_arrow`. |
| `game/presentation/telegraph_rim.gd` `TelegraphRim` | new, static | `outline(shape, radius, half_arc, length, segments) -> PackedVector2Array` (pure) and `build_mesh(outline, height) -> ArrayMesh`. |
| `game/presentation/shaders/telegraph_rim.gdshader` | new | Unshaded, alpha fading with height, brightening with `progress`. |
| `HeroInput` | changed | `move` = `CameraMath.camera_relative_move(raw, rig.yaw())`. `aim` = lock target position or the crosshair resolution above. Sets `BTN_STRAFE` in `held` while locked. Right stick no longer aims; it feeds `CameraRig.look()`. The bot path is untouched. |
| `HeroMotor` | changed, one rule | In the facing block: after the action and dodge branches, if not downed and `held & BTN_STRAFE` and the flat direction to `inp.aim` is non-zero, face it; otherwise the existing move-direction rule. Deterministic, no side effects. |
| `GameTypes` | changed | `BTN_STRAFE := 8`. |
| `Presentation` | changed | `enemy_targets() -> Dictionary` (key → centre-of-mass position for alive, shown enemies, keyed so a respawn makes a new key) and `active_telegraphs() -> Array` (centre, progress) for the HUD. Telegraph creation attaches the rim mesh as a child, so it shares transform and lifetime. |
| `Hud` | changed | Crosshair, lock reticle, threat chevrons; `_draw_arrow` uses `ScreenEdge`. |
| `Settings` and `boot.gd` | changed | `lock_on` action; ping and bond defaults as in the controls table; the four new options and their controls. |
| `arena.gd` and `asset_test.gd` | changed | Wire the new rig and mouse capture (captured when focused and no overlay is open). |

### Data (`data/tables/rules.csv`)

- Removed: `camera_pitch_deg`, `camera_cursor_offset` (only `CameraRig` reads them today).
- Changed: `camera_distance_m` 14 → 3.6 (boom length; same meaning, distance from the follow point).
- Added:

| ID | Value | Unit |
| --- | --- | --- |
| `camera_pivot_height_m` | 1.55 | m |
| `camera_shoulder_offset_m` | 0.55 | m |
| `camera_pitch_min_deg` | -40 | deg |
| `camera_pitch_max_deg` | 25 | deg |
| `camera_fov_default_deg` | 58 | deg |
| `camera_mouse_deg_per_px` | 0.12 | deg/px |
| `camera_stick_deg_per_s` | 180 | deg/s |
| `camera_lockon_turn_rate` | 8 | 1/s |
| `camera_lockon_pitch_deg` | -15 | deg |
| `aim_ray_max_m` | 40 | m |
| `aim_enemy_radius_m` | 0.6 | m |
| `lockon_range_m` | 20 | m |
| `lockon_break_m` | 26 | m |
| `lockon_cone_deg` | 30 | deg |
| `lockon_switch_deg` | 6 | deg |
| `lockon_switch_window_s` | 0.2 | s |
| `threat_indicator_range_m` | 15 | m |

The content hash changes, so both PCs must update together (existing rule). The telegraph rim height
(0.35 m) is a cosmetic constant in `TelegraphRim`, like the other presentation-only constants.

### Network and rollback

- `INPUT_PROPERTIES` and the wire format are unchanged. `held` carries one new bit value.
- Prediction replays recorded input, so camera state never enters rollback.
- `HeroMotor.step()` stays deterministic and free of side effects.
- No new motor state, so `STATE_PROPERTIES` is unchanged.

### Docs

- `docs/design/master_plan.md`:
  - "Controls and feel": keyboard and mouse becomes "WASD, mouse look, crosshair aim, lock-on"; the
    controller becomes "move and look sticks, lock-on, soft aim assist".
  - "Two screens": "about 50° pitch with a cursor offset" becomes "a close over-the-shoulder camera".
  - The Art section's photoreal rewrite belongs to sub-project 2's spec, not this one.
- `README.md` controls table: look, lock-on, ping and bond rows.
- `OPUS_HANDOFF.md`: a short note that controls, the `rules.csv` hash and `HeroMotor` facing changed.

## Delivery: two pull requests

1. **Camera and controls**: `CameraRig`, `CameraMath`, `LockOn`, `HeroInput`, the `HeroMotor` strafe
   rule, `GameTypes`, `Settings` and the boot menu, the crosshair and lock reticle, data rows, arena and
   asset-test wiring, docs.
2. **Readability**: `ScreenEdge` (with `_draw_arrow` moved onto it), threat chevrons, `TelegraphRim` and
   its shader.

## Testing

**New GUT unit tests** (`tests/unit/`):

- `test_camera_math.gd`:
  - camera-relative movement at yaw 0°, 90°, 180° and −90°
  - zero input stays zero
  - pitch clamps at both limits
  - invert-Y flips only pitch
- `test_lock_on.gd`:
  - picks the candidate nearest the crosshair inside cone and range
  - ignores candidates behind the camera or beyond 20 m
  - switches left and right in angular order, and stays on the current target when none is on that side
  - flick detection needs the 6° and 0.2 s thresholds
  - breaks on a missing key, a new generation key, and beyond 26 m
- `test_screen_edge.gd`:
  - an on-screen point is reported as on-screen
  - off-screen points land on the margin rectangle in the right direction
  - behind-camera points are mirrored
- `test_telegraph_rim.gd`:
  - circle outlines are closed with the requested segment count at the given radius
  - cone outlines include the apex and both edges at ± the half-arc
  - line outlines are the rectangle
- `test_hero_motor.gd` (new cases only):
  - with `BTN_STRAFE`, yaw follows the aim while moving
  - without it, yaw follows movement
  - an active action still sets yaw from the action direction
  - downed heroes ignore strafe
  - two identical step sequences give identical state

**Unchanged:**

- Every existing test passes with its expected values untouched.
- The scene-load smoke test passes.
- `./tools/run_tests.ps1` passes.
- `./tools/soak.ps1 -Seconds 60` shows no new `[correction]` lines and similar bandwidth to before.

**Human review (AGENTS.md):**

- Screenshots via `--screenshot`.
- The owner plays solo with mouse and with a controller:
  - orbiting, wall collision and the pitch limits
  - crosshair spells, including Glacial Spire placement
  - lock-on picking, switching and breaking, and strafing
  - threat chevrons, the partner marker and telegraph rims
- Then a two-window run through `launch_two.ps1`.

## Risks

- **Running toward the camera turns the hero around** when not locked on. This is normal for this camera
  style; judge it in playtest.
- **Floor telegraphs at a low angle** may still be hard to read through crowds even with rims. The
  chevrons cover off-screen threats; on-screen readability is judged in playtest.
- **Enemies attacking from behind** may feel unfair without Combat Director changes; this is deliberately
  deferred (see non-goals).
- **Mouse capture with two windows on one PC.** Capture is tied to window focus; verify with
  `launch_two.ps1`.
