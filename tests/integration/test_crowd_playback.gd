extends GutTest

const Arena = preload("res://game/scenes/arena/arena.gd")


func _entity(generation: int, x: float = 0.0) -> CrowdCodec.Entity:
	var entity: CrowdCodec.Entity = CrowdCodec.Entity.new()
	entity.id = 1
	entity.generation = generation
	entity.kind = GameData.enemy_index(&"drowned_thrall")
	entity.position = Vector3(x, 0.0, 0.0)
	return entity


func test_arena_receives_valid_packets_and_rejects_bad_or_stale_packets() -> void:
	var arena: Node = Arena.new()
	var playback: SnapshotBuffer = arena.get("snapshots")
	arena.call("on_crowd", CrowdCodec.encode(100, [_entity(1, 5.0)]))
	assert_eq(playback.latest_tick(), 100)
	assert_eq(playback.depth(), 1)
	arena.call("on_crowd", PackedByteArray([1, 2, 3]))
	arena.call("on_crowd", CrowdCodec.encode(99, [_entity(1, 99.0)]))
	assert_eq(playback.latest_tick(), 100)
	assert_almost_eq(playback.sample(100.0)[0].position.x, 5.0, 0.001)
	arena.call("on_crowd", CrowdCodec.encode(103, []))
	assert_eq(playback.sample(103.0).size(), 0)
	arena.free()


func test_reused_entity_id_gets_a_new_visual_and_no_old_hit_stop() -> void:
	var view: Presentation = Presentation.new()
	add_child_autofree(view)
	view.set_process(false)
	view.update_entities([_entity(1)], 0.0)
	var old_visual: EnemyVisual = view.enemies[1]
	old_visual.hit_stop(10000)
	view.update_entities([_entity(2, 10.0)], 0.0)
	var new_visual: EnemyVisual = view.enemies[1]
	assert_ne(new_visual, old_visual, "Spawn generation identifies a new enemy even when kind and ID are reused")
	assert_true(old_visual.is_queued_for_deletion())
	assert_almost_eq(new_visual.global_position.x, 10.0, 0.001, "The previous enemy's hit-stop cannot freeze the new spawn")


func test_same_entity_generation_keeps_its_visual_between_snapshots() -> void:
	var view: Presentation = Presentation.new()
	add_child_autofree(view)
	view.set_process(false)
	view.update_entities([_entity(1)], 0.0)
	var original: EnemyVisual = view.enemies[1]
	view.update_entities([_entity(1, 3.0)], 0.0)
	assert_eq(view.enemies[1], original)
	assert_almost_eq(original.global_position.x, 3.0, 0.001)
	view.update_entities([], 0.0)
	assert_true(view.enemies.is_empty())
	assert_true(original.is_queued_for_deletion())
