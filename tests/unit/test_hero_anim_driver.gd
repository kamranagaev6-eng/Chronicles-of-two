extends GutTest

const MotorKit := preload("res://tests/unit/test_hero_motor.gd")

var motor: HeroMotor
var clips: ClipSet


func before_each() -> void:
	motor = MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	clips = ClipSet.for_set(&"vanguard")


func _act(ability_id: StringName, slot: int, started: int) -> void:
	motor.action_slot = slot
	motor.action_ability = GameData.ability_index(ability_id)
	motor.action_tick = started


func _pose(tick: int, factor: float = 0.0, life: int = NetProtocol.LIFE_ALIVE, finisher_s: float = -1.0) -> AnimPose:
	return HeroAnimDriver.pose(motor, life, tick, factor, finisher_s, clips)


func test_contact_frame_lands_on_the_active_tick() -> void:
	for case: Array in [[&"vanguard_sword_strike", GameTypes.ACT_BASIC, 6, &"ual2/Sword_Regular_A", 0.25],
			[&"vanguard_shield_smash", GameTypes.ACT_HEAVY, 14, &"ual2/Shield_OneShot", 0.1],
			[&"judgment_cleave", GameTypes.ACT_1, 10, &"ual1/Sword_Attack", 0.4],
			[&"oathshield_recall", GameTypes.ACT_THROW, 0, &"extra/Catch", 0.0]]:
		_act(case[0], case[1], 100)
		var p: AnimPose = _pose(100 + int(case[2]))
		assert_eq(p.action_clip, case[3])
		assert_almost_eq(p.action_time_s, float(case[4]), 0.0001, str(case[0]))


func test_time_between_ticks_uses_the_tick_factor() -> void:
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_almost_eq(_pose(103, 0.0).action_time_s, 0.125, 0.0001)
	assert_almost_eq(_pose(102, 0.5).action_time_s, 0.25 * 2.5 / 6.0, 0.0001)


func test_rollback_times_are_clamped() -> void:
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_almost_eq(_pose(90).action_time_s, 0.0, 0.0001, "an action that starts in the future shows its first frame")
	assert_almost_eq(_pose(103, 7.0).action_time_s, _pose(103, 1.0).action_time_s, 0.0001, "tick_factor is clamped to 1")


func test_a_throws_recovery_still_shows_the_throw() -> void:
	_act(&"oathshield_throw", GameTypes.ACT_THROW, 100)
	motor.weapon_out = true
	assert_eq(_pose(115).action_clip, &"ual2/OverhandThrow")


func test_rule_order() -> void:
	motor.blocking = true
	motor.block_start_tick = 100
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_eq(_pose(103).action_clip, &"ual2/Sword_Regular_A", "an action beats the block")
	motor.dodge_start_tick = 100
	motor.dodge_ticks_left = 9
	assert_eq(_pose(103).action_clip, &"ual1/Roll", "a dodge beats an action")
	assert_eq(_pose(103, 0.0, NetProtocol.LIFE_ALIVE, 0.2).action_clip, &"extra/Finisher_Blow", "a finisher beats a dodge")
	motor.downed = true
	var down: AnimPose = _pose(103, 0.0, NetProtocol.LIFE_DOWNED)
	assert_false(down.locomotion)
	assert_eq(down.base_clip, &"extra/Prone_Hold")
	assert_eq(down.action_clip, &"")
	var dead: AnimPose = _pose(103, 0.0, NetProtocol.LIFE_FALLEN)
	assert_eq(dead.base_clip, &"ual1/Death01")
	assert_almost_eq(dead.base_time_s, 2.4, 0.0001, "held on its last frame")


func test_dodge_and_finisher_timing() -> void:
	motor.dodge_start_tick = 100
	motor.dodge_ticks_left = 0
	assert_almost_eq(_pose(100 + motor.dodge_ticks).action_time_s, 1.0, 0.0001, "the tumble ends as the dodge does")
	assert_eq(_pose(100 + motor.dodge_ticks + 9).action_clip, &"ual1/Roll", "ten more ticks to stand up")
	assert_eq(_pose(100 + motor.dodge_ticks + 10).action_clip, &"")
	var impact_s: float = GameData.rule(&"finisher_impact_ticks") / 60.0
	assert_almost_eq(_pose(200, 0.0, NetProtocol.LIFE_ALIVE, impact_s).action_time_s, 0.38, 0.0001)


func test_block_and_layers() -> void:
	motor.blocking = true
	motor.block_start_tick = 100
	var still: AnimPose = _pose(130)
	assert_eq(still.action_clip, &"ual2/Idle_Shield")
	assert_false(still.action_upper)
	motor.move_velocity = Vector3(0, 0, 4.0)
	assert_true(_pose(130).action_upper, "upper body only while moving")
	motor.blocking = false
	_act(&"vanguard_overhead", GameTypes.ACT_BASIC, 100)
	assert_false(_pose(104).action_upper, "a full-body row stays full body while moving")
	_act(&"vanguard_sword_strike", GameTypes.ACT_BASIC, 100)
	assert_true(_pose(104).action_upper)


func test_locomotion_reads_speed_and_direction() -> void:
	motor.yaw = 0.0
	motor.move_velocity = Vector3(0, 0, 6.2)
	var forward: AnimPose = _pose(10)
	assert_true(forward.locomotion)
	assert_almost_eq(forward.speed_mps, 6.2, 0.0001)
	assert_almost_eq(forward.move_angle, 0.0, 0.0001)
	motor.move_velocity = Vector3(6.2, 0, 0)
	assert_almost_eq(_pose(10).move_angle, PI / 2.0, 0.0001)
	motor.move_velocity = Vector3(0, 3.0, -6.2)
	assert_almost_eq(absf(_pose(10).move_angle), PI, 0.0001)
	assert_almost_eq(_pose(10).speed_mps, 6.2, 0.0001, "vertical speed does not count")


func test_stationary_hero_has_no_directional_twist() -> void:
	motor.yaw = PI / 2.0
	motor.move_velocity = Vector3.ZERO
	var still: AnimPose = _pose(10)
	assert_almost_eq(still.speed_mps, 0.0, 0.0001)
	assert_almost_eq(still.move_angle, 0.0, 0.0001, "idle facing must not twist the hips")
