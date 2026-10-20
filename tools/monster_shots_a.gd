extends SceneTree
## Renders monster worker A's five monsters in front of the camera in the boiler factory.
## Run (needs a display): godot --path . --script res://tools/monster_shots_a.gd -- <out_dir> [kind...]
## Kinds: screamer, spitter, splitter, crawler, dropper, burrower.

const KINDS := ["screamer", "spitter", "splitter", "dropper", "burrower"]
var SHOTS := [
	{"kind": "screamer", "script": Screamer, "pos": Vector3(4.0, 0.1, 16.6), "pitch": -0.3},
	{"kind": "spitter", "script": Spitter, "pos": Vector3(4.0, 0.1, 14.8), "pitch": 0.1},
	{"kind": "splitter", "script": Splitter, "pos": Vector3(4.0, 0.1, 15.6), "pitch": -0.05},
	{"kind": "dropper", "script": CeilingDropper, "pos": Vector3(4.0, 0.1, 15.0), "pitch": 0.75},
	{"kind": "burrower", "script": Burrower, "pos": Vector3(4.0, 0.1, 11.5), "pitch": -0.05},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var only: Array = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Run.director_enabled = false
	Run.forced_map = "factory"
	Run.forced_monsters = KINDS
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	main.start_run({})
	for i in 30:
		await process_frame
	var found := {}
	for node in main.run.monsters_root.get_children():
		if node is Node3D:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.global_position = Vector3(0, -50, -100)
			for shot in SHOTS:
				if node.get_script() == shot.script and not found.has(shot.kind):
					found[shot.kind] = node
	var player: Player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for shot in SHOTS:
		if not only.is_empty() and not only.has(shot.kind):
			continue
		var monster: Node3D = found.get(shot.kind)
		if monster == null:
			print("missing ", shot.kind)
			continue
		player.global_position = Vector3(4.0, 0.1, 19.0)
		player.rotation.y = 0.0
		player.get_node("Head").rotation.x = shot.pitch
		monster.global_position = shot.pos
		monster.rotation.y = PI * 0.92
		var lamp := OmniLight3D.new()
		lamp.light_energy = 2.0
		lamp.omni_range = 12.0
		main.run.add_child(lamp)
		lamp.global_position = shot.pos + Vector3(0.5, 3.0, 2.5)
		match shot.kind:
			"screamer":
				await _pose(monster, func() -> void: monster.state = Screamer.State.WINDUP)
				_save(out_dir, "screamer_breath")
				monster.state = Screamer.State.WANDER
				await _pose(monster)
			"spitter":
				await _pose(monster)
				_save(out_dir, "spitter")
				await _pose(monster, func() -> void: monster.state = Spitter.State.WINDUP)
				_save(out_dir, "spitter_windup")
				# Side view.
				monster.rotation.y = PI * 0.5
				await _pose(monster)
				_save(out_dir, "spitter_side")
				monster.state = Spitter.State.WANDER
				_hide(monster)
				lamp.queue_free()
				continue
			"splitter":
				await _pose(monster)
				_save(out_dir, "splitter")
				monster.torn = 0.85
				await _pose(monster)
				_save(out_dir, "splitter_torn")
				# Its crawlers.
				_hide(monster)
				var crawler := SplitterCrawler.new()
				crawler.set_meta("kind", "crawler")
				main.run.add_child(crawler)
				crawler.process_mode = Node.PROCESS_MODE_DISABLED
				for i in 3:
					var extra: Node3D = crawler if i == 0 else SplitterCrawler.new()
					if i > 0:
						main.run.add_child(extra)
						extra.process_mode = Node.PROCESS_MODE_DISABLED
					extra.global_position = Vector3(3.2 + i * 0.8, 0.1, 17.0 - i * 0.4)
					extra.rotation.y = PI * (0.8 + i * 0.15)
				player.get_node("Head").rotation.x = -0.5
				for i in 20:
					await process_frame
				_save(out_dir, "crawlers")
				for node in main.run.get_children():
					if node is SplitterCrawler:
						node.queue_free()
				lamp.queue_free()
				continue
			"dropper":
				# Up on the ceiling over the player's head, looking up at it.
				monster.global_position = monster.ceiling_above(Vector3(4.0, 0.1, 16.0))
				monster.state = CeilingDropper.State.HANG
				lamp.global_position = Vector3(4.0, 1.0, 17.5)
				await _pose(monster)
				_save(out_dir, "dropper_ceiling")
				monster.state = CeilingDropper.State.GRAB
				monster.global_position = Vector3(4.0, 2.0, 15.5)
				player.get_node("Head").rotation.x = 0.1
				await _pose(monster)
				_save(out_dir, "dropper_grab")
				monster.state = CeilingDropper.State.HANG
				_hide(monster)
				lamp.queue_free()
				continue
			"burrower":
				lamp.light_energy = 4.0
				lamp.omni_range = 16.0
				lamp.global_position = Vector3(4.0, 3.0, 16.0)
				monster.state = Burrower.State.SURFACE
				await _pose(monster)
				_save(out_dir, "burrower_reared")
				monster.state = Burrower.State.TUNNEL
				monster._rear = 0.0
				monster.state = Burrower.State.DIVE
				monster.state = Burrower.State.SLAM
				await _pose(monster)
				monster.rotation.y = PI * 0.6
				await _pose(monster)
				_save(out_dir, "burrower")
				monster.state = Burrower.State.TUNNEL
				monster.global_position = Vector3(4.0, 0.1, 14.5)
				player.get_node("Head").rotation.x = -0.35
				await _pose(monster)
				_save(out_dir, "burrower_tunnel")
				_hide(monster)
				lamp.queue_free()
				continue
		_save(out_dir, shot.kind)
		lamp.queue_free()
		_hide(monster)
	quit()


## Let the monster's own animation settle into a pose (its AI stays off).
func _pose(monster: Node3D, setup := Callable()) -> void:
	if setup.is_valid():
		setup.call()
	for i in 30:
		if monster.has_method("_animate"):
			monster._animate(1.0 / 30.0)
		await process_frame


func _hide(monster: Node3D) -> void:
	monster.global_position = Vector3(0, -50, -100)


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
