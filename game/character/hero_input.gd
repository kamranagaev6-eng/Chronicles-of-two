class_name HeroInput
extends Node
## netfox input node. The owning player's PC fills these properties every network tick (devices or
## the scripted bot); netfox sends them to the host with redundancy. Action presses are sticky
## sequence numbers, so a lost packet can never lose a press, and the motor's 150 ms buffer
## decides when it actually starts.

const INPUT_PROPERTIES: Array[String] = ["move", "aim", "held", "req_seq", "req_slot", "dodge_seq", "view_tick"]
const ABILITY_ACTIONS: Array[StringName] = [&"ability_1", &"ability_2", &"ability_3", &"ability_4"]

var move: Vector2 = Vector2.ZERO
var aim: Vector3 = Vector3(0, 0, 4)
var held: int = 0
var req_seq: int = 0
var req_slot: int = -1
var dodge_seq: int = 0
var view_tick: int = 0

var hero: Node3D
var arena: Node
var camera: Camera3D
var bot: RefCounted = null
var input_enabled: bool = true
var _aim_dir: Vector3 = Vector3(0, 0, 1)
var _frame := HeroMotor.InputFrame.new()


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)


func _exit_tree() -> void:
	if NetworkTime.before_tick_loop.is_connected(_gather):
		NetworkTime.before_tick_loop.disconnect(_gather)


func is_local() -> bool:
	return is_multiplayer_authority() and multiplayer.has_multiplayer_peer()


## Snapshot of the current properties for the motor (netfox has already applied this tick's input).
func frame() -> HeroMotor.InputFrame:
	_frame.move = move
	_frame.aim = aim
	_frame.held = held
	_frame.req_seq = req_seq
	_frame.req_slot = req_slot
	_frame.dodge_seq = dodge_seq
	_frame.view_tick = view_tick
	return _frame


func request_action(slot: int) -> void:
	req_seq += 1
	req_slot = slot


func request_dodge() -> void:
	dodge_seq += 1


## Presses are latched every frame so none are missed between network ticks.
func _process(_delta: float) -> void:
	if not is_local() or bot != null or not input_enabled:
		return
	for i in ABILITY_ACTIONS.size():
		if Input.is_action_just_pressed(ABILITY_ACTIONS[i]):
			request_action(GameTypes.ACT_1 + i)
	if Input.is_action_just_pressed(&"shove"):
		request_action(GameTypes.ACT_SHOVE)
	if Input.is_action_just_pressed(&"flask"):
		request_action(GameTypes.ACT_FLASK)
	if Input.is_action_just_pressed(&"dodge"):
		request_dodge()


func _gather() -> void:
	if not is_local():
		return
	if arena != null and arena.has_method("view_tick"):
		view_tick = int(arena.call("view_tick"))
	if bot != null:
		bot.call("drive", self)
		return
	if not input_enabled:
		move = Vector2.ZERO
		held = 0
		return
	move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	held = 0
	if Input.is_action_pressed(&"attack"):
		held |= GameTypes.BTN_ATTACK
	if Input.is_action_pressed(&"interact"):
		held |= GameTypes.BTN_INTERACT
	if Input.is_action_pressed(&"bond"):
		held |= GameTypes.BTN_BOND
	aim = _compute_aim()


func _compute_aim() -> Vector3:
	var origin := hero.global_position if hero != null else Vector3.ZERO
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick.length() > 0.25:
		_aim_dir = Vector3(stick.x, 0.0, stick.y).normalized()
		return _assisted(origin, origin + _aim_dir * 8.0)
	if camera != null and DisplayServer.get_name() != "headless" and Input.get_connected_joypads().is_empty() or (camera != null and _mouse_recent()):
		var mouse := camera.get_viewport().get_mouse_position()
		var from := camera.project_ray_origin(mouse)
		var dir := camera.project_ray_normal(mouse)
		var plane := Plane(Vector3.UP, origin.y)
		var hit: Variant = plane.intersects_ray(from, dir)
		if hit != null:
			var p: Vector3 = hit
			var d := GameTypes.flat_dir(origin, p)
			if d != Vector3.ZERO:
				_aim_dir = d
			return p
	if move.length() > 0.2:
		_aim_dir = Vector3(move.x, 0.0, move.y).normalized()
	return _assisted(origin, origin + _aim_dir * 8.0)


var _last_mouse_move_msec: int = 0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_last_mouse_move_msec = Time.get_ticks_msec()


func _mouse_recent() -> bool:
	return Time.get_ticks_msec() - _last_mouse_move_msec < 3000


## Controller soft lock-on: snap to the nearest enemy within 25 degrees and 14 m when aim assist is on.
func _assisted(origin: Vector3, point: Vector3) -> Vector3:
	if arena == null or not Settings.assist("aim") or not arena.has_method("enemy_positions"):
		return point
	var best := point
	var best_score := INF
	for p: Vector3 in arena.call("enemy_positions"):
		var d := GameTypes.flat(p - origin)
		var dist := d.length()
		if dist < 0.5 or dist > 14.0:
			continue
		var angle := absf(_aim_dir.signed_angle_to(d.normalized(), Vector3.UP))
		if angle < deg_to_rad(25.0) and angle * 10.0 + dist < best_score:
			best_score = angle * 10.0 + dist
			best = p
	return best
