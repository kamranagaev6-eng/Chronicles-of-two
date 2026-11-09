class_name SnapshotBuffer
extends RefCounted
## Client presentation of complete host snapshots. Never applies gameplay or extrapolates attacks.
## Samples the host timeline behind the existing interpolation_buffer_s data rule.

const TICK_MODULUS: int = 0x100000000
const TICK_MASK: int = TICK_MODULUS - 1
const HALF_TICK_RANGE: int = TICK_MODULUS / 2


class Frame:
	extends RefCounted
	var tick: int = 0
	var entities: Dictionary[int, CrowdCodec.Entity] = {}


var delay_ticks: float = 0.0
var interp_ticks: float:
	get:
		return delay_ticks
	set(value):
		if _tick_rate > 0.0:
			configure(_tick_rate, value / _tick_rate, _snapshot_rate)
var arrival_offset: float = -1.0
var _tick_rate: float = 0.0
var _snapshot_rate: float = 0.0
var _capacity: int = 2
var _frames: Array[Frame] = []
var _arrival_offsets: PackedFloat64Array = PackedFloat64Array()
var _newest_raw_tick: int = -1
var _newest_tick: int = -1


func _init() -> void:
	configure_from_rules()


func configure_from_rules() -> bool:
	GameData.ensure_loaded()
	return configure(GameData.rule(&"sim_tickrate"), GameData.rule(&"interpolation_buffer_s"), GameData.rule(&"enemy_snapshot_hz"))


## The two extra frames retain both sides of the interpolation interval.
func configure(tick_rate: float, delay_seconds: float, snapshot_rate: float) -> bool:
	if not is_finite(tick_rate) or not is_finite(delay_seconds) or not is_finite(snapshot_rate):
		return false
	if tick_rate <= 0.0 or delay_seconds < 0.0 or snapshot_rate <= 0.0 or snapshot_rate > tick_rate:
		return false
	_tick_rate = tick_rate
	_snapshot_rate = snapshot_rate
	delay_ticks = delay_seconds * tick_rate
	_capacity = maxi(2, ceili(delay_seconds * snapshot_rate) + 2)
	clear()
	return true


func clear() -> void:
	_frames.clear()
	_newest_raw_tick = -1
	_newest_tick = -1
	_arrival_offsets.clear()
	arrival_offset = -1.0


## Invalid, duplicate and older packets leave the entire buffer unchanged.
func push_packet(bytes: PackedByteArray) -> bool:
	var decoded: Dictionary = CrowdCodec.decode(bytes)
	if decoded.is_empty():
		return false
	var raw_tick: int = int(decoded["tick"])
	var entities: Array[CrowdCodec.Entity] = decoded["entities"]
	return _append_snapshot(raw_tick, entities)


## Compatibility with the arena's decoded-snapshot and local-arrival-clock interface.
func push(tick: int, entities: Array[CrowdCodec.Entity], local_tick: float) -> bool:
	if not is_finite(local_tick) or local_tick < 0.0 or not CrowdCodec.is_valid_snapshot(tick, entities):
		return false
	if not _append_snapshot(tick & TICK_MASK, entities):
		return false
	_arrival_offsets.append(_project_tick(local_tick) - float(_newest_tick))
	while _arrival_offsets.size() > _capacity:
		_arrival_offsets.remove_at(0)
	var total: float = 0.0
	for offset: float in _arrival_offsets:
		total += offset
	arrival_offset = total / float(_arrival_offsets.size())
	return true


func _append_snapshot(raw_tick: int, entities: Array[CrowdCodec.Entity]) -> bool:
	var unwrapped_tick: int = raw_tick
	if _newest_raw_tick >= 0:
		var distance: int = _tick_distance(raw_tick, _newest_raw_tick)
		if distance <= 0:
			return false
		unwrapped_tick = _newest_tick + distance
	var frame: Frame = Frame.new()
	frame.tick = unwrapped_tick
	for entity: CrowdCodec.Entity in entities:
		frame.entities[entity.id] = _copy_entity(entity)
	_frames.append(frame)
	while _frames.size() > _capacity:
		_frames.pop_front()
	_newest_raw_tick = raw_tick
	_newest_tick = unwrapped_tick
	return true


## Pass the synchronized host tick when an arrival-clock adjustment is unnecessary.
func sample_host_tick(host_tick: float) -> Array[CrowdCodec.Entity]:
	if _frames.is_empty() or not is_finite(host_tick) or host_tick < 0.0:
		return []
	return sample(_project_tick(host_tick) - delay_ticks)


## The arrival clock is smoothed over the same bounded window as retained snapshots.
func render_tick(local_tick: float) -> float:
	if not is_finite(local_tick) or local_tick < 0.0:
		return NAN
	return _project_tick(local_tick) - maxf(0.0, arrival_offset) - delay_ticks


## Empty snapshots remove every entity once their timestamp reaches the display timeline.
func sample(display_tick: float) -> Array[CrowdCodec.Entity]:
	if _frames.is_empty() or not is_finite(display_tick):
		return []
	var before: Frame = _frames[0]
	if display_tick <= float(before.tick):
		return _sample_frames(before, before, 0.0)
	for index: int in range(1, _frames.size()):
		var after: Frame = _frames[index]
		if display_tick < float(after.tick):
			var alpha: float = (display_tick - float(before.tick)) / float(after.tick - before.tick)
			return _sample_frames(before, after, alpha)
		before = after
	return _sample_frames(before, before, 0.0)


func depth(display_tick: float = NAN) -> int:
	if is_nan(display_tick):
		return _frames.size()
	var count: int = 0
	for frame: Frame in _frames:
		if float(frame.tick) > display_tick:
			count += 1
	return count


func span_ms() -> float:
	if _frames.size() < 2 or _tick_rate <= 0.0:
		return 0.0
	return float(_frames[-1].tick - _frames[0].tick) / _tick_rate * 1000.0


func latest_tick() -> int:
	return _newest_tick


func _project_tick(tick: float) -> float:
	if _newest_raw_tick < 0:
		return tick
	var raw_tick: int = floori(tick) & TICK_MASK
	return float(_newest_tick + _tick_distance(raw_tick, _newest_raw_tick)) + tick - floor(tick)


static func _tick_distance(newer: int, older: int) -> int:
	var distance: int = (newer - older) & TICK_MASK
	return distance - TICK_MODULUS if distance >= HALF_TICK_RANGE else distance


static func _sample_frames(before: Frame, after: Frame, alpha: float) -> Array[CrowdCodec.Entity]:
	var result: Array[CrowdCodec.Entity] = []
	var ids: Array[int] = before.entities.keys()
	ids.sort()
	for id: int in ids:
		var source: CrowdCodec.Entity = before.entities[id]
		var entity: CrowdCodec.Entity = _copy_entity(source)
		var next: CrowdCodec.Entity = after.entities.get(id) as CrowdCodec.Entity
		if next != null and source.generation == next.generation and source.kind == next.kind:
			entity.position = source.position.lerp(next.position, alpha)
			entity.yaw = lerp_angle(source.yaw, next.yaw, alpha)
		# Discrete state and membership advance at their snapshot tick, never early.
		result.append(entity)
	return result


static func _copy_entity(source: CrowdCodec.Entity) -> CrowdCodec.Entity:
	var entity: CrowdCodec.Entity = CrowdCodec.Entity.new()
	entity.id = source.id
	entity.generation = source.generation
	entity.kind = source.kind
	entity.position = source.position
	entity.yaw = source.yaw
	entity.anim = source.anim
	entity.health = source.health
	entity.stagger = source.stagger
	entity.primer0 = source.primer0
	entity.primer1 = source.primer1
	entity.flags = source.flags
	return entity
