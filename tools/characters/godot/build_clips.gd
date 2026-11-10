extends SceneTree

const CLIPS_JSON := "res://art/characters/clips_extra.json"
const OUT_LIB := "res://assets/animations/chronicle/extra.res"

const LIBRARIES: Dictionary = {
	"ual1": "res://assets/animations/quaternius/UAL1_Standard.glb",
	"ual2": "res://assets/animations/quaternius/UAL2_Standard.glb",
}

const ALL_BONES: Array[String] = [
	"Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"LeftThumbMetacarpal", "LeftThumbProximal", "LeftThumbDistal",
	"LeftIndexProximal", "LeftIndexIntermediate", "LeftIndexDistal",
	"LeftMiddleProximal", "LeftMiddleIntermediate", "LeftMiddleDistal",
	"LeftRingProximal", "LeftRingIntermediate", "LeftRingDistal",
	"LeftLittleProximal", "LeftLittleIntermediate", "LeftLittleDistal",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal",
	"RightIndexProximal", "RightIndexIntermediate", "RightIndexDistal",
	"RightMiddleProximal", "RightMiddleIntermediate", "RightMiddleDistal",
	"RightRingProximal", "RightRingIntermediate", "RightRingDistal",
	"RightLittleProximal", "RightLittleIntermediate", "RightLittleDistal",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"
]


func _initialize() -> void:
	var success := _build()
	quit(0 if success else 1)


func _build() -> bool:
	if not FileAccess.file_exists(CLIPS_JSON):
		printerr("build_clips: missing config ", CLIPS_JSON)
		return false

	var raw := FileAccess.get_file_as_string(CLIPS_JSON)
	var config: Variant = JSON.parse_string(raw)
	if not (config is Dictionary and config.has("clips")):
		printerr("build_clips: invalid JSON in ", CLIPS_JSON)
		return false

	var source_libs: Dictionary = {}
	for key: String in LIBRARIES:
		var path: String = LIBRARIES[key]
		if not ResourceLoader.exists(path):
			printerr("build_clips: source library missing ", path)
			return false
		var lib: AnimationLibrary = load(path) as AnimationLibrary
		if lib == null:
			printerr("build_clips: failed to load source library ", path)
			return false
		source_libs[key] = lib

	var out_lib := AnimationLibrary.new()
	var clips_list: Array = config["clips"]

	for clip_spec: Dictionary in clips_list:
		var name: String = clip_spec["name"]
		var op: String = clip_spec["op"]
		var anim: Animation = null

		match op:
			"slice":
				anim = _build_slice(clip_spec, source_libs)
			"sequence":
				anim = _build_sequence(clip_spec, source_libs)
			"pose_loop":
				anim = _build_pose_loop(clip_spec, source_libs)
			_:
				printerr("build_clips: unknown op ", op)
				return false

		if anim == null:
			printerr("build_clips: failed to build clip ", name)
			return false

		out_lib.add_animation(StringName(name), anim)
		print("build_clips: built ", name, " len=", anim.length)

	DirAccess.make_dir_recursive_absolute("res://assets/animations/chronicle")
	var err := ResourceSaver.save(out_lib, OUT_LIB)
	if err != OK:
		printerr("build_clips: failed to save ", OUT_LIB, " err=", err)
		return false

	print("build_clips: saved ", OUT_LIB)
	return true


func _get_source_anim(from_str: String, libs: Dictionary) -> Animation:
	var parts := from_str.split("/")
	if parts.size() != 2:
		printerr("build_clips: invalid source clip specifier: ", from_str)
		return null
	var lib: AnimationLibrary = libs.get(parts[0])
	if lib == null or not lib.has_animation(parts[1]):
		printerr("build_clips: animation missing: ", from_str)
		return null
	return lib.get_animation(parts[1])


func _sample_rot(anim: Animation, bone: String, t: float) -> Quaternion:
	var track := anim.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D)
	if track != -1:
		return anim.rotation_track_interpolate(track, t)
	return Quaternion.IDENTITY


func _sample_pos(anim: Animation, bone: String, t: float) -> Vector3:
	var track := anim.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_POSITION_3D)
	if track != -1:
		return anim.position_track_interpolate(track, t)
	return Vector3.ZERO


## Keep the 30 Hz sample grid and append the exact endpoint, including short final intervals.
func _sample_times(length: float) -> Array[float]:
	var times: Array[float] = []
	for index: int in floori(length * 30.0) + 1:
		var time_s: float = index / 30.0
		if time_s < length:
			times.append(time_s)
	times.append(length)
	return times


func _build_slice(spec: Dictionary, libs: Dictionary) -> Animation:
	var anim := _get_source_anim(spec["from"], libs)
	if anim == null:
		return null
	var start: float = float(spec["start"])
	var end: float = float(spec["end"])
	var length: float = end - start
	if length <= 0.0:
		printerr("build_clips: slice end <= start for ", spec["name"])
		return null

	var out := Animation.new()
	out.length = length

	var times: Array[float] = _sample_times(length)

	for bone: String in ALL_BONES:
		var track_idx := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(track_idx, NodePath("%GeneralSkeleton:" + bone))
		for t_out: float in times:
			var rot := _sample_rot(anim, bone, start + t_out)
			out.rotation_track_insert_key(track_idx, t_out, rot)

	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath("%GeneralSkeleton:Hips"))
	for t_out: float in times:
		var pos := _sample_pos(anim, "Hips", start + t_out)
		out.position_track_insert_key(hips_track, t_out, pos)

	return out


func _build_sequence(spec: Dictionary, libs: Dictionary) -> Animation:
	var parts: Array = spec["parts"]
	var crossfade: float = float(spec.get("crossfade", 0.05))

	var total_len: float = 0.0
	for p: Dictionary in parts:
		# Validate before sampling so a missing source becomes a failed build, never a
		# runtime error followed by a misleading successful save and process exit.
		if _get_source_anim(p["from"], libs) == null:
			return null
		var part_len: float = float(p["end"]) - float(p["start"])
		if part_len <= 0.0:
			printerr("build_clips: sequence part end <= start for ", spec["name"])
			return null
		total_len += part_len

	if total_len <= 0.0:
		return null

	var out := Animation.new()
	out.length = total_len

	var times: Array[float] = _sample_times(total_len)

	for bone: String in ALL_BONES:
		var track_idx := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(track_idx, NodePath("%GeneralSkeleton:" + bone))
		for t_out: float in times:
			var rot := _sample_sequence_rot(parts, crossfade, bone, t_out, libs)
			out.rotation_track_insert_key(track_idx, t_out, rot)

	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath("%GeneralSkeleton:Hips"))
	for t_out: float in times:
		var pos := _sample_sequence_pos(parts, crossfade, "Hips", t_out, libs)
		out.position_track_insert_key(hips_track, t_out, pos)

	return out


func _sample_sequence_rot(parts: Array, crossfade: float, bone: String, t: float, libs: Dictionary) -> Quaternion:
	var acc: float = 0.0
	var prev_last: Quaternion = Quaternion.IDENTITY

	for idx: int in parts.size():
		var p: Dictionary = parts[idx]
		var anim := _get_source_anim(p["from"], libs)
		var p_start: float = float(p["start"])
		var p_end: float = float(p["end"])
		var p_len: float = p_end - p_start

		if t <= acc + p_len or idx == parts.size() - 1:
			var t_in_part: float = clampf(t - acc, 0.0, p_len)
			var cur_rot := _sample_rot(anim, bone, p_start + t_in_part)
			if idx > 0 and crossfade > 0.0 and t_in_part < crossfade:
				var factor: float = t_in_part / crossfade
				return prev_last.slerp(cur_rot, factor)
			return cur_rot

		prev_last = _sample_rot(anim, bone, p_end)
		acc += p_len

	return Quaternion.IDENTITY


func _sample_sequence_pos(parts: Array, crossfade: float, bone: String, t: float, libs: Dictionary) -> Vector3:
	var acc: float = 0.0
	var prev_last: Vector3 = Vector3.ZERO

	for idx: int in parts.size():
		var p: Dictionary = parts[idx]
		var anim := _get_source_anim(p["from"], libs)
		var p_start: float = float(p["start"])
		var p_end: float = float(p["end"])
		var p_len: float = p_end - p_start

		if t <= acc + p_len or idx == parts.size() - 1:
			var t_in_part: float = clampf(t - acc, 0.0, p_len)
			var cur_pos := _sample_pos(anim, bone, p_start + t_in_part)
			if idx > 0 and crossfade > 0.0 and t_in_part < crossfade:
				var factor: float = t_in_part / crossfade
				return prev_last.lerp(cur_pos, factor)
			return cur_pos

		prev_last = _sample_pos(anim, bone, p_end)
		acc += p_len

	return Vector3.ZERO


func _build_pose_loop(spec: Dictionary, libs: Dictionary) -> Animation:
	var anim := _get_source_anim(spec["from"], libs)
	if anim == null:
		return null
	var at: float = float(spec["at"])
	var length: float = float(spec["length"])
	var sways: Array = spec.get("sway", [])
	if length <= 0.0:
		printerr("build_clips: pose-loop length <= 0 for ", spec["name"])
		return null

	var out := Animation.new()
	out.length = length
	out.loop_mode = Animation.LOOP_LINEAR

	var times: Array[float] = _sample_times(length)

	var sway_by_bone: Dictionary = {}
	for s: Dictionary in sways:
		sway_by_bone[s["bone"]] = s

	for bone: String in ALL_BONES:
		var track_idx := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(track_idx, NodePath("%GeneralSkeleton:" + bone))
		var base_rot := _sample_rot(anim, bone, at)
		var has_sway: bool = sway_by_bone.has(bone)

		for t_out: float in times:
			var rot := base_rot
			if has_sway:
				var s: Dictionary = sway_by_bone[bone]
				var axis_arr: Array = s["axis"]
				var axis := Vector3(float(axis_arr[0]), float(axis_arr[1]), float(axis_arr[2])).normalized()
				var deg: float = float(s["degrees"])
				var phase: float = float(s["phase"])
				var angle := deg_to_rad(deg) * sin(TAU * (t_out / length + phase))
				var turn := Quaternion(axis, angle)
				rot = rot * turn
			out.rotation_track_insert_key(track_idx, t_out, rot)

	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath("%GeneralSkeleton:Hips"))
	var base_pos := _sample_pos(anim, "Hips", at)
	for t_out: float in times:
		out.position_track_insert_key(hips_track, t_out, base_pos)

	return out
