class_name FlowField
extends RefCounted
## Grid Dijkstra toward a target, refreshed a few times a second by the host. Swarms read a direction
## per cell instead of each running its own path query. Costs: 10 straight, 14 diagonal; no corner cutting.

const UNREACHABLE := 1 << 30

var width: int = 0
var height: int = 0
var cell_size: float = 1.0
var origin: Vector2 = Vector2.ZERO
var walkable := PackedByteArray()
var dist := PackedInt32Array()
var target_cell := Vector2i(-1, -1)

const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


func setup(p_width: int, p_height: int, p_cell_size: float, p_origin: Vector2) -> void:
	width = p_width
	height = p_height
	cell_size = p_cell_size
	origin = p_origin
	walkable.resize(width * height)
	walkable.fill(1)
	dist.resize(width * height)
	dist.fill(UNREACHABLE)


func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori((pos.x - origin.x) / cell_size), floori((pos.z - origin.y) / cell_size))


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * cell_size, 0.0, origin.y + (c.y + 0.5) * cell_size)


func block_circle(center: Vector3, radius: float) -> void:
	var c0 := cell_of(center - Vector3(radius, 0, radius))
	var c1 := cell_of(center + Vector3(radius, 0, radius))
	for y in range(maxi(0, c0.y), mini(height - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(width - 1, c1.x) + 1):
			var cc := cell_center(Vector2i(x, y))
			if Vector2(cc.x - center.x, cc.z - center.z).length() <= radius:
				walkable[y * width + x] = 0


func block_rect(min_corner: Vector3, max_corner: Vector3) -> void:
	var c0 := cell_of(min_corner)
	var c1 := cell_of(max_corner)
	for y in range(maxi(0, c0.y), mini(height - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(width - 1, c1.x) + 1):
			walkable[y * width + x] = 0


func is_walkable(pos: Vector3) -> bool:
	var c := cell_of(pos)
	return in_bounds(c) and walkable[c.y * width + c.x] == 1


func compute(target: Vector3) -> void:
	dist.fill(UNREACHABLE)
	target_cell = _nearest_walkable(cell_of(target))
	if target_cell.x < 0:
		return
	var heap := _Heap.new()
	var start := target_cell.y * width + target_cell.x
	dist[start] = 0
	heap.push(0, start)
	while not heap.is_empty():
		var top := heap.pop()
		var d: int = top[0]
		var i: int = top[1]
		if d > dist[i]:
			continue
		var x := i % width
		var y := i / width
		for k in 8:
			var dir := _DIRS[k]
			var nx := x + dir.x
			var ny := y + dir.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var n := ny * width + nx
			if walkable[n] == 0:
				continue
			if k >= 4 and (walkable[y * width + nx] == 0 or walkable[ny * width + x] == 0):
				continue
			var nd := d + (14 if k >= 4 else 10)
			if nd < dist[n]:
				dist[n] = nd
				heap.push(nd, n)


func distance_at(pos: Vector3) -> int:
	var c := cell_of(pos)
	if not in_bounds(c):
		return UNREACHABLE
	return dist[c.y * width + c.x]


func reachable(pos: Vector3) -> bool:
	return distance_at(pos) < UNREACHABLE


## Unit direction toward the target from this position (zero at the target or when unreachable).
func direction_at(pos: Vector3) -> Vector3:
	var c := cell_of(pos)
	if not in_bounds(c):
		return GameTypes.flat_dir(pos, cell_center(target_cell)) if target_cell.x >= 0 else Vector3.ZERO
	var i := c.y * width + c.x
	if dist[i] >= UNREACHABLE:
		var w := _nearest_walkable(c)
		return GameTypes.flat_dir(pos, cell_center(w)) if w.x >= 0 else Vector3.ZERO
	if dist[i] == 0:
		return Vector3.ZERO
	var best := i
	var best_d := dist[i]
	for k in 8:
		var dir := _DIRS[k]
		var nx := c.x + dir.x
		var ny := c.y + dir.y
		if nx < 0 or ny < 0 or nx >= width or ny >= height:
			continue
		if k >= 4 and (walkable[c.y * width + nx] == 0 or walkable[ny * width + c.x] == 0):
			continue
		var n := ny * width + nx
		if dist[n] < best_d:
			best_d = dist[n]
			best = n
	if best == i:
		return Vector3.ZERO
	return GameTypes.flat_dir(pos, cell_center(Vector2i(best % width, best / width)))


func _nearest_walkable(c: Vector2i) -> Vector2i:
	if in_bounds(c) and walkable[c.y * width + c.x] == 1:
		return c
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := Vector2i(c.x + dx, c.y + dy)
				if in_bounds(n) and walkable[n.y * width + n.x] == 1:
					return n
	return Vector2i(-1, -1)


## Minimal binary heap of [priority, value] pairs.
class _Heap:
	extends RefCounted
	var _p := PackedInt32Array()
	var _v := PackedInt32Array()

	func is_empty() -> bool:
		return _p.is_empty()

	func push(priority: int, value: int) -> void:
		_p.append(priority)
		_v.append(value)
		var i := _p.size() - 1
		while i > 0:
			var parent := (i - 1) / 2
			if _p[parent] <= _p[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> Array:
		var top := [_p[0], _v[0]]
		var last := _p.size() - 1
		_p[0] = _p[last]
		_v[0] = _v[last]
		_p.resize(last)
		_v.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < _p.size() and _p[l] < _p[m]:
				m = l
			if r < _p.size() and _p[r] < _p[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var tp := _p[a]
		_p[a] = _p[b]
		_p[b] = tp
		var tv := _v[a]
		_v[a] = _v[b]
		_v[b] = tv
