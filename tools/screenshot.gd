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
	main.show_loadout()  # the game opens on the title screen
	for i in 10:
		await process_frame
	_save(out_dir, "loadout")

	main.session.host(24560)
	var guest_id := 2
	main.session.roster[guest_id] = {"name": "阿明", "role": "guardian"}
	main.session.roster_changed.emit()
	main.show_lobby()
	for i in 10:
		await process_frame
	_save(out_dir, "lobby")
	main.session.leave()

	main.show_menus = false
	Run.forced_monsters = ["colossus", "mannequin", "moth", "mimic"]
	Run.forced_map = "factory"
	main.start_run({"build": Arsenal.STARTER, "boosts": ["adrenaline"]})
	for i in 30:
		await process_frame
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	var extras := []
	for node in main.run.monsters_root.get_children():
		if node is Node3D and node != main.colossus:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			extras.append(node)
			node.global_position = Vector3(0, -50, -100)
	for shot in SHOTS:
		main.player.global_position = shot.pos
		main.player.rotation.y = shot.yaw
		main.player.get_node("Head").rotation.x = shot.pitch
		main.player.velocity = Vector3.ZERO
		main.colossus.global_position = shot.get("monster", Vector3(0, 0, -100))
		main.colossus.rotation.y = PI
		for i in 20:
			await process_frame
		_save(out_dir, shot.name)

	# A teammate, as other players see them.
	var mate := Player.new()
	mate.display_name = "阿明"
	mate.set_multiplayer_authority(guest_id)
	main.run.players_root.add_child(mate)
	mate.global_position = Vector3(4.0, 0.1, 15.5)
	mate.rotation.y = PI * 0.85
	main.player.global_position = Vector3(4.0, 0.1, 19.0)
	main.player.rotation.y = 0.0
	main.player.get_node("Head").rotation.x = 0.0
	main.hud.set_voice("speaking")
	for i in 20:
		await process_frame
	_save(out_dir, "teammate")

	mate.queue_free()
	main.hud.set_voice("")
	# The new monsters, one at a time, in front of the camera.
	var player: Player = main.player
	player.global_position = Vector3(4.0, 0.1, 19.0)
	player.rotation.y = 0.0
	var done := {}
	for node in extras:
		var shot := ""
		if node is Mannequin:
			node.global_position = Vector3(4.3, 0.05, 16.2)
			node.rotation.y = 0.2
			node.pose = 1
			shot = "mannequin"
		elif node is Moth:
			node.global_position = Vector3(3.8, 1.6, 17.6)
			node.rotation.y = 0.6
			shot = "moth"
		elif node is Mimic:
			node.global_position = Vector3(4.0, 0.05, 17.9)
			node.rotation.y = 0.9
			node.disguised = false
			shot = "mimic"
		if shot != "" and not done.has(shot):
			done[shot] = true
			player.get_node("Head").rotation.x = -0.6 if shot == "mimic" else -0.05
			for i in 15:
				await process_frame
			_save(out_dir, shot)
		node.global_position = Vector3(0, -50, -100)

	# A row of loot, to show off the shapes.
	player.global_position = Vector3(4.0, 0.1, 19.0)
	player.rotation.y = 0.0
	player.get_node("Head").rotation.x = -0.55
	var picks := [12, 19, 34, 40, 53, 60, 69, 72, 84, 98, 57, 93]
	var index := 0
	for item in LootTable.ITEMS:
		if item.id in picks:
			var x := 3.0 + (index % 6) * 0.4
			var z := 17.0 - (index / 6) * 0.6
			main.run.host_spawn_loot(item, Vector3(x, 0.4, z))
			index += 1
	for i in 30:
		await process_frame
	_save(out_dir, "loot")

	# The guardian's machine room, over the same run.
	main.run.field.energy = 70.0
	main.run.host_set_gate(1, true)
	main.hud.visible = false
	var view := GuardianView.new()
	view.run = main.run
	view.pixel_scale = main._container.stretch_shrink
	main.add_child(view)
	for i in 5:
		await process_frame
	view.energy = 70.0
	view.cooldowns = {"gate": 12.0, "power": 0.0, "monster": 0.0}
	view.extracted = 140
	for ping in [[Vector3(-6, 0, 4), 14.0, 0.3], [Vector3(10, 6, -6), 8.0, 1.2], [Vector3(2, 0, 12), 6.0, 0.8]]:
		view._pings.append({"pos": ping[0], "radius": ping[1], "age": ping[2]})
	view._select_monster()
	for i in 10:
		await process_frame
	_save(out_dir, "guardian")
	view.queue_free()
	main.hud.visible = true

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
