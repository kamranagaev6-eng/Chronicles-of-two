# Owner direction: action-adventure feel (9 Nov 2026)

The owner wants Chronicle of Two to feel like a cinematic action-adventure in the spirit of God of War:
an over-the-shoulder camera, weighty melee with finishers, a signature weapon you throw and call back,
and exploration with puzzles and a story told while you travel. Everything stays **original**: our own
heroes, world, story, names, art and music. We borrow kinds of mechanics, never content.

Where this conflicts with `master_plan.md`, this document wins. Everything else in the plan stands:
two equal heroes, Resonance (prime and finish), the Bond meter and Double Techs, surfaces and physics,
host authority, Emberrest, the Chronicle.

## Camera

- Each player has an **over-the-shoulder camera** behind their own hero (pivot at the shoulder, about
  3.8 m back, collision-aware), with mouse or right-stick look. Movement is camera-relative.
- Aiming uses a centre crosshair. Melee softly locks onto the enemy in front; a hard lock-on can be toggled.
- The plan's 50 degree overhead camera stays as an option in Settings (and for accessibility).

## Weighty melee and finishers

- **Light combos:** each class has a three-step light chain; the last step hits harder and knocks back.
- **Heavy attack:** slower, big stagger and knockback. It replaces the universal shove as the class-neutral
  physics push (into walls, hazards and the Belfry bell).
- **Block and parry:** hold to block frontal hits; pressing block just before a hit parries it, stunning the
  attacker and building Resolve. Every class can guard (the Vanguard with its shield, the Riftweaver with a
  rift ward); the Vanguard can't block while its shield is thrown.
- **Finishers:** a stunned enemy (full stagger meter) can be finished with Interact. Ordinary enemies die;
  Staggered elites and bosses take heavy damage. If both heroes finish the same Staggered elite or boss
  together, it's a **tandem finisher** (double damage, Bond meter). Finishers lock the hero briefly and make
  them invulnerable, and the camera frames the moment (presentation only).
- Hit feel goes up for heavy hits and finishers: longer hit-stop, camera punch, layered impacts.

## Signature throw-and-recall weapons

- **Vanguard: Oathshield.** Throw the shield: it Dazes what it hits (primer), pins ordinary enemies, and
  lodges in walls and mechanisms. Recall it: it flies back through enemies as an **Impact finisher**.
  While it's away, the Vanguard can't block.
- **Riftweaver: Rift Anchor.** Throw the anchor: it Freezes what it hits (primer) and freezes water around
  where it lodges. Recall it: it flies back through enemies as an **Arcane finisher**. While it's away, the
  Riftweaver's light attacks are weaker sparks.
- Throw primes and recall finishes, so your own throw-and-recall is a Basic reaction, while recalling
  through your partner's primers is a Resonance. Lodged weapons are puzzle tools: jam a gear to hold a gate,
  stop a water wheel, ring a bell, strike a distant rune.

## Exploration, puzzles and story

- Expeditions become connected spaces with side paths, breakable walls and secrets (Chronicle pages, runes).
- Puzzles use throws and both heroes: jam a mechanism so your partner can pass, freeze a wheel, hit targets
  from the right angle. Every mandatory puzzle can be solved by every class pairing.
- The story is told while you travel: banter between the two heroes, short in-engine moments at room
  thresholds, and Chronicle pages. The camera never cuts away during play.

## Controls (defaults, all rebindable)

| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Look / move | mouse / WASD | right stick / left stick |
| Light / heavy attack | LMB / RMB | RB / RT |
| Block (hold), parry (tap just before a hit) | Shift | LB |
| Abilities 1-4 | Q, E, R, C | D-pad up, right, down, left |
| Throw / recall | G | Y |
| Dodge | Space | A |
| Interact, revive, finisher | F | X |
| Lock-on | Tab | R3 |
| Flask / Bond action / ping | 1 / T / Z | L3 / back + R3 / D-pad (hold) |
| Loadout / pause / help / network | K / Esc / F1 / F3 | Back / Start |
