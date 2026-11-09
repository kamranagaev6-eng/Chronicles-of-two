class_name BondTether
extends MeshInstance3D
## The Bond Tether: a ribbon of light within 14 m that fades out by 18 m and reconnects by itself.
## On its own it is cosmetic: it never pulls, never punishes separation, and each PC draws it from
## the hero positions it already has. Link abilities and Tetherblade runes (later) infuse it.

enum State { CONNECTED, FADING, DROPPED }

var hero_a: Node3D
var hero_b: Node3D
var color_a := ProcMesh.GOLD
var color_b := ProcMesh.VIOLET
var full_m: float = 14.0
var fade_m: float = 18.0
var _im := ImmediateMesh.new()
var _t: float = 0.0


static func state_for(distance: float, full: float, fade: float) -> int:
	if distance <= full:
		return State.CONNECTED
	if distance <= fade:
		return State.FADING
	return State.DROPPED


static func alpha_for(distance: float, full: float, fade: float) -> float:
	if distance <= full:
		return 1.0
	if distance >= fade:
		return 0.0
	return 1.0 - (distance - full) / (fade - full)


func _ready() -> void:
	mesh = _im
	full_m = GameData.rule(&"tether_full_m")
	fade_m = GameData.rule(&"tether_fade_m")
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true


func _process(delta: float) -> void:
	_t += delta
	_im.clear_surfaces()
	if hero_a == null or hero_b == null or not is_instance_valid(hero_a) or not is_instance_valid(hero_b):
		return
	if not hero_a.visible or not hero_b.visible:
		return
	var a := hero_a.global_position + Vector3(0, 1.0, 0)
	var b := hero_b.global_position + Vector3(0, 1.0, 0)
	var dist := GameTypes.flat(b - a).length()
	var alpha := alpha_for(dist, full_m, fade_m)
	if alpha <= 0.01 or dist < 0.5:
		return
	var segments := 24
	var side := (b - a).cross(Vector3.UP).normalized() * 0.07
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segments + 1:
		var k := float(i) / segments
		var p := a.lerp(b, k)
		p.y -= sin(k * PI) * minf(0.6, dist * 0.04)
		p.y += sin(k * 9.0 - _t * 4.0) * 0.05
		var c := color_a.lerp(color_b, k)
		c.a = alpha * (0.35 + 0.25 * sin(k * 12.0 - _t * 6.0) ** 2)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side)
	_im.surface_end()
