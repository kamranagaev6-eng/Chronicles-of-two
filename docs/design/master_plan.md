<!-- Converted from "Chronicle of Two — Master Plan.docx" (8 Nov 2026). The Word document is the original; this copy exists so agents can search it. -->

# Chronicle of Two — Master Plan

Nov 8, 2026 · @StabilityOS
## At a glance

Build a private two-player action RPG about you and Anastasia in Godot 4.7.2: host-authoritative online co-op over Tailscale, CC0 and original assets, a detailed storybook look, and a prologue plus four acts to level 40. The first production commitment is one polished adventure, the Sunken Crypt, played as Dawn Vanguard and Riftweaver.

This is the single source of truth, merged from the Word master plan and the Integrated Blueprint. It keeps the larger campaign you chose and the stronger version of every system; the last sections list each conflict and how it was settled.

| Area | Decision |
| --- | --- |
| Players | Exactly two, each on their own Windows PC with their own camera; online or LAN |
| Engine | Godot 4.7.2 stable (18 Aug 2026), pinned; typed GDScript |
| Rendering | Forward+ on Direct3D 12, Godot’s Windows default since 4.6; Vulkan kept as a tested fallback |
| Physics | Built-in Jolt, set explicitly in project settings; a custom character motor and gameplay rules on top |
| Netcode | ENet listen server; the host owns every outcome; netfox 1.35.3 predicts only each player’s own movement and dodge |
| Connection | Tailscale’s free Personal plan first, direct LAN second; no public relay required |
| Assets | CC0 third-party art and audio plus your own work; any exception is a written ledger decision |
| Art | “Ember Storybook”: detailed storybook fantasy on one consistent Quaternius character family |
| Tools | Godot, Blender, Krita, Audacity, Git; $0 in software, assuming the two PCs you already own |
| Classes | Four classes, 12 abilities each (48), two specializations each; either of you can play any class |
| Campaign | Prologue plus four acts: 13 expeditions with 13 finales, level cap 40, about 25–35 hours |
| First pair | Dawn Vanguard + Riftweaver, the freeze → shatter pair; your own preferences override it |
| First adventure | The Sunken Crypt: the Bellkeeper elite and the Drowned Abbess, one 45–60 minute evening |
| Timeline | Sunken Crypt in about 6–9 months; Act 1 in about 12–24 months; the full campaign over several years, at 10–15 hours a week |
| Out of scope | Couch co-op, matchmaking, more than two players, live host migration, a custom physics solver, a runtime language model |

## Vision and pillars

Chronicle of Two is about fantasy versions of you and Anastasia growing stronger together and rebuilding a home. Both heroes matter equally, build independently and shape the story together.

The moment it is built for: you come home from a dangerous expedition with a new ability combination, something new for Emberrest, and another story about what you did together.

Pillars
- Two halves of one fight. One of you sets up, the other pays off, and either can play either role. Every class can fight, dodge, recover, prime and finish, so nobody is ever just the support.
- Coordination creates openings. Positioning, protection, control and timing matter as much as damage. Partner combos are worth seeking, never mandatory.
- Builds you are proud of together. Path of Exile-style depth at a scale two people can master. Progress adds new choices and behaviours, not just bigger numbers.
- A story that is ours. Visible dice, campfire rituals, banter you partly write and record, and a Chronicle that writes itself from what you do.
- A living, reactive world. Water freezes, oil burns, enemies slam into walls, and the tether between you can become a weapon.

Rules every system follows
- Affection is expression, never power: gifts, Bond events, dialogue and decorations never gate combat strength.
- There is no approval meter between you. Bond progress only grows, and agreement is never scored or rewarded.
- Nothing punishes separation, disagreement or a bad roll. Failures change the route; they never block the campaign.
- Every mandatory mechanic works with all ten class pairings. A class may offer a faster solution, never the only one.
- The host decides every gameplay outcome. Presentation can differ between the two PCs; results never do.
- Every number in this plan is a tuning seed for playtesting, not a promise.
## Story and campaign

The campaign is a prologue plus four acts: 13 expeditions, 13 finales, levels 1–40 and about 25–35 hours. Each act ends as a complete chapter, so the game is worth playing together long before the last act exists.

Premise. Working title: Chronicle of Two — The Last Hearth. You two are an established couple living at Emberrest, a home at the edge of a fading world. The world’s history lives in a living book, the Chronicle, and the stars above Emberrest are its copy in the sky.

Stars are going out, and roads, places and the memories tied to them vanish with them; people call it the Unwriting. Its cause is the Archivist, who fears loss so much that he lifts the world, page by page, into a perfect frozen Library where nothing can ever change.

On the night the first star dies, both your names appear together on a blank page: the first co-written page in a thousand years. Together you are Emberbound, and the Chronicle can write things back, but only what two people live through together. Recover three Star Embers, rekindle the constellation, and follow it to the Library to decide what deserves preserving and what must stay free to change.

The tone is hopeful fantasy: dangerous dungeons, affectionate humour, and a home that grows warmer every act.

| Stage | Levels | Expedition | Finale and its duo mechanic |
| --- | --- | --- | --- |
| Prologue · Begin: the Last Page | 1–3 | Archive Ruins | Blank Knight: its armour of blank pages tears only to Resonances; the tutorial for primer → finisher |
| Act 1 · Remember: Hearthvale, flooded ruins and brittle undead | 3–12 | Sunken Crypt | Drowned Abbess: floods alternate with exposed anchors. Freeze the water or turn the sluice wheels, break the anchors, then use the stagger window. Elite on the way: the Bellkeeper, staggered by slamming it into its own bell |
|  |  | Millrace Tunnels | Sluicewarden: one of you works the mill gates while the other fights on shifting water; currents carry bodies into the wheels |
|  |  | Old Lighthouse | Tide-Bell Golem: trade who holds its attention while the other rings warding bells on opposite galleries; slam it into the lamp to stagger it |
| Act 2 · Change: the Whispering Grove, living roots, spreading fire, corrupted spirits | 12–22 | Briarwood Maze | Thorn Matriarch: roots seize one hero at a time and the partner frees them with any hit; fire clears briars but spreads |
|  |  | Hollow Oak | Twin Dryads: both must fall within 10 s of each other, a wider window on easier difficulties |
|  |  | Moonwell Caverns | Pale Hart: solid only in moonlight; one of you turns mirror stones to light it while the other strikes |
| Act 3 · Choose: the Spire of Embers, ancient machinery and combined mechanics | 22–32 | Forge-Deeps | Chainwright: chains one hero to an anvil; the partner breaks the chain or baits the hammer onto it |
|  |  | Glass Desert | Cinder Duke: oil and fire everywhere; douse his armour with water or cold, or ignite oil beneath him to crack it |
|  |  | The Spire | Mirror Pair: echoes of you both that copy your class signatures but not your gear; each echo resists its original, so you swap targets |
| Act 4 · Write: the Library of Ends, floating pages and unwritten islands | 32–40 | Floating Archive | Margin Warden: platforms exist only while one of you keeps them written; take turns writing and fighting |
|  |  | Islands of Lost Pages | Collected Echoes: earlier bosses remixed into one gauntlet, each with a new twist |
|  |  | Library of Ends | The Archivist and the Unwriting: the three-phase finale below |


Every mandatory mechanic has a class-neutral tool, such as sluice wheels, bells, mirror stones, water barrels, braziers and the universal shove, so all ten pairings can win; a matching class just finds a faster way. Thirteen finales do not mean thirteen unrelated skeletons: several reuse an enemy foundation with new behaviour.

The Archivist, in three phases
- Split pages: you stand on two separated platforms; each of you sees the hazards on the other’s platform and has to call them out, by voice or the ping wheel.
- The Unwriting: the arena erases itself from the edges, and every Resonance writes a patch of floor back.
- The co-written page: the final blow is your Double Tech, triggered together.

The choice in each act. Both of you must confirm it, and no option blocks progress.
- Act 1: what to restore first at Emberrest.
- Act 2: how to heal a forest whose spirits disagree about its future.
- Act 3: what becomes of the Mirror Pair, your archived echoes: let them fade, or write them into the Chronicle as a memory.
- Act 4: what to do with the Library: free everything it holds, or make it a place you can visit but never be trapped in.

Optional content. About 12 optional quests, three per act, reuse expedition spaces with new objectives. Each hero also gets a three-part personal quest, co-written in a 20-minute session zero around a hometown, a lost mentor and a fear. Its parts land in Acts 1–3; each part grants a constellation point, and the last unlocks that hero’s specialization capstone. Example: in The Lantern of Mirevale, Anastasia’s hero restores an erased childhood place.

After the campaign. Pages Unwritten adds seeded Memory Delves with stacking modifiers, Legend difficulty, three challenge ranks per expedition and Heirloom chase items. Each anniversary after the finale adds a 2–4 hour chapter themed on your real year together, with new relics, Heirlooms and runes; the level cap stays at 40 so the campaign’s balance holds. Until then, each anniversary during development gets a small gift: a camp decoration, a relic or a Chronicle page about your year.
## Loops, sessions and Emberrest

Every evening follows one loop: a “Previously on…” recap, preparation at Emberrest, an expedition, a choice, and a return home stronger, with something new for the house.

| Loop | Rhythm |
| --- | --- |
| Moment to moment | Position → attack → prime an enemy → partner finishes → dodge or protect → collect rewards |
| One evening | Recap → prepare at home → expedition → choice → home with upgrades |
| Whole campaign | Grow your heroes → restore Emberrest → unlock regions → change the world together |


Sessions. A normal evening runs 45–75 minutes. An expedition takes 30–60 minutes and checkpoints at a Waystone after every cleared room, so longer ones can span evenings. Either of you can pause; play resumes when both are ready, and camp and region transitions need both of you.

Emberrest grows visibly as you play

| Unlocked | Facility | What it does |
| --- | --- | --- |
| Prologue | The Emberhearth and tent | Camp conversations, rest, the Chronicle book, the Bond constellation |
| Act 1 | Forge and rune table | Craft, upgrade, socket runes, respec; training dummies with a damage readout |
| Act 1 | Kitchen and garden | One shared meal buff per expedition; each of you adds an ingredient |
| Act 1 | Letterbox | Letters and wrapped gifts for each other, delivered when you choose |
| Act 2 | Chronicle room | Boss trophies, big decisions, first victories, memorable rescues |
| Act 2 | Living quarters and terrace | Decorate furniture spots, change outfits, scrapbook and photo mode |
| Act 3 | Observatory | The restored constellation, charted; Act 4 and each anniversary chapter begin here |


Act 1’s choice decides which of the forge, kitchen or garden is restored first; the others follow during the act.

When one of you is offline. Story expeditions and all XP need both of you, so neither can out-level the other. Alone, you can train on the dummies, use photo mode, draft builds, loadouts and decoration layouts, and write letters that arrive at your partner’s next session. Solo mode loads a read-only copy of your hero, so nothing done alone can conflict with the shared save; drafts apply with a preview when you next play together. Timed offline missions and offline currency are deferred.
## Combat and the Resonance system

Combat is real-time and built around Resonance: one of you primes an enemy, and the other’s finisher detonates it for double damage and a named effect. Detonating your own primer still works, but pays far less.

Every hero has
- A basic attack.
- A dodge with 2 charges and brief invulnerability.
- Four equipped class abilities, chosen from the twelve.
- A shove that pushes enemies into walls and hazards, stronger with STR; heavy enemies barely move. Every class has it, so physics mechanics never depend on class.
- A healing flask that refills at Waystones.
- The shared Bond action, which fires the Double Tech once the Bond meter is full.

Controls and feel
- Each of you picks keyboard and mouse (WASD, cursor aim) or a controller (twin-stick, soft lock-on). Click-to-move is out of scope.
- Rebinding, hold-or-toggle options, a 150 ms input buffer and authored cancel windows are standard. No class needs rapid repeated presses.
- Hits land with 40–80 ms of hit-stop, trauma-based screen shake (a per-player slider), a one-frame flash and layered sound. Hit-stop is presentation only and never pauses the host simulation.
- Combat shows no dice: crits use a pseudo-random distribution, and damage-over-time ailments use buildup bars.

Readability
- Enemy telegraphs are red-orange ground decals drawn above player effects.
- Your effects are gold and Anastasia’s are violet (swappable); your partner’s effects render at 60% opacity on your screen.
- Primers show over enemies as icons in the owner’s colour and shape. A target ready to detonate gets an outline and a sound, and every tooltip names its primer or finisher tag.

Resonance rules
- Some abilities apply a primer: a tag that records its owner, type, strength and expiry. It lasts 4 s.
- Each player can hold one primer per enemy, so an enemy carries at most two. A new primer from the same player replaces their old one.
- Finishers come in four types (Impact, Arcane, Precision, Primal) and consume one primer, preferring the partner’s.
- Consuming your partner’s primer triggers a Resonance: the finisher hit deals ×2 damage, plays the full named effect and fills the Bond meter. Consuming your own is a Basic reaction: ×1.25 and a half-strength effect.
- Partner means the other player, not another class, so two Riftweavers resonate with each other normally.
- A skill can’t consume a primer it created in the same action, and one action detonates at most once per target, however many projectiles it has.
- If two finishers reach the same primer, the host resolves them in arrival order; the second is a normal hit.
- After a detonation, that primer type can’t be reapplied to that target for 4 s.
- Reactions never trigger reactions and never apply primers. Rally, below, is the one bounded exception.
- Reactions are data rows keyed by primer type and finisher type; the resolver never mentions class names.

Physics feeds the same system: an enemy slammed into a wall above 6 m/s becomes Dazed, owned by whoever knocked it there.

Primer and finisher types

| Class | Primers it applies | Finisher type | What the finisher adds to any reaction |
| --- | --- | --- | --- |
| Dawn Vanguard | Dazed, Sanctified | Impact | Knockback, launch, extra stagger |
| Riftweaver | Frozen, Shocked | Arcane | Leaves a matching surface or spreads through an area |
| Shadowstrider | Marked, Envenomed | Precision | +50% crit chance on the hit, focused on one target |
| Verdant Warden | Rooted, Terrified | Primal | Spreads through nature: heals allies or snares nearby enemies |


| Primer | Base effect when it resonates |
| --- | --- |
| Dazed | Concussion: double stagger damage from the hit |
| Sanctified | Radiance: a holy burst; allies nearby gain a small barrier |
| Frozen | Shatter: an ice-shard burst; struck enemies are Exposed (20% more elemental damage taken) for 6 s |
| Shocked | Discharge: arcs to 4 nearby enemies; electrifies water |
| Marked | Pinpoint: +50% crit chance on the hit; executes non-elites under 15% health |
| Envenomed | Rupture: the remaining poison is dealt at once, ×1.5 |
| Rooted | Snap: a launch with a 1.2 s juggle window |
| Terrified | Panic Break: the target bolts into its neighbours and knocks them down |


Any primer and finisher combine into base effect plus finisher twist, so no combination is ever blank. Sixteen combinations get a signature reaction of their own:

| Pairing | Partner’s primer → your finisher | Signature reaction |
| --- | --- | --- |
| Vanguard + Riftweaver | Frozen → Impact | Shatterfall: shards blast outward with knockback; struck enemies Exposed |
| Vanguard + Riftweaver | Dazed → Arcane | Thunderclap: the target becomes a lightning rod, arcing to 4 enemies and electrifying water within 4 m |
| Vanguard + Shadowstrider | Dazed → Precision | Coup de Grâce: the hit always crits; executes non-elites under 20% and elites under 8% |
| Vanguard + Shadowstrider | Marked → Impact | Sundering Judgment: ignores 50% of armour; nearby enemies knocked down |
| Vanguard + Warden | Rooted → Impact | Groundbreaker: rooted enemies are torn up and launched for a 1.2 s juggle; landing deals area damage |
| Vanguard + Warden | Sanctified → Primal | Sacred Bloom: holy flowers burst; allies within 5 m gain a barrier of 10% max health |
| Riftweaver + Shadowstrider | Marked → Arcane | Hex Bloom: enemies within 6 m take 20% more damage for 5 s |
| Riftweaver + Shadowstrider | Shocked → Precision | Chain Execution: the strike jumps through every Shocked enemy within 8 m at 60% damage each |
| Riftweaver + Warden | Rooted → Arcane | Thunderbloom: lightning runs along the roots between rooted enemies; the roots become electrified briars for 4 s |
| Riftweaver + Warden | Frozen → Primal | Frostbriar: a frost-thorn field slows and damages enemies; heroes inside regenerate 2% health a second |
| Shadowstrider + Warden | Envenomed → Primal | Feeding Frenzy: the spirit wolf devours the poison, dealing it at once ×1.5; both heroes heal 30% of it, capped at 15% max health |
| Shadowstrider + Warden | Rooted → Precision | Thornhunt: the target and rooted enemies within 6 m bleed heavily for 3 s; crits refresh it |
| Vanguard ×2 | Dazed → Impact | Twin Verdict: triple stagger; Sanctified ground nearby fuses into a holy nova |
| Riftweaver ×2 | Frozen → Arcane | Superconduct: enemies within 5 m take 30% more elemental damage for 6 s |
| Shadowstrider ×2 | Marked → Precision | Crimson Waltz: every bleed and poison on the target detonates; a kill gives both heroes 3 Momentum |
| Warden ×2 | Rooted → Primal | Wild Hunt: a spirit stampede charges through rooted enemies in a line |


Rally (unlocked by the Bond perk Back and Forth). A Resonance can leave a fresh primer owned by the player who triggered it, and the partner has 3 s to answer. There are at most three exchanges, with the multiplier stepping down ×2 → ×1.6 → ×1.3; the third ends in a Crescendo that fills a large share of the Bond meter.

Stagger and bosses
- Every enemy has one stagger meter, separate from health and from primer tags.
- Ordinary enemies can be frozen, rooted, knocked down or launched; a full meter stuns them for 1.5 s.
- Elites take shortened control with diminishing returns. Bosses ignore hard control, and control they resist becomes stagger instead.
- Bosses accept primers during vulnerable phases even when their movement can’t be interrupted. Primed enemies take stagger twice as fast.
- A full meter Staggers an elite or boss for 6 s, during which it takes 50% more damage: the Double Tech window. A recovery period then prevents an immediate repeat.
- Thresholds and contributions are tuned per encounter, never a fixed fraction per combo. Invulnerable boss phases are clearly shown and reject both damage and primers.

The Bond meter and Double Techs

Resonances, Rally exchanges, revives and protecting your partner fill one shared Bond meter. When it is full, one of you requests the Double Tech and the other confirms within 3 s; an unconfirmed request costs nothing. Double Techs unlock at the end of the Prologue, and a pairing whose own Double Tech isn’t built yet uses Hearthflare: a barrier on both heroes and a coordinated area attack between you.

| Pairing | Double Tech | What happens |
| --- | --- | --- |
| Vanguard + Riftweaver | Meteor Aegis | A rift lifts the Vanguard; a frost-wrapped slam lands where you aim |
| Vanguard + Shadowstrider | Hammer and Anvil | The Vanguard pins the target; the Shadowstrider strikes five times from the shadows |
| Vanguard + Warden | Sacred Grove | A consecrated grove heals allies and burns enemies inside it |
| Riftweaver + Shadowstrider | Rift Assassination | A rift opens behind every Marked enemy; the Shadowstrider strikes through them all |
| Riftweaver + Warden | Eternal Winter Garden | A frozen garden roots and chills everything in a wide circle |
| Shadowstrider + Warden | Pack Hunt | Spirit wolves and shadow clones hunt the five nearest enemies |
| Vanguard ×2 | Shieldwall | Interlocked shields block everything in front, then a double shield rush |
| Riftweaver ×2 | Binary Star | Two stars of frost and lightning orbit you both |
| Shadowstrider ×2 | Shadow Dance | Both of you vanish, then strike every enemy in reach |
| Warden ×2 | World Tree | A great tree raises a revive zone and heavy roots |


All ten share one framework and one power budget; bespoke animations arrive as each class is completed.

The Bond Tether
- A ribbon of light connects you within 14 m, fades between 14 and 18 m, and drops beyond 18 m. It reconnects on its own when you are back within 14 m.
- On its own it is cosmetic: it never pulls either of you, never punishes separation, and costs about 3 bytes of network state.
- Link abilities and Tetherblade runes infuse it for 6 s: holy heals allies who cross it, lightning chains to enemies touching it, fire leaves a burning line and cold chills. While it is infused, the host shape-casts a capsule along it at 20 Hz.
- Damage shared through any link applies once and never bounces back, and downing one of you never downs the other.
## The four classes

Each class has a resource, a signature passive, twelve abilities and two specializations, and you equip four abilities at a time. Every class can deal damage, survive, prime, finish and revive, and no class is required for any mandatory mechanic.

How abilities unlock (all classes)
- Ten core abilities unlock at levels 1, 1, 2, 3, 6, 9, 15, 20, 25 and 30, so you hold four by the end of the Prologue.
- At level 12, the Specialization Trial at the end of Act 1 adds your chosen specialization’s signature ability; switching specialization swaps it for the other one.
- Your specialization capstone unlocks when you finish your hero’s personal quest.
- Change class or specialization at Emberrest whenever you like. Your level stays, each class keeps its own saved loadout, and you can both pick the same class.
### Dawn Vanguard — the Shield and the Blade

An armoured frontliner with holy fire, barriers and displacement. Resource: Resolve, built by landing hits, perfect blocks and guarding your partner; it never requires taking damage. Signature, Oathbond: while your partner is within 8 m, 10% of the damage they take moves to your armour, up to 20% with CHA.

| Level | Ability | Tag | What it does |
| --- | --- | --- | --- |
| 1 | Judgment Cleave | Primer: Sanctified | Sweeping strike; leaves consecrated ground that ignites oil |
| 1 | Shield Rush | Finisher: Impact | Collision-aware charge that slams enemies into walls |
| 2 | Radiant Aegis | Support | Barrier on both heroes inside its radius |
| 3 | Lance of Dawn | Primer: Dazed | Thrown radiant spear that pierces a line |
| 6 | Leap Slam | Finisher: Impact | Leap to a point; heavy area slam with large stagger |
| 9 | Sacred Tether | Link | For 8 s, 25% of your partner’s damage taken moves to you; infuses the tether with holy light |
| 12 | Bulwark Stance (Sunwarden) | Primer: Dazed | Block stance; perfect blocks Daze the attacker |
| 12 | Final Verdict (Ashen Templar) | Finisher: Impact | Execution strike; double damage below 30% health |
| 15 | Taunting Roar | Control | Nearby enemies prefer you for 4 s; you gain Resolve |
| 20 | Consecrate | Surface · Primer: Sanctified | Sanctified ground: heroes regenerate, undead burn, enemies inside are primed |
| 25 | Sunbreak Uppercut | Finisher: Impact | Launches the target; bosses take heavy stagger instead |
| 30 | Martyr’s Step | Rescue | Dash to your partner and take the next hit meant for them; a downed partner’s revive runs at double speed |


Specializations: Sunwarden (barriers, auras, counters) or Ashen Templar (radiant fire, aggressive finishers, sustain).
### Riftweaver — the Arcane Architect

Elemental control and spatial magic: fragile up close, devastating at range. Resource: Flux, which regenerates; at zero you simply can’t cast, and only the Overcast keystone lets you cast past zero into Strain, which drains health. Signature, Elemental Weave: casting a different element from your last spell refunds 15% of its cost.

| Level | Ability | Tag | What it does |
| --- | --- | --- | --- |
| 1 | Glacial Spire | Primer: Frozen | Frost projectile; freezes ordinary enemies and turns water to ice |
| 1 | Arc Lance | Finisher: Arcane | Lightning lance; electrifies water it crosses |
| 2 | Blink | Mobility | Short teleport to a valid spot |
| 3 | Ember Orb | Fire | Slow fire orb; sets Burning and ignites oil |
| 6 | Rain Call | Surface | Rain makes a wide Water surface and soaks everything under it |
| 9 | Singularity Rift | Control | Vortex that pulls enemies and loose objects together; leaves a Rift well |
| 12 | Time Fracture (Chronarch) | Rescue | Returns your partner to where they stood 3 s ago, with their health from then if it was higher |
| 12 | Storm Wall (Stormcaller) | Primer: Shocked | A wall of lightning; enemies crossing it are Shocked, and it electrifies water it touches |
| 15 | Overcharge Surge | Link · Primer: Shocked | For 8 s, both heroes’ hits chain lightning and apply Shocked, owned by you |
| 20 | Mirror Rift | Utility | Two linked rifts: projectiles and heroes entering one leave the other |
| 25 | Frost Nova | Primer: Frozen | Ring of frost around you; freezes nearby enemies and ices water |
| 30 | Starfall | Finisher: Arcane | Channelled star shower over an area; leaves Burning ground |


Specializations: Chronarch (tempo, cooldowns, protective timing; never a rewind of the shared world) or Stormcaller (lightning, weather and surface reactions).
### Shadowstrider — the Lethal Phantom

Precision, mobility, traps and burst. Resource: Momentum, up to 5 charges earned from hits and well-timed dodges; finishers spend charges for more damage. Signature, Backstab and Mark: hits from behind or on Marked targets gain +25% crit chance and +25% crit damage.

| Level | Ability | Tag | What it does |
| --- | --- | --- | --- |
| 1 | Hunter’s Mark | Primer: Marked | Ranged shot that Marks its target |
| 1 | Twin Fang | Finisher: Precision | Two fast strikes; spends Momentum for more damage |
| 2 | Shadowstep | Mobility · Link | Reposition behind a target or beside your partner |
| 3 | Toxic Caltrops | Primer: Envenomed | Slowing poison trap |
| 6 | Fan of Knives | Physical | Cone of knives that applies Bleeding |
| 9 | Smoke Veil | Support | Concealment zone for both heroes; enemies inside lose their attack tokens |
| 12 | Phantom Clone (Nightblade) | Decoy | A clone repeats your next strike and draws attacks |
| 12 | Tripwire Trap (Trapwright) | Primer: Marked · Surface | A wire between two posts; enemies crossing it fall prone, Marked and soaked in oil |
| 15 | Eviscerate | Finisher: Precision | Consumes bleeds and poison for burst damage |
| 20 | Ricochet Bolt | Finisher: Precision | Ranged bolt that bounces off walls up to three times |
| 25 | Grapple Hook | Mobility · Control | Pull yourself to a point, or yank a light enemy into a hazard |
| 30 | Death Blossom | Finisher: Precision | A storm of spinning blades around you; Marked targets take the most |


Specializations: Nightblade (close-range precision and executions) or Trapwright (traps, oil and ranged control).
### Verdant Warden — the Spirit Shaper

Offensive nature magic, a spirit companion and recovery. Resource: Verdance, earned in combat and faster on Overgrowth. Signature, Spirit Wolf: a persistent companion that harries your target, one per player.

| Level | Ability | Tag | What it does |
| --- | --- | --- | --- |
| 1 | Grasping Briars | Primer: Rooted | Roots erupt and pin a group |
| 1 | Sap Lash | Finisher: Primal | Piercing thorn whip |
| 2 | Bloom of Renewal | Support | Healing zone that cleanses ailments |
| 3 | Wolf Pounce | Finisher: Primal | Sends the wolf to pounce at range |
| 6 | Primal Roar | Primer: Terrified | Fear burst that staggers; both heroes gain crit chance |
| 9 | Thornwall | Control | A wall of thorns that blocks movement and projectiles; enemies pushed into it bleed |
| 12 | Wild Shape: Bear (Wildshaper) | Form | Bear form; its claw finisher counts as Primal |
| 12 | Moonwell (Spiritcaller) | Rescue | Rally zone where revives are twice as fast and heroes heal |
| 15 | Overgrowth | Surface | Spreads Overgrowth: a root chance for enemies, cover and faster Verdance for heroes |
| 20 | Spore Burst | Primer: Terrified | A spore cloud that panics enemies inside; harmless to heroes |
| 25 | Stampede | Finisher: Primal | A spirit herd charges in a line, knocking enemies down |
| 30 | Heart of the Grove | Support | Plants a heartwood for 10 s that heals both heroes and roots enemies at its edge |


Specializations: Wildshaper (forms and impact) or Spiritcaller (spirits, protection and revives).
## Progression: attributes, constellations and runes

You level together and choose apart: shared XP keeps both heroes at the same level, while attributes, constellation points, runes and gear stay personal. Every respec is free at Emberrest.

Six attributes. Start from 15, 14, 13, 12, 10 and 8, with a suggested spread per class, and add 1 point every four levels (10 by level 40). Gear adds more for combat, but roleplay checks use your permanent attributes only, with the modifier capped at +5.

| Attribute | In combat | In roleplay checks |
| --- | --- | --- |
| STR | Physical damage, stagger damage, knockback force, shove | Athletics: doors, portcullises, physics puzzles |
| DEX | Attack speed, dodge distance, projectile speed, crit chance | Stealth, locks, traps |
| CON | Health, stagger resistance, ailment resistance, downed timer | Endurance, poison, drinking contests |
| INT | Spell damage, surface size and duration | Arcana, history, Chronicle pages |
| WIS | Resource regeneration, control duration, ailment buildup | Perception, insight, medicine |
| CHA | Link, aura and spirit strength (bounded); Oathbond share | Persuasion, deception, leadership, prices |


Personal constellation. Each class has about 70 nodes, including both specialization branches and six keystones that change rules. Examples: Glass Star (abilities cost health instead of your resource) and Overcast (Riftweaver casting past zero Flux into Strain). You earn 45 points: one per level from 2 to 40, one per personal-quest part, and one for each of the Act 1–3 finales. Specialization branches open at level 12.

Bond constellation. Twenty shared nodes, identical for both of you: twelve modest permanent benefits and eight major perks. Nodes come only from shared milestones: one from each of the 13 finales, and seven from co-op firsts (first Resonance, first revive, first boss Staggered, first Double Tech, first optional quest, and each personal quest finished). You equip two major perks in Act 1, three in Act 2 and four from Act 3.

| Major perk | Effect |
| --- | --- |
| Watch Each Other’s Back | 20% more crit damage while within 5 m of each other |
| Apart Together | More than 15 m apart, each of you deals 15% more damage |
| Covering Fire | Hitting an enemy that threatens your partner gives 10% more damage for 4 s |
| Twin Execution | An elite kill gives both heroes 5 s of haste |
| Perfect Timing | Resonances within 0.5 s of the primer give 50% more Bond meter |
| Second Wind | Finishing a revive gives both heroes a barrier |
| Second Chance | One instant mutual revive per expedition |
| Back and Forth | Unlocks Rally exchanges |


The twelve permanent nodes are deliberately modest, for example Shared Respite (your flask also heals your partner for 25% of its amount), +0.5 s primer duration, 10% faster revives and +2 m tether range.

Runes
- Every equipped ability has three sockets: Form from level 1, Bond from level 6 and Technique from level 12.
- Runes are permanent unlocks in a shared library. Once either of you finds one, both of you can equip it at the same time.
- Duplicates raise that rune’s tier (I → II → III, three duplicates a step); after tier III they become crafting material.
- Tags decide what fits: a ground zone can’t take a projectile-return rune, and a melee strike can’t take Fork. The rune table previews cost, cooldown, damage and behaviour before you confirm.
- Triggered echoes can’t trigger further echoes, healing from damage has a recovery cap, and conversions follow a one-way table with no cycles.

| Category | Library target | Purpose | Examples |
| --- | --- | --- | --- |
| Form | 25 | Shape: projectile count, area, chain, return, lingering zones | Fork, Chain, Pierce, Ricochet, Return, Reach, Expansion, Compression, Echo, Lingering |
| Technique | 50 | Conversion, timing, charges, resource trade-offs, conditions | Overload (costs 50% more, deals 40% more), Quickening, Anchoring, Leech, Warding, Infusion: Frost, Storm, Ember and Thorn |
| Bond | 25 | Partner interactions, tether effects, coordinated recovery | Resonant (+30% on Resonances this skill primes or triggers), Kinship (10% of damage dealt heals your partner, capped), Attune (your partner’s next skill takes this skill’s element), Tethered (20% more damage while the tether is connected), Tetherblade (this skill infuses the tether for 6 s) |


The Sunken Crypt ships 12 runes: eight Form (Fork, Chain, Pierce, Reach, Expansion, Compression, Echo, Lingering) and four Bond (Resonant, Kinship, Attune, Tethered). The library grows only after each behaviour type works reliably. The four Infusion runes arrive in Act 3: they convert half a skill’s damage and change the primer it applies, giving same-class pairs more combos.
## Damage math and stacking rules

The host computes every hit with one formula in one fixed order, and tooltips call the same calculator, so the number you read is the number you get.

```
Hit = Σ_packets (B + E·A) · (1 + I) · (Π_k M_k) · C · (1 − R) · (1 + V) · X
```


| Symbol | Meaning |
| --- | --- |
| B | Skill base damage, including its weapon contribution |
| A, E | Added flat damage, and the skill’s added-damage effectiveness |
| I | The sum of every applicable increased and reduced modifier: one additive pool |
| Mₖ | Each independent more or less factor: runes, keystones, specializations, Bond sources |
| C | The critical multiplier, when the hit crits |
| R | Mitigation: armour against physical damage, resistance against elemental |
| V | The sum of target vulnerabilities (Exposed, Hex Bloom, Staggered), capped at +100% |
| X | The reaction multiplier: 2 for a Resonance, 1.25 for a Basic reaction, otherwise 1 |


Stacking rules
- Gear and the personal constellation give “increased”, one additive pool. Runes, keystones and specializations give “more”, each multiplying separately.
- Co-op bonuses never join the additive pool, so they can’t be diluted. Bond perks, Bond runes and Link skills are separate factors, together capped at ×1.5 on any one hit.
- Keep fractional precision through the whole calculation, and round only for display and stored state.
- Resolve local item modifiers once. Converted damage keeps provenance tags, and each eligible modifier applies to it once.
- Each named effect follows one declared stacking rule. Damage over time can’t re-trigger on-hit effects, and triggered effects can’t chain without limit.
- Damage redirection (Oathbond, Sacred Tether) applies once and is never redirected again, even between two Vanguards.
- Every recovery effect has an explicit cap.

Mitigation
- Armour reduces a physical hit by armour ÷ (armour + 10 × hit), capped at 90%.
- Resistances cap at 75%. There are no act-based resistance penalties; later acts simply bring more elemental damage.
- Interception is honest about effective health: taking 70% of each hit is about 42.9% more effective health for that hero (1 ÷ 0.7), while the partner carries the other 30%.
## Loot, crafting and gifting

Loot is personal and easy to read, crafting is fully deterministic, and giving each other things is a feature of its own, with its own moment on screen.

Slots: weapon, offhand, head, chest, gloves, boots, amulet and ring. Two-handed weapons fill both hand slots and carry a matching item budget. Free transmog and a show-helmet toggle keep your favourite look.

| Rarity | Affixes | Notes |
| --- | --- | --- |
| Common | 0 | Base items and salvage |
| Enchanted | 1–2 | Early upgrades |
| Rare | 3 + 1 forged slot | The main chase; at most 2 prefixes and 2 suffixes; the forged slot is filled at the forge |
| Relic | Fixed | About 24 authored items, each changing a recognisable behaviour; several are your real memories |
| Heirloom | Fixed, in pairs | Six matched pairs; each half is useful alone, with a modest optional bonus while your partner wears the other half |

- Affixes: tiers T1–T5 by item level. Tooltips say why an item helps your current build.
- Drops: personal to each player, about 70% rolled for your current class and loadout. Crafting materials are shared, and loot-filter presets hide what you don’t want.
- Bosses: always a choice of three useful rewards.
- Forge: salvage gear into materials. Each item has a fixed Forging Potential budget, and every action shows its exact cost and the complete result before you commit. You can fill the forged slot with a chosen affix, raise an affix’s tier, or replace one affix with another from the eligible list. Ember Essences from bosses unlock the rarest affix families, and nothing is random once an item has dropped.
- Gifting: “Offer to Partner” works anywhere, and the gift moves only when your partner accepts. In person, your heroes do a short hand-over within 1 m after the transfer commits, and a banner announces it. Gifts can carry a note, are logged in the Chronicle, and commit exactly once even if a request repeats. Gifts wrapped at the letterbox can be set to open now, tonight, or at the start of your next session.
- Matching outfits: cosmetic sets earned from Bond events. No equipment set is ever mandatory.
## Exploration, dice, choices, difficulty and recovery

Dice belong to exploration and conversation, never to combat, and nothing in a roll, a choice or a defeat punishes either of you for the other’s play.

Checks. Roll a visible d20 + attribute modifier (max +5) + training (+2 for trained skills) against DC 5–25. One hero leads, and a partner within 5 m can Help, which grants advantage: roll twice, keep the higher. Inspiration (max 2) buys a reroll, and the host rolls and records every die.
- Failure opens a complication or another route, never a dead end.
- A natural 20 unlocks a bonus outcome and a Chronicle entry; a natural 1 is funny, never punishing.
- Optional Karmic Dice add +3 after two failures in a row.

Two-player choices

| Kind | How it resolves |
| --- | --- |
| Small (flavour lines) | The lead speaker alternates; the other can interject |
| Medium | Both pick in secret, and matching picks resolve. A mismatch shows both picks: talk it out and pick again, or, only if you both agree, let a visible Fate roll decide |
| Major story choices | Both must confirm the same option. No timer and no dice |


Agreeing never earns rewards, disagreeing never costs anything, and there is no persuasion contest between the two of you.

Difficulty. Story, Adventure and Heroic, changeable at Emberrest with equal progression rewards; Legend unlocks after the campaign. Difficulty adjusts enemy aggression, telegraph timing, damage taken and encounter size, not just enemy health. The game is tuned for exactly two players, with no scaling code for other party sizes.

Per-player assists, private to each of you: aim assistance, dodge timing assistance (+50% invulnerability window), −25% damage taken, telegraph emphasis, hold-or-toggle inputs, auto-loot, subtitles and camera-shake strength. Each of you can play your own way without one carrying the other.

Downed and revive
- A downed hero can crawl for 25 s, plus 2 s per CON modifier point.
- Holding interact for 2.5 s revives, and the reviver takes 50% less damage meanwhile. Every class can revive.
- The revived hero stands at 40% health with 2 s of protection.
- If both of you fall, the encounter restarts from the latest Waystone. You keep all XP and equipment, and completed rewards stay committed.
- Rescues are recorded in the Chronicle as shared memories, never as a score.

Friendly fire is off. Surfaces and effects you create can’t hurt or disable either of you; enemy and world hazards stay dangerous.
## Banter, Bond events and the Chronicle

The relationship lives in authored moments: banter that reacts to what just happened, Bond scenes at camp, and a Chronicle that writes itself. It never lives in a score.

How banter works. The game uses the rule-matching approach Valve built for Left 4 Dead (Elan Ruskin, GDC 2012): it tracks facts about the moment and plays the most specific line that fits.
- A gameplay event sends a concept with the current facts. Events include a low-health save, a combo, a boss phase, entering a region, a gift and a quiet moment; facts include the speaker, partner health, tether state, region, session counters and quest flags.
- Each rule lists criteria, and the matching rule with the most criteria wins, so special cases beat general ones. Priority breaks ties.
- Rules carry cooldowns and “already said” flags so lines don’t repeat, plus an expiry so a line never plays after its moment has passed.
- A finished line can trigger a reply rule for the other hero, turning single lines into short exchanges.

Aim for about 40 lines in the Sunken Crypt and about 300 across the campaign, 30–40% of them written or recorded by the two of you. Text comes first; record selected personal moments later. Starter lines: “I had that under control, but thanks!” after a low-health save, and “Remind me to buy you dinner for that one.” after a rescue.

Bond events. Thirteen Fire Emblem-style camp scenes, three per act and one at the finale, raise your bond rank from C to S over the campaign. Think campfire talks, a stargazing check, a cooking duet and a festival dance. They are short and always available, and they reward expression (outfits, decorations, Chronicle pages, photo poses, new banter), never combat power.

Dialogue. A small custom runner reads plain-text scripts with explicit conditions. The host owns narrative state, and both PCs show the same node while recording each player’s readiness and votes. Dialogic 2 is the fallback if you would rather have an editor; verify its Godot 4.7 support first.

The Chronicle. Structured events (boss defeated, place restored, gift given, rescue made, choice resolved, natural 20 rolled) become authored journal entries from templates. Each session opens with a short “Previously on…” built from the last session’s entries, and no runtime language model is needed.

Relationship-safe rules
- No approval meter between the two of you; Bond progress only grows.
- Romance and affection are expression, never power.
- Disagreement is talked out or settled by a roll you both chose; agreement is never paid for.
- Failures are funny, never humiliating.
- A 20-minute session zero, before the Sunken Crypt, sets lines (never in the game) and veils (off-screen only). It also picks which real memories become relics, places and quests, and sketches both personal quests.
## Engineering architecture and online co-op

One PC hosts and also plays. The host simulates and decides everything that matters, both PCs run the same presentation code, and each PC predicts only its own hero’s movement.
*(diagram in the original Word document)*

host-authoritative co-op · 5 parts

Inputs flow into the host’s simulation; confirmed results flow out to both screens and into the shared save.

Modules

| Module | Owns |
| --- | --- |
| Definitions | Immutable abilities, effects, runes, items, affixes, enemies, encounters and banter rules |
| Session | Host and join, build and content checks, readiness, pause, reconnect |
| Character | Input, the movement motor, attributes, resources, loadouts |
| Ability and combat | Costs, timing, hit queries, primers, Resonance, damage, mitigation, stagger |
| World | Surfaces, physics objects, destruction, interactables, the Bond Tether |
| Encounter | Enemy AI, the Combat Director, navigation, boss phases, Waystones |
| Progression and campaign store | XP, constellations, items, crafting, gifting, saves |
| Narrative | Dialogue, choices, quest flags, banter rules, Chronicle entries |
| Presentation | Animation, audio, VFX, camera, UI, cosmetic physics |


Clients send commands, and the host emits result events that presentation, UI, narrative and saves consume. Definitions stay separate from runtime state: an ItemDefinition describes a kind of item, while an item instance records its ID, rolls and owner. Host-side gameplay must never depend on the host’s camera, animation playback or UI.

Data authoring: one source of truth per data type
- Typed Godot Resources (.tres) hold structured definitions: abilities, statuses, runes, items, enemies and encounters.
- CSV tables hold genuinely tabular data: the reaction matrix, surface rules, affix and loot tables, banter rules and the XP curve. Godot imports .csv files as translations by default, so set each data table to keep the file as-is; a typed loader validates it at startup and in tests.
- Never keep the same definition in two formats. Add an importer only if authoring becomes a measured bottleneck.

Network messages use stable IDs and plain data, never Resources, scene paths, object instances or executable commands.

| Message | Minimum contents |
| --- | --- |
| InputCommand | Sequence, simulation tick, movement, aim, buttons |
| AbilityIntent | Action sequence, ability ID, aim, the tick the guest was seeing |
| ActorSnapshot | Entity ID, spawn generation, tick, position, velocity, combat state |
| GameplayEvent | Unique event ID, tick, type, entities involved, result |
| RoomPatch | Room ID, revision, changed surface or interactable state |
| CampaignCheckpoint | Campaign ID, schema version, revision, parent hash, content hash |


Rates and channels
- The simulation runs at a fixed 60 Hz. Enemy snapshots go out at 20 Hz in one packed crowd message with a 100 ms interpolation buffer, surface patches at 10 Hz, and stats reliably when they change.
- Frequent, replaceable snapshots travel unreliably on their own channel; abilities, inventory, dialogue and rewards travel as reliable transactions.
- Budget: aim under 40 KB/s each way in a busy fight, measured with overhead; 100 KB/s is the hard ceiling.

Responsiveness for the guest
- netfox’s RollbackSynchronizer predicts each player’s own movement and dodge, then reconciles with the host. Replayed movement code never spawns loot, applies damage or replays sounds.
- The guest sends an AbilityIntent and immediately plays the cast animation and wind-up effects. On a predicted contact it plays hit-stop, flash and sound at once; damage numbers and primers appear only when the host confirms.
- The host validates ownership, cost, cooldown, range, timing and collision. For melee and hitscan it rewinds target hit volumes up to 200 ms to match what the guest saw, never the Jolt world; if blocking geometry has changed, the current geometry wins.
- Projectiles are always host-simulated. A rejected hit simply shows no damage number, and clients never apply damage.

Path of Exile shows why: its old “predictive” mode drifted out of sync, and its “lockstep” mode felt laggy. Predicting only your own movement and confirming everything else on the host sits between the two.

Connection

| Option | Role | Notes |
| --- | --- | --- |
| Tailscale | Primary | Free Personal plan: up to 6 users, non-commercial use. Join by the host’s Tailscale address, saved as a favourite, and show measured round-trip time and whether the link is direct or relayed |
| LAN address | Same house | No setup |
| netfox.noray | Optional, later | Self-hosted NAT punch-through, only after the baseline works; the maintainer’s public instance is for testing only |


Both PCs must run the same build and content manifest to join.

Disconnects and separate rooms
- If the guest drops, the encounter pauses for up to 2 minutes, and reconnecting restores an authoritative snapshot with the same hero.
- If the host drops, the guest returns to the menu, and either PC can then resume from the latest shared checkpoint. There is no live host migration.
- You may explore separate rooms: the host keeps simulating every relevant encounter, including rooms its own camera can’t see. Boss fog gates, camp and region transitions need both of you.

Two screens
- Each PC has its own camera at about 50° pitch with a cursor offset.
- A partner panel shows health, resource, Bond meter, Double Tech readiness and active primers.
- An off-screen arrow shows your partner’s distance and health and pulses when they are downed. A radial ping wheel marks targets and hazards, and a Regroup marker appears beyond 60 m.

Godot multiplayer pitfalls to avoid
- Keep MultiplayerSpawner nodes high in the scene tree, never inside nodes that get freed.
- Put synchronised properties in a dedicated child node, and set MultiplayerSynchronizer visibility explicitly.
- Send crowds as one packed snapshot, not one synchroniser per enemy.
- Pin netfox, and use plain RPCs for anything it doesn’t need to predict.

Testing alone
- Run two local instances (Debug → Customize Run Instances, or --host and --join flags).
- Add 80 ms ± 20 ms of latency and 2% loss with clumsy on Windows.
- Watch an F3 overlay of round-trip time, jitter, loss, buffer depth and reconciliations.
- Run a scripted bot partner for unattended soak tests.
## Physics, surfaces and enemy AI

Jolt moves the bodies, the game’s own rules decide what physics means in a fight, and the host owns every outcome that matters. Nothing relies on physics behaving identically on both PCs.

Ground rules
- Jolt has been Godot’s default 3D physics for new projects since 4.6. Record it explicitly in project settings so an upgrade can’t change it silently.
- Jolt is deterministic only for identical binaries making identical calls in the same order, so sync never depends on it.
- Full rigid-body rollback would need manual physics stepping, so prediction stops at the character controller.

| Category | Examples | Authority |
| --- | --- | --- |
| Gameplay | Movement, dodges, hit volumes, projectiles, knockback, stagger | Host decides; your own movement is predicted locally |
| Important objects | Movable crates, explosive barrels, breakable barriers, puzzle objects | Host simulates and replicates transforms |
| Cosmetic | Debris, sparks, hair and capes, death ragdolls, foliage | Each PC simulates its own, and they may differ |


Movement and hits
- Characters are scripted CharacterBody3D capsules with grounding, slopes, acceleration, dodge and authored ability movement. CharacterBody3D ignores physics forces and material friction, so ice sliding and knockback live in the motor.
- Gameplay moves the character and animation follows. Root motion drives only leaps, dashes and slams, and nothing moves a character twice.
- Ability timing (wind-up, active frames, cancel and buffer windows) lives in the ability’s data, in simulation ticks. Animation method tracks only cue sounds, trails and footsteps.
- Melee samples authored hit volumes across the active frames, one hit per target per swing.
- Projectiles are pooled data, shape-cast every tick with swept checks, initial-overlap handling and bounded substeps: pierce, chain (nearest unhit target within 8 m), fork (±25°), return, and ricochet off wall normals.

Impacts
- Knockback is a velocity change, Δv = J ÷ m: the ability’s impulse, scaled by STR, over a mass class (light 1, medium 3, heavy 8), with per-class caps. Bosses don’t move until they are Staggered.
- A wall slam above 6 m/s deals speed × mass × 4 and applies Dazed. The host tests it with pre-impact velocity and approach angle, once per action per target, and enemies hitting enemies pass on 60% of the momentum.
- Launches follow ballistic arcs, and air hits extend hang time up to three juggles.
- Pulls use bounded acceleration with separation steering, so bodies never stack.
- Ice sets friction to 0.1 through a per-cell lookup, and slipping enemies fall prone.

Destruction. Selected props have an intact and a pre-fractured version (Blender Cell Fracture). The host changes the prop’s gameplay state and sends break(prop_id, seed); each PC spawns pooled chunks that vanish after 4 s. Breakable barriers reveal shortcuts and switch on prepared navigation links, big collapses are authored animations, and destroyed objects never block a required route.

Ragdolls and secondary motion. Death ragdolls are local (PhysicalBoneSimulator3D, at most six at once) and settle out of the way. Hit reactions are authored first, then blend selected upper-body bones physically at 30–60% for 0.3 s. Capes and hair use SpringBoneSimulator3D, and foliage bends around heroes in a shader.

Elemental surfaces

| Surface | + Fire | + Cold | + Lightning | + Nature | + Holy | Effect |
| --- | --- | --- | --- | --- | --- | --- |
| Water | Steam cloud (enemies Blinded) | Ice | Electrified | Overgrowth ×2 | Holy water | Wet; −10% speed |
| Ice | Water | Refresh | Shatters (Brittle) | — | — | Friction 0.1; knockback ×2 |
| Oil | Explosion + Burning | — | Ignites | — | — | 30% slow |
| Burning | Refresh | Extinguished → Water | — | Spreads into briars | — | Damage over time |
| Overgrowth | Burns fast | Frozen briars | Thunderbloom | Refresh | — | Root chance for enemies; cover |
| Poison cloud | Explosion | Dissipates | — | Absorbed | Cleansed | Envenomed |
| Sanctified | Ashen | — | — | Blessed grove | Refresh | Heroes regenerate; undead burn |
| Rift well | — | — | — | — | — | Pulls bodies; curves projectiles |


Build order: Water, Ice, Oil and Fire first; Overgrowth, Poison cloud and Sanctified once those are reliable; Rift well with Singularity Rift. The first chain to prove is Rain → Water → Freeze → Ice → Knockback → Wall slam.
- Each room uses 0.5 m cells in bounded chunks, storing material, intensity (0–15), flags (Electrified, Blessed, Cursed), owner and expiry. Clouds live on a separate layer.
- The host updates active cells and their neighbours at 10 Hz, from rules in a data table.
- The grid writes a small texture that the ground shader samples to blend water, ice, fire and briars; decals are only for hero moments.
- Changed chunks go out with revisions, run-length encoded only when that is smaller, plus a full snapshot on join or recovery. Never assume an update fits in 1 KB.
- Hazard damage is time-based, ticking per actor and hazard type after 0.5 s of contact; crossing more cells never multiplies it.

Enemy AI and the Combat Director
- Enemies run data-driven state machines. LimboAI behaviour trees are allowed only where a boss needs them, after its Godot 4.7 build is verified.
- A host-side Combat Director gives each hero attack tokens: by default one melee-or-heavy commitment and two ranged. An enemy must claim a token before its telegraph starts.
- Enemies without a token keep up the pressure: they strafe, reposition, flank, defend or prepare instead of queueing.
- Engagement slots around each hero (six at 2 m, ten at 5 m) spread attackers out and reserve reachable approach positions.
- Tokens are released when an attack ends or is interrupted, and on stun, ragdoll, death, despawn and retargeting. A 1 s audit reclaims leaks, which would otherwise shrink the pool until enemies silently stop attacking.
- One aggression dial per encounter scales every pool, and difficulty sets it; Heroic allows two melee commitments.
- Taunts change target preference without making the partner irrelevant.
- Swarms follow host flow fields updated at 4 Hz; elites use NavigationServer3D with avoidance.
## Saves and transactions

There is one canonical campaign save holding both heroes. The current host is its only writer, and a copy replaces another only when its history proves it is newer; computer clocks never decide.

What a checkpoint holds: both heroes (attributes, allocations, equipment, inventories, loadouts), shared XP and level, materials, the rune library, Bond progression, world and room state, Emberrest upgrades, quest flags and resolved choices, journal entries, the expedition seed and the latest Waystone.

How it is written
- Versioned JSON with a tested migration chain; never serialise engine objects with var_to_bytes.
- Local atomic replacement, with checksums and retained backups, after every cleared room, boss reward and camp change.
- Each checkpoint records its parent revision and hash.
- Completed checkpoints are mirrored to the guest at every Waystone and rest, so either PC can host the next session.

Resolving copies
- A copy automatically supersedes another only when its ancestry proves it is a descendant.
- Divergent branches are kept and shown side by side for you to pick. They are never merged and never chosen by timestamp.
- Switching hosts happens cleanly from a shared checkpoint. If the host drops mid-encounter, you may replay the unfinished progress since that checkpoint.

Transactions
- Gifts, trades, crafting and reward claims are host transactions with unique IDs, so a repeated packet can’t duplicate or lose an item.
- A hand-over animation follows a committed transfer; it never performs it.
- Dungeon layouts come from a shared seed, and the host rolls all loot and sends the results.
- Solo activities (training, photos, drafts, letters) live outside the campaign save, so they can never create a conflicting branch.
## Art, assets, avatars, animation and audio

The look is “Ember Storybook”: detailed storybook fantasy built on one consistent character family, so heroes, enemies and armour read as one world. Consistency comes from shared proportions, rig, materials and lighting, not from re-colouring unrelated packs.

Style guide
- Expressive adult heroes with recognisable hair, faces, colours and accessories; the most detail goes to the two heroes and key encounters.
- Soft, atmospheric light, warm at home and dramatic in dungeons, with one colour grade (LUT) and a controlled palette per region.
- Clear material differences between cloth, metal, leather, skin and stone; readable silhouettes and restrained outlines.
- Readability first: muted enemies, red-orange telegraphs above player effects, your gold and Anastasia’s violet.
- Scale: 1 unit = 1 m, heroes 1.8 m tall, doors 3 m wide. Check every asset from the gameplay camera.
- Lower graphics settings never change hitboxes, telegraphs or gameplay objects.

Free sources (the seed of the licence ledger)

| Asset | Licence | Use |
| --- | --- | --- |
| Quaternius Universal Base Characters, free Standard edition | CC0 | Hero bodies and the canonical rig |
| Quaternius Modular Character Outfits – Fantasy | CC0 | Modular armour on the same rig |
| Quaternius Universal Animation Library, free Standard edition | CC0 | Locomotion, combat, emotes |
| Quaternius medieval village, stylized nature and fantasy prop kits | CC0 | Emberrest and the regions |
| KayKit dungeon and nature kits, free tiers | CC0 | Props where proportions fit; never the hero style |
| Kenney props, UI and audio, including Impact Sounds | CC0 | Props, interface, impacts |
| Poly Haven, ambientCG | CC0 | Textures and HDRIs |
| Freesound, CC0 uploads only | CC0 | Ambience and foley |


Asset policy
- Baseline: CC0 third-party art and audio plus your own work. Paid “Source” editions are optional extras; plan only on the free downloads.
- Any exception, such as the Sonniss GDC audio bundles (royalty-free, not CC0) or CC-BY music credited in game, needs a ledger row and an explicit yes from you.
- Not used: Mixamo, Fab, Unity Asset Store packs, non-commercial licences, Hunyuan3D, and photo-to-3D of faces.
- The ledger, /docs/license_ledger.csv, records asset ID, source URL, author, licence, edition downloaded, files included, attribution text, modifications and date verified. CI fails if any file in /assets has no row; software and add-on licences are tracked separately.

Your avatars
- Choose compatible base bodies and one canonical skeleton.
- Customise face proportions, hair, skin, accessories and starting outfits in Blender. Anastasia can sketch her look in VRoid Studio first as a reference sheet, while the game model stays on the Quaternius base.
- Keep one rest pose, naming scheme, scale and material convention.
- Retarget animations with Godot’s humanoid bone mapping; rest poses and tracks matter, not just bone names.
- Validate locomotion, weapon grips, attack contacts, dodge, revive and camp gestures.
- Split the body into six regions that armour pieces hide, to prevent clipping.
- Add foot placement, look-at and secondary motion once the base set works.
- Export runtime assets as glTF/GLB.

The Milestone 0 asset test scene holds both heroes beside an enemy, stairs, slopes, equipment swaps, attacks, a ragdoll and representative lighting. A real keepsake can become a Relic: model it from your own photos, or with open-source photogrammetry. Props only, never faces.

Animation
- The first polished heroes need directional locomotion with starts, stops and turns, upper-body attack layers, directional hit reactions, foot IK, weapon sockets with timed trails, blinking, eye direction and a few camp expressions.
- Keep combat-readable speed and recovery consistent across clips from different sources.
- Your own signature moves and emotes can come from phone video through free motion-capture tools such as FreeMoCap or Rokoko Vision. Treat it as a fun extra, not a dependency, and check each tool’s terms.

VFX: slash meshes with scrolling-UV shaders, Blender-rendered flipbooks and GPUParticles3D, with godotshaders.com for starting points and each shader’s licence checked.

Audio and voice
- SFX from Kenney and CC0 Freesound; music that is CC0 or your own, with CC-BY only as a ledger exception.
- Adaptive music layers (explore → combat → boss) on Godot’s interactive music streams, with no FMOD or Wwise.
- Record your own voices in Audacity with light reverb, pitch and EQ: selected moments first, more if you enjoy it.
## Tech stack, repository and the AI-agent playbook

Godot fits this project because nearly every project file is plain text that an AI agent can read, diff and test headless. The stack costs $0, and nothing in it is needed that Godot’s command line can’t build and test.

| Layer | Choice | Notes |
| --- | --- | --- |
| Engine | Godot 4.7.2 stable, pinned | MIT. Move to 4.8 only after its first maintenance release, and only between milestones |
| Language | Typed GDScript | C# only for an isolated hot path, if profiling demands it |
| Rendering | Forward+ on Direct3D 12, with quality presets; LightmapGI in dungeons, SDFGI off | Vulkan stays a tested fallback (--rendering-driver vulkan) |
| Physics | Built-in Jolt | Set explicitly in project settings |
| Netcode | ENet high-level multiplayer + netfox 1.35.3 | MIT; pinned, with plain RPCs for everything it doesn’t predict |
| Connection | Tailscale Personal; LAN | Free |
| Abilities and stats | A custom “GAS-lite”: attributes, effects, tags and abilities as typed Resources | Yours |
| Enemy AI | Data-driven state machines; LimboAI optional | Verify LimboAI on 4.7 before adopting |
| Dialogue | Custom plain-text runner with co-op voting | Dialogic 2 as fallback |
| Tests | GUT, run headless | Pin the version that passes the Milestone 0 compatibility check |
| Editor bridge | An MCP bridge to the Godot editor, optional | A convenience only, never a build dependency |
| Tools | Blender, Krita, Audacity | Free |
| Version control | Git, a private GitHub repo, LFS for large binaries, and a second local backup | GitHub Free includes 10 GiB of LFS storage and 10 GiB of monthly bandwidth |
| Builds | Versioned ZIPs over Tailscale first; later an itch.io restricted page with butler for auto-updates | Free |


Repository layout
- /AGENTS.md, with CLAUDE.md pointing to it.
- /docs/design/*.md, /docs/license_ledger.csv, and /docs/godot_api/: the 4.7 class reference generated with --doctool, so agents search real APIs.
- /data/: the CSV tables and the .tres definitions.
- /game/, /assets/ with their .import files, /tests/, and /tools/ for the ledger checker, data validators and two-instance launcher.
- .godot/ is ignored.

AGENTS.md essentials (short and authoritative)
- Godot 4.7.2 and the pinned add-on versions only. Never Godot 3 APIs: KinematicBody → CharacterBody3D, Spatial → Node3D, yield → await, export → @export, onready → @onready, instance() → instantiate(), string connect() → signal.connect(callable).
- Static typing everywhere. Every gameplay number lives in /data, with stable content IDs and one source of truth per definition.
- The host owns shared gameplay: never apply damage, roll loot or change progression on a client.
- Prediction and replay code is free of side effects.
- Every system ships with tests run through godot --headless, plus a scene-load check. Never change a test’s expected values just to make it pass.
- Commit .import sidecar files, because they are source configuration, but change import settings only through the editor. Never commit .godot/.
- One system per pull request, and a human reviews every visual change.

Test-first targets: damage and armour math; reaction resolution (each primer consumed once, no loops); golden-grid surface tests; 100,000-roll loot statistics against the real tables; save migrations and branch conflicts; gift and craft idempotency; Combat Director token-leak tests; a headless smoke test that loads every scene and resource; and bot soak tests.
## Performance budgets

Benchmark on the slower of your two PCs at 1080p and 60 fps, reporting frame-time percentiles and visible stutters. Start with conservative limits and raise them only after profiling both machines.

| Item | Sunken Crypt acceptance | Target after profiling |
| --- | --- | --- |
| Frame time | 60 fps; report percentiles and stutters | ≤16.6 ms with full effects (gameplay CPU ≤6 ms, render ≤8 ms) |
| Representative fight | Two heroes, 20 active enemies, a boss variant, full effects | 60 enemies with full AI; 120 with distance-throttled AI |
| Gameplay rigid bodies | ≤24 active | ≤150 active; enemies stay kinematic |
| Ragdolls | Up to 6, a ceiling rather than a guaranteed allocation | 6 |
| Cosmetic debris per PC | 40 pieces, pooled, 4 s lifetime | Same |
| Triangles | Heroes 15–25k with armour; enemies 3–8k; bosses ≤60k | Same, with auto-LOD |
| Textures and GPU memory | 2K heroes, 1–2K environment; under 4 GB | Same |
| Draw calls | Measure | Under 2,000; MultiMesh for grass, rubble and swarms |
| Particles | Measure | ≤40 GPU emitters, ≤30k particles |
| Network | Under 100 KB/s each way, measured with overhead | Under 40 KB/s each way in a busy fight |
| Stability | A one-hour two-PC soak | Repeated sessions stay stable |


Pool projectiles, enemies, VFX and damage numbers, and profile at every milestone. A 60-enemy fight is a later benchmark, not a condition for the game’s quality.
## Roadmap, gates and cut list

The first engineering commitment is a two-PC arena with authoritative combat and a recoverable shared save; the first production commitment is the Sunken Crypt. Every milestone from M1 on is something you can sit down and play together.
*(diagram in the original Word document)*

milestone roadmap · 6 milestones with gates, then a chapter a year

Each diamond is the test that must pass before the next milestone begins; the highlighted milestone is the first production commitment.

What each milestone contains
- M0 Foundations: the repo and AGENTS.md; GUT with headless CI; data loaders; host and join over Tailscale with the network overlay; predicted movement on static geometry; checkpoint mirroring; the asset test scene.
- M1 Combat arena: Vanguard and Riftweaver with four abilities each and basic Form runes; Shatterfall and Thunderclap; water, ice, oil and fire; knockback and wall slams; downed and revive; Combat Director v1; Bond Tether v1; two enemy types and an elite; hit feel; shared pause and reconnect.
- M2 The Sunken Crypt: the full adventure below, at levels 3–7 with a fifth ability each; 12 runes; personal loot and gifting; the forge and kitchen; a small constellation, the first Bond perks and Hearthflare; one camp conversation and about 40 banter lines; the Chronicle; saves with migration and checkpoint recovery; avatars v1.
- M3 Act 1 complete: all four classes playable to level 12; the Specialization Trial; Millrace Tunnels and Old Lighthouse; Forging Potential crafting, dice checks, co-op dialogue and voting; Act 1 Bond events and Emberrest growth.
- M4 Acts 2–4: the remaining abilities, specializations, rune library, expeditions and finales, one act at a time. Introduce one new environmental mechanic at a time, then combine them in Act 3.
- M5 Polish and endgame: animation, VFX, audio, UI readability, accessibility and performance passes; Legend difficulty; challenge ranks; Memory Delves.

These are planning estimates at 10–15 development hours a week, engine learning included. Re-forecast after M2 from your real pace, and again after Act 1.

The Sunken Crypt, step by step
- Leave Emberrest after choosing gear and a meal.
- Learn coordinated attacks in the flooded entrance.
- Use water, ice, oil and fire in the drowned chapel.
- Solve a two-person puzzle with interchangeable roles.
- Stagger the Bellkeeper by slamming it into its own bell.
- Find a rune and test it before the boss.
- Defeat the Drowned Abbess: floods alternate with exposed anchors, and the sluice wheels let any pair win.
- Return home, choose rewards, upgrade gear and unlock a Chronicle entry.

Why Dawn Vanguard + Riftweaver first. The pair covers melee against ranged, Impact against Frozen, knockback and wall slams, the water → ice → shatter chain, pull physics (Singularity Rift into Leap Slam) and shared barriers. It is also the original “Anastasia freezes, you shatter” moment. Your preferences override it: if Anastasia wants the Shadowstrider, start with Vanguard + Shadowstrider (Coup de Grâce) and bring surfaces in during M2.

Cut list, in order, if production slips
- Cosmetic destruction density and secondary physics.
- Bespoke Double Tech animations; every pairing uses Hearthflare.
- Rally exchanges.
- Procedural variation of rooms on replays.
- Optional voice coverage.
- Endgame modifiers, Memory Delves and Legend difficulty.
- Optional quests, side rooms and repeated encounter variants.
- The second specialization per class.

If the forecast after Act 1 still runs too long, shorten Acts 2–4 to two expeditions each before touching anything below.

Never cut: responsive two-player combat and the netcode foundations, reliable saves, downed and revive, both heroes growing stronger, gifting, Emberrest, Bond events and the Chronicle.
## Test plan and verification

Automated tests guard the rules that break silently; playtests decide whether it is fun. Both run at every milestone.

| System | Cases that must pass |
| --- | --- |
| Combat math | Local and global modifiers applied once; conversion; mitigation; fractional damage; capped recovery; the vulnerability and Bond caps |
| Resonance | Mirror classes; partner attribution; expired primers; two finishers on one primer; bosses resisting control; the Rally limit |
| Triggers | No echo loops, repeated detonation or recursive damage transfer |
| Movement | Slopes, walls, dodge, correction, interruption, replay without duplicate effects |
| Collision | Fast projectiles, initial overlap, moving targets, melee rotation, wall-slam deduplication |
| Surfaces | Reaction order, expiry, ownership, frame-rate independence, snapshot recovery, golden grids |
| AI | Token release after death, stun, ragdoll, despawn and retargeting; reachable engagement positions |
| Loot | Affix eligibility, caps, duplicate groups, seeded generation, 100,000-roll distributions against the real tables |
| Saves | Migration, interrupted writes, a corrupt latest file, branch conflicts, host switching, both heroes loading into the right identities |
| Transactions | Repeated gift and craft requests; a disconnect during acceptance; no duplication |
| Networking | 0, 80 and 150 ms round trip; jitter; 0% and 2% loss; reconnect while paused; mismatched builds |
| Content | Every scene and resource loads; no missing IDs, broken animation references or ledger gaps |


Movement target: at 80 ms round trip, the 95th-percentile correction stays under 0.25 m on the standard traversal course. Measure and report failures; never replace the test with a claim of “zero jitter”.

Verification checklist
- ☐ Physics: fast projectiles and dashes respect walls, destroyed objects never block required routes, and low settings keep gameplay identical.
- ☐ Balance: every mandatory encounter is cleared with every class pairing, with no dedicated healer.
- ☐ Performance: the busiest encounter is measured on both PCs.
- ☐ Usability: both of you can read a combo cue, equip an upgrade, revive and join a story choice without explanation.
- ☐ Feel: all ten pairings are playtested before the campaign is done; automated combinations can’t tell you whether a build is fun.
- ☐ Assets: every file has a ledger row with its free edition and licence.
## Decisions for the two of you

Only the first of these is needed before Milestone 1; the rest can wait until session zero or later.
- Which class does each of you want first? The default is Vanguard + Riftweaver.
- Your heroes’ names, and the world’s name.
- Session zero: which real memories and inside jokes become relics, places and quests, and what your lines and veils are.
- Voices: both of you throughout, or only at key moments?
- Default difficulty, and which assists each of you turns on.
- Which PC hosts by default? Usually the stronger PC on the better connection.
- Will the game ever be shared beyond the two of you? The CC0 baseline keeps that door open either way; this decides whether licence exceptions are ever allowed.

Settled by this plan: friendly fire is off; solo play covers training, photos, drafts and letters; avatars use the Quaternius base, with VRoid only as a sketchpad; the campaign runs four acts to level 40.
## How this plan merges the two earlier plans

Where the two plans agreed, this plan keeps the shared design. Where they conflicted, the table shows the decision and why; everything else is the stronger version of each system, combined.

| Topic | Word master plan | Integrated Blueprint | Decision |
| --- | --- | --- | --- |
| Scope | Prologue + 3 acts, level 20, then anniversary chapters | Prologue + 4 acts, level 40, 13 expeditions, 48 abilities, ~100 runes | The larger campaign you chose, delivered act by act, with anniversary chapters after it |
| Abilities | 7–8 per class, with tags and descriptions | 12 per class, names only | 12 per class, each with a tag, unlock level and description |
| Combo payoff | ×3.5 with a partner’s primer, ×2 with your own | +50% and +25% | ×2 and ×1.25, plus strong named effects: worth chasing, never runaway |
| Primer limit | One per player per enemy | One per family per enemy | One per player, which handles mirror classes and keeps icons readable; the Blueprint’s per-action detonation limits added |
| Bosses | A primer gauge; each combo removes 25% of the stagger bar | Primers in vulnerable phases; stagger tuned per encounter | The Blueprint’s rules, plus the master plan’s 6 s Staggered window |
| Bond Tether | Damages by default; channelled; snaps at 18 m | Cosmetic; damage only from an ability or rune | Cosmetic by default; Link abilities and Tetherblade runes make it a weapon |
| Bond nodes | Earned from Bond events | Never tied to affectionate content | Earned from finales and co-op firsts; Bond events give cosmetic and story rewards |
| Disagreements | A Charisma duel | Talk it out; no persuasion contest | Talk it out, or a Fate roll only if you both agree |
| Rescues | A “Debt of Life” counter | No scoreboard | Rescues recorded as shared memories |
| Saves | Newest timestamp and version win | Ancestry and explicit branch choice | Ancestry; clocks never decide |
| Rounding | Round down after each stage | Fractional precision to the end | Fractional precision |
| Resistances | Act II and III penalties | No mandatory penalties | No penalties |
| Equipment | 6 slots; Rare has 3 affixes + 1 forged | 8 slots; Rare up to 4 with prefix and suffix limits | 8 slots; Rare has 3 affixes + 1 forged slot, within those limits |
| Crafting | Includes a random reroll | Fixed, previewed costs | Fully deterministic; a reroll becomes choosing an affix |
| Runes | Two sockets; tiered rune items | Three socket types; a shared library | Three sockets and a shared library; duplicates raise tiers |
| Art | Chunky low-poly on one gradient atlas | Detailed storybook on one character family | Detailed storybook, keeping the master plan’s readability and scale rules |
| Avatars | Quaternius or VRoid, chosen by eye | Quaternius; no VRoid conversion | Quaternius; VRoid only as a likeness sketchpad |
| Licences | CC0-first; Mixamo and Fab allowed | CC0 and original work only | CC0 and original work; exceptions only by written decision |
| Rendering | Direct3D 12 | Vulkan first | Direct3D 12, Godot’s Windows default since 4.6; Vulkan as fallback |
| Data format | CSV, imported into Resources | Resources; avoid two formats | Resources for definitions, CSV for tables, never both for one thing |
| Lag compensation | Client hit claims; 150 ms rewind | Host hit queries; 200 ms history | Host queries with 200 ms history, keeping instant hit feedback for the guest |
| .import files | Never edit | Commit them | Commit them; change them only through the editor |
| Offline play | Crafting, War Table, banked XP | Training, photos, drafts | Training, photos, drafts and letters; the War Table is deferred |
| Friendly fire | An open decision | Off | Off |
| Enemy attack tokens | 1 melee, 1 heavy, 2 ranged | 1 melee-or-heavy, 2 ranged | The gentler default; Heroic raises it |
| First adventure | The Sunken Observatory and the Bellkeeper | The Sunken Crypt and the Drowned Abbess | The Sunken Crypt, with the Bellkeeper as its elite |
| Story start | You meet in the prologue | An established couple | An established couple, whose names appear together on the first co-written page |
| Connection extras | GodotSteam with app ID 480 | Not included | Dropped; Tailscale and LAN cover two PCs |
| Finisher types | Impact, Eldritch, Precision, Primal | Impact, Precision, Arcane; Primal only as flavour | Four types, one per class (Impact, Arcane, Precision, Primal), which keeps all ten pairings symmetrical |


New in this version: an Act 4 theme (Write), duo mechanics for all 13 finales, a full unlock schedule for the 48 abilities, Bond-node sources, letters and timed gift delivery, small anniversary gifts during development, and one merged cut list.
## References

Versions and plan terms were re-checked on 8 November 2026.
- Godot 4.7.2 maintenance release
- Godot 4.6 dev 5: Direct3D 12 becomes the Windows default
- Godot docs: CSV files import as translations by default
- netfox 1.35.3 on the Godot Asset Library
- netfox.noray
- Tailscale free plans and pricing
- GitHub Git LFS quotas and billing
- Quaternius Universal Base Characters
- Quaternius Modular Character Outfits – Fantasy
- Elan Ruskin, AI-driven Dynamic Dialog through Fuzzy Pattern Matching, GDC 2012
