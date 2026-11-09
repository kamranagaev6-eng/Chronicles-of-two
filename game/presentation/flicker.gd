extends OmniLight3D
## Warm firelight flicker for braziers and torches (presentation only).

var _base: float = -1.0
var _t: float = 0.0


func _process(delta: float) -> void:
	if _base < 0.0:
		_base = light_energy
		_t = randf() * 10.0
	_t += delta
	light_energy = _base * (0.85 + 0.1 * sin(_t * 7.3) + 0.05 * sin(_t * 17.1 + 1.3))
