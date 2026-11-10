extends GutTest

const VANGUARD := "res://assets/characters/vanguard/vanguard.glb"
const MotorKit := preload("res://tests/unit/test_hero_motor.gd")
const GOLD := Color(0.95, 0.72, 0.25)
const VIOLET := Color(0.62, 0.42, 1.0)

var clips: ClipSet


func before_each() -> void:
	clips = ClipSet.for_set(&"vanguard")


func _animated() -> Array[Variant]:
	var scene: Node3D = (load(VANGUARD) as PackedScene).instantiate()
	add_child_autofree(scene)
	var sk := scene.get_node("%GeneralSkeleton") as Skeleton3D
	var animator := CharacterAnimator.new()
	scene.add_child(animator)
	animator.setup(sk, clips)
	return [animator, sk]


func _sample(clip: StringName, bone: String, t: float) -> Quaternion:
	var parts := String(clip).split("/")
	var anim := (load(CharacterAnimator.LIBRARIES[StringName(parts[0])]) as AnimationLibrary).get_animation(parts[1])
	return anim.rotation_track_interpolate(anim.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D), t)


func _rot(sk: Skeleton3D, bone: String) -> Quaternion:
	return sk.get_bone_pose_rotation(sk.find_bone(bone))


## Apply the same pose a few times so the eased blends settle.
func _settle(animator: CharacterAnimator, pose: AnimPose) -> void:
	for i: int in 40:
		animator.apply(pose, 0.1)
	animator.apply(pose, 0.0)


func test_full_body_action_sits_at_its_exact_time() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	_settle(a[0], pose)
	for bone: String in ["RightUpperArm", "LeftUpperLeg"]:
		assert_almost_eq(rad_to_deg(_rot(a[1], bone).angle_to(_sample(&"ual2/Sword_Regular_A", bone, 0.25))), 0.0, 0.1, bone)


func test_upper_body_action_leaves_the_legs_to_the_walk() -> void:
	var a := _animated()
	var b := _animated()
	var pose := AnimPose.new()
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	pose.action_upper = true
	_settle(a[0], pose)
	_settle(b[0], AnimPose.new())
	assert_almost_eq(rad_to_deg(_rot(a[1], "RightUpperArm").angle_to(_sample(&"ual2/Sword_Regular_A", "RightUpperArm", 0.25))), 0.0, 0.1)
	assert_almost_eq(rad_to_deg(_rot(a[1], "LeftUpperLeg").angle_to(_rot(b[1], "LeftUpperLeg"))), 0.0, 0.1, "legs match a rig with no action")


func test_zero_delta_holds_the_pose() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.speed_mps = 5.36
	(a[0] as CharacterAnimator).apply(pose, 0.2)
	var before := _rot(a[1], "LeftUpperLeg")
	(a[0] as CharacterAnimator).apply(pose, 0.0)
	assert_true(before.is_equal_approx(_rot(a[1], "LeftUpperLeg")))


func test_pinned_base_clip() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.locomotion = false
	pose.base_clip = &"ual1/Death01"
	pose.base_time_s = 2.4
	_settle(a[0], pose)
	assert_almost_eq(rad_to_deg(_rot(a[1], "Spine").angle_to(_sample(&"ual1/Death01", "Spine", 2.4))), 0.0, 0.1)


func test_unknown_clip_keeps_the_previous_pose() -> void:
	var a := _animated()
	var pose := AnimPose.new()
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	_settle(a[0], pose)
	var before := _rot(a[1], "RightUpperArm")
	pose.action_clip = &"ual2/No_Such_Clip"
	(a[0] as CharacterAnimator).apply(pose, 0.016)
	assert_almost_eq(rad_to_deg(before.angle_to(_rot(a[1], "RightUpperArm"))), 0.0, 0.1, "not dropped to the rest pose")


func test_two_animators_do_not_share_clips() -> void:
	var a := _animated()
	var b := _animated()
	var swing := AnimPose.new()
	swing.action_clip = &"ual2/Sword_Regular_A"
	swing.action_time_s = 0.25
	var guard := AnimPose.new()
	guard.action_clip = &"ual2/Idle_Shield"
	guard.action_time_s = 0.5
	_settle(a[0], swing)
	_settle(b[0], guard)
	(a[0] as CharacterAnimator).apply(swing, 0.016)
	assert_almost_eq(rad_to_deg(_rot(a[1], "RightUpperArm").angle_to(_sample(&"ual2/Sword_Regular_A", "RightUpperArm", 0.25))), 0.0, 0.1)


func test_locomotion_rate_is_clamped_and_reverses() -> void:
	var a := _animated()
	var animator := a[0] as CharacterAnimator
	var pose := AnimPose.new()
	pose.speed_mps = 6.2
	animator.apply(pose, 0.016)
	assert_almost_eq(animator.last_locomotion_rate, 6.2 / 5.36, 0.01)
	pose.speed_mps = 400.0
	animator.apply(pose, 0.016)
	assert_almost_eq(animator.last_locomotion_rate, 1.5, 0.0001)
	pose.speed_mps = 6.2
	pose.move_angle = PI
	animator.apply(pose, 0.016)
	assert_lt(animator.last_locomotion_rate, 0.0, "moving backwards plays the cycle in reverse")
	for bone: String in ["Hips", "Spine", "LeftUpperLeg"]:
		assert_true(_rot(a[1], bone).is_finite(), bone)


func test_rig_shares_cached_clips_and_copies_only_a_changed_loop() -> void:
	var cached := load(CharacterAnimator.LIBRARIES[&"ual1"]) as AnimationLibrary
	var idle_loop_before: Animation.LoopMode = cached.get_animation(&"Sword_Idle").loop_mode
	assert_ne(idle_loop_before, Animation.LOOP_LINEAR, "precondition: the import does not loop Sword_Idle, so the copy path runs")
	var a := _animated()
	var tree := (a[0] as Node).get_node("AnimationTree") as AnimationTree
	assert_same(tree.get_animation(&"ual1/Roll"), cached.get_animation(&"Roll"), "an unchanged clip is the cached resource")
	assert_not_same(tree.get_animation(&"ual1/Sword_Idle"), cached.get_animation(&"Sword_Idle"), "a re-looped clip is the rig's own copy")
	assert_eq(tree.get_animation(&"ual1/Sword_Idle").loop_mode, Animation.LOOP_LINEAR, "a looping row loops on the rig")
	assert_eq(cached.get_animation(&"Sword_Idle").loop_mode, idle_loop_before, "the cached import is untouched")


## Hips rotation of a fresh rig after one step of `pose` at `move_angle` = `deg` degrees.
func _hips_at(pose: AnimPose, deg: float) -> Quaternion:
	var a := _animated()
	pose.move_angle = deg_to_rad(deg)
	_settle(a[0], pose)
	return _rot(a[1], "Hips")


## Angle in degrees between `turn` and a rotation of `deg` degrees about the vertical.
func _off_vertical_turn(turn: Quaternion, deg: float) -> float:
	return rad_to_deg(turn.angle_to(Quaternion(Vector3.UP, deg_to_rad(deg))))


func test_locomotion_turns_the_hips_toward_the_movement() -> void:
	var jog := AnimPose.new()
	jog.speed_mps = 5.36
	var straight := _hips_at(jog, 0.0)
	assert_almost_eq(_off_vertical_turn(_hips_at(jog, 60.0) * straight.inverse(), 60.0), 0.0, 0.1, "60 degrees to the side")
	var reversed := _hips_at(jog, 180.0)
	var a := _animated()
	jog.move_angle = deg_to_rad(150.0)
	_settle(a[0], jog)
	assert_lt((a[0] as CharacterAnimator).last_locomotion_rate, 0.0, "beyond 100 degrees the cycle reverses")
	assert_almost_eq(_off_vertical_turn(_rot(a[1], "Hips") * reversed.inverse(), -30.0), 0.0, 0.1, "the hips carry the remaining angle")


func test_upper_body_action_over_moving_legs_still_twists() -> void:
	var pose := AnimPose.new()
	pose.speed_mps = 5.36
	pose.action_clip = &"ual2/Sword_Regular_A"
	pose.action_time_s = 0.25
	pose.action_upper = true
	var straight := _hips_at(pose, 0.0)
	assert_almost_eq(_off_vertical_turn(_hips_at(pose, 60.0) * straight.inverse(), 60.0), 0.0, 0.1)


func test_no_twist_outside_locomotion() -> void:
	var crawl := AnimPose.new()
	crawl.locomotion = false
	crawl.base_clip = &"extra/Downed_Crawl"
	crawl.base_time_s = 0.4
	crawl.speed_mps = 0.75
	crawl.move_angle = deg_to_rad(60.0)
	var swing := AnimPose.new()
	swing.action_clip = &"ual2/Sword_Regular_A"
	swing.action_time_s = 0.25
	swing.speed_mps = 5.36
	swing.move_angle = deg_to_rad(60.0)
	for case: Array in [[crawl, &"extra/Downed_Crawl", 0.4], [swing, &"ual2/Sword_Regular_A", 0.25]]:
		var a := _animated()
		_settle(a[0], case[0])
		for bone: String in ["Hips", "Spine"]:
			assert_almost_eq(rad_to_deg(_rot(a[1], bone).angle_to(_sample(case[1], bone, case[2]))), 0.0, 0.1, "%s %s" % [case[1], bone])


func _rig() -> CharacterRig:
	var rig: CharacterRig = CharacterRig.create(load(VANGUARD) as PackedScene, &"vanguard")
	add_child_autofree(rig)
	return rig


func _accent_color(rig: CharacterRig) -> Color:
	var body: MeshInstance3D = rig.find_child("Body", true, false) as MeshInstance3D
	for surface: int in body.mesh.get_surface_count():
		if body.mesh.surface_get_material(surface).resource_name == "accent_trim":
			return (body.get_active_material(surface) as BaseMaterial3D).albedo_color
	return Color.BLACK


func test_parts_cover_every_mesh() -> void:
	var rig: CharacterRig = _rig()
	assert_eq(rig.parts.size(), rig.find_children("*", "GeometryInstance3D", true, false).size())
	assert_almost_eq(rig.built_height, 1.8, 0.01)


func test_signature_and_headgear_switch() -> void:
	var rig: CharacterRig = _rig()
	var shield: Node3D = rig.find_child("Sig_Oathshield", true, false) as Node3D
	var sword: Node3D = rig.find_child("Prop_Sword", true, false) as Node3D
	rig.set_signature_visible(false)
	assert_false(shield.visible)
	assert_true(sword.visible, "only the signature weapon hides")
	rig.set_signature_visible(true)
	assert_true(shield.visible)
	var helm: Node3D = rig.find_child("Headgear", true, false) as Node3D
	var hair: Node3D = rig.find_child("HairFull", true, false) as Node3D
	assert_true(helm.visible and not hair.visible, "headgear is on by default")
	rig.set_headgear_visible(false)
	assert_true(hair.visible and not helm.visible)


func test_two_rigs_keep_their_own_colour() -> void:
	var a: CharacterRig = _rig()
	var b: CharacterRig = _rig()
	a.set_accent(GOLD)
	b.set_accent(VIOLET)
	assert_true(_accent_color(a).is_equal_approx(GOLD))
	assert_true(_accent_color(b).is_equal_approx(VIOLET))
	b.set_headgear_visible(false)
	assert_true((a.find_child("Headgear", true, false) as Node3D).visible)


func test_update_hero_drives_the_pose_and_the_thrown_shield() -> void:
	var rig: CharacterRig = _rig()
	var motor: HeroMotor = MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	var arm: int = rig.skeleton.find_bone("RightUpperArm")
	var rest: Quaternion = rig.skeleton.get_bone_rest(arm).basis.get_rotation_quaternion()
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.1)
	assert_false(rig.skeleton.get_bone_pose_rotation(arm).is_equal_approx(rest), "the idle is not the rest pose")
	motor.weapon_out = true
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 11, 0.0, 0.016)
	assert_false((rig.find_child("Sig_Oathshield", true, false) as Node3D).visible)


func test_hit_and_finisher_run_on_the_rigs_own_clock() -> void:
	var rig: CharacterRig = _rig()
	var motor: HeroMotor = MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.1)
	var head: int = rig.skeleton.find_bone("Head")
	var calm: Quaternion = rig.skeleton.get_bone_pose_rotation(head)
	rig.play_hit()
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.05)
	assert_false(calm.is_equal_approx(rig.skeleton.get_bone_pose_rotation(head)), "the hit overlay moves the head")
	rig.play_finisher(60)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 10, 0.0, 0.0)
	var frozen: Quaternion = rig.skeleton.get_bone_pose_rotation(head)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 40, 0.0, 0.0)
	assert_true(frozen.is_equal_approx(rig.skeleton.get_bone_pose_rotation(head)), "zero delta holds, as hit-stop needs")


func test_invalid_scene_and_missing_skeleton_return_null() -> void:
	assert_null(CharacterRig.create(PackedScene.new(), &"vanguard"), "an empty scene cannot be instantiated")
	var root: Node3D = Node3D.new()
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(root), OK)
	root.free()
	assert_null(CharacterRig.create(scene, &"vanguard"), "a scene without a skeleton is unusable")
	assert_null(CharacterRig.create(scene, &"missing_set"), "an unknown clip set is unusable")
	var broken_root: Node3D = Node3D.new()
	var broken_skeleton: Skeleton3D = Skeleton3D.new()
	broken_skeleton.name = "GeneralSkeleton"
	broken_skeleton.add_bone("Hips")
	broken_root.add_child(broken_skeleton)
	broken_skeleton.owner = broken_root
	var broken_scene: PackedScene = PackedScene.new()
	assert_eq(broken_scene.pack(broken_root), OK)
	broken_root.free()
	assert_null(CharacterRig.create(broken_scene, &"vanguard"), "an incomplete skeleton is unusable")


func test_revived_hero_plays_get_up_at_real_time() -> void:
	var rig: CharacterRig = _rig()
	var motor: HeroMotor = MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	rig.update_hero(motor, NetProtocol.LIFE_DOWNED, 10, 0.0, 0.1)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 11, 0.0, 0.1)
	var first: Quaternion = _rot(rig.skeleton, "RightUpperArm")
	assert_almost_eq(rad_to_deg(first.angle_to(_sample(&"ual2/LayToIdle", "RightUpperArm", 0.37))), 0.0, 0.1)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 12, 0.0, 0.2)
	var later: Quaternion = _rot(rig.skeleton, "RightUpperArm")
	assert_almost_eq(rad_to_deg(later.angle_to(_sample(&"ual2/LayToIdle", "RightUpperArm", 0.57))), 0.0, 0.1)


## The host sets life to Alive at once but queues the motor's `downed = false` for a later tick.
func test_get_up_waits_for_the_motor_to_stand() -> void:
	var rig: CharacterRig = _rig()
	var motor: HeroMotor = MotorKit.make_moveset_motor(&"vanguard")
	autofree(motor)
	motor.downed = true
	rig.update_hero(motor, NetProtocol.LIFE_DOWNED, 10, 0.0, 0.1)
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 11, 0.0, 0.1)
	motor.downed = false
	rig.update_hero(motor, NetProtocol.LIFE_ALIVE, 12, 0.0, 0.1)
	var first: Quaternion = _rot(rig.skeleton, "RightUpperArm")
	assert_almost_eq(rad_to_deg(first.angle_to(_sample(&"ual2/LayToIdle", "RightUpperArm", 0.37))), 0.0, 0.1)
