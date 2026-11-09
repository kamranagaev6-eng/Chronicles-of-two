class_name BotBrain
extends RefCounted
## Scripted partner for unattended soak tests (--bot). It plays like a cautious human: starts waves at
## the Waystone, keeps its class range, attacks, casts what is off cooldown, dodges telegraphs and
## revives its partner. It only ever writes input properties, exactly like a real player.

var hero: Hero
var arena: Node
var rng := RandomNumberGenerator.new()
var _next_cast_tick: int = 0
var _next_dodge_tick: int = 0
var _strafe_sign: float = 1.0
var _strafe_until: int = 0


func _init(p_hero: Hero, p_arena: Node) -> void:
	hero = p_hero
	arena = p_arena
	rng.seed = 7919 + p_hero.slot * 104729


func drive(input: HeroInput) -> void:
	var tick := NetworkTime.tick
	var pos := hero.global_position
	input.held = 0
	input.move = Vector2.ZERO
	if hero.motor.downed:
		var toward: Vector3 = arena.call("waystone_position")
		_move_toward(input, pos, toward, 0.0)
		return
	var partner: Hero = arena.call("partner_of", hero.slot)
	if partner != null and partner.stats.life == NetProtocol.LIFE_DOWNED:
		var d := GameTypes.flat(partner.global_position - pos).length()
		if d > 1.2:
			_move_toward(input, pos, partner.global_position, 1.0)
		else:
			input.held |= GameTypes.BTN_INTERACT
		input.aim = partner.global_position
		return
	var state: int = arena.call("encounter_state")
	if state == NetProtocol.WAVE_PREP or state == NetProtocol.WAVE_BREAK:
		var ws: Vector3 = arena.call("waystone_position")
		if GameTypes.flat(ws - pos).length() > 1.8:
			_move_toward(input, pos, ws, 1.5)
		elif tick % 90 == 0:
			input.held |= GameTypes.BTN_INTERACT
		else:
			input.held |= GameTypes.BTN_INTERACT
		return
	var target: Variant = arena.call("nearest_enemy_position", pos)
	if target == null:
		return
	var tpos: Vector3 = target
	input.aim = tpos
	var dist := GameTypes.flat(tpos - pos).length()
	var preferred := 1.7 if hero.class_def.id == &"vanguard" else 7.0
	if tick >= _strafe_until:
		_strafe_sign = -_strafe_sign
		_strafe_until = tick + rng.randi_range(60, 150)
	var to_target := GameTypes.flat_dir(pos, tpos)
	var side := Vector3(-to_target.z, 0.0, to_target.x) * _strafe_sign
	var radial := 0.0
	if dist > preferred + 0.6:
		radial = 1.0
	elif dist < preferred - 0.6:
		radial = -1.0
	var mv := (to_target * radial + side * 0.6)
	if mv.length() > 0.01:
		mv = mv.normalized()
	input.move = Vector2(mv.x, mv.z)
	if dist < preferred + 4.0:
		input.held |= GameTypes.BTN_ATTACK
	# Coordination first: finish what the partner primed, prime what nobody has.
	var primed: Variant = arena.call("primed_enemy_position", 1 - hero.slot, pos, 11.0)
	var finisher := _slot_with(func(d: AbilityDefinition) -> bool: return d.is_finisher())
	var primer := _slot_with(func(d: AbilityDefinition) -> bool: return d.is_primer())
	if primed != null and finisher >= 0 and hero.motor.can_start(finisher, tick):
		input.aim = primed
		input.request_action(finisher)
		_next_cast_tick = tick + 30
	elif primer >= 0 and tick >= _next_cast_tick and dist < 12.0 and hero.motor.can_start(primer, tick):
		input.request_action(primer)
		_next_cast_tick = tick + rng.randi_range(30, 70)
	elif tick >= _next_cast_tick and dist < 12.0:
		var slots: Array[int] = [GameTypes.ACT_1, GameTypes.ACT_2, GameTypes.ACT_3, GameTypes.ACT_4, GameTypes.ACT_SHOVE]
		slots.shuffle()
		for s: int in slots:
			if hero.motor.can_start(s, tick):
				input.request_action(s)
				break
		_next_cast_tick = tick + rng.randi_range(40, 110)
	if hero.stats.health_fraction() < 0.45 and hero.motor.flask_charges > 0 and tick % 120 == 0:
		input.request_action(GameTypes.ACT_FLASK)
	var threatened: bool = arena.call("telegraph_threatens", pos)
	if (threatened or tick >= _next_dodge_tick) and hero.motor.dodge_charges > 0:
		input.request_dodge()
		_next_dodge_tick = tick + rng.randi_range(150, 300)


func _slot_with(test: Callable) -> int:
	for s in range(GameTypes.ACT_1, GameTypes.ACT_4 + 1):
		var def := hero.motor.ability_at(s)
		if def != null and test.call(def):
			return s
	return -1


func _move_toward(input: HeroInput, pos: Vector3, target: Vector3, stop_at: float) -> void:
	var d := GameTypes.flat(target - pos)
	if d.length() <= stop_at:
		input.move = Vector2.ZERO
		return
	var n := d.normalized()
	input.move = Vector2(n.x, n.z)
	input.aim = target
