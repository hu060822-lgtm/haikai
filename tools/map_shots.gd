extends SceneTree
## Renders a few views of the newer maps, plus the guardian's overview of each.
## Run (needs a display): godot --path . --script res://tools/map_shots.gd -- <out_dir>

const SHOTS := {
	"mall": [
		{"name": "mall_lobby", "pos": Vector3(0.0, 0.1, 21.0), "yaw": 0.0, "pitch": 0.05},
		{"name": "mall_atrium", "pos": Vector3(-9.0, 0.1, 9.0), "yaw": -0.7, "pitch": 0.2},
		{"name": "mall_escalator", "pos": Vector3(5.0, 0.1, 8.5), "yaw": PI / 2.0, "pitch": 0.2},
		{"name": "mall_upper", "pos": Vector3(-9.0, 5.1, 14.0), "yaw": 0.0, "pitch": -0.15},
		{"name": "mall_shop", "pos": Vector3(-10.0, 0.1, -1.0), "yaw": PI / 2.0, "pitch": -0.05},
		{"name": "mall_dock", "pos": Vector3(0.0, 0.1, -20.0), "yaw": -PI / 2.0, "pitch": 0.0},
	],
	"station": [
		{"name": "station_hut", "pos": Vector3(-14.0, 0.1, 1.0), "yaw": PI / 2.0 + 0.3, "pitch": 0.0},
		{"name": "station_snow", "pos": Vector3(-6.0, 0.1, 2.0), "yaw": -PI / 2.0, "pitch": 0.05},
		{"name": "station_yard", "pos": Vector3(-2.0, 0.1, 4.0), "yaw": PI, "pitch": 0.05},
		{"name": "station_generator", "pos": Vector3(13.0, 0.1, -19.0), "yaw": -PI / 2.0, "pitch": -0.1},
		{"name": "station_garage", "pos": Vector3(10.0, 0.1, 18.0), "yaw": -PI / 2.0, "pitch": 0.0},
		{"name": "station_lab", "pos": Vector3(-11.0, 0.1, 20.0), "yaw": PI / 2.0, "pitch": -0.05},
	],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Run.forced_monsters = ["colossus"]
	Run.director_enabled = false
	for id in SHOTS:
		Run.forced_map = id
		var main = load("res://scenes/main.tscn").instantiate()
		main.show_menus = false
		root.add_child(main)
		main.start_run({})
		for i in 30:
			await process_frame
		main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
		main.colossus.global_position = Vector3(0, -50, -100)
		for shot in SHOTS[id]:
			main.player.global_position = shot.pos
			main.player.rotation.y = shot.yaw
			main.player.get_node("Head").rotation.x = shot.pitch
			main.player.velocity = Vector3.ZERO
			for i in 40:
				await process_frame
			_save(out_dir, shot.name)
		# After the objective: neon / headlights on.
		main.run._lever_pulled()
		var last: Dictionary = SHOTS[id][0]
		main.player.global_position = last.pos
		main.player.rotation.y = last.yaw
		for i in 40:
			await process_frame
		_save(out_dir, id + "_powered")
		main.hud.visible = false
		var view := GuardianView.new()
		view.run = main.run
		view.pixel_scale = main._container.stretch_shrink
		main.add_child(view)
		for i in 10:
			await process_frame
		_save(out_dir, id + "_guardian")
		main.queue_free()
		for i in 5:
			await process_frame
	quit()


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
