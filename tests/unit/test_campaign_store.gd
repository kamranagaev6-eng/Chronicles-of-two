extends GutTest
## Saves: round trip, corrupt latest file, interrupted writes, ancestry (never timestamps), branch
## conflicts, migrations, tampering, and both heroes loading into the right identities.

var store: CampaignStore
var root: String


func before_each() -> void:
	root = "user://test_saves_%d" % randi()
	store = CampaignStore.new(root)


func after_each() -> void:
	_rm_tree(ProjectSettings.globalize_path(root))


func _rm_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d: String in DirAccess.get_directories_at(path):
		_rm_tree(path + "/" + d)
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)


func _data(level: int) -> Dictionary:
	var d := CampaignState.new_campaign("Test Hearth", level)
	CampaignState.bind_profile(d, "profile-host", "Ember", &"vanguard", "gold")
	CampaignState.bind_profile(d, "profile-guest", "Anastasia", &"riftweaver", "violet")
	return d


func test_round_trip() -> void:
	var cp := CampaignStore.make_checkpoint("c1", _data(3), null, "host")
	assert_eq(store.write(cp), OK)
	var loaded := store.load_latest("c1")
	assert_not_null(loaded)
	assert_eq(loaded.content_hash, cp.content_hash)
	assert_eq(loaded.revision, 1)
	assert_eq(int(loaded.data["level"]), 3)


func test_corrupt_latest_falls_back_to_backup() -> void:
	var cp1 := CampaignStore.make_checkpoint("c1", _data(3), null)
	var cp2 := CampaignStore.make_checkpoint("c1", _data(4), cp1)
	store.write(cp1)
	store.write(cp2)
	var f := FileAccess.open(store.latest_path("c1"), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var loaded := store.load_latest("c1")
	assert_not_null(loaded)
	assert_eq(loaded.content_hash, cp1.content_hash, "the newest valid backup")


func test_interrupted_write_recovers_the_verified_tmp() -> void:
	var cp1 := CampaignStore.make_checkpoint("c1", _data(3), null)
	var cp2 := CampaignStore.make_checkpoint("c1", _data(4), cp1)
	store.write(cp1)
	var f := FileAccess.open(store.latest_path("c1") + ".tmp", FileAccess.WRITE)
	f.store_string(CampaignStore.serialize(cp2))
	f.close()
	assert_eq(store.load_latest("c1").content_hash, cp2.content_hash)
	f = FileAccess.open(store.latest_path("c1") + ".tmp", FileAccess.WRITE)
	f.store_string(CampaignStore.serialize(cp2).substr(0, 40))
	f.close()
	assert_eq(store.load_latest("c1").content_hash, cp1.content_hash, "a torn tmp file is ignored")


func test_ancestry_decides_never_timestamps() -> void:
	var cp1 := CampaignStore.make_checkpoint("c1", _data(3), null)
	var cp2 := CampaignStore.make_checkpoint("c1", _data(4), cp1)
	cp2.created_unix = cp1.created_unix - 100000
	assert_eq(CampaignStore.relation(cp2, cp1), CampaignStore.Relation.A_DESCENDS_FROM_B)
	assert_eq(CampaignStore.relation(cp1, cp2), CampaignStore.Relation.B_DESCENDS_FROM_A)
	assert_eq(CampaignStore.relation(cp1, cp1), CampaignStore.Relation.SAME)


func test_divergent_branches_are_kept() -> void:
	var cp1 := CampaignStore.make_checkpoint("c1", _data(3), null)
	var a := CampaignStore.make_checkpoint("c1", _data(4), cp1, "pc-a")
	var b := CampaignStore.make_checkpoint("c1", _data(5), cp1, "pc-b")
	assert_eq(CampaignStore.relation(a, b), CampaignStore.Relation.DIVERGENT)
	store.write(a)
	assert_eq(store.store_branch(b), OK)
	var branches := store.list_branches("c1")
	assert_eq(branches.size(), 1)
	assert_eq(branches[0].content_hash, b.content_hash)
	assert_eq(store.load_latest("c1").content_hash, a.content_hash, "a branch never replaces the latest")
	var other := CampaignStore.make_checkpoint("c2", _data(3), null)
	assert_eq(CampaignStore.relation(a, other), CampaignStore.Relation.UNRELATED)


func test_tampered_payload_is_rejected() -> void:
	var text := CampaignStore.serialize(CampaignStore.make_checkpoint("c1", _data(3), null))
	assert_null(CampaignStore.parse(text.replace("Test Hearth", "Evil Hearth")))
	assert_not_null(CampaignStore.parse(text))


func test_v1_saves_migrate_to_v2() -> void:
	var v1 := {"campaign_name": "Old", "level": 2, "hero_a": {"name": "Ember"}, "hero_b": {"name": "Ana"}}
	var payload := JSON.stringify(v1, "", true, true)
	var h := CampaignStore.hash_of("old", 1, 1, "", payload)
	var header := JSON.stringify({"format": CampaignStore.FORMAT, "campaign_id": "old", "schema_version": 1, "revision": 1,
		"parent_hash": "", "lineage": [], "content_hash": h, "created_unix": 0, "created_by": ""}, "", true)
	var cp := CampaignStore.parse(header + "\n" + payload + "\n")
	assert_not_null(cp)
	assert_eq(str(cp.data["heroes"]["a"]["name"]), "Ember")
	assert_eq(str(cp.data["heroes"]["b"]["name"]), "Ana")
	assert_true(cp.data.has("rune_library"))
	assert_false(cp.data.has("hero_a"))
	assert_true(SaveMigrations.migrate(v1, 99).is_empty(), "unknown versions are refused, never guessed")


func test_both_heroes_load_into_the_right_identities() -> void:
	var cp := CampaignStore.make_checkpoint("c1", _data(3), null)
	store.write(cp)
	var loaded := store.load_latest("c1")
	assert_eq(CampaignState.hero_key_for_profile(loaded.data, "profile-host"), "a")
	assert_eq(CampaignState.hero_key_for_profile(loaded.data, "profile-guest"), "b")
	assert_eq(CampaignState.bind_profile(loaded.data, "stranger", "X", &"vanguard", "gold"), "", "exactly two heroes")
	CampaignState.select_class(loaded.data, "b", &"vanguard")
	CampaignState.select_class(loaded.data, "b", &"riftweaver")
	var loadout := CampaignState.loadout_of(loaded.data, "b")
	assert_eq((loadout["abilities"] as Array).size(), 4, "each class keeps its own loadout")


func test_backups_are_pruned() -> void:
	store.backups_to_keep = 3
	var parent: CampaignStore.Checkpoint = null
	for i in 8:
		var cp := CampaignStore.make_checkpoint("c1", _data(3 + i), parent)
		store.write(cp)
		parent = cp
	var backups := DirAccess.get_files_at(store.campaign_dir("c1") + "/backups")
	assert_eq(backups.size(), 3)
	assert_eq(store.load_latest("c1").revision, 8)
