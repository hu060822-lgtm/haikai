extends SceneTree
## Screenshots of the gunsmith bench: the frame picker, a deep carbine build with tuning
## sliders, the part picker with stat deltas (a calibre change, a handguard swap that
## drops rail parts, a second rail accessory), saved plans and a random build.
## Run (needs a display):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . \
##     --script res://tools/bench_shots.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://bench"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	GameState.money = 3200
	var screen := LoadoutScreen.new()
	root.add_child(screen)
	await _frames(20)
	for state: String in ["frame_list", "deep_carbine", "deep_tuned", "receiver_picker", "handguard_picker", "rail_picker", "plans"]:
		screen.shot_state(state)
		await _frames(14)
		_save(out_dir, "bench_" + state)
	screen.close_picker()
	screen._set_tab("frames")
	screen.select_frame("shotgun")
	screen.strip_all()
	screen.random_mod(7)
	await _frames(14)
	_save(out_dir, "bench_random_shotgun")
	screen.select_frame("service_pistol")
	screen.strip_all()
	screen.set_part("barrel", "threaded_barrel")
	screen.set_part("muzzle", "flash_hider")
	screen.open_slot("silencer")
	screen._hover_part("can_wet")
	await _frames(14)
	_save(out_dir, "bench_pistol_picker")
	screen.queue_free()
	await _frames(3)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
