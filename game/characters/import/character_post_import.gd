@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	var source_path := get_source_file()
	var base_path := source_path.get_basename()
	var manifest_path := base_path + ".build.json"
	if not FileAccess.file_exists(manifest_path):
		push_error("character_post_import: manifest %s missing for %s" % [manifest_path, source_path])
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		push_error("character_post_import: manifest %s is not a JSON object, for %s" % [manifest_path, source_path])
		return null
	var manifest: Dictionary = parsed
	var height: Variant = manifest.get("built_height_m")
	if not (height is float or height is int):
		push_error("character_post_import: manifest %s has no numeric built_height_m, for %s" % [manifest_path, source_path])
		return null
	scene.set_meta("built_height_m", float(height))

	var sk := scene.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if sk == null:
		push_error("character_post_import: no GeneralSkeleton found in " + source_path)
		return null
	sk.unique_name_in_owner = true

	var skinned_count := 0
	for n: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if gi is MeshInstance3D and (gi as MeshInstance3D).skin != null:
			skinned_count += 1

	if skinned_count > 3:
		push_error("character_post_import: more than three skinned meshes (%d) in %s" % [skinned_count, source_path])
		return null

	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			match mat.resource_name:
				"skin":
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.subsurf_scatter_enabled = true
					mat.subsurf_scatter_strength = 0.3
					mat.subsurf_scatter_skin_mode = true
					mat.roughness = 0.58
					mat.normal_scale = 0.6
				"hair", "brows", "lashes":
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.35
					mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat.roughness = 0.55
				"eyes":
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.roughness = 0.15

	var sockets: Dictionary = manifest.get("sockets", {})
	for prop_name: String in sockets:
		var prop := scene.find_child(prop_name, true, false) as Node3D
		if prop == null:
			push_error("character_post_import: prop %s missing from %s" % [prop_name, source_path])
			return null
		var socket_type: String = str(sockets[prop_name])
		var bone_name := ""
		if socket_type == "right_hand_grip":
			bone_name = "RightHand"
		elif socket_type == "left_forearm":
			bone_name = "LeftLowerArm"
		elif socket_type == "spine_belt":
			bone_name = "Spine" if sk.find_bone("Spine") != -1 else "Hips"
		else:
			push_error("character_post_import: unknown socket type %s for %s" % [socket_type, prop_name])
			return null

		var bone_idx := sk.find_bone(bone_name)
		if bone_idx == -1:
			push_error("character_post_import: skeleton missing bone %s for %s" % [bone_name, prop_name])
			return null

		var attachment := BoneAttachment3D.new()
		attachment.name = prop_name + "_Socket"
		attachment.bone_name = bone_name
		sk.add_child(attachment)
		attachment.owner = scene

		var parent := prop.get_parent()
		if parent != null:
			prop.owner = null
			parent.remove_child(prop)
		attachment.add_child(prop)
		prop.owner = scene

		if socket_type == "right_hand_grip":
			var hand_rest := sk.get_bone_global_rest(bone_idx)
			var fingers_idx := sk.find_bone("RightMiddleProximal")
			var fingers := Vector3(0, 0, 1)
			if fingers_idx != -1:
				fingers = (sk.get_bone_global_rest(fingers_idx).origin - hand_rest.origin).normalized()
			var sword_rest := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
				hand_rest.origin + fingers * 0.09 + Vector3(0, -0.04, 0))
			prop.transform = hand_rest.affine_inverse() * sword_rest
		elif socket_type == "left_forearm":
			var fore_rest := sk.get_bone_global_rest(bone_idx)
			var wrist_idx := sk.find_bone("LeftHand")
			var wrist := fore_rest.origin + Vector3(0, 0.25, 0)
			if wrist_idx != -1:
				wrist = sk.get_bone_global_rest(wrist_idx).origin
			prop.transform = fore_rest.affine_inverse() * Transform3D(Basis.IDENTITY, fore_rest.origin.lerp(wrist, 0.6) + Vector3(0, 0.075, 0))
		elif socket_type == "spine_belt":
			var spine_rest := sk.get_bone_global_rest(bone_idx)
			var belt_target := Transform3D(Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)),
				spine_rest.origin + Vector3(0.19, -0.06, -0.03))
			prop.transform = spine_rest.affine_inverse() * belt_target

	return scene
