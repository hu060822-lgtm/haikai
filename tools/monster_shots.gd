extends SceneTree
## Renders each of the newer monsters in front of the camera in the boiler factory.
## Run (needs a display): godot --path . --script res://tools/monster_shots.gd -- <out_dir>

var SHOTS := [
	{"kind": "watcher", "script": Watcher, "pos": Vector3(4.0, 0.1, 8.0), "pitch": 0.5},
	{"kind": "greeter", "script": Greeter, "pos": Vector3(4.0, 0.1, 15.8), "pitch": 0.0},
	{"kind": "collector", "script": Collector, "pos": Vector3(3.6, 0.1, 15.6), "pitch": -0.1},
	{"kind": "rats", "script": RatSwarm, "pos": Vector3(4.0, 0.1, 17.6), "pitch": -0.75},
	{"kind": "centipede", "script": Centipede, "pos": Vector3(3.0, 0.1, 15.0), "pitch": -0.2},
	{"kind": "mother", "script": LullabyMother, "pos": Vector3(4.0, 0.1, 11.0), "pitch": 0.35},
	{"kind": "fog_walker", "script": FogWalker, "pos": Vector3(4.0, 0.1, 15.5), "pitch": 0.0},
	{"kind": "tuner", "script": Tuner, "pos": Vector3(4.0, 0.1, 15.5), "pitch": 0.05},
	{"kind": "child", "script": HideChild, "pos": Vector3(4.0, 0.1, 16.5), "pitch": -0.3},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Run.forced_map = "factory"
	Run.forced_monsters = ["watcher", "greeter", "collector", "rats", "centipede", "mother", "fog_walker", "tuner", "child"]
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	main.start_run({})
	for i in 30:
		await process_frame
	var monsters := {}
	for node in main.run.monsters_root.get_children():
		if node is Node3D:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.global_position = Vector3(0, -50, -100)
			for shot in SHOTS:
				if node.get_script() == shot.script and not monsters.has(shot.kind):
					monsters[shot.kind] = node
	var player: Player = main.player
	for shot in SHOTS:
		var monster: Node3D = monsters.get(shot.kind)
		if monster == null:
			continue
		player.global_position = Vector3(4.0, 0.1, 19.0)
		player.rotation.y = 0.0
		player.get_node("Head").rotation.x = shot.pitch
		monster.global_position = shot.pos
		monster.rotation.y = 0.0 if shot.kind == "rats" else PI * 0.92
		if monster is Collector:
			monster.cart_load = 4
		if monster is FogWalker:
			monster.revealed = true
		if monster is HideChild:
			monster.state = HideChild.State.HIDE
		if monster is Centipede:
			# Lay the body out in a line receding from the camera.
			var trail := PackedVector3Array()
			for i in Centipede.SEGMENTS * 2:
				trail.append(shot.pos + Vector3(-2.0 + 0.55 * i, 0, -0.35 * i + 0.4 * sin(i * 0.6)))
			monster.trail = trail
			monster.process_mode = Node.PROCESS_MODE_INHERIT
			monster.set_physics_process(false)
			monster._pose_body()
		var lamp: OmniLight3D = null
		if monster is Watcher or monster is LullabyMother or monster is Centipede or monster is FogWalker or monster is Tuner:
			# Light it from below so it reads in a still frame.
			lamp = OmniLight3D.new()
			lamp.light_energy = 2.5
			lamp.omni_range = 14.0
			main.run.add_child(lamp)
			lamp.global_position = shot.pos + Vector3(0, 4, 3)
		for i in 30:
			await process_frame
		_save(out_dir, shot.kind)
		if monster is Greeter:
			monster.angry = true
			for i in 5:
				await process_frame
			_save(out_dir, "greeter_angry")
		if lamp != null:
			lamp.queue_free()
		monster.global_position = Vector3(0, -50, -100)
	quit()


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
