class_name ArenaLayout
extends RefCounted
## The Milestone 1 combat arena: a flooded crypt hall. One description feeds the collision geometry,
## the flow-field walkability, the pre-placed surfaces and the spawn points, so they never disagree.
## Scale: 1 unit = 1 m; heroes are 1.8 m tall; walls 3 m high.

const SIZE := Vector2(36.0, 28.0)
const ORIGIN := Vector2(-18.0, -14.0)
const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 1.0

const PILLARS: Array[Vector3] = [
	Vector3(-11, 0, -6), Vector3(11, 0, -6), Vector3(-6, 0, 2), Vector3(6, 0, 2.5), Vector3(-12, 0, 7), Vector3(12, 0, 6.5)]
const PILLAR_RADIUS := 0.8

## Low broken walls inside the hall: [center, size]. Good for wall slams.
const BLOCKS: Array = [
	[Vector3(0, 0, -3.5), Vector3(4.0, 1.4, 0.8)],
	[Vector3(-15.5, 0, 3.5), Vector3(0.8, 1.6, 3.0)],
	[Vector3(15.5, 0, -6.5), Vector3(0.8, 1.6, 3.0)],
]

const WATER_RECTS: Array = [
	[Vector3(-9.0, 0, -11.0), Vector3(-2.5, 0, -5.5)],
	[Vector3(2.5, 0, 4.0), Vector3(9.5, 0, 8.5)],
]
const WATER_CIRCLES: Array = [[Vector3(-13.0, 0, 0.0), 2.2]]
const OIL_RECTS: Array = [[Vector3(-1.5, 0, -12.8), Vector3(4.5, 0, -10.0)]]
const OIL_CIRCLES: Array = [[Vector3(13.0, 0, -10.0), 1.8]]

const OIL_BARRELS: Array[Vector3] = [Vector3(-15.5, 0, -11.0), Vector3(14.8, 0, -1.5), Vector3(1.2, 0, -7.0)]
const WATER_BARRELS: Array[Vector3] = [Vector3(-15.0, 0, 10.0), Vector3(9.0, 0, 11.5)]
const DUMMIES: Array[Vector3] = [Vector3(14.0, 0, 10.5), Vector3(16.0, 0, 7.5)]

const WAYSTONE := Vector3(0.0, 0.0, 10.0)
const HERO_SPAWNS: Array[Vector3] = [Vector3(-1.6, 0, 11.0), Vector3(1.6, 0, 11.0)]
const SPAWNS := {
	&"north": Vector3(0.0, 0, -12.5),
	&"west": Vector3(-16.5, 0, -2.5),
	&"east": Vector3(16.5, 0, -2.5),
}
const BRAZIERS: Array[Vector3] = [Vector3(-17, 0, -13), Vector3(17, 0, -13), Vector3(-17, 0, 13), Vector3(17, 0, 13), Vector3(-3, 0, 12.5), Vector3(3, 0, 12.5)]


static func bounds_min() -> Vector3:
	return Vector3(ORIGIN.x, 0, ORIGIN.y)


static func bounds_max() -> Vector3:
	return Vector3(ORIGIN.x + SIZE.x, 0, ORIGIN.y + SIZE.y)


static func paint_surfaces(grid: SurfaceGrid) -> void:
	for r: Array in WATER_RECTS:
		grid.paint_base_rect(r[0], r[1], SurfaceGrid.WATER)
	for c: Array in WATER_CIRCLES:
		grid.paint_base_circle(c[0], c[1], SurfaceGrid.WATER)
	for r: Array in OIL_RECTS:
		grid.paint_base_rect(r[0], r[1], SurfaceGrid.OIL)
	for c: Array in OIL_CIRCLES:
		grid.paint_base_circle(c[0], c[1], SurfaceGrid.OIL)


## Walkability for enemy flow fields (obstacles inflated by a typical enemy radius).
static func configure_flow(field: FlowField) -> void:
	field.setup(int(SIZE.x), int(SIZE.y), 1.0, ORIGIN)
	for p: Vector3 in PILLARS:
		field.block_circle(p, PILLAR_RADIUS + 0.45)
	for b: Array in BLOCKS:
		var c: Vector3 = b[0]
		var s: Vector3 = b[1]
		field.block_rect(c - Vector3(s.x * 0.5 + 0.45, 0, s.z * 0.5 + 0.45), c + Vector3(s.x * 0.5 + 0.45, 0, s.z * 0.5 + 0.45))
