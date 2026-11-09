extends Node3D
## Milestone 0 asset test scene: both heroes beside enemies, stairs, slopes, equipment swaps, attacks,
## a ragdoll and representative lighting. Runs offline; the controllable hero uses the real HeroMotor
## so slopes, stairs, dodges and ability timing can be checked from the gameplay camera.
## Keys: WASD move, Space dodge, LMB/RMB/Q/E/R attack, 1 helmet, 2 weapons, 3 outfit colour,
## G drop a ragdoll, L lighting preset, Esc back to the menu.

var player: CharacterBody3D
var motor: HeroMotor
var player_model: Node3D
var camera_rig: CameraRig
var _tick: int = 0
var _input := HeroMotor.InputFrame.new()
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _warm: bool = false
var _showcase: Array[Node3D] = []
var _helmets: Array[Node3D] = []
var _weapons_alt: bool = false
var _outfit: int = 0
var _ragdolls: Array[Node3D] = []
var _info: Label


func _ready() -> void:
	_build_ground()
	_build_lighting()
	_build_showcase()
	_build_player()
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.target = player
	camera_rig.aim_source = func() -> Vector3: return _input.aim
	camera_rig.snap_to(player.global_position)
	_spawn_ragdoll(Vector3(6, 4, -4))
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_info = UiKit.label(ui, "", 15)
	_info.position = Vector2(16, 16)


func _build_ground() -> void:
	var floor_mat := ProcMesh.material(Color(0.36, 0.34, 0.37), 0.9)
	_static_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60), floor_mat)
	# Stairs: visual steps over an invisible ramp collider (characters never climb raw steps).
	var steps := 6
	for i in steps:
		var h := 0.2 * (i + 1)
		var mesh := MeshInstance3D.new()
		mesh.mesh = ProcMesh.box(Vector3(3.0, h, 0.5))
		mesh.material_override = ProcMesh.material(Color(0.5, 0.46, 0.42), 0.85)
		mesh.position = Vector3(-8, h * 0.5, -2.0 - i * 0.5)
		add_child(mesh)
	_ramp(Vector3(-8, 0.6, -3.25), Vector3(3.0, 0.05, 3.25), deg_to_rad(20.3), false)
	_static_box(Vector3(-8, 0.6, -6.5), Vector3(3.0, 1.2, 3.5), ProcMesh.material(Color(0.45, 0.42, 0.4), 0.85))
	# Slopes at 15, 30 and 45 degrees.
	var x := 0.0
	for angle: float in [15.0, 30.0, 45.0]:
		_ramp(Vector3(x, 1.0, -8.0), Vector3(2.5, 0.2, 5.0), deg_to_rad(angle), true)
		var label := Label3D.new()
		label.text = "%d deg" % angle
		label.position = Vector3(x, 3.4, -5.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		add_child(label)
		x += 4.0
	_static_box(Vector3(14, 1.5, 0), Vector3(1, 3, 10), ProcMesh.material(Color(0.3, 0.28, 0.33), 0.9))


func _static_box(center: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = ProcMesh.box(size)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _ramp(center: Vector3, size: Vector3, angle: float, visible_mesh: bool) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		var mesh := MeshInstance3D.new()
		mesh.mesh = ProcMesh.box(size)
		mesh.material_override = ProcMesh.material(Color(0.48, 0.44, 0.4), 0.85)
		body.add_child(mesh)
	add_child(body)


func _build_lighting() -> void:
	_env = WorldEnvironment.new()
	_env.environment = Environment.new()
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(_sun)
	for p: Vector3 in [Vector3(-4, 0, 3), Vector3(4, 0, 3)]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.32)
		light.light_energy = 2.0
		light.omni_range = 8.0
		light.position = p + Vector3(0, 2, 0)
		light.set_script(preload("res://game/presentation/flicker.gd"))
		add_child(light)
	_apply_lighting()


func _apply_lighting() -> void:
	var e := _env.environment
	e.background_mode = Environment.BG_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.ssao_enabled = true
	if _warm:
		e.background_color = Color(0.35, 0.3, 0.28)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.8, 0.66, 0.52)
		e.ambient_light_energy = 0.8
		e.fog_enabled = false
		_sun.light_color = Color(1.0, 0.86, 0.68)
		_sun.light_energy = 1.3
	else:
		e.background_color = Color(0.03, 0.03, 0.05)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.36, 0.38, 0.5)
		e.ambient_light_energy = 0.5
		e.fog_enabled = true
		e.fog_density = 0.015
		e.fog_light_color = Color(0.2, 0.22, 0.3)
		_sun.light_color = Color(0.62, 0.68, 0.9)
		_sun.light_energy = 0.55


func _build_showcase() -> void:
	var specs := [[&"vanguard", "gold"], [&"riftweaver", "violet"]]
	for i in specs.size():
		var spec: Array = specs[i]
		var model := ProcMesh.build_hero(spec[0], ProcMesh.player_color(spec[1]))
		model.position = Vector3(-2.5 + i * 2.0, 0, 3)
		model.rotation_degrees.y = 180.0
		add_child(model)
		_showcase.append(model)
		var helmet := MeshInstance3D.new()
		helmet.mesh = ProcMesh.cylinder(0.19, 0.2, 0.25)
		helmet.material_override = ProcMesh.material(Color(0.55, 0.55, 0.6), 0.35, 0.7)
		helmet.position = Vector3(0, 1.74, 0)
		helmet.visible = false
		model.get_node("Body").add_child(helmet)
		_helmets.append(helmet)
	var x := 2.5
	for id: StringName in [&"drowned_thrall", &"crypt_archer", &"drowned_knight", &"training_dummy"]:
		var def := GameData.enemy(id)
		var model := ProcMesh.build_enemy(def)
		model.position = Vector3(x, 0, 3)
		model.rotation_degrees.y = 180.0
		add_child(model)
		var label := Label3D.new()
		label.text = def.display_name
		label.position = Vector3(x, def.height + 0.6, 3)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		add_child(label)
		x += 2.0


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.35
	player.floor_max_angle = deg_to_rad(50.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Hero.CAPSULE_RADIUS
	capsule.height = Hero.CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position.y = 0.9
	player.add_child(shape)
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	motor = HeroMotor.new()
	player.add_child(motor)
	motor.configure_from_rules()
	var c := GameData.class_def(&"vanguard")
	motor.move_speed = c.move_speed
	var defs: Array[AbilityDefinition] = []
	defs.resize(GameTypes.ACTION_COUNT)
	defs[GameTypes.ACT_BASIC] = GameData.ability(c.basic_attack)
	for i in c.abilities.size():
		defs[i + 1] = GameData.ability(c.abilities[i])
	defs[GameTypes.ACT_SHOVE] = GameData.ability(&"shove")
	defs[GameTypes.ACT_FLASK] = GameData.ability(&"flask")
	motor.abilities = defs
	player_model = ProcMesh.build_hero(&"vanguard", ProcMesh.GOLD)
	player.add_child(player_model)


func _physics_process(delta: float) -> void:
	_tick += 1
	_input.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_input.held = GameTypes.BTN_ATTACK if Input.is_action_pressed(&"attack") else 0
	if camera_rig != null and camera_rig.camera != null:
		var mouse := get_viewport().get_mouse_position()
		var from := camera_rig.camera.project_ray_origin(mouse)
		var dir := camera_rig.camera.project_ray_normal(mouse)
		var hit: Variant = Plane(Vector3.UP, player.global_position.y).intersects_ray(from, dir)
		if hit != null:
			_input.aim = hit
	for i in 4:
		if Input.is_action_just_pressed(StringName("ability_%d" % (i + 1))):
			_input.req_seq += 1
			_input.req_slot = i + 1
	if Input.is_action_just_pressed(&"dodge"):
		_input.dodge_seq += 1
	var result := motor.step(_input, _tick, player.global_position, delta, motor.grounded)
	player.velocity = result.velocity
	player.move_and_slide()
	motor.grounded = player.is_on_floor()
	player_model.rotation.y = lerp_angle(player_model.rotation.y, motor.yaw, 0.3)
	var arm := player_model.get_node("Body/ArmR") as Node3D
	arm.rotation.x = deg_to_rad(-120.0) if motor.action_slot >= 0 else lerpf(arm.rotation.x, 0.0, 0.2)
	(player_model.get_node("Body") as Node3D).rotation.x = deg_to_rad(30.0) if motor.dodge_ticks_left > 0 else 0.0


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		get_tree().change_scene_to_file(Net.BOOT_SCENE)
	if Input.is_key_pressed(KEY_1) and Input.is_action_just_pressed(&"flask"):
		for h: Node3D in _helmets:
			h.visible = not h.visible
	if Input.is_physical_key_pressed(KEY_2) and not _weapons_alt:
		_weapons_alt = true
		for m: Node3D in _showcase:
			var w := m.get_node_or_null("Body/ArmR/Weapon") as Node3D
			if w != null:
				w.scale = Vector3(1.0, 1.4, 1.0) if w.scale.y < 1.2 else Vector3.ONE
	elif not Input.is_physical_key_pressed(KEY_2):
		_weapons_alt = false
	if Input.is_action_just_pressed(&"interact"):
		_spawn_ragdoll(player.global_position + Vector3(0, 3, 0))
	if Input.is_action_just_pressed(&"bond"):
		_warm = not _warm
		_apply_lighting()
	_info.text = "Asset test scene (M0 placeholder art)\nWASD move · Space dodge · LMB/RMB/Q/E/R attacks · F drop ragdoll · T lighting (%s) · 1 helmets · 2 weapon swap · Esc menu\nPosition %s  on floor %s  stairs/ramp at left, slopes 15/30/45 at back" % [
		"warm home" if _warm else "dungeon", str(player.global_position.snapped(Vector3.ONE * 0.01)), motor.grounded]


## A simple ragdoll from capsules and cone-twist joints (death ragdolls are local and settle out of the way).
func _spawn_ragdoll(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	_ragdolls.append(root)
	while _ragdolls.size() > 6:
		_ragdolls[0].queue_free()
		_ragdolls.remove_at(0)
	var pelvis := _bone(root, at, Vector3(0.3, 0.25, 0.2))
	var chest := _bone(root, at + Vector3(0, 0.45, 0), Vector3(0.36, 0.35, 0.22))
	var head := _bone(root, at + Vector3(0, 0.85, 0), Vector3(0.2, 0.22, 0.2))
	var leg_l := _bone(root, at + Vector3(-0.12, -0.5, 0), Vector3(0.12, 0.6, 0.12))
	var leg_r := _bone(root, at + Vector3(0.12, -0.5, 0), Vector3(0.12, 0.6, 0.12))
	var arm_l := _bone(root, at + Vector3(-0.4, 0.45, 0), Vector3(0.1, 0.5, 0.1))
	var arm_r := _bone(root, at + Vector3(0.4, 0.45, 0), Vector3(0.1, 0.5, 0.1))
	_joint(root, pelvis, chest, at + Vector3(0, 0.22, 0))
	_joint(root, chest, head, at + Vector3(0, 0.68, 0))
	_joint(root, pelvis, leg_l, at + Vector3(-0.12, -0.15, 0))
	_joint(root, pelvis, leg_r, at + Vector3(0.12, -0.15, 0))
	_joint(root, chest, arm_l, at + Vector3(-0.3, 0.65, 0))
	_joint(root, chest, arm_r, at + Vector3(0.3, 0.65, 0))
	chest.apply_central_impulse(Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))


func _bone(root: Node3D, pos: Vector3, size: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.collision_layer = 8
	b.collision_mask = 1 | 8
	b.mass = size.x * size.y * size.z * 200.0 + 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	b.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = ProcMesh.box(size)
	mesh.material_override = ProcMesh.material(Color(0.4, 0.5, 0.45), 0.8)
	b.add_child(mesh)
	root.add_child(b)
	b.global_position = pos
	return b


func _joint(root: Node3D, a: RigidBody3D, b: RigidBody3D, at: Vector3) -> void:
	var j := ConeTwistJoint3D.new()
	root.add_child(j)
	j.global_position = at
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(45.0))
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(30.0))
