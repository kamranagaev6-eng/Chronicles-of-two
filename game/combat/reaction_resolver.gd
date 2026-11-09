class_name ReactionResolver
extends RefCounted
## Resonance rules. A finisher consumes one primer, preferring the partner's:
##   partner's primer -> Resonance (x2, full named effect, fills the Bond meter)
##   own primer       -> Basic reaction (x1.25, half-strength effect)
## "Partner" means the other player, not another class. One action detonates at most once per target.
## Reactions are data rows keyed by (primer, finisher); this resolver never mentions class names.

enum Kind { NONE, RESONANCE, BASIC }


class Outcome:
	extends RefCounted
	var kind: int = Kind.NONE
	var primer: PrimerStore.Primer
	var finisher: StringName
	var reaction_id: StringName
	var name: String = ""
	var is_signature: bool = false
	var multiplier: float = 1.0
	## 1.0 for a Resonance, basic_effect_strength for a Basic reaction.
	var strength: float = 1.0
	## Signature row, or empty when the reaction is base effect + finisher twist.
	var signature: Dictionary = {}
	var base_effect: Dictionary = {}
	var twist: Dictionary = {}

	func triggered() -> bool:
		return kind != Kind.NONE


var store: PrimerStore
var resonance_multiplier: float = 2.0
var basic_multiplier: float = 1.25
var basic_strength: float = 0.5
var lockout_ticks: int = 240
var _detonated: Dictionary = {}  # "action|target" -> tick


func _init(p_store: PrimerStore = null) -> void:
	store = p_store if p_store != null else PrimerStore.new()


func configure_from_rules() -> void:
	resonance_multiplier = GameData.rule(&"resonance_multiplier")
	basic_multiplier = GameData.rule(&"basic_reaction_multiplier")
	basic_strength = GameData.rule(&"basic_effect_strength")
	lockout_ticks = GameData.rule_ticks(&"primer_lockout_s")


func resolve_finisher(target_id: int, attacker_slot: int, finisher: StringName, action_uid: int, tick: int) -> Outcome:
	var outcome := Outcome.new()
	outcome.finisher = finisher
	var key := "%d|%d" % [action_uid, target_id]
	if _detonated.has(key):
		return outcome
	var primer := store.consume_for_finisher(target_id, attacker_slot, tick, action_uid, lockout_ticks)
	if primer == null:
		return outcome
	_detonated[key] = tick
	outcome.primer = primer
	if primer.owner_slot != attacker_slot:
		outcome.kind = Kind.RESONANCE
		outcome.multiplier = resonance_multiplier
		outcome.strength = 1.0
	else:
		outcome.kind = Kind.BASIC
		outcome.multiplier = basic_multiplier
		outcome.strength = basic_strength
	describe(outcome, primer.type, finisher)
	return outcome


## Fill in the reaction identity for (primer, finisher): a signature row, or base effect + twist.
static func describe(outcome: Outcome, primer: StringName, finisher: StringName) -> void:
	outcome.base_effect = GameData.primers.get(primer, {}) as Dictionary
	outcome.twist = GameData.finishers.get(finisher, {}) as Dictionary
	var sig := GameData.signature_row(primer, finisher)
	if not sig.is_empty():
		outcome.signature = sig
		outcome.is_signature = true
		outcome.reaction_id = sig["reaction_id"]
		outcome.name = sig["name"]
	else:
		outcome.reaction_id = StringName("%s+%s" % [outcome.base_effect.get("effect_id", primer), outcome.twist.get("twist_id", finisher)])
		outcome.name = "%s (%s)" % [outcome.base_effect.get("name", String(primer)), outcome.twist.get("name", String(finisher))]


## Forget detonation records older than the given tick (actions never last that long).
func prune(tick: int, keep_ticks: int = 600) -> void:
	for key: String in _detonated.keys():
		if tick - int(_detonated[key]) > keep_ticks:
			_detonated.erase(key)
	store.prune(tick)
