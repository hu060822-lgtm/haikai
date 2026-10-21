extends SceneTree
## Screenshots of the bulky hauls: a lineup of every one (and the heavy fillers), a few in
## a room, one held in first person, and two scavengers carrying one together.
## Run (needs a display):
##   godot --path . --rendering-driver opengl3 --script res://tools/haul_shots.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://hauls"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	await _lineup(out_dir)

	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	Run.forced_monsters = ["colossus"]
	Run.forced_map = "factory"
	main.start_run({"build": Arsenal.STARTER, "boosts": []})
	for i in 30:
		await process_frame
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, -50, -100)
	var player: Player = main.player
	var head: Node3D = player.get_node("Head")

	# A few hauls standing around the spawn room.
	player.global_position = Vector3(4.0, 0.1, 19.0)
	player.rotation.y = 0.0
	head.rotation.x = -0.12
	var picks := [101, 106, 102, 110, 119]
	var spots := [Vector3(2.4, 0, 15.6), Vector3(3.6, 0, 14.6), Vector3(5.0, 0, 15.2), Vector3(6.0, 0, 16.6), Vector3(1.6, 0, 17.0)]
	var hauls: Array[LootItem] = []
	for i in picks.size():
		var data := LootTable.make(picks[i])
		var size: Vector3 = data.size
		hauls.append(main.run.host_spawn_loot(data, spots[i] + Vector3.UP * (size.y / 2.0 + 0.02), 0.4 - i * 0.35, true))
	for i in 30:
		await process_frame
	_save(out_dir, "room")

	# Holding the safe in first person.
	player.global_position = Vector3(3.6, 0.1, 16.4)
	await _frames(5)
	player.grab_bulky(hauls[0])
	for i in 40:
		await process_frame
	_save(out_dir, "hold_safe")
	player.release_bulky()
	await _frames(30)
	# A tall one, tipped forward.
	player.global_position = Vector3(3.6, 0.1, 16.4)
	player.rotation.y = 0.0
	await _frames(5)
	player.grab_bulky(hauls[1])
	for i in 40:
		await process_frame
	_save(out_dir, "hold_mannequin")
	player.release_bulky()
	await _frames(30)

	# Two scavengers carrying the generator, seen from a third camera.
	var mate := Player.new()
	mate.name = "2"
	mate.display_name = "阿明"
	mate.set_multiplayer_authority(2)
	mate.build_sync()
	main.run.players_root.add_child(mate)
	player.global_position = Vector3(4.0, 0.1, 16.0)
	player.rotation.y = -PI / 2.0
	mate.global_position = Vector3(5.6, 0.1, 15.6)
	mate.rotation.y = PI / 2.0
	hauls[0].global_position = Vector3(0.5, 0.6, 12.5)
	hauls[2].global_position = Vector3(4.8, 0.4, 15.8)
	await _frames(5)
	player.grab_bulky(hauls[2])
	await _frames(5)
	hauls[2].carry.host_grab(2)
	for i in 20:
		await process_frame
	var cam := Camera3D.new()
	main.run.add_child(cam)
	cam.global_position = Vector3(1.6, 1.9, 19.2)
	cam.look_at(Vector3(4.9, 0.8, 15.8))
	cam.fov = 60
	cam.current = true
	# The local player has no third-person body; stand a stand-in for them.
	var stand_in := Player.new()
	stand_in.name = "3"
	stand_in.display_name = "你"
	stand_in.set_multiplayer_authority(3)
	stand_in.build_sync()
	main.run.players_root.add_child(stand_in)
	stand_in.global_transform = player.global_transform
	stand_in.collision_layer = 0
	stand_in.held_bulky = hauls[2]
	var lamp := OmniLight3D.new()
	lamp.light_energy = 4.0
	lamp.omni_range = 6.0
	lamp.light_color = Color(1.0, 0.85, 0.6)
	main.run.add_child(lamp)
	lamp.global_position = Vector3(4.6, 2.3, 17.4)
	for i in 30:
		await process_frame
	_save(out_dir, "two_carry")
	cam.current = false
	player.get_node("Head").get_child(0).current = true
	await _frames(10)
	_save(out_dir, "two_carry_fp")
	quit()


## Every bulky haul and filler on a bright stage.
func _lineup(out_dir: String) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	stage.add_child(LowPoly.instance(LowPoly.chamfer_box(Vector3(40, 0.2, 20), 0.05), "concrete",
		Color(0.6, 0.6, 0.6), LowPoly.at(Vector3(0, -0.1, 0))))
	var bulky: Array = []
	var fillers: Array = []
	for item: Dictionary in LootTable.ITEMS:
		if LootTable.is_bulky(item):
			bulky.append(item)
		elif item.id >= 121:
			fillers.append(item)
	var nodes: Array[Node3D] = []
	for i in bulky.size():
		var row := i / 7
		nodes.append(_model(bulky[i], Vector3((i % 7 - 3) * 1.6, 0, -row * 2.6)))
	for i in fillers.size():
		nodes.append(_model(fillers[i], Vector3((i - 4.5) * 0.5, 0, 3.0)))
	for node in nodes:
		stage.add_child(node)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 62
	for row in 3:
		camera.position = Vector3(0, 1.9, -row * 2.6 + 5.0)
		camera.rotation_degrees = Vector3(-14, 0, 0)
		for i in 8:
			await process_frame
		_save(out_dir, "lineup_%d" % row)
	camera.position = Vector3(0, 1.3, 5.6)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	camera.fov = 45
	for i in 4:
		await process_frame
	_save(out_dir, "fillers")
	stage.queue_free()
	await process_frame


func _model(data: Dictionary, at: Vector3) -> Node3D:
	var holder := Node3D.new()
	var size: Vector3 = data.size
	holder.position = at + Vector3.UP * size.y / 2.0
	holder.rotation.y = -0.45
	var body := MeshInstance3D.new()
	body.mesh = LootShapes.mesh_for(data)
	body.material_override = PS1Materials.get_material(data.texture, data.color, true)
	holder.add_child(body)
	var trim := LootShapes.trim_mesh_for(data)
	if trim != null:
		var trim_node := MeshInstance3D.new()
		trim_node.mesh = trim
		trim_node.material_override = LootShapes.trim_material(data)
		holder.add_child(trim_node)
	return holder


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
