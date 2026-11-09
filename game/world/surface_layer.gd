class_name SurfaceLayer
extends Node3D
## Owns the elemental surface grid on this PC and draws it through the ground shader.
## The host simulates it; a guest applies the host's chunk patches. Both render the same way.

const GROUND_SHADER := preload("res://game/presentation/shaders/ground_surface.gdshader")

var grid := SurfaceGrid.new()
var image: Image
var texture: ImageTexture
var ground: MeshInstance3D
var _steam: Array[Node3D] = []


func setup(size: Vector2, origin: Vector2) -> void:
	var cell := GameData.rule(&"surface_cell_m")
	grid.setup(roundi(size.x / cell), roundi(size.y / cell), cell, origin, int(GameData.rule(&"surface_chunk_cells")))
	grid.configure_from_data()
	image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(image)
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	ground.mesh = plane
	ground.position = Vector3(origin.x + size.x * 0.5, 0.0, origin.y + size.y * 0.5)
	# The crypt-floor photoscan and its weathering settings live in materials/crypt_ground.tres.
	var mat := MaterialKit.GROUND.duplicate() as ShaderMaterial
	mat.set_shader_parameter("surface_tex", texture)
	mat.set_shader_parameter("grid_origin", origin)
	mat.set_shader_parameter("grid_size", size)
	ground.material_override = mat
	add_child(ground)


func _process(_delta: float) -> void:
	if grid.render_dirty.is_empty() or image == null:
		return
	for ci: int in grid.render_dirty.keys():
		var cx := ci % grid.chunks_x
		var cy := ci / grid.chunks_x
		for y in range(cy * grid.chunk_cells, mini(grid.height, (cy + 1) * grid.chunk_cells)):
			for x in range(cx * grid.chunk_cells, mini(grid.width, (cx + 1) * grid.chunk_cells)):
				var i := y * grid.width + x
				image.set_pixel(x, y, Color8(grid.material[i], grid.flags[i], grid.cloud[i], 255))
	grid.render_dirty.clear()
	texture.update(image)


func material_at(pos: Vector3) -> int:
	return grid.material_at(pos)


## Movement effect of the ground under a hero. Player-made ice never trips heroes (friendly fire is off).
func hero_query(pos: Vector3) -> Dictionary:
	var mat := grid.material_at(pos)
	var row: Dictionary = GameData.surface_materials.get(GameData.surface_name(mat), {})
	var speed := float(row.get("speed_multiplier", 1.0))
	var friction := float(row.get("friction", 1.0))
	var owner_id := grid.owner_at(pos)
	if owner_id == GameTypes.SLOT_HOST or owner_id == GameTypes.SLOT_GUEST:
		friction = 1.0
		speed = maxf(speed, 1.0) if mat == SurfaceGrid.ICE else speed
	return {"speed": speed, "friction": friction}
