extends SceneTree
## Renders the awakening HUD at each stage (沉睡 / 驚醒 / 暴走), a shot's eye pulse, the
## stage banners, and the red-pulsing exit lift at 暴走.
## Run (needs a display):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/awakening_shots.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Awakening.frozen = true
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	Run.forced_monsters = ["colossus"]
	Run.forced_map = "factory"
	main.start_run({"build": Arsenal.STARTER, "boosts": ["adrenaline"]})
	await _frames(40)
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, -50, -100)
	var player: Player = main.player
	player.global_position = Vector3(4.0, 0.1, 19.0)
	player.rotation.y = 0.0
	main.hud._help_timer = 0.0
	main.hud.show_message("", 0.0)
	var awake: Awakening = main.run.awakening
	await _frames(60)

	awake.level = 18.0
	await _frames(5)
	_save(out_dir, "stage0")
	awake.shot_woke.emit(1.0)
	await _frames(9)
	_save(out_dir, "stage0_shot")

	awake.host_force_stage(1)
	awake.level = 48.0
	await _frames(30)
	_save(out_dir, "stage1_banner")
	await _frames(300)
	_save(out_dir, "stage1")

	awake.host_force_stage(2)
	awake.level = 82.0
	await _frames(30)
	_save(out_dir, "stage2_banner")
	await _frames(300)
	_save(out_dir, "stage2")

	# The exit lift at 暴走.
	main.run._lever_pulled()
	var zone: ExtractionZone = main.level.extraction_zone
	player.global_position = zone.global_position + Vector3(0.0, -1.1, 5.5)
	player.rotation.y = 0.0
	player.get_node("Head").rotation.x = -0.1
	player.set_lantern(false)
	main.hud.show_message("", 0.0)
	await _frames(40)
	_save(out_dir, "stage2_exit")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
