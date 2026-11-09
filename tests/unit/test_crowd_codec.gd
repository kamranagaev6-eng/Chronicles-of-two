extends GutTest


func _entity(id: int = 1) -> CrowdCodec.Entity:
	var entity: CrowdCodec.Entity = CrowdCodec.Entity.new()
	entity.id = id
	return entity


func test_empty_crowd_is_a_valid_complete_snapshot() -> void:
	var packet: PackedByteArray = CrowdCodec.encode(12, [])
	assert_eq(packet.size(), CrowdCodec.HEADER_BYTES)
	var decoded: Dictionary = CrowdCodec.decode(packet)
	assert_eq(int(decoded["tick"]), 12)
	assert_eq((decoded["entities"] as Array).size(), 0)


func test_every_truncated_packet_and_unknown_version_are_rejected() -> void:
	var packet: PackedByteArray = CrowdCodec.encode(12, [_entity()])
	for length: int in range(packet.size()):
		assert_true(CrowdCodec.decode(packet.slice(0, length)).is_empty(), "Truncation at byte %d" % length)
	packet[0] = CrowdCodec.VERSION + 1
	assert_true(CrowdCodec.decode(packet).is_empty())


func test_trailing_bytes_and_incorrect_count_are_rejected() -> void:
	var packet: PackedByteArray = CrowdCodec.encode(12, [_entity()])
	packet.append(0)
	assert_true(CrowdCodec.decode(packet).is_empty())
	packet = CrowdCodec.encode(12, [_entity()])
	packet[5] = 2
	assert_true(CrowdCodec.decode(packet).is_empty())
	packet[5] = 0
	assert_true(CrowdCodec.decode(packet).is_empty())


func test_zero_or_duplicate_network_entity_ids_are_rejected() -> void:
	var packet: PackedByteArray = CrowdCodec.encode(12, [_entity(1), _entity(2)])
	packet[CrowdCodec.HEADER_BYTES] = 0
	packet[CrowdCodec.HEADER_BYTES + 1] = 0
	assert_true(CrowdCodec.decode(packet).is_empty())
	packet = CrowdCodec.encode(12, [_entity(1), _entity(2)])
	packet[CrowdCodec.HEADER_BYTES + CrowdCodec.ENTITY_BYTES] = 1
	assert_true(CrowdCodec.decode(packet).is_empty(), "A full snapshot cannot contain two lifetimes for one ID")


func test_encoder_rejects_duplicate_ids_and_missing_entities() -> void:
	assert_true(CrowdCodec.encode(12, [_entity(1), _entity(1)]).is_empty())
	assert_true(CrowdCodec.encode(12, [null]).is_empty())
	assert_true(CrowdCodec.encode(-1, [_entity()]).is_empty())


func test_encoder_does_not_silently_wrap_out_of_range_fields() -> void:
	var invalid_fields: Array[Dictionary] = [
		{"field": "id", "value": 0}, {"field": "id", "value": 0x10000},
		{"field": "generation", "value": 256}, {"field": "kind", "value": -1},
		{"field": "anim", "value": 256}, {"field": "primer0", "value": 16},
		{"field": "primer1", "value": -1}, {"field": "flags", "value": 0x10000},
	]
	for invalid: Dictionary in invalid_fields:
		var entity: CrowdCodec.Entity = _entity()
		entity.set(str(invalid["field"]), invalid["value"])
		assert_true(CrowdCodec.encode(12, [entity]).is_empty(), str(invalid))


func test_non_finite_numbers_never_reach_the_wire() -> void:
	var entity: CrowdCodec.Entity = _entity()
	entity.position.x = NAN
	assert_true(CrowdCodec.encode(12, [entity]).is_empty())
	entity = _entity()
	entity.yaw = INF
	assert_true(CrowdCodec.encode(12, [entity]).is_empty())
	entity = _entity()
	entity.health = NAN
	assert_true(CrowdCodec.encode(12, [entity]).is_empty())


func test_continuous_host_ticks_wrap_in_the_32_bit_wire_field() -> void:
	var decoded: Dictionary = CrowdCodec.decode(CrowdCodec.encode(0x100000005, [_entity()]))
	assert_eq(int(decoded["tick"]), 5)


func test_valid_boundary_fields_survive_round_trip() -> void:
	var entity: CrowdCodec.Entity = _entity(0xFFFF)
	entity.generation = 0xFF
	entity.kind = 0xFF
	entity.anim = 0xFF
	entity.primer0 = 0x0F
	entity.primer1 = 0x0F
	entity.flags = 0xFFFF
	entity.position = Vector3(-327.68, 327.67, 0.0)
	var decoded: Dictionary = CrowdCodec.decode(CrowdCodec.encode(0xFFFFFFFF, [entity]))
	var result: CrowdCodec.Entity = decoded["entities"][0]
	assert_eq(result.id, 0xFFFF)
	assert_eq(result.generation, 0xFF)
	assert_eq(result.kind, 0xFF)
	assert_eq(result.anim, 0xFF)
	assert_eq(result.flags, 0xFFFF)
	assert_eq(result.primer0, 0x0F)
	assert_eq(result.primer1, 0x0F)
	assert_almost_eq(result.position, entity.position, Vector3.ONE * 0.001)
