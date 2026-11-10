extends "res://tools/characters/godot/build_clips.gd"
## Exercise the real builder on short synthetic clips without modifying project assets.


func _initialize() -> void:
	var source: Animation = Animation.new()
	source.length = 1.0
	var rotation: int = source.add_track(Animation.TYPE_ROTATION_3D)
	source.track_set_path(rotation, NodePath("%GeneralSkeleton:Spine"))
	source.rotation_track_insert_key(rotation, 0.0, Quaternion.IDENTITY)
	source.rotation_track_insert_key(rotation, 1.0, Quaternion(Vector3.UP, 0.7))
	var position: int = source.add_track(Animation.TYPE_POSITION_3D)
	source.track_set_path(position, NodePath("%GeneralSkeleton:Hips"))
	source.position_track_insert_key(position, 0.0, Vector3.ZERO)
	source.position_track_insert_key(position, 1.0, Vector3(0.2, 1.0, 0.0))
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(&"source", source)
	var libraries: Dictionary = {"probe": library}
	var missing: Animation = _build_sequence({"name": "missing", "parts": [
		{"from": "probe/no_such_clip", "start": 0.0, "end": 0.341}]}, libraries)
	if missing != null:
		printerr("A missing sequence source must fail the build")
		quit(1)
		return
	var animations: Array[Animation] = [
		_build_slice({"name": "slice", "from": "probe/source", "start": 0.0, "end": 0.341}, libraries),
		_build_sequence({"name": "sequence", "parts": [
			{"from": "probe/source", "start": 0.0, "end": 0.341}]}, libraries),
		_build_pose_loop({"name": "pose", "from": "probe/source", "at": 0.0, "length": 0.341}, libraries),
	]
	for animation: Animation in animations:
		if animation == null:
			quit(1)
			return
		for track: int in animation.get_track_count():
			var last: int = animation.track_get_key_count(track) - 1
			if last < 0 or not is_equal_approx(animation.track_get_key_time(track, last), animation.length):
				printerr("A fractional clip is missing its final sample")
				quit(1)
				return
	print("clip builder probe passed")
	quit(0)
