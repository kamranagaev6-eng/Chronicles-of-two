class_name KnockbackRules
extends RefCounted
## Impacts as velocity changes: dv = J / m, capped per mass class. Wall slams above a threshold
## deal speed * mass * factor and apply Dazed. Pure functions; the host applies the results.


## Speed change from an impulse on a body of the given mass, capped.
static func delta_v(impulse: float, mass: float, cap: float) -> float:
	if mass <= 0.0 or impulse <= 0.0:
		return 0.0
	return minf(impulse / mass, cap)


## Impulse scaled by the source's STR modifier.
static func scaled_impulse(base_impulse: float, str_modifier: int, per_modifier: float) -> float:
	return maxf(0.0, base_impulse * (1.0 + float(str_modifier) * per_modifier))


## Speed into the wall along its normal (the normal points from the wall toward the body).
## Returns 0 below the threshold.
static func slam_speed(pre_impact_velocity: Vector3, wall_normal: Vector3, threshold: float) -> float:
	var n := Vector3(wall_normal.x, 0.0, wall_normal.z)
	if n.length_squared() < 0.0001:
		return 0.0
	n = n.normalized()
	var into := -pre_impact_velocity.dot(n)
	return into if into >= threshold else 0.0


static func slam_damage(speed: float, mass: float, factor: float) -> float:
	return speed * mass * factor


## Velocity change given to body 2 when body 1 (mass m1, velocity v1) hits it.
static func transfer(v1: Vector3, m1: float, m2: float, fraction: float) -> Vector3:
	if m2 <= 0.0:
		return Vector3.ZERO
	return v1 * (fraction * m1 / m2)


## Apply deceleration to a knockback velocity for one tick. Friction scales the deceleration (ice 0.1).
static func decay(v: Vector3, decel: float, friction: float, dt: float) -> Vector3:
	var speed := v.length()
	if speed <= 0.0001:
		return Vector3.ZERO
	var new_speed := maxf(0.0, speed - decel * friction * dt)
	return v * (new_speed / speed)
