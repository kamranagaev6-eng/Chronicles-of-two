extends GutTest
## Data loaders and validation, CSV parsing, transactions, the crowd snapshot codec, PRD crits,
## attributes and rune compatibility.

const T := CsvTable.ColumnType


func test_game_data_loads_clean() -> void:
	assert_eq(GameData.errors.size(), 0, "data errors: %s" % [GameData.errors])
	assert_ne(GameData.content_hash(), "")
	for cls: StringName in [&"vanguard", &"riftweaver"]:
		var c := GameData.class_def(cls)
		assert_not_null(c)
		var levels: Array[int] = []
		for ab: StringName in c.abilities:
			levels.append(GameData.ability(ab).unlock_level)
		assert_eq(levels, [1, 1, 2, 3, 6] as Array[int], "%s unlocks at 1, 1, 2, 3, 6" % cls)
	assert_eq(GameData.enemy_id_at(GameData.enemy_index(&"drowned_knight")), &"drowned_knight")


func test_every_class_primes_and_finishes() -> void:
	for cls: StringName in GameData.classes.keys():
		var c := GameData.class_def(cls)
		var primes := false
		var finishes := false
		for ab: StringName in c.abilities:
			var def := GameData.ability(ab)
			primes = primes or def.is_primer()
			finishes = finishes or def.is_finisher()
		assert_true(primes and finishes, "%s can prime and finish by level 3" % cls)


func test_csv_parsing_and_errors() -> void:
	var text := "# comment\nname,count,ratio,flag,tags\nalpha,3,0.5,true,a;b\n\"be,ta\",x,1,maybe,\nalpha,1,1,false,\n"
	var table := CsvTable.from_text(text, {"name": T.STRING, "count": T.INT, "ratio": T.FLOAT, "flag": T.BOOL, "tags": T.NAME_LIST}, "name")
	assert_eq(table.rows.size(), 3)
	assert_eq(str(table.rows[1]["name"]), "be,ta", "quoted commas")
	assert_eq(int(table.rows[0]["count"]), 3)
	assert_eq((table.rows[0]["tags"] as Array).size(), 2)
	assert_eq(table.errors.size(), 3, "bad int, bad bool and a duplicate key: %s" % [table.errors])
	var missing := CsvTable.from_text("a,b\n1,2\n", {"a": T.INT, "c": T.INT})
	assert_eq(missing.errors.size(), 2, "missing c and unexpected b")


func test_transactions_run_once() -> void:
	var log := TransactionLog.new()
	var inventory := {"giver": ["relic"], "receiver": []}
	var gift := func() -> bool:
		var item: Variant = (inventory["giver"] as Array).pop_back()
		if item == null:
			return false
		(inventory["receiver"] as Array).append(item)
		return true
	assert_true(log.execute("gift-1", gift))
	assert_true(log.execute("gift-1", gift), "a repeated packet returns the recorded result")
	assert_eq((inventory["receiver"] as Array).size(), 1, "and never moves the item twice")
	assert_eq((inventory["giver"] as Array).size(), 0, "nor loses it")


func test_crowd_codec_round_trip() -> void:
	var entities: Array[CrowdCodec.Entity] = []
	for i in 20:
		var e := CrowdCodec.Entity.new()
		e.id = 1000 + i
		e.generation = i
		e.kind = i % 4
		e.position = Vector3(i * 1.37 - 12.0, 0.5, -i * 0.91)
		e.yaw = i * 0.3
		e.anim = i % 12
		e.health = i / 20.0
		e.stagger = 0.5
		e.primer0 = 3
		e.primer1 = 7
		e.flags = GameTypes.FLAG_EXPOSED | GameTypes.FLAG_ELITE
		entities.append(e)
	var bytes := CrowdCodec.encode(77, entities)
	assert_eq(bytes.size(), CrowdCodec.HEADER_BYTES + CrowdCodec.ENTITY_BYTES * 20, "17 bytes per entity")
	assert_lt(bytes.size(), 400, "20 enemies fit one small packet")
	var decoded := CrowdCodec.decode(bytes)
	assert_eq(int(decoded["tick"]), 77)
	var out: Array = decoded["entities"]
	for i in 20:
		var a: CrowdCodec.Entity = entities[i]
		var b: CrowdCodec.Entity = out[i]
		assert_eq(b.id, a.id)
		assert_lt(b.position.distance_to(a.position), 0.01)
		assert_eq(b.primer1, 7)
		assert_eq(b.flags, a.flags)
		assert_almost_eq(b.health, a.health, 0.005)
	assert_true(CrowdCodec.decode(bytes.slice(0, 20)).is_empty(), "truncated data is rejected")


func test_prd_matches_the_nominal_rate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for p: float in [0.05, 0.25]:
		var prd := PrdRoller.new()
		var procs := 0
		var streak := 0
		var worst := 0
		for _i in 100000:
			if prd.roll(&"crit", p, rng):
				procs += 1
				streak = 0
			else:
				streak += 1
				worst = maxi(worst, streak)
		assert_almost_eq(procs / 100000.0, p, p * 0.04, "rate for p=%s" % p)
		assert_lt(worst, ceili(1.0 / PrdRoller.c_for(p)), "streaks are bounded for p=%s" % p)


func test_attribute_modifiers() -> void:
	assert_eq(AttributeSet.modifier_for(15), 2)
	assert_eq(AttributeSet.modifier_for(8), -1)
	assert_eq(AttributeSet.modifier_for(10), 0)
	assert_eq(AttributeSet.modifier_for(9), -1)
	var a := AttributeSet.from_dictionary({"str": 30, "dex": 15})
	assert_eq(a.roleplay_modifier(&"str"), 5, "roleplay modifiers cap at +5")
	assert_almost_eq(AttributeSet.from_dictionary({"str": 15}).stat(&"physical_damage_inc"), 0.1, 0.0001)


func test_rune_compatibility_follows_tags() -> void:
	var fork := GameData.rune(&"fork")
	var expansion := GameData.rune(&"expansion")
	var compression := GameData.rune(&"compression")
	var reach := GameData.rune(&"reach")
	assert_true(fork.fits(GameData.ability(&"glacial_spire")))
	assert_false(fork.fits(GameData.ability(&"judgment_cleave")), "a melee strike can't take Fork")
	assert_true(expansion.fits(GameData.ability(&"judgment_cleave")))
	assert_false(compression.fits(GameData.ability(&"radiant_aegis")))
	assert_true(reach.fits(GameData.ability(&"blink")))
	assert_false(fork.fits(GameData.ability(&"blink")))
	var echo := GameData.rune(&"echo")
	var lingering := GameData.rune(&"lingering")
	var resonant := GameData.rune(&"resonant")
	var kinship := GameData.rune(&"kinship")
	var attune := GameData.rune(&"attune")
	var tethered := GameData.rune(&"tethered")
	assert_not_null(echo)
	assert_not_null(lingering)
	assert_not_null(resonant)
	assert_not_null(kinship)
	assert_not_null(attune)
	assert_not_null(tethered)
	assert_true(echo.fits(GameData.ability(&"judgment_cleave")))
	assert_false(echo.fits(GameData.ability(&"radiant_aegis")), "support skill cannot take echo")
	assert_true(lingering.fits(GameData.ability(&"judgment_cleave")))
	assert_eq(resonant.category, &"bond")
	assert_eq(kinship.category, &"bond")
	assert_eq(attune.category, &"bond")
	assert_eq(tethered.category, &"bond")
	assert_true(resonant.fits(GameData.ability(&"judgment_cleave")), "bond runes fit any ability")

