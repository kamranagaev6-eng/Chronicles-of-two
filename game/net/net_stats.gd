class_name NetStats
extends RefCounted
## Numbers for the F3 overlay and the soak report: round trip, jitter, loss, bandwidth (with ENet
## overhead), snapshot buffer depth and prediction corrections.

var rtt_ms: float = 0.0
var jitter_ms: float = 0.0
var loss_percent: float = 0.0
var sent_kbps: float = 0.0
var recv_kbps: float = 0.0
var buffer_depth: int = 0
var buffer_ms: float = 0.0
var reconciliations: int = 0
var corrections: PackedFloat32Array = PackedFloat32Array()
var last_correction: float = 0.0
var bytes_by_kind: Dictionary[String, int] = {}
var _window_sent: Dictionary[String, int] = {}
var _accum: float = 0.0
var _bytes_sent_window: int = 0
var _bytes_recv_window: int = 0


func reset() -> void:
	rtt_ms = 0.0
	jitter_ms = 0.0
	loss_percent = 0.0
	sent_kbps = 0.0
	recv_kbps = 0.0
	buffer_depth = 0
	buffer_ms = 0.0
	reconciliations = 0
	corrections = PackedFloat32Array()
	last_correction = 0.0
	bytes_by_kind = {}
	_window_sent = {}
	_accum = 0.0
	_bytes_sent_window = 0
	_bytes_recv_window = 0


func record_correction(meters: float) -> void:
	if not is_finite(meters) or meters < 0.0:
		return
	last_correction = meters
	if meters > 0.001:
		reconciliations += 1
		corrections.append(meters)
		if corrections.size() > 4096:
			corrections = corrections.slice(corrections.size() - 4096)


func correction_percentile(p: float) -> float:
	if corrections.is_empty() or not is_finite(p):
		return 0.0
	var sorted: PackedFloat32Array = corrections.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)]


func count_sent(kind: String, bytes: int) -> void:
	if bytes < 0:
		return
	bytes_by_kind[kind] = int(bytes_by_kind.get(kind, 0)) + bytes
	_window_sent[kind] = int(_window_sent.get(kind, 0)) + bytes


## Poll ENet once per frame; bandwidth is averaged over one-second windows.
func poll(mp: MultiplayerAPI, remote_peer: int, delta: float) -> void:
	var enet: ENetMultiplayerPeer = mp.multiplayer_peer as ENetMultiplayerPeer if mp != null else null
	if enet == null or remote_peer <= 0:
		return
	if enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or not mp.get_peers().has(remote_peer):
		return
	var p: ENetPacketPeer = enet.get_peer(remote_peer)
	if p == null:
		return
	rtt_ms = p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	jitter_ms = p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)
	loss_percent = p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) * 100.0
	var host: ENetConnection = enet.host
	if host != null:
		record_bandwidth(int(host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)),
			int(host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)), delta)


## Transport byte counts include ENet overhead. Rates retain the overlay's KiB/s convention.
## Accept zero elapsed time without dropping bytes already drained from ENet.
func record_bandwidth(sent_bytes: int, received_bytes: int, delta: float) -> void:
	if sent_bytes < 0 or received_bytes < 0 or not is_finite(delta) or delta < 0.0:
		return
	_bytes_sent_window += sent_bytes
	_bytes_recv_window += received_bytes
	_accum += delta
	if _accum >= 1.0:
		sent_kbps = _bytes_sent_window / 1024.0 / _accum
		recv_kbps = _bytes_recv_window / 1024.0 / _accum
		_bytes_sent_window = 0
		_bytes_recv_window = 0
		_window_sent = {}
		_accum = 0.0


func summary() -> String:
	return "rtt %.0f ms, jitter %.0f ms, loss %.1f%%, up %.1f KB/s, down %.1f KB/s, reconciliations %d, p95 correction %.3f m, max %.3f m" % [
		rtt_ms, jitter_ms, loss_percent, sent_kbps, recv_kbps, reconciliations,
		correction_percentile(0.95), correction_percentile(1.0)]
