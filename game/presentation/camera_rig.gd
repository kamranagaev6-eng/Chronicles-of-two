class_name CameraRig
extends Node3D
## One camera per PC at about 50 degrees of pitch, leading toward the cursor.
## Trauma-based screen shake with a per-player strength slider (presentation only).

var camera: Camera3D
var target: Node3D
var aim_source: Callable
var trauma: float = 0.0
var _focus := Vector3.ZERO
var _noise_t: float = 0.0
var _pitch: float = 50.0
var _distance: float = 17.0
var _lead: float = 0.22


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_pitch = GameData.rule(&"camera_pitch_deg")
	_distance = GameData.rule(&"camera_distance_m")
	_lead = GameData.rule(&"camera_cursor_offset")


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount * float(Settings.option("camera_shake", 1.0)), 0.0, 1.0)


func snap_to(pos: Vector3) -> void:
	_focus = pos


func _process(delta: float) -> void:
	var goal := _focus
	if target != null and is_instance_valid(target):
		goal = target.global_position
		if aim_source.is_valid():
			var aim: Vector3 = aim_source.call()
			var lead := GameTypes.flat(aim - goal)
			goal += lead.limit_length(9.0) * _lead
	_focus = _focus.lerp(goal, minf(1.0, delta * 7.0))
	var pitch := deg_to_rad(_pitch)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * _distance
	_noise_t += delta * 30.0
	var shake := trauma * trauma
	var jitter := Vector3(sin(_noise_t * 1.3) + sin(_noise_t * 2.9) * 0.5, sin(_noise_t * 1.7 + 1.0), 0.0) * shake * 0.35
	camera.global_position = _focus + offset + jitter
	camera.look_at(_focus + Vector3(0, 0.6, 0) + jitter * 0.5, Vector3.UP)
	camera.rotation.z += sin(_noise_t * 2.1) * shake * 0.03
	trauma = maxf(0.0, trauma - delta * 1.6)
