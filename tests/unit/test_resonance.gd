extends GutTest
## Resonance: partner attribution, own-primer Basic reactions, one primer per player, same-action
## protection, one detonation per action per target, two finishers on one primer, expiry, lockout,
## mirror classes and a non-blank reaction for every primer x finisher.

const HOST := 0
const GUEST := 1
const DURATION := 240

var store: PrimerStore
var resolver: ReactionResolver


func before_each() -> void:
	store = PrimerStore.new()
	resolver = ReactionResolver.new(store)
	resolver.configure_from_rules()


func test_partner_primer_resonates() -> void:
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 10)
	var out := resolver.resolve_finisher(1, HOST, &"impact", 20, 10)
	assert_eq(out.kind, ReactionResolver.Kind.RESONANCE)
	assert_eq(out.multiplier, 2.0)
	assert_eq(out.strength, 1.0)
	assert_eq(out.reaction_id, &"shatterfall")
	assert_true(out.is_signature)


func test_own_primer_is_a_basic_reaction() -> void:
	store.apply(1, &"sanctified", HOST, 1.0, 0, DURATION, 30)
	var out := resolver.resolve_finisher(1, HOST, &"impact", 31, 5)
	assert_eq(out.kind, ReactionResolver.Kind.BASIC)
	assert_eq(out.multiplier, 1.25)
	assert_eq(out.strength, 0.5)
	assert_false(out.is_signature)
	assert_eq(out.reaction_id, &"radiance+impact_twist")


func test_partner_primer_is_preferred() -> void:
	store.apply(1, &"dazed", HOST, 1.0, 0, DURATION, 1)
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 2)
	var out := resolver.resolve_finisher(1, HOST, &"impact", 3, 5)
	assert_eq(out.kind, ReactionResolver.Kind.RESONANCE)
	assert_eq(out.primer.type, &"frozen")
	assert_eq(store.live_primers(1, 5).size(), 1, "own primer is left in place")


func test_one_primer_per_player_per_enemy() -> void:
	store.apply(1, &"dazed", HOST, 1.0, 0, DURATION, 1)
	store.apply(1, &"sanctified", HOST, 1.0, 1, DURATION, 2)
	var live := store.live_primers(1, 2)
	assert_eq(live.size(), 1)
	assert_eq(live[0].type, &"sanctified", "a new primer replaces the player's old one")
	store.apply(1, &"frozen", GUEST, 1.0, 2, DURATION, 3)
	assert_eq(store.live_primers(1, 3).size(), 2, "at most two per enemy")


func test_action_cannot_consume_its_own_primer() -> void:
	store.apply(1, &"dazed", HOST, 1.0, 0, DURATION, 50)
	var out := resolver.resolve_finisher(1, HOST, &"impact", 50, 1)
	assert_eq(out.kind, ReactionResolver.Kind.NONE)
	assert_eq(store.live_primers(1, 1).size(), 1)


func test_one_detonation_per_action_per_target() -> void:
	store.apply(1, &"dazed", HOST, 1.0, 0, DURATION, 1)
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 2)
	assert_eq(resolver.resolve_finisher(1, HOST, &"impact", 60, 5).kind, ReactionResolver.Kind.RESONANCE)
	assert_eq(resolver.resolve_finisher(1, HOST, &"impact", 60, 6).kind, ReactionResolver.Kind.NONE, "a second projectile of the same action")
	assert_eq(store.live_primers(1, 6).size(), 1)


func test_two_finishers_on_one_primer() -> void:
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 1)
	assert_eq(resolver.resolve_finisher(1, HOST, &"impact", 70, 5).kind, ReactionResolver.Kind.RESONANCE)
	assert_eq(resolver.resolve_finisher(1, GUEST, &"arcane", 71, 5).kind, ReactionResolver.Kind.NONE, "the later arrival is a normal hit")


func test_expired_primers_do_nothing() -> void:
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 1)
	assert_eq(resolver.resolve_finisher(1, HOST, &"impact", 2, DURATION).kind, ReactionResolver.Kind.NONE)


func test_lockout_after_detonation() -> void:
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 1)
	resolver.resolve_finisher(1, HOST, &"impact", 2, 10)
	assert_false(store.apply(1, &"frozen", GUEST, 1.0, 100, DURATION, 3), "same type locked out for 4 s")
	assert_true(store.apply(1, &"dazed", HOST, 1.0, 100, DURATION, 4), "other types are fine")
	assert_true(store.apply(1, &"frozen", GUEST, 1.0, 10 + resolver.lockout_ticks, DURATION, 5))


func test_mirror_classes_resonate() -> void:
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 1)
	var out := resolver.resolve_finisher(1, HOST, &"arcane", 2, 5)
	assert_eq(out.kind, ReactionResolver.Kind.RESONANCE, "partner means the other player, not another class")
	assert_eq(out.reaction_id, &"superconduct")


func test_every_combination_has_a_reaction() -> void:
	var count := 0
	for primer: StringName in GameTypes.PRIMER_TYPES:
		for finisher: StringName in GameTypes.FINISHER_TYPES:
			var out := ReactionResolver.Outcome.new()
			ReactionResolver.describe(out, primer, finisher)
			assert_ne(out.name, "", "%s -> %s has a name" % [primer, finisher])
			assert_ne(out.reaction_id, &"", "%s -> %s has an id" % [primer, finisher])
			count += 1
	assert_eq(count, 32)
	assert_eq(GameData.signatures.size(), 16, "sixteen signature reactions")


func test_detonations_leave_no_new_primer() -> void:
	store.apply(1, &"frozen", GUEST, 1.0, 0, DURATION, 1)
	resolver.resolve_finisher(1, HOST, &"impact", 2, 5)
	assert_eq(store.live_primers(1, 5).size(), 0, "reactions never apply primers")
