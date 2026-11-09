class_name ReactionEffects
extends RefCounted
## What a reaction does once the resolver has chosen it. Signature reactions have their own effect;
## every other primer x finisher is the primer's base effect plus the finisher's twist, so no
## combination is ever blank. Reaction damage never triggers reactions and never applies primers.

const IMPLEMENTED_SIGNATURES: Array[StringName] = [&"shatterfall", &"thunderclap", &"twin_verdict", &"superconduct"]


## Multiplier on the triggering hit's stagger (Concussion, Twin Verdict, the Impact twist).
static func stagger_multiplier(outcome: ReactionResolver.Outcome) -> float:
	if outcome == null:
		return 1.0
	var s := outcome.strength
	var mult := 1.0
	if outcome.is_signature and outcome.reaction_id == &"twin_verdict":
		return 1.0 + (float(outcome.signature["magnitude"]) - 1.0) * s
	if StringName(outcome.base_effect.get("effect_id", "")) == &"concussion":
		mult *= 1.0 + (float(outcome.base_effect["magnitude"]) - 1.0) * s
	if StringName(outcome.twist.get("twist_id", "")) == &"impact_twist":
		mult *= 1.0 + float(outcome.twist["magnitude"]) * s
	return mult


## Extra knockback impulse added to the triggering hit.
static func extra_impulse(outcome: ReactionResolver.Outcome) -> float:
	if outcome == null:
		return 0.0
	if outcome.is_signature and outcome.reaction_id in IMPLEMENTED_SIGNATURES:
		return float(outcome.signature.get("impulse", 0.0)) * 0.5 * outcome.strength
	if StringName(outcome.twist.get("twist_id", "")) == &"impact_twist":
		return float(outcome.twist["impulse"]) * outcome.strength
	return 0.0


## Extra crit chance on the triggering hit (Pinpoint, Precision twist).
static func crit_bonus(outcome: ReactionResolver.Outcome) -> float:
	if outcome == null:
		return 0.0
	var bonus := 0.0
	if StringName(outcome.base_effect.get("effect_id", "")) == &"pinpoint":
		bonus += float(outcome.base_effect["magnitude"]) * outcome.strength
	if StringName(outcome.twist.get("twist_id", "")) == &"precision_twist":
		bonus += float(outcome.twist["magnitude"]) * outcome.strength
	return bonus


static func apply(cs: CombatSystem, outcome: ReactionResolver.Outcome, target: Enemy, h: CombatSystem.HitSpec, hit_damage: float, t: int) -> float:
	var s := outcome.strength
	var center := target.global_position
	var radius := 0.0
	if outcome.is_signature and outcome.reaction_id in IMPLEMENTED_SIGNATURES:
		var row := outcome.signature
		radius = float(row["radius"]) * (0.7 + 0.3 * s)
		match outcome.reaction_id:
			&"shatterfall":
				var struck := cs.area_hit(center, radius, h, hit_damage * float(row["damage_scale"]) * s, &"cold", target.id, float(row["impulse"]) * s)
				struck.append(target)
				for e: Enemy in struck:
					e.add_status(&"exposed", roundi(float(row["duration"]) * 60.0 * s), float(row["magnitude"]), h.slot, t)
			&"thunderclap":
				cs.arc_lightning(target, int(row["magnitude"]), radius + 2.0, hit_damage * float(row["damage_scale"]) * s, h)
				cs.surface_apply(center, radius, &"lightning", h.slot)
			&"twin_verdict":
				if cs.consume_sanctified_near(center, radius):
					cs.area_hit(center, radius, h, hit_damage * float(row["damage_scale"]) * s, &"holy", -1, float(row["impulse"]) * s)
			&"superconduct":
				for e: Enemy in cs.entities.query_radius(center, radius, -1, false):
					e.add_status(&"superconduct", roundi(float(row["duration"]) * 60.0 * s), float(row["magnitude"]), h.slot, t)
		return radius
	# Base effect of the primer.
	var base := outcome.base_effect
	var base_radius := float(base.get("radius", 0.0)) * (0.7 + 0.3 * s)
	radius = base_radius
	match StringName(base.get("effect_id", "")):
		&"radiance":
			cs.area_hit(center, base_radius, h, hit_damage * float(base["damage_scale"]) * s, &"holy", target.id, 0.0)
			cs.barrier_heroes_near(center, base_radius, float(base["magnitude"]) * s, float(base["duration"]), h.slot)
		&"shatter":
			var struck := cs.area_hit(center, base_radius, h, hit_damage * float(base["damage_scale"]) * s, &"cold", target.id, 0.0)
			struck.append(target)
			for e: Enemy in struck:
				e.add_status(&"exposed", roundi(float(base["duration"]) * 60.0 * s), float(base["magnitude"]), h.slot, t)
		&"discharge":
			cs.arc_lightning(target, int(base["magnitude"]), base_radius, hit_damage * float(base["damage_scale"]) * s, h)
			cs.surface_apply(center, 2.0, &"lightning", h.slot)
		&"pinpoint":
			if not target.is_elite() and target.health_fraction() < 0.15 and not target.def.immortal:
				cs.execute(target, h.slot, t)
		&"rupture":
			cs.area_hit(center, 0.1, h, hit_damage * float(base["damage_scale"]) * s, &"poison", -1, 0.0, [target])
		&"snap":
			target.launch(roundi(float(base["duration"]) * 60.0 * s), t)
		&"panic_break":
			for e: Enemy in cs.entities.query_radius(center, base_radius, -1, false):
				e.knock_down(roundi(float(base["duration"]) * 60.0), t)
	# Twist of the finisher.
	var twist := outcome.twist
	match StringName(twist.get("twist_id", "")):
		&"arcane_twist":
			var element := StringName(str(base.get("element", "")))
			if element in GameTypes.ELEMENTS:
				cs.surface_apply(center, float(twist["radius"]) * (0.6 + 0.4 * s), element, h.slot)
			radius = maxf(radius, float(twist["radius"]))
		&"primal_twist":
			cs.heal_heroes_near(center, float(twist["radius"]), float(twist["magnitude"]) * s)
	return radius
