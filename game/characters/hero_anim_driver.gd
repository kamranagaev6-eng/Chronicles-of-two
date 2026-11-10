class_name HeroAnimDriver
extends RefCounted
## Reads the motor's existing state to choose a pose. Never mutates simulation or emits effects.

const TICKS_PER_SECOND: float = 60.0
const DODGE_RECOVERY_TICKS: int = 10


static func pose(motor: HeroMotor, life: int, tick: int, tick_factor: float,
		finisher_elapsed_s: float, clips: ClipSet) -> AnimPose:
	var result: AnimPose = AnimPose.new()
	var velocity: Vector3 = motor.move_velocity
	result.speed_mps = Vector2(velocity.x, velocity.z).length()
	if result.speed_mps > 0.0001:
		result.move_angle = wrapf(atan2(velocity.x, velocity.z) - motor.yaw, -PI, PI)

	if life == NetProtocol.LIFE_FALLEN:
		var dead: ClipSet.ClipRow = clips.base_row(&"dead")
		result.locomotion = false
		result.base_clip = dead.clip
		result.base_time_s = dead.end_s
		return result

	if motor.downed or life == NetProtocol.LIFE_DOWNED:
		result.locomotion = false
		result.base_clip = clips.base_row(&"downed_crawl" if result.speed_mps > 0.2 else &"downed_idle").clip
		return result

	if finisher_elapsed_s >= 0.0:
		var impact_s: float = GameData.rule(&"finisher_impact_ticks") / TICKS_PER_SECOND
		var lock_s: float = GameData.rule(&"finisher_lock_ticks") / TICKS_PER_SECOND
		_set_action(result, clips.base_row(&"finisher"), impact_s, maxf(0.0, lock_s - impact_s),
			finisher_elapsed_s, true)
		return result

	if motor.dodge_ticks_left > 0 or tick - motor.dodge_start_tick < motor.dodge_ticks + DODGE_RECOVERY_TICKS:
		_set_action(result, clips.base_row(&"dodge"), motor.dodge_ticks / TICKS_PER_SECOND,
			DODGE_RECOVERY_TICKS / TICKS_PER_SECOND, _elapsed(tick, motor.dodge_start_tick, tick_factor), true)
		return result

	if motor.action_slot >= 0:
		var definition: AbilityDefinition = motor.current_action_def()
		if definition != null:
			_set_action(result, clips.ability_row(definition), definition.windup_ticks / TICKS_PER_SECOND,
				(definition.active_ticks + definition.recovery_ticks) / TICKS_PER_SECOND,
				_elapsed(tick, motor.action_tick, tick_factor))
			return result

	if motor.blocking:
		var block: ClipSet.ClipRow = clips.base_row(&"block")
		result.action_clip = block.clip
		var duration: float = block.end_s - block.start_s
		result.action_time_s = block.start_s
		if duration > 0.0:
			result.action_time_s += fposmod(_elapsed(tick, motor.block_start_tick, tick_factor), duration)
		result.action_upper = _upper_layer(block, result.speed_mps)
	return result


static func _elapsed(tick: int, start_tick: int, tick_factor: float) -> float:
	return maxf(0.0, (tick - start_tick + clampf(tick_factor, 0.0, 1.0)) / TICKS_PER_SECOND)


static func _set_action(result: AnimPose, row: ClipSet.ClipRow, windup_s: float,
		rest_s: float, elapsed_s: float, full_body: bool = false) -> void:
	result.action_clip = row.clip
	result.action_time_s = ClipSet.clip_time(row, windup_s, rest_s, elapsed_s)
	result.action_upper = not full_body and _upper_layer(row, result.speed_mps)


static func _upper_layer(row: ClipSet.ClipRow, speed_mps: float) -> bool:
	return row.layer == &"upper" or (row.layer == &"upper_when_moving" and speed_mps > 0.5)
