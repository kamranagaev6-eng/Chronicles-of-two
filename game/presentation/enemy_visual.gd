class_name EnemyVisual
extends Node3D
## Presentation for one host-simulated entity, identical on both PCs: posed from its replicated
## state, primer markers in the owner's colour and shape, an outline when the local player can
## detonate it, a health bar, hit flash and presentation-only hit-stop.

const A := GameTypes.Anim
const OUTLINE_SHADER := preload("res://game/presentation/shaders/outline.gdshader")

var entity_id: int = 0
var kind: int = 0
var def: EnemyDefinition
var model: Node3D
var body: Node3D
var arm_r: Node3D
var parts: Array[GeometryInstance3D] = []
var hp_back: MeshInstance3D
var hp_fill: MeshInstance3D
var stagger_fill: MeshInstance3D
var markers: Array[Node3D] = []
var marker_labels: Array[Label3D] = []
var state: CrowdCodec.Entity
var local_slot: int = 0
var partner_color := ProcMesh.VIOLET
var own_color := ProcMesh.GOLD
var dying_since: int = -1
var _freeze_until: int = 0
var _flash_until: int = 0
var _flash_mat: StandardMaterial3D
var _frozen_mat: StandardMaterial3D
var _outline: ShaderMaterial
var _outline_on: bool = false
var _t: float = 0.0
var ready_changed: Callable


func setup(p_id: int, p_kind: int, p_local_slot: int, colors: Array[Color]) -> void:
	entity_id = p_id
	kind = p_kind
	local_slot = p_local_slot
	own_color = colors[p_local_slot]
	partner_color = colors[1 - p_local_slot]
	if kind >= NetProtocol.KIND_OIL_BARREL:
		def = EnemyDefinition.new()
		def.id = &"oil_barrel" if kind == NetProtocol.KIND_OIL_BARREL else &"water_barrel"
		def.height = 1.0
		def.radius = 0.4
	else:
		def = GameData.enemy(GameData.enemy_id_at(kind))
	model = ProcMesh.build_enemy(def)
	add_child(model)
	body = model.get_node("Body")
	arm_r = body.get_node_or_null("ArmR")
	_collect(model)
	_flash_mat = ProcMesh.unshaded(Color(1, 1, 1, 0.8))
	_frozen_mat = ProcMesh.unshaded(Color(0.65, 0.9, 1.0, 0.55))
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline.set_shader_parameter("color", partner_color)
	if def.id != &"oil_barrel" and def.id != &"water_barrel":
		var top := def.height + 0.45
		hp_back = _bar(Vector3(0, top, 0), Color(0.05, 0.05, 0.06, 0.8), 1.0)
		hp_fill = _bar(Vector3(0, top, 0), Color(0.85, 0.2, 0.18, 0.95), 1.0)
		stagger_fill = _bar(Vector3(0, top - 0.09, 0), Color(1.0, 0.85, 0.3, 0.95), 0.4)
		for i in 2:
			var marker := Node3D.new()
			marker.position = Vector3(-0.28 + i * 0.56, top + 0.3, 0)
			add_child(marker)
			var shape := MeshInstance3D.new()
			shape.mesh = ProcMesh.box(Vector3(0.22, 0.22, 0.02)) if i == 0 else ProcMesh.sphere(0.13)
			var mat := ProcMesh.unshaded(colors[i], false)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.no_depth_test = true
			shape.material_override = mat
			if i == 0:
				shape.rotation_degrees.z = 45.0
			marker.add_child(shape)
			var label := Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.font_size = 28
			label.outline_size = 6
			label.pixel_size = 0.006
			label.position.y = 0.22
			marker.add_child(label)
			marker.visible = false
			markers.append(marker)
			marker_labels.append(label)


func _collect(n: Node) -> void:
	if n is GeometryInstance3D and n.name != "Blob":
		parts.append(n as GeometryInstance3D)
	for c: Node in n.get_children():
		_collect(c)


func _bar(pos: Vector3, color: Color, height_scale: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.08 * height_scale)
	mi.mesh = q
	var mat := ProcMesh.unshaded(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 2
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func hit_stop(ms: int) -> void:
	_freeze_until = maxi(_freeze_until, Time.get_ticks_msec() + ms)


func flash() -> void:
	_flash_until = Time.get_ticks_msec() + 34
	for p: GeometryInstance3D in parts:
		p.material_overlay = _flash_mat


## Apply the latest (host) or interpolated (guest) state.
func apply_state(s: CrowdCodec.Entity, delta: float) -> void:
	state = s
	var now := Time.get_ticks_msec()
	if _flash_until > 0 and now >= _flash_until:
		_flash_until = 0
		for p: GeometryInstance3D in parts:
			p.material_overlay = _frozen_mat if s.flags & GameTypes.FLAG_FROZEN != 0 else null
	if now < _freeze_until:
		return
	_t += delta
	global_position = s.position
	model.rotation.y = lerp_angle(model.rotation.y, s.yaw, minf(1.0, delta * 14.0))
	_pose(s, delta)
	if hp_fill != null:
		var show := s.health < 0.999 or s.flags & GameTypes.FLAG_ELITE != 0
		hp_back.visible = show and s.anim != A.DEAD
		hp_fill.visible = hp_back.visible
		stagger_fill.visible = hp_back.visible and s.stagger > 0.01
		hp_fill.scale.x = maxf(0.001, s.health)
		hp_fill.position.x = -(1.0 - s.health) * 0.5
		stagger_fill.scale.x = maxf(0.001, s.stagger)
		stagger_fill.position.x = -(1.0 - s.stagger) * 0.5
		_update_markers(s)
	if _flash_until == 0:
		var frozen := s.flags & GameTypes.FLAG_FROZEN != 0
		for p: GeometryInstance3D in parts:
			p.material_overlay = _frozen_mat if frozen else null


func _update_markers(s: CrowdCodec.Entity) -> void:
	var primers := [s.primer0, s.primer1]
	for i in 2:
		var p: int = primers[i]
		markers[i].visible = p > 0 and s.anim != A.DEAD
		if p > 0:
			marker_labels[i].text = String(GameTypes.primer_at(p - 1)).capitalize()
			marker_labels[i].modulate = own_color if i == local_slot else partner_color
			markers[i].position.y = def.height + 0.75 + 0.05 * sin(_t * 5.0 + i)
	var detonate_ready: bool = int(primers[1 - local_slot]) > 0 and s.anim != A.DEAD
	if detonate_ready != _outline_on:
		_outline_on = detonate_ready
		var torso := body.get_node_or_null("Torso") as GeometryInstance3D
		if torso != null:
			var mat := torso.material_override
			if mat != null:
				var copy := mat.duplicate() as Material
				copy.next_pass = _outline if detonate_ready else null
				torso.material_override = copy
		if detonate_ready and ready_changed.is_valid():
			ready_changed.call(self)


func _pose(s: CrowdCodec.Entity, delta: float) -> void:
	var target_rot := Vector3.ZERO
	var target_pos := Vector3.ZERO
	var arm := Vector3.ZERO
	match s.anim:
		A.SPAWNING:
			target_pos = Vector3(0, -0.6, 0)
		A.MOVE:
			target_rot.x = deg_to_rad(8.0)
			target_pos.y = absf(sin(_t * 9.0)) * 0.05
			arm = Vector3(sin(_t * 9.0) * 0.4, 0, 0)
		A.TELEGRAPH:
			target_rot.x = deg_to_rad(-12.0)
			arm = Vector3(deg_to_rad(-160.0), 0, 0)
		A.ATTACK:
			target_rot.x = deg_to_rad(18.0)
			arm = Vector3(deg_to_rad(50.0), 0, 0)
		A.RECOVER:
			target_rot.x = deg_to_rad(6.0)
		A.STUNNED:
			target_rot = Vector3(deg_to_rad(10.0), 0, sin(_t * 6.0) * 0.25)
		A.STAGGERED:
			target_rot.x = deg_to_rad(25.0)
			target_pos.y = -0.35
		A.KNOCKBACK:
			target_rot.x = deg_to_rad(-25.0)
		A.PRONE:
			target_rot.x = deg_to_rad(-85.0)
			target_pos = Vector3(0, 0.3, -0.5)
		A.LAUNCHED:
			target_rot.x = _t * 6.0
		A.DEAD:
			target_rot.x = deg_to_rad(-90.0)
			target_pos = Vector3(0, 0.2 - minf(1.0, _death_time()) * 0.6, -0.6)
	if s.anim == A.LAUNCHED:
		body.rotation = target_rot
	else:
		body.rotation = body.rotation.lerp(target_rot, minf(1.0, delta * 12.0))
	body.position = body.position.lerp(target_pos, minf(1.0, delta * 10.0))
	if arm_r != null:
		arm_r.rotation = arm_r.rotation.lerp(arm, minf(1.0, delta * 16.0))


func _death_time() -> float:
	if dying_since < 0:
		dying_since = Time.get_ticks_msec()
	return (Time.get_ticks_msec() - dying_since) / 1000.0
