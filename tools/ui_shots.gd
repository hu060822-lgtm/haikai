extends SceneTree
## Renders every menu and the in-game HUD (factory + research station) to PNGs.
## Run (needs a display):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/ui_shots.gd -- <out_dir> [prefix]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var prefix: String = args[1] if args.size() > 1 else "ui_"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	GameState.money = 2400
	GameState.extractions = 3
	GameState.deaths = 5
	GameState.best_haul = 812

	# The first screen you see, then the stash.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(40)
	_save(out_dir, prefix + "title")
	if main._menu is TitleScreen:
		main._menu._glitch_left = 0.3
		main._menu._next_glitch = 5.0
		await _frames(2)
		_save(out_dir, prefix + "title_glitch")
	main.show_loadout()
	await _frames(15)
	_save(out_dir, prefix + "loadout")

	main.session.host(24561)
	main.session.roster[2] = {"name": "阿明", "role": "scavenger", "squad": 1}
	main.session.roster[3] = {"name": "小葵", "role": "guardian"}
	main.session.roster_changed.emit()
	main.show_lobby()
	await _frames(15)
	_save(out_dir, prefix + "lobby")
	main.session.leave()
	main.queue_free()
	await _frames(5)

	for map in ["factory", "station"]:
		main = load("res://scenes/main.tscn").instantiate()
		main.show_menus = false
		root.add_child(main)
		Run.forced_monsters = ["colossus"]
		Run.forced_map = map
		main.start_run({"weapon": "nail_gun", "boosts": ["adrenaline", "night_goggles"]})
		await _frames(40)
		main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
		main.colossus.global_position = Vector3(0, -50, -100)
		var player: Player = main.player
		player.process_mode = Node.PROCESS_MODE_DISABLED
		var fake: Array = [LootTable.ITEMS[0], LootTable.ITEMS[4]]
		for item in LootTable.ITEMS:
			if item.has("use"):
				fake.append(item)
				break
		player.inventory_changed.emit(fake, 6.4, 385)
		player.stamina_changed.emit(0.62)
		player.health_changed.emit(0.78)
		player.prompt_changed.emit(LootTable.prompt(LootTable.ITEMS[12]) if map == "factory" else "[E] 打開白色的門")
		main.hud.set_voice("speaking")
		if map == "station":
			main.run.time_left = 95.0
			main.hud.show_message("外面風雪好大，體溫一直在掉…", 5.0)
			main.hud.set_extract_progress(0.45)
		await _frames(30)
		_save(out_dir, prefix + "hud_" + map)
		main.queue_free()
		await _frames(5)

	for survived in [true, false]:
		var result := ResultScreen.new()
		result.survived = survived
		result.cause = "被鍋爐巨像抓住了"
		result.items = [LootTable.ITEMS[0], LootTable.ITEMS[4], LootTable.ITEMS[4], LootTable.ITEMS[29]]
		result.payout = LootTable.payout(result.items)
		result.lost_gear = ["crowbar", "adrenaline"]
		result.summary = {"extracted": 420, "threshold": 250, "guardian_won": false, "guardian": ""}
		root.add_child(result)
		await _frames(20)
		_save(out_dir, prefix + ("result" if survived else "result_dead"))
		result.queue_free()
		await _frames(3)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
