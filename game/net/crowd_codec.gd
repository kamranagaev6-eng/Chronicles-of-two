class_name CrowdCodec
extends RefCounted
## One packed snapshot for every host-simulated entity (enemies and important props), sent unreliably
## at 20 Hz. 17 bytes per entity; positions quantised to 1 cm within +/-327 m of the origin.

const VERSION := 1
const HEADER_BYTES := 7
const ENTITY_BYTES := 17


class Entity:
	extends RefCounted
	var id: int = 0
	var generation: int = 0
	## Enemy type index (GameData.enemy_index) or a prop kind >= 200.
	var kind: int = 0
	var position: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var anim: int = 0
	var health: float = 1.0   ## 0..1
	var stagger: float = 0.0  ## 0..1
	## Primer type index + 1 owned by each player slot (0 = none).
	var primer0: int = 0
	var primer1: int = 0
	var flags: int = 0


static func encode(tick: int, entities: Array[Entity]) -> PackedByteArray:
	if not is_valid_snapshot(tick, entities):
		return PackedByteArray()
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_u8(VERSION)
	buf.put_u32(tick & 0xFFFFFFFF)
	buf.put_u16(entities.size())
	for e: Entity in entities:
		buf.put_u16(e.id & 0xFFFF)
		buf.put_u8(e.generation & 0xFF)
		buf.put_u8(e.kind & 0xFF)
		buf.put_16(_q(e.position.x))
		buf.put_16(_q(e.position.y))
		buf.put_16(_q(e.position.z))
		buf.put_u8(int(round(fposmod(e.yaw, TAU) / TAU * 256.0)) & 0xFF)
		buf.put_u8(e.anim & 0xFF)
		buf.put_u8(int(round(clampf(e.health, 0.0, 1.0) * 255.0)))
		buf.put_u8(int(round(clampf(e.stagger, 0.0, 1.0) * 255.0)))
		buf.put_u8((e.primer0 & 0x0F) | ((e.primer1 & 0x0F) << 4))
		buf.put_u16(e.flags & 0xFFFF)
	return buf.data_array


## Returns {"tick": int, "entities": Array[Entity]} or an empty dictionary for malformed data.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_BYTES:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.data_array = bytes
	if buf.get_u8() != VERSION:
		return {}
	var tick := buf.get_u32()
	var count := buf.get_u16()
	if bytes.size() != HEADER_BYTES + count * ENTITY_BYTES:
		return {}
	var entities: Array[Entity] = []
	var ids: Dictionary[int, bool] = {}
	for _index: int in range(count):
		var e := Entity.new()
		e.id = buf.get_u16()
		if e.id == 0 or ids.has(e.id):
			return {}
		ids[e.id] = true
		e.generation = buf.get_u8()
		e.kind = buf.get_u8()
		e.position = Vector3(buf.get_16() / 100.0, buf.get_16() / 100.0, buf.get_16() / 100.0)
		e.yaw = buf.get_u8() / 256.0 * TAU
		e.anim = buf.get_u8()
		e.health = buf.get_u8() / 255.0
		e.stagger = buf.get_u8() / 255.0
		var primers := buf.get_u8()
		e.primer0 = primers & 0x0F
		e.primer1 = (primers >> 4) & 0x0F
		e.flags = buf.get_u16()
		entities.append(e)
	return {"tick": tick, "entities": entities}


static func is_valid_snapshot(tick: int, entities: Array[Entity]) -> bool:
	if tick < 0 or entities.size() > 0xFFFF:
		return false
	var ids: Dictionary[int, bool] = {}
	for entity: Entity in entities:
		if not _valid_entity(entity) or ids.has(entity.id):
			return false
		ids[entity.id] = true
	return true


static func _valid_entity(entity: Entity) -> bool:
	if entity == null:
		return false
	return entity.id > 0 and entity.id <= 0xFFFF \
		and entity.generation >= 0 and entity.generation <= 0xFF \
		and entity.kind >= 0 and entity.kind <= 0xFF \
		and entity.anim >= 0 and entity.anim <= 0xFF \
		and entity.primer0 >= 0 and entity.primer0 <= 0x0F \
		and entity.primer1 >= 0 and entity.primer1 <= 0x0F \
		and entity.flags >= 0 and entity.flags <= 0xFFFF \
		and entity.position.is_finite() and is_finite(entity.yaw) \
		and is_finite(entity.health) and is_finite(entity.stagger)


static func _q(v: float) -> int:
	return clampi(roundi(v * 100.0), -32768, 32767)
