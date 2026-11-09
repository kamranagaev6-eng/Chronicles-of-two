class_name Enemy
extends CharacterBody3D
## Host-only simulation body for an enemy or an important prop. Data-driven state machine:
## chase an engagement slot, claim an attack token, telegraph, attack, recover, release.
## Control effects (freeze, stun, stagger, prone, knockback, launch) interrupt it and release tokens.
## Presentation never reads this node directly on the guest; it receives packed snapshots instead.

const A := GameTypes.Anim
const HISTORY := 32

var id: int = 0
var generation: int = 0
var kind: int = 0
var def: EnemyDefinition
var is_prop: bool = false
var manager: Node = null

var health: float = 100.0
var stagger: StaggerState
var mass: float = 3.0
var velocity_cap: float = 12.0
var statuses: Dictionary = {}     # name -> [until_tick, magnitude, owner_slot]
var anim: int = A.SPAWNING
var state_until: int = 0
var yaw: float = 0.0
var target_slot: int = -1
var dead: bool = false
var death_tick: int = -1
var spawn_tick: int = 0

var knock_velocity := Vector3.ZERO
var knock_owner: int = -1
var knock_action: int = -1
var _slammed: Dictionary = {}        # action uid -> true
var _transferred: Dictionary = {}    # "uid|other" -> true
var air_until: int = -1
var juggles: int = 0

var attack_dir := Vector3(0, 0, 1)
var attack_point := Vector3.ZERO
var _retarget_tick: int = 0
var _hold_angle: float = 0.0
var _history_ticks := PackedInt32Array()
var _history_pos := PackedVector3Array()
var last_hit_slot: int = -1


func setup(p_id: int, p_generation: int, p_kind: int, p_def: EnemyDefinition, p_manager: Node, tick: int) -> void:
	id = p_id
	generation = p_generation
	kind = p_kind
	def = p_def
	manager = p_manager
	spawn_tick = tick
	health = def.max_health
	stagger = StaggerState.new(def.stagger_max, def.rank)
	stagger.configure_from_rules()
	mass = GameData.mass_of(def.mass_class)
	velocity_cap = GameData.velocity_cap_of(def.mass_class)
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = def.radius
	capsule.height = maxf(def.height, def.radius * 2.0 + 0.01)
	shape.shape = capsule
	shape.position = Vector3(0, capsule.height * 0.5, 0)
	add_child(shape)
	anim = A.SPAWNING
	state_until = tick + 36
	_history_ticks.resize(HISTORY)
	_history_ticks.fill(-1)
	_history_pos.resize(HISTORY)


func radius() -> float:
	return def.radius


func is_elite() -> bool:
	return def.is_elite_or_boss()


func health_fraction() -> float:
	return clampf(health / def.max_health, 0.0, 1.0)


func has_status(status: StringName, tick: int) -> bool:
	return statuses.has(status) and tick < int((statuses[status] as Array)[0])


func status_magnitude(status: StringName, tick: int) -> float:
	return float((statuses[status] as Array)[1]) if has_status(status, tick) else 0.0


func add_status(status: StringName, ticks: int, magnitude: float, owner_slot: int, tick: int) -> void:
	if ticks <= 0:
		return
	var until := tick + ticks
	if statuses.has(status):
		var cur: Array = statuses[status]
		until = maxi(until, int(cur[0]))
		magnitude = maxf(magnitude, float(cur[1]))
	statuses[status] = [until, magnitude, owner_slot]


func record_history(tick: int) -> void:
	var i := tick % HISTORY
	_history_ticks[i] = tick
	_history_pos[i] = global_position


## Position at a past tick for lag compensation (falls back to the current position).
func position_at(tick: int) -> Vector3:
	var i := tick % HISTORY
	if tick >= 0 and _history_ticks[i] == tick:
		return _history_pos[i]
	return global_position


func is_disabled(tick: int) -> bool:
	return anim in [A.STUNNED, A.FROZEN, A.STAGGERED, A.PRONE, A.KNOCKBACK, A.LAUNCHED, A.DEAD, A.SPAWNING]


func is_attacking() -> bool:
	return anim in [A.TELEGRAPH, A.ATTACK, A.RECOVER]


# --- Control --------------------------------------------------------------------------

func interrupt(tick: int) -> void:
	if anim == A.TELEGRAPH or anim == A.ATTACK:
		manager.call("emit_event", [NetProtocol.EV_TELEGRAPH_END, id])
	manager.call("release_tokens", self)


func apply_knockback(dv: Vector3, owner_slot: int, action_uid: int, tick: int) -> void:
	if dead or dv.length() < 0.05:
		return
	if def.rank == &"boss" and not stagger.is_staggered(tick):
		return
	knock_velocity += GameTypes.flat(dv)
	if knock_velocity.length() > velocity_cap * 2.0:
		knock_velocity = knock_velocity.normalized() * velocity_cap * 2.0
	knock_owner = owner_slot
	knock_action = action_uid
	if not is_prop and knock_velocity.length() > 1.0:
		interrupt(tick)
		anim = A.KNOCKBACK


func launch(ticks: int, tick: int) -> void:
	if dead or is_elite():
		return
	if juggles >= int(GameData.rule(&"juggle_max")):
		return
	juggles += 1
	interrupt(tick)
	air_until = maxi(air_until, tick + ticks)
	anim = A.LAUNCHED


func knock_down(ticks: int, tick: int) -> void:
	if dead or is_prop:
		return
	var t := stagger.control_duration(ticks, tick)
	if t <= 0:
		return
	interrupt(tick)
	anim = A.PRONE
	state_until = maxi(state_until, tick + t)


func on_stun(tick: int) -> void:
	interrupt(tick)
	anim = A.STUNNED
	state_until = stagger.stunned_until


func on_stagger(tick: int) -> void:
	interrupt(tick)
	anim = A.STAGGERED
	state_until = stagger.staggered_until


func kill(tick: int) -> void:
	if dead:
		return
	interrupt(tick)
	dead = true
	death_tick = tick
	anim = A.DEAD
	knock_velocity = Vector3.ZERO


# --- Simulation -------------------------------------------------------------------------

func sim_tick(tick: int, dt: float) -> void:
	if dead:
		return
	record_history(tick)
	if is_prop:
		_move_knockback(tick, dt)
		return
	# Control states first.
	if anim == A.SPAWNING:
		if tick >= state_until:
			anim = A.IDLE
		return
	if has_status(&"frozen", tick):
		if anim != A.FROZEN:
			interrupt(tick)
		anim = A.FROZEN
		_move_knockback(tick, dt)
		return
	elif anim == A.FROZEN:
		anim = A.IDLE
	if air_until > tick:
		anim = A.LAUNCHED
		_move_knockback(tick, dt)
		return
	elif anim == A.LAUNCHED:
		anim = A.PRONE
		state_until = tick + 30
		juggles = 0
	if knock_velocity.length() > 0.6:
		anim = A.KNOCKBACK
		_move_knockback(tick, dt)
		return
	elif anim == A.KNOCKBACK:
		var on_ice: bool = manager.call("surface_material_at", global_position) == SurfaceGrid.ICE
		if on_ice:
			anim = A.PRONE
			state_until = tick + GameData.rule_ticks(&"prone_s")
		else:
			anim = A.IDLE
	if anim == A.STUNNED or anim == A.STAGGERED or anim == A.PRONE:
		if tick < state_until:
			if anim == A.STAGGERED:
				_steer(Vector3.ZERO, dt, 0.0)
			return
		anim = A.IDLE
	if def.attack_kind == &"none":
		anim = A.IDLE
		return
	_think(tick, dt)


func _think(tick: int, dt: float) -> void:
	var heroes: Array = manager.call("targetable_heroes")
	if heroes.is_empty():
		if is_attacking():
			interrupt(tick)
		anim = A.IDLE
		_steer(Vector3.ZERO, dt, 1.0)
		return
	if target_slot < 0 or tick >= _retarget_tick or not _target_valid(heroes):
		var previous := target_slot
		target_slot = _pick_target(heroes)
		_retarget_tick = tick + 30
		if previous != target_slot and previous >= 0 and not is_attacking():
			manager.call("release_tokens", self)
	var hero: Node3D = manager.call("hero_node", target_slot)
	if hero == null:
		return
	var hero_pos := hero.global_position
	var to_hero := GameTypes.flat(hero_pos - global_position)
	var dist := to_hero.length()

	match anim:
		A.TELEGRAPH:
			yaw = atan2(attack_dir.x, attack_dir.z)
			_steer(Vector3.ZERO, dt, 0.0)
			if tick >= state_until:
				anim = A.ATTACK
				state_until = tick + def.active_ticks
				manager.call("enemy_attack", self, tick)
			return
		A.ATTACK:
			_steer(Vector3.ZERO, dt, 0.0)
			if tick >= state_until:
				anim = A.RECOVER
				state_until = tick + def.recovery_ticks
			return
		A.RECOVER:
			_steer(Vector3.ZERO, dt, 0.3)
			if tick >= state_until:
				manager.call("release_tokens", self)
				anim = A.IDLE
			return

	var in_range := dist <= def.attack_range
	var blinded := has_status(&"blinded", tick)
	if in_range and not blinded and manager.call("has_line_of_sight", global_position, hero_pos):
		if manager.call("claim_token", self, target_slot, tick):
			_begin_telegraph(hero_pos, tick)
			return
	# No token: keep the pressure on from an engagement slot.
	var ring := CombatDirector.RING_INNER if def.token_kind == &"melee" else CombatDirector.RING_OUTER
	var slot_pos: Vector3 = manager.call("engagement_slot", self, target_slot, ring, hero_pos)
	var to_slot := GameTypes.flat(slot_pos - global_position)
	var desired := Vector3.ZERO
	if to_slot.length() > 0.6:
		var flow: Vector3 = manager.call("flow_direction", target_slot, global_position)
		desired = flow if flow != Vector3.ZERO and to_slot.length() > 3.0 else to_slot.normalized()
		anim = A.MOVE
	else:
		_hold_angle += dt * 0.6
		desired = Vector3(-to_hero.z, 0, to_hero.x).normalized() * 0.35 * sin(_hold_angle)
		anim = A.IDLE
	if dist > 0.01:
		yaw = lerp_angle(yaw, atan2(to_hero.x, to_hero.z), minf(1.0, dt * 8.0))
	_steer(desired, dt, 1.0)


func _begin_telegraph(hero_pos: Vector3, tick: int) -> void:
	anim = A.TELEGRAPH
	state_until = tick + def.telegraph_ticks
	attack_dir = GameTypes.flat_dir(global_position, hero_pos)
	if attack_dir == Vector3.ZERO:
		attack_dir = Vector3(sin(yaw), 0, cos(yaw))
	yaw = atan2(attack_dir.x, attack_dir.z)
	var shape := NetProtocol.TG_SECTOR
	var center := global_position
	var radius_m := def.attack_radius
	var length := 0.0
	match def.attack_kind:
		&"slam":
			shape = NetProtocol.TG_CIRCLE
			center = global_position + attack_dir * 1.4
		&"arrow":
			shape = NetProtocol.TG_LINE
			length = def.attack_range
			radius_m = 0.5
	attack_point = center
	manager.call("emit_event", [NetProtocol.EV_TELEGRAPH, id, shape, snappedf(center.x, 0.01), snappedf(center.z, 0.01),
		snappedf(attack_dir.x, 0.001), snappedf(attack_dir.z, 0.001), radius_m, def.attack_arc_deg, length, def.telegraph_ticks])


func _target_valid(heroes: Array) -> bool:
	for h: Node3D in heroes:
		if int(h.get("slot")) == target_slot:
			return true
	return false


func _pick_target(heroes: Array) -> int:
	var best := -1
	var best_d := INF
	for h: Node3D in heroes:
		var d := global_position.distance_squared_to(h.global_position)
		if int(h.get("slot")) == target_slot:
			d *= 0.6  # hysteresis: keep the current target unless the other is clearly closer
		if d < best_d:
			best_d = d
			best = int(h.get("slot"))
	return best


func _steer(desired_dir: Vector3, dt: float, speed_scale: float) -> void:
	var speed := def.move_speed * speed_scale * float(manager.call("surface_speed_at", global_position))
	var sep: Vector3 = manager.call("separation", self)
	var v := desired_dir * speed + sep * 2.5
	velocity = Vector3(v.x, -2.0, v.z) * NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor


func _move_knockback(tick: int, dt: float) -> void:
	if knock_velocity.length() < 0.05:
		knock_velocity = Vector3.ZERO
		return
	var pre := knock_velocity
	velocity = Vector3(pre.x, -2.0, pre.z) * NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) > 0.7:
			continue
		var speed := KnockbackRules.slam_speed(pre, n, GameData.rule(&"wall_slam_speed"))
		if speed > 0.0 and not _slammed.has(knock_action):
			_slammed[knock_action] = true
			manager.call("on_wall_slam", self, speed, knock_owner, knock_action, tick)
		var into := pre.dot(Vector3(n.x, 0, n.z))
		if into < 0.0:
			knock_velocity = (pre - Vector3(n.x, 0, n.z) * into * 1.3) * 0.35
		break
	manager.call("transfer_momentum", self, pre, tick)
	var friction: float = manager.call("surface_friction_at", global_position)
	knock_velocity = KnockbackRules.decay(knock_velocity, GameData.rule(&"knockback_decel"), friction, dt)


func mark_transfer(key: String) -> bool:
	if _transferred.has(key):
		return false
	_transferred[key] = true
	return true
