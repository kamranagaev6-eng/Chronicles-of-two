class_name RuneDefinition
extends Resource
## A rune changes how an ability behaves. Tags decide where it fits.

@export var id: StringName
@export var display_name: String
## form | bond | technique
@export var category: StringName = &"form"
@export_multiline var description: String
## The ability must carry at least one of these rune tags.
@export var requires_any_tags: Array[StringName] = []
## The ability must carry none of these.
@export var excludes_tags: Array[StringName] = []
@export var extra_projectiles: int = 0
@export var fork_count: int = 0
@export var chain_count: int = 0
@export var pierce_add: int = 0
@export var range_multiplier: float = 1.0
@export var area_multiplier: float = 1.0
## Separate "more" factor on the ability's damage.
@export var damage_more: float = 1.0
@export var cost_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
## Echo: the ability's impact repeats after a delay at a fraction of its damage (0 = no echo).
## Echoes never echo, never apply primers and never trigger reactions.
@export var echo_delay_s: float = 0.0
@export var echo_damage_fraction: float = 0.0
## Lingering: zones, surfaces, barriers and statuses the ability creates last longer.
@export var duration_multiplier: float = 1.0
## Bond runes. Their bonuses are co-op "more" factors, capped together with Bond perks and Link skills.
## Resonant: Resonances this skill primes or triggers.
@export var resonance_more: float = 1.0
## Tethered: while the Bond Tether is connected.
@export var tether_more: float = 1.0
## Kinship: share of damage dealt that heals the partner, capped per hit (fraction of their max health).
@export var partner_heal_fraction: float = 0.0
@export var partner_heal_cap_fraction: float = 0.0
## Attune: the partner's next skill within this many seconds takes this skill's element.
@export var attune_seconds: float = 0.0


## Tags decide what fits: the ability's rune tags plus its behaviour tags (primer, finisher, support...).
func fits(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	var any_match := requires_any_tags.is_empty()
	for tag: StringName in requires_any_tags:
		if ability.rune_tags.has(tag) or ability.tags.has(tag):
			any_match = true
			break
	if not any_match:
		return false
	for tag: StringName in excludes_tags:
		if ability.rune_tags.has(tag) or ability.tags.has(tag):
			return false
	return true


## Which loadout socket the rune occupies.
func socket() -> StringName:
	return category
