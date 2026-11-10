extends Node3D
## Authored characters under plain light, every clip row, or the real Drowned Hall cost gate.
## Run this scene with --character=vanguard --sheet=turnaround|moves|cost --out=<png> [--size=<W>x<H>].

const GOLD: Color = Color(0.95, 0.72, 0.25)
const VIOLET: Color = Color(0.62, 0.42, 1.0)
const COLUMNS: int = 8
const COLUMN_SPACING: float = 1.65
const MOVE_COLUMN_SPACING: float = 3.1
const MOVE_ROW_SPACING: float = 2.9
const SETTLE_FRAMES: int = 45
const SAMPLE_FRAMES: int = 150
const COST_LIMIT_MS: float = 1.5
const WATCHDOG_SECONDS: float = 120.0
const TURN_ANGLES: Array[float] = [0.0, 40.0, 180.0, 215.0, 180.0, 150.0, 20.0, 200.0]
const TURN_ROLES: Array[StringName] = [&"idle", &"idle", &"idle", &"idle", &"jog", &"action_default", &"block", &"dodge"]

var _character: StringName
var _roster_row: Dictionary = {}
var _clips: ClipSet
var _light_rows: Array[ClipSet.ClipRow] = []
var _cost_rigs: Array[CharacterRig] = []
var _cost_crowd: Node3D
var _cost_clock: float = 0.0
var _animate_cost: bool = false
var _finished: bool = false
var _output: String


func _ready() -> void:
	set_process(false)
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_watchdog)
	_run()


func _run() -> void:
	await get_tree().process_frame
	CharacterKit.enabled = true
	_character = StringName(str(Settings.arg("character", "vanguard")))
	var sheet: String = str(Settings.arg("sheet", "turnaround"))
	_output = str(Settings.arg("out", "res://tools/out/characters_pr1/%s.png" % sheet))
	if Settings.is_headless():
		_fail("a review sheet needs a window and a rendering device")
		return
	if Settings.has_arg("size") and not await _apply_size(str(Settings.arg("size"))):
		return
	if not _resolve_character():
		return
	match sheet:
		"turnaround":
			if not _turnaround():
				return
		"moves":
			if not _moves():
				return
		"cost":
			await _cost()
			return
		_:
			_fail("unknown sheet '%s'" % sheet)
			return
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if not await _save_picture():
		return
	print("[characters] sheet=%s character=%s out=%s" % [sheet, _character, _output])
	_finished = true
	get_tree().quit()


func _resolve_character() -> bool:
	for row: Dictionary in GameData.character_roster.values():
		if row["character"] == _character:
			_roster_row = row
			break
	if _roster_row.is_empty():
		_fail("no roster row for '%s'" % _character)
		return false
	_clips = ClipSet.for_set(_roster_row["clip_set"])
	if _clips == null:
		_fail("unknown clip set for '%s'" % _character)
		return false
	var definition: ClassDefinition = GameData.class_def(_roster_row["for_id"])
	if definition != null:
		for ability_id: StringName in definition.light_combo:
			_light_rows.append(_clips.ability_row(GameData.ability(ability_id)))
	if _light_rows.is_empty():
		_light_rows.append(_clips.ability_row(null))
	return true


func _new_rig(parent: Node3D, position: Vector3, yaw_degrees: float, index: int) -> CharacterRig:
	var color: Color = GOLD if index % 2 == 0 else VIOLET
	var rig: CharacterRig
	if _roster_row["for_kind"] == &"class":
		rig = CharacterKit.hero_rig(_roster_row["for_id"], color)
	else:
		var packed: PackedScene = load(CharacterKit.scene_path(_character)) as PackedScene
		rig = CharacterRig.create(packed, _roster_row["clip_set"])
		if rig != null:
			rig.set_accent(color)
	if rig == null:
		_fail("could not create rig '%s'" % _character)
		return null
	parent.add_child(rig)
	rig.position = position
	rig.rotation_degrees.y = yaw_degrees
	return rig


func _freeze(rig: CharacterRig, row: ClipSet.ClipRow) -> void:
	var pose: AnimPose = AnimPose.new()
	pose.locomotion = false
	pose.base_clip = row.clip
	pose.base_time_s = lerpf(row.start_s, row.end_s, 0.3) if row.loop else row.contact_s
	# The public animator eases its layer weights; settle them before holding zero delta.
	for step: int in 40:
		rig.animator.apply(pose, 0.1)
	rig.animator.apply(pose, 0.0)


func _turnaround() -> bool:
	_studio()
	for index: int in TURN_ANGLES.size():
		var role: StringName = TURN_ROLES[index]
		var row: ClipSet.ClipRow = _light_rows[0] if index == 5 else _clips.base_row(role)
		var position: Vector3 = Vector3((index - (COLUMNS - 1) * 0.5) * COLUMN_SPACING, 0.0, 0.0)
		var rig: CharacterRig = _new_rig(self, position, TURN_ANGLES[index], index)
		if rig == null:
			return false
		_freeze(rig, row)
		var role_label: String = String(row.role).replace("ability:vanguard_", "").replace("ability:riftweaver_", "")
		_label("%s\n%d deg" % [role_label, roundi(TURN_ANGLES[index])], position + Vector3(0.0, 2.25, 0.0))
	_fit_camera(AABB(Vector3(-7.2, -0.1, -1.1), Vector3(14.4, 3.2, 2.2)), Vector3(0.0, 0.9, 14.0))
	return true


func _moves() -> bool:
	_studio(false)
	var rows: Array[ClipSet.ClipRow] = _clips.all_rows()
	var row_count: int = ceili(rows.size() / float(COLUMNS))
	for index: int in rows.size():
		var column: int = index % COLUMNS
		var row_index: int = index / COLUMNS
		# A flat grid avoids perspective placing a rear row's labels over the row in front.
		var position: Vector3 = Vector3((column - (COLUMNS - 1) * 0.5) * MOVE_COLUMN_SPACING, -row_index * MOVE_ROW_SPACING, 0.0)
		var rig: CharacterRig = _new_rig(self, position, 0.0, index)
		if rig == null:
			return false
		_freeze(rig, rows[index])
		_label(String(rows[index].role).replace(":", ":\n"), position + Vector3(0.0, 2.25, 0.0), 450.0)
	var depth: float = maxi(row_count - 1, 0) * MOVE_ROW_SPACING
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var center_y: float = (2.7 - depth) * 0.5
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(depth + 3.2, COLUMNS * MOVE_COLUMN_SPACING / aspect) * 1.08
	camera.near = 0.05
	camera.far = 250.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, center_y, 18.0), Vector3(0.0, center_y, 0.0), Vector3.UP)
	camera.current = true
	return true


func _studio(show_floor: bool = true) -> void:
	Engine.max_fps = 60
	var viewport: Viewport = get_viewport()
	viewport.scaling_3d_scale = 1.0
	viewport.use_taa = false
	viewport.msaa_3d = Viewport.MSAA_4X
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.14, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.55, 0.65)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	# The cameras look along -Z: the key lights the faces they see, the rim comes from behind.
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	key.light_energy = 2.4
	key.light_color = Color(1.0, 0.93, 0.82)
	key.shadow_enabled = true
	add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, -160.0, 0.0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.6, 0.75, 1.0)
	add_child(rim)
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(50.0, 50.0)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.22, 0.22, 0.24)
	floor_material.roughness = 0.85
	var floor_instance: MeshInstance3D = MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_material
	floor_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	floor_instance.visible = show_floor
	add_child(floor_instance)


func _label(text: String, position: Vector3, width: float = 250.0) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.005
	label.outline_size = 6
	label.width = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position
	label.no_depth_test = true
	label.modulate = Color(0.92, 0.93, 0.96)
	add_child(label)


func _fit_camera(bounds: AABB, direction: Vector3) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.05
	camera.far = 250.0
	add_child(camera)
	var center: Vector3 = bounds.get_center()
	var axis: Vector3 = direction.normalized()
	camera.look_at_from_position(center + axis, center, Vector3.UP)
	var view_basis: Basis = camera.global_basis.transposed()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var tan_vertical: float = tan(deg_to_rad(camera.fov) * 0.5)
	var distance: float = 1.0
	for endpoint: int in 8:
		var point: Vector3 = view_basis * (bounds.get_endpoint(endpoint) - center)
		distance = maxf(distance, point.z + absf(point.y) / tan_vertical)
		distance = maxf(distance, point.z + absf(point.x) / (tan_vertical * aspect))
	camera.look_at_from_position(center + axis * distance * 1.06, center, Vector3.UP)
	camera.current = true


func _cost() -> void:
	var world: Node3D = Node3D.new()
	world.name = "World"
	add_child(world)
	ArenaBuilder.build(world, false)
	var surface: SurfaceLayer = SurfaceLayer.new()
	add_child(surface)
	surface.setup(ArenaLayout.SIZE, ArenaLayout.ORIGIN)
	ArenaLayout.paint_surfaces(surface.grid)
	surface.grid.take_patches()
	# The benchmark is always High, regardless of a saved profile or --graphics override.
	var prior_graphics: Variant = Settings.args.get("graphics")
	Settings.args["graphics"] = "high"
	RenderPipeline.setup(self, world, get_viewport(), &"sunken_crypt")
	if prior_graphics == null:
		Settings.args.erase("graphics")
	else:
		Settings.args["graphics"] = prior_graphics
	var environment_node: WorldEnvironment = RenderPipeline.find_environment(world)
	var high: Dictionary = RenderQuality.preset(&"high")
	RenderQuality.apply(get_viewport(), environment_node.environment if environment_node != null else null,
		world, high, float(high[&"render_scale"]))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_cost_crowd = Node3D.new()
	_cost_crowd.name = "CharacterCrowd"
	add_child(_cost_crowd)
	for index: int in 12:
		var position: Vector3 = Vector3((index % 6 - 2.5) * 1.6, 0.0, 4.5 - (index / 6) * 3.0)
		var rig: CharacterRig = _new_rig(_cost_crowd, position, 180.0 if index < 2 else 0.0, index)
		if rig == null:
			return
		_cost_rigs.append(rig)
	var camera: Camera3D = Camera3D.new()
	camera.fov = GameData.rule(&"camera_fov_deg")
	camera.near = 0.05
	camera.far = 250.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 3.5, 12.0), Vector3(0.0, 1.0, 2.8), Vector3.UP)
	camera.current = true
	_cost_crowd.visible = false
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var empty_ms: float = await _average_frame_ms()
	_cost_crowd.visible = true
	_animate_cost = true
	set_process(true)
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var full_ms: float = await _average_frame_ms()
	var added_ms: float = full_ms - empty_ms
	if not await _save_picture():
		return
	var size: Vector2i = _render_size()
	print("[characters] sheet=cost empty_ms=%.3f full_ms=%.3f added_ms=%.3f size=%dx%d" % [empty_ms, full_ms, added_ms, size.x, size.y])
	_finished = true
	get_tree().quit(1 if added_ms > COST_LIMIT_MS else 0)


func _process(delta: float) -> void:
	if not _animate_cost:
		return
	_cost_clock += delta
	var jog: ClipSet.ClipRow = _clips.base_row(&"jog")
	for index: int in _cost_rigs.size():
		var pose: AnimPose = AnimPose.new()
		if index < 2:
			pose.speed_mps = jog.speed_mps
		else:
			var total_s: float = 0.0
			for row: ClipSet.ClipRow in _light_rows:
				total_s += maxf(0.001, row.end_s - row.start_s)
			var elapsed: float = fposmod(_cost_clock + index * 0.17, total_s)
			for row: ClipSet.ClipRow in _light_rows:
				var length_s: float = maxf(0.001, row.end_s - row.start_s)
				if elapsed < length_s:
					pose.action_clip = row.clip
					pose.action_time_s = row.start_s + elapsed
					break
				elapsed -= length_s
		_cost_rigs[index].animator.apply(pose, delta)


func _average_frame_ms() -> float:
	var started_usec: int = Time.get_ticks_usec()
	for frame: int in SAMPLE_FRAMES:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - started_usec) / (1000.0 * SAMPLE_FRAMES)


func _save_picture() -> bool:
	await RenderingServer.frame_post_draw
	var absolute: String = ProjectSettings.globalize_path(_output)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		_fail("could not create output directory (%s)" % error_string(error))
		return false
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("could not read the review viewport")
		return false
	error = image.save_png(absolute)
	if error != OK:
		_fail("could not save '%s' (%s)" % [_output, error_string(error)])
		return false
	return true


## --size=<W>x<H>: a borderless window of exactly that many pixels with its top-left at 0,0. Returns false
## (and quits with code 2) when the size lies outside the area all screens cover from 0,0, or unless the
## viewport, read back, reaches the size: reported screen sizes are unreliable under mixed DPI scaling,
## the readback is not.
func _apply_size(text: String) -> bool:
	var parts: PackedStringArray = text.to_lower().split("x")
	var wanted: Vector2i = Vector2i(-1, -1)
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		wanted = Vector2i(parts[0].to_int(), parts[1].to_int())
	var cover: Vector2i = Vector2i.ZERO
	for index: int in DisplayServer.get_screen_count():
		cover = cover.max(DisplayServer.screen_get_position(index) + DisplayServer.screen_get_size(index))
	if wanted.x <= 0 or wanted.y <= 0 or wanted.x > cover.x or wanted.y > cover.y:
		_fail("size %s not available (screens cover %dx%d)" % [text, cover.x, cover.y])
		return false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i.ZERO)
	DisplayServer.window_set_size(wanted)
	for frame: int in 30:
		await get_tree().process_frame
		# The readback stalls the GPU, so it runs only once the window agrees.
		if DisplayServer.window_get_size() == wanted and _render_size() == wanted:
			return true
	var got: Vector2i = _render_size()
	_fail("size %s not available (got %dx%d)" % [text, got.x, got.y])
	return false


## The pixel size the scene is rendered and saved at: read back from the viewport, because under the
## project's canvas_items stretch the texture's reported size is not the render size.
func _render_size() -> Vector2i:
	var image: Image = get_viewport().get_texture().get_image()
	return image.get_size() if image != null else Vector2i.ZERO


func _watchdog() -> void:
	if not _finished:
		_fail("watchdog expired after 120 seconds", 3)


func _fail(message: String, code: int = 2) -> void:
	if _finished:
		return
	_finished = true
	printerr("[characters] " + message)
	get_tree().quit(code)
