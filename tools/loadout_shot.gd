extends SceneTree
## Renders the loadout (gear shop) screen.
## Run (needs a display): godot --path . --script res://tools/loadout_shot.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	GameState.money = 2400
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.show_loadout()  # the game opens on the title screen
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("loadout.png"))
	print("saved loadout")
	quit()
