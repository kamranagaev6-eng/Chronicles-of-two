class_name CharacterRig
extends Node3D
## A locally animated character. Its presentation clock never changes simulation state.

const TICKS_PER_SECOND: float = 60.0

var parts: Array[GeometryInstance3D] = []
var skeleton: Skeleton3D
var animator: CharacterAnimator
var built_height: float = 0.0

var _clips: ClipSet
var _signature_parts: Array[Node3D] = []
var _headgear: Node3D
var _hair: Node3D
var _clock: float = 0.0
var _hit_started: float = -1.0
var _finisher_started: float = -1.0
var _finisher_duration: float = 0.0
var _get_up_started: float = -1.0
var _was_downed: bool = false


static func create(scene: PackedScene, clip_set: StringName) -> CharacterRig:
	if scene == null or not scene.can_instantiate():
		return null
	var clips: ClipSet = ClipSet.for_set(clip_set)
	if clips == null:
		return null
	var instance: Node = scene.instantiate()
	if instance == null:
		return null
	var model: Node3D = instance as Node3D
	if model == null:
		instance.free()
		return null
	var sk: Skeleton3D = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if sk == null or not _has_humanoid_bones(sk):
		model.free()
		return null

	var rig: CharacterRig = new()
	rig._clips = clips
	rig.add_child(model)
	rig.skeleton = sk
	rig.built_height = float(model.get_meta("built_height_m", 0.0))
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		rig.parts.append(node as GeometryInstance3D)
	for node: Node in model.find_children("*", "Node3D", true, false):
		if String(node.name).begins_with("Sig_"):
			rig._signature_parts.append(node as Node3D)
	rig._headgear = model.find_child("Headgear", true, false) as Node3D
	rig._hair = model.find_child("HairFull", true, false) as Node3D
	rig.set_headgear_visible(true)
	rig.animator = CharacterAnimator.new()
	rig.add_child(rig.animator)
	rig.animator.setup(sk, clips)
	return rig


static func _has_humanoid_bones(sk: Skeleton3D) -> bool:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for index: int in profile.bone_size:
		var bone: StringName = profile.get_bone_name(index)
		# The authored skeleton does not map the optional facial bones.
		if bone in [&"LeftEye", &"RightEye", &"Jaw"]:
			continue
		if sk.find_bone(bone) < 0:
			return false
	return true


func set_accent(color: Color) -> void:
	for part: GeometryInstance3D in parts:
		var mesh_instance: MeshInstance3D = part as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: BaseMaterial3D = mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != "accent_trim":
				continue
			var colored: BaseMaterial3D = source.duplicate() as BaseMaterial3D
			colored.albedo_color = color
			mesh_instance.set_surface_override_material(surface, colored)


func set_signature_visible(shown: bool) -> void:
	for part: Node3D in _signature_parts:
		part.visible = shown


func set_headgear_visible(shown: bool) -> void:
	if _headgear != null:
		_headgear.visible = shown
	if _hair != null:
		_hair.visible = not shown


func update_hero(motor: HeroMotor, life: int, tick: int, tick_factor: float, delta: float) -> void:
	_clock += maxf(delta, 0.0)
	set_signature_visible(not motor.weapon_out)
	# The host sets life to Alive at once but the motor's `downed` clears a tick or more later, and the
	# driver shows the downed pose until it does: the get-up starts when both say the hero stands.
	if life == NetProtocol.LIFE_DOWNED:
		_was_downed = true
	elif life == NetProtocol.LIFE_FALLEN:
		_was_downed = false
	if life != NetProtocol.LIFE_ALIVE or motor.downed:
		_get_up_started = -1.0
	elif _was_downed:
		_was_downed = false
		_get_up_started = _clock

	var finisher_elapsed: float = -1.0
	if _finisher_started >= 0.0:
		var elapsed: float = _clock - _finisher_started
		if elapsed < _finisher_duration:
			finisher_elapsed = elapsed
		else:
			_finisher_started = -1.0
	var pose: AnimPose = HeroAnimDriver.pose(motor, life, tick, tick_factor, finisher_elapsed, _clips)

	if _get_up_started >= 0.0:
		var get_up: ClipSet.ClipRow = _clips.row(&"get_up")
		var elapsed: float = _clock - _get_up_started
		if get_up != null and elapsed < get_up.end_s - get_up.start_s:
			pose.action_clip = get_up.clip
			pose.action_time_s = get_up.start_s + elapsed
			pose.action_upper = false
		else:
			_get_up_started = -1.0

	if _hit_started >= 0.0:
		var hit: ClipSet.ClipRow = _clips.row(&"hit")
		var elapsed: float = _clock - _hit_started
		if hit != null and elapsed < hit.end_s - hit.start_s:
			pose.overlay_clip = hit.clip
			pose.overlay_time_s = hit.start_s + elapsed
		else:
			_hit_started = -1.0
	animator.apply(pose, delta)


func play_finisher(lock_ticks: int) -> void:
	_finisher_started = _clock
	_finisher_duration = maxi(lock_ticks, 0) / TICKS_PER_SECOND


func play_hit() -> void:
	_hit_started = _clock
