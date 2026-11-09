extends GutTest
## Damage formula: one order, additive increased pool, separate more factors, capped co-op factors,
## armour and resistance caps, the vulnerability cap and fractional precision.

var caps: DamageCalculator.Caps


func before_each() -> void:
	caps = DamageCalculator.Caps.new()


func _hit(packets: Array[DamageCalculator.Packet], ctx: DamageCalculator.Context) -> float:
	return DamageCalculator.compute(packets, ctx, caps).total


func _p(t: StringName, base: float, added: float = 0.0, eff: float = 1.0) -> Array[DamageCalculator.Packet]:
	var out: Array[DamageCalculator.Packet] = [DamageCalculator.Packet.new(t, base, added, eff)]
	return out


func test_plain_hit() -> void:
	assert_almost_eq(_hit(_p(&"physical", 100.0), DamageCalculator.Context.new()), 100.0, 0.0001)


func test_added_damage_uses_effectiveness() -> void:
	assert_almost_eq(_hit(_p(&"physical", 50.0, 20.0, 0.5), DamageCalculator.Context.new()), 60.0, 0.0001)


func test_increased_is_one_additive_pool() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.increased = {&"all": 0.2, &"physical": 0.3, &"fire": 5.0}
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 150.0, 0.0001)


func test_more_factors_multiply_separately() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.more = [1.2, 1.5]
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 180.0, 0.0001)


func test_coop_factors_are_capped_as_a_group() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.coop_more = [1.3, 1.3]
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 150.0, 0.0001, "1.69 capped to 1.5")
	ctx.more = [2.0]
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 300.0, 0.0001, "other more factors are not capped")


func test_crit_multiplier() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.crit = true
	ctx.crit_multiplier = 1.5
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 150.0, 0.0001)


func test_armour_formula() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.armour = 100.0
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 100.0 * (1.0 - 100.0 / 1100.0), 0.0001)


func test_armour_cap() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.armour = 1000000.0
	assert_almost_eq(_hit(_p(&"physical", 10.0), ctx), 1.0, 0.0001, "armour caps at 90%")


func test_resistance_cap_and_negative_resistance() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.resistances = {&"fire": 0.9}
	assert_almost_eq(_hit(_p(&"fire", 100.0), ctx), 25.0, 0.0001, "resistance caps at 75%")
	ctx.resistances = {&"fire": -0.25}
	assert_almost_eq(_hit(_p(&"fire", 100.0), ctx), 125.0, 0.0001)


func test_vulnerability_cap_and_elemental_only_sources() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.vulnerability = 0.8
	ctx.elemental_vulnerability = 0.5
	assert_almost_eq(_hit(_p(&"fire", 100.0), ctx), 200.0, 0.0001, "V caps at +100%")
	ctx.vulnerability = 0.2
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), 120.0, 0.0001, "Exposed never boosts physical")


func test_full_order() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.increased = {&"all": 0.5}
	ctx.more = [1.2]
	ctx.crit = true
	ctx.crit_multiplier = 1.5
	ctx.armour = 50.0
	ctx.vulnerability = 0.2
	ctx.reaction_multiplier = 2.0
	var pre := 100.0 * 1.5 * 1.2 * 1.5
	var r := 50.0 / (50.0 + 10.0 * pre)
	assert_almost_eq(_hit(_p(&"physical", 100.0), ctx), pre * (1.0 - r) * 1.2 * 2.0, 0.0001)


func test_fractional_precision_is_kept() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.reaction_multiplier = 1.25
	assert_almost_eq(_hit(_p(&"physical", 10.4), ctx), 13.0, 0.000001)


func test_packets_are_mitigated_separately() -> void:
	var ctx := DamageCalculator.Context.new()
	ctx.armour = 100.0
	ctx.resistances = {&"fire": 0.5}
	var packets: Array[DamageCalculator.Packet] = [DamageCalculator.Packet.new(&"physical", 50.0), DamageCalculator.Packet.new(&"fire", 50.0)]
	var result := DamageCalculator.compute(packets, ctx, caps)
	assert_almost_eq(float(result.by_type[&"physical"]), 50.0 * (1.0 - 100.0 / 600.0), 0.0001)
	assert_almost_eq(float(result.by_type[&"fire"]), 25.0, 0.0001)
	assert_almost_eq(result.total, 50.0 * (1.0 - 100.0 / 600.0) + 25.0, 0.0001)


func test_caps_come_from_rules() -> void:
	var from_rules := DamageCalculator.Caps.from_rules()
	assert_eq(from_rules.armour_cap, 0.9)
	assert_eq(from_rules.resist_cap, 0.75)
	assert_eq(from_rules.coop_cap, 1.5)
