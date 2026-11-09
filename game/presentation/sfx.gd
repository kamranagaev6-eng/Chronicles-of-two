class_name Sfx
extends Node3D
## Layered placeholder sound effects synthesised at startup (original work, nothing to license).
## Pooled positional players; presentation only.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next: int = 0
var _next_flat: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242
	for i in 20:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 60.0
		add_child(p)
		_players.append(p)
	for i in 6:
		var f := AudioStreamPlayer.new()
		add_child(f)
		_flat.append(f)
	_streams[&"hit_physical"] = _make(0.09, func(t: float, n: float) -> float: return (n * 0.7 + sin(TAU * 110.0 * t) * 0.8) * exp(-t * 40.0))
	_streams[&"hit_holy"] = _make(0.35, func(t: float, n: float) -> float: return (sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1320.0 * t) * 0.3 + n * 0.2 * exp(-t * 60.0)) * exp(-t * 9.0))
	_streams[&"hit_cold"] = _make(0.25, func(t: float, n: float) -> float: return (sin(TAU * (2400.0 + 600.0 * sin(t * 90.0)) * t) * 0.35 + n * 0.25) * exp(-t * 14.0))
	_streams[&"hit_lightning"] = _make(0.22, func(t: float, n: float) -> float: return (n if absf(n) > 0.6 else n * 0.15) * exp(-t * 10.0))
	_streams[&"hit_fire"] = _make(0.28, func(t: float, n: float) -> float: return n * 0.6 * sin(minf(1.0, t * 12.0) * PI * 0.5) * exp(-t * 7.0))
	_streams[&"hit_arcane"] = _make(0.18, func(t: float, n: float) -> float: return (sin(TAU * (520.0 - 900.0 * t) * t) * 0.6 + n * 0.15) * exp(-t * 14.0))
	_streams[&"slam"] = _make(0.35, func(t: float, n: float) -> float: return (sin(TAU * (75.0 - 30.0 * t) * t) * 1.0 + n * 0.5 * exp(-t * 30.0)) * exp(-t * 9.0))
	_streams[&"shatter"] = _make(0.5, func(t: float, n: float) -> float: return (sin(TAU * 3100.0 * t) * exp(-t * 18.0) + sin(TAU * 4700.0 * t) * exp(-t * 11.0) + n * 0.4 * exp(-t * 25.0)) * 0.6)
	_streams[&"explode"] = _make(0.8, func(t: float, n: float) -> float: return (n * 0.9 * exp(-t * 5.0) + sin(TAU * 48.0 * t) * 0.7 * exp(-t * 4.0)))
	_streams[&"whoosh"] = _make(0.2, func(t: float, n: float) -> float: return n * 0.35 * sin(t / 0.2 * PI))
	_streams[&"cast"] = _make(0.16, func(t: float, n: float) -> float: return sin(TAU * (300.0 + 1400.0 * t) * t) * 0.35 * sin(t / 0.16 * PI))
	_streams[&"ready"] = _make(0.3, func(t: float, n: float) -> float: return (sin(TAU * (660.0 if t < 0.12 else 990.0) * t) * 0.35) * exp(-fmod(t, 0.12) * 12.0))
	_streams[&"revive"] = _make(0.7, func(t: float, n: float) -> float: return sin(TAU * [523.0, 659.0, 784.0, 1046.0][mini(3, int(t / 0.17))] * t) * 0.35 * exp(-fmod(t, 0.17) * 6.0))
	_streams[&"hurt"] = _make(0.18, func(t: float, n: float) -> float: return (fposmod(t * (160.0 - 200.0 * t), 1.0) * 2.0 - 1.0) * 0.45 * exp(-t * 12.0) + n * 0.1)
	_streams[&"resonance"] = _make(0.6, func(t: float, n: float) -> float: return (sin(TAU * 440.0 * t) + sin(TAU * 554.4 * t) + sin(TAU * 659.3 * t)) * 0.22 * sin(minf(1.0, t * 8.0) * PI * 0.5) * exp(-t * 3.5))
	_streams[&"horn"] = _make(0.9, func(t: float, n: float) -> float: return (fposmod(t * (220.0 + 4.0 * sin(t * 30.0)), 1.0) * 2.0 - 1.0) * 0.28 * sin(minf(1.0, t * 5.0) * PI * 0.5) * exp(-t * 1.8))
	_streams[&"ui"] = _make(0.04, func(t: float, n: float) -> float: return sin(TAU * 1200.0 * t) * 0.3 * exp(-t * 90.0))
	_streams[&"warn"] = _make(0.12, func(t: float, n: float) -> float: return sin(TAU * 330.0 * t) * 0.18 * exp(-t * 18.0))
	_streams[&"splash"] = _make(0.4, func(t: float, n: float) -> float: return n * 0.5 * exp(-t * 9.0) * (0.6 + 0.4 * sin(TAU * 7.0 * t)))


func _make(seconds: float, wave: Callable) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var v: float = wave.call(t, _rng.randf_range(-1.0, 1.0))
		data.encode_s16(i * 2, clampi(int(v * 26000.0), -32767, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func play(sound: StringName, at: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	if at is Vector3:
		var p := _players[_next]
		_next = (_next + 1) % _players.size()
		p.stream = stream
		p.global_position = at
		p.volume_db = volume_db
		p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
		p.play()
	else:
		var f := _flat[_next_flat]
		_next_flat = (_next_flat + 1) % _flat.size()
		f.stream = stream
		f.volume_db = volume_db
		f.pitch_scale = pitch
		f.play()


func hit_sound(damage_type: StringName) -> StringName:
	match damage_type:
		&"holy":
			return &"hit_holy"
		&"cold":
			return &"hit_cold"
		&"lightning":
			return &"hit_lightning"
		&"fire":
			return &"hit_fire"
		&"arcane":
			return &"hit_arcane"
	return &"hit_physical"
