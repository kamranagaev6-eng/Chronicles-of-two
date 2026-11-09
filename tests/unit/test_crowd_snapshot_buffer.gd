extends GutTest

var buffer: SnapshotBuffer


func before_each() -> void:
	buffer = SnapshotBuffer.new()
	assert_true(buffer.configure(60.0, 0.1, 20.0))


func _entity(id: int, x: float, generation: int = 1, kind: int = 0) -> CrowdCodec.Entity:
	var entity: CrowdCodec.Entity = CrowdCodec.Entity.new()
	entity.id = id
	entity.generation = generation
	entity.kind = kind
	entity.position = Vector3(x, 0.0, 0.0)
	return entity


func _push(tick: int, entities: Array[CrowdCodec.Entity]) -> void:
	assert_true(buffer.push_packet(CrowdCodec.encode(tick, entities)))


func test_empty_buffer_returns_no_entities() -> void:
	assert_eq(buffer.sample_host_tick(100.0).size(), 0)
	assert_eq(buffer.depth(), 0)
	assert_eq(buffer.latest_tick(), -1)


func test_interpolates_on_the_delayed_host_timeline() -> void:
	_push(0, [_entity(1, 0.0)])
	_push(6, [_entity(1, 6.0)])
	var result: Array[CrowdCodec.Entity] = buffer.sample_host_tick(9.0)
	assert_eq(result.size(), 1)
	assert_almost_eq(result[0].position.x, 3.0, 0.001, "100 ms delay at 60 Hz is six ticks")
	assert_almost_eq(buffer.sample_host_tick(9.5)[0].position.x, 3.5, 0.001, "Fractional rendering ticks stay smooth")


func test_interpolates_all_position_axes() -> void:
	var after: CrowdCodec.Entity = _entity(1, 6.0)
	after.position = Vector3(6.0, 2.0, -4.0)
	_push(0, [_entity(1, 0.0)])
	_push(6, [after])
	assert_almost_eq(buffer.sample_host_tick(9.0)[0].position, Vector3(3.0, 1.0, -2.0), Vector3.ONE * 0.001)


func test_yaw_uses_the_short_arc_across_zero() -> void:
	var before: CrowdCodec.Entity = _entity(1, 0.0)
	var after: CrowdCodec.Entity = _entity(1, 0.0)
	before.yaw = TAU - 0.1
	after.yaw = 0.1
	_push(0, [before])
	_push(6, [after])
	assert_lt(absf(angle_difference(buffer.sample_host_tick(9.0)[0].yaw, 0.0)), 0.02)


func test_startup_and_starvation_hold_known_positions() -> void:
	_push(12, [_entity(1, 5.0)])
	assert_almost_eq(buffer.sample_host_tick(0.0)[0].position.x, 5.0, 0.001)
	assert_almost_eq(buffer.sample_host_tick(100.0)[0].position.x, 5.0, 0.001, "Do not invent movement beyond the latest host state")


func test_lost_snapshots_interpolate_between_available_frames() -> void:
	_push(0, [_entity(1, 0.0)])
	_push(12, [_entity(1, 12.0)])
	assert_almost_eq(buffer.sample_host_tick(12.0)[0].position.x, 6.0, 0.001)


func test_duplicate_and_out_of_order_packets_do_not_rewind_state() -> void:
	_push(12, [_entity(1, 5.0)])
	assert_false(buffer.push_packet(CrowdCodec.encode(12, [_entity(1, 20.0)])))
	assert_false(buffer.push_packet(CrowdCodec.encode(9, [_entity(1, 30.0)])))
	assert_eq(buffer.depth(), 1)
	assert_eq(buffer.latest_tick(), 12)
	assert_almost_eq(buffer.sample_host_tick(50.0)[0].position.x, 5.0, 0.001)


func test_malformed_packet_does_not_clear_valid_state() -> void:
	_push(12, [_entity(1, 5.0)])
	assert_false(buffer.push_packet(PackedByteArray([1, 2, 3])))
	assert_eq(buffer.depth(), 1)
	assert_eq(buffer.latest_tick(), 12)


func test_reused_id_snaps_at_new_generation_instead_of_crossing_the_arena() -> void:
	_push(0, [_entity(1, 0.0, 1)])
	_push(6, [_entity(1, 100.0, 2)])
	assert_eq(buffer.sample_host_tick(9.0)[0].generation, 1)
	assert_almost_eq(buffer.sample_host_tick(9.0)[0].position.x, 0.0, 0.001)
	assert_eq(buffer.sample_host_tick(12.0)[0].generation, 2)
	assert_almost_eq(buffer.sample_host_tick(12.0)[0].position.x, 100.0, 0.001)


func test_changed_entity_kind_is_not_blended() -> void:
	_push(0, [_entity(1, 0.0, 1, 0)])
	_push(6, [_entity(1, 50.0, 1, 1)])
	assert_almost_eq(buffer.sample_host_tick(9.0)[0].position.x, 0.0, 0.001)
	assert_eq(buffer.sample_host_tick(12.0)[0].kind, 1)


func test_spawn_and_despawn_follow_snapshot_boundaries() -> void:
	_push(0, [_entity(1, 0.0)])
	_push(6, [_entity(2, 6.0)])
	var between: Array[CrowdCodec.Entity] = buffer.sample_host_tick(9.0)
	assert_eq(between.size(), 1)
	assert_eq(between[0].id, 1)
	var at_boundary: Array[CrowdCodec.Entity] = buffer.sample_host_tick(12.0)
	assert_eq(at_boundary.size(), 1)
	assert_eq(at_boundary[0].id, 2)


func test_empty_full_snapshot_removes_every_entity() -> void:
	_push(0, [_entity(1, 0.0), _entity(2, 2.0)])
	_push(6, [])
	assert_eq(buffer.sample_host_tick(9.0).size(), 2)
	assert_eq(buffer.sample_host_tick(12.0).size(), 0)
	assert_eq(buffer.sample_host_tick(100.0).size(), 0)


func test_discrete_combat_state_does_not_arrive_before_its_tick() -> void:
	var before: CrowdCodec.Entity = _entity(1, 0.0)
	before.health = 0.8
	before.anim = 1
	var after: CrowdCodec.Entity = _entity(1, 6.0)
	after.health = 0.2
	after.anim = 2
	after.primer0 = 3
	after.flags = GameTypes.FLAG_FROZEN
	_push(0, [before])
	_push(6, [after])
	var result: CrowdCodec.Entity = buffer.sample_host_tick(9.0)[0]
	assert_almost_eq(result.health, 0.8, 0.001)
	assert_eq(result.anim, 1)
	assert_eq(result.primer0, 0)
	assert_eq(result.flags, 0)
	assert_almost_eq(buffer.sample_host_tick(12.0)[0].health, 0.2, 0.001)
	assert_eq(buffer.sample_host_tick(12.0)[0].flags, GameTypes.FLAG_FROZEN)


func test_rendered_state_cannot_mutate_buffer_history() -> void:
	_push(0, [_entity(1, 0.0)])
	_push(6, [_entity(1, 6.0)])
	var result: Array[CrowdCodec.Entity] = buffer.sample_host_tick(9.0)
	result[0].position.x = 100.0
	result[0].health = 0.0
	result.clear()
	assert_almost_eq(buffer.sample_host_tick(9.0)[0].position.x, 3.0, 0.001)
	assert_eq(buffer.sample_host_tick(9.0)[0].health, 1.0)


func test_entities_are_returned_in_stable_id_order() -> void:
	_push(0, [_entity(3, 3.0), _entity(1, 1.0), _entity(2, 2.0)])
	var result: Array[CrowdCodec.Entity] = buffer.sample_host_tick(0.0)
	assert_eq(result[0].id, 1)
	assert_eq(result[1].id, 2)
	assert_eq(result[2].id, 3)


func test_retained_history_is_bounded_and_reports_actual_span() -> void:
	for tick: int in range(0, 31, 3):
		_push(tick, [_entity(1, float(tick))])
	assert_eq(buffer.depth(), 4)
	assert_almost_eq(buffer.span_ms(), 150.0, 0.001)
	assert_almost_eq(buffer.sample_host_tick(30.0)[0].position.x, 24.0, 0.001)


func test_tick_wrap_preserves_order_and_interpolation() -> void:
	assert_true(buffer.configure(60.0, 0.0, 20.0))
	_push(0xFFFFFFFE, [_entity(1, 0.0)])
	_push(1, [_entity(1, 3.0)])
	assert_eq(buffer.latest_tick(), 0x100000001)
	assert_almost_eq(buffer.sample_host_tick(0.0)[0].position.x, 2.0, 0.001)
	assert_false(buffer.push_packet(CrowdCodec.encode(0xFFFFFFFF, [_entity(1, 99.0)])))
	assert_almost_eq(buffer.sample_host_tick(1.0)[0].position.x, 3.0, 0.001)


func test_clear_allows_a_new_session_with_an_earlier_tick() -> void:
	_push(100, [_entity(1, 5.0)])
	buffer.clear()
	assert_eq(buffer.depth(), 0)
	assert_eq(buffer.span_ms(), 0.0)
	_push(0, [_entity(2, 2.0)])
	assert_eq(buffer.sample_host_tick(0.0)[0].id, 2)


func test_invalid_configuration_and_sample_times_are_rejected() -> void:
	_push(12, [_entity(1, 5.0)])
	assert_false(buffer.configure(0.0, 0.1, 20.0))
	assert_false(buffer.configure(60.0, -1.0, 20.0))
	assert_false(buffer.configure(60.0, 0.1, INF))
	assert_eq(buffer.depth(), 1, "Invalid configuration leaves the existing buffer intact")
	assert_eq(buffer.sample_host_tick(NAN).size(), 0)
	assert_eq(buffer.sample_host_tick(INF).size(), 0)
	assert_eq(buffer.sample_host_tick(-1.0).size(), 0)


func test_arena_interface_applies_arrival_offset_and_delay_once() -> void:
	assert_true(buffer.push(0, [_entity(1, 0.0)], 30.0))
	assert_true(buffer.push(6, [_entity(1, 6.0)], 36.0))
	var display_tick: float = buffer.render_tick(39.0)
	assert_almost_eq(buffer.arrival_offset, 30.0, 0.001)
	assert_almost_eq(display_tick, 3.0, 0.001)
	assert_almost_eq(buffer.sample(display_tick)[0].position.x, 3.0, 0.001)
	assert_eq(buffer.depth(display_tick), 1, "Only future snapshots count toward the display buffer")
	assert_eq(buffer.depth(), 2, "Retained history is available independently")


func test_stale_packets_do_not_change_arrival_clock() -> void:
	assert_true(buffer.push(6, [_entity(1, 6.0)], 36.0))
	assert_false(buffer.push(6, [_entity(1, 99.0)], 100.0))
	assert_false(buffer.push(3, [_entity(1, 99.0)], 100.0))
	assert_false(buffer.push(9, [_entity(1, 99.0)], NAN))
	assert_almost_eq(buffer.arrival_offset, 30.0, 0.001)
	assert_eq(buffer.latest_tick(), 6)


func test_decoded_input_objects_are_copied_on_arrival() -> void:
	var source: CrowdCodec.Entity = _entity(1, 5.0)
	assert_true(buffer.push(0, [source], 0.0))
	source.position.x = 99.0
	source.flags = GameTypes.FLAG_FROZEN
	assert_almost_eq(buffer.sample(0.0)[0].position.x, 5.0, 0.001)
	assert_eq(buffer.sample(0.0)[0].flags, 0)


func test_arrival_clock_wrap_is_handled_on_both_timelines() -> void:
	assert_true(buffer.push(0xFFFFFFFE, [_entity(1, 0.0)], 3.0))
	assert_true(buffer.push(1, [_entity(1, 3.0)], 6.0))
	assert_almost_eq(buffer.arrival_offset, 5.0, 0.001)
	assert_almost_eq(buffer.sample(buffer.render_tick(10.5))[0].position.x, 1.5, 0.001)


func test_clear_resets_clock_and_existing_interp_property_is_supported() -> void:
	assert_true(buffer.push(6, [_entity(1, 6.0)], 36.0))
	buffer.clear()
	assert_eq(buffer.arrival_offset, -1.0)
	buffer.interp_ticks = GameData.rule(&"interpolation_buffer_s") * GameData.rule(&"sim_tickrate")
	assert_almost_eq(buffer.interp_ticks, 6.0, 0.001)
	assert_true(buffer.push(0, [_entity(2, 2.0)], 0.0))
	assert_eq(buffer.sample(buffer.render_tick(0.0))[0].id, 2)


func test_arrival_smoothing_discards_old_latency_samples() -> void:
	for tick: int in range(0, 31, 3):
		assert_true(buffer.push(tick, [_entity(1, float(tick))], float(tick + (12 if tick < 12 else 3))))
	assert_almost_eq(buffer.arrival_offset, 3.0, 0.001, "A past latency spike cannot bias the buffer forever")
