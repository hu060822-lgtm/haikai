extends SceneTree
## Renders a few camera positions to PNGs for quick visual checks.
## Run (needs a display): godot --path . --script res://tools/screenshot.gd -- <out_dir>

const SHOTS := [
	{"name": "spawn", "pos": Vector3(0.0, 0.1, 18.0), "yaw": 0.0, "pitch": 0.0},
	{"name": "boiler", "pos": Vector3(2.0, 0.1, -4.5), "yaw": 0.2, "pitch": 0.05},
	{"name": "pipe_walk", "pos": Vector3(12.0, 3.05, -4.0), "yaw": PI / 2.0, "pitch": -0.15},
	{"name": "duct", "pos": Vector3(-5.0, 0.05, 10.5), "yaw": 0.0, "pitch": -0.1},
	{"name": "extraction", "pos": Vector3(8.0, 0.1, -12.0), "yaw": 0.0, "pitch": 0.0},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	main.auto_restart = false
	root.add_child(main)
	for i in 30:
		await process_frame
	for shot in SHOTS:
		main.player.global_position = shot.pos
		main.player.rotation.y = shot.yaw
		main.player.get_child(1).rotation.x = shot.pitch
		main.player.velocity = Vector3.ZERO
		for i in 20:
			await process_frame
		var image := root.get_texture().get_image()
		image.save_png(out_dir.path_join(shot.name + ".png"))
		print("saved ", shot.name)
	quit()
