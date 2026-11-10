extends SceneTree

const MPFB_BONE_MAP_PATH := "res://game/characters/import/mpfb_bone_map.tres"
const QUATERNIUS_BONE_MAP_PATH := "res://game/characters/import/quaternius_bone_map.tres"
const MATERIALS_DIR := "res://game/characters/materials"

const UE_NAMES := {
	"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03",
	"Neck": "neck_01", "Head": "head",
	"Shoulder": "clavicle", "UpperArm": "upperarm", "LowerArm": "lowerarm", "Hand": "hand",
	"ThumbMetacarpal": "thumb_01", "ThumbProximal": "thumb_02", "ThumbDistal": "thumb_03",
	"IndexProximal": "index_01", "IndexIntermediate": "index_02", "IndexDistal": "index_03",
	"MiddleProximal": "middle_01", "MiddleIntermediate": "middle_02", "MiddleDistal": "middle_03",
	"RingProximal": "ring_01", "RingIntermediate": "ring_02", "RingDistal": "ring_03",
	"LittleProximal": "pinky_01", "LittleIntermediate": "pinky_02", "LittleDistal": "pinky_03",
	"UpperLeg": "thigh", "LowerLeg": "calf", "Foot": "foot", "Toes": "ball",
}


func _init() -> void:
	var failed := false
	var mat_slots: PackedStringArray = []
	var mat_dir := DirAccess.open(MATERIALS_DIR)
	if mat_dir != null:
		mat_dir.list_dir_begin()
		var file_name := mat_dir.get_next()
		while file_name != "":
			if not mat_dir.current_is_dir() and file_name.ends_with(".tres"):
				mat_slots.append(file_name.get_basename())
			file_name = mat_dir.get_next()
		mat_dir.list_dir_end()
	mat_slots.sort()

	# 1. Process character GLBs: res://assets/characters/*/*.glb
	var char_base := "res://assets/characters"
	var char_dir := DirAccess.open(char_base)
	if char_dir != null:
		char_dir.list_dir_begin()
		var sub_dir := char_dir.get_next()
		while sub_dir != "":
			if char_dir.current_is_dir() and not sub_dir.begins_with("."):
				var sub_path := char_base + "/" + sub_dir
				var inner_dir := DirAccess.open(sub_path)
				if inner_dir != null:
					inner_dir.list_dir_begin()
					var glb_file := inner_dir.get_next()
					while glb_file != "":
						if not inner_dir.current_is_dir() and glb_file.ends_with(".glb"):
							var glb_path := sub_path + "/" + glb_file
							if sub_dir == "props":
								if not _process_prop(glb_path, mat_slots):
									failed = true
							elif not _process_character(glb_path, mat_slots):
								failed = true
						glb_file = inner_dir.get_next()
					inner_dir.list_dir_end()
			sub_dir = char_dir.get_next()
		char_dir.list_dir_end()

	# 2. Process Quaternius clips: res://assets/animations/quaternius/*.glb
	var anim_base := "res://assets/animations/quaternius"
	var anim_dir := DirAccess.open(anim_base)
	if anim_dir != null:
		anim_dir.list_dir_begin()
		var glb_file := anim_dir.get_next()
		while glb_file != "":
			if not anim_dir.current_is_dir() and glb_file.ends_with(".glb"):
				var glb_path := anim_base + "/" + glb_file
				if not _process_clip(glb_path):
					failed = true
			glb_file = anim_dir.get_next()
		anim_dir.list_dir_end()

	quit(1 if failed else 0)


func _process_character(glb_path: String, mat_slots: PackedStringArray) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(glb_path, state) != OK:
		printerr("write_imports: failed to read GLB ", glb_path)
		return false
	var scene := doc.generate_scene(state)
	var sk := _skeleton(scene)
	if sk == null:
		printerr("write_imports: no skeleton in ", glb_path)
		scene.free()
		return false
	var skel_path := String(scene.get_path_to(sk))
	var bone_map := _ensure_bone_map(MPFB_BONE_MAP_PATH, sk)

	var import_path := glb_path + ".import"
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(import_path):
		cfg.load(import_path)

	cfg.set_value("remap", "importer", "scene")
	cfg.set_value("remap", "type", "PackedScene")
	cfg.set_value("deps", "source_file", glb_path)
	cfg.set_value("params", "gltf/embedded_image_handling", 2)
	# 1 = "Remap to StandardMaterial3D". A from-scratch .import without the key falls back to 0 ("Do Not Remap").
	cfg.set_value("params", "gltf/texture_map_mode", 1)
	cfg.set_value("params", "animation/import", false)
	cfg.set_value("params", "import_script/path", "res://game/characters/import/character_post_import.gd")

	var sub: Dictionary = cfg.get_value("params", "_subresources", {})
	if not sub.has("nodes"):
		sub["nodes"] = {}
	var skel_key := "PATH:" + skel_path
	var node_sub: Dictionary = sub["nodes"].get(skel_key, {})
	node_sub["retarget/bone_map"] = bone_map
	node_sub["retarget/rest_fixer/fix_silhouette/enable"] = true
	sub["nodes"][skel_key] = node_sub

	if not sub.has("materials"):
		sub["materials"] = {}
	# Only the GLB's own material slots that have a shared material file.
	for mat: Material in state.get_materials():
		var slot := mat.resource_name
		if not mat_slots.has(slot):
			continue
		sub["materials"][slot] = {
			"use_external/enabled": true,
			"use_external/path": MATERIALS_DIR + "/" + slot + ".tres"
		}
	cfg.set_value("params", "_subresources", sub)

	var err := cfg.save(import_path)
	print("write_imports: saved character ", import_path, " err=", err)
	scene.free()
	return err == OK


func _process_prop(glb_path: String, mat_slots: PackedStringArray) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(glb_path, state) != OK:
		printerr("write_imports: failed to read prop GLB ", glb_path)
		return false

	var import_path := glb_path + ".import"
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(import_path):
		cfg.load(import_path)

	cfg.set_value("remap", "importer", "scene")
	cfg.set_value("remap", "type", "PackedScene")
	cfg.set_value("deps", "source_file", glb_path)
	cfg.set_value("params", "gltf/embedded_image_handling", 2)
	cfg.set_value("params", "gltf/texture_map_mode", 1)
	cfg.set_value("params", "animation/import", false)

	var sub: Dictionary = cfg.get_value("params", "_subresources", {})
	if not sub.has("materials"):
		sub["materials"] = {}
	for mat: Material in state.get_materials():
		var slot := mat.resource_name
		if mat_slots.has(slot):
			sub["materials"][slot] = {
				"use_external/enabled": true,
				"use_external/path": MATERIALS_DIR + "/" + slot + ".tres"
			}
	cfg.set_value("params", "_subresources", sub)

	var err := cfg.save(import_path)
	print("write_imports: saved prop ", import_path, " err=", err)
	return err == OK


func _process_clip(glb_path: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(glb_path, state) != OK:
		printerr("write_imports: failed to read clip ", glb_path)
		return false
	var scene := doc.generate_scene(state)
	var sk := _skeleton(scene)
	if sk == null:
		printerr("write_imports: no skeleton in clip ", glb_path)
		scene.free()
		return false
	var skel_path := String(scene.get_path_to(sk))
	var bone_map := _ensure_bone_map(QUATERNIUS_BONE_MAP_PATH, sk)

	var import_path := glb_path + ".import"
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(import_path):
		cfg.load(import_path)

	cfg.set_value("remap", "importer", "animation_library")
	cfg.set_value("remap", "type", "AnimationLibrary")
	cfg.set_value("deps", "source_file", glb_path)
	# Keep rest-valued bone rotations: exact-pose checks and derived clips sample every mapped bone.
	cfg.set_value("params", "animation/remove_immutable_tracks", false)

	var sub: Dictionary = cfg.get_value("params", "_subresources", {})
	if not sub.has("nodes"):
		sub["nodes"] = {}
	var skel_key := "PATH:" + skel_path
	var node_sub: Dictionary = sub["nodes"].get(skel_key, {})
	node_sub["retarget/bone_map"] = bone_map
	node_sub["retarget/remove_tracks/unmapped_bones"] = true
	sub["nodes"][skel_key] = node_sub

	cfg.set_value("params", "_subresources", sub)

	var err := cfg.save(import_path)
	print("write_imports: saved clip ", import_path, " err=", err)
	scene.free()
	return err == OK


func _ensure_bone_map(map_path: String, sk: Skeleton3D) -> BoneMap:
	if FileAccess.file_exists(map_path):
		return load(map_path) as BoneMap
	var bones := {}
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i).to_lower()] = sk.get_bone_name(i)
	var bm := BoneMap.new()
	var profile := SkeletonProfileHumanoid.new()
	bm.profile = profile
	for i in profile.bone_size:
		var pname := String(profile.get_bone_name(i))
		var want := _ue_name(pname)
		if want != "" and bones.has(want):
			bm.set_skeleton_bone_name(pname, bones[want])
	var err := ResourceSaver.save(bm, map_path)
	print("write_imports: created bone map ", map_path, " err=", err)
	return load(map_path) as BoneMap


func _ue_name(profile_bone: String) -> String:
	var side := ""
	var core := profile_bone
	if profile_bone.begins_with("Left"):
		side = "_l"
		core = profile_bone.substr(4)
	elif profile_bone.begins_with("Right"):
		side = "_r"
		core = profile_bone.substr(5)
	if not UE_NAMES.has(core):
		return ""
	return String(UE_NAMES[core]) + side


func _skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c: Node in n.get_children():
		var found := _skeleton(c)
		if found != null:
			return found
	return null
