extends GutTest

var stats: NetStats


func before_each() -> void:
	stats = NetStats.new()


func test_reset_clears_every_displayed_measurement() -> void:
	stats.rtt_ms = 80.0
	stats.jitter_ms = 20.0
	stats.loss_percent = 2.0
	stats.buffer_depth = 3
	stats.buffer_ms = 100.0
	stats.record_correction(0.5)
	stats.count_sent("snapshot", 1024)
	stats.record_bandwidth(2048, 4096, 1.0)
	stats.reset()
	assert_eq(stats.rtt_ms, 0.0)
	assert_eq(stats.jitter_ms, 0.0)
	assert_eq(stats.loss_percent, 0.0)
	assert_eq(stats.buffer_depth, 0)
	assert_eq(stats.buffer_ms, 0.0)
	assert_eq(stats.sent_kbps, 0.0)
	assert_eq(stats.recv_kbps, 0.0)
	assert_eq(stats.last_correction, 0.0)
	assert_eq(stats.reconciliations, 0)
	assert_true(stats.corrections.is_empty())
	assert_true(stats.bytes_by_kind.is_empty())


func test_new_session_does_not_inherit_partial_bandwidth_window() -> void:
	stats.record_bandwidth(8192, 8192, 0.5)
	stats.reset()
	stats.record_bandwidth(512, 0, 0.5)
	assert_eq(stats.sent_kbps, 0.0, "New session has not completed its first measurement window")
	stats.record_bandwidth(512, 1024, 0.5)
	assert_almost_eq(stats.sent_kbps, 1.0, 0.0001)
	assert_almost_eq(stats.recv_kbps, 1.0, 0.0001)


func test_bandwidth_uses_actual_elapsed_time() -> void:
	stats.record_bandwidth(1024, 2048, 0.25)
	assert_eq(stats.sent_kbps, 0.0)
	stats.record_bandwidth(2048, 1024, 1.25)
	assert_almost_eq(stats.sent_kbps, 2.0, 0.0001)
	assert_almost_eq(stats.recv_kbps, 2.0, 0.0001)
	stats.record_bandwidth(0, 0, 1.0)
	assert_eq(stats.sent_kbps, 0.0)
	assert_eq(stats.recv_kbps, 0.0)


func test_zero_duration_keeps_bytes_until_the_clock_advances() -> void:
	stats.record_bandwidth(1024, 2048, 0.0)
	assert_eq(stats.sent_kbps, 0.0)
	stats.record_bandwidth(0, 0, 1.0)
	assert_almost_eq(stats.sent_kbps, 1.0, 0.0001)
	assert_almost_eq(stats.recv_kbps, 2.0, 0.0001)


func test_invalid_samples_cannot_poison_bandwidth_or_corrections() -> void:
	stats.record_bandwidth(-1, 1024, 1.0)
	stats.record_bandwidth(1024, 1024, NAN)
	stats.record_bandwidth(1024, 1024, -1.0)
	stats.record_bandwidth(0, 0, 1.0)
	assert_eq(stats.sent_kbps, 0.0)
	assert_eq(stats.recv_kbps, 0.0)
	stats.record_correction(0.25)
	stats.record_correction(-1.0)
	stats.record_correction(NAN)
	stats.record_correction(INF)
	assert_eq(stats.last_correction, 0.25)
	assert_eq(stats.reconciliations, 1)
	assert_eq(stats.correction_percentile(NAN), 0.0)


func test_correction_percentiles_preserve_the_observation_order() -> void:
	for distance: float in [0.25, 0.5, 1.0, 0.125, 0.375]:
		stats.record_correction(distance)
	var recorded: PackedFloat32Array = stats.corrections.duplicate()
	assert_eq(stats.correction_percentile(0.8), 0.5)
	assert_eq(stats.correction_percentile(0.0), 0.125)
	assert_eq(stats.correction_percentile(1.0), 1.0)
	assert_eq(stats.correction_percentile(2.0), 1.0)
	assert_eq(stats.corrections, recorded)


func test_correction_history_is_bounded_but_total_count_is_preserved() -> void:
	for distance: int in range(1, 4098):
		stats.record_correction(float(distance))
	assert_eq(stats.corrections.size(), 4096)
	assert_eq(stats.reconciliations, 4097)
	assert_eq(stats.correction_percentile(0.0), 2.0)
	assert_eq(stats.correction_percentile(1.0), 4097.0)


func test_submillimeter_updates_do_not_count_as_reconciliations() -> void:
	stats.record_correction(0.0)
	stats.record_correction(0.0005)
	assert_eq(stats.reconciliations, 0)
	assert_almost_eq(stats.last_correction, 0.0005, 0.00001)
	assert_true(stats.corrections.is_empty())


func test_payload_accounting_does_not_accept_negative_bytes() -> void:
	stats.count_sent("snapshot", 100)
	stats.count_sent("snapshot", 50)
	stats.count_sent("snapshot", -100)
	stats.count_sent("events", 25)
	assert_eq(stats.bytes_by_kind["snapshot"], 150)
	assert_eq(stats.bytes_by_kind["events"], 25)


func test_polling_without_an_online_peer_is_safe() -> void:
	stats.poll(null, 1, 0.1)
	var offline: MultiplayerAPI = MultiplayerAPI.create_default_interface()
	offline.multiplayer_peer = OfflineMultiplayerPeer.new()
	stats.poll(offline, 1, 0.1)
	stats.poll(offline, 0, 0.1)
	assert_eq(stats.rtt_ms, 0.0)
	assert_eq(stats.sent_kbps, 0.0)
