extends GutTest
## Stagger meters, control diminishing returns and impact physics rules.



func test_ordinary_enemy_is_stunned() -> void:
	var s := StaggerState.new(40.0, &"normal")
	assert_eq(s.add(20.0, false, 0), StaggerState.Event.NONE)
	assert_eq(s.add(20.0, false, 1), StaggerState.Event.STUN)
	assert_true(s.is_stunned(2))
	assert_false(s.is_stunned(1 + s.stun_ticks))


func test_primed_enemies_take_stagger_twice_as_fast() -> void:
	var s := StaggerState.new(40.0, &"normal")
	assert_eq(s.add(20.0, true, 0), StaggerState.Event.STUN)


func test_elite_stagger_window_and_recovery() -> void:
	var s := StaggerState.new(100.0, &"elite")
	assert_eq(s.add(100.0, false, 0), StaggerState.Event.STAGGER)
	assert_true(s.is_staggered(10))
	assert_eq(s.add(500.0, false, 10), StaggerState.Event.NONE, "no meter gain while Staggered")
	assert_eq(s.add(500.0, false, s.staggered_ticks + 5), StaggerState.Event.NONE, "recovery prevents an immediate repeat")
	assert_eq(s.add(100.0, false, s.staggered_ticks + s.recovery_ticks + 1), StaggerState.Event.STAGGER)


func test_elite_control_diminishes() -> void:
	var s := StaggerState.new(100.0, &"elite")
	assert_eq(s.control_duration(96, 0), 48)
	assert_eq(s.control_duration(96, 10), 24)
	assert_eq(s.control_duration(96, 20), 12)
	assert_eq(s.control_duration(96, 30), 0, "immune after three")
	assert_eq(s.control_duration(96, 30 + s.dr_window_ticks + 1), 48, "window resets")


func test_boss_and_normal_control() -> void:
	assert_eq(StaggerState.new(100.0, &"boss").control_duration(96, 0), 0)
	assert_eq(StaggerState.new(100.0, &"normal").control_duration(96, 0), 96)


func test_delta_v_and_caps() -> void:
	assert_almost_eq(KnockbackRules.delta_v(24.0, 3.0, 12.0), 8.0, 0.0001)
	assert_almost_eq(KnockbackRules.delta_v(24.0, 1.0, 16.0), 16.0, 0.0001)
	assert_almost_eq(KnockbackRules.delta_v(24.0, 8.0, 5.0), 3.0, 0.0001, "heavy enemies barely move")


func test_str_scales_impulse() -> void:
	assert_almost_eq(KnockbackRules.scaled_impulse(24.0, 2, 0.06), 26.88, 0.0001)
	assert_almost_eq(KnockbackRules.scaled_impulse(24.0, -1, 0.06), 22.56, 0.0001)


func test_wall_slam_threshold_uses_pre_impact_velocity() -> void:
	assert_almost_eq(KnockbackRules.slam_speed(Vector3(-8, 0, 0), Vector3(1, 0, 0), 6.0), 8.0, 0.0001)
	assert_eq(KnockbackRules.slam_speed(Vector3(-5, 0, 0), Vector3(1, 0, 0), 6.0), 0.0)
	assert_almost_eq(KnockbackRules.slam_speed(Vector3(-8, 0, 8), Vector3(1, 0, 0), 6.0), 8.0, 0.0001, "approach angle counts")
	assert_eq(KnockbackRules.slam_speed(Vector3(8, 0, 0), Vector3(1, 0, 0), 6.0), 0.0, "moving away is no slam")


func test_slam_damage_and_momentum_transfer() -> void:
	assert_almost_eq(KnockbackRules.slam_damage(8.0, 3.0, 4.0), 96.0, 0.0001)
	assert_eq(KnockbackRules.transfer(Vector3(10, 0, 0), 3.0, 1.0, 0.6), Vector3(18, 0, 0))


func test_knockback_decay_respects_friction() -> void:
	assert_almost_eq(KnockbackRules.decay(Vector3(10, 0, 0), 18.0, 1.0, 0.5).x, 1.0, 0.0001)
	assert_almost_eq(KnockbackRules.decay(Vector3(10, 0, 0), 18.0, 0.1, 0.5).x, 9.1, 0.0001, "ice keeps bodies sliding")
	assert_eq(KnockbackRules.decay(Vector3(1, 0, 0), 18.0, 1.0, 0.5), Vector3.ZERO)
