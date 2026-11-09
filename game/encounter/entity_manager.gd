class_name EntityManager
extends Node3D
## Host-only owner of every host-simulated entity: enemies and important props (barrels).
## Allocates stable entity IDs with spawn generations, keeps short position histories for lag
## compensation, runs the Combat Director and per-hero flow fields, and packs crowd snapshots.

var arena: Node
var combat: Node
var director := CombatDirector.new()
var flow_fields: Array[FlowField] = []
var entities: Dictionary = {}     # id -> Enemy
var _generations: Dictionary = {}
var _next_id: int = 1
var _flow_counter: int = 0
var _audit_counter: int = 0
var tokens_reclaimed: int = 0


func setup(p_arena: Node, p_combat: Node, layout_flow: Callable) -> void:
	arena = p_arena
	combat = p_combat
	director.configure_from_rules()
	for _i in GameTypes.SLOT_COUNT:
		var f := FlowField.new()
		layout_flow.call(f)
		flow_fields.append(f)


func spawn_enemy(enemy_id: StringName, pos: Vector3, tick: int) -> Enemy:
	var def := GameData.enemy(enemy_id)
	if def == null:
		push_error("Unknown enemy %s" % enemy_id)
		return null
	return _spawn(def, GameData.enemy_index(enemy_id), false, pos, tick)


func spawn_prop(prop_kind: int, pos: Vector3, tick: int) -> Enemy:
	var def := EnemyDefinition.new()
	def.id = &"oil_barrel" if prop_kind == NetProtocol.KIND_OIL_BARREL else &"water_barrel"
	def.display_name = "Oil barrel" if prop_kind == NetProtocol.KIND_OIL_BARREL else "Water barrel"
	def.rank = &"normal"
	def.undead = false
	def.mass_class = &"light"
	def.max_health = 1.0
	def.stagger_max = 0.0
	def.move_speed = 0.0
	def.radius = 0.4
	def.height = 1.0
	def.token_kind = &"none"
	def.attack_kind = &"none"
	var e := _spawn(def, prop_kind, true, pos, tick)
	e.anim = GameTypes.Anim.IDLE
	return e


func _spawn(def: EnemyDefinition, p_kind: int, prop: bool, pos: Vector3, tick: int) -> Enemy:
	var id := _allocate_id()
	var gen: int = (int(_generations.get(id, 0)) + 1) & 0xFF
	_generations[id] = gen
	var e := Enemy.new()
	e.name = "E%d" % id
	e.is_prop = prop
	e.setup(id, gen, p_kind, def, self, tick)
	add_child(e)
	e.global_position = pos
	entities[id] = e
	if not prop:
		emit_event([NetProtocol.EV_SPAWN, id, p_kind, snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)])
	return e


func _allocate_id() -> int:
	for _i in 65535:
		var id := _next_id
		_next_id = _next_id + 1 if _next_id < 65535 else 1
		if not entities.has(id):
			return id
	return -1


func despawn(e: Enemy) -> void:
	director.forget(e.id)
	entities.erase(e.id)
	e.queue_free()


func clear_all() -> void:
	for id: int in entities.keys():
		var e: Enemy = entities[id]
		director.forget(id)
		e.queue_free()
	entities.clear()


func get_entity(id: int) -> Enemy:
	return entities.get(id) as Enemy


func alive_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in entities.values():
		if not e.dead and not e.is_prop:
			out.append(e)
	return out


func alive_entities() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in entities.values():
		if not e.dead:
			out.append(e)
	return out


## Entities whose capsule overlaps a circle. With at_tick >= 0, positions are rewound for lag compensation.
func query_radius(center: Vector3, radius: float, at_tick: int = -1, include_props: bool = true) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in entities.values():
		if e.dead or (e.is_prop and not include_props):
			continue
		var p := e.position_at(at_tick) if at_tick >= 0 else e.global_position
		if GameTypes.flat(p - center).length() <= radius + e.radius():
			out.append(e)
	return out


func tick(t: int, dt: float) -> void:
	_flow_counter += 1
	if _flow_counter >= int(60.0 / GameData.rule(&"flow_field_hz")):
		_flow_counter = 0
		for slot in GameTypes.SLOT_COUNT:
			var h: Node3D = hero_node(slot)
			if h != null:
				flow_fields[slot].compute(h.global_position)
	_audit_counter += 1
	if _audit_counter >= GameData.rule_ticks(&"token_audit_s"):
		_audit_counter = 0
		tokens_reclaimed += director.audit(func(enemy_id: int, hero_slot: int, _kind: StringName, claimed: int) -> bool:
			return _token_valid(enemy_id, hero_slot, claimed, t))
	for e: Enemy in entities.values():
		e.sim_tick(t, dt)
		if e.dead and t - e.death_tick > 90:
			despawn(e)


func _token_valid(enemy_id: int, hero_slot: int, claimed_tick: int, t: int) -> bool:
	var e: Enemy = entities.get(enemy_id)
	if e == null or e.dead or e.target_slot != hero_slot:
		return false
	if e.is_attacking():
		return true
	return t - claimed_tick < GameData.rule_ticks(&"token_claim_grace_s")


func build_snapshot(t: int) -> PackedByteArray:
	return CrowdCodec.encode(t, view_states(t))


## Current states in snapshot form (the host's own presentation uses these directly).
func view_states(t: int) -> Array[CrowdCodec.Entity]:
	var out: Array[CrowdCodec.Entity] = []
	var store: PrimerStore = (combat.get("resolver") as ReactionResolver).store
	for e: Enemy in entities.values():
		var s := CrowdCodec.Entity.new()
		s.id = e.id
		s.generation = e.generation
		s.kind = e.kind
		s.position = e.global_position
		if e.air_until > t:
			var remaining := float(e.air_until - t) / 72.0
			s.position.y += 1.6 * sin(clampf(remaining, 0.0, 1.0) * PI)
		s.yaw = e.yaw
		s.anim = e.anim
		s.health = e.health_fraction()
		s.stagger = e.stagger.fraction() if not e.stagger.is_staggered(t) else 1.0
		var p0 := store.primer_of(e.id, 0, t)
		var p1 := store.primer_of(e.id, 1, t)
		s.primer0 = GameTypes.primer_index(p0.type) + 1 if p0 != null else 0
		s.primer1 = GameTypes.primer_index(p1.type) + 1 if p1 != null else 0
		var flags := 0
		if e.has_status(&"exposed", t):
			flags |= GameTypes.FLAG_EXPOSED
		if e.has_status(&"burning", t):
			flags |= GameTypes.FLAG_BURNING
		if e.has_status(&"frozen", t):
			flags |= GameTypes.FLAG_FROZEN
		if e.stagger.is_staggered(t):
			flags |= GameTypes.FLAG_STAGGERED
		if e.has_status(&"superconduct", t):
			flags |= GameTypes.FLAG_SUPERCONDUCT
		if e.is_elite():
			flags |= GameTypes.FLAG_ELITE
		if e.has_status(&"blinded", t):
			flags |= GameTypes.FLAG_BLINDED
		s.flags = flags
		out.append(s)
	return out


# --- Services for Enemy ---------------------------------------------------------------

func emit_event(ev: Array) -> void:
	arena.call("emit_event", ev)


func release_tokens(e: Enemy) -> void:
	director.release_token(e.id)


func claim_token(e: Enemy, hero_slot: int, t: int) -> bool:
	return director.request_token(e.id, hero_slot, e.def.token_kind, t)


func engagement_slot(e: Enemy, hero_slot: int, ring: int, hero_pos: Vector3) -> Vector3:
	var field := flow_fields[hero_slot]
	return director.request_slot(e.id, hero_slot, ring, hero_pos, e.global_position,
		func(p: Vector3) -> bool: return field.is_walkable(p))


func flow_direction(hero_slot: int, pos: Vector3) -> Vector3:
	return flow_fields[hero_slot].direction_at(pos)


func targetable_heroes() -> Array:
	return arena.call("targetable_heroes")


func hero_node(slot: int) -> Node3D:
	return arena.call("hero", slot)


func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), to + Vector3(0, 1.0, 0), 1)
	return space.intersect_ray(ray).is_empty()


func surface_material_at(pos: Vector3) -> int:
	return arena.call("surface_material_at", pos)


func surface_speed_at(pos: Vector3) -> float:
	var row: Dictionary = GameData.surface_materials.get(GameData.surface_name(surface_material_at(pos)), {})
	return float(row.get("speed_multiplier", 1.0))


func surface_friction_at(pos: Vector3) -> float:
	var row: Dictionary = GameData.surface_materials.get(GameData.surface_name(surface_material_at(pos)), {})
	return float(row.get("friction", 1.0))


func separation(e: Enemy) -> Vector3:
	var push := Vector3.ZERO
	var r := GameData.rule(&"separation_radius")
	for other: Enemy in entities.values():
		if other == e or other.dead or other.is_prop:
			continue
		var d := GameTypes.flat(e.global_position - other.global_position)
		var dist := d.length()
		var reach := r + other.radius() * 0.5
		if dist < reach and dist > 0.0001:
			push += d / dist * (1.0 - dist / reach)
	return push


func enemy_attack(e: Enemy, t: int) -> void:
	combat.call("enemy_attack", e, t)


func on_wall_slam(e: Enemy, speed: float, owner_slot: int, action_uid: int, t: int) -> void:
	combat.call("on_wall_slam", e, speed, owner_slot, action_uid, t)


## Enemies hitting enemies pass on 60% of the momentum, once per action per pair.
func transfer_momentum(e: Enemy, pre: Vector3, t: int) -> void:
	if pre.length() < 2.0:
		return
	for other: Enemy in entities.values():
		if other == e or other.dead:
			continue
		var d := GameTypes.flat(other.global_position - e.global_position)
		if d.length() > e.radius() + other.radius() + 0.1:
			continue
		if pre.dot(d) <= 0.0:
			continue
		if not e.mark_transfer("%d|%d" % [e.knock_action, other.id]):
			continue
		var dv := KnockbackRules.transfer(pre, e.mass, other.mass, GameData.rule(&"momentum_transfer"))
		dv = dv.limit_length(other.velocity_cap)
		other.apply_knockback(dv, e.knock_owner, e.knock_action, t)
		e.knock_velocity *= 0.4
		combat.call("on_body_collision", e, other, t)
