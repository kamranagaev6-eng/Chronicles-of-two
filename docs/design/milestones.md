# Chronicle of Two — Milestone Status and Roadmap

Design source of truth: `docs/design/master_plan.md`  
Engineering rules: `AGENTS.md`  
Engine: Godot 4.7.2 stable (typed GDScript), GUT 9.7.1, netfox 1.35.3

---

## Milestone Overview & Gates

| Milestone | Target Window | Description | Gate / Acceptance Criteria | Status |
|---|---|---|---|---|
| **M0: Foundations** | Month 1 | Repo, AGENTS.md, GUT CI, data loaders, host/join, predicted movement, checkpoint mirroring, asset test scene. | Both PCs connect, movement is predicted, a checkpoint mirrors, chosen assets render. | **Complete** |
| **M1: Combat Arena** | Months 2–4 | Vanguard + Riftweaver, 4 abilities each, basic Form runes, surfaces, wall slams, downed/revive, Combat Director v1, Bond Tether v1, 2 enemy types + elite, hit feel, shared pause/reconnect. | 15 minutes at 80 ms and 2% loss without desync, and both want one more wave. | **Active / Substantially Complete** |
| **M2: The Sunken Crypt** | Months 4–9 | **First production commitment.** 45–60 min adventure: Bellkeeper elite, Drowned Abbess boss, levels 3–7, 12 runes, loot & gifting, forge & kitchen, small constellation, first Bond perks, Hearthflare, camp convo & ~40 banter lines, Chronicle, saves with migration. | Finish it, quit, and resume the next day with the other PC hosting. | **In Progress** |
| **M3: Act 1 Complete** | Months 12–24 | All four classes to level 12, Specialization Trial, Millrace Tunnels & Old Lighthouse, Forging Potential crafting, dice checks, co-op dialogue and voting, Act 1 Bond events, Emberrest growth. | All ten class pairings clear Act 1, and no class is required. | Planned |
| **M4: Acts 2–4** | Years 3–5+ | Remaining abilities, specializations, full rune library, expeditions and finales, one act at a time. | Per act: a fresh save reaches the finale and every choice carries forward. | Planned |
| **M5: Polish & Endgame** | After Act 4 | Feel, readability, accessibility, performance passes, Legend difficulty, challenge ranks, Memory Delves. | Repeated sessions stay stable, and you each find your next upgrade unaided. | Planned |
| **Anniversary Chapters** | Yearly | 2–4 hour chapter themed on your real year together. Level cap stays 40. | Small gifts during dev; full chapters post-M5. | Planned |

---

## Detailed Milestone Breakdown

### M0: Foundations
- [x] Repository setup, `.gitignore`, `.gitattributes`, `AGENTS.md`, and `CLAUDE.md`.
- [x] Pinned engine verification (`Godot 4.7.2.stable.official.ed1daf0bf`).
- [x] GUT 9.7.1 test harness with headless runner (`tools/run_tests.ps1`).
- [x] Typed `GameData` autoload and CSV loaders with Keep File importers.
- [x] Asset licence ledger (`docs/license_ledger.csv`) and verification script (`tools/check_ledger.gd`).
- [x] Software licence ledger (`docs/software_licenses.csv`).
- [x] Host/join session over Tailscale/LAN with network performance overlay.
- [x] CharacterBody3D motor with deterministic `_rollback_tick` predictions (`HeroMotor`).
- [x] Checkpoint state serialization, atomic writes, backup pruning, and ancestry validation (`CampaignStore`).
- [x] Asset test scene (`game/scenes/asset_test/asset_test.tscn`).

### M1: Combat Arena
- [x] Dawn Vanguard and Riftweaver class definitions with starting abilities (levels 1, 1, 2, 3).
- [x] Core combat calculations: single authoritative hit formula, mitigation, vulnerability caps, co-op caps (`DamageCalculator`).
- [x] Authoritative Resonance resolver: primer application, partner vs. own consumption, 4 s lockout, 16 signature reactions (`ReactionResolver`).
- [x] Elemental surface grid: 0.5 m cells, 10 Hz updates, water/ice/oil/burning/sanctified material reactions (`SurfaceGrid`).
- [x] Impact physics: knockback Δv = J/m, mass classes, wall-slam detection (≥6 m/s) with Dazed primer and momentum transfer (`KnockbackRules`).
- [x] Stagger system: separate stagger meters, elite 6 s stagger windows, diminishing returns, boss immunities (`StaggerState`).
- [x] Host-side Combat Director: melee and ranged token pools, unreachable slot skipping, 1 s leak audit (`CombatDirector`).
- [x] Bond Tether v1: cosmetic ribbon within 14 m, fading to 18 m, auto-reconnect (`BondTether`).
- [x] Packed crowd snapshot codec: 20 Hz encoding/decoding, generation tracking, yaw short-arc interpolation (`CrowdCodec`, `SnapshotBuffer`).
- [x] Downed and revive state machine: crawling, 2.5 s hold-to-revive, revive protection.
- [x] Enemy types in arena: Drowned Thrall, Crypt Archer, Drowned Knight elite, Training Dummy.
- [x] Basic Form runes for loadout customization (Fork, Chain, Pierce, Reach, Expansion, Compression).
- [x] Main boot menu with Tailscale/LAN hosting, settings, assists, solo practice, and automated soak testing (`tools/soak.ps1`).
- [ ] 15-minute two-PC live soak gate sign-off (80 ms RTT, 2% packet loss).

### M2: The Sunken Crypt (First Production Commitment)
- [ ] Adventure layout: Flooded Entrance → Drowned Chapel → Sluice puzzle → Bellkeeper Arena → Boss Antechamber → Drowned Abbess Crypt.
- [x] Elite definition: The Bellkeeper (`data/enemies/bellkeeper.tres`).
- [x] Boss definition: The Drowned Abbess (`data/enemies/drowned_abbess.tres`).
- [x] Complete 12-rune library for Sunken Crypt:
  - Form (8): Fork, Chain, Pierce, Reach, Expansion, Compression, Echo, Lingering.
  - Bond (4): Resonant, Kinship, Attune, Tethered.
- [ ] Universal interactables: Sluice wheels, braziers, water barrels, warding bells.
- [ ] Bellkeeper slam-into-bell stagger encounter logic.
- [ ] Drowned Abbess flood / anchor phases and stagger vulnerability.
- [ ] Personal loot drops, loot filtering, and "Offer to Partner" transactional gifting.
- [ ] Emberrest facilities: Campfire & tent, Forge & rune socketing table, Kitchen shared meal buff.
- [ ] Constellation prototype: small hero tree + Bond constellation first perks (e.g. Hearthflare default Double Tech).
- [ ] Banter system v1: Valve-style rule matcher with ~40 authored lines for Sunken Crypt.
- [ ] Chronicle journal entry generation from structured expedition events.

### M3: Act 1 Complete
- [ ] Shadowstrider (Momentum, Backstab/Mark, Precision finisher) and Verdant Warden (Verdance, Spirit Wolf, Primal finisher).
- [ ] Act 1 Expeditions: Millrace Tunnels (Sluicewarden) and Old Lighthouse (Tide-Bell Golem).
- [ ] Level 12 Specialization Trial and first specialization choices.
- [ ] Deterministic Forging Potential crafting system.
- [ ] Roleplay exploration dice checks (d20 + modifier + Help/Advantage + Inspiration).
- [ ] Two-player dialogue runner with voting and secret simultaneous picks.
- [ ] Camp Bond events C → B.

### M4: Acts 2–4
- [ ] Act 2: The Whispering Grove (Briarwood Maze, Hollow Oak, Moonwell Caverns). Levels 12–22.
- [ ] Act 3: Spire of Embers (Forge-Deeps, Glass Desert, The Spire). Levels 22–32.
- [ ] Act 4: Library of Ends (Floating Archive, Islands of Lost Pages, Library of Ends). Levels 32–40.
- [ ] Full 48 class abilities and remaining rune library (Technique runes, Infusion runes).

### M5: Polish, Accessibility & Endgame
- [ ] High/low settings parity: telegraph decals, input buffer tuning, assist modes.
- [ ] Audio pass: CC0 adaptive music layers, Foley, personal recorded banter.
- [ ] Memory Delves, challenge ranks, and Legend difficulty.

---

## Cut List Priority (If Schedule Slips)
1. Cosmetic destruction density and secondary physics.
2. Bespoke Double Tech animations (use shared Hearthflare).
3. Rally exchanges.
4. Procedural variation of rooms on replays.
5. Optional voice coverage.
6. Endgame modifiers, Memory Delves, and Legend difficulty.
7. Optional quests, side rooms, and repeated encounter variants.
8. The second specialization per class.
*Never cut: Responsive two-player combat, netcode foundations, reliable saves, downed/revive, hero growth, gifting, Emberrest, Bond events, Chronicle.*
