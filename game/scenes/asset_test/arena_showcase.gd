extends Node3D
## Texture review scene: the Drowned Hall built exactly as in play (ArenaBuilder + SurfaceLayer), with
## every elemental surface painted, both heroes and each enemy kind posed, under fixed cameras that do
## not depend on the gameplay camera. Keys 1-7 switch camera, Esc returns to the menu.
## Command line (after --): --showcase-camera=1..7, plus the usual --screenshot / --quit-after.

const CAMERAS: Array = [
	# [position, look-at target]
	[Vector3(0.0, 17.0, 23.0), Vector3(0.0, 0.0, 3.0)],    # 1: the whole hall
	[Vector3(0.0, 2.6, 13.4), Vector3(0.0, 1.0, 8.0)],     # 2: heroes and enemies at the Waystone
	[Vector3(5.0, 3.2, 12.0), Vector3(6.0, 0.4, 6.0)],     # 3: water, ice and lightning by the east pillar
	[Vector3(1.5, 3.6, -5.5), Vector3(1.5, 0.3, -11.0)],   # 4: oil, fire and holy ground by the north wall
	[Vector3(-9.5, 1.7, 3.0), Vector3(-15.5, 1.4, 1.5)],   # 5: masonry, ruin and pillar close up
	[Vector3(-0.6, 2.3, 13.0), Vector3(0.0, 3.0, -10.0)], # 6: shoulder-height architectural view
	[Vector3(-13.3, 1.9, 10.5), Vector3(-17.0, 2.8, -3.0)], # 7: fire, wall relief and wet stone
]

var surface: SurfaceLayer
var _cameras: Array[Camera3D] = []


func _ready() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	ArenaBuilder.build(world, headless)
	surface = SurfaceLayer.new()
	surface.name = "Surfaces"
	add_child(surface)
	surface.setup(ArenaLayout.SIZE, ArenaLayout.ORIGIN)
	ArenaLayout.paint_surfaces(surface.grid)
	_paint_reactions()
	_pose_cast()
	for i in CAMERAS.size():
		var cam := Camera3D.new()
		cam.name = "Camera%d" % (i + 1)
		cam.fov = 50.0
		add_child(cam)
		cam.look_at_from_position(CAMERAS[i][0], CAMERAS[i][1])
		_cameras.append(cam)
	_use_camera(clampi(int(str(Settings.arg("showcase-camera", "1"))), 1, CAMERAS.size()) - 1)
	if str(Settings.arg("showcase-ssr", "1")) == "0":
		for node: Node in world.get_children():
			if node is WorldEnvironment:
				(node as WorldEnvironment).environment.ssr_enabled = false


## The surface reactions a fight leaves behind, frozen in place (nothing calls grid.update here).
func _paint_reactions() -> void:
	var g := surface.grid
	g.apply_element(Vector3(4.2, 0, 6.2), 1.6, &"cold", 1)            # ice on the east pool
	g.apply_element(Vector3(8.2, 0, 5.2), 0.8, &"lightning", 0)       # the rest of that pool is electrified
	g.apply_element(Vector3(3.2, 0, -11.4), 1.4, &"fire", 0)          # burning oil by the north wall
	g.paint_base_circle(Vector3(-1.2, 0, -8.2), 1.5, SurfaceGrid.SANCTIFIED)
	g.paint_base_circle(Vector3(-4.5, 0, 6.5), 1.2, SurfaceGrid.WATER)
	g.apply_element(Vector3(-4.5, 0, 6.5), 0.6, &"holy", 0)           # a blessed puddle


func _pose_cast() -> void:
	var cast := Node3D.new()
	cast.name = "Cast"
	add_child(cast)
	var vanguard := ProcMesh.build_hero(&"vanguard", ProcMesh.GOLD)
	vanguard.position = Vector3(-1.4, 0, 11.0)
	vanguard.rotation_degrees.y = 160.0
	cast.add_child(vanguard)
	var riftweaver := ProcMesh.build_hero(&"riftweaver", ProcMesh.VIOLET)
	riftweaver.position = Vector3(1.4, 0, 11.0)
	riftweaver.rotation_degrees.y = 200.0
	cast.add_child(riftweaver)
	var x := -4.5
	for id: StringName in [&"drowned_thrall", &"crypt_archer", &"drowned_knight", &"bellkeeper", &"training_dummy"]:
		var def := GameData.enemy(id)
		if def == null:
			continue
		var enemy := ProcMesh.build_enemy(def)
		enemy.position = Vector3(x, 0, 7.6)
		enemy.rotation_degrees.y = 10.0 * x
		cast.add_child(enemy)
		x += 2.25
	for i in ArenaLayout.OIL_BARRELS.size() + ArenaLayout.WATER_BARRELS.size():
		var oil := i < ArenaLayout.OIL_BARRELS.size()
		var def := EnemyDefinition.new()
		def.id = &"oil_barrel" if oil else &"water_barrel"
		def.radius = 0.4
		def.height = 1.8
		var barrel := ProcMesh.build_enemy(def)
		barrel.position = ArenaLayout.OIL_BARRELS[i] if oil else ArenaLayout.WATER_BARRELS[i - ArenaLayout.OIL_BARRELS.size()]
		cast.add_child(barrel)


func _use_camera(index: int) -> void:
	for i in _cameras.size():
		_cameras[i].current = i == index


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + _cameras.size():
		_use_camera(key.keycode - KEY_1)
	elif key.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://game/scenes/boot/boot.tscn")
