extends GutTest
## Flow fields route around walls, never cut corners and report unreachable pockets.

var field: FlowField


func before_each() -> void:
	field = FlowField.new()
	field.setup(12, 12, 1.0, Vector2.ZERO)


func test_open_field_points_at_target() -> void:
	field.compute(Vector3(10.5, 0, 5.5))
	var d := field.direction_at(Vector3(2.5, 0, 5.5))
	assert_gt(d.x, 0.9)
	assert_true(field.reachable(Vector3(0.5, 0, 0.5)))


func test_routes_around_a_wall() -> void:
	field.block_rect(Vector3(6, 0, 0), Vector3(6.9, 0, 9.9))
	field.compute(Vector3(10.5, 0, 2.5))
	var pos := Vector3(2.5, 0, 2.5)
	for _i in 40:
		var d := field.direction_at(pos)
		if d == Vector3.ZERO:
			break
		pos += d * 0.5
		assert_true(field.is_walkable(pos), "path stays on walkable cells at %s" % pos)
	assert_lt(pos.distance_to(Vector3(10.5, 0, 2.5)), 1.0, "arrived around the wall")


func test_enclosed_pocket_is_unreachable() -> void:
	field.block_rect(Vector3(0, 0, 3), Vector3(3.9, 0, 3.9))
	field.block_rect(Vector3(3, 0, 0), Vector3(3.9, 0, 3.9))
	field.compute(Vector3(10.5, 0, 10.5))
	assert_false(field.reachable(Vector3(1.5, 0, 1.5)))
	assert_true(field.reachable(Vector3(8.5, 0, 1.5)))
