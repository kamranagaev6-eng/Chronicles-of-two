extends GutTest
## Golden-grid surface tests: reaction order, expiry, ownership, spreading, flooding, determinism,
## and network patches (revisions, run-length encoding, full snapshot recovery).

var grid: SurfaceGrid


func _make() -> SurfaceGrid:
	var g := SurfaceGrid.new()
	g.setup(48, 48, 0.5, Vector2.ZERO, 16)
	g.configure_from_data()
	return g


func before_each() -> void:
	grid = _make()


func _run(updates: int, g: SurfaceGrid = null) -> void:
	var target := g if g != null else grid
	for _i in updates:
		target.update()


func test_water_freezes_then_thaws() -> void:
	grid.paint_base_rect(Vector3(2, 0, 2), Vector3(6, 0, 6), SurfaceGrid.WATER)
	grid.apply_element(Vector3(4, 0, 4), 1.0, &"cold", 1)
	assert_eq(grid.material_at(Vector3(4, 0, 4)), SurfaceGrid.ICE)
	assert_eq(grid.material_at(Vector3(2.2, 0, 2.2)), SurfaceGrid.WATER, "outside the radius stays water")
	assert_eq(grid.owner_at(Vector3(4, 0, 4)), 1, "the Riftweaver owns the ice")
	_run(79)
	assert_eq(grid.material_at(Vector3(4, 0, 4)), SurfaceGrid.ICE)
	_run(2)
	assert_eq(grid.material_at(Vector3(4, 0, 4)), SurfaceGrid.WATER, "ice reverts to its base after 8 s")


func test_fire_melts_ice_for_good() -> void:
	grid.paint_base_rect(Vector3(2, 0, 2), Vector3(6, 0, 6), SurfaceGrid.WATER)
	grid.apply_element(Vector3(4, 0, 4), 1.0, &"cold", 1)
	grid.apply_element(Vector3(4, 0, 4), 1.0, &"fire", 1)
	assert_eq(grid.material_at(Vector3(4, 0, 4)), SurfaceGrid.WATER)
	_run(200)
	assert_eq(grid.material_at(Vector3(4, 0, 4)), SurfaceGrid.WATER)


func test_oil_explodes_burns_and_is_consumed() -> void:
	grid.paint_base_rect(Vector3(2, 0, 2), Vector3(4, 0, 4), SurfaceGrid.OIL)
	grid.events.clear()
	var counts := grid.apply_element(Vector3(3, 0, 3), 0.8, &"fire", 0)
	assert_true(counts.has(&"explode"))
	var explosions := grid.events.filter(func(e: Dictionary) -> bool: return e["type"] == &"explode")
	assert_eq(explosions.size(), 1, "one aggregated explosion event per application")
	assert_eq(grid.material_at(Vector3(3, 0, 3)), SurfaceGrid.BURNING)
	_run(200)
	assert_eq(grid.material_at(Vector3(3, 0, 3)), SurfaceGrid.NONE, "burnt oil is gone")
	assert_eq(grid.material_at(Vector3(2.1, 0, 2.1)), SurfaceGrid.NONE, "fire spread through the whole slick")


func test_fire_spreads_along_an_oil_trail() -> void:
	grid.paint_base_rect(Vector3(1.0, 0, 5.0), Vector3(9.9, 0, 5.4), SurfaceGrid.OIL)
	grid.apply_element(Vector3(1.25, 0, 5.25), 0.2, &"fire", 1)
	_run(20)
	assert_eq(grid.material_at(Vector3(3.75, 0, 5.25)), SurfaceGrid.BURNING, "5 cells along after 20 updates")
	assert_eq(grid.material_at(Vector3(9.75, 0, 5.25)), SurfaceGrid.OIL, "the far end has not caught yet")
	assert_eq(grid.owner_at(Vector3(3.75, 0, 5.25)), 1, "spread fire keeps the igniter as owner")
	_run(70)
	for x in range(2, 20):
		assert_ne(grid.material_at(Vector3(x * 0.5 + 0.25, 0, 5.25)), SurfaceGrid.OIL, "no oil left at cell %d" % x)


func test_lightning_floods_connected_water_only() -> void:
	grid.paint_base_rect(Vector3(1, 0, 1), Vector3(4, 0, 4), SurfaceGrid.WATER)
	grid.paint_base_rect(Vector3(10, 0, 10), Vector3(12, 0, 12), SurfaceGrid.WATER)
	grid.apply_element(Vector3(1.25, 0, 1.25), 0.2, &"lightning", 1)
	assert_true(grid.flags_at(Vector3(3.75, 0, 3.75)) & SurfaceGrid.FLAG_ELECTRIFIED != 0, "the whole pool conducts")
	assert_eq(grid.flags_at(Vector3(11, 0, 11)), 0, "a separate pool stays dry")
	_run(41)
	assert_eq(grid.flags_at(Vector3(3.75, 0, 3.75)), 0, "electrified water fades after 4 s")


func test_cold_extinguishes_fire_into_a_puddle_that_evaporates() -> void:
	grid.paint_base_rect(Vector3(2, 0, 2), Vector3(3, 0, 3), SurfaceGrid.OIL)
	grid.apply_element(Vector3(2.5, 0, 2.5), 0.6, &"fire", 0)
	grid.apply_element(Vector3(2.5, 0, 2.5), 0.6, &"cold", 1)
	assert_eq(grid.material_at(Vector3(2.5, 0, 2.5)), SurfaceGrid.WATER)
	_run(61)
	assert_eq(grid.material_at(Vector3(2.5, 0, 2.5)), SurfaceGrid.NONE)


func test_steam_cloud_and_holy_ground() -> void:
	grid.paint_base_rect(Vector3(2, 0, 2), Vector3(3, 0, 3), SurfaceGrid.WATER)
	grid.apply_element(Vector3(2.5, 0, 2.5), 0.4, &"fire", 1)
	assert_eq(grid.cloud_at(Vector3(2.5, 0, 2.5)), SurfaceGrid.CLOUD_STEAM)
	_run(31)
	assert_eq(grid.cloud_at(Vector3(2.5, 0, 2.5)), SurfaceGrid.CLOUD_NONE)
	grid.apply_element(Vector3(8, 0, 8), 1.0, &"holy", 0)
	assert_eq(grid.material_at(Vector3(8, 0, 8)), SurfaceGrid.SANCTIFIED)
	_run(81)
	assert_eq(grid.material_at(Vector3(8, 0, 8)), SurfaceGrid.NONE)


func test_consecrated_ground_ignites_oil() -> void:
	grid.paint_base_rect(Vector3(2, 0, 2), Vector3(3, 0, 3), SurfaceGrid.OIL)
	grid.apply_element(Vector3(2.5, 0, 2.5), 0.4, &"holy", 0)
	assert_eq(grid.material_at(Vector3(2.5, 0, 2.5)), SurfaceGrid.BURNING)


func test_same_operations_give_identical_grids() -> void:
	var a := _make()
	var b := _make()
	for g: SurfaceGrid in [a, b]:
		g.paint_base_rect(Vector3(1, 0, 1), Vector3(8, 0, 3), SurfaceGrid.OIL)
		g.paint_base_rect(Vector3(1, 0, 6), Vector3(8, 0, 9), SurfaceGrid.WATER)
		g.apply_element(Vector3(2, 0, 2), 0.5, &"fire", 0)
		g.apply_element(Vector3(5, 0, 7), 1.5, &"cold", 1)
		_run(37, g)
		g.apply_element(Vector3(3, 0, 7), 1.0, &"lightning", 1)
		_run(13, g)
	assert_eq(a.material, b.material)
	assert_eq(a.flags, b.flags)
	assert_eq(a.expiry, b.expiry)


func test_patches_and_full_snapshot_reproduce_the_host_grid() -> void:
	var guest := _make()
	grid.paint_base_rect(Vector3(1, 0, 1), Vector3(8, 0, 3), SurfaceGrid.OIL)
	grid.paint_base_rect(Vector3(1, 0, 6), Vector3(20, 0, 9), SurfaceGrid.WATER)
	guest.apply_full_snapshot(grid.full_snapshot())
	grid.take_patches()
	grid.apply_element(Vector3(2, 0, 2), 0.5, &"fire", 0)
	grid.apply_element(Vector3(5, 0, 7), 1.5, &"cold", 1)
	for _i in 10:
		grid.update()
		for p: Array in grid.take_patches():
			assert_true(guest.apply_patch(int(p[0]), int(p[1]), p[2] as PackedByteArray))
	assert_eq(guest.material, grid.material)
	assert_eq(guest.flags, grid.flags)
	assert_eq(guest.cloud, grid.cloud)
	assert_false(guest.apply_patch(0, 0, grid.encode_chunk(0)), "stale revisions are ignored")
	var late := _make()
	late.apply_full_snapshot(grid.full_snapshot())
	assert_eq(late.material, grid.material, "a joining guest recovers from one full snapshot")


func test_empty_chunks_encode_small() -> void:
	assert_lt(grid.encode_chunk(0).size(), 12, "run-length encoding when it is smaller")
	assert_eq(grid.chunks_x * grid.chunks_y, 9)
