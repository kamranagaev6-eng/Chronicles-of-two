class_name GameTypes
extends RefCounted
## Shared enums and stable index tables. Network messages use these small integers, never names.

## Player slots. Slot 0 hosts by default; either PC can host a later session.
const SLOT_HOST := 0
const SLOT_GUEST := 1
const SLOT_COUNT := 2
## Owners for surfaces and effects that are not a hero.
const OWNER_WORLD := 2
const OWNER_ENEMY := 3

## Action slots on the hero motor.
const ACT_BASIC := 0
const ACT_1 := 1
const ACT_2 := 2
const ACT_3 := 3
const ACT_4 := 4
const ACT_SHOVE := 5
const ACT_FLASK := 6
const ACTION_COUNT := 7

## Held-button bits carried in the input stream.
const BTN_ATTACK := 1
const BTN_INTERACT := 2
const BTN_BOND := 4

const PRIMER_TYPES: Array[StringName] = [&"dazed", &"sanctified", &"frozen", &"shocked", &"marked", &"envenomed", &"rooted", &"terrified"]
const FINISHER_TYPES: Array[StringName] = [&"impact", &"arcane", &"precision", &"primal"]
const DAMAGE_TYPES: Array[StringName] = [&"physical", &"fire", &"cold", &"lightning", &"holy", &"arcane", &"poison"]
## Append-only: indices are stored in motor state (Elemental Weave) and in the surface rule table.
const ELEMENTS: Array[StringName] = [&"fire", &"cold", &"lightning", &"holy", &"water"]

## Enemy animation states shared by the host simulation and every presentation.
enum Anim { IDLE, MOVE, TELEGRAPH, ATTACK, RECOVER, STUNNED, KNOCKBACK, FROZEN, STAGGERED, PRONE, DEAD, SPAWNING, LAUNCHED }

## Status flag bits replicated with each entity.
const FLAG_EXPOSED := 1
const FLAG_BURNING := 2
const FLAG_FROZEN := 4
const FLAG_STAGGERED := 8
const FLAG_SUPERCONDUCT := 16
const FLAG_ELITE := 32
const FLAG_WET := 64
const FLAG_DETONATE_READY := 128
const FLAG_BLINDED := 256
const FLAG_OILED := 512
const FLAG_SUBMERGED := 1024
const FLAG_WARDED := 2048


static func primer_index(primer: StringName) -> int:
	return PRIMER_TYPES.find(primer)


static func primer_at(index: int) -> StringName:
	if index < 0 or index >= PRIMER_TYPES.size():
		return &""
	return PRIMER_TYPES[index]


static func element_index(element: StringName) -> int:
	return ELEMENTS.find(element)


static func element_at(index: int) -> StringName:
	if index < 0 or index >= ELEMENTS.size():
		return &""
	return ELEMENTS[index]


static func damage_type_index(t: StringName) -> int:
	return DAMAGE_TYPES.find(t)


static func damage_type_at(index: int) -> StringName:
	if index < 0 or index >= DAMAGE_TYPES.size():
		return &"physical"
	return DAMAGE_TYPES[index]


static func is_elemental(damage_type: StringName) -> bool:
	return damage_type != &"physical" and damage_type != &"poison"


static func partner_of(slot: int) -> int:
	return 1 - slot


## Horizontal unit direction from a to b (zero if they coincide).
static func flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var len := d.length()
	if len < 0.0001:
		return Vector3.ZERO
	return d / len


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
