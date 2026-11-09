extends GutTest
## Hero motor: acceleration, dodge charges and invulnerability, the input buffer, cancel windows,
## cooldowns, Flux costs with Elemental Weave, charges, host commands and deterministic replay.

const DT := 1.0 / 60.0

var motor: HeroMotor
var frame: HeroMotor.InputFrame


static func make_motor(class_id: StringName) -> HeroMotor:
	var m := HeroMotor.new()
	m.configure_from_rules()
	var c := GameData.class_def(class_id)
	m.move_speed = c.move_speed
	m.resource_max = c.resource_max
	m.resource = c.resource_start
	m.uses_flux = c.resource_id == &"flux"
	m.resource_regen_per_tick = c.resource_regen_per_s / 60.0
	var defs: Array[AbilityDefinition] = []
	defs.resize(GameTypes.ACTION_COUNT)
	defs[GameTypes.ACT_BASIC] = GameData.ability(c.basic_attack)
	for i in c.abilities.size():
		defs[i + 1] = GameData.ability(c.abilities[i])
	defs[GameTypes.ACT_SHOVE] = GameData.ability(&"shove")
	defs[GameTypes.ACT_FLASK] = GameData.ability(&"flask")
	m.abilities = defs
	return m


func before_each() -> void:
	motor = make_motor(&"vanguard")
	frame = HeroMotor.InputFrame.new()
	frame.aim = Vector3(0, 0, 10)


func after_each() -> void:
	motor.free()


func _step(tick: int) -> HeroMotor.StepResult:
	return motor.step(frame, tick, Vector3.ZERO, DT, true)


func _request(slot: int) -> void:
	frame.req_seq += 1
	frame.req_slot = slot


func test_accelerates_to_move_speed() -> void:
	frame.move = Vector2(1, 0)
	var r: HeroMotor.StepResult
	for t in 60:
		r = _step(t)
	assert_almost_eq(r.velocity.x, motor.move_speed, 0.01)
	assert_almost_eq(motor.yaw, PI / 2.0, 0.001, "faces the movement direction")


func test_dodge_charges_and_recharge() -> void:
	frame.move = Vector2(0, 1)
	frame.dodge_seq = 1
	_step(0)
	assert_eq(motor.dodge_charges, 1)
	assert_true(motor.is_invulnerable(0))
	assert_true(motor.is_invulnerable(motor.iframe_ticks - 1))
	assert_false(motor.is_invulnerable(motor.iframe_ticks))
	for t in range(1, 20):
		_step(t)
	frame.dodge_seq = 2
	_step(20)
	assert_eq(motor.dodge_charges, 0)
	for t in range(21, 40):
		_step(t)
	frame.dodge_seq = 3
	_step(40)
	assert_eq(motor.dodge_ticks_left, 0, "no charges left")
	for t in range(41, motor.dodge_recharge_ticks + 2):
		_step(t)
	assert_eq(motor.dodge_charges, 1, "a charge returns after the recharge time")


func test_action_timeline_events() -> void:
	_request(GameTypes.ACT_1)
	var kinds: Array[StringName] = []
	var def := motor.ability_at(GameTypes.ACT_1)
	for t in def.total_ticks() + 2:
		for e: Dictionary in _step(t).events:
			kinds.append(e["type"])
	assert_eq(kinds[0], &"start")
	assert_eq(kinds.count(&"active"), def.active_ticks)
	assert_true(kinds.has(&"end"))
	assert_eq(motor.action_slot, -1)


func test_input_buffer_starts_queued_ability() -> void:
	_request(GameTypes.ACT_1)
	_step(0)
	var def := motor.ability_at(GameTypes.ACT_1)
	var t := 1
	while t < def.cancel_tick - 3:
		_step(t)
		t += 1
	_request(GameTypes.ACT_4)
	var started_at := -1
	for k in range(t, t + 10):
		for e: Dictionary in _step(k).events:
			if e["type"] == &"start" and int(e["slot"]) == GameTypes.ACT_4:
				started_at = k
	assert_eq(started_at, def.cancel_tick, "starts as soon as the cancel window opens")


func test_buffer_expires() -> void:
	_request(GameTypes.ACT_1)
	_step(0)
	_request(GameTypes.ACT_4)
	_step(1)
	var def := motor.ability_at(GameTypes.ACT_1)
	var started := false
	for k in range(2, def.cancel_tick + 2):
		for e: Dictionary in _step(k).events:
			started = started or (e["type"] == &"start" and int(e["slot"]) == GameTypes.ACT_4)
	assert_false(started, "a press older than 150 ms is dropped")


func test_cooldown_blocks_restart() -> void:
	_request(GameTypes.ACT_1)
	_step(0)
	var def := motor.ability_at(GameTypes.ACT_1)
	for t in range(1, def.total_ticks() + 1):
		_step(t)
	assert_false(motor.can_start(GameTypes.ACT_1, def.total_ticks() + 1))
	assert_true(motor.can_start(GameTypes.ACT_1, def.cooldown_ticks))


func test_dodge_cannot_cancel_active_frames() -> void:
	_request(GameTypes.ACT_2)  # Shield Rush: long active window
	_step(0)
	var def := motor.ability_at(GameTypes.ACT_2)
	for t in range(1, def.windup_ticks + 1):
		_step(t)
	assert_false(motor.can_dodge(def.windup_ticks + 1))
	assert_true(motor.can_dodge(def.windup_ticks + def.active_ticks))


func test_shield_rush_charges_along_the_aim() -> void:
	_request(GameTypes.ACT_2)
	var def := motor.ability_at(GameTypes.ACT_2)
	var charged := false
	for t in def.windup_ticks + 3:
		var r := _step(t)
		if t > def.windup_ticks:
			charged = charged or r.velocity.z > def.move_speed - 0.01
	assert_true(charged)


func test_flux_costs_and_elemental_weave() -> void:
	motor.free()
	motor = make_motor(&"riftweaver")
	motor.resource_regen_per_tick = 0.0
	var spire := GameData.ability(&"glacial_spire")
	var lance := GameData.ability(&"arc_lance")
	_request(GameTypes.ACT_1)
	_step(0)
	assert_almost_eq(motor.resource, 100.0 - spire.cost, 0.0001)
	for t in range(1, 40):
		_step(t)
	_request(GameTypes.ACT_2)
	_step(40)
	assert_almost_eq(motor.resource, 100.0 - spire.cost - lance.cost * 0.85, 0.0001, "a different element refunds 15%")
	motor.resource = 1.0
	assert_false(motor.can_start(GameTypes.ACT_1, 1000), "at zero Flux you simply can't cast")


func test_host_commands() -> void:
	motor.apply_command({"type": &"knockback", "velocity": Vector3(8, 0, 0)})
	var r := _step(0)
	assert_gt(r.velocity.x, 7.0)
	motor.apply_command({"type": &"downed", "value": true})
	_request(GameTypes.ACT_1)
	for e: Dictionary in _step(1).events:
		assert_ne(e["type"], &"start", "downed heroes can't act")
	motor.apply_command({"type": &"reset"})
	assert_false(motor.downed)
	assert_eq(motor.flask_charges, motor.flask_max)


func test_replay_is_deterministic() -> void:
	var run := func(m: HeroMotor) -> PackedStringArray:
		var f := HeroMotor.InputFrame.new()
		var lines := PackedStringArray()
		for t in 240:
			f.move = Vector2(sin(t * 0.1), cos(t * 0.07))
			f.aim = Vector3(cos(t * 0.05) * 8.0, 0, sin(t * 0.05) * 8.0)
			if t % 37 == 0:
				f.req_seq += 1
				f.req_slot = 1 + (t / 37) % 4
			if t % 53 == 0:
				f.dodge_seq += 1
			f.held = GameTypes.BTN_ATTACK if t % 90 < 30 else 0
			var r: HeroMotor.StepResult = m.step(f, t, Vector3.ZERO, DT, true)
			lines.append("%s|%s|%d|%d|%.5f" % [r.velocity, r.events.size(), m.action_slot, m.dodge_charges, m.resource])
		return lines
	var a := make_motor(&"vanguard")
	var b := make_motor(&"vanguard")
	assert_eq(run.call(a), run.call(b), "same inputs, same results")
	a.free()
	b.free()
