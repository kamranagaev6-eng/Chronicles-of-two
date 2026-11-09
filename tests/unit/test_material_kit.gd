extends GutTest
## Photoscan material library: every kind loads its texture maps, every downloaded map is used,
## and tinted variants are cached copies that leave the shared base untouched.

const TRIPLANAR := "res://game/presentation/shaders/pbr_triplanar.gdshader"
const GROUND := "res://game/presentation/shaders/ground_surface.gdshader"
const TEXTURE_DIR := "res://assets/textures/ambientcg"


func _texture_path(mat: ShaderMaterial, param: StringName) -> String:
	var tex: Variant = mat.get_shader_parameter(param)
	return (tex as Texture2D).resource_path if tex is Texture2D else ""


func test_every_kind_uses_the_triplanar_shader_and_core_maps() -> void:
	for kind: StringName in MaterialKit.KINDS:
		var mat: ShaderMaterial = MaterialKit.KINDS[kind]
		assert_not_null(mat, "%s loads" % kind)
		assert_eq(mat.shader.resource_path, TRIPLANAR, "%s uses the triplanar shader" % kind)
		for param: StringName in [&"albedo_tex", &"normal_tex", &"roughness_tex"]:
			var path := _texture_path(mat, param)
			assert_true(path.begins_with(TEXTURE_DIR + "/"), "%s has %s from the photoscan sets (got '%s')" % [kind, param, path])
		assert_gt(float(mat.get_shader_parameter(&"albedo_mean")), 0.0, "%s knows its colour map's mean luminance" % kind)
		var use_metal: Variant = mat.get_shader_parameter(&"use_metal_tex")
		if use_metal != null and bool(use_metal):
			assert_true(_texture_path(mat, &"metal_tex").ends_with("_Metalness.jpg"), "%s reads a metalness map" % kind)


func test_ground_material_has_the_height_map_for_surface_blending() -> void:
	var ground := MaterialKit.GROUND
	assert_eq(ground.shader.resource_path, GROUND)
	for param: StringName in [&"albedo_tex", &"normal_tex", &"roughness_tex", &"ao_tex", &"height_tex"]:
		assert_true(_texture_path(ground, param).begins_with(TEXTURE_DIR + "/Tiles093/"), "ground %s" % param)


func test_every_downloaded_map_is_used_by_a_material() -> void:
	var used: Dictionary[String, bool] = {}
	var materials: Array[ShaderMaterial] = [MaterialKit.GROUND]
	for kind: StringName in MaterialKit.KINDS:
		materials.append(MaterialKit.KINDS[kind])
	for mat: ShaderMaterial in materials:
		for param: StringName in [&"albedo_tex", &"normal_tex", &"roughness_tex", &"ao_tex", &"metal_tex", &"height_tex"]:
			var path := _texture_path(mat, param)
			if not path.is_empty():
				used[path] = true
	var files: PackedStringArray = PackedStringArray()
	for set_name: String in DirAccess.get_directories_at(TEXTURE_DIR):
		for file: String in DirAccess.get_files_at(TEXTURE_DIR.path_join(set_name)):
			if file.ends_with(".jpg"):
				files.append(TEXTURE_DIR.path_join(set_name).path_join(file))
	assert_gt(files.size(), 0, "the photoscan maps are on disk (run tools/fetch_textures.ps1)")
	for path: String in files:
		assert_true(used.has(path), "%s is sampled by some material" % path)


func test_plain_request_returns_the_shared_base() -> void:
	assert_same(MaterialKit.surface(&"steel_worn"), MaterialKit.KINDS[&"steel_worn"])


func test_tinted_variant_is_a_cached_copy_and_leaves_the_base_alone() -> void:
	var base: ShaderMaterial = MaterialKit.KINDS[&"cloth"]
	var base_tint: Variant = base.get_shader_parameter(&"tint")
	var gold := MaterialKit.surface(&"cloth", Color(0.95, 0.72, 0.25), {&"damp": 0.4})
	assert_ne(gold, base, "a tint makes a copy")
	assert_eq(gold.get_shader_parameter(&"tint"), Color(0.95, 0.72, 0.25))
	assert_almost_eq(float(gold.get_shader_parameter(&"damp")), 0.4, 0.0001)
	assert_eq(base.get_shader_parameter(&"tint"), base_tint, "the shared base keeps its tint")
	assert_same(MaterialKit.surface(&"cloth", Color(0.95, 0.72, 0.25), {&"damp": 0.4}), gold, "same request, same cached material")


func test_trim_glows_in_the_accent_colour() -> void:
	var violet := Color(0.62, 0.42, 1.0)
	var trim := MaterialKit.trim(violet)
	assert_eq(trim.get_shader_parameter(&"tint"), violet)
	assert_eq(trim.get_shader_parameter(&"emission_color"), violet)
	assert_gt(float(trim.get_shader_parameter(&"emission_energy")), 0.0)


func test_heroes_and_enemies_are_built_from_photoscan_materials() -> void:
	var hero := ProcMesh.build_hero(&"vanguard", ProcMesh.GOLD)
	var torso := hero.get_node("Body/Torso") as MeshInstance3D
	assert_true(torso.material_override is ShaderMaterial, "the Vanguard's armour is a photoscan material")
	assert_not_null(hero.get_node_or_null("Body/ArmL/Shield/Rim"), "the shield rim hides with the shield")
	hero.free()
	var def := EnemyDefinition.new()
	def.id = &"drowned_thrall"
	def.height = 1.8
	def.radius = 0.4
	var enemy := ProcMesh.build_enemy(def)
	var flesh := (enemy.get_node("Body/Torso") as MeshInstance3D).material_override as ShaderMaterial
	assert_not_null(flesh)
	assert_eq(flesh.get_shader_parameter(&"tint"), def.body_color, "drowned flesh is tinted by the enemy colour")
	enemy.free()
