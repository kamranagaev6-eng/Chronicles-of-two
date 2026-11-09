class_name Hero
extends CharacterBody3D
## A networked hero. netfox's RollbackSynchronizer predicts the owner's movement and dodge and
## reconciles with the host. Gameplay effects never happen here: fresh motor events are handed to the
## host's combat system and to presentation exactly once. Host-side changes (knockback, downed,
## revive, respawn, resource gains) enter through a tick-stamped command queue applied inside the
## rollback tick, so resimulation reapplies them identically.

signal action_event(hero: Hero, ev: Dictionary)

const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.8

var slot: int = 0
var setup: Dictionary = {}
var arena: Node = null
var class_def: ClassDefinition
var attributes: AttributeSet
var hero_name: String = "Hero"
var color_name: String = "gold"
var loadout_ids: Array[StringName] = []
var runes: Dictionary = {}
var assists: Dictionary = {}

var motor: HeroMotor
var input: HeroInput
var rollback: RollbackSynchronizer
var stats := HeroStats.new()

## Host only: commands by tick, the last tick simulated with real input, and a short
## position/invulnerability history so enemy hits resolve against the hero's own timeline.
var last_fresh_tick: int = -1
var timeline: Dictionary = {}
var _commands: Dictionary = {}

## Owner only: predicted positions per tick, for measuring reconciliation corrections.
var _predicted: Dictionary = {}
var _loop_correction: float = 0.0
var teleported_tick: int = -100


static func create(p_slot: int, p_setup: Dictionary, p_arena: Node) -> Hero:
	var hero := Hero.new()
	hero.slot = p_slot
	hero.setup = p_setup
	hero.arena = p_arena
	hero.name = "Hero%d" % p_slot
	return hero


func _ready() -> void:
	class_def = GameData.class_def(StringName(str(setup.get("class_id", "vanguard"))))
	attributes = AttributeSet.from_dictionary(setup.get("attributes", class_def.attributes()) as Dictionary)
	hero_name = str(setup.get("name", "Hero"))
	color_name = str(setup.get("color", "gold"))
	assists = setup.get("assists", {}) as Dictionary
	var loadout: Dictionary = setup.get("loadout", {})
	loadout_ids.clear()
	for id: Variant in loadout.get("abilities", []):
		loadout_ids.append(StringName(str(id)))
	runes = loadout.get("runes", {}) as Dictionary

	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0, CAPSULE_HEIGHT * 0.5, 0)
	add_child(shape)

	motor = HeroMotor.new()
	motor.name = "Motor"
	add_child(motor)
	_configure_motor()

	input = HeroInput.new()
	input.name = "Input"
	input.hero = self
	input.arena = arena
	add_child(input)

	var owner_peer := int(setup.get("peer_id", 1))
	set_multiplayer_authority(1, true)
	input.set_multiplayer_authority(owner_peer)

	stats.max_health = class_def.max_health * (1.0 + attributes.stat(&"max_health_inc"))
	stats.health = stats.max_health

	rollback = RollbackSynchronizer.new()
	rollback.name = "RollbackSynchronizer"
	rollback.root = self
	var state_props: Array[String] = [":position"]
	for p: String in HeroMotor.STATE_PROPERTIES:
		state_props.append("Motor:" + p)
	rollback.state_properties = state_props
	var input_props: Array[String] = []
	for p: String in HeroInput.INPUT_PROPERTIES:
		input_props.append("Input:" + p)
	rollback.input_properties = input_props
	# Inputs go to the host only (saves bandwidth); the partner's hero arrives as host state at 60 Hz.
	rollback.enable_input_broadcast = false
	add_child(rollback)

	NetworkRollback.after_loop.connect(_after_rollback_loop)


func _exit_tree() -> void:
	if NetworkRollback.after_loop.is_connected(_after_rollback_loop):
		NetworkRollback.after_loop.disconnect(_after_rollback_loop)


func _configure_motor() -> void:
	motor.configure_from_rules()
	motor.move_speed = class_def.move_speed
	motor.resource_max = class_def.resource_max
	motor.resource = class_def.resource_start
	motor.uses_flux = class_def.resource_id == &"flux"
	motor.resource_regen_per_tick = class_def.resource_regen_per_s * (1.0 + attributes.stat(&"resource_regen_inc")) / GameData.rule(&"sim_tickrate")
	motor.dodge_distance_multiplier = 1.0 + attributes.stat(&"dodge_distance_inc")
	if bool(assists.get("dodge_timing", false)):
		motor.iframe_ticks = roundi(motor.iframe_ticks * GameData.rule(&"dodge_assist_multiplier"))
	var defs: Array[AbilityDefinition] = []
	defs.resize(GameTypes.ACTION_COUNT)
	defs[GameTypes.ACT_BASIC] = GameData.ability(class_def.basic_attack)
	for i in mini(4, loadout_ids.size()):
		defs[GameTypes.ACT_1 + i] = GameData.ability(loadout_ids[i])
	defs[GameTypes.ACT_SHOVE] = GameData.ability(&"shove")
	defs[GameTypes.ACT_FLASK] = GameData.ability(&"flask")
	motor.abilities = defs
	motor.surface_query = _surface_query
	motor.blink_resolver = _blink_resolve


## Changing loadout or runes (only out of combat). Both PCs apply the same change from the host's event.
func set_loadout(ability_ids: Array, rune_map: Dictionary) -> void:
	loadout_ids.clear()
	for id: Variant in ability_ids:
		loadout_ids.append(StringName(str(id)))
	runes = rune_map
	for i in 4:
		motor.abilities[GameTypes.ACT_1 + i] = GameData.ability(loadout_ids[i]) if i < loadout_ids.size() else null


func ability_for_slot(action_slot: int) -> AbilityDefinition:
	return motor.ability_at(action_slot)


func rune_for(ability_id: StringName) -> RuneDefinition:
	var entry: Variant = runes.get(String(ability_id), null)
	if entry is Dictionary and (entry as Dictionary).has("form"):
		return GameData.rune(StringName(str((entry as Dictionary)["form"])))
	return null


func is_local_player() -> bool:
	return input != null and input.is_multiplayer_authority()


func feet() -> Vector3:
	return global_position


func center() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func facing() -> Vector3:
	return Vector3(sin(motor.yaw), 0.0, cos(motor.yaw))


# --- Simulation ----------------------------------------------------------------------

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if multiplayer.is_server():
		var cmds: Array = _commands.get(tick, [])
		for c: Dictionary in cmds:
			if StringName(c.get("type", "")) == &"teleport":
				global_position = c["position"]
				teleported_tick = tick
			else:
				motor.apply_command(c)
	var f := input.frame()
	var origin := global_position
	var result := motor.step(f, tick, origin, delta, motor.grounded)
	if result.teleport:
		global_position = result.teleport_to
		teleported_tick = tick
	velocity = result.velocity * NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	motor.grounded = is_on_floor()
	if global_position.y < -10.0:
		global_position = Vector3(global_position.x, 1.0, global_position.z)
	if is_fresh:
		for ev: Dictionary in result.events:
			ev["hero_slot"] = slot
			ev["origin"] = origin
			ev["view_tick"] = f.view_tick
			action_event.emit(self, ev)
		if multiplayer.is_server():
			last_fresh_tick = maxi(last_fresh_tick, tick)
			timeline[tick] = [global_position, motor.is_invulnerable(tick)]
			timeline.erase(tick - 90)
			_commands.erase(tick - 90)
	if is_local_player() and not multiplayer.is_server():
		var key := tick + 1
		if not is_fresh and _predicted.has(key):
			var diff := global_position - (_predicted[key] as Vector3)
			if diff.length() >= _loop_correction:
				_loop_correction = diff.length()
				_loop_correction_vec = diff
		_predicted[key] = global_position
		_predicted.erase(key - 120)


var _loop_correction_vec := Vector3.ZERO
## Presentation listens to smooth over prediction corrections instead of snapping.
signal corrected(offset: Vector3)


func _after_rollback_loop() -> void:
	if is_local_player() and not multiplayer.is_server():
		Net.stats.record_correction(_loop_correction)
		if _loop_correction > 0.5:
			var def := motor.ability_at(motor.action_slot)
			print("[correction] tick %d: %.3f m %s · action %s · dodge %d · teleported %d · downed %s · paused %s" % [
				NetworkTime.tick, _loop_correction, _loop_correction_vec, def.id if def != null else &"-",
				motor.dodge_ticks_left, teleported_tick, motor.downed, motor.paused])
		if _loop_correction > 0.001 and teleported_tick < NetworkTime.tick - 4:
			corrected.emit(_loop_correction_vec)
	_loop_correction = 0.0
	_loop_correction_vec = Vector3.ZERO


## Host: schedule a command for the next tick this hero will simulate with real input.
func queue_command(cmd: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var t := last_fresh_tick + 1 if last_fresh_tick >= 0 else NetworkTime.tick
	var list: Array = _commands.get(t, [])
	list.append(cmd)
	_commands[t] = list


## Host: position and invulnerability at a tick of this hero's own timeline (null when unknown yet).
func timeline_at(tick: int) -> Variant:
	return timeline.get(tick, null)


func _surface_query(pos: Vector3) -> Dictionary:
	if arena != null and arena.has_method("hero_surface_query"):
		return arena.call("hero_surface_query", pos)
	return {"speed": 1.0, "friction": 1.0}


## Blink lands on the furthest point toward the target that a capsule can stand on.
func _blink_resolve(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return to
	var params := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	params.shape = capsule
	params.collision_mask = 1
	params.transform = Transform3D(Basis(), from + Vector3(0, CAPSULE_HEIGHT * 0.5 + 0.05, 0))
	params.motion = GameTypes.flat(to - from)
	var fractions := space.cast_motion(params)
	var safe := fractions[0] if fractions.size() > 0 else 1.0
	var target := from + GameTypes.flat(to - from) * safe
	var ray := PhysicsRayQueryParameters3D.create(target + Vector3(0, 3.0, 0), target + Vector3(0, -3.0, 0), 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		target.y = (hit["position"] as Vector3).y
	return target
