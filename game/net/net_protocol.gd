class_name NetProtocol
extends RefCounted
## Stable message vocabulary. Every message is plain data: ints, floats, strings, arrays,
## dictionaries and PackedByteArray. Never Resources, scene paths or object instances.

const PROTOCOL_VERSION := 1
const DEFAULT_PORT := 24680

## ENet transfer channels (netfox uses channel 0 for its input/state traffic).
const CH_SNAPSHOT := 1   ## unreliable_ordered: crowd snapshots
const CH_EVENTS := 2     ## reliable: gameplay events and hero stats
const CH_SURFACE := 3    ## reliable: surface chunk patches
const CH_CONTROL := 4    ## reliable: handshake, lobby, pause, requests
const CH_BULK := 5       ## reliable: checkpoint mirroring

## Gameplay event types (first element of every event array).
const EV_HIT := 1            ## [t, entity_id, amount, crit, dmg_type, source_slot, x, y, z, reaction_kind]
const EV_REACTION := 2       ## [t, reaction_id, name, kind, slot, x, y, z, radius, signature]
const EV_PRIMER := 3         ## [t, entity_id, primer_index, slot]
const EV_DEATH := 4          ## [t, entity_id, x, y, z]
const EV_TELEGRAPH := 5      ## [t, entity_id, shape, x, z, dir_x, dir_z, radius, arc_deg, length, ticks]
const EV_PROJ_SPAWN := 6     ## [t, proj_id, visual, team, x, y, z, vx, vy, vz, max_dist, radius]
const EV_PROJ_END := 7       ## [t, proj_id, x, y, z, burst]
const EV_HERO_HIT := 8       ## [t, slot, amount, x, y, z, dodged]
const EV_HERO_STATS := 9     ## [t, slot, health, max_health, barrier, state, downed_left_s, revive_progress]
const EV_WAVE := 10          ## [t, state, wave, wave_count, enemies_left]
const EV_SAVED := 11         ## [t, revision, short_hash]
const EV_SURFACE_FX := 12    ## [t, kind, x, y, z, count, element]
const EV_BOND := 13          ## [t, meter, gained_by_slot, reason]
const EV_SLAM := 14          ## [t, entity_id, speed, x, y, z]
const EV_STAGGER := 15       ## [t, entity_id, kind]  kind: 1 stun, 2 stagger
const EV_PING := 16          ## [t, slot, x, y, z]
const EV_PAUSE := 17         ## [t, paused, by_slot, reason, seconds_left]
const EV_BARRIER := 18       ## [t, slot, amount]
const EV_HEAL := 19          ## [t, slot, amount]
const EV_XP := 20            ## [t, amount, level, xp]
const EV_JOURNAL := 21       ## [t, text]
const EV_TELEGRAPH_END := 22 ## [t, entity_id]
const EV_REJECTED := 23      ## [t, slot, text]
const EV_DOUBLE_TECH := 24   ## [t, state, slot]  state: 1 requested, 2 fired, 3 expired
const EV_SPAWN := 25         ## [t, entity_id, kind, x, y, z]
const EV_DETONATE_READY := 26 ## [t, entity_id, slot]
const EV_BEAM := 27          ## [t, slot, x0, y0, z0, x1, y1, z1, visual]
const EV_LOADOUT := 28       ## [t, slot, abilities, runes]
const EV_BREAK := 29         ## [t, entity_id, kind, x, y, z]
const EV_GATE := 30          ## [t, gate_id, open]
const EV_OBJECTIVE := 31     ## [t, room_index, room_label, hint]
const EV_PROP := 32          ## [t, prop_id, value]  plates, wheels, shrines, bells (0..1)
const EV_REWARD := 33        ## [t, state, options]  state: 1 offer, 2 closed; options are rune ids
const EV_LIBRARY := 34       ## [t, rune_library]
const EV_PHASE := 35         ## [t, phase_name, seconds_left]  boss phases (flood, ebb, staggered)
const EV_COMPLETE := 36      ## [t, expedition_id, summary]
const EV_PARRY := 37         ## [t, slot, entity_id, x, y, z]
const EV_FINISHER := 38      ## [t, slot, entity_id, kind, lock_ticks]  kind: 1 kill, 2 heavy, 3 tandem
const EV_WEAPON := 39        ## [t, slot, state, x, y, z]  state: 1 thrown, 2 lodged, 3 recalled, 4 caught

## Hero life states carried in EV_HERO_STATS.
const LIFE_ALIVE := 0
const LIFE_DOWNED := 1
const LIFE_FALLEN := 2

## Encounter states carried in EV_WAVE.
const WAVE_PREP := 0
const WAVE_ACTIVE := 1
const WAVE_BREAK := 2
const WAVE_VICTORY := 3
const WAVE_RESTART := 4

## Projectile visuals.
const PV_ARCANE := 0
const PV_FROST := 1
const PV_FIRE := 2
const PV_HOLY_LANCE := 3
const PV_ARROW := 4
const PV_LIGHTNING := 5

## Telegraph shapes.
const TG_CIRCLE := 0
const TG_SECTOR := 1
const TG_LINE := 2

## Prop kinds share the entity space with enemies (enemy kinds are GameData.enemy_index values).
const KIND_OIL_BARREL := 200
const KIND_WATER_BARREL := 201
const KIND_ANCHOR := 202
const KIND_OATHSHIELD := 203
const KIND_RIFT_ANCHOR := 204
## Thrown signature weapons ride in the crowd snapshot as entities WEAPON_ENTITY_BASE + slot.
const WEAPON_ENTITY_BASE := 65010

## Reserved ids for environment telegraphs that are not entities (the Belfry bell).
const ENV_BELL := 65001
