extends SceneTree
## Screenshots for the organ work (怪物就是零件):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --script res://tools/organ_shots.gd -- <out_dir> [set]
## Sets: "lineup" (every organ model as floor loot, in rows), "floor" (organs as real loot
## in a run), "bench" (the gunsmith with organs fitted), "bestiary" (the 怪物圖鑑 panel).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var which: String = args[1] if args.size() > 1 else "lineup"
	DirAccess.make_dir_recursive_absolute(out)
	GameState.save_enabled = false
	GameModels_snap()
	match which:
		"lineup":
			await _lineup(out)
		"bench":
			await _bench(out)
		"bestiary":
			await _bestiary(out)
		"floor":
			await _floor(out)
	quit()


func GameModels_snap() -> void:
	GunModels.snap = 400.0


func _save(path: String) -> void:
	for i in 6:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved ", path)


func _stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.5)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	stage.add_child(LowPoly.instance(LowPoly.chamfer_box(Vector3(30, 0.2, 20), 0.05), "concrete",
		Color(0.45, 0.45, 0.45), LowPoly.at(Vector3(0, -0.1, 0))))
	return stage


func _lineup(out: String) -> void:
	var ids := Arsenal.organ_ids()
	var per_row := 4
	for page in 2:
		var stage := _stage()
		var shown := ids.slice(page * 12, page * 12 + 12)
		for i in shown.size():
			var id: String = shown[i]
			var data := Organs.loot_data(id)
			var size: Vector3 = data.size
			var model := Node3D.new()
			model.add_child(Organs.floor_model(id, size))
			var row := i / per_row
			model.position = Vector3((i % per_row - 1.5) * 1.05, size.y * 0.5, -row * 1.1)
			model.rotation_degrees.y = 150.0
			stage.add_child(model)
			var label := Label3D.new()
			label.text = data.name
			label.font_size = 32
			label.pixel_size = 0.003
			label.position = Vector3(model.position.x, 0.02, model.position.z + 0.45)
			label.rotation_degrees.x = -60
			stage.add_child(label)
		var camera := Camera3D.new()
		camera.position = Vector3(0, 2.3, 1.7)
		camera.rotation_degrees = Vector3(-50, 0, 0)
		camera.fov = 55
		stage.add_child(camera)
		camera.current = true
		await _save(out.path_join("organs_lineup_%d.png" % page))
		stage.free()


func _bench(out: String) -> void:
	for id in Arsenal.organ_ids():
		GameState.stash[id] = 1
	var screen := LoadoutScreen.new()
	root.add_child(screen)
	await process_frame
	screen.plan = {"frame": "smg", "parts": {"muzzle": "screamer_mask", "sight": "watcher_eye", "magazine": "centipede_segment",
		"stock": "knight_door", "underbarrel": "hound_fang", "ammo": "spitter_sac", "gadget": "mother_musicbox"}}
	screen.select_frame("smg")
	await _save(out.path_join("bench_organs.png"))
	screen.open_slot("ammo")
	screen._hover_part("colossus_heart")
	await _save(out.path_join("bench_picker.png"))
	GameState.stash.erase("weaver_gland")
	GameState.stash.erase("colossus_heart")
	screen.close_picker()
	screen.open_slot("ammo")
	await _save(out.path_join("bench_picker_missing.png"))
	screen.close_picker()
	screen.plan = {"frame": "rifle", "parts": {"barrel": "burrower_drill", "ammo": "weaver_gland", "sight": "eye_lens", "stock": "mannequin_arm"}}
	screen.select_frame("rifle")
	await _save(out.path_join("bench_missing_organ.png"))
	screen.free()


func _bestiary(out: String) -> void:
	var screen := LoadoutScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open_bestiary()
	await _save(out.path_join("bestiary.png"))
	screen.bestiary_scroll(0.5)
	await _save(out.path_join("bestiary_2.png"))
	screen.bestiary_scroll(1.0)
	await _save(out.path_join("bestiary_3.png"))
	screen.free()


## In a real run: monsters killed and broken right in front of the player drop their
## organs (the real host path), plus a few more organs laid out; then a first-person look
## at an organ gun.
func _floor(out: String) -> void:
	GameState.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	Run.forced_monsters = ["hounds", "spitter", "shield_knight", "screamer"]
	Run.forced_map = "factory"
	main.start_run({"build": {"frame": "revolver", "parts": {"sight": "watcher_eye", "underbarrel": "hound_fang", "gadget": "mother_musicbox", "muzzle": "screamer_mask"}}, "boosts": []})
	for i in 40:
		await process_frame
	var run: Run = main.run
	var player: Player = main.player
	var spot := Vector3(4.0, 0.1, 19.0)
	player.global_position = spot
	player.rotation.y = 0.0
	main.hud._help_timer = 0.0
	main.hud.show_message("", 0.0)
	var front := spot + Vector3(0, 0.3, -2.6)
	var kills := 0
	for monster in run.live_monsters():
		monster.process_mode = Node.PROCESS_MODE_DISABLED
		monster.global_position = front + Vector3(-1.2 + kills * 0.8, 0, -kills * 0.3)
		kills += 1
	run.rng.seed = 4
	for monster in run.live_monsters():
		run.host_damage_monster(monster, 5000.0, {"bullet": true}, spot)
	for monster in run.live_monsters():
		monster.global_position = Vector3(0, -50, -100)
	var extra := ["colossus_heart", "watcher_eye", "centipede_segment", "mother_musicbox", "weaver_gland"]
	for i in extra.size():
		run.host_spawn_loot(Organs.loot_data(extra[i]), front + Vector3(-1.6 + i * 0.8, 0.4, -1.4), 0.6 * i, false)
	for i in 90:
		await process_frame
	var head: Node3D = player.get_node("Head")
	head.rotation.x = -0.5
	for i in 10:
		await process_frame
	await _save(out.path_join("organs_in_game.png"))
	head.rotation.x = -0.05
	player.force_aim = true
	for i in 30:
		await process_frame
	await _save(out.path_join("organ_gun_aim.png"))
	player.force_aim = false
	for i in 20:
		await process_frame
	await _save(out.path_join("organ_gun_hip.png"))
