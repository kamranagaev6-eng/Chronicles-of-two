extends GutTest

const DEFINITION := "res://art/characters/vanguard.json"
const MANIFEST := "res://assets/characters/vanguard/vanguard.build.json"


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary


func test_manifest_matches_its_definition() -> void:
	assert_eq(_manifest()["definition_sha256"], FileAccess.get_sha256(DEFINITION), "rebuild the Vanguard")


func test_manifest_is_within_budget() -> void:
	var m := _manifest()
	assert_lte(int(m["total_triangles"]), 60000)
	assert_almost_eq(float(m["built_height_m"]), 1.8, 0.01)
	for part: String in ["Body", "Headgear", "HairFull", "Prop_Sword", "Sig_Oathshield"]:
		assert_gt(int((m["triangles"] as Dictionary).get(part, 0)), 0, part)
	assert_eq((m["sockets"] as Dictionary)["Sig_Oathshield"], "left_forearm")


const VANGUARD := "res://assets/characters/vanguard/vanguard.glb"


func _scene() -> Node3D:
	var scene: Node3D = (load(VANGUARD) as PackedScene).instantiate()
	add_child_autofree(scene)
	return scene


func test_skeleton_is_retargeted_to_a_t_pose() -> void:
	var sk := _scene().get_node("%GeneralSkeleton") as Skeleton3D
	assert_eq(sk.get_bone_count(), 53)
	for bone: String in ["Root", "Hips", "Spine", "UpperChest", "Head", "LeftUpperArm", "RightHand", "LeftToes"]:
		assert_ne(sk.find_bone(bone), -1, bone)
	var arm := sk.get_bone_global_rest(sk.find_bone("LeftLowerArm")).origin - sk.get_bone_global_rest(sk.find_bone("LeftUpperArm")).origin
	assert_lt(absf(arm.normalized().y), 0.15, "upper arm is level in the rest pose")
	var toes := sk.get_bone_global_rest(sk.find_bone("LeftToes")).origin
	assert_gt(toes.z, sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin.z, "faces +Z")


func test_meshes_follow_the_rules() -> void:
	var scene := _scene()
	var skinned: PackedStringArray = []
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		assert_eq(mi.gi_mode, GeometryInstance3D.GI_MODE_DISABLED, mi.name)
		if mi.skin != null:
			skinned.append(mi.name)
	skinned.sort()
	assert_eq(skinned, PackedStringArray(["Body", "HairFull", "Headgear"]))
	assert_almost_eq(float(scene.get_meta("built_height_m")), 1.8, 0.01)


func test_textures_are_compressed_with_mipmaps() -> void:
	var body := _scene().find_child("Body", true, false) as MeshInstance3D
	var checked := 0
	for s in body.mesh.get_surface_count():
		var mat := body.mesh.surface_get_material(s) as BaseMaterial3D
		if mat != null and mat.albedo_texture is PortableCompressedTexture2D:
			var img := mat.albedo_texture.get_image()
			assert_true(img.is_compressed() and img.has_mipmaps(), mat.resource_name)
			checked += 1
	assert_gt(checked, 0)


func test_outfit_and_skin_materials() -> void:
	var by_name := {}
	for n: Node in _scene().find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			by_name[mat.resource_name] = mat
	for slot: String in ["skin", "eyes", "hair", "brows", "lashes", "steel_plate", "leather", "cloth", "wood", "accent_trim"]:
		assert_has(by_name, slot)
	assert_eq((by_name["steel_plate"] as Material).resource_path, "res://game/characters/materials/steel_plate.tres")
	var skin := by_name["skin"] as BaseMaterial3D
	assert_eq(skin.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_true(skin.subsurf_scatter_enabled)
	assert_eq((by_name["hair"] as BaseMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)


func test_props_sit_on_their_bones() -> void:
	var scene := _scene()
	for pair: Array in [["Prop_Sword", "RightHand"], ["Sig_Oathshield", "LeftLowerArm"]]:
		var socket := scene.find_child(pair[0], true, false).get_parent() as BoneAttachment3D
		assert_not_null(socket, pair[0])
		assert_eq(socket.bone_name, pair[1])


func after_each() -> void:
	CharacterKit.enabled = false
	GameData.character_roster.erase("class|ghost")


func test_no_rig_without_a_window_unless_asked() -> void:
	assert_false(CharacterKit.enabled, "GUT runs headless")
	assert_null(CharacterKit.hero_rig(&"vanguard", Color(0.95, 0.72, 0.25)))


func test_kit_hands_out_rigs_and_survives_bad_rows() -> void:
	CharacterKit.enabled = true
	var rig: CharacterRig = CharacterKit.hero_rig(&"vanguard", Color(0.95, 0.72, 0.25))
	assert_not_null(rig)
	if rig != null:
		add_child_autofree(rig)
	assert_true(CharacterKit.has_hero(&"vanguard"))
	assert_null(CharacterKit.hero_rig(&"riftweaver", Color.WHITE), "no roster row yet: the placeholder is used")
	GameData.character_roster["class|ghost"] = {"for_kind": &"class", "for_id": &"ghost", "character": &"no_such_model", "clip_set": &"vanguard"}
	assert_null(CharacterKit.hero_rig(&"ghost", Color.WHITE), "a missing model gives null, not a crash")
	GameData.character_roster["class|ghost"]["character"] = &"vanguard"
	GameData.character_roster["class|ghost"]["clip_set"] = &"no_such_set"
	assert_null(CharacterKit.hero_rig(&"ghost", Color.WHITE), "an unknown clip set gives null")


func test_git_lfs_pointer_is_not_a_glb() -> void:
	var path: String = "user://character_lfs_pointer_test.glb"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("version https://git-lfs.github.com/spec/v1\noid sha256:placeholder\n")
	file.close()
	assert_false(CharacterKit._has_glb_header(path), "an LFS pointer must not be sent to the scene loader")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0x67, 0x6c, 0x54, 0x46]))
	file.close()
	assert_true(CharacterKit._has_glb_header(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

