extends SceneTree
## Renders the in-run HUD with the minimap (small and large) on every map, plus the
## rasterised floor plans themselves and the dream corridor's static.
## Run (needs a display):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/minimap_shots.gd -- <out_dir> [map ...]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://minimap"
	var maps: Array = Array(args.slice(1)) if args.size() > 1 else MapRoster.MAPS
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Awakening.frozen = true
	for map_id in maps:
		var main = load("res://scenes/main.tscn").instantiate()
		main.show_menus = false
		root.add_child(main)
		Run.forced_monsters = ["colossus"]
		Run.forced_map = map_id
		main.start_run({"build": {"frame": "nail_gun", "parts": {"sight": "red_dot"}}, "boosts": ["adrenaline"]})
		await _frames(40)
		main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
		main.colossus.global_position = Vector3(0, -50, -100)
		var player: Player = main.player
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.rotation.y = deg_to_rad(-35.0)
		# A squadmate a few metres off, and a rival who must NOT show.
		var mate := Player.new()
		mate.name = "98"
		mate.display_name = "阿明"
		mate.squad = player.squad
		var rival := Player.new()
		rival.name = "99"
		rival.squad = player.squad + 1
		main.run.players_root.add_child(mate)
		main.run.players_root.add_child(rival)
		await _frames(2)
		mate.process_mode = Node.PROCESS_MODE_DISABLED
		rival.process_mode = Node.PROCESS_MODE_DISABLED
		mate.global_position = player.global_position + Vector3(4.0, 0.0, -3.0)
		rival.global_position = player.global_position + Vector3(-3.0, 0.0, -4.0)
		player._camera.current = true
		var map: Minimap = main.hud.minimap
		var started := Time.get_ticks_msec()
		map.rasterise_now()
		print("%s plan %dx%d in %d ms" % [map_id, map._cells.x, map._cells.y, Time.get_ticks_msec() - started])
		map._images[0].save_png(out_dir.path_join("plan_%s_ground.png" % map_id))
		map._images[1].save_png(out_dir.path_join("plan_%s_upper.png" % map_id))
		await _frames(20)
		_save(out_dir, "minimap_%s_small" % map_id)
		# Large, with the exit open (a green pad or a rim chevron, and a diamond on the strip).
		main.level.objective_on = true
		map.set_mode(Minimap.Mode.LARGE)
		await _frames(10)
		_save(out_dir, "minimap_%s_large" % map_id)
		if map_id == "afternoon":
			player.global_position = Vector3(13.0, 0.1, 0.0)
			player.rotation.y = -PI / 2.0
			await _frames(10)
			_save(out_dir, "minimap_afternoon_corridor_static")
		map.set_mode(Minimap.Mode.HIDDEN)
		await _frames(5)
		_save(out_dir, "minimap_%s_hidden" % map_id)
		main.queue_free()
		await _frames(5)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
