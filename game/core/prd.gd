class_name PrdRoller
extends RefCounted
## Pseudo-random distribution: the chance grows with each miss so streaks stay short,
## while the long-run proc rate equals the nominal chance. Host-only (uses the host RNG).

static var _c_cache: Dictionary = {}

var _attempts: Dictionary = {}  # key -> attempts since the last proc


## Probability increment C for a nominal chance p (cached, binary search on the expected rate).
static func c_for(p: float) -> float:
	if p <= 0.0:
		return 0.0
	if p >= 1.0:
		return 1.0
	var key := snappedf(p, 0.0001)
	if _c_cache.has(key):
		return _c_cache[key]
	var lo := 0.0
	var hi := p
	var c := p
	for _i in 60:
		c = (lo + hi) * 0.5
		var rate := _rate_for_c(c)
		if rate > p:
			hi = c
		else:
			lo = c
	_c_cache[key] = c
	return c


static func _rate_for_c(c: float) -> float:
	var expected := 0.0
	var no_proc := 1.0
	var n := 1
	while true:
		var chance := minf(1.0, c * n)
		expected += n * no_proc * chance
		no_proc *= (1.0 - chance)
		if chance >= 1.0 or no_proc < 1e-12:
			break
		n += 1
	return 1.0 / expected


func roll(key: Variant, p: float, rng: RandomNumberGenerator) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	var n: int = int(_attempts.get(key, 0)) + 1
	var chance := minf(1.0, c_for(p) * n)
	if rng.randf() < chance:
		_attempts[key] = 0
		return true
	_attempts[key] = n
	return false


func reset(key: Variant) -> void:
	_attempts.erase(key)
