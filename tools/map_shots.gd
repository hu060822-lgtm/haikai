extends SceneTree
## Renders a few views of the newer maps.
## Run (needs a display): godot --path . --script res://tools/map_shots.gd -- <out_dir> [map]

const SHOTS := {
	"factory": [],
	"mall": [
		{"name": "mall_lobby", "pos": Vector3(0.0, 0.1, 21.0), "yaw": 0.0, "pitch": 0.05},
		{"name": "mall_atrium", "pos": Vector3(-9.0, 0.1, 9.0), "yaw": -0.7, "pitch": 0.2},
		{"name": "mall_escalator", "pos": Vector3(5.0, 0.1, 8.5), "yaw": PI / 2.0, "pitch": 0.2},
		{"name": "mall_upper", "pos": Vector3(-9.0, 5.1, 14.0), "yaw": 0.0, "pitch": -0.15},
		{"name": "mall_shop", "pos": Vector3(-10.0, 0.1, -1.0), "yaw": PI / 2.0, "pitch": -0.05},
		{"name": "mall_dock", "pos": Vector3(0.0, 0.1, -20.0), "yaw": -PI / 2.0, "pitch": 0.0},
	],
	"subway": [
		{"name": "subway_concourse", "pos": Vector3(-29.0, 5.1, -1.0), "yaw": -PI / 2.0 - 0.2, "pitch": 0.0},
		{"name": "subway_platform", "pos": Vector3(-2.0, 0.1, -4.5), "yaw": -PI / 2.0 + 0.15, "pitch": 0.05},
		{"name": "subway_tracks", "pos": Vector3(14.0, 0.1, -12.2), "yaw": PI / 2.0 - 0.25, "pitch": -0.05},
		{"name": "subway_escalator", "pos": Vector3(3.0, 0.1, 0.5), "yaw": PI / 2.0, "pitch": 0.25},
		{"name": "subway_signal_box", "pos": Vector3(35.0, 0.1, -3.5), "yaw": -PI / 2.0 - 0.4, "pitch": -0.05},
		{"name": "subway_lift", "pos": Vector3(-26.0, 0.1, 2.5), "yaw": PI / 2.0, "pitch": 0.0},
	],
	"afternoon": [
		{"name": "afternoon_corridor", "pos": Vector3(2.0, 0.1, 0.0), "yaw": -PI / 2.0, "pitch": 0.0},
		{"name": "afternoon_living", "pos": Vector3(0.0, 0.1, -2.5), "yaw": 0.0, "pitch": 0.0},
		{"name": "afternoon_playground", "pos": Vector3(-8.0, 0.1, -4.0), "yaw": 0.6, "pitch": 0.1},
		{"name": "afternoon_dining", "pos": Vector3(8.0, 0.1, -10.0), "yaw": -PI / 2.0, "pitch": -0.05},
		{"name": "afternoon_bedroom", "pos": Vector3(-7.0, 0.1, 4.0), "yaw": PI * 0.75, "pitch": 0.15},
		{"name": "afternoon_pool", "pos": Vector3(8.0, 0.1, 4.0), "yaw": -PI * 0.75, "pitch": -0.05},
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
	# Optional second argument: only this map.
	var only: String = args[1] if args.size() > 1 else ""
	for id in SHOTS:
		if only != "" and id != only:
			continue
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
		# A few rooms from the random wings, seen from their clear centres.
		var shown := 0
		for grid in main.level.wings:
			var by_size: Array = grid.rooms.duplicate()
			by_size.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return (a.max - a.min).length() > (b.max - b.min).length())
			var seen_kits := {}
			for room in by_size:
				if shown >= 6 or not room.wide or room.get("kit", "") == "" or seen_kits.has(room.kit):
					continue
				seen_kits[room.kit] = true
				var centre: Vector3 = room.clear_points[0]
				var corner := Vector3(room.min.x if centre.x - room.min.x > room.max.x - centre.x else room.max.x, 0,
					room.min.y if centre.z - room.min.y > room.max.y - centre.z else room.max.y)
				var to := corner - centre
				main.player.global_position = centre + Vector3(0, 0.1, 0)
				main.player.rotation.y = atan2(-to.x, -to.z)
				main.player.get_node("Head").rotation.x = -0.1
				main.player.velocity = Vector3.ZERO
				for i in 40:
					await process_frame
				_save(out_dir, "%s_wing_%d_%s" % [id, shown, room.kit])
				shown += 1
		if SHOTS[id].is_empty():
			main.queue_free()
			for i in 5:
				await process_frame
			continue
		# The subway's last train, seen from the platform as it comes through.
		if main.level.has_method("host_call_train"):
			main.level.warn_time = 4.0
			main.player.global_position = Vector3(6.0, 0.1, 4.6)
			main.player.rotation.y = PI / 2.0 + 0.5
			main.player.get_node("Head").rotation.x = -0.05
			main.level.host_call_train(1, 1)
			for i in 150:
				await process_frame
			_save(out_dir, id + "_warning")
			while main.level.train_state != "passing":
				await process_frame
			# Frames are slow under xvfb: pin the train where it shows best.
			for at: float in [-2.0, 30.0]:
				main.level._sweep_t = (SubwayStation.END_X + at) / SubwayStation.TRAIN_SPEED
				main.level._place_train()
				await process_frame
				await process_frame
				_save(out_dir, id + ("_train" if at < 0.0 else "_train2"))
		# After the objective: neon / headlights on.
		main.run._lever_pulled()
		var last: Dictionary = SHOTS[id][0]
		main.player.global_position = last.pos
		main.player.rotation.y = last.yaw
		for i in 40:
			await process_frame
		_save(out_dir, id + "_powered")
		main.queue_free()
		for i in 5:
			await process_frame
	quit()


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
