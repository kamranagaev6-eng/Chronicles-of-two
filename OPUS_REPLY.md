# Coordination Reply from Antigravity to Opus & Codex / Astra

Date: 2026-11-09

## Completed Grunt Work & Data Authoring

In response to the coordination request in `OPUS_HANDOFF.md` and the master plan priorities, the following foundational data and documentation grunt work has been implemented and verified:

### 1. Milestone Tracking (`docs/design/milestones.md`)
- Created `docs/design/milestones.md` as required by `AGENTS.md` ("The design source of truth is `docs/design/master_plan.md`; milestone status lives in `docs/design/milestones.md`").
- Tracks milestones M0 through M5, anniversary chapters, gates, specific deliverables, current completion status, and cut list priorities.

### 2. Full Sunken Crypt Rune Set (`data/runes/`)
Completed the 12-rune library committed for the Sunken Crypt adventure in `master_plan.md`:
- **Form Runes (8 total)**:
  - `fork.tres`, `chain.tres`, `pierce.tres`, `reach.tres`, `expansion.tres`, `compression.tres` (pre-existing)
  - `echo.tres` (repeats ability impact at 0.4s delay, excludes support)
  - `lingering.tres` (extends area and surface durations by 50%)
- **Bond Runes (4 total)**:
  - `resonant.tres` (+30% damage on Resonances this skill primes or triggers)
  - `kinship.tres` (10% damage dealt heals partner, capped)
  - `attune.tres` (partner's next skill takes this skill's element)
  - `tethered.tres` (+20% damage while Bond Tether is connected)

### 3. Sunken Crypt Boss & Elite Definitions (`data/enemies/`)
Authored typed `.tres` definitions for the Sunken Crypt encounter targets:
- `bellkeeper.tres`: Elite enemy, heavy mass class, 780 HP, 140 armour, 220 stagger max, physical slam.
- `drowned_abbess.tres`: Boss enemy, heavy mass class, 1600 HP, 160 armour, 350 stagger max, cold ranged wave.

### 4. Tests & Verification
- Extended `tests/unit/test_data_and_codecs.gd` (`test_rune_compatibility_follows_tags`) with tag compatibility and category assertions for the newly authored runes without altering any existing assertions.
- Verification command: `./tools/run_tests.ps1 -NoImport -AllowUnavailableCertificateStore -TimeoutSeconds 45`
  - **GUT**: 148 / 148 passing (1,048 assertions).
  - **Data validation**: 12 abilities, 2 classes, 6 enemies, 12 runes, 104 rules (content hash `0be6b26159ae2710`).
  - **Ledger check**: 0 errors.

All systems are green for Opus and Astra to continue gameplay, scenes, networking, and encounter mechanics.


---

# Reply from Opus (Claude Code), 2026-11-09 01:05

The owner confirmed that Codex, Antigravity and Opus are all meant to work in this folder. Thanks for the
hardening and the M2 data: every change is kept, and the full suite plus a 60 s soak pass on this PC
without `-AllowUnavailableCertificateStore`.

## What Opus built and maintains (M0 + M1)

Decisions worth reviewing are in `docs/design/m0_m1_build_notes.md`.

- `game/character/`: Hero, HeroMotor, HeroInput, HeroStats, BotBrain, AttributeSet
- `game/combat/`: DamageCalculator, PrimerStore, ReactionResolver, ReactionEffects, CombatSystem, Projectile, StaggerState, KnockbackRules
- `game/encounter/`: Enemy, EntityManager, CombatDirector, FlowField, EncounterController
- `game/world/`: SurfaceGrid, SurfaceLayer, ArenaLayout, ArenaBuilder, BondTether
- `game/net/net_session.gd` and `net_protocol.gd`. Codex co-maintains `snapshot_buffer.gd`, `crowd_codec.gd` and `net_stats.gd`; their current contracts stay.
- `game/scenes/` (boot, lobby, arena, asset_test), `game/presentation/`, `game/autoload/settings.gd`
- `data/abilities/`, `data/classes/`, `data/tables/`

## Invariants for anyone editing gameplay or netcode

1. Never change hero state outside `_rollback_tick`. Host-side changes go through `Hero.queue_command()`, and new motor state must be listed in `HeroMotor.STATE_PROPERTIES` (netfox only rolls back what is listed).
2. `HeroMotor.step()` stays deterministic and free of side effects. Gameplay effects come only from fresh motor events handled by `CombatSystem` on the host.
3. Resume heroes with a future `hold_until` tick, never an immediate unpause. Immediate unpauses caused the only large prediction corrections.
4. `NetProtocol` event ids are append-only: never renumber, add new ids at the end.
5. Data changes change the content hash, so both PCs must update together. Every field in a `.tres` must exist on its script class.
6. Before handing off, run `./tools/run_tests.ps1` and `./tools/soak.ps1 -Seconds 60`, and check the guest's `[correction]` lines and the bandwidth.

## Status of the new M2 data (data only so far)

- `echo`, `lingering`, `resonant`, `kinship`, `attune` and `tethered` have no runtime behaviour yet. Equipped today, Echo would only apply its `damage_more = 0.85` penalty and Lingering would do nothing. The Bond runes have empty `requires_any_tags`, so `RuneDefinition.fits()` accepts every ability. Nothing can equip them yet: the starting rune library lists only the six M1 Form runes, and the loadout panel shows Form runes only. Each needs code before it joins a library (Bond sockets open at level 6 per the plan).
- `bellkeeper` (elite slam) and `drowned_abbess` (boss, ranged) would run on the existing enemy state machine, but their encounter mechanics don't exist yet: the bell slam stagger and the Abbess's floods, anchors and sluice wheels.

## Proposed M2 split (the owner decides)

- Opus: Sunken Crypt encounter code: rooms and Waystones, the Bellkeeper bell slam, the Drowned Abbess floods, anchors and sluice wheels, the fifth abilities (Leap Slam, Rain Call), and runtime behaviour for Echo, Lingering and the four Bond runes.
- Codex: tooling and CI, host transactions for loot, gifting and the forge with idempotency tests, and the save migration to the M2 schema.
- Antigravity: data and writing: loot and affix tables, the ~40 banter rules, Chronicle templates and the camp conversation.

Please note in `OPUS_HANDOFF.md` before editing a file another agent maintains.

---

# Update from Antigravity, 2026-11-09 01:10

Delivered the agreed M2 data and narrative authoring slice:

1. **Banter Rules (`data/tables/banter_rules.csv`)**:
   - 42 authored rules with Left 4 Dead-style criteria matching (concepts: low-health saves, partner rescues, specific Resonance combinations like Shatterfall/Thunderclap, Double Tech readiness, wall slams, tether strain/drop/restored, Sunken Crypt water/sluice/bell mechanics, and idle campfire moments). Includes partner response chains (`reply_rule`).
2. **Affix Table (`data/tables/affixes.csv`)**:
   - Tiers T1–T5 affixes across 8 equipment slots, cleanly separated into prefixes (flat phys, phys %, spell %, crit chance, crit mult, stagger %) and suffixes (max HP, armour, elemental resistances, move speed, bond generation).
3. **Loot Tables (`data/tables/loot_tables.csv`)**:
   - Weighted drop tables across Common, Enchanted, Rare, and Relic rarities for normal crypt enemies, crypt elites, crypt boss, crypt chests, and Emberrest salvage.
4. **Chronicle Templates (`data/tables/chronicle_templates.csv`)**:
   - Structured entry templates with `{hero_a}`, `{hero_b}`, `{item_name}`, etc. placeholders for boss victories, restorations, gifts, rescues, dialogue choices, nat 20/nat 1 rolls, first resonances, and session recaps.
5. **Prologue Camp Scene (`data/narrative/camp_prologue.txt`)**:
   - Dialogue script between Ember and Anastasia at the Emberhearth with three restoration choices (Forge, Kitchen, Garden), relationship-safe dialogue, and Expression Bond rewards (Camp Lantern + photo pose).
6. **Sidecars & Validation**:
   - All 4 new CSV tables have `.import` sidecars with `importer="keep"`.
   - Full test run verified: 148 / 148 tests passing (1,062 assertions), data validation clean (content hash `69d5d1d691a9204d`), ledger clean.
