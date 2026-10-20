extends SceneTree
## Screenshots of the first-person guns: idle, aiming, firing (muzzle flash, tracers),
## flame, tesla arc, reload, knife, hit marker, and a rival holding a gun.
## Run (needs a display): godot --rendering-driver opengl3 --path . --script res://tools/combat_shots.gd -- <out_dir>

const SPOT := Vector3(4.0, 0.1, 19.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://combat_shots"
	var only: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	Run.forced_monsters = ["colossus", "collector"]
	Run.forced_map = "factory"
	main.start_run({"build": Arsenal.STARTER, "boosts": []})
	await _frames(40)
	var run: Run = main.run
	var player: Player = main.player
	for monster in run.live_monsters():
		monster.process_mode = Node.PROCESS_MODE_DISABLED
		monster.global_position = Vector3(0, -50, -100)
	var greeter: Node3D = null
	for monster in run.live_monsters():
		if monster is Collector:
			greeter = monster
	main.hud._help_timer = 0.0
	main.hud.show_message("", 0.0)
	var head: Node3D = player.get_node("Head")
	var shots := [
		{"name": "revolver_idle", "build": {"frame": "revolver", "parts": {}}},
		{"name": "revolver_fire", "build": {"frame": "revolver", "parts": {}}, "fire": true},
		{"name": "revolver_aim", "build": {"frame": "revolver", "parts": {"sight": "red_dot"}}, "aim": true},
		{"name": "smg_fire", "build": {"frame": "smg", "parts": {"muzzle": "compensator", "magazine": "drum_mag", "stock": "heavy_stock", "underbarrel": "flashlight"}}, "fire": true},
		{"name": "shotgun_fire", "build": {"frame": "shotgun", "parts": {"stock": "heavy_stock"}}, "fire": true, "target": true},
		{"name": "rifle_aim", "build": {"frame": "rifle", "parts": {"sight": "scope"}}, "aim": true, "fire": true},
		{"name": "flamethrower", "build": {"frame": "flamethrower", "parts": {}}, "fire": true, "repeat": 6, "target": true},
		{"name": "tesla", "build": {"frame": "tesla", "parts": {}}, "fire": true, "target": true},
		{"name": "railgun", "build": {"frame": "railgun", "parts": {"sight": "red_dot"}}, "fire": true},
		{"name": "saw", "build": {"frame": "saw_launcher", "parts": {}}, "fire": true, "wait": 4},
		{"name": "reload", "build": {"frame": "smg", "parts": {}}, "reload": true},
		{"name": "knife", "build": {"frame": "revolver", "parts": {}}, "knife": true},
	]
	for shot in shots:
		if only != "" and not shot.name.begins_with(only):
			continue
		player.equip({"build": shot.build})
		player.global_position = SPOT
		player.rotation.y = 0.0
		head.rotation.x = -0.04
		player.velocity = Vector3.ZERO
		player.force_aim = shot.get("aim", false)
		if greeter != null:
			greeter.global_position = Vector3(4.0, 0.1, 13.5) if shot.get("target", false) else Vector3(0, -50, -100)
			greeter.rotation.y = PI
		await _frames(30)
		if shot.get("reload", false):
			player.mag_ammo = 3
			player.reload()
			await _frames(int(player.weapon.reload * 60.0 * 0.4))
		if shot.get("knife", false):
			player.melee()
			await create_timer(0.12).timeout
		if shot.get("fire", false):
			for i in shot.get("repeat", 1):
				player._fire_cooldown = 0.0
				player.fire()
				await _frames(1 if i == shot.get("repeat", 1) - 1 else 5)
			await _frames(shot.get("wait", 0))
		_save(out_dir, shot.name)
		player.force_aim = false

	# A hit marker on the HUD.
	main.hud.show_hit(16.0, "hit")
	await _frames(2)
	_save(out_dir, "hit_marker")
	main.hud.show_hit(48.0, "kill")
	await _frames(2)
	_save(out_dir, "kill_marker")

	# A rival scavenger holding a shotgun, as other players see them.
	var rival := Player.new()
	rival.display_name = "對手"
	rival.squad = 1
	rival.set_multiplayer_authority(7)
	run.players_root.add_child(rival)
	rival.gun_code = JSON.stringify({"frame": "shotgun", "parts": {"stock": "heavy_stock"}})
	rival.global_position = Vector3(4.6, 0.1, 16.6)
	rival.rotation.y = PI * 0.8
	player.equip({"build": Arsenal.STARTER})
	player.global_position = SPOT
	player.rotation.y = 0.0
	head.rotation.x = -0.1
	await _frames(20)
	_save(out_dir, "rival")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
