class_name MaterialKit
extends RefCounted
## Photoscanned surface materials (CC0, ambientCG) for the placeholder primitives. Each kind is a
## ShaderMaterial resource in game/presentation/materials; tinted or adjusted variants are cached
## duplicates, so every part with the same look shares one material.

const KINDS: Dictionary[StringName, ShaderMaterial] = {
	&"crypt_wall": preload("res://game/presentation/materials/crypt_wall.tres"),
	&"crypt_stone": preload("res://game/presentation/materials/crypt_stone.tres"),
	# Recessed joints behind separately modelled blocks: dark, fully rough, damp, mossy grit.
	&"crypt_mortar": preload("res://game/presentation/materials/crypt_mortar.tres"),
	&"crypt_floor": preload("res://game/presentation/materials/crypt_floor.tres"),
	&"wood_planks": preload("res://game/presentation/materials/wood_planks.tres"),
	&"wood_grain": preload("res://game/presentation/materials/wood_grain.tres"),
	&"hair": preload("res://game/presentation/materials/hair.tres"),
	&"steel_worn": preload("res://game/presentation/materials/steel_worn.tres"),
	&"iron_rusted": preload("res://game/presentation/materials/iron_rusted.tres"),
	&"gilded": preload("res://game/presentation/materials/gilded.tres"),
	&"cloth": preload("res://game/presentation/materials/cloth.tres"),
	&"burlap": preload("res://game/presentation/materials/burlap.tres"),
	&"leather": preload("res://game/presentation/materials/leather.tres"),
	&"drowned_flesh": preload("res://game/presentation/materials/drowned_flesh.tres"),
}
const GROUND: ShaderMaterial = preload("res://game/presentation/materials/crypt_ground.tres")

static var _cache: Dictionary[String, Material] = {}


## The kind's material, optionally recoloured (tint keeps the photo's light and dark detail) and with
## any shader parameters overridden. Returns the shared base resource when nothing changes.
static func surface(kind: StringName, tint: Color = Color.WHITE, overrides: Dictionary = {}) -> ShaderMaterial:
	var base: ShaderMaterial = KINDS[kind]
	if tint == Color.WHITE and overrides.is_empty():
		return base
	var key := "%s|%s|%s" % [kind, tint.to_html(), str(overrides)]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var mat := base.duplicate() as ShaderMaterial
	if tint != Color.WHITE:
		mat.set_shader_parameter(&"tint", tint)
	for param: StringName in overrides:
		mat.set_shader_parameter(param, overrides[param])
	_cache[key] = mat
	return mat


## A metal trim in a player's colour that glows faintly, so the owner reads at a glance.
static func trim(accent: Color, glow: float = 0.35) -> ShaderMaterial:
	return surface(&"gilded", accent, {&"emission_color": accent, &"emission_energy": glow})


## Skin with a little subsurface scattering so faces and hands don't read as painted plastic.
static func skin(color: Color) -> StandardMaterial3D:
	var key := "skin|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.35
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	_cache[key] = m
	return m
