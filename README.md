# Chronicle of Two

A private two-player action RPG in **Godot 4.7.2**: host-authoritative online co-op over Tailscale
or LAN, the "Ember Storybook" look, and Resonance combat where one of you primes and the other
finishes. The design is in [`docs/design/master_plan.md`](docs/design/master_plan.md); what exists
today is in [`docs/design/milestones.md`](docs/design/milestones.md).

This build is **Milestone 0 (foundations) + Milestone 1 (the two-PC combat arena)** with
placeholder art: Dawn Vanguard + Riftweaver, three waves and an elite in the Drowned Hall.

## Requirements

- Godot 4.7.2 stable (win64). It lives in `.engine/` (ignored by Git). `tools/godot_path.ps1` finds it there, in `$env:GODOT`, or on `PATH`.
- PowerShell 7 for the tools.
- Add-ons are in the repo and pinned: GUT 9.7.1, netfox 1.35.3.

## Play

1. Both PCs run the same build (the join is refused otherwise).
2. One of you: **Host a game**. The lobby shows the addresses to share; the Tailscale `100.x` address works anywhere, the LAN one at home.
3. The other: type that address, **Join**, and save it as a favourite.
4. Pick your classes (either of you can play either; you can both pick the same), tick **Ready**, and the host starts the arena.
5. In the arena, hold **F** at the Waystone to start a wave. Waves checkpoint at the Waystone; a full clear is a victory.

Controls (rebind them in **Settings and assists**; controllers work too):

| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Move / aim | WASD / mouse | left stick / right stick |
| Basic attack (hold) | LMB | RT |
| Abilities 1-4 | RMB, Q, E, R | RB, LB, Y, LT |
| Dodge (2 charges) | Space | A |
| Shove | Shift | B |
| Interact / revive (hold) | F | X |
| Healing flask | 1 | D-pad up |
| Bond action (Hearthflare, both hold) | T | R3 |
| Ping | MMB or Z | D-pad down |
| Pause (shared) / loadout / help / network overlay | Esc / Tab / F1 / F3 | Start / Back |

**Combos:** the Riftweaver's **Glacial Spire** freezes (primer: Frozen) and the Vanguard's
**Shield Rush** shatters it (finisher: Impact) into **Shatterfall**. The Vanguard's **Lance of
Dawn** dazes (primer: Dazed) and the Riftweaver's **Arc Lance** detonates it into **Thunderclap**.
Your partner's primers show in their colour; an enemy you can detonate gets an outline and a chime.
Water freezes, oil burns, lightning electrifies whole pools, and enemies slammed into walls above
6 m/s become Dazed.

## Develop and test

```powershell
./tools/run_tests.ps1          # pinned-engine import, GUT (unit + integration), data validation, licence ledger
./tools/soak.ps1 -Seconds 90   # headless host + headless guest, both bots, over loopback; prints a report
./tools/launch_two.ps1         # host and guest windows side by side on this PC (separate profiles/saves)
```

Command-line switches (after `--`): `--host`, `--join=ADDRESS`, `--port=N`, `--solo`, `--profile=NAME`
(separate profile and saves), `--class=vanguard|riftweaver`, `--bot`, `--auto-ready`, `--quit-after=SECONDS`,
`--screenshot=PATH --screenshot-after=SECONDS`, `--scene=asset_test`.
For 80 ms +/- 20 ms and 2% loss, run [clumsy](https://jagt.github.io/clumsy/) alongside `launch_two.ps1`.

Rules for contributors and agents: [`AGENTS.md`](AGENTS.md).
