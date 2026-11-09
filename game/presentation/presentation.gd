class_name Presentation
extends Node3D
## Everything both PCs show: entity visuals, projectiles, telegraphs, damage numbers, reactions,
## surface effects, pings and hit feel. It consumes the same GameplayEvents on both PCs, so the
## picture can differ in timing but never in results. Partner effects render at 60% opacity.

const TELEGRAPH_SHADER := preload("res://game/presentation/shaders/telegraph.gdshader")

var arena: Node
var local_slot: int = 0
var colors: Array[Color] = [ProcMesh.GOLD, ProcMesh.VIOLET]
var sfx: Sfx
var camera_rig: CameraRig
var hero_visuals: Dictionary = {}     # slot -> HeroVisual
var enemies: Dictionary = {}          # id -> EnemyVisual
var _projectiles: Dictionary = {}     # id -> [node, velocity, remaining]
var _telegraphs: Dictionary = {}      # entity id -> [node, start_msec, duration_msec]
var _fx: Array = []                   # [node, end_msec, kind, data]
var _numbers: Array[Label3D] = []
var _number_next: int = 0
var _predicted_contact: Dictionary = {}
var headless: bool = false
var partner_opacity: float = 0.6
var show_numbers: bool = true


func setup(p_arena: Node, p_local_slot: int, p_colors: Array[Color], p_camera: CameraRig) -> void:
	arena = p_arena
	local_slot = p_local_slot
	colors = p_colors
	camera_rig = p_camera
	headless = Settings.is_headless()
	partner_opacity = GameData.rule(&"partner_effect_opacity")
	show_numbers = bool(Settings.option("damage_numbers", true))
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	for i in 48:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 10
		l.font_size = 48
		l.pixel_size = 0.006
		l.visible = false
		l.render_priority = 20
		add_child(l)
		_numbers.append(l)


func add_hero(hero: Hero) -> HeroVisual:
	var v := HeroVisual.new()
	v.name = "HeroVisual%d" % hero.slot
	add_child(v)
	v.setup(hero)
	hero_visuals[hero.slot] = v
	hero.action_event.connect(_on_hero_action)
	return v


func slot_color(slot: int, alpha: float = 1.0) -> Color:
	var c := colors[slot] if slot >= 0 and slot < 2 else Color(1, 0.95, 0.85)
	c.a = alpha * (1.0 if slot == local_slot or slot < 0 else partner_opacity)
	return c


# --- Entities -------------------------------------------------------------------------------

func update_entities(states: Array[CrowdCodec.Entity], delta: float) -> void:
	var seen: Dictionary = {}
	for s: CrowdCodec.Entity in states:
		seen[s.id] = true
		var v: EnemyVisual = enemies.get(s.id)
		if v != null and (v.kind != s.kind or (v.state != null and v.state.generation != s.generation)):
			v.queue_free()
			_end_telegraph(s.id)
			_predicted_contact.erase(s.id)
			v = null
		if v == null:
			v = EnemyVisual.new()
			v.name = "Entity%d" % s.id
			add_child(v)
			v.setup(s.id, s.kind, local_slot, colors)
			v.ready_changed = _on_detonate_ready
			v.global_position = s.position
			enemies[s.id] = v
		v.apply_state(s, delta)
	for id: int in enemies.keys():
		if not seen.has(id):
			(enemies[id] as EnemyVisual).queue_free()
			enemies.erase(id)
			_end_telegraph(id)
			_predicted_contact.erase(id)


func enemy_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: EnemyVisual in enemies.values():
		if v.state != null and v.state.anim != GameTypes.Anim.DEAD and v.kind < NetProtocol.KIND_OIL_BARREL and v.def.attack_kind != &"none":
			out.append(v.global_position)
	return out


func _on_detonate_ready(v: EnemyVisual) -> void:
	sfx.play(&"ready", v.global_position, -6.0)


# --- Local action presentation (predicted on the owner's PC) ------------------------------

func _on_hero_action(hero: Hero, ev: Dictionary) -> void:
	var type: StringName = ev["type"]
	var hv: HeroVisual = hero_visuals.get(hero.slot)
	var pos: Vector3 = ev["origin"]
	match type:
		&"start":
			sfx.play(&"cast", pos, -10.0)
		&"dodge":
			sfx.play(&"whoosh", pos, -6.0)
			_burst(pos + Vector3(0, 0.3, 0), Color(0.8, 0.8, 0.85, 0.5), 8, 0.25, 2.0)
		&"blink":
			_burst((ev["from"] as Vector3) + Vector3(0, 1, 0), slot_color(hero.slot, 0.9), 16, 0.4, 3.0)
			_burst((ev["to"] as Vector3) + Vector3(0, 1, 0), slot_color(hero.slot, 0.9), 16, 0.4, 3.0)
			sfx.play(&"hit_arcane", ev["to"], -4.0)
		&"active":
			var def := GameData.ability(StringName(str(ev["ability"])))
			if def == null:
				return
			var dir: Vector3 = ev["dir"]
			if def.delivery == &"melee_arc" and int(ev["index"]) == 0:
				_slash(pos, dir, def.range_m, def.arc_deg, slot_color(hero.slot, 0.85))
				if hero.is_local_player():
					_predict_contacts(pos, dir, def.range_m, def.arc_deg)
			elif def.delivery == &"charge" and int(ev["index"]) % 3 == 0:
				_burst(pos + Vector3(0, 0.2, 0), Color(0.75, 0.7, 0.6, 0.6), 4, 0.3, 1.5)
				if hero.is_local_player():
					_predict_contacts(pos, dir, def.radius_m + 0.6, 360.0)
			elif def.delivery == &"self_area" and int(ev["index"]) == 0:
				_ring(pos + Vector3(0, 0.1, 0), def.radius_m, slot_color(hero.slot, 0.8), 0.5)
			elif def.delivery == &"flask" and int(ev["index"]) == 0:
				_burst(pos + Vector3(0, 1.2, 0), Color(0.4, 1.0, 0.5, 0.8), 12, 0.5, 1.5)
	if hv != null and type == &"active" and int(ev.get("index", 1)) == 0:
		hv.hit_stop(0)


## Predicted contact: the owner feels the hit at once (flash, hit-stop, sound); numbers wait for the host.
func _predict_contacts(origin: Vector3, dir: Vector3, reach: float, arc_deg: float) -> void:
	var now := Time.get_ticks_msec()
	for v: EnemyVisual in enemies.values():
		if v.state == null or v.state.anim == GameTypes.Anim.DEAD or v.kind >= NetProtocol.KIND_OIL_BARREL:
			continue
		var d := GameTypes.flat(v.global_position - origin)
		if d.length() > reach + v.def.radius:
			continue
		if arc_deg < 360.0 and d.length() > 0.3 and absf(dir.angle_to(d.normalized())) > deg_to_rad(arc_deg * 0.5) + 0.3:
			continue
		if int(_predicted_contact.get(v.entity_id, 0)) > now - 120:
			continue
		_predicted_contact[v.entity_id] = now
		v.flash()
		v.hit_stop(55)
		sfx.play(&"hit_physical", v.global_position, -2.0)
		if camera_rig != null:
			camera_rig.add_trauma(0.12)


# --- Gameplay events ------------------------------------------------------------------------

func handle_event(ev: Array) -> void:
	var type: int = ev[0]
	match type:
		NetProtocol.EV_HIT:
			_on_hit(ev)
		NetProtocol.EV_REACTION:
			var slot: int = ev[4]
			var p := Vector3(ev[5], ev[6], ev[7])
			var c := slot_color(slot)
			var signature: bool = ev[9]
			_popup(p + Vector3(0, 2.6, 0), str(ev[2]).to_upper() if signature else str(ev[2]), c, 1.6 if signature else 1.1, 1.2)
			_ring(p + Vector3(0, 0.15, 0), maxf(1.5, float(ev[8])), c, 0.45)
			_burst(p + Vector3(0, 1.0, 0), c, 28 if int(ev[3]) == 1 else 12, 0.6, 6.0)
			sfx.play(&"resonance" if int(ev[3]) == 1 else &"hit_arcane", p, 0.0)
			if camera_rig != null:
				camera_rig.add_trauma(0.45 if int(ev[3]) == 1 else 0.2)
			_hitstop_near(p, 6.0, 80)
		NetProtocol.EV_PRIMER:
			var v: EnemyVisual = enemies.get(int(ev[1]))
			if v != null:
				_burst(v.global_position + Vector3(0, 1.4, 0), slot_color(int(ev[3]), 0.8), 6, 0.3, 1.0)
		NetProtocol.EV_DEATH:
			var p := Vector3(ev[2], ev[3], ev[4])
			_burst(p + Vector3(0, 0.8, 0), Color(0.3, 0.55, 0.5, 0.8), 18, 0.7, 3.0)
			sfx.play(&"splash", p, -4.0)
			_end_telegraph(int(ev[1]))
		NetProtocol.EV_TELEGRAPH:
			_begin_telegraph(ev)
		NetProtocol.EV_TELEGRAPH_END:
			_end_telegraph(int(ev[1]))
		NetProtocol.EV_PROJ_SPAWN:
			_spawn_projectile(ev)
		NetProtocol.EV_PROJ_END:
			_end_projectile(ev)
		NetProtocol.EV_HERO_HIT:
			var slot: int = ev[1]
			var p := Vector3(ev[3], ev[4], ev[5]) + Vector3(0, 2.0, 0)
			if bool(ev[6]):
				_popup(p, "Dodged", Color(0.85, 0.9, 1.0), 0.8, 0.6)
			else:
				_number(p, "%d" % roundi(float(ev[2])), Color(1.0, 0.3, 0.25), 1.0)
				var hv: HeroVisual = hero_visuals.get(slot)
				if hv != null:
					hv.flash()
					hv.hit_stop(45)
				sfx.play(&"hurt", p, -3.0)
				if slot == local_slot and camera_rig != null:
					camera_rig.add_trauma(0.35)
		NetProtocol.EV_SURFACE_FX:
			_surface_fx(ev)
		NetProtocol.EV_SLAM:
			var p := Vector3(ev[3], ev[4], ev[5])
			_popup(p + Vector3(0, 2.2, 0), "SLAM %.0f m/s" % float(ev[2]), Color(1.0, 0.85, 0.5), 1.0, 0.9)
			_burst(p + Vector3(0, 0.8, 0), Color(0.8, 0.75, 0.65, 0.9), 22, 0.5, 5.0)
			sfx.play(&"slam", p, 2.0)
			if camera_rig != null:
				camera_rig.add_trauma(0.4)
			var v: EnemyVisual = enemies.get(int(ev[1]))
			if v != null:
				v.hit_stop(80)
		NetProtocol.EV_STAGGER:
			var v: EnemyVisual = enemies.get(int(ev[1]))
			if v != null:
				var big := int(ev[2]) == 2
				_popup(v.global_position + Vector3(0, 2.8, 0), "STAGGERED!" if big else "Stunned", Color(1.0, 0.85, 0.3), 1.4 if big else 0.8, 1.2)
				if big:
					sfx.play(&"horn", v.global_position, -2.0)
		NetProtocol.EV_PING:
			var p := Vector3(ev[2], ev[3], ev[4])
			_ring(p + Vector3(0, 0.1, 0), 1.2, slot_color(int(ev[1])), 3.0)
			_popup(p + Vector3(0, 1.4, 0), "!", slot_color(int(ev[1])), 1.6, 3.0)
			sfx.play(&"ready", p, -2.0)
		NetProtocol.EV_BARRIER:
			var hv: HeroVisual = hero_visuals.get(int(ev[1]))
			if hv != null:
				_number(hv.global_position + Vector3(0, 2.2, 0), "+%d barrier" % roundi(float(ev[2])), Color(1.0, 0.9, 0.55), 0.8)
		NetProtocol.EV_HEAL:
			var hv: HeroVisual = hero_visuals.get(int(ev[1]))
			if hv != null:
				_number(hv.global_position + Vector3(0, 2.2, 0), "+%d" % roundi(float(ev[2])), Color(0.45, 1.0, 0.5), 0.8)
		NetProtocol.EV_BEAM:
			var a := Vector3(ev[2], ev[3], ev[4])
			var b := Vector3(ev[5], ev[6], ev[7])
			_beam(a, b, slot_color(int(ev[1])).lerp(Color(0.6, 0.7, 1.0), 0.5))
			sfx.play(&"hit_lightning", b, -4.0)
		NetProtocol.EV_DOUBLE_TECH:
			if int(ev[1]) == 2:
				for hv: HeroVisual in hero_visuals.values():
					_ring(hv.global_position + Vector3(0, 0.1, 0), 3.5, Color(1.0, 0.8, 0.45), 0.8)
					_burst(hv.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.75, 0.4), 40, 0.8, 7.0)
				sfx.play(&"resonance", null, 2.0, 0.8)
				if camera_rig != null:
					camera_rig.add_trauma(0.6)
		NetProtocol.EV_SPAWN:
			var p := Vector3(ev[3], ev[4], ev[5])
			_burst(p + Vector3(0, 0.3, 0), Color(0.2, 0.35, 0.4, 0.8), 14, 0.6, 2.0)
			sfx.play(&"splash", p, -6.0)
		NetProtocol.EV_BREAK:
			var p := Vector3(ev[3], ev[4], ev[5])
			var oil := int(ev[2]) == NetProtocol.KIND_OIL_BARREL
			_burst(p + Vector3(0, 0.6, 0), Color(0.15, 0.1, 0.05) if oil else Color(0.4, 0.6, 0.8), 20, 0.5, 3.5)
			sfx.play(&"splash", p, 0.0)


func _on_hit(ev: Array) -> void:
	var id: int = ev[1]
	var amount: float = ev[2]
	var crit: bool = ev[3]
	var damage_type := GameTypes.damage_type_at(int(ev[4]))
	var slot: int = ev[5]
	var p := Vector3(ev[6], ev[7], ev[8])
	var reaction_kind: int = ev[9]
	var v: EnemyVisual = enemies.get(id)
	var predicted := int(_predicted_contact.get(id, 0)) > Time.get_ticks_msec() - 400
	if v != null and not predicted:
		v.flash()
		v.hit_stop(clampi(40 + roundi(amount * 0.6), 40, 80))
		sfx.play(sfx.hit_sound(damage_type), p, -4.0 if amount < 15.0 else 0.0)
	var hv: HeroVisual = hero_visuals.get(slot)
	if hv != null and amount > 12.0:
		hv.hit_stop(clampi(40 + roundi(amount * 0.4), 40, 80))
	if show_numbers and amount >= 0.5:
		var col := ProcMesh.element_color(damage_type)
		if reaction_kind == 1:
			col = colors[slot] if slot >= 0 else col
		var size := 1.0 + (0.45 if crit else 0.0) + (0.35 if reaction_kind == 1 else 0.0)
		_number(p + Vector3(randf_range(-0.3, 0.3), 2.0, 0), ("%d!" if crit else "%d") % maxi(1, roundi(amount)), col, size)
	if slot == local_slot and camera_rig != null:
		camera_rig.add_trauma(0.06 + minf(0.2, amount * 0.004))


func _surface_fx(ev: Array) -> void:
	var kind := StringName(str(ev[1]))
	var p := Vector3(ev[2], 0.2, ev[4])
	match kind:
		&"explode":
			_burst(p + Vector3(0, 0.6, 0), Color(1.0, 0.55, 0.15), 40, 0.8, 7.0)
			_ring(p, 2.6, Color(1.0, 0.5, 0.15, 0.9), 0.45)
			sfx.play(&"explode", p, 3.0)
			if camera_rig != null:
				camera_rig.add_trauma(0.5)
		&"steam":
			_burst(p + Vector3(0, 0.5, 0), Color(0.9, 0.92, 0.95, 0.5), 24, 1.2, 1.6)
			sfx.play(&"whoosh", p, -2.0, 0.7)
		&"freeze":
			_burst(p + Vector3(0, 0.3, 0), Color(0.7, 0.9, 1.0, 0.8), 14, 0.5, 2.0)
			sfx.play(&"hit_cold", p, -4.0)
		&"electrify":
			_burst(p + Vector3(0, 0.3, 0), Color(0.6, 0.7, 1.0, 0.9), 18, 0.4, 3.0)
			sfx.play(&"hit_lightning", p, -2.0)
		&"shatter":
			_burst(p + Vector3(0, 0.4, 0), Color(0.8, 0.95, 1.0), 26, 0.6, 5.0)
			sfx.play(&"shatter", p, 0.0)
		&"ignite", &"scorch":
			_burst(p + Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.2, 0.9), 12, 0.5, 2.0)
			sfx.play(&"hit_fire", p, -4.0)
		&"consecrate", &"bless":
			_ring(p, 1.5, Color(1.0, 0.85, 0.4, 0.8), 0.5)


# --- Projectiles and telegraphs -------------------------------------------------------------

func _spawn_projectile(ev: Array) -> void:
	var id: int = ev[1]
	var visual: int = ev[2]
	var owner_code: int = ev[3]   # hero slot, or 2 for enemy projectiles
	var pos := Vector3(ev[4], ev[5], ev[6])
	var vel := Vector3(ev[7], ev[8], ev[9])
	var node := Node3D.new()
	add_child(node)
	node.global_position = pos
	var color := Color(0.8, 0.5, 1.0)
	var mesh: Mesh = ProcMesh.sphere(float(ev[11]) * 0.8)
	match visual:
		NetProtocol.PV_FROST:
			color = Color(0.6, 0.9, 1.0)
			mesh = ProcMesh.capsule(0.12, 0.7)
		NetProtocol.PV_FIRE:
			color = Color(1.0, 0.5, 0.15)
			mesh = ProcMesh.sphere(0.4)
		NetProtocol.PV_HOLY_LANCE:
			color = Color(1.0, 0.88, 0.5)
			mesh = ProcMesh.capsule(0.07, 1.4)
		NetProtocol.PV_ARROW:
			color = Color(0.95, 0.7, 0.4)
			mesh = ProcMesh.capsule(0.03, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var alpha := 1.0 if owner_code == local_slot or owner_code == 2 else partner_opacity
	var mat := ProcMesh.emissive(color, color, 3.0) if alpha >= 1.0 else ProcMesh.unshaded(Color(color.r, color.g, color.b, alpha))
	mi.material_override = mat
	if mesh is CapsuleMesh:
		mi.rotation_degrees.x = 90.0
	node.add_child(mi)
	if vel.length() > 0.01:
		node.look_at(pos + vel, Vector3.UP)
	if not headless and visual != NetProtocol.PV_ARROW:
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = 1.2
		l.omni_range = 3.0
		node.add_child(l)
	_projectiles[id] = [node, vel, float(ev[10])]


func _end_projectile(ev: Array) -> void:
	var id: int = ev[1]
	var entry: Array = _projectiles.get(id, [])
	if entry.is_empty():
		return
	var node: Node3D = entry[0]
	var p := Vector3(ev[2], ev[3], ev[4])
	if bool(ev[5]):
		_burst(p, Color(1.0, 0.55, 0.15), 30, 0.6, 6.0)
		_ring(Vector3(p.x, 0.15, p.z), 2.2, Color(1.0, 0.5, 0.2, 0.9), 0.4)
		sfx.play(&"explode", p, 0.0)
		if camera_rig != null:
			camera_rig.add_trauma(0.3)
	else:
		_burst(p, Color(0.9, 0.85, 1.0, 0.7), 6, 0.25, 1.5)
	node.queue_free()
	_projectiles.erase(id)


func _begin_telegraph(ev: Array) -> void:
	var id: int = ev[1]
	_end_telegraph(id)
	var shape: int = ev[2]
	var center := Vector3(ev[3], 0.04, ev[4])
	var dir := Vector3(ev[5], 0, ev[6])
	var radius: float = ev[7]
	var arc: float = ev[8]
	var length: float = ev[9]
	var ticks: int = ev[10]
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = TELEGRAPH_SHADER
	mat.render_priority = 10
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("half_arc", deg_to_rad(arc * 0.5))
	mat.set_shader_parameter("emphasis", 1.0 if Settings.assist("telegraph_emphasis") else 0.0)
	match shape:
		NetProtocol.TG_LINE:
			plane.size = Vector2(radius * 2.0, length)
			mi.position = center + dir * length * 0.5
		_:
			plane.size = Vector2(radius * 2.0, radius * 2.0)
			mi.position = center
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if dir.length() > 0.01:
		mi.basis = Basis.looking_at(-dir, Vector3.UP)
	_telegraphs[id] = [mi, Time.get_ticks_msec(), ticks * 1000 / 60]
	sfx.play(&"warn", center, -12.0)


func _end_telegraph(id: int) -> void:
	var entry: Array = _telegraphs.get(id, [])
	if entry.is_empty():
		return
	(entry[0] as Node).queue_free()
	_telegraphs.erase(id)


## Bots dodge when a telegraph covers them.
func telegraph_threatens(pos: Vector3) -> bool:
	for entry: Array in _telegraphs.values():
		var mi: MeshInstance3D = entry[0]
		var plane := mi.mesh as PlaneMesh
		var local := mi.global_transform.affine_inverse() * pos
		if absf(local.x) <= plane.size.x * 0.5 + 0.4 and absf(local.z) <= plane.size.y * 0.5 + 0.4:
			return true
	return false


# --- Little effects ---------------------------------------------------------------------------

func _number(pos: Vector3, text: String, color: Color, size: float) -> void:
	if headless:
		return
	var l := _numbers[_number_next]
	_number_next = (_number_next + 1) % _numbers.size()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.font_size = roundi(44 * size)
	l.global_position = pos
	l.visible = true
	_fx.append([l, Time.get_ticks_msec() + 900, &"number", pos])


func _popup(pos: Vector3, text: String, color: Color, size: float, seconds: float) -> void:
	if headless:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 12
	l.modulate = color
	l.font_size = roundi(52 * size)
	l.pixel_size = 0.006
	l.render_priority = 21
	add_child(l)
	l.global_position = pos
	_fx.append([l, Time.get_ticks_msec() + int(seconds * 1000.0), &"popup", pos])


func _ring(pos: Vector3, radius: float, color: Color, seconds: float) -> void:
	if headless:
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 40
	t.ring_segments = 4
	mi.mesh = t
	mi.material_override = ProcMesh.unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 1.0, 0.2) * radius
	_fx.append([mi, Time.get_ticks_msec() + int(seconds * 1000.0), &"ring", radius])


func _burst(pos: Vector3, color: Color, amount: int, seconds: float, speed: float) -> void:
	if headless:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = seconds
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	var mat := ProcMesh.unshaded(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p.material_override = mat
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_fx.append([p, Time.get_ticks_msec() + int(seconds * 1000.0) + 200, &"burst", null])


func _beam(a: Vector3, b: Vector3, color: Color) -> void:
	if headless:
		return
	var mi := MeshInstance3D.new()
	var len := a.distance_to(b)
	mi.mesh = ProcMesh.box(Vector3(0.12, 0.12, len))
	mi.material_override = ProcMesh.emissive(color, color, 5.0)
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	if len > 0.01:
		mi.look_at(b, Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	_fx.append([mi, Time.get_ticks_msec() + 160, &"beam", null])


func _slash(origin: Vector3, dir: Vector3, reach: float, arc_deg: float, color: Color) -> void:
	if headless:
		return
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var half := deg_to_rad(arc_deg * 0.5)
	var base_angle := atan2(dir.x, dir.z)
	for i in 17:
		var a := base_angle - half + 2.0 * half * i / 16.0
		var d := Vector3(sin(a), 0, cos(a))
		var fade := sin(float(i) / 16.0 * PI)
		im.surface_set_color(Color(color.r, color.g, color.b, color.a * fade))
		im.surface_add_vertex(origin + Vector3(0, 1.0, 0) + d * reach * 0.45)
		im.surface_set_color(Color(color.r, color.g, color.b, color.a * fade * 0.2))
		im.surface_add_vertex(origin + Vector3(0, 1.0, 0) + d * reach)
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fx.append([mi, Time.get_ticks_msec() + 140, &"slash", null])


func _hitstop_near(center: Vector3, radius: float, ms: int) -> void:
	for v: EnemyVisual in enemies.values():
		if GameTypes.flat(v.global_position - center).length() <= radius:
			v.hit_stop(ms)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for id: int in _projectiles.keys():
		var entry: Array = _projectiles[id]
		var node: Node3D = entry[0]
		var vel: Vector3 = entry[1]
		var step := vel * delta
		var remaining: float = entry[2]
		if remaining <= 0.0:
			continue
		if step.length() > remaining:
			step = step.normalized() * remaining
		entry[2] = remaining - step.length()
		node.global_position += step
	for entry: Array in _telegraphs.values():
		var mi: MeshInstance3D = entry[0]
		var k := clampf(float(now - int(entry[1])) / maxf(1.0, float(entry[2])), 0.0, 1.0)
		(mi.material_override as ShaderMaterial).set_shader_parameter("progress", k)
	var keep: Array = []
	for fx: Array in _fx:
		var node: Node3D = fx[0]
		var end_ms: int = fx[1]
		if not is_instance_valid(node):
			continue
		if now >= end_ms:
			if fx[2] == &"number":
				node.visible = false
			else:
				node.queue_free()
			continue
		match fx[2]:
			&"number", &"popup":
				node.global_position.y += delta * (1.2 if fx[2] == &"number" else 0.5)
				var l := node as Label3D
				l.modulate.a = clampf(float(end_ms - now) / 400.0, 0.0, 1.0)
			&"ring":
				var r: float = fx[3]
				node.scale = node.scale.lerp(Vector3(r, 1.0, r), minf(1.0, delta * 9.0))
				var m := (node as MeshInstance3D).material_override as StandardMaterial3D
				m.albedo_color.a = clampf(float(end_ms - now) / 300.0, 0.0, 1.0) * 0.9
		keep.append(fx)
	_fx = keep
