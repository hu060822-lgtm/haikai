extends SceneTree
## Renders the menus and a few camera positions to PNGs for quick visual checks.
## Run (needs a display): godot --path . --script res://tools/screenshot.gd -- <out_dir>

const SHOTS := [
	{"name": "spawn", "pos": Vector3(4.0, 0.1, 19.0), "yaw": 0.0, "pitch": 0.0},
	{"name": "colossus", "pos": Vector3(0.0, 0.1, 4.0), "yaw": 0.0, "pitch": 0.15, "monster": Vector3(0.0, 0.1, -4.5)},
	{"name": "boiler", "pos": Vector3(2.0, 0.1, -4.5), "yaw": 0.2, "pitch": 0.05},
	{"name": "catwalk", "pos": Vector3(13.5, 6.05, 8.0), "yaw": 0.3, "pitch": -0.2},
	{"name": "pipe_walk", "pos": Vector3(11.0, 6.05, -4.0), "yaw": PI / 2.0, "pitch": -0.25},
	{"name": "tool_room", "pos": Vector3(-8.0, 0.1, 16.5), "yaw": PI / 2.0, "pitch": -0.05},
	{"name": "extraction", "pos": Vector3(8.0, 0.1, -11.0), "yaw": 0.0, "pitch": 0.0},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	_save(out_dir, "loadout")

	main.show_menus = false
	main.start_run({"weapon": "crowbar", "boosts": ["adrenaline"]})
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 30:
		await process_frame
	for shot in SHOTS:
		main.player.global_position = shot.pos
		main.player.rotation.y = shot.yaw
		main.player.get_child(1).rotation.x = shot.pitch
		main.player.velocity = Vector3.ZERO
		main.colossus.global_position = shot.get("monster", Vector3(0, 0, -100))
		main.colossus.rotation.y = PI
		for i in 20:
			await process_frame
		_save(out_dir, shot.name)

	var result := ResultScreen.new()
	result.survived = true
	result.items = [LootTable.ITEMS[0], LootTable.ITEMS[4], LootTable.ITEMS[4], LootTable.ITEMS[29]]
	result.payout = LootTable.payout(result.items)
	main.add_child(result)
	for i in 5:
		await process_frame
	_save(out_dir, "result")
	quit()


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
