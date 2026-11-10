extends GutTest


func _row(start: float, contact: float, end: float) -> ClipSet.ClipRow:
	var row: ClipSet.ClipRow = ClipSet.ClipRow.new()
	row.start_s = start
	row.contact_s = contact
	row.end_s = end
	return row


func test_contact_lands_when_the_active_window_opens() -> void:
	var row: ClipSet.ClipRow = _row(0.0, 0.25, 0.43)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.0), 0.0, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.05), 0.125, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.1), 0.25, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 0.225), 0.34, 0.0001)
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, 9.0), 0.43, 0.0001)


func test_degenerate_timings_stay_finite() -> void:
	var row: ClipSet.ClipRow = _row(0.1, 0.25, 0.43)
	assert_almost_eq(ClipSet.clip_time(row, 0.0, 0.25, 0.0), 0.25, 0.0001, "no windup starts at contact")
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.0, 0.2), 0.43, 0.0001, "no recovery ends at once")
	assert_almost_eq(ClipSet.clip_time(row, 0.1, 0.25, -3.0), 0.1, 0.0001, "time before the start is clamped")
	assert_almost_eq(ClipSet.clip_time(_row(0.2, 0.2, 0.2), 0.0, 0.0, 0.0), 0.2, 0.0001)


func test_every_vanguard_move_has_its_own_row() -> void:
	var clips: ClipSet = ClipSet.for_set(&"vanguard")
	var c: ClassDefinition = GameData.class_def(&"vanguard")
	var ids: Array[StringName] = [c.heavy_attack, c.throw_ability, c.recall_ability, &"shove", &"flask"]
	ids.append_array(c.light_combo)
	ids.append_array(c.abilities)
	for id: StringName in ids:
		assert_eq(clips.ability_row(GameData.ability(id)).role, StringName("ability:%s" % id))
	for role: StringName in [&"idle", &"walk", &"jog", &"sprint", &"block", &"dodge", &"hit", &"get_up",
			&"downed_idle", &"downed_crawl", &"dead", &"finisher", &"action_default"]:
		assert_not_null(clips.row(role), str(role))


func test_windups_are_not_stretched_too_far() -> void:
	var clips: ClipSet = ClipSet.for_set(&"vanguard")
	for id: StringName in GameData.abilities:
		var def: AbilityDefinition = GameData.ability(id)
		var row: ClipSet.ClipRow = clips.row(StringName("ability:%s" % id))
		if row != null and def.windup_ticks > 0:
			var rate: float = ClipSet.windup_rate(row, def.windup_ticks / 60.0)
			assert_between(rate, 0.4, 3.0, str(id))
	assert_between(ClipSet.windup_rate(clips.row(&"dodge"), GameData.rule(&"dodge_ticks") / 60.0), 0.4, 3.0)
	assert_between(ClipSet.windup_rate(clips.row(&"finisher"), GameData.rule(&"finisher_impact_ticks") / 60.0), 0.4, 3.0)


func test_missing_rows_fall_back_and_never_return_null() -> void:
	var clips: ClipSet = ClipSet.for_set(&"vanguard")
	var stray: AbilityDefinition = AbilityDefinition.new()
	stray.id = &"not_in_the_table"
	stray.delivery = &"melee_arc"
	assert_eq(clips.ability_row(stray).role, &"action_default")
	assert_eq(clips.base_row(&"no_such_role").role, &"idle")
	assert_null(clips.row(&"no_such_role"))
	assert_null(ClipSet.for_set(&"no_such_set"))


func test_rows_have_ordered_times_and_known_layers() -> void:
	for row: Dictionary in GameData.character_clips[&"vanguard"]:
		assert_true(0.0 <= row["start_s"] and row["start_s"] <= row["contact_s"] and row["contact_s"] <= row["end_s"], str(row["role"]))
		assert_has([&"full", &"upper", &"upper_when_moving"], row["layer"])
		assert_eq(String(row["clip"]).split("/").size(), 2, str(row["role"]))


const LIBRARIES := {
	"ual1": "res://assets/animations/quaternius/UAL1_Standard.glb",
	"ual2": "res://assets/animations/quaternius/UAL2_Standard.glb",
	"extra": "res://assets/animations/chronicle/extra.res",
}


func test_extra_clips_have_their_lengths() -> void:
	var extra: AnimationLibrary = load(LIBRARIES["extra"])
	for pair: Array in [["Prone_Hold", 0.5], ["Downed_Crawl", 1.6], ["Catch", 0.3], ["Finisher_Blow", 0.9], ["Leap_Slam", 0.92]]:
		assert_almost_eq(extra.get_animation(pair[0]).length, pair[1], 0.02, pair[0])
	var crawl := extra.get_animation(&"Downed_Crawl")
	var arm := crawl.find_track(NodePath("%GeneralSkeleton:LeftUpperArm"), Animation.TYPE_ROTATION_3D)
	assert_false(crawl.rotation_track_interpolate(arm, 0.4).is_equal_approx(crawl.rotation_track_interpolate(arm, 1.2)), "the arm sways")
	assert_true(crawl.rotation_track_interpolate(arm, 0.0).is_equal_approx(crawl.rotation_track_interpolate(arm, 1.6)), "and loops")


func test_every_row_points_at_a_real_clip_within_its_length() -> void:
	var libs := {}
	for key: String in LIBRARIES:
		libs[key] = load(LIBRARIES[key]) as AnimationLibrary
	for row: Dictionary in GameData.character_clips[&"vanguard"]:
		var parts := String(row["clip"]).split("/")
		var lib := libs.get(parts[0]) as AnimationLibrary
		assert_true(lib != null and lib.has_animation(parts[1]), str(row["clip"]))
		if lib != null and lib.has_animation(parts[1]):
			assert_lte(float(row["end_s"]), lib.get_animation(parts[1]).length + 0.02, str(row["role"]))

