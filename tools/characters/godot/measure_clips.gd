extends SceneTree

const VANGUARD := "res://assets/characters/vanguard/vanguard.glb"
const UAL1 := "res://assets/animations/quaternius/UAL1_Standard.glb"
const UAL2 := "res://assets/animations/quaternius/UAL2_Standard.glb"
const EXTRA := "res://assets/animations/chronicle/extra.res"


func _initialize() -> void:
	_run()


func _run() -> void:
	if not FileAccess.file_exists(VANGUARD):
		printerr("measure_clips: vanguard GLB missing: ", VANGUARD)
		quit(1)
		return

	var hero: Node3D = (load(VANGUARD) as PackedScene).instantiate()
	root.add_child(hero)
	var sk := hero.get_node("%GeneralSkeleton") as Skeleton3D
	if sk == null:
		printerr("measure_clips: skeleton %GeneralSkeleton missing in vanguard")
		hero.free()
		quit(1)
		return

	var ap := AnimationPlayer.new()
	hero.add_child(ap)
	if FileAccess.file_exists(UAL1):
		ap.add_animation_library(&"ual1", load(UAL1))
	if FileAccess.file_exists(UAL2):
		ap.add_animation_library(&"ual2", load(UAL2))
	if FileAccess.file_exists(EXTRA):
		ap.add_animation_library(&"extra", load(EXTRA))

	await process_frame
	var rh := sk.find_bone("RightHand")
	var lh := sk.find_bone("LeftHand")
	var hips := sk.find_bone("Hips")

	for anim_name: String in ap.get_animation_list():
		var anim := ap.get_animation(anim_name)
		ap.play(anim_name)
		var steps := int(anim.length * 60.0)
		var prev_r := Vector3.ZERO
		var prev_l := Vector3.ZERO
		var best_r := 0.0
		var best_l := 0.0
		var t_r := 0.0
		var t_l := 0.0
		var low := 99.0
		var t_low := 0.0

		for i in steps + 1:
			var t := i / 60.0
			ap.seek(t, true)
			var r := sk.get_bone_global_pose(rh).origin if rh != -1 else Vector3.ZERO
			var l := sk.get_bone_global_pose(lh).origin if lh != -1 else Vector3.ZERO
			var h := sk.get_bone_global_pose(hips).origin.y if hips != -1 else 0.0
			if i > 0:
				var vr := r.distance_to(prev_r) * 60.0
				var vl := l.distance_to(prev_l) * 60.0
				if vr > best_r:
					best_r = vr
					t_r = t
				if vl > best_l:
					best_l = vl
					t_l = t
			if h < low:
				low = h
				t_low = t
			prev_r = r
			prev_l = l

		print("MEASURE %-30s len=%.2f loop=%d rhand_peak=%.2fs (%.1f m/s) lhand_peak=%.2fs (%.1f m/s) hips_low=%.2fs (%.2f m)" % [
			anim_name, anim.length, anim.loop_mode, t_r, best_r, t_l, best_l, t_low, low])

	hero.free()
	quit(0)
