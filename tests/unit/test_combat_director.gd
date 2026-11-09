extends GutTest
## Combat Director: token limits per hero, release paths, leak audit, aggression dial, engagement slots.

var director: CombatDirector


func before_each() -> void:
	director = CombatDirector.new()
	director.configure_from_rules()


func test_default_pools() -> void:
	assert_true(director.request_token(1, 0, &"melee", 0))
	assert_false(director.request_token(2, 0, &"melee", 0), "one melee-or-heavy commitment per hero")
	assert_true(director.request_token(2, 1, &"melee", 0), "the other hero has its own pool")
	assert_true(director.request_token(3, 0, &"ranged", 0))
	assert_true(director.request_token(4, 0, &"ranged", 0))
	assert_false(director.request_token(5, 0, &"ranged", 0), "two ranged per hero")


func test_release_frees_the_token() -> void:
	director.request_token(1, 0, &"melee", 0)
	director.release_token(1)
	assert_true(director.request_token(2, 0, &"melee", 0))
	director.forget(2)
	assert_eq(director.in_use(0, &"melee"), 0)


func test_rerequest_and_retarget() -> void:
	assert_true(director.request_token(1, 0, &"melee", 0))
	assert_true(director.request_token(1, 0, &"melee", 5), "holding already counts once")
	assert_eq(director.in_use(0, &"melee"), 1)
	assert_true(director.request_token(1, 1, &"melee", 6), "retargeting releases the old token")
	assert_eq(director.in_use(0, &"melee"), 0)
	assert_eq(director.in_use(1, &"melee"), 1)


func test_audit_reclaims_leaked_tokens() -> void:
	for id in [1, 2]:
		director.request_token(id, id - 1, &"melee", 0)
	director.request_token(3, 0, &"ranged", 0)
	var dead := {1: true, 3: true}
	var reclaimed := director.audit(func(enemy_id: int, _hero: int, _kind: StringName, _tick: int) -> bool:
		return not dead.has(enemy_id))
	assert_eq(reclaimed, 2)
	assert_eq(director.in_use(0, &"melee"), 0)
	assert_eq(director.in_use(0, &"ranged"), 0)
	assert_eq(director.in_use(1, &"melee"), 1)
	assert_true(director.request_token(9, 0, &"melee", 1), "the pool did not shrink")


func test_aggression_dial_and_heroic() -> void:
	director.aggression = 2.0
	assert_eq(director.capacity(&"melee"), 2)
	assert_eq(director.capacity(&"ranged"), 4)
	var heroic := CombatDirector.new()
	heroic.configure_from_rules(true)
	assert_eq(heroic.capacity(&"melee"), 2, "Heroic allows two melee commitments")


func test_engagement_slots_are_unique() -> void:
	var hero := Vector3(10, 0, 10)
	var seen: Dictionary = {}
	var always := func(_p: Vector3) -> bool: return true
	for id in range(1, 7):
		var p := director.request_slot(id, 0, CombatDirector.RING_INNER, hero, Vector3(0, 0, 0), always)
		assert_almost_eq(p.distance_to(hero), 2.0, 0.001)
		assert_false(seen.has(p), "slot %s already taken" % p)
		seen[p] = true
	var full := director.request_slot(7, 0, CombatDirector.RING_INNER, hero, Vector3.ZERO, always)
	assert_eq(full, hero, "no slot left: fall back to the hero position")
	director.release_slot(3)
	assert_ne(director.request_slot(7, 0, CombatDirector.RING_INNER, hero, Vector3.ZERO, always), hero)


func test_unreachable_slots_are_skipped() -> void:
	var hero := Vector3.ZERO
	var east_only := func(p: Vector3) -> bool: return p.x > 0.5
	var p := director.request_slot(1, 0, CombatDirector.RING_OUTER, hero, Vector3(-10, 0, 0), east_only)
	assert_gt(p.x, 0.5)
