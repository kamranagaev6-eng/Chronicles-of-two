class_name DamageCalculator
extends RefCounted
## The one damage formula, in one fixed order. Tooltips call the same code, so the number you read
## is the number you get:
##   Hit = sum over packets of (B + E*A) * (1 + I) * (prod M_k) * C * (1 - R) * (1 + V) * X
## Fractional precision is kept to the end; round only for display and stored state.


class Packet:
	extends RefCounted
	var damage_type: StringName = &"physical"
	var base: float = 0.0          ## B: skill base damage including weapon contribution
	var added: float = 0.0         ## A: added flat damage
	var effectiveness: float = 1.0 ## E: the skill's added-damage effectiveness

	func _init(p_type: StringName = &"physical", p_base: float = 0.0, p_added: float = 0.0, p_eff: float = 1.0) -> void:
		damage_type = p_type
		base = p_base
		added = p_added
		effectiveness = p_eff


class Context:
	extends RefCounted
	## I: increased/reduced, one additive pool. Keys: damage type, &"all", &"elemental", &"spell".
	var increased: Dictionary = {}
	## M_k: independent more/less factors (runes, keystones, specializations).
	var more: Array[float] = []
	## Co-op factors (Bond perks, Bond runes, Link skills): multiplied together, capped as a group.
	var coop_more: Array[float] = []
	var crit: bool = false
	var crit_multiplier: float = 1.5
	var armour: float = 0.0
	## Fraction of armour ignored (e.g. Sundering Judgment).
	var armour_ignore: float = 0.0
	## Elemental resistances by damage type (fractions; may be negative).
	var resistances: Dictionary = {}
	## V contributions that apply to every packet (Staggered, Hex Bloom).
	var vulnerability: float = 0.0
	## V contributions that apply to elemental packets only (Exposed, Superconduct).
	var elemental_vulnerability: float = 0.0
	## X: 2 for a Resonance, 1.25 for a Basic reaction, otherwise 1.
	var reaction_multiplier: float = 1.0
	var is_spell: bool = false

	func increased_for(damage_type: StringName) -> float:
		var total: float = increased.get(&"all", 0.0)
		total += increased.get(damage_type, 0.0)
		if GameTypes.is_elemental(damage_type):
			total += increased.get(&"elemental", 0.0)
		if is_spell:
			total += increased.get(&"spell", 0.0)
		return total


class Caps:
	extends RefCounted
	var armour_hit_factor: float = 10.0
	var armour_cap: float = 0.9
	var resist_cap: float = 0.75
	var vulnerability_cap: float = 1.0
	var coop_cap: float = 1.5

	static func from_rules() -> Caps:
		var caps := Caps.new()
		caps.armour_hit_factor = GameData.rule(&"armour_hit_factor")
		caps.armour_cap = GameData.rule(&"armour_cap")
		caps.resist_cap = GameData.rule(&"resist_cap")
		caps.vulnerability_cap = GameData.rule(&"vulnerability_cap")
		caps.coop_cap = GameData.rule(&"coop_more_cap")
		return caps


class Result:
	extends RefCounted
	var total: float = 0.0
	var by_type: Dictionary = {}
	## Damage prevented by armour and resistances.
	var mitigated: float = 0.0
	var crit: bool = false


static func coop_factor(ctx: Context, caps: Caps) -> float:
	var product := 1.0
	for f: float in ctx.coop_more:
		product *= f
	return minf(product, caps.coop_cap)


static func more_factor(ctx: Context) -> float:
	var product := 1.0
	for f: float in ctx.more:
		product *= f
	return product


## Physical mitigation from armour for a hit of the given size.
static func armour_reduction(armour: float, hit: float, caps: Caps) -> float:
	if armour <= 0.0 or hit <= 0.0:
		return 0.0
	return minf(armour / (armour + caps.armour_hit_factor * hit), caps.armour_cap)


static func compute(packets: Array[Packet], ctx: Context, caps: Caps) -> Result:
	var result := Result.new()
	result.crit = ctx.crit
	var more := more_factor(ctx) * coop_factor(ctx, caps)
	var crit := ctx.crit_multiplier if ctx.crit else 1.0
	for packet: Packet in packets:
		var raw := packet.base + packet.effectiveness * packet.added
		if raw <= 0.0:
			continue
		var pre := raw * (1.0 + ctx.increased_for(packet.damage_type)) * more * crit
		pre = maxf(pre, 0.0)
		var r := 0.0
		if packet.damage_type == &"physical":
			r = armour_reduction(ctx.armour * (1.0 - ctx.armour_ignore), pre, caps)
		else:
			r = minf(float(ctx.resistances.get(packet.damage_type, 0.0)), caps.resist_cap)
		var v := ctx.vulnerability
		if GameTypes.is_elemental(packet.damage_type):
			v += ctx.elemental_vulnerability
		v = minf(v, caps.vulnerability_cap)
		var after_mitigation := pre * (1.0 - r)
		var dealt := after_mitigation * (1.0 + v) * ctx.reaction_multiplier
		result.mitigated += pre - after_mitigation
		result.total += dealt
		result.by_type[packet.damage_type] = float(result.by_type.get(packet.damage_type, 0.0)) + dealt
	return result
