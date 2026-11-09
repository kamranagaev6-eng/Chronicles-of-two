class_name HeroVisual
extends Node3D
## Presentation for one hero on this PC: interpolates between network ticks, smooths prediction
## corrections, and animates the placeholder model from the motor's action, dodge and downed state.
## Hit-stop here is presentation only; it never pauses the simulation.

var hero: Hero
var accent: Color
var model: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var parts: Array[GeometryInstance3D] = []
var bubble: MeshInstance3D
var downed_ring: MeshInstance3D
var revive_ring: MeshInstance3D
var name_label: Label3D
var light: OmniLight3D

var _prev := Vector3.ZERO
var _cur := Vector3.ZERO
var _offset := Vector3.ZERO
var _freeze_until: int = 0
var _flash_until: int = 0
var _flash_mat: StandardMaterial3D
var _yaw: float = 0.0
var _bob: float = 0.0
var _swing: float = 0.0
var _inited: bool = false


func setup(p_hero: Hero) -> void:
	hero = p_hero
	top_level = true
	accent = ProcMesh.player_color(hero.color_name)
	model = ProcMesh.build_hero(hero.class_def.id, accent)
	add_child(model)
	body = model.get_node("Body")
	arm_l = body.get_node("ArmL")
	arm_r = body.get_node("ArmR")
	_collect(model)
	_flash_mat = ProcMesh.unshaded(Color(1, 1, 1, 0.75))
	bubble = MeshInstance3D.new()
	bubble.mesh = ProcMesh.sphere(1.0)
	bubble.material_override = ProcMesh.unshaded(Color(accent.r, accent.g, accent.b, 0.18))
	bubble.position.y = 0.95
	bubble.scale = Vector3(0.8, 1.05, 0.8)
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.visible = false
	add_child(bubble)
	downed_ring = _ring(0.9, Color(1, 0.25, 0.2, 0.7))
	revive_ring = _ring(1.15, Color(accent.r, accent.g, accent.b, 0.9))
	name_label = Label3D.new()
	name_label.text = hero.hero_name
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = accent
	name_label.outline_size = 8
	name_label.font_size = 40
	name_label.pixel_size = 0.006
	name_label.position.y = 2.25
	name_label.no_depth_test = true
	add_child(name_label)
	if not Settings.is_headless():
		light = OmniLight3D.new()
		light.light_color = accent
		light.light_energy = 0.6
		light.omni_range = 3.5
		light.position.y = 1.6
		add_child(light)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	hero.corrected.connect(_on_corrected)


func _exit_tree() -> void:
	if NetworkTime.after_tick_loop.is_connected(_after_tick_loop):
		NetworkTime.after_tick_loop.disconnect(_after_tick_loop)


func _collect(n: Node) -> void:
	if n is GeometryInstance3D and n.name != "Blob":
		parts.append(n as GeometryInstance3D)
	for c: Node in n.get_children():
		_collect(c)


func _ring(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.06
	t.outer_radius = radius
	t.rings = 32
	t.ring_segments = 6
	mi.mesh = t
	mi.material_override = ProcMesh.unshaded(color)
	mi.position.y = 0.05
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _after_tick_loop() -> void:
	_prev = _cur
	_cur = hero.global_position
	if not _inited:
		_prev = _cur
		_inited = true
	elif hero.teleported_tick >= NetworkTime.tick - 2:
		_prev = _cur
		_offset = Vector3.ZERO
	elif not hero.is_local_player() and (_cur - _prev).length() > 1.5:
		_offset += _prev - _cur


func _on_corrected(vec: Vector3) -> void:
	if vec.length() < 2.0:
		_offset -= vec


func hit_stop(ms: int) -> void:
	_freeze_until = maxi(_freeze_until, Time.get_ticks_msec() + ms)


func flash() -> void:
	_flash_until = Time.get_ticks_msec() + 34
	for p: GeometryInstance3D in parts:
		p.material_overlay = _flash_mat


func _process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var now := Time.get_ticks_msec()
	if _flash_until > 0 and now >= _flash_until:
		_flash_until = 0
		for p: GeometryInstance3D in parts:
			p.material_overlay = null
	if now < _freeze_until:
		return
	var t := NetworkTime.tick_factor
	var pos := _prev.lerp(_cur, t) + _offset
	_offset = _offset * exp(-delta * 14.0)
	global_position = pos
	var m := hero.motor
	_yaw = lerp_angle(_yaw, m.yaw, minf(1.0, delta * 16.0))
	model.rotation.y = _yaw
	_animate(delta, m)
	var s := hero.stats
	bubble.visible = s.barrier > 0.5 and s.is_alive()
	if bubble.visible:
		(bubble.material_override as StandardMaterial3D).albedo_color.a = 0.1 + 0.15 * clampf(s.barrier / (s.max_health * 0.2), 0.0, 1.0)
	downed_ring.visible = s.life == NetProtocol.LIFE_DOWNED
	if downed_ring.visible:
		downed_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(now * 0.008))
	revive_ring.visible = s.life == NetProtocol.LIFE_DOWNED and s.revive_progress > 0.0
	if revive_ring.visible:
		revive_ring.scale = Vector3.ONE * (0.3 + 0.7 * s.revive_progress)
	name_label.modulate.a = 0.35 if s.life == NetProtocol.LIFE_FALLEN else 1.0


func _animate(delta: float, m: HeroMotor) -> void:
	var speed := GameTypes.flat(m.move_velocity).length()
	var life := hero.stats.life
	if life != NetProtocol.LIFE_ALIVE or m.downed:
		body.rotation = Vector3(deg_to_rad(-80.0), 0, 0)
		body.position = Vector3(0, 0.25, 0.6)
		arm_l.rotation = Vector3.ZERO
		arm_r.rotation = Vector3.ZERO
		return
	body.position = Vector3.ZERO
	_bob += delta * (4.0 + speed * 1.6)
	var lean := clampf(speed / 7.0, 0.0, 1.0) * deg_to_rad(10.0)
	body.rotation = Vector3(lean, 0, 0)
	body.position.y = absf(sin(_bob)) * 0.05 * clampf(speed / 3.0, 0.0, 1.0)
	if m.dodge_ticks_left > 0:
		body.rotation.x = deg_to_rad(35.0)
		body.scale = Vector3(1.05, 0.8, 1.05)
		return
	body.scale = Vector3.ONE
	var arm_r_target := Vector3(sin(_bob) * 0.35 * clampf(speed / 3.0, 0.0, 1.0), 0, 0)
	var arm_l_target := Vector3(-sin(_bob) * 0.35 * clampf(speed / 3.0, 0.0, 1.0), 0, 0)
	if m.action_slot >= 0:
		var def := m.ability_at(m.action_slot)
		if def != null:
			var elapsed := float(NetworkTime.tick - m.action_tick) + NetworkTime.tick_factor
			var w := float(maxi(1, def.windup_ticks))
			if elapsed < w:
				var k := elapsed / w
				arm_r_target = Vector3(deg_to_rad(-150.0) * k, 0, deg_to_rad(-20.0) * k)
				if def.delivery == &"charge":
					arm_l_target = Vector3(deg_to_rad(-80.0) * k, 0, 0)
			elif elapsed < w + def.active_ticks + 6:
				var k2 := clampf((elapsed - w) / maxf(4.0, float(def.active_ticks)), 0.0, 1.0)
				arm_r_target = Vector3(deg_to_rad(lerpf(-150.0, 40.0, k2)), 0, deg_to_rad(lerpf(-20.0, 30.0, k2)))
				if def.delivery == &"charge":
					arm_l_target = Vector3(deg_to_rad(-85.0), 0, 0)
			if hero.class_def.id == &"riftweaver" and def.delivery != &"melee_arc":
				arm_r_target = Vector3(deg_to_rad(-100.0), 0, 0)
				arm_l_target = Vector3(deg_to_rad(-70.0), 0, deg_to_rad(15.0))
	arm_r.rotation = arm_r.rotation.lerp(arm_r_target, minf(1.0, delta * 22.0))
	arm_l.rotation = arm_l.rotation.lerp(arm_l_target, minf(1.0, delta * 22.0))
