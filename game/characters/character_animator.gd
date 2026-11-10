class_name CharacterAnimator
extends Node
## One character's animation graph. Simulation time pins actions; only locomotion advances freely.

const LIBRARIES: Dictionary = {
	&"ual1": "res://assets/animations/quaternius/UAL1_Standard.glb",
	&"ual2": "res://assets/animations/quaternius/UAL2_Standard.glb",
	&"extra": "res://assets/animations/chronicle/extra.res",
}
const LOCOMOTION_ROLES: Array[StringName] = [&"idle", &"walk", &"jog", &"sprint"]

var last_locomotion_rate: float = 1.0

var _skeleton: Skeleton3D
var _tree: AnimationTree
var _graph: AnimationNodeBlendTree
var _cycles: Array[ClipSet.ClipRow] = []
var _warned: Dictionary[StringName, bool] = {}
var _base: AnimationNodeAnimation
var _full: AnimationNodeAnimation
var _upper: AnimationNodeAnimation
var _over: AnimationNodeAnimation
var _base_weight: float = 0.0
var _full_weight: float = 0.0
var _upper_weight: float = 0.0
var _over_weight: float = 0.0
var _base_time: float = -1.0
var _full_time: float = 0.0
var _upper_time: float = 0.0
var _over_time: float = 0.0
var _hips: int = -1
var _spine: int = -1
var _untwisted_hips: Quaternion = Quaternion.IDENTITY
var _untwisted_spine: Quaternion = Quaternion.IDENTITY
var _twisted: bool = false


func setup(skeleton: Skeleton3D, clips: ClipSet) -> void:
	_skeleton = skeleton
	_hips = skeleton.find_bone("Hips")
	_spine = skeleton.find_bone("Spine")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	add_child(_tree)
	# The animator may be outside the imported scene, whose owner resolves its unique skeleton name.
	var animation_root: Node = skeleton.owner if skeleton.owner != null else skeleton.get_parent()
	_tree.root_node = _tree.get_path_to(animation_root)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key: StringName in LIBRARIES:
		var path: String = LIBRARIES[key]
		if not ResourceLoader.exists(path):
			_warn_once(key, "CharacterAnimator: animation library missing: " + path)
			continue
		var source: AnimationLibrary = load(path) as AnimationLibrary
		if source != null:
			# A light library of this rig's own shares the cached clips; only a clip whose loop flag
			# must change is copied, so a cached import is never mutated.
			var library: AnimationLibrary = AnimationLibrary.new()
			for clip_name: StringName in source.get_animation_list():
				library.add_animation(clip_name, source.get_animation(clip_name))
			for row: ClipSet.ClipRow in clips.all_rows():
				var parts: PackedStringArray = String(row.clip).split("/")
				if row.loop and parts.size() == 2 and StringName(parts[0]) == key and library.has_animation(parts[1]):
					var shared: Animation = library.get_animation(parts[1])
					if shared.loop_mode != Animation.LOOP_LINEAR:
						var own: Animation = shared.duplicate() as Animation
						own.loop_mode = Animation.LOOP_LINEAR
						library.add_animation(parts[1], own)
			_tree.add_animation_library(key, library)

	_graph = AnimationNodeBlendTree.new()
	var space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 1.0
	space.sync = true
	for role: StringName in LOCOMOTION_ROLES:
		var row: ClipSet.ClipRow = clips.row(role)
		if row == null or not _valid_clip(row.clip):
			continue
		var cycle: AnimationNodeAnimation = AnimationNodeAnimation.new()
		cycle.animation = row.clip
		space.add_blend_point(cycle, row.speed_mps, -1, role)
		space.max_space = maxf(space.max_space, row.speed_mps)
		_cycles.append(row)
	_cycles.sort_custom(func(a: ClipSet.ClipRow, b: ClipSet.ClipRow) -> bool: return a.speed_mps < b.speed_mps)
	_graph.add_node(&"Loco", space)
	_graph.add_node(&"LocoScale", AnimationNodeTimeScale.new())
	_graph.connect_node(&"LocoScale", 0, &"Loco")

	var idle: ClipSet.ClipRow = clips.base_row(&"idle")
	var initial_clip: StringName = idle.clip if idle != null and _tree.has_animation(idle.clip) else &""
	_base = _seek_layer(&"Base", &"BaseSeek", initial_clip)
	_full = _seek_layer(&"ActFull", &"ActFullSeek", initial_clip)
	_upper = _seek_layer(&"ActUpper", &"ActUpperSeek", initial_clip)
	_over = _seek_layer(&"Over", &"OverSeek", initial_clip)
	_mix(&"BaseMix", &"LocoScale", &"BaseSeek", false)
	_mix(&"FullMix", &"BaseMix", &"ActFullSeek", false)
	_mix(&"UpperMix", &"FullMix", &"ActUpperSeek", true)
	_mix(&"OverMix", &"UpperMix", &"OverSeek", true)
	_graph.connect_node(&"output", 0, &"OverMix")
	_tree.tree_root = _graph
	_tree.active = true


func apply(pose: AnimPose, delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or _tree == null:
		return
	var speed: float = maxf(pose.speed_mps, 0.0) if is_finite(pose.speed_mps) else 0.0
	var angle: float = wrapf(pose.move_angle, -PI, PI) if is_finite(pose.move_angle) else 0.0
	last_locomotion_rate = _locomotion_rate(speed)
	if absf(angle) > deg_to_rad(100.0):
		last_locomotion_rate = -last_locomotion_rate
		angle -= signf(angle) * PI
	_tree.set("parameters/Loco/blend_position", speed)
	_tree.set("parameters/LocoScale/scale", last_locomotion_rate)

	if pose.locomotion:
		_base_weight = lerpf(_base_weight, 0.0, minf(1.0, delta * 8.0))
	elif _valid_clip(pose.base_clip):
		_base.animation = pose.base_clip
		_base_time = pose.base_time_s
		_base_weight = lerpf(_base_weight, 1.0, minf(1.0, delta * 8.0))
	_tree.set("parameters/BaseMix/blend_amount", _base_weight)
	if _base_time >= 0.0:
		_tree.set("parameters/BaseSeek/seek_request", _base_time)

	if pose.action_clip.is_empty():
		_full_weight = lerpf(_full_weight, 0.0, minf(1.0, delta * 12.0))
		_upper_weight = lerpf(_upper_weight, 0.0, minf(1.0, delta * 12.0))
	elif _valid_clip(pose.action_clip):
		if pose.action_upper:
			_upper.animation = pose.action_clip
			_upper_time = pose.action_time_s
		else:
			_full.animation = pose.action_clip
			_full_time = pose.action_time_s
		_full_weight = lerpf(_full_weight, 0.0 if pose.action_upper else 1.0, minf(1.0, delta * 12.0))
		_upper_weight = lerpf(_upper_weight, 1.0 if pose.action_upper else 0.0, minf(1.0, delta * 12.0))
	_tree.set("parameters/FullMix/blend_amount", _full_weight)
	_tree.set("parameters/UpperMix/blend_amount", _upper_weight)
	# Re-seek the retained clip too: an unknown replacement must hold its last valid action pose.
	_tree.set("parameters/ActFullSeek/seek_request", _full_time)
	_tree.set("parameters/ActUpperSeek/seek_request", _upper_time)

	if pose.overlay_clip.is_empty():
		_over_weight = 0.0
	elif _valid_clip(pose.overlay_clip):
		_over.animation = pose.overlay_clip
		_over_time = pose.overlay_time_s
		_over_weight = 0.6
	_tree.set("parameters/OverMix/blend_amount", _over_weight)
	_tree.set("parameters/OverSeek/seek_request", _over_time)

	# Remove the last presentation twist before mixing, including tracks with zero blend weight.
	if _twisted:
		_skeleton.set_bone_pose_rotation(_hips, _untwisted_hips)
		_skeleton.set_bone_pose_rotation(_spine, _untwisted_spine)
	_tree.advance(delta)
	# The twist belongs to the walk only: scale it by the lower body's locomotion share.
	angle *= (1.0 - _base_weight) * (1.0 - _full_weight)
	if _hips >= 0 and _spine >= 0:
		_untwisted_hips = _skeleton.get_bone_pose_rotation(_hips)
		_untwisted_spine = _skeleton.get_bone_pose_rotation(_spine)
		_skeleton.set_bone_pose_rotation(_hips, Quaternion(Vector3.UP, angle) * _untwisted_hips)
		_skeleton.set_bone_pose_rotation(_spine, Quaternion(Vector3.UP, -angle) * _untwisted_spine)
		_twisted = true


func _seek_layer(animation_name: StringName, seek_name: StringName, initial_clip: StringName) -> AnimationNodeAnimation:
	var animation: AnimationNodeAnimation = AnimationNodeAnimation.new()
	animation.animation = initial_clip
	_graph.add_node(animation_name, animation)
	_graph.add_node(seek_name, AnimationNodeTimeSeek.new())
	_graph.connect_node(seek_name, 0, animation_name)
	return animation


func _mix(mix_name: StringName, base_name: StringName, action_name: StringName, upper_only: bool) -> void:
	var blend: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	if upper_only:
		blend.filter_enabled = true
		for i: int in _skeleton.get_bone_count():
			var bone: String = _skeleton.get_bone_name(i)
			if bone in ["Spine", "Chest", "UpperChest", "Neck", "Head"] or \
					((bone.begins_with("Left") or bone.begins_with("Right")) and \
					not (bone.ends_with("UpperLeg") or bone.ends_with("LowerLeg") or bone.ends_with("Foot") or bone.ends_with("Toes"))):
				blend.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	_graph.add_node(mix_name, blend)
	_graph.connect_node(mix_name, 0, base_name)
	_graph.connect_node(mix_name, 1, action_name)


func _locomotion_rate(speed: float) -> float:
	if speed < 0.2:
		return 1.0
	var leading_speed: float = 0.0
	for row: ClipSet.ClipRow in _cycles:
		if row.speed_mps > 0.0 and (leading_speed <= 0.0 or row.speed_mps <= speed):
			leading_speed = row.speed_mps
	if leading_speed <= 0.0:
		return 1.0
	return clampf(speed / leading_speed, 0.6, 1.5)


func _valid_clip(clip: StringName) -> bool:
	if _tree.has_animation(clip):
		return true
	if not clip.is_empty():
		_warn_once(clip, "CharacterAnimator: unknown clip '%s'; retaining its previous layer" % clip)
	return false


func _warn_once(key: StringName, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)
