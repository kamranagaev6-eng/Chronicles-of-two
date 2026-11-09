class_name ProcMesh
extends RefCounted
## Placeholder "Ember Storybook" models built from primitives: one shared proportion family
## (heroes 1.8 m) so heroes, enemies and props read as one world until the CC0 character kit is in.

const GOLD := Color(0.95, 0.72, 0.25)
const VIOLET := Color(0.62, 0.42, 1.0)

static var _cache: Dictionary = {}


static func player_color(color_name: String) -> Color:
	return VIOLET if color_name == "violet" else GOLD


static func material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "m%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	# Cinematic rim lighting for heroic silhouettes against dark backgrounds
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.5
	if metallic > 0.2:
		m.clearcoat_enabled = true
		m.clearcoat_roughness = 0.25
	_cache[key] = m
	return m


static func emissive(color: Color, emission: Color, energy: float = 1.0) -> StandardMaterial3D:
	var key := "e%s|%s|%.2f" % [color.to_html(), emission.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	_cache[key] = m
	return m


static func unshaded(color: Color, transparent: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func part(parent: Node3D, part_name: String, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 6
	return c


static func sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 12
	return c


## A hero: body, head, hair, cloak and class kit. Returns the root; named parts are animated by HeroVisual.
static func build_hero(class_id: StringName, accent: Color) -> Node3D:
	var root := Node3D.new()
	var skin := material(Color(0.86, 0.68, 0.56), 0.7)
	var cloth := material(accent.darkened(0.45), 0.85)
	var trim := emissive(accent, accent, 0.35)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var torso_mat := material(Color(0.55, 0.55, 0.6), 0.45, 0.55) if class_id == &"vanguard" else cloth
	part(body, "Torso", capsule(0.3, 1.05), torso_mat, Vector3(0, 1.05, 0))
	part(body, "Belt", cylinder(0.31, 0.31, 0.08), trim, Vector3(0, 0.82, 0))
	part(body, "LegL", capsule(0.11, 0.8), cloth, Vector3(-0.13, 0.42, 0))
	part(body, "LegR", capsule(0.11, 0.8), cloth, Vector3(0.13, 0.42, 0))
	var head := part(body, "Head", sphere(0.17), skin, Vector3(0, 1.68, 0))
	part(head, "Hair", sphere(0.18), material(Color(0.32, 0.2, 0.14) if class_id == &"vanguard" else Color(0.85, 0.82, 0.92), 0.9), Vector3(0, 0.05, -0.04))
	part(head, "EyeL", sphere(0.025), material(Color(0.1, 0.1, 0.12)), Vector3(-0.06, 0.02, 0.15))
	part(head, "EyeR", sphere(0.025), material(Color(0.1, 0.1, 0.12)), Vector3(0.06, 0.02, 0.15))
	var cloak := part(body, "Cloak", box(Vector3(0.62, 0.95, 0.05)), cloth, Vector3(0, 1.05, -0.3), Vector3(8, 0, 0))
	cloak.material_override = material(accent.darkened(0.25), 0.9)
	var arm_l := Node3D.new()
	arm_l.name = "ArmL"
	arm_l.position = Vector3(-0.38, 1.42, 0)
	body.add_child(arm_l)
	part(arm_l, "Sleeve", capsule(0.09, 0.62), torso_mat, Vector3(0, -0.28, 0))
	var arm_r := Node3D.new()
	arm_r.name = "ArmR"
	arm_r.position = Vector3(0.38, 1.42, 0)
	body.add_child(arm_r)
	part(arm_r, "Sleeve", capsule(0.09, 0.62), torso_mat, Vector3(0, -0.28, 0))
	if class_id == &"vanguard":
		part(body, "Pauldron", box(Vector3(0.9, 0.14, 0.42)), trim, Vector3(0, 1.48, 0))
		var sword := part(arm_r, "Weapon", box(Vector3(0.07, 1.05, 0.14)), material(Color(0.86, 0.88, 0.95), 0.25, 0.9), Vector3(0, -0.55, 0.42), Vector3(90, 0, 0))
		part(sword, "Guard", box(Vector3(0.32, 0.06, 0.08)), trim, Vector3(0, -0.45, 0))
		part(arm_l, "Shield", cylinder(0.36, 0.36, 0.07), material(Color(0.45, 0.42, 0.5), 0.4, 0.6), Vector3(-0.08, -0.35, 0.22), Vector3(0, 0, 90))
		part(arm_l, "ShieldBoss", sphere(0.1), trim, Vector3(-0.13, -0.35, 0.22))
	else:
		var staff := part(arm_r, "Weapon", cylinder(0.03, 0.04, 1.7), material(Color(0.35, 0.24, 0.18), 0.8), Vector3(0, -0.35, 0.18))
		part(staff, "Orb", sphere(0.12), emissive(accent.lightened(0.3), accent, 2.5), Vector3(0, 0.92, 0))
		part(body, "Hood", sphere(0.21), cloth, Vector3(0, 1.72, -0.05))
		part(body, "Book", box(Vector3(0.22, 0.28, 0.08)), trim, Vector3(-0.3, 0.9, 0.05))
	var shadow := MeshInstance3D.new()
	shadow.name = "Blob"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.01
	shadow.mesh = disc
	shadow.position.y = 0.02
	shadow.material_override = unshaded(Color(0, 0, 0, 0.35))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	return root


## Enemies share the hero proportions but read as muted, drowned silhouettes.
static func build_enemy(def: EnemyDefinition) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var scale := def.height / 1.8
	body.scale = Vector3(scale, scale, scale)
	var flesh := material(def.body_color, 0.85)
	var accent := emissive(def.accent_color, def.accent_color, 1.6)
	match def.id:
		&"training_dummy":
			part(body, "Post", cylinder(0.08, 0.1, 1.9), material(Color(0.42, 0.3, 0.2)), Vector3(0, 0.95, 0))
			part(body, "Torso", capsule(0.32, 0.9), material(Color(0.78, 0.66, 0.42), 0.95), Vector3(0, 1.15, 0))
			part(body, "Head", sphere(0.2), material(Color(0.78, 0.66, 0.42), 0.95), Vector3(0, 1.75, 0))
			part(body, "Arms", box(Vector3(1.2, 0.1, 0.1)), material(Color(0.42, 0.3, 0.2)), Vector3(0, 1.35, 0))
		&"oil_barrel", &"water_barrel":
			var c := Color(0.3, 0.22, 0.15) if def.id == &"oil_barrel" else Color(0.35, 0.3, 0.24)
			part(body, "Barrel", cylinder(0.36, 0.4, 0.95), material(c, 0.8), Vector3(0, 0.48, 0))
			var band_col := Color(0.15, 0.13, 0.12) if def.id == &"oil_barrel" else Color(0.25, 0.45, 0.6)
			part(body, "Band", cylinder(0.41, 0.41, 0.08), material(band_col, 0.5, 0.6), Vector3(0, 0.3, 0))
			part(body, "Band2", cylinder(0.39, 0.39, 0.08), material(band_col, 0.5, 0.6), Vector3(0, 0.75, 0))
		_:
			var hunch := 12.0 if def.id == &"drowned_thrall" else 0.0
			part(body, "Torso", capsule(0.3 if def.id != &"crypt_archer" else 0.24, 1.0), flesh, Vector3(0, 1.0, 0), Vector3(hunch, 0, 0))
			part(body, "LegL", capsule(0.1, 0.8), flesh, Vector3(-0.13, 0.4, 0))
			part(body, "LegR", capsule(0.1, 0.8), flesh, Vector3(0.13, 0.4, 0))
			var head := part(body, "Head", sphere(0.17), material(def.body_color.lightened(0.15), 0.8), Vector3(0, 1.62, 0.08 if hunch > 0.0 else 0.0))
			part(head, "EyeL", sphere(0.035), accent, Vector3(-0.06, 0.02, 0.14))
			part(head, "EyeR", sphere(0.035), accent, Vector3(0.06, 0.02, 0.14))
			var arm_l := Node3D.new()
			arm_l.name = "ArmL"
			arm_l.position = Vector3(-0.36, 1.38, 0)
			body.add_child(arm_l)
			part(arm_l, "Sleeve", capsule(0.08, 0.66), flesh, Vector3(0, -0.3, 0))
			var arm_r := Node3D.new()
			arm_r.name = "ArmR"
			arm_r.position = Vector3(0.36, 1.38, 0)
			body.add_child(arm_r)
			part(arm_r, "Sleeve", capsule(0.08, 0.66), flesh, Vector3(0, -0.3, 0))
			match def.id:
				&"drowned_thrall":
					part(arm_r, "Weapon", box(Vector3(0.06, 0.7, 0.12)), material(Color(0.4, 0.42, 0.38), 0.5, 0.5), Vector3(0, -0.6, 0.25), Vector3(70, 0, 0))
					part(body, "Rags", box(Vector3(0.66, 0.5, 0.06)), material(Color(0.2, 0.26, 0.24)), Vector3(0, 0.75, 0.22))
				&"crypt_archer":
					part(arm_l, "Weapon", cylinder(0.025, 0.025, 1.3), material(Color(0.45, 0.32, 0.2)), Vector3(0, -0.35, 0.3), Vector3(10, 0, 0))
					part(body, "Quiver", cylinder(0.08, 0.08, 0.6), material(Color(0.3, 0.2, 0.12)), Vector3(0.15, 1.2, -0.25), Vector3(20, 0, 0))
					part(body, "Hood", sphere(0.2), material(Color(0.3, 0.27, 0.22), 0.9), Vector3(0, 1.66, -0.03))
				&"drowned_knight":
					part(body, "Pauldrons", box(Vector3(1.0, 0.2, 0.5)), material(Color(0.32, 0.36, 0.42), 0.35, 0.7), Vector3(0, 1.45, 0))
					part(body, "Helm", cylinder(0.19, 0.21, 0.32), material(Color(0.32, 0.36, 0.42), 0.35, 0.7), Vector3(0, 1.7, 0))
					part(body, "Visor", box(Vector3(0.24, 0.04, 0.05)), accent, Vector3(0, 1.72, 0.2))
					part(arm_l, "Shield", box(Vector3(0.12, 1.0, 0.7)), material(Color(0.28, 0.3, 0.34), 0.4, 0.6), Vector3(-0.1, -0.35, 0.25))
					part(arm_r, "Weapon", box(Vector3(0.2, 0.9, 0.2)), material(Color(0.3, 0.3, 0.32), 0.5, 0.7), Vector3(0, -0.7, 0.2), Vector3(60, 0, 0))
	var shadow := MeshInstance3D.new()
	shadow.name = "Blob"
	var disc := CylinderMesh.new()
	disc.top_radius = def.radius * 1.1
	disc.bottom_radius = def.radius * 1.1
	disc.height = 0.01
	shadow.mesh = disc
	shadow.position.y = 0.02
	shadow.material_override = unshaded(Color(0, 0, 0, 0.35))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	return root


static func element_color(element: StringName) -> Color:
	match element:
		&"fire":
			return Color(1.0, 0.5, 0.15)
		&"cold":
			return Color(0.55, 0.85, 1.0)
		&"lightning":
			return Color(0.6, 0.65, 1.0)
		&"holy":
			return Color(1.0, 0.86, 0.45)
		&"arcane":
			return Color(0.8, 0.5, 1.0)
		&"poison":
			return Color(0.5, 0.9, 0.3)
	return Color(0.95, 0.92, 0.88)
