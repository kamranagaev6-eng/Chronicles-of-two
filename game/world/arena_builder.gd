class_name ArenaBuilder
extends RefCounted
## Builds the crypt from ArenaLayout: collision, photoscanned stone and iron (MaterialKit) and lighting.
## Uses ambientCG CC0 photoscanned PBR materials for God of War-level tactile stone and metal.

static var _pbr_cache: Dictionary = {}


static func pbr_material(set_name: String, uv_scale: Vector3 = Vector3.ONE, triplanar: bool = false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [set_name, uv_scale, triplanar]
	if _pbr_cache.has(key):
		return _pbr_cache[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/ambientcg/" + set_name + "/" + set_name + "_1K-JPG_"
	if ResourceLoader.exists(base + "Color.jpg"):
		m.albedo_texture = load(base + "Color.jpg") as Texture2D
	if ResourceLoader.exists(base + "NormalGL.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "NormalGL.jpg") as Texture2D
		m.normal_scale = 1.3
	if ResourceLoader.exists(base + "Roughness.jpg"):
		m.roughness_texture = load(base + "Roughness.jpg") as Texture2D
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if ResourceLoader.exists(base + "AmbientOcclusion.jpg"):
		m.ao_enabled = true
		m.ao_texture = load(base + "AmbientOcclusion.jpg") as Texture2D
		m.ao_light_affect = 0.5
	if ResourceLoader.exists(base + "Metalness.jpg"):
		m.metallic = 1.0
		m.metallic_texture = load(base + "Metalness.jpg") as Texture2D
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_scale = uv_scale
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 3.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_pbr_cache[key] = m
	return m


static func build(root: Node3D, headless: bool) -> void:
	# Layered photoscan materials (MaterialKit): world-space triplanar maps plus moss, damp streaks,
	# grime and a drowned waterline at the base.
	var stone: Material = MaterialKit.surface(&"crypt_stone")
	var masonry: Material = MaterialKit.surface(&"crypt_wall")
	var size := ArenaLayout.SIZE
	var o := ArenaLayout.ORIGIN
	# Floor collision (the visible floor is the surface layer's ground mesh).
	_box(root, "FloorBody", Vector3(o.x + size.x * 0.5, -0.5, o.y + size.y * 0.5), Vector3(size.x + 4.0, 1.0, size.y + 4.0), null)
	# Perimeter walls.
	var t := ArenaLayout.WALL_THICKNESS
	var h := ArenaLayout.WALL_HEIGHT
	_box(root, "WallN", Vector3(0, h * 0.5, o.y - t * 0.5), Vector3(size.x + t * 2.0, h, t), masonry)
	_box(root, "WallS", Vector3(0, h * 0.5, o.y + size.y + t * 0.5), Vector3(size.x + t * 2.0, h, t), masonry)
	_box(root, "WallW", Vector3(o.x - t * 0.5, h * 0.5, 0), Vector3(t, h, size.y), masonry)
	_box(root, "WallE", Vector3(o.x + size.x + t * 0.5, h * 0.5, 0), Vector3(t, h, size.y), masonry)
	for i in ArenaLayout.PILLARS.size():
		var p: Vector3 = ArenaLayout.PILLARS[i]
		_pillar(root, "Pillar%d" % i, p, ArenaLayout.PILLAR_RADIUS, 4.2, stone)
	for i in ArenaLayout.BLOCKS.size():
		var b: Array = ArenaLayout.BLOCKS[i]
		var s: Vector3 = b[1]
		_box(root, "Ruin%d" % i, (b[0] as Vector3) + Vector3(0, s.y * 0.5, 0), s, masonry)
	# Waystone: the checkpoint obelisk.
	var ws := Node3D.new()
	ws.name = "Waystone"
	ws.position = ArenaLayout.WAYSTONE
	root.add_child(ws)
	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 1.4
	pm.bottom_radius = 1.6
	pm.height = 0.25
	plinth.mesh = pm
	plinth.position.y = 0.12
	plinth.material_override = MaterialKit.surface(&"crypt_stone", Color.WHITE, {&"waterline": 0.0, &"grime_height": 0.0, &"moss": 0.15, &"edge_wear": 0.7, &"brightness": 1.6})
	ws.add_child(plinth)
	var obelisk := MeshInstance3D.new()
	var om := PrismMesh.new()
	om.size = Vector3(0.7, 2.4, 0.7)
	obelisk.mesh = om
	obelisk.position.y = 1.45
	# Carved slate whose cracks and veins glow, rather than a flat glowing prism.
	obelisk.material_override = MaterialKit.surface(&"crypt_stone", Color(0.55, 0.7, 0.9), {
		&"tint_strength": 0.35, &"brightness": 1.5, &"waterline": 0.0, &"grime_height": 0.0, &"moss": 0.0,
		&"world_space": false, &"tiles_per_metre": 0.8, &"emission_color": Color(0.35, 0.65, 1.0),
		&"emission_energy": 3.0, &"glow_in_cracks": 1.0})
	ws.add_child(obelisk)
	if not headless:
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.5, 0.75, 1.0)
		glow.light_energy = 1.6
		glow.omni_range = 7.0
		glow.position.y = 2.2
		ws.add_child(glow)
		_lights(root)


static func _box(root: Node3D, node_name: String, center: Vector3, box_size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	shape.shape = bs
	body.add_child(shape)
	if mat != null:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box_size
		mesh.mesh = bm
		mesh.material_override = mat
		body.add_child(mesh)
	root.add_child(body)
	return body


static func _pillar(root: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos + Vector3(0, height * 0.5, 0)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = radius
	cs.height = height
	shape.shape = cs
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.85
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	mesh.mesh = cm
	mesh.material_override = mat
	body.add_child(mesh)
	var cap := MeshInstance3D.new()
	var capm := BoxMesh.new()
	capm.size = Vector3(radius * 2.4, 0.35, radius * 2.4)
	cap.mesh = capm
	cap.position.y = height * 0.5
	cap.material_override = mat
	body.add_child(cap)
	root.add_child(body)


static func _lights(root: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.35, 0.46)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_bloom = 0.12
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Volumetric fog: Norse dungeon mist drifting across the crypt floor
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.018
	e.volumetric_fog_albedo = Color(0.18, 0.22, 0.28)
	e.volumetric_fog_emission = Color(0.015, 0.02, 0.03)
	e.volumetric_fog_emission_energy = 1.0
	e.volumetric_fog_anisotropy = 0.35
	e.volumetric_fog_length = 35.0
	# Deep contact shadows and reflections
	e.ssao_enabled = true
	e.ssao_radius = 1.6
	e.ssao_intensity = 2.4
	e.ssao_power = 1.6
	e.ssao_detail = 0.8
	e.ssil_enabled = true
	e.ssil_radius = 4.0
	e.ssil_intensity = 0.8
	e.ssr_enabled = true
	e.ssr_max_steps = 64
	# Film contrast & saturation grade
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.15
	e.adjustment_saturation = 1.06
	env.environment = e
	root.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.68, 0.74, 0.95)
	moon.light_energy = 0.9
	moon.light_volumetric_fog_energy = 1.4
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_blend_splits = true
	moon.rotation_degrees = Vector3(-62, 28, 0)
	root.add_child(moon)
	for i in ArenaLayout.BRAZIERS.size():
		var p: Vector3 = ArenaLayout.BRAZIERS[i]
		var bowl := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.45
		bm.bottom_radius = 0.2
		bm.height = 1.1
		bowl.mesh = bm
		bowl.position = p + Vector3(0, 0.55, 0)
		bowl.material_override = MaterialKit.surface(&"iron_rusted")
		root.add_child(bowl)
		var fire := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.28
		fm.height = 0.5
		fire.mesh = fm
		fire.position = p + Vector3(0, 1.25, 0)
		fire.material_override = ProcMesh.emissive(Color(1.0, 0.55, 0.2), Color(1.0, 0.45, 0.1), 4.0)
		root.add_child(fire)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.32)
		light.light_energy = 2.4
		light.omni_range = 10.0
		light.light_volumetric_fog_energy = 1.8
		light.shadow_enabled = true
		light.shadow_blur = 1.3
		light.position = p + Vector3(0, 1.8, 0)
		light.set_script(preload("res://game/presentation/flicker.gd"))
		root.add_child(light)
