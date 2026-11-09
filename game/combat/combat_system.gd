class_name CombatSystem
extends Node
## Host-only. Turns fresh hero action events into hits, runs projectiles, resolves enemy attacks
## against each hero's own timeline (fair dodges for the guest), applies Resonance, stagger,
## knockback, statuses, hazards, downed and revive, and the shared Bond meter.
## Every outcome is decided here, once, and announced as a GameplayEvent.

class HitSpec:
	extends RefCounted
	var slot: int = -1
	var uid: int = 0
	var ability: AbilityDefinition
	var damage_type: StringName = &"physical"
	var base: float = 0.0
	var stagger: float = 0.0
	var impulse: float = 0.0
	var impulse_dir := Vector3.ZERO
	var primer: StringName = &""
	var finisher: StringName = &""
	var is_reaction: bool = false
	var more: Array[float] = []
	var crit_bonus: float = 0.0
	var armour_ignore: float = 0.0
	var status: StringName = &""
	var status_ticks: int = 0
	var status_magnitude: float = 0.0
	var element: StringName = &""


class ActionRun:
	extends RefCounted
	var uid: int = 0
	var slot: int = 0
	var ability: AbilityDefinition
	var rune: RuneDefinition
	var hits: Dictionary = {}
	var more: Array[float] = []
	var range_mult: float = 1.0
	var area_mult: float = 1.0
	var resource_given: bool = false
	var empowered: bool = false


var arena: Node
var entities: EntityManager
var surface: SurfaceGrid
var resolver := ReactionResolver.new()
var caps: DamageCalculator.Caps
var prd := PrdRoller.new()
var rng := RandomNumberGenerator.new()
var projectiles: Array[Projectile] = []
var bond_meter: float = 0.0
var paused: bool = false
var counters: Dictionary = {"resonances": 0, "basic_reactions": 0, "slams": 0, "hits": 0, "kills": 0, "revives": 0, "downs": 0, "projectiles": 0}

var _next_projectile: int = 1
var _hero_events: Array[Dictionary] = []
var _runs: Dictionary = {}
var _pending_hero_hits: Array[Dictionary] = []
var _contact: Dictionary = {}
var _reviving: Dictionary = {}   # reviver slot -> last tick spent reviving
var _double_tech_slot: int = -1
var _double_tech_until: int = -1
var _surface_counter: int = 0
var _bond_sent: float = -1.0
var _primer_ticks: int = 240
var _lag_ticks: int = 12
var _hero_wait_ticks: int = 12


func setup(p_arena: Node, p_entities: EntityManager, p_surface: SurfaceGrid, seed_value: int) -> void:
	arena = p_arena
	entities = p_entities
	surface = p_surface
	caps = DamageCalculator.Caps.from_rules()
	resolver.configure_from_rules()
	rng.seed = seed_value
	_primer_ticks = GameData.rule_ticks(&"primer_duration_s")
	_lag_ticks = GameData.rule_ticks(&"lag_comp_max_s")
	_hero_wait_ticks = GameData.rule_ticks(&"hero_hit_wait_s")


func on_hero_event(_hero: Hero, ev: Dictionary) -> void:
	_hero_events.append(ev)


func reset_encounter_state() -> void:
	projectiles.clear()
	_runs.clear()
	_pending_hero_hits.clear()
	_contact.clear()
	resolver = ReactionResolver.new()
	resolver.configure_from_rules()


func emit(ev: Array) -> void:
	arena.call("emit_event", ev)


func hero(slot: int) -> Hero:
	return arena.call("hero", slot) as Hero


static func action_uid(slot: int, seq: int) -> int:
	return (slot << 24) | (seq & 0xFFFFFF)


# --- Tick ---------------------------------------------------------------------------------

func tick(t: int, dt: float) -> void:
	if paused:
		_hero_events.clear()
		return
	_process_hero_events(t)
	_step_projectiles(t, dt)
	_resolve_pending_hero_hits(t)
	_tick_statuses(t)
	_tick_heroes(t, dt)
	_tick_double_tech(t)
	_surface_counter += 1
	if _surface_counter >= int(60.0 / GameData.rule(&"surface_update_hz")):
		_surface_counter = 0
		surface.update()
		_tick_hazards(t)
		_consume_surface_events(t)
	if t % 60 == 0:
		resolver.prune(t)
	if absf(bond_meter - _bond_sent) > 0.001:
		_bond_sent = bond_meter
		emit([NetProtocol.EV_BOND, snappedf(bond_meter, 0.001), -1, ""])


func _process_hero_events(t: int) -> void:
	var events := _hero_events
	_hero_events = []
	for ev: Dictionary in events:
		var slot: int = ev["hero_slot"]
		var h := hero(slot)
		if h == null:
			continue
		var type: StringName = ev["type"]
		if type == &"dodge" or type == &"blink":
			continue
		var uid := action_uid(slot, int(ev.get("seq", 0)))
		match type:
			&"start":
				_runs[uid] = _make_run(h, uid, GameData.ability(StringName(str(ev["ability"]))))
			&"active":
				var run: ActionRun = _runs.get(uid)
				if run == null:
					run = _make_run(h, uid, GameData.ability(StringName(str(ev["ability"]))))
					_runs[uid] = run
				_deliver(h, run, ev, t)
			&"end", &"cancel":
				_runs.erase(uid)


func _make_run(h: Hero, uid: int, def: AbilityDefinition) -> ActionRun:
	var run := ActionRun.new()
	run.uid = uid
	run.slot = h.slot
	run.ability = def
	run.rune = h.rune_for(def.id) if def != null else null
	if run.rune != null and run.rune.fits(def):
		if not is_equal_approx(run.rune.damage_more, 1.0):
			run.more.append(run.rune.damage_more)
		run.range_mult = run.rune.range_multiplier
		run.area_mult = run.rune.area_multiplier
	else:
		run.rune = null
	return run


func _lag_tick(ev: Dictionary, t: int) -> int:
	return clampi(int(ev.get("view_tick", t)), t - _lag_ticks, t)


func _deliver(h: Hero, run: ActionRun, ev: Dictionary, t: int) -> void:
	var def := run.ability
	if def == null:
		return
	var origin: Vector3 = ev["origin"]
	var dir: Vector3 = ev["dir"]
	var index: int = ev["index"]
	match def.delivery:
		&"melee_arc":
			_melee(h, run, origin, dir, index, _lag_tick(ev, t), t)
		&"projectile":
			if index == 0:
				_spawn_hero_projectiles(h, run, origin, dir, t)
		&"line":
			if index == 0:
				_line(h, run, origin, dir, _lag_tick(ev, t), t)
		&"charge":
			if index < def.move_ticks:
				_charge(h, run, origin, dir, _lag_tick(ev, t), t)
		&"self_area":
			if index == 0:
				barrier_heroes_near(origin, def.radius_m * sqrt(run.area_mult), def.barrier_fraction * (1.0 + h.attributes.stat(&"link_strength_inc")), def.barrier_duration_s, h.slot)
		&"flask":
			if index == 0:
				_heal(h, h.stats.max_health * GameData.rule(&"flask_heal_fraction"))


# --- Hero deliveries ---------------------------------------------------------------------

func _hit_from_ability(h: Hero, run: ActionRun, e: Enemy, push_dir: Vector3, t: int) -> float:
	var def := run.ability
	var spec := HitSpec.new()
	spec.slot = h.slot
	spec.uid = run.uid
	spec.ability = def
	spec.damage_type = def.damage_type
	spec.base = def.base_damage
	spec.stagger = def.stagger
	spec.impulse = def.impulse
	spec.impulse_dir = push_dir
	spec.primer = def.primer
	spec.finisher = def.finisher
	spec.more = run.more.duplicate()
	spec.status = def.status
	spec.status_ticks = roundi(def.status_duration_s * 60.0)
	spec.status_magnitude = def.status_magnitude
	spec.element = def.element
	if def.id == &"shove":
		spec.impulse = KnockbackRules.scaled_impulse(def.impulse, h.attributes.modifier(&"str"), GameData.rule(&"str_impulse_per_mod"))
	if def.is_finisher() and h.class_def.resource_id == &"resolve":
		if not run.empowered and h.motor.resource >= GameData.rule(&"resolve_empower_cost"):
			run.empowered = true
			h.queue_command({"type": &"resource", "delta": -GameData.rule(&"resolve_empower_cost")})
		if run.empowered:
			spec.more.append(GameData.rule(&"resolve_empower_more"))
	var dealt := hit_entity(e, spec, t)
	if dealt > 0.0 and not run.resource_given and def.resource_gain > 0.0 and h.class_def.resource_id == &"resolve":
		run.resource_given = true
		h.queue_command({"type": &"resource", "delta": def.resource_gain})
	return dealt


func _melee(h: Hero, run: ActionRun, origin: Vector3, dir: Vector3, index: int, at_tick: int, t: int) -> void:
	var def := run.ability
	var reach := def.range_m * run.range_mult * sqrt(run.area_mult)
	var half_arc := deg_to_rad(def.arc_deg * 0.5)
	for e: Enemy in entities.query_radius(origin, reach, at_tick):
		if run.hits.has(e.id):
			continue
		var d := GameTypes.flat(e.position_at(at_tick) - origin)
		var dist := d.length()
		if dist > 0.3:
			var slack := atan2(e.radius(), maxf(dist, 0.1))
			if absf(dir.angle_to(d / dist)) > half_arc + slack:
				continue
		run.hits[e.id] = true
		_hit_from_ability(h, run, e, d / dist if dist > 0.01 else dir, t)
	if index == 0 and def.surface_element != &"":
		var radius := def.surface_radius_m * sqrt(run.area_mult) * (1.0 + h.attributes.stat(&"surface_area_inc"))
		surface_apply(origin + dir * reach * 0.55, radius, def.surface_element, h.slot)


func _charge(h: Hero, run: ActionRun, origin: Vector3, dir: Vector3, at_tick: int, t: int) -> void:
	var def := run.ability
	var radius := def.radius_m * sqrt(run.area_mult)
	for e: Enemy in entities.query_radius(origin + dir * 0.4, radius, at_tick):
		if run.hits.has(e.id):
			continue
		run.hits[e.id] = true
		var side := GameTypes.flat(e.position_at(at_tick) - origin)
		var push := (dir * 0.85 + (side.normalized() if side.length() > 0.01 else Vector3.ZERO) * 0.15).normalized()
		_hit_from_ability(h, run, e, push, t)


func _line(h: Hero, run: ActionRun, origin: Vector3, dir: Vector3, at_tick: int, t: int) -> void:
	var def := run.ability
	var from := origin + Vector3(0, 1.0, 0)
	var reach := def.range_m * run.range_mult
	var to := _clip_to_walls(from, from + dir * reach)
	var length := GameTypes.flat(to - from).length()
	var candidates: Array = []
	for e: Enemy in entities.alive_entities():
		var p := GameTypes.flat(e.position_at(at_tick) - origin)
		var along := p.dot(dir)
		if along < -0.3 or along > length + e.radius():
			continue
		var off := (p - dir * along).length()
		if off <= def.radius_m + e.radius():
			candidates.append([along, e])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var max_hits := 1 + def.pierce + (run.rune.pierce_add if run.rune != null else 0)
	var last: Enemy = null
	for c: Array in candidates:
		if max_hits <= 0:
			break
		var e: Enemy = c[1]
		run.hits[e.id] = true
		_hit_from_ability(h, run, e, dir, t)
		last = e
		max_hits -= 1
	emit([NetProtocol.EV_BEAM, h.slot, from.x, from.y, from.z, to.x, to.y, to.z, NetProtocol.PV_LIGHTNING])
	if def.surface_element != &"":
		surface.apply_element_segment(origin, origin + dir * length, def.surface_radius_m, def.surface_element, h.slot)
	if run.rune != null and run.rune.chain_count > 0 and last != null:
		var chain_from := last
		for _i in run.rune.chain_count:
			var next := _nearest_unhit(chain_from.global_position, 8.0, run.hits)
			if next == null:
				break
			run.hits[next.id] = true
			var a := chain_from.global_position + Vector3(0, 1, 0)
			var b := next.global_position + Vector3(0, 1, 0)
			emit([NetProtocol.EV_BEAM, h.slot, a.x, a.y, a.z, b.x, b.y, b.z, NetProtocol.PV_LIGHTNING])
			_hit_from_ability(h, run, next, GameTypes.flat_dir(chain_from.global_position, next.global_position), t)
			chain_from = next


func _nearest_unhit(from: Vector3, max_dist: float, hits: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist
	for e: Enemy in entities.alive_enemies():
		if hits.has(e.id):
			continue
		var d := GameTypes.flat(e.global_position - from).length()
		if d < best_d:
			best_d = d
			best = e
	return best


func _clip_to_walls(from: Vector3, to: Vector3) -> Vector3:
	var node := arena as Node3D
	if node == null or not node.is_inside_tree():
		return to
	var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return to if hit.is_empty() else hit["position"]


func _projectile_visual(def: AbilityDefinition) -> int:
	match def.id:
		&"glacial_spire":
			return NetProtocol.PV_FROST
		&"ember_orb":
			return NetProtocol.PV_FIRE
		&"lance_of_dawn":
			return NetProtocol.PV_HOLY_LANCE
	return NetProtocol.PV_ARCANE


func _spawn_hero_projectiles(h: Hero, run: ActionRun, origin: Vector3, dir: Vector3, t: int) -> void:
	var def := run.ability
	var count := 1 + (run.rune.extra_projectiles if run.rune != null else 0)
	for i in count:
		var angle := 0.0 if count == 1 else deg_to_rad(-10.0 + 20.0 * i / float(count - 1))
		var p := Projectile.new()
		p.team = Projectile.TEAM_HEROES
		p.slot = h.slot
		p.uid = run.uid
		p.ability = def
		p.rune = run.rune
		p.visual = _projectile_visual(def)
		p.position = origin + Vector3(0, 1.1, 0) + dir * 0.6
		p.velocity = dir.rotated(Vector3.UP, angle) * def.projectile_speed
		p.radius = def.projectile_radius
		p.remaining = def.range_m * run.range_mult
		p.pierce_left = def.pierce + (run.rune.pierce_add if run.rune != null else 0)
		p.fork_left = run.rune.fork_count if run.rune != null else 0
		p.chain_left = run.rune.chain_count if run.rune != null else 0
		p.more = run.more.duplicate()
		_launch(p)


func _launch(p: Projectile) -> void:
	p.id = _next_projectile
	_next_projectile += 1
	projectiles.append(p)
	counters["projectiles"] = int(counters["projectiles"]) + 1
	var owner_code := 2 if p.team == Projectile.TEAM_ENEMIES else p.slot
	emit([NetProtocol.EV_PROJ_SPAWN, p.id, p.visual, owner_code, p.position.x, p.position.y, p.position.z,
		p.velocity.x, p.velocity.y, p.velocity.z, p.remaining, p.radius])


func _step_projectiles(t: int, dt: float) -> void:
	var still: Array[Projectile] = []
	var spawned: Array[Projectile] = []
	for p: Projectile in projectiles:
		if not p.alive:
			continue
		var from := p.position
		var step := p.velocity * dt
		if step.length() > p.remaining:
			step = step.normalized() * p.remaining
		var to := _clip_to_walls(from, from + step)
		var hit_wall := not to.is_equal_approx(from + step)
		var travelled := (to - from).length()
		p.remaining -= travelled
		if p.ability != null:
			_projectile_path_surface(p, from, to)
		var end_pos := to
		var ended := false
		if p.team == Projectile.TEAM_HEROES:
			for e: Enemy in _segment_hits(from, to, p.radius, p.hits):
				p.hits[e.id] = true
				var h := hero(p.slot)
				if h == null:
					continue
				var run := ActionRun.new()
				run.uid = p.uid
				run.slot = p.slot
				run.ability = p.ability
				run.more = p.more
				run.rune = p.rune
				run.resource_given = true
				_hit_from_ability(h, run, e, p.velocity.normalized(), t)
				if p.fork_left > 0:
					for sign: float in [-1.0, 1.0]:
						var f := p.copy_for_split()
						f.position = e.global_position + Vector3(0, 1.1, 0)
						f.velocity = p.velocity.rotated(Vector3.UP, deg_to_rad(25.0) * sign)
						f.remaining = maxf(p.remaining, 6.0)
						spawned.append(f)
					p.fork_left = 0
					ended = true
					end_pos = e.global_position + Vector3(0, 1.1, 0)
					break
				if p.chain_left > 0:
					var next := _nearest_unhit(e.global_position, 8.0, p.hits)
					if next != null:
						var c := p.copy_for_split()
						c.chain_left = p.chain_left - 1
						c.position = e.global_position + Vector3(0, 1.1, 0)
						c.velocity = GameTypes.flat_dir(e.global_position, next.global_position) * p.velocity.length()
						c.remaining = 9.0
						spawned.append(c)
					ended = true
					end_pos = e.global_position + Vector3(0, 1.1, 0)
					break
				if p.pierce_left > 0:
					p.pierce_left -= 1
				else:
					ended = true
					end_pos = e.global_position + Vector3(0, 1.1, 0)
					break
		else:
			for slot in GameTypes.SLOT_COUNT:
				var h := hero(slot)
				if h == null or not h.stats.is_alive():
					continue
				if _segment_point_distance(from, to, h.center()) <= p.radius + Hero.CAPSULE_RADIUS + 0.1:
					damage_hero(h, p.damage, p.damage_type, from, p.velocity.normalized() * 2.0, h.last_fresh_tick)
					ended = true
					end_pos = h.center()
					break
		p.position = end_pos if ended else to
		if ended or hit_wall or p.remaining <= 0.01:
			_end_projectile(p, t)
		else:
			still.append(p)
	for s: Projectile in spawned:
		_launch(s)
		still.append(s)
	projectiles = still


func _end_projectile(p: Projectile, t: int) -> void:
	p.alive = false
	var burst := false
	if p.team == Projectile.TEAM_HEROES and p.ability != null:
		var def := p.ability
		if def.id == &"ember_orb":
			burst = true
			var spec := HitSpec.new()
			spec.slot = p.slot
			spec.uid = p.uid ^ 0x2000000
			spec.damage_type = &"fire"
			spec.base = def.base_damage * 0.7
			spec.stagger = def.stagger
			spec.more = p.more.duplicate()
			spec.status = &"burning"
			spec.status_ticks = roundi(def.status_duration_s * 60.0)
			spec.status_magnitude = def.status_magnitude
			spec.element = &"fire"
			spec.is_reaction = false
			for e: Enemy in entities.query_radius(p.position, def.radius_m):
				if not p.hits.has(e.id):
					hit_entity(e, spec, t)
		if def.surface_element != &"":
			surface_apply(Vector3(p.position.x, 0, p.position.z), def.surface_radius_m, def.surface_element, p.slot)
	emit([NetProtocol.EV_PROJ_END, p.id, p.position.x, p.position.y, p.position.z, burst])


func _projectile_path_surface(p: Projectile, from: Vector3, to: Vector3) -> void:
	match p.ability.id:
		&"glacial_spire":
			surface.apply_element_segment(Vector3(from.x, 0, from.z), Vector3(to.x, 0, to.z), 0.6, &"cold", p.slot)
		&"ember_orb":
			surface.apply_element_segment(Vector3(from.x, 0, from.z), Vector3(to.x, 0, to.z), 0.45, &"fire", p.slot)


func _segment_hits(from: Vector3, to: Vector3, radius: float, exclude: Dictionary) -> Array[Enemy]:
	var found: Array = []
	for e: Enemy in entities.alive_entities():
		if exclude.has(e.id):
			continue
		var center := e.global_position + Vector3(0, minf(1.0, e.def.height * 0.5), 0)
		var d := _segment_point_distance(from, to, center)
		if d <= radius + e.radius():
			found.append([from.distance_squared_to(center), e])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[Enemy] = []
	for f: Array in found:
		out.append(f[1])
	return out


static func _segment_point_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var p2 := Vector2(p.x, p.z)
	var ab := b2 - a2
	var len2 := ab.length_squared()
	var u := 0.0 if len2 < 0.000001 else clampf((p2 - a2).dot(ab) / len2, 0.0, 1.0)
	return (a2 + ab * u).distance_to(p2)


# --- The hit pipeline ----------------------------------------------------------------------

## Resolve one hit against an enemy or prop. Returns the damage dealt.
func hit_entity(e: Enemy, h: HitSpec, t: int) -> float:
	if e.dead:
		return 0.0
	if e.is_prop:
		if h.base > 0.0 or h.is_reaction:
			break_prop(e, h.element, h.slot, t)
		elif h.impulse > 0.0:
			var dv := KnockbackRules.delta_v(h.impulse, e.mass, e.velocity_cap)
			e.apply_knockback(h.impulse_dir * dv, h.slot, h.uid, t)
		return 0.0
	var src := hero(h.slot) if h.slot >= 0 else null
	var was_primed := not resolver.store.live_primers(e.id, t).is_empty()
	var outcome: ReactionResolver.Outcome = null
	if h.finisher != &"" and not h.is_reaction:
		var o := resolver.resolve_finisher(e.id, h.slot, h.finisher, h.uid, t)
		if o.triggered():
			outcome = o
	var ctx := DamageCalculator.Context.new()
	if src != null:
		if h.damage_type == &"physical":
			ctx.increased[&"physical"] = src.attributes.stat(&"physical_damage_inc")
		else:
			ctx.increased[h.damage_type] = src.attributes.stat(&"spell_damage_inc")
	ctx.more = h.more
	var crit_chance := GameData.rule(&"base_crit_chance") + h.crit_bonus + ReactionEffects.crit_bonus(outcome)
	if src != null:
		crit_chance += src.attributes.stat(&"crit_chance_add")
	ctx.crit = h.base > 0.0 and prd.roll(h.slot, crit_chance, rng)
	ctx.crit_multiplier = GameData.rule(&"base_crit_multiplier")
	ctx.armour = e.def.armour
	ctx.armour_ignore = h.armour_ignore
	ctx.resistances = {&"fire": e.def.resist_fire, &"cold": e.def.resist_cold, &"lightning": e.def.resist_lightning, &"holy": e.def.resist_holy}
	if e.stagger.is_staggered(t):
		ctx.vulnerability += GameData.rule(&"staggered_vulnerability")
	ctx.elemental_vulnerability += e.status_magnitude(&"exposed", t) + e.status_magnitude(&"superconduct", t)
	if outcome != null:
		ctx.reaction_multiplier = outcome.multiplier
	var packets: Array[DamageCalculator.Packet] = [DamageCalculator.Packet.new(h.damage_type, h.base)]
	var result := DamageCalculator.compute(packets, ctx, caps)
	var dealt := result.total
	_apply_damage(e, dealt, t)
	counters["hits"] = int(counters["hits"]) + 1
	# Stagger.
	var stag := h.stagger * ReactionEffects.stagger_multiplier(outcome)
	if src != null:
		stag *= 1.0 + src.attributes.stat(&"stagger_inc")
	match e.stagger.add(stag, was_primed, t):
		StaggerState.Event.STUN:
			e.on_stun(t)
			emit([NetProtocol.EV_STAGGER, e.id, 1])
		StaggerState.Event.STAGGER:
			e.on_stagger(t)
			emit([NetProtocol.EV_STAGGER, e.id, 2])
			arena.call("chronicle_first", "first_stagger", "%s Staggered for the first time." % e.def.display_name)
	# Knockback (heavy enemies barely move; ice doubles it).
	var impulse := h.impulse + ReactionEffects.extra_impulse(outcome)
	if impulse > 0.0 and h.impulse_dir != Vector3.ZERO:
		if src != null and h.ability != null and h.ability.id != &"shove":
			impulse = KnockbackRules.scaled_impulse(impulse, src.attributes.modifier(&"str"), GameData.rule(&"str_impulse_per_mod"))
		var dv := KnockbackRules.delta_v(impulse, e.mass, e.velocity_cap)
		var ground := GameData.surface_materials.get(GameData.surface_name(surface.material_at(e.global_position)), {}) as Dictionary
		dv *= float(ground.get("knockback_multiplier", 1.0))
		e.apply_knockback(GameTypes.flat(h.impulse_dir).normalized() * dv, h.slot, h.uid, t)
	# Primer (never from reactions).
	if h.primer != &"" and not h.is_reaction and not e.dead:
		if resolver.store.apply(e.id, h.primer, h.slot, 1.0, t, _primer_ticks, h.uid):
			emit([NetProtocol.EV_PRIMER, e.id, GameTypes.primer_index(h.primer), h.slot])
		if h.primer == &"frozen":
			var base_ticks := roundi(GameData.rule(&"freeze_s") * 60.0 * (1.0 + (src.attributes.stat(&"control_duration_inc") if src != null else 0.0)))
			var ticks := e.stagger.control_duration(base_ticks, t)
			if ticks > 0:
				e.add_status(&"frozen", ticks, 1.0, h.slot, t)
			elif e.is_elite():
				e.stagger.add(StaggerState.control_to_stagger(base_ticks), true, t)
	if h.status != &"" and h.status_ticks > 0 and not e.dead:
		e.add_status(h.status, h.status_ticks, h.status_magnitude, h.slot, t)
	var kind := 0
	if outcome != null:
		kind = 1 if outcome.kind == ReactionResolver.Kind.RESONANCE else 2
	var p := e.global_position
	emit([NetProtocol.EV_HIT, e.id, snappedf(dealt, 0.1), result.crit, GameTypes.damage_type_index(h.damage_type), h.slot, p.x, p.y, p.z, kind])
	if outcome != null:
		var radius := ReactionEffects.apply(self, outcome, e, h, dealt, t)
		if outcome.kind == ReactionResolver.Kind.RESONANCE:
			counters["resonances"] = int(counters["resonances"]) + 1
			add_bond(GameData.rule(&"bond_gain_resonance"), h.slot, "resonance")
			arena.call("chronicle_first", "first_resonance", "First Resonance: %s." % outcome.name)
		else:
			counters["basic_reactions"] = int(counters["basic_reactions"]) + 1
		emit([NetProtocol.EV_REACTION, String(outcome.reaction_id), outcome.name, kind, h.slot, p.x, p.y, p.z, radius, outcome.is_signature])
	if e.health <= 0.0 and not e.def.immortal:
		_kill(e, h.slot, t)
	return dealt


func _apply_damage(e: Enemy, amount: float, t: int) -> void:
	if e.def.immortal:
		e.health = maxf(1.0, e.health - amount)
		e.statuses[&"recently_hit"] = [t + 180, 0.0, -1]
	else:
		e.health -= amount


func _kill(e: Enemy, slot: int, t: int) -> void:
	e.kill(t)
	resolver.store.clear_target(e.id)
	entities.director.forget(e.id)
	counters["kills"] = int(counters["kills"]) + 1
	var p := e.global_position
	emit([NetProtocol.EV_DEATH, e.id, p.x, p.y, p.z])
	arena.call("on_enemy_killed", e, slot)


func execute(e: Enemy, slot: int, t: int) -> void:
	_apply_damage(e, e.health + 1.0, t)
	_kill(e, slot, t)


func break_prop(e: Enemy, element: StringName, slot: int, t: int) -> void:
	if e.dead:
		return
	var p := e.global_position
	e.kill(t)
	emit([NetProtocol.EV_BREAK, e.id, e.kind, p.x, p.y, p.z])
	var flat := Vector3(p.x, 0, p.z)
	if e.kind == NetProtocol.KIND_OIL_BARREL:
		surface.paint_base_circle(flat, 1.7, SurfaceGrid.OIL)
		if element == &"fire" or element == &"holy":
			surface_apply(flat, 1.7, &"fire", slot)
	else:
		surface.paint_base_circle(flat, 1.9, SurfaceGrid.WATER)


# --- Area helpers used by reactions --------------------------------------------------------

## Reaction damage to every enemy in a circle (no primers, no further reactions). Returns those struck.
func area_hit(center: Vector3, radius: float, src: HitSpec, damage: float, damage_type: StringName, exclude_id: int, impulse: float, only: Array = []) -> Array[Enemy]:
	var struck: Array[Enemy] = []
	var targets: Array = only if not only.is_empty() else entities.query_radius(center, radius)
	for e: Enemy in targets:
		if e.id == exclude_id or e.dead:
			continue
		var spec := HitSpec.new()
		spec.slot = src.slot
		spec.uid = src.uid ^ 0x1000000
		spec.damage_type = damage_type
		spec.base = damage
		spec.stagger = damage * 0.15
		spec.impulse = impulse
		spec.impulse_dir = GameTypes.flat_dir(center, e.global_position)
		spec.is_reaction = true
		spec.element = damage_type
		hit_entity(e, spec, NetworkTime.tick)
		struck.append(e)
	return struck


func arc_lightning(origin_enemy: Enemy, count: int, radius: float, damage: float, src: HitSpec) -> void:
	var hit: Dictionary = {origin_enemy.id: true}
	var from := origin_enemy
	for _i in count:
		var next := _nearest_unhit(from.global_position, radius, hit)
		if next == null:
			break
		hit[next.id] = true
		var a := from.global_position + Vector3(0, 1.2, 0)
		var b := next.global_position + Vector3(0, 1.2, 0)
		emit([NetProtocol.EV_BEAM, src.slot, a.x, a.y, a.z, b.x, b.y, b.z, NetProtocol.PV_LIGHTNING])
		area_hit(next.global_position, 0.1, src, damage, &"lightning", -1, 0.0, [next])


func surface_apply(center: Vector3, radius: float, element: StringName, owner_slot: int) -> void:
	surface.apply_element(Vector3(center.x, 0, center.z), radius, element, owner_slot)


func consume_sanctified_near(center: Vector3, radius: float) -> bool:
	var found := false
	for i: int in surface.cells_in_circle(Vector3(center.x, 0, center.z), radius):
		if surface.material[i] == SurfaceGrid.SANCTIFIED:
			found = true
			break
	if found:
		surface.apply_element(Vector3(center.x, 0, center.z), radius, &"fire", GameTypes.OWNER_WORLD)
	return found


func barrier_heroes_near(center: Vector3, radius: float, fraction: float, duration_s: float, source_slot: int) -> void:
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h == null or not h.stats.is_alive():
			continue
		if GameTypes.flat(h.global_position - center).length() > radius:
			continue
		var amount := h.stats.max_health * fraction
		h.stats.barrier = maxf(h.stats.barrier, amount)
		h.stats.barrier_until = NetworkTime.tick + roundi(duration_s * 60.0)
		h.stats.dirty = true
		emit([NetProtocol.EV_BARRIER, slot, snappedf(amount, 0.1)])
		if slot != source_slot:
			add_bond(GameData.rule(&"bond_gain_protect"), source_slot, "protect")


func heal_heroes_near(center: Vector3, radius: float, fraction: float) -> void:
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h != null and h.stats.is_alive() and GameTypes.flat(h.global_position - center).length() <= radius:
			_heal(h, h.stats.max_health * fraction)


func _heal(h: Hero, amount: float) -> void:
	if not h.stats.is_alive():
		return
	var before := h.stats.health
	h.stats.health = minf(h.stats.max_health, h.stats.health + amount)
	h.stats.dirty = true
	if h.stats.health - before > 0.5:
		emit([NetProtocol.EV_HEAL, h.slot, snappedf(h.stats.health - before, 0.1)])


func add_bond(amount: float, slot: int, reason: String) -> void:
	bond_meter = clampf(bond_meter + amount, 0.0, 1.0)


# --- Physics callbacks -----------------------------------------------------------------------

func on_wall_slam(e: Enemy, speed: float, owner_slot: int, action: int, t: int) -> void:
	if e.is_prop:
		break_prop(e, &"", owner_slot, t)
		return
	counters["slams"] = int(counters["slams"]) + 1
	var spec := HitSpec.new()
	spec.slot = owner_slot
	spec.uid = action ^ 0x4000000
	spec.damage_type = &"physical"
	spec.base = KnockbackRules.slam_damage(speed, e.mass, GameData.rule(&"wall_slam_damage_factor"))
	spec.stagger = speed * e.mass * 1.5
	spec.primer = &"dazed"
	var p := e.global_position
	emit([NetProtocol.EV_SLAM, e.id, snappedf(speed, 0.1), p.x, p.y, p.z])
	arena.call("chronicle_first", "first_slam", "%s was slammed into a wall at %.1f m/s." % [e.def.display_name, speed])
	hit_entity(e, spec, t)


func on_body_collision(_a: Enemy, b: Enemy, t: int) -> void:
	if b.is_prop:
		break_prop(b, &"", _a.knock_owner, t)


# --- Enemy attacks against heroes ------------------------------------------------------------

func enemy_attack(e: Enemy, t: int) -> void:
	match e.def.attack_kind:
		&"arrow":
			var p := Projectile.new()
			p.team = Projectile.TEAM_ENEMIES
			p.visual = NetProtocol.PV_ARROW
			p.position = e.global_position + Vector3(0, 1.2, 0) + e.attack_dir * 0.5
			p.velocity = e.attack_dir * e.def.projectile_speed
			p.radius = e.def.attack_radius
			p.remaining = e.def.attack_range + 2.0
			p.damage = e.def.attack_damage
			p.damage_type = e.def.attack_damage_type
			p.source_entity = e.id
			_launch(p)
		_:
			_pending_hero_hits.append({"due": t, "deadline": t + _hero_wait_ticks, "entity": e.id,
				"kind": e.def.attack_kind, "center": e.attack_point, "origin": e.global_position, "dir": e.attack_dir,
				"radius": e.def.attack_radius, "arc": e.def.attack_arc_deg, "damage": e.def.attack_damage,
				"type": e.def.attack_damage_type, "impulse": e.def.attack_impulse, "done": {}})


## Enemy hits resolve on the target hero's own timeline: the guest's dodge at that tick counts.
func _resolve_pending_hero_hits(t: int) -> void:
	var remaining: Array[Dictionary] = []
	for hit: Dictionary in _pending_hero_hits:
		var done: Dictionary = hit["done"]
		var due: int = hit["due"]
		var all_done := true
		for slot in GameTypes.SLOT_COUNT:
			if done.has(slot):
				continue
			var h := hero(slot)
			if h == null or not h.stats.is_alive():
				done[slot] = true
				continue
			var sample: Variant = h.timeline_at(due)
			var pos: Vector3
			var invulnerable: bool
			if sample != null:
				pos = (sample as Array)[0]
				invulnerable = (sample as Array)[1]
			elif t >= int(hit["deadline"]) or h.is_local_player():
				pos = h.global_position
				invulnerable = h.motor.is_invulnerable(h.last_fresh_tick)
			else:
				all_done = false
				continue
			done[slot] = true
			if _in_attack_shape(hit, pos):
				var src: Vector3 = hit["origin"]
				var push := GameTypes.flat_dir(src, pos) * float(hit["impulse"]) / 3.0
				if invulnerable:
					emit([NetProtocol.EV_HERO_HIT, slot, 0.0, pos.x, pos.y, pos.z, true])
				else:
					damage_hero(h, float(hit["damage"]), StringName(str(hit["type"])), src, push, due)
		if not all_done:
			remaining.append(hit)
	_pending_hero_hits = remaining


func _in_attack_shape(hit: Dictionary, pos: Vector3) -> bool:
	var reach: float = float(hit["radius"]) + Hero.CAPSULE_RADIUS
	match StringName(str(hit["kind"])):
		&"slam":
			return GameTypes.flat(pos - (hit["center"] as Vector3)).length() <= reach
		_:
			var origin: Vector3 = hit["origin"]
			var d := GameTypes.flat(pos - origin)
			if d.length() > reach:
				return false
			if d.length() < 0.4:
				return true
			return absf((hit["dir"] as Vector3).angle_to(d.normalized())) <= deg_to_rad(float(hit["arc"]) * 0.5) + 0.15


## Damage a hero. Applies dodges, protection, assists, armour, Oathbond redirection and barriers.
func damage_hero(h: Hero, amount: float, damage_type: StringName, source_pos: Vector3, push: Vector3, at_tick: int, redirected: bool = false) -> void:
	if not h.stats.is_alive() or amount <= 0.0:
		return
	var t := NetworkTime.tick
	if h.stats.protected_until > t or (not redirected and h.motor.is_invulnerable(at_tick)):
		var p := h.global_position
		emit([NetProtocol.EV_HERO_HIT, h.slot, 0.0, p.x, p.y, p.z, true])
		return
	if bool(h.assists.get("damage_taken", false)):
		amount *= GameData.rule(&"damage_assist_multiplier")
	if t - int(_reviving.get(h.slot, -100)) <= 1:
		amount *= GameData.rule(&"revive_damage_taken_multiplier")
	var ctx := DamageCalculator.Context.new()
	ctx.armour = h.class_def.armour
	var packets: Array[DamageCalculator.Packet] = [DamageCalculator.Packet.new(damage_type, amount)]
	var dealt := DamageCalculator.compute(packets, ctx, caps).total
	if not redirected:
		var partner := hero(GameTypes.partner_of(h.slot))
		if partner != null and partner.stats.is_alive() and partner.class_def.id == &"vanguard" \
				and GameTypes.flat(partner.global_position - h.global_position).length() <= GameData.rule(&"oathbond_range_m"):
			var share := minf(GameData.rule(&"oathbond_share") + partner.attributes.stat(&"oathbond_share_add"), GameData.rule(&"oathbond_share_cap"))
			if share > 0.0:
				damage_hero(partner, amount * share, damage_type, source_pos, Vector3.ZERO, t, true)
				dealt *= 1.0 - share
				add_bond(GameData.rule(&"bond_gain_protect") * 0.25, partner.slot, "oathbond")
	if h.stats.barrier > 0.0:
		var absorbed := minf(h.stats.barrier, dealt)
		h.stats.barrier -= absorbed
		dealt -= absorbed
	h.stats.health -= dealt
	h.stats.dirty = true
	var pos := h.global_position
	emit([NetProtocol.EV_HERO_HIT, h.slot, snappedf(dealt, 0.1), pos.x, pos.y, pos.z, false])
	if push.length() > 0.1:
		h.queue_command({"type": &"knockback", "velocity": GameTypes.flat(push)})
	if h.stats.health <= 0.0:
		_down(h, t)


func _down(h: Hero, t: int) -> void:
	h.stats.health = 0.0
	h.stats.barrier = 0.0
	h.stats.life = NetProtocol.LIFE_DOWNED
	var seconds := GameData.rule(&"downed_crawl_s") + GameData.rule(&"downed_per_con_s") * maxi(0, h.attributes.modifier(&"con"))
	h.stats.downed_until = t + roundi(seconds * 60.0)
	h.stats.revive_progress = 0.0
	h.stats.dirty = true
	h.queue_command({"type": &"downed", "value": true})
	counters["downs"] = int(counters["downs"]) + 1


# --- Per-tick upkeep ---------------------------------------------------------------------------

func _tick_statuses(t: int) -> void:
	var dot_tick := t % 30 == 0
	for e: Enemy in entities.alive_entities():
		if e.def.immortal and not e.has_status(&"recently_hit", t) and e.health < e.def.max_health:
			e.health = e.def.max_health
		if dot_tick and e.has_status(&"burning", t):
			var info: Array = e.statuses[&"burning"]
			var dmg := float(info[1]) * 0.5 * (1.0 - minf(e.def.resist_fire, 0.75))
			_dot(e, dmg, &"fire", int(info[2]), t)


func _dot(e: Enemy, amount: float, damage_type: StringName, slot: int, t: int) -> void:
	if amount <= 0.0 or e.dead:
		return
	_apply_damage(e, amount, t)
	var p := e.global_position
	emit([NetProtocol.EV_HIT, e.id, snappedf(amount, 0.1), false, GameTypes.damage_type_index(damage_type), slot, p.x, p.y, p.z, 0])
	if e.health <= 0.0 and not e.def.immortal:
		_kill(e, slot, t)


func _tick_heroes(t: int, dt: float) -> void:
	var revive_ticks := GameData.rule(&"revive_hold_s") * 60.0
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h == null:
			continue
		var s := h.stats
		if s.barrier > 0.0 and t >= s.barrier_until:
			s.barrier = 0.0
			s.dirty = true
		if s.life == NetProtocol.LIFE_DOWNED:
			if t >= s.downed_until:
				s.life = NetProtocol.LIFE_FALLEN
				s.revive_progress = 0.0
				s.dirty = true
				continue
			var partner := hero(GameTypes.partner_of(slot))
			var helping := partner != null and partner.stats.is_alive() \
				and (partner.input.held & GameTypes.BTN_INTERACT) != 0 \
				and GameTypes.flat(partner.global_position - h.global_position).length() <= GameData.rule(&"revive_range_m")
			if helping:
				_reviving[partner.slot] = t
				s.revive_progress = minf(1.0, s.revive_progress + 1.0 / revive_ticks)
				s.reviver_slot = partner.slot
				s.dirty = true
				if s.revive_progress >= 1.0:
					_revive(h, partner, t)
			elif s.revive_progress > 0.0:
				s.revive_progress = maxf(0.0, s.revive_progress - 0.5 / revive_ticks)
				s.dirty = true


func _revive(h: Hero, by: Hero, t: int) -> void:
	h.stats.life = NetProtocol.LIFE_ALIVE
	h.stats.health = h.stats.max_health * GameData.rule(&"revived_health_fraction")
	h.stats.revive_progress = 0.0
	h.stats.protected_until = t + GameData.rule_ticks(&"revived_protection_s")
	h.stats.dirty = true
	h.queue_command({"type": &"downed", "value": false})
	h.queue_command({"type": &"protect", "until": h.stats.protected_until})
	counters["revives"] = int(counters["revives"]) + 1
	add_bond(GameData.rule(&"bond_gain_revive"), by.slot, "revive")
	arena.call("chronicle_add", "rescue", "%s brought %s back to their feet." % [by.hero_name, h.hero_name])


## Revive everyone at once (wave cleared, encounter restart). Fallen heroes stand up too.
func restore_heroes(full: bool) -> void:
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h == null:
			continue
		if not h.stats.is_alive():
			h.stats.life = NetProtocol.LIFE_ALIVE
			h.stats.health = h.stats.max_health * (1.0 if full else GameData.rule(&"revived_health_fraction"))
			h.queue_command({"type": &"downed", "value": false})
		elif full:
			h.stats.health = h.stats.max_health
		h.stats.revive_progress = 0.0
		h.stats.dirty = true


func all_heroes_down() -> bool:
	var any := false
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h == null:
			continue
		any = true
		if h.stats.is_alive():
			return false
	return any


func _tick_double_tech(t: int) -> void:
	if bond_meter < 1.0:
		_double_tech_slot = -1
		return
	var solo := hero(1) == null
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h == null or not h.stats.is_alive() or (h.input.held & GameTypes.BTN_BOND) == 0:
			continue
		if _double_tech_slot < 0 or t > _double_tech_until:
			_double_tech_slot = slot
			_double_tech_until = t + 180
			emit([NetProtocol.EV_DOUBLE_TECH, 1, slot])
			if solo:
				_fire_hearthflare(t)
		elif _double_tech_slot != slot:
			_fire_hearthflare(t)
	if _double_tech_slot >= 0 and t > _double_tech_until:
		emit([NetProtocol.EV_DOUBLE_TECH, 3, _double_tech_slot])
		_double_tech_slot = -1


## Hearthflare: the shared Double Tech used until a pairing's bespoke one exists.
func _fire_hearthflare(t: int) -> void:
	bond_meter = 0.0
	_double_tech_slot = -1
	emit([NetProtocol.EV_DOUBLE_TECH, 2, -1])
	var points: Array[Vector3] = []
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h != null and h.stats.is_alive():
			points.append(h.global_position)
			h.stats.barrier = maxf(h.stats.barrier, h.stats.max_health * 0.15)
			h.stats.barrier_until = t + 360
			h.stats.dirty = true
	if points.is_empty():
		return
	var spec := HitSpec.new()
	spec.slot = -1
	spec.uid = 0x7000000 + t
	spec.is_reaction = true
	var struck: Dictionary = {}
	for e: Enemy in entities.alive_enemies():
		var near := false
		for p: Vector3 in points:
			near = near or GameTypes.flat(e.global_position - p).length() <= 3.5
		if points.size() == 2:
			near = near or _segment_point_distance(points[0], points[1], e.global_position) <= 2.5
		if near and not struck.has(e.id):
			struck[e.id] = true
			var hs := HitSpec.new()
			hs.slot = GameTypes.SLOT_HOST
			hs.uid = spec.uid
			hs.damage_type = &"holy"
			hs.base = 60.0
			hs.stagger = 40.0
			hs.is_reaction = true
			hit_entity(e, hs, t)


# --- Surfaces and hazards -------------------------------------------------------------------

func _tick_hazards(t: int) -> void:
	var step := int(60.0 / GameData.rule(&"surface_update_hz"))
	var delay := GameData.rule_ticks(&"hazard_contact_delay_s")
	var period := GameData.rule_ticks(&"hazard_tick_s")
	for e: Enemy in entities.alive_enemies():
		var p := e.global_position
		var mat := surface.material_at(p)
		var flags := surface.flags_at(p)
		var owner_id := surface.owner_at(p)
		if surface.cloud_at(p) == SurfaceGrid.CLOUD_STEAM:
			e.add_status(&"blinded", 30, 1.0, owner_id, t)
		var hazards: Dictionary = {}
		if mat == SurfaceGrid.BURNING and owner_id != GameTypes.OWNER_ENEMY:
			hazards[&"fire"] = float((GameData.surface_materials[&"burning"] as Dictionary)["hazard_dps"])
		if mat == SurfaceGrid.WATER and flags & SurfaceGrid.FLAG_ELECTRIFIED != 0 and owner_id != GameTypes.OWNER_ENEMY:
			hazards[&"lightning"] = 10.0
		if mat == SurfaceGrid.SANCTIFIED and e.def.undead:
			hazards[&"holy"] = float((GameData.surface_materials[&"sanctified"] as Dictionary)["undead_dps"])
		_apply_hazards("e%d" % e.id, hazards, step, delay, period, func(kind: StringName, dps: float) -> void:
			_dot(e, dps * period / 60.0 * (1.0 - minf(e.def.resist(kind), 0.75)), kind, owner_id if owner_id < 2 else -1, t))
	for slot in GameTypes.SLOT_COUNT:
		var h := hero(slot)
		if h == null or not h.stats.is_alive():
			continue
		var p := h.global_position
		var mat := surface.material_at(p)
		var owner_id := surface.owner_at(p)
		if mat == SurfaceGrid.SANCTIFIED:
			_heal(h, h.stats.max_health * float((GameData.surface_materials[&"sanctified"] as Dictionary)["hero_regen_fraction"]) * step / 60.0)
		var hazards: Dictionary = {}
		var player_made := owner_id == GameTypes.SLOT_HOST or owner_id == GameTypes.SLOT_GUEST
		if mat == SurfaceGrid.BURNING and not player_made:
			hazards[&"fire"] = 14.0
		_apply_hazards("h%d" % slot, hazards, step, delay, period, func(kind: StringName, dps: float) -> void:
			damage_hero(h, dps * period / 60.0, kind, p, Vector3.ZERO, h.last_fresh_tick))


## Hazards tick per actor and hazard type after a contact delay; crossing more cells never multiplies them.
func _apply_hazards(actor_key: String, hazards: Dictionary, step: int, delay: int, period: int, deal: Callable) -> void:
	for kind: StringName in [&"fire", &"lightning", &"holy"]:
		var key := "%s|%s" % [actor_key, kind]
		if not hazards.has(kind):
			_contact.erase(key)
			continue
		var before: int = int(_contact.get(key, 0))
		var after := before + step
		_contact[key] = after
		if after >= delay and (before < delay or (after - delay) / period > (before - delay) / period):
			deal.call(kind, float(hazards[kind]))


func _consume_surface_events(t: int) -> void:
	for ev: Dictionary in surface.events:
		var type: StringName = ev["type"]
		var p: Vector3 = ev["position"]
		emit([NetProtocol.EV_SURFACE_FX, String(type), p.x, p.y, p.z, int(ev["count"]), String(ev.get("element", ""))])
		if type == &"explode":
			var owner_slot: int = int(ev["owner"])
			var spec := HitSpec.new()
			spec.slot = owner_slot if owner_slot < 2 else -1
			spec.uid = 0x6000000 + t
			spec.damage_type = &"fire"
			spec.base = 28.0
			spec.stagger = 18.0
			spec.impulse = 10.0
			spec.is_reaction = true
			spec.element = &"fire"
			for e: Enemy in entities.query_radius(p, 2.6):
				spec.impulse_dir = GameTypes.flat_dir(p, e.global_position)
				hit_entity(e, spec, t)
		elif type == &"shatter":
			for e: Enemy in entities.query_radius(p, 2.0, -1, false):
				e.add_status(&"brittle", 180, 0.2, int(ev["owner"]), t)
	surface.events.clear()
