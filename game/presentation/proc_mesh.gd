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
	var skin := MaterialKit.skin(Color(0.86, 0.68, 0.56))
	var cloth := MaterialKit.surface(&"cloth", accent.darkened(0.55))
	var trim := MaterialKit.trim(accent)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var torso_mat: Material = MaterialKit.surface(&"steel_worn") if class_id == &"vanguard" else MaterialKit.surface(&"cloth", accent.darkened(0.4))
	part(body, "Torso", capsule(0.3, 1.05), torso_mat, Vector3(0, 1.05, 0))
	part(body, "Belt", cylinder(0.31, 0.31, 0.08), trim, Vector3(0, 0.82, 0))
	part(body, "LegL", capsule(0.11, 0.8), cloth, Vector3(-0.13, 0.42, 0))
	part(body, "LegR", capsule(0.11, 0.8), cloth, Vector3(0.13, 0.42, 0))
	var head := part(body, "Head", sphere(0.17), skin, Vector3(0, 1.68, 0))
	var hair_color := Color(0.32, 0.2, 0.14) if class_id == &"vanguard" else Color(0.85, 0.82, 0.92)
	part(head, "Hair", sphere(0.18), MaterialKit.surface(&"hair", hair_color), Vector3(0, 0.05, -0.04))
	part(head, "EyeL", sphere(0.025), material(Color(0.1, 0.1, 0.12), 0.2), Vector3(-0.06, 0.02, 0.15))
	part(head, "EyeR", sphere(0.025), material(Color(0.1, 0.1, 0.12), 0.2), Vector3(0.06, 0.02, 0.15))
	var cloak := part(body, "Cloak", box(Vector3(0.62, 0.95, 0.05)), cloth, Vector3(0, 1.05, -0.3), Vector3(8, 0, 0))
	cloak.material_override = MaterialKit.surface(&"cloth", accent.darkened(0.25), {&"grime_height": 0.6})
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
		var blade := MaterialKit.surface(&"steel_worn", Color.WHITE, {&"brightness": 2.4, &"roughness_scale": 0.45, &"tiles_per_metre": 2.5})
		var sword := part(arm_r, "Weapon", box(Vector3(0.07, 1.05, 0.14)), blade, Vector3(0, -0.55, 0.42), Vector3(90, 0, 0))
		part(sword, "Guard", box(Vector3(0.32, 0.06, 0.08)), trim, Vector3(0, -0.45, 0))
		part(sword, "Grip", cylinder(0.025, 0.025, 0.22), MaterialKit.surface(&"leather"), Vector3(0, -0.6, 0))
		var shield := part(arm_l, "Shield", cylinder(0.36, 0.36, 0.07), MaterialKit.surface(&"wood_planks", Color.WHITE, {&"tiles_per_metre": 1.6}), Vector3(-0.08, -0.35, 0.22), Vector3(0, 0, 90))
		# Child of the shield so it hides with it while the shield is thrown.
		part(shield, "Rim", cylinder(0.375, 0.375, 0.05), MaterialKit.surface(&"iron_rusted"), Vector3.ZERO)
		part(arm_l, "ShieldBoss", sphere(0.1), trim, Vector3(-0.13, -0.35, 0.22))
	else:
		var staff := part(arm_r, "Weapon", cylinder(0.03, 0.04, 1.7), MaterialKit.surface(&"wood_grain"), Vector3(0, -0.35, 0.18))
		part(staff, "Orb", sphere(0.12), emissive(accent.lightened(0.3), accent, 2.5), Vector3(0, 0.92, 0))
		part(body, "Hood", sphere(0.21), cloth, Vector3(0, 1.72, -0.05))
		part(body, "Book", box(Vector3(0.22, 0.28, 0.08)), MaterialKit.surface(&"leather", accent.darkened(0.3), {&"tint_strength": 0.6}), Vector3(-0.3, 0.9, 0.05))
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
	var flesh := MaterialKit.surface(&"drowned_flesh", def.body_color)
	var accent := emissive(def.accent_color, def.accent_color, 1.6)
	match def.id:
		&"training_dummy":
			var post := MaterialKit.surface(&"wood_grain")
			var sack := MaterialKit.surface(&"burlap")
			part(body, "Post", cylinder(0.08, 0.1, 1.9), post, Vector3(0, 0.95, 0))
			part(body, "Torso", capsule(0.32, 0.9), sack, Vector3(0, 1.15, 0))
			part(body, "Head", sphere(0.2), sack, Vector3(0, 1.75, 0))
			part(body, "Arms", box(Vector3(1.2, 0.1, 0.1)), post, Vector3(0, 1.35, 0))
			part(body, "Rope", cylinder(0.33, 0.33, 0.05), MaterialKit.surface(&"burlap", Color(0.55, 0.45, 0.3), {&"tint_strength": 0.5, &"tiles_per_metre": 4.0}), Vector3(0, 1.35, 0))
		&"oil_barrel", &"water_barrel":
			var oil := def.id == &"oil_barrel"
			var staves := MaterialKit.surface(&"wood_planks", Color.WHITE, {&"brightness": 0.75 if oil else 1.3, &"damp": 0.2 if oil else 0.7})
			part(body, "Barrel", cylinder(0.36, 0.4, 0.95), staves, Vector3(0, 0.48, 0))
			var bands := MaterialKit.surface(&"iron_rusted") if oil else MaterialKit.surface(&"steel_worn", Color(0.25, 0.45, 0.6), {&"tint_strength": 0.45})
			part(body, "Band", cylinder(0.41, 0.41, 0.08), bands, Vector3(0, 0.3, 0))
			part(body, "Band2", cylinder(0.39, 0.39, 0.08), bands, Vector3(0, 0.75, 0))
			part(body, "Lid", cylinder(0.33, 0.33, 0.03), staves, Vector3(0, 0.96, 0))
		_:
			var hunch := 12.0 if def.id == &"drowned_thrall" else 0.0
			part(body, "Torso", capsule(0.3 if def.id != &"crypt_archer" else 0.24, 1.0), flesh, Vector3(0, 1.0, 0), Vector3(hunch, 0, 0))
			part(body, "LegL", capsule(0.1, 0.8), flesh, Vector3(-0.13, 0.4, 0))
			part(body, "LegR", capsule(0.1, 0.8), flesh, Vector3(0.13, 0.4, 0))
			var head := part(body, "Head", sphere(0.17), MaterialKit.surface(&"drowned_flesh", def.body_color.lightened(0.15)), Vector3(0, 1.62, 0.08 if hunch > 0.0 else 0.0))
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
					part(arm_r, "Weapon", box(Vector3(0.06, 0.7, 0.12)), MaterialKit.surface(&"iron_rusted", Color.WHITE, {&"tiles_per_metre": 2.0}), Vector3(0, -0.6, 0.25), Vector3(70, 0, 0))
					part(body, "Rags", box(Vector3(0.66, 0.5, 0.06)), MaterialKit.surface(&"cloth", Color(0.2, 0.26, 0.24), {&"damp": 0.8, &"moss": 0.4}), Vector3(0, 0.75, 0.22))
				&"crypt_archer":
					part(arm_l, "Weapon", cylinder(0.025, 0.025, 1.3), MaterialKit.surface(&"wood_grain", Color.WHITE, {&"tiles_per_metre": 2.5}), Vector3(0, -0.35, 0.3), Vector3(10, 0, 0))
					part(body, "Quiver", cylinder(0.08, 0.08, 0.6), MaterialKit.surface(&"leather"), Vector3(0.15, 1.2, -0.25), Vector3(20, 0, 0))
					part(body, "Hood", sphere(0.2), MaterialKit.surface(&"cloth", Color(0.3, 0.27, 0.22), {&"damp": 0.5}), Vector3(0, 1.66, -0.03))
				&"drowned_knight":
					var armour := MaterialKit.surface(&"steel_worn", Color(0.32, 0.36, 0.42), {&"tint_strength": 0.35, &"moss": 0.45, &"damp": 0.6, &"brightness": 1.2})
					part(body, "Pauldrons", box(Vector3(1.0, 0.2, 0.5)), armour, Vector3(0, 1.45, 0))
					part(body, "Helm", cylinder(0.19, 0.21, 0.32), armour, Vector3(0, 1.7, 0))
					part(body, "Visor", box(Vector3(0.24, 0.04, 0.05)), accent, Vector3(0, 1.72, 0.2))
					part(arm_l, "Shield", box(Vector3(0.12, 1.0, 0.7)), MaterialKit.surface(&"steel_worn", Color(0.28, 0.3, 0.34), {&"tint_strength": 0.4, &"moss": 0.55, &"damp": 0.7}), Vector3(-0.1, -0.35, 0.25))
					part(arm_r, "Weapon", box(Vector3(0.2, 0.9, 0.2)), MaterialKit.surface(&"iron_rusted"), Vector3(0, -0.7, 0.2), Vector3(60, 0, 0))
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
