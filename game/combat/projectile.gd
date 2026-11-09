class_name Projectile
extends RefCounted
## Pooled projectile data, always host-simulated: shape-cast every tick with a swept segment.
## Pierce, chain (nearest unhit within 8 m), fork (+/-25 degrees) and wall impacts.

const TEAM_HEROES := 0
const TEAM_ENEMIES := 1

var id: int = 0
var team: int = TEAM_HEROES
var slot: int = -1
var uid: int = 0
var ability: AbilityDefinition
var visual: int = 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var radius: float = 0.3
var remaining: float = 10.0
var pierce_left: int = 0
var fork_left: int = 0
var chain_left: int = 0
var more: Array[float] = []
var hits: Dictionary = {}
var alive: bool = true
## Enemy projectiles carry their own damage numbers.
var damage: float = 0.0
var damage_type: StringName = &"physical"
var source_entity: int = -1
var rune: RuneDefinition


func copy_for_split() -> Projectile:
	var p := Projectile.new()
	p.team = team
	p.slot = slot
	p.uid = uid
	p.ability = ability
	p.visual = visual
	p.position = position
	p.velocity = velocity
	p.radius = radius
	p.remaining = remaining
	p.pierce_left = pierce_left
	p.fork_left = 0
	p.chain_left = 0
	p.more = more.duplicate()
	p.hits = hits.duplicate()
	p.damage = damage
	p.damage_type = damage_type
	p.rune = rune
	return p
