class_name CombatDirector
extends RefCounted
## Host-side attack tokens and engagement slots. Each hero has a small pool of attack commitments
## (by default one melee-or-heavy and two ranged); an enemy must claim a token before its telegraph starts.
## Tokens are released when an attack ends or is interrupted, and on stun, ragdoll, death, despawn and
## retargeting. A periodic audit reclaims leaks, which would otherwise shrink the pool until enemies
## silently stop attacking.

const RING_INNER := 0
const RING_OUTER := 1

var base_melee: int = 1
var base_ranged: int = 2
var aggression: float = 1.0
var inner_count: int = 6
var inner_radius: float = 2.0
var outer_count: int = 10
var outer_radius: float = 5.0

var _holders: Dictionary = {}       # enemy_id -> {"hero": int, "kind": StringName, "tick": int}
var _counts: Dictionary = {}        # "hero|kind" -> int
var _slots: Dictionary = {}         # "hero|ring" -> Array[int] (enemy id or -1 per slot)
var _slot_of: Dictionary = {}       # enemy_id -> [hero, ring, index]


func configure_from_rules(heroic: bool = false) -> void:
	base_melee = int(GameData.rule(&"tokens_melee_heroic" if heroic else &"tokens_melee"))
	base_ranged = int(GameData.rule(&"tokens_ranged"))
	inner_count = int(GameData.rule(&"slots_inner_count"))
	inner_radius = GameData.rule(&"slots_inner_radius")
	outer_count = int(GameData.rule(&"slots_outer_count"))
	outer_radius = GameData.rule(&"slots_outer_radius")


## Tokens available per hero for a pool after the encounter's aggression dial.
func capacity(kind: StringName) -> int:
	var base := base_melee if kind == &"melee" else base_ranged
	if aggression <= 0.0:
		return 0
	return maxi(1, roundi(base * aggression))


func in_use(hero_slot: int, kind: StringName) -> int:
	return int(_counts.get("%d|%s" % [hero_slot, kind], 0))


func holds_token(enemy_id: int) -> bool:
	return _holders.has(enemy_id)


func holder_info(enemy_id: int) -> Dictionary:
	return _holders.get(enemy_id, {}) as Dictionary


func request_token(enemy_id: int, hero_slot: int, kind: StringName, tick: int) -> bool:
	if kind != &"melee" and kind != &"ranged":
		return false
	if _holders.has(enemy_id):
		var info: Dictionary = _holders[enemy_id]
		if int(info["hero"]) == hero_slot and info["kind"] == kind:
			return true
		release_token(enemy_id)
	if in_use(hero_slot, kind) >= capacity(kind):
		return false
	_holders[enemy_id] = {"hero": hero_slot, "kind": kind, "tick": tick}
	var key := "%d|%s" % [hero_slot, kind]
	_counts[key] = int(_counts.get(key, 0)) + 1
	return true


func release_token(enemy_id: int) -> void:
	if not _holders.has(enemy_id):
		return
	var info: Dictionary = _holders[enemy_id]
	var key := "%d|%s" % [int(info["hero"]), info["kind"]]
	_counts[key] = maxi(0, int(_counts.get(key, 0)) - 1)
	_holders.erase(enemy_id)


## Release everything an enemy holds (death, despawn).
func forget(enemy_id: int) -> void:
	release_token(enemy_id)
	release_slot(enemy_id)


## validator(enemy_id: int, hero_slot: int, kind: StringName, claimed_tick: int) -> bool says whether
## the holder still legitimately needs its token. Returns how many tokens were reclaimed.
func audit(validator: Callable) -> int:
	var reclaimed := 0
	for enemy_id: int in _holders.keys():
		var info: Dictionary = _holders[enemy_id]
		var ok: bool = validator.call(enemy_id, int(info["hero"]), info["kind"], int(info["tick"]))
		if not ok:
			release_token(enemy_id)
			reclaimed += 1
	return reclaimed


func token_count() -> int:
	return _holders.size()


# --- Engagement slots ----------------------------------------------------------------

func ring_size(ring: int) -> int:
	return inner_count if ring == RING_INNER else outer_count


func ring_radius(ring: int) -> float:
	return inner_radius if ring == RING_INNER else outer_radius


func slot_position(hero_pos: Vector3, ring: int, index: int) -> Vector3:
	var n := ring_size(ring)
	var angle := TAU * float(index) / float(n) + (0.0 if ring == RING_INNER else PI / n)
	var r := ring_radius(ring)
	return Vector3(hero_pos.x + cos(angle) * r, hero_pos.y, hero_pos.z + sin(angle) * r)


## Claim (or keep) the nearest free reachable slot around a hero. reachable(pos: Vector3) -> bool.
## Returns the slot position, or the hero position when every slot is taken or unreachable.
func request_slot(enemy_id: int, hero_slot: int, ring: int, hero_pos: Vector3, from_pos: Vector3, reachable: Callable) -> Vector3:
	var key := "%d|%d" % [hero_slot, ring]
	var slots: Array = _slots.get(key, [])
	if slots.size() != ring_size(ring):
		slots.resize(ring_size(ring))
		for i in slots.size():
			if slots[i] == null:
				slots[i] = -1
		_slots[key] = slots
	if _slot_of.has(enemy_id):
		var cur: Array = _slot_of[enemy_id]
		if int(cur[0]) == hero_slot and int(cur[1]) == ring:
			var p := slot_position(hero_pos, ring, int(cur[2]))
			if reachable.call(p):
				return p
		release_slot(enemy_id)
	var best := -1
	var best_d := INF
	for i in slots.size():
		if int(slots[i]) != -1:
			continue
		var p := slot_position(hero_pos, ring, i)
		if not reachable.call(p):
			continue
		var d := from_pos.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return hero_pos
	slots[best] = enemy_id
	_slot_of[enemy_id] = [hero_slot, ring, best]
	return slot_position(hero_pos, ring, best)


func release_slot(enemy_id: int) -> void:
	if not _slot_of.has(enemy_id):
		return
	var cur: Array = _slot_of[enemy_id]
	var key := "%d|%d" % [int(cur[0]), int(cur[1])]
	var slots: Array = _slots.get(key, [])
	var index := int(cur[2])
	if index < slots.size() and int(slots[index]) == enemy_id:
		slots[index] = -1
	_slot_of.erase(enemy_id)


func slot_of(enemy_id: int) -> Array:
	return _slot_of.get(enemy_id, []) as Array
