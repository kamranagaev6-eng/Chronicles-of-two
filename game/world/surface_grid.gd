class_name SurfaceGrid
extends RefCounted
## Elemental surfaces on a 0.5 m grid in bounded chunks. Every cell stores its material, the base material
## it reverts to, flags (Electrified, Blessed, Cursed), owner and expiry; clouds live on a separate layer.
## The host updates active cells at 10 Hz from the rules table; guests receive chunk patches.
## Pure and deterministic: no nodes, no randomness, time measured in update ticks.

const FLAG_ELECTRIFIED := 1
const FLAG_BLESSED := 2
const FLAG_CURSED := 4
## Network-only bit: the guest learns whether a cell is player-made (it never needs the exact owner).
const FLAG_PLAYER_MADE := 128
const FLAG_NAMES := {&"electrified": FLAG_ELECTRIFIED, &"blessed": FLAG_BLESSED, &"cursed": FLAG_CURSED}
const CLOUD_NONE := 0
const CLOUD_STEAM := 1

const NONE := 0
const WATER := 1
const ICE := 2
const OIL := 3
const BURNING := 4
const SANCTIFIED := 5

var width: int = 0
var height: int = 0
var cell_size: float = 0.5
var origin: Vector2 = Vector2.ZERO
var chunk_cells: int = 16
var chunks_x: int = 0
var chunks_y: int = 0
var update_hz: int = 10

var material := PackedByteArray()
var base := PackedByteArray()
var heat := PackedByteArray()
var flags := PackedByteArray()
var owner := PackedByteArray()
var expiry := PackedInt32Array()
var flag_expiry := PackedInt32Array()
var cloud := PackedByteArray()
var cloud_expiry := PackedInt32Array()
var chunk_revision := PackedInt32Array()
var update_tick: int = 1

## Reaction events produced since the consumer last cleared them: {type, position, owner, count, element}.
var events: Array[Dictionary] = []
## Chunks changed since the renderer last looked.
var render_dirty: Dictionary = {}

var burning_updates: int = 60
var spread_updates: int = 3
var steam_updates: int = 30
var electrify_flood_limit: int = 800

var _rules: Dictionary = {}     # material * 8 + element -> rule
var _active: Dictionary = {}    # cell index -> true
var _dirty: Dictionary = {}     # chunk index -> true (network)


func setup(p_width: int, p_height: int, p_cell_size: float, p_origin: Vector2, p_chunk_cells: int = 16) -> void:
	width = p_width
	height = p_height
	cell_size = p_cell_size
	origin = p_origin
	chunk_cells = p_chunk_cells
	chunks_x = ceili(float(width) / chunk_cells)
	chunks_y = ceili(float(height) / chunk_cells)
	var n := width * height
	material.resize(n)
	material.fill(NONE)
	base.resize(n)
	base.fill(NONE)
	heat.resize(n)
	heat.fill(0)
	flags.resize(n)
	flags.fill(0)
	owner.resize(n)
	owner.fill(GameTypes.OWNER_WORLD)
	expiry.resize(n)
	expiry.fill(0)
	flag_expiry.resize(n)
	flag_expiry.fill(0)
	cloud.resize(n)
	cloud.fill(CLOUD_NONE)
	cloud_expiry.resize(n)
	cloud_expiry.fill(0)
	chunk_revision.resize(chunks_x * chunks_y)
	chunk_revision.fill(0)
	_active.clear()
	_dirty.clear()
	render_dirty.clear()
	events.clear()
	update_tick = 1


## Load reaction rules and timings from GameData (surface_reactions.csv and rules.csv).
func configure_from_data() -> void:
	var rows: Array[Dictionary] = []
	for key: String in GameData.surface_reactions.keys():
		rows.append(GameData.surface_reactions[key])
	var codes: Dictionary = {}
	for mat: StringName in GameData.surface_materials.keys():
		codes[mat] = int((GameData.surface_materials[mat] as Dictionary)["code"])
	update_hz = int(GameData.rule(&"surface_update_hz"))
	spread_updates = maxi(1, roundi(GameData.rule(&"fire_spread_s") * update_hz))
	configure_rules(rows, codes)


## rows: dictionaries shaped like surface_reactions.csv rows; codes: material name -> code.
func configure_rules(rows: Array[Dictionary], codes: Dictionary) -> void:
	_rules.clear()
	for row: Dictionary in rows:
		var mat: int = codes.get(row["material"], -1)
		var elem := GameTypes.element_index(row["element"])
		var result: int = codes.get(row["result"], -1)
		if mat < 0 or elem < 0 or result < 0:
			push_error("SurfaceGrid: bad rule %s" % row)
			continue
		var base_after_name: StringName = row.get("base_after", &"")
		var rule := {
			"result": result,
			"base_after": codes.get(base_after_name, -1) if base_after_name != &"" else -1,
			"add": _flag_bits(row.get("add_flags", [])),
			"clear": _flag_bits(row.get("clear_flags", [])),
			"event": row.get("event", &""),
			"duration": roundi(float(row.get("duration_s", 0.0)) * update_hz),
		}
		_rules[mat * 8 + elem] = rule
		if mat == OIL and elem == GameTypes.element_index(&"fire"):
			burning_updates = maxi(1, rule["duration"])


static func _flag_bits(names: Variant) -> int:
	var bits := 0
	if names is Array:
		for n: Variant in names:
			bits |= int(FLAG_NAMES.get(StringName(str(n)), 0))
	return bits


# --- Geometry ----------------------------------------------------------------

func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori((pos.x - origin.x) / cell_size), floori((pos.z - origin.y) / cell_size))


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index_of(c: Vector2i) -> int:
	return c.y * width + c.x


func index_at(pos: Vector3) -> int:
	var c := cell_of(pos)
	return index_of(c) if in_bounds(c) else -1


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * cell_size, 0.0, origin.y + (c.y + 0.5) * cell_size)


func chunk_of_index(i: int) -> int:
	var cx := (i % width) / chunk_cells
	var cy := (i / width) / chunk_cells
	return cy * chunks_x + cx


func material_at(pos: Vector3) -> int:
	var i := index_at(pos)
	return material[i] if i >= 0 else NONE


func flags_at(pos: Vector3) -> int:
	var i := index_at(pos)
	return flags[i] if i >= 0 else 0


func owner_at(pos: Vector3) -> int:
	var i := index_at(pos)
	return owner[i] if i >= 0 else GameTypes.OWNER_WORLD


func cloud_at(pos: Vector3) -> int:
	var i := index_at(pos)
	return cloud[i] if i >= 0 else CLOUD_NONE


## Cell indices whose centers lie within radius of the point (always includes the containing cell).
func cells_in_circle(center: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c0 := cell_of(Vector3(center.x - radius, 0.0, center.z - radius))
	var c1 := cell_of(Vector3(center.x + radius, 0.0, center.z + radius))
	var r2 := radius * radius
	for y in range(maxi(0, c0.y), mini(height - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(width - 1, c1.x) + 1):
			var cc := cell_center(Vector2i(x, y))
			var dx := cc.x - center.x
			var dz := cc.z - center.z
			if dx * dx + dz * dz <= r2:
				out.append(y * width + x)
	var own := index_at(center)
	if own >= 0 and not out.has(own):
		out.append(own)
	return out


# --- Authoring (pre-placed world surfaces) ----------------------------------------

func paint_base_circle(center: Vector3, radius: float, mat: int) -> void:
	for i: int in cells_in_circle(center, radius):
		_set_permanent(i, mat)


func paint_base_rect(min_corner: Vector3, max_corner: Vector3, mat: int) -> void:
	var c0 := cell_of(min_corner)
	var c1 := cell_of(max_corner)
	for y in range(maxi(0, c0.y), mini(height - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(width - 1, c1.x) + 1):
			_set_permanent(y * width + x, mat)


func _set_permanent(i: int, mat: int) -> void:
	material[i] = mat
	base[i] = mat
	expiry[i] = 0
	owner[i] = GameTypes.OWNER_WORLD
	_mark(i)


# --- Reactions ------------------------------------------------------------------

## Apply an element over a circle. Returns {event_name: cell count}; one aggregated event per type is queued.
func apply_element(center: Vector3, radius: float, element: StringName, owner_id: int) -> Dictionary:
	return _apply_cells(cells_in_circle(center, radius), element, owner_id, center)


## Apply an element along a segment (paths of projectiles and lances).
func apply_element_segment(from: Vector3, to: Vector3, radius: float, element: StringName, owner_id: int) -> Dictionary:
	var seen: Dictionary = {}
	var cells := PackedInt32Array()
	var length := GameTypes.flat(to - from).length()
	var steps := maxi(1, ceili(length / (cell_size * 0.5)))
	for s in steps + 1:
		var p := from.lerp(to, float(s) / steps)
		for i: int in cells_in_circle(p, radius):
			if not seen.has(i):
				seen[i] = true
				cells.append(i)
	return _apply_cells(cells, element, owner_id, (from + to) * 0.5)


func _apply_cells(cells: PackedInt32Array, element: StringName, owner_id: int, where: Vector3) -> Dictionary:
	var elem := GameTypes.element_index(element)
	var counts: Dictionary = {}
	if elem < 0:
		return counts
	var electrified_seeds := PackedInt32Array()
	for i: int in cells:
		var ev := _react(i, elem, owner_id)
		if ev != &"":
			counts[ev] = int(counts.get(ev, 0)) + 1
			if ev == &"electrify":
				electrified_seeds.append(i)
	if not electrified_seeds.is_empty():
		var rule: Dictionary = _rules.get(WATER * 8 + elem, {})
		var extra := _flood_electrify(electrified_seeds, int(rule.get("duration", 40)), owner_id)
		counts[&"electrify"] = int(counts.get(&"electrify", 0)) + extra
	for ev: StringName in counts.keys():
		events.append({"type": ev, "position": where, "owner": owner_id, "count": counts[ev], "element": element})
	return counts


func _react(i: int, elem: int, owner_id: int) -> StringName:
	var mat := material[i]
	var rule: Dictionary = _rules.get(mat * 8 + elem, {})
	if rule.is_empty():
		return &""
	var event: StringName = rule["event"]
	var duration: int = rule["duration"]
	var add: int = rule["add"]
	flags[i] = flags[i] & ~int(rule["clear"])
	if flags[i] == 0:
		flag_expiry[i] = 0
	if add != 0:
		flags[i] = flags[i] | add
		flag_expiry[i] = update_tick + maxi(1, duration)
	var new_mat: int = rule["result"]
	if new_mat != mat:
		material[i] = new_mat
		heat[i] = 0
		if duration > 0 and add == 0:
			expiry[i] = update_tick + duration
		else:
			expiry[i] = 0
			base[i] = new_mat
		if new_mat != WATER:
			flags[i] = flags[i] & ~FLAG_ELECTRIFIED
	elif event == &"refresh" and duration > 0:
		expiry[i] = update_tick + duration
	var base_after: int = rule["base_after"]
	if base_after >= 0:
		base[i] = base_after
	owner[i] = owner_id
	if event == &"steam":
		cloud[i] = CLOUD_STEAM
		cloud_expiry[i] = update_tick + steam_updates
	_mark(i)
	return event


## Lightning spreads through connected water: electrify every water cell reachable from the seeds.
func _flood_electrify(seeds: PackedInt32Array, duration: int, owner_id: int) -> int:
	var visited: Dictionary = {}
	var queue: Array[int] = []
	for s: int in seeds:
		visited[s] = true
		queue.append(s)
	var added := 0
	var head := 0
	while head < queue.size() and visited.size() < electrify_flood_limit:
		var i: int = queue[head]
		head += 1
		var x := i % width
		var y := i / width
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var n := ny * width + nx
			if visited.has(n) or material[n] != WATER:
				continue
			visited[n] = true
			queue.append(n)
			flags[n] = flags[n] | FLAG_ELECTRIFIED
			flag_expiry[n] = update_tick + maxi(1, duration)
			owner[n] = owner_id
			_mark(n)
			added += 1
	return added


## Advance one surface tick (10 Hz): expiries, cloud fade and fire spreading into adjacent oil.
func update() -> void:
	update_tick += 1
	var spread: Dictionary = {}  # oil cell -> source owner
	for i: int in _active.keys():
		var changed := false
		if expiry[i] != 0 and update_tick >= expiry[i]:
			material[i] = base[i]
			expiry[i] = 0
			heat[i] = 0
			if material[i] != WATER:
				flags[i] = flags[i] & ~FLAG_ELECTRIFIED
			changed = true
		if flag_expiry[i] != 0 and update_tick >= flag_expiry[i]:
			flags[i] = 0
			flag_expiry[i] = 0
			changed = true
		if cloud_expiry[i] != 0 and update_tick >= cloud_expiry[i]:
			cloud[i] = CLOUD_NONE
			cloud_expiry[i] = 0
			changed = true
		if material[i] == BURNING:
			var x := i % width
			var y := i / width
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var n := ny * width + nx
				if material[n] == OIL:
					spread[n] = owner[i]
		if changed:
			_mark_dirty_only(i)
		if not _needs_update(i):
			_active.erase(i)
	for n: int in spread.keys():
		heat[n] = mini(255, heat[n] + 1)
		if heat[n] >= spread_updates:
			material[n] = BURNING
			base[n] = NONE
			expiry[n] = update_tick + burning_updates
			owner[n] = int(spread[n])
			heat[n] = 0
			_mark(n)


func _needs_update(i: int) -> bool:
	return expiry[i] != 0 or flag_expiry[i] != 0 or cloud_expiry[i] != 0 or material[i] == BURNING


func _mark(i: int) -> void:
	if _needs_update(i):
		_active[i] = true
	_mark_dirty_only(i)


func _mark_dirty_only(i: int) -> void:
	var ci := chunk_of_index(i)
	_dirty[ci] = true
	render_dirty[ci] = true


func active_count() -> int:
	return _active.size()


# --- Network encoding ---------------------------------------------------------------
# Each cell is two bytes: (material | cloud << 4, flags). A chunk is sent raw or run-length encoded,
# whichever is smaller; header byte 0 = raw, 1 = RLE of (count, b0, b1) triples.

func encode_chunk(ci: int) -> PackedByteArray:
	var raw := PackedByteArray()
	var cx := ci % chunks_x
	var cy := ci / chunks_x
	for y in range(cy * chunk_cells, mini(height, (cy + 1) * chunk_cells)):
		for x in range(cx * chunk_cells, mini(width, (cx + 1) * chunk_cells)):
			var i := y * width + x
			raw.append((material[i] & 0x0F) | ((cloud[i] & 0x0F) << 4))
			var player_made := FLAG_PLAYER_MADE if owner[i] < GameTypes.SLOT_COUNT else 0
			raw.append((flags[i] & 0x7F) | player_made)
	var rle := PackedByteArray([1])
	var k := 0
	while k < raw.size():
		var b0 := raw[k]
		var b1 := raw[k + 1]
		var count := 1
		while count < 255 and k + count * 2 + 1 < raw.size() and raw[k + count * 2] == b0 and raw[k + count * 2 + 1] == b1:
			count += 1
		rle.append(count)
		rle.append(b0)
		rle.append(b1)
		k += count * 2
	if rle.size() < raw.size() + 1:
		return rle
	var out := PackedByteArray([0])
	out.append_array(raw)
	return out


func decode_chunk(ci: int, data: PackedByteArray) -> void:
	if data.is_empty():
		return
	var raw := PackedByteArray()
	if data[0] == 1:
		var k := 1
		while k + 2 < data.size():
			var count := data[k]
			for _c in count:
				raw.append(data[k + 1])
				raw.append(data[k + 2])
			k += 3
	else:
		raw = data.slice(1)
	var cx := ci % chunks_x
	var cy := ci / chunks_x
	var j := 0
	for y in range(cy * chunk_cells, mini(height, (cy + 1) * chunk_cells)):
		for x in range(cx * chunk_cells, mini(width, (cx + 1) * chunk_cells)):
			if j + 1 >= raw.size():
				return
			var i := y * width + x
			material[i] = raw[j] & 0x0F
			cloud[i] = (raw[j] >> 4) & 0x0F
			flags[i] = raw[j + 1] & 0x7F
			owner[i] = GameTypes.SLOT_HOST if raw[j + 1] & FLAG_PLAYER_MADE != 0 else GameTypes.OWNER_WORLD
			j += 2
	render_dirty[ci] = true


## Changed chunks since the last call, each as [chunk_index, revision, bytes]. Revisions only grow.
func take_patches() -> Array:
	var out: Array = []
	var keys: Array = _dirty.keys()
	keys.sort()
	for ci: int in keys:
		chunk_revision[ci] += 1
		out.append([ci, chunk_revision[ci], encode_chunk(ci)])
	_dirty.clear()
	return out


## Apply a patch received from the host; stale revisions are ignored.
func apply_patch(ci: int, revision: int, data: PackedByteArray) -> bool:
	if ci < 0 or ci >= chunk_revision.size() or revision <= chunk_revision[ci]:
		return false
	chunk_revision[ci] = revision
	decode_chunk(ci, data)
	return true


## Every chunk, for a guest joining or recovering.
func full_snapshot() -> Array:
	var out: Array = []
	for ci in chunk_revision.size():
		out.append([ci, chunk_revision[ci], encode_chunk(ci)])
	return out


func apply_full_snapshot(chunks: Array) -> void:
	for entry: Array in chunks:
		var ci: int = entry[0]
		if ci < 0 or ci >= chunk_revision.size():
			continue
		chunk_revision[ci] = int(entry[1])
		decode_chunk(ci, entry[2] as PackedByteArray)
