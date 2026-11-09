# M0 + M1 build notes (Opus)

Companion to `milestones.md`. It records what this build verified, what it didn't, and the decisions
made while building that the two of you should review. Written 9 Nov 2026.

## Verified

- `./tools/run_tests.ps1`: import, every GUT test (unit + integration), data validation and the licence ledger pass.
- `./tools/soak.ps1 -Seconds 60`: a headless host and a headless guest, both bots, on loopback. They play full
  three-wave victories (including the Drowned Knight elite) with Resonances, Basic reactions, wall slams and
  token-leak reclaims, and no script errors. Guest prediction: 0-1 reconciliations per minute, max 5 cm.
  Bandwidth 18-37 KB/s each way (target 40, ceiling 100).
- Windowed run on this PC (D3D12, RTX 2070 SUPER): host and guest screens render the arena, HUD, telegraphs,
  surfaces, frozen/stunned states and the partner arrow.

## Not verified yet

- Two physical PCs over Tailscale; 80 ms +/- 20 ms and 2% loss (run clumsy with `tools/launch_two.ps1`).
- Controller play, rebinding in practice, and frame times on the slower PC.
- The real look: all art is procedural placeholder, and all sound is synthesised placeholder.

## Decisions to review

| Decision | Why | Plan reference |
| --- | --- | --- |
| Action presses ride in the netfox input stream as sticky sequence numbers; the motor's 150 ms buffer decides when they start | A lost packet can't lose a press, and ability movement (Shield Rush, Blink) is predicted like dodge | "AbilityIntent ... reliable transactions" |
| Effects run on the host only, from fresh motor events; host changes to heroes enter a tick-stamped command queue inside the rollback tick | The host also resimulates late guest inputs, so changes made outside the rollback tick would be lost | "Prediction and replay code is free of side effects" |
| Enemy hits resolve on the target hero's own timeline (waiting up to 200 ms for the guest's input) | The guest's dodges count where they pressed them | Extends "Nothing punishes..." |
| netfox input broadcast is off | It halved bandwidth; the partner's hero still arrives as host state at 60 Hz | Network budget |
| Sessions start held until the guest loads; resumes happen at a future tick known to both PCs | It removed the only large prediction corrections seen | Movement correction target |
| Heroes and enemies don't physically block each other; enemies use separation steering | Keeps hero prediction exact | Predicted movement on static geometry |
| All enemies use 1 m flow fields, including the elite | Simpler v1; the plan gives elites NavigationServer3D | "elites use NavigationServer3D" |
| Basic attacks are Sword Strike and Rift Bolt; Resolve empowers finishers instead of gating them | The plan names the resource but not what spends it | Classes |
| The Bond meter and Hearthflare are on in the M1 arena | The arena is set at the end of the Prologue, when Double Techs unlock | Bond meter and Double Techs |

## Multi-agent note

Several agents edited this folder at the same time as this build (see `OPUS_HANDOFF.md` and `OPUS_REPLY.md`).
Before relying on any file, run `./tools/run_tests.ps1` and a soak, and review diffs once the folder is under Git.
