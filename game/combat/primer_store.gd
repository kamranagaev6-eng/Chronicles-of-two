class_name PrimerStore
extends RefCounted
## Primer tags on enemies. Each player holds at most one primer per enemy (so at most two per enemy);
## a new primer from the same player replaces their old one. After a detonation the same primer type
## cannot be reapplied to that target until the lockout ends. Host-only.


class Primer:
	extends RefCounted
	var type: StringName
	var owner_slot: int
	var strength: float = 1.0
	var applied_tick: int
	var expires_tick: int
	## Unique action ID that created it; that same action can never consume it.
	var source_action: int

	func is_live(tick: int) -> bool:
		return tick < expires_tick


var _by_target: Dictionary = {}   # target_id -> Array[Primer]
var _lockouts: Dictionary = {}    # "target|type" -> tick when the lockout ends


## Returns false when the primer type is locked out on that target.
func apply(target_id: int, type: StringName, owner_slot: int, strength: float, tick: int, duration_ticks: int, source_action: int) -> bool:
	if is_locked_out(target_id, type, tick):
		return false
	var list: Array = _by_target.get(target_id, [])
	for i in range(list.size() - 1, -1, -1):
		var existing: Primer = list[i]
		if existing.owner_slot == owner_slot or not existing.is_live(tick):
			list.remove_at(i)
	var p := Primer.new()
	p.type = type
	p.owner_slot = owner_slot
	p.strength = strength
	p.applied_tick = tick
	p.expires_tick = tick + duration_ticks
	p.source_action = source_action
	list.append(p)
	_by_target[target_id] = list
	return true


func is_locked_out(target_id: int, type: StringName, tick: int) -> bool:
	var key := "%d|%s" % [target_id, type]
	return _lockouts.has(key) and tick < int(_lockouts[key])


func live_primers(target_id: int, tick: int) -> Array[Primer]:
	var out: Array[Primer] = []
	for p: Primer in _by_target.get(target_id, []):
		if p.is_live(tick):
			out.append(p)
	return out


func primer_of(target_id: int, owner_slot: int, tick: int) -> Primer:
	for p: Primer in live_primers(target_id, tick):
		if p.owner_slot == owner_slot:
			return p
	return null


## Consume one primer for a finisher, preferring the partner's. Returns null when nothing is consumable.
func consume_for_finisher(target_id: int, attacker_slot: int, tick: int, action_uid: int, lockout_ticks: int) -> Primer:
	var candidates := live_primers(target_id, tick)
	var chosen: Primer = null
	for p: Primer in candidates:
		if p.source_action == action_uid:
			continue
		if p.owner_slot != attacker_slot:
			chosen = p
			break
		if chosen == null:
			chosen = p
	if chosen == null:
		return null
	var list: Array = _by_target.get(target_id, [])
	list.erase(chosen)
	_lockouts["%d|%s" % [target_id, chosen.type]] = tick + lockout_ticks
	return chosen


func clear_target(target_id: int) -> void:
	_by_target.erase(target_id)
	var prefix := "%d|" % target_id
	for key: String in _lockouts.keys():
		if key.begins_with(prefix):
			_lockouts.erase(key)


func prune(tick: int) -> void:
	for target_id: int in _by_target.keys():
		var list: Array = _by_target[target_id]
		for i in range(list.size() - 1, -1, -1):
			if not (list[i] as Primer).is_live(tick):
				list.remove_at(i)
		if list.is_empty():
			_by_target.erase(target_id)
	for key: String in _lockouts.keys():
		if tick >= int(_lockouts[key]):
			_lockouts.erase(key)
