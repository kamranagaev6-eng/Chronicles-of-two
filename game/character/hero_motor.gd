class_name HeroMotor
extends Node
## Deterministic hero simulation: movement, dodge, action timing, cooldowns and resource.
## It runs inside netfox's _rollback_tick on both PCs: the owner predicts it, the host decides it.
## No side effects: step() only changes this node's state and returns events. The host and the
## presentation act on those events only for fresh ticks, so replays never duplicate anything.

## Rollback state, synchronised by netfox as "Motor:<name>".
const STATE_PROPERTIES: Array[String] = [
	"yaw", "move_velocity", "ext_velocity", "vel_y", "grounded",
	"dodge_charges", "dodge_recharge_tick", "dodge_start_tick", "dodge_ticks_left", "dodge_dir",
	"dodge_seq_seen", "dodge_pending_tick",
	"action_slot", "action_seq", "action_tick", "action_aim", "action_dir",
	"req_seq_seen", "pending_slot", "pending_tick",
	"cd0", "cd1", "cd2", "cd3", "cd4", "cd5", "cd6",
	"resource", "last_element", "flask_charges", "downed", "paused", "hold_until", "protected_until",
]


class InputFrame:
	extends RefCounted
	var move: Vector2 = Vector2.ZERO
	var aim: Vector3 = Vector3.ZERO
	var held: int = 0
	var req_seq: int = 0
	var req_slot: int = -1
	var dodge_seq: int = 0
	var view_tick: int = 0


class StepResult:
	extends RefCounted
	var velocity: Vector3 = Vector3.ZERO
	var teleport: bool = false
	var teleport_to: Vector3 = Vector3.ZERO
	var events: Array[Dictionary] = []


# --- Configuration (identical on both PCs; set at spawn) ---------------------------
var move_speed: float = 6.0
var resource_max: float = 100.0
var resource_regen_per_tick: float = 0.0
var uses_flux: bool = false
var weave_refund: float = 0.15
var dodge_distance_multiplier: float = 1.0
var iframe_ticks: int = 10
var dodge_ticks: int = 12
var dodge_speed: float = 13.0
var dodge_charges_max: int = 2
var dodge_recharge_ticks: int = 96
var buffer_ticks: int = 9
var accel: float = 70.0
var decel: float = 90.0
var crawl_multiplier: float = 0.25
var knockback_decel: float = 18.0
var flask_max: int = 3
var gravity: float = 24.0
## Ability per action slot (GameTypes.ACT_*), null where empty.
var abilities: Array[AbilityDefinition] = []
## func(pos: Vector3) -> Dictionary {"speed": float, "friction": float}
var surface_query: Callable
## func(from: Vector3, to: Vector3) -> Vector3: furthest valid point toward `to`.
var blink_resolver: Callable

# --- Rollback state -------------------------------------------------------------------
var yaw: float = 0.0
var move_velocity: Vector3 = Vector3.ZERO
var ext_velocity: Vector3 = Vector3.ZERO
var vel_y: float = 0.0
var grounded: bool = true
var dodge_charges: int = 2
var dodge_recharge_tick: int = -1
var dodge_start_tick: int = -100000
var dodge_ticks_left: int = 0
var dodge_dir: Vector3 = Vector3.ZERO
var dodge_seq_seen: int = 0
var dodge_pending_tick: int = -1
var action_slot: int = -1
var action_seq: int = 0
var action_tick: int = 0
var action_aim: Vector3 = Vector3.ZERO
var action_dir: Vector3 = Vector3(0, 0, 1)
var req_seq_seen: int = 0
var pending_slot: int = -1
var pending_tick: int = -1
var cd0: int = 0
var cd1: int = 0
var cd2: int = 0
var cd3: int = 0
var cd4: int = 0
var cd5: int = 0
var cd6: int = 0
var resource: float = 0.0
var last_element: int = -1
var flask_charges: int = 3
var downed: bool = false
var paused: bool = false
## Resumes are scheduled for a future tick so both PCs release on exactly the same tick.
var hold_until: int = 0
var protected_until: int = -1


func configure_from_rules() -> void:
	dodge_ticks = int(GameData.rule(&"dodge_ticks"))
	dodge_speed = GameData.rule(&"dodge_speed")
	dodge_charges_max = int(GameData.rule(&"dodge_charges"))
	dodge_recharge_ticks = GameData.rule_ticks(&"dodge_recharge_s")
	iframe_ticks = int(GameData.rule(&"dodge_iframe_ticks"))
	buffer_ticks = GameData.rule_ticks(&"input_buffer_s")
	accel = GameData.rule(&"hero_accel")
	decel = GameData.rule(&"hero_decel")
	crawl_multiplier = GameData.rule(&"downed_crawl_multiplier")
	knockback_decel = GameData.rule(&"knockback_decel")
	flask_max = int(GameData.rule(&"flask_charges"))
	weave_refund = GameData.rule(&"flux_weave_refund")
	dodge_charges = dodge_charges_max
	flask_charges = flask_max


func get_cd(slot: int) -> int:
	match slot:
		0: return cd0
		1: return cd1
		2: return cd2
		3: return cd3
		4: return cd4
		5: return cd5
		6: return cd6
	return 0


func set_cd(slot: int, value: int) -> void:
	match slot:
		0: cd0 = value
		1: cd1 = value
		2: cd2 = value
		3: cd3 = value
		4: cd4 = value
		5: cd5 = value
		6: cd6 = value


func ability_at(slot: int) -> AbilityDefinition:
	if slot < 0 or slot >= abilities.size():
		return null
	return abilities[slot]


func is_invulnerable(tick: int) -> bool:
	return tick - dodge_start_tick < iframe_ticks or tick < protected_until


func is_acting() -> bool:
	return action_slot >= 0


## Ticks since the current action started (or -1 when idle).
func action_elapsed(tick: int) -> int:
	return tick - action_tick if action_slot >= 0 else -1


func effective_cost(def: AbilityDefinition) -> float:
	if def == null or def.cost <= 0.0:
		return 0.0
	var elem := GameTypes.element_index(def.element)
	if elem >= 0 and last_element >= 0 and elem != last_element:
		return def.cost * (1.0 - weave_refund)
	return def.cost


func can_start(slot: int, tick: int) -> bool:
	if downed or paused or tick < hold_until:
		return false
	var def := ability_at(slot)
	if def == null:
		return false
	if get_cd(slot) > tick:
		return false
	if uses_flux and resource + 0.0001 < effective_cost(def):
		return false
	if slot == GameTypes.ACT_FLASK and flask_charges <= 0:
		return false
	if dodge_ticks_left > 0:
		return false
	if action_slot >= 0:
		var cur := ability_at(action_slot)
		var elapsed := tick - action_tick
		if cur != null and elapsed < cur.total_ticks():
			if cur.cancel_tick < 0 or elapsed < cur.cancel_tick:
				return false
	return true


func can_dodge(tick: int) -> bool:
	if downed or paused or dodge_charges <= 0 or dodge_ticks_left > 0:
		return false
	if action_slot >= 0:
		var cur := ability_at(action_slot)
		var elapsed := tick - action_tick
		if cur != null and elapsed >= cur.windup_ticks and elapsed < cur.windup_ticks + cur.active_ticks:
			return false
	return true


## Host commands are applied at a specific tick inside the rollback tick, so replays re-apply them.
func apply_command(cmd: Dictionary) -> void:
	match StringName(cmd.get("type", "")):
		&"knockback":
			ext_velocity += cmd.get("velocity", Vector3.ZERO) as Vector3
		&"downed":
			downed = bool(cmd.get("value", false))
			if downed:
				action_slot = -1
				pending_slot = -1
				dodge_ticks_left = 0
				move_velocity = Vector3.ZERO
		&"paused":
			paused = bool(cmd.get("value", false))
		&"hold_until":
			hold_until = int(cmd.get("tick", 0))
		&"resource":
			resource = clampf(resource + float(cmd.get("delta", 0.0)), 0.0, resource_max)
		&"protect":
			protected_until = maxi(protected_until, int(cmd.get("until", 0)))
		&"flask_refill":
			flask_charges = flask_max
		&"reset":
			action_slot = -1
			pending_slot = -1
			dodge_ticks_left = 0
			dodge_charges = dodge_charges_max
			dodge_recharge_tick = -1
			move_velocity = Vector3.ZERO
			ext_velocity = Vector3.ZERO
			downed = false
			flask_charges = flask_max
			for s in GameTypes.ACTION_COUNT:
				set_cd(s, 0)


func step(inp: InputFrame, tick: int, position: Vector3, dt: float, on_floor: bool) -> StepResult:
	var result := StepResult.new()
	if resource_regen_per_tick > 0.0 and not paused:
		resource = minf(resource_max, resource + resource_regen_per_tick)
	if dodge_charges < dodge_charges_max and dodge_recharge_tick >= 0 and tick >= dodge_recharge_tick:
		dodge_charges += 1
		dodge_recharge_tick = tick + dodge_recharge_ticks if dodge_charges < dodge_charges_max else -1

	if inp.dodge_seq != dodge_seq_seen:
		dodge_seq_seen = inp.dodge_seq
		dodge_pending_tick = tick
	if inp.req_seq != req_seq_seen:
		req_seq_seen = inp.req_seq
		pending_slot = inp.req_slot
		pending_tick = tick
	if pending_slot >= 0 and tick - pending_tick > buffer_ticks:
		pending_slot = -1
	if dodge_pending_tick >= 0 and tick - dodge_pending_tick > buffer_ticks:
		dodge_pending_tick = -1

	var move_dir := Vector3(inp.move.x, 0.0, inp.move.y)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var surface := {"speed": 1.0, "friction": 1.0}
	if surface_query.is_valid():
		surface = surface_query.call(position)

	if paused or tick < hold_until:
		move_velocity = Vector3.ZERO
		ext_velocity = Vector3.ZERO
		pending_slot = -1
		dodge_pending_tick = -1
		result.velocity = Vector3(0.0, _vertical(on_floor, dt), 0.0)
		return result

	if downed:
		move_velocity = move_dir * move_speed * crawl_multiplier
		ext_velocity = KnockbackRules.decay(ext_velocity, knockback_decel, 1.0, dt)
		result.velocity = move_velocity + ext_velocity + Vector3(0.0, _vertical(on_floor, dt), 0.0)
		if move_dir != Vector3.ZERO:
			yaw = atan2(move_dir.x, move_dir.z)
		return result

	# Dodge first: it may cancel wind-up and recovery, never active frames.
	if dodge_pending_tick >= 0 and can_dodge(tick):
		dodge_pending_tick = -1
		if action_slot >= 0:
			result.events.append({"type": &"cancel", "slot": action_slot, "seq": action_seq, "tick": tick})
			action_slot = -1
		dodge_charges -= 1
		if dodge_recharge_tick < 0:
			dodge_recharge_tick = tick + dodge_recharge_ticks
		dodge_start_tick = tick
		dodge_ticks_left = dodge_ticks
		dodge_dir = move_dir.normalized() if move_dir != Vector3.ZERO else Vector3(sin(yaw), 0.0, cos(yaw))
		result.events.append({"type": &"dodge", "tick": tick, "dir": dodge_dir})

	# Buffered request, then the held basic attack.
	if pending_slot >= 0 and can_start(pending_slot, tick):
		_start_action(pending_slot, inp, tick, position, result)
	elif pending_slot < 0 and (inp.held & GameTypes.BTN_ATTACK) != 0 and action_slot < 0 and can_start(GameTypes.ACT_BASIC, tick):
		_start_action(GameTypes.ACT_BASIC, inp, tick, position, result)

	# Action timeline.
	var charge_velocity := Vector3.ZERO
	var charging := false
	var move_multiplier := 1.0
	if action_slot >= 0:
		var def := ability_at(action_slot)
		var elapsed := tick - action_tick
		if def == null:
			action_slot = -1
		else:
			move_multiplier = def.move_multiplier
			if elapsed >= def.windup_ticks and elapsed < def.windup_ticks + def.active_ticks:
				var index := elapsed - def.windup_ticks
				result.events.append({"type": &"active", "slot": action_slot, "seq": action_seq, "tick": tick,
					"index": index, "aim": action_aim, "dir": action_dir, "ability": def.id})
				if def.delivery == &"charge" and index < def.move_ticks:
					charging = true
					charge_velocity = action_dir * def.move_speed
				if def.delivery == &"blink" and index == 0:
					var target := _blink_target(position, def)
					result.teleport = true
					result.teleport_to = target
					result.events.append({"type": &"blink", "seq": action_seq, "tick": tick, "from": position, "to": target})
			if elapsed + 1 >= def.total_ticks():
				result.events.append({"type": &"end", "slot": action_slot, "seq": action_seq, "tick": tick})
				action_slot = -1

	# Movement.
	var horizontal := Vector3.ZERO
	if dodge_ticks_left > 0:
		dodge_ticks_left -= 1
		horizontal = dodge_dir * dodge_speed * dodge_distance_multiplier
		move_velocity = horizontal * 0.5
	elif charging:
		horizontal = charge_velocity
		move_velocity = Vector3.ZERO
	else:
		var desired := move_dir * move_speed * float(surface.get("speed", 1.0)) * move_multiplier
		var friction: float = surface.get("friction", 1.0)
		var rate := (accel if desired.length() >= move_velocity.length() else decel) * friction
		move_velocity = move_velocity.move_toward(desired, rate * dt)
		horizontal = move_velocity
	ext_velocity = KnockbackRules.decay(ext_velocity, knockback_decel, float(surface.get("friction", 1.0)), dt)

	# Facing.
	if action_slot >= 0:
		yaw = atan2(action_dir.x, action_dir.z)
	elif dodge_ticks_left > 0:
		yaw = atan2(dodge_dir.x, dodge_dir.z)
	elif move_dir != Vector3.ZERO:
		yaw = atan2(move_dir.x, move_dir.z)

	result.velocity = horizontal + ext_velocity + Vector3(0.0, _vertical(on_floor, dt), 0.0)
	return result


func _vertical(on_floor: bool, dt: float) -> float:
	if on_floor:
		vel_y = -0.5
	else:
		vel_y = maxf(vel_y - gravity * dt, -30.0)
	return vel_y


func _start_action(slot: int, inp: InputFrame, tick: int, position: Vector3, result: StepResult) -> void:
	var def := ability_at(slot)
	action_slot = slot
	action_seq += 1
	action_tick = tick
	action_aim = inp.aim
	var dir := GameTypes.flat_dir(position, inp.aim)
	action_dir = dir if dir != Vector3.ZERO else Vector3(sin(yaw), 0.0, cos(yaw))
	set_cd(slot, tick + def.cooldown_ticks)
	if uses_flux:
		resource = maxf(0.0, resource - effective_cost(def))
	var elem := GameTypes.element_index(def.element)
	if elem >= 0:
		last_element = elem
	if slot == GameTypes.ACT_FLASK:
		flask_charges -= 1
	if slot == pending_slot:
		pending_slot = -1
	result.events.append({"type": &"start", "slot": slot, "seq": action_seq, "tick": tick,
		"aim": action_aim, "dir": action_dir, "ability": def.id})


func _blink_target(position: Vector3, def: AbilityDefinition) -> Vector3:
	var to := action_aim
	var offset := GameTypes.flat(to - position)
	if offset.length() > def.range_m:
		offset = offset.normalized() * def.range_m
	to = position + offset
	if blink_resolver.is_valid():
		return blink_resolver.call(position, to)
	return to
