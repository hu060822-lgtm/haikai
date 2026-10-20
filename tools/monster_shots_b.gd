extends SceneTree
## Renders monster worker B's five monsters in front of the camera in the boiler factory.
## Run (needs a display): godot --path . --script res://tools/monster_shots_b.gd -- <out_dir> [kind...]

const KINDS := ["hounds", "weaver", "shield_knight", "stalker", "eyes"]
var SHOTS := [
	{"kind": "hounds", "script": Hound, "pos": Vector3(4.0, 0.1, 16.2), "pitch": -0.25},
	{"kind": "weaver", "script": WebWeaver, "pos": Vector3(4.0, 0.1, 14.6), "pitch": -0.25},
	{"kind": "shield_knight", "script": ShieldKnight, "pos": Vector3(4.0, 0.1, 11.5), "pitch": 0.22},
	{"kind": "stalker", "script": ShadowStalker, "pos": Vector3(4.0, 0.1, 15.8), "pitch": 0.05},
	{"kind": "eyes", "script": DriftEye, "pos": Vector3(4.0, 2.0, 16.3), "pitch": 0.35},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var only: Array = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Run.director_enabled = false
	Run.forced_map = "factory"
	Run.forced_monsters = KINDS
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	main.start_run({})
	for i in 30:
		await process_frame
	var found := {}
	for node in main.run.monsters_root.get_children():
		if node is Node3D:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.global_position = Vector3(0, -50, -100)
			for shot in SHOTS:
				if node.get_script() == shot.script:
					if not found.has(shot.kind):
						found[shot.kind] = []
					found[shot.kind].append(node)
	var player: Player = main.player
	for shot in SHOTS:
		if not only.is_empty() and not only.has(shot.kind):
			continue
		var group: Array = found.get(shot.kind, [])
		if group.is_empty():
			print("missing ", shot.kind)
			continue
		player.global_position = Vector3(4.0, 0.1, 19.0)
		player.rotation.y = 0.0
		player.get_node("Head").rotation.x = shot.pitch
		var monster: Node3D = group[0]
		monster.global_position = shot.pos
		monster.rotation.y = PI * 0.92
		var extras: Array[Node3D] = []
		var lamp := OmniLight3D.new()
		lamp.light_energy = 2.2
		lamp.omni_range = 12.0
		main.run.add_child(lamp)
		lamp.global_position = shot.pos + Vector3(0.5, 3.5, 2.5)
		if monster is Hound:
			monster.is_leader = true
			monster.rotation.y = PI * 0.8
			if group.size() > 1:
				group[1].global_position = shot.pos + Vector3(-1.6, 0, 0.9)
				group[1].rotation.y = PI * 1.25
				group[1].is_leader = false
				extras.append(group[1])
		if monster is WebWeaver:
			monster.global_position = shot.pos + Vector3(-0.6, 0, 0.4)
			monster.rotation.y = PI * 0.85
			var web := WebWeaver.make_web(2.6, WebWeaver.WEB_HEIGHT)
			main.run.add_child(web)
			web.global_position = shot.pos + Vector3(0.6, 0, -1.4)
			web.rotation.y = 0.15
			extras.append(web)
		if monster is DriftEye:
			monster.rotation.y = 0.0
			monster.look_at(player.head_position(), Vector3.UP)
			for i in range(1, mini(group.size(), 3)):
				group[i].global_position = shot.pos + Vector3(-1.2 * i + 0.4, 0.5 * i - 0.3, -1.0 * i)
				group[i].look_at(player.head_position(), Vector3.UP)
				extras.append(group[i])
		if monster is ShadowStalker:
			monster.lit = false
			for i in 30:
				await process_frame
			_save(out_dir, "stalker_dark")
			monster.lit = true
		for i in 30:
			await process_frame
		_save(out_dir, shot.kind)
		if monster is ShieldKnight:
			monster.state = ShieldKnight.State.STAGGER
			monster.process_mode = Node.PROCESS_MODE_INHERIT
			monster.set_physics_process(false)
			for i in 40:
				monster._animate(1.0 / 30.0)
				await process_frame
			_save(out_dir, "shield_knight_stagger")
			monster.process_mode = Node.PROCESS_MODE_DISABLED
			# And from behind.
			player.global_position = shot.pos + Vector3(0, 0, -6.0)
			player.rotation.y = PI
			for i in 20:
				await process_frame
			_save(out_dir, "shield_knight_back")
		lamp.queue_free()
		for extra in extras:
			if extra.get_parent() == main.run:
				extra.queue_free()
			else:
				extra.global_position = Vector3(0, -50, -100)
		monster.global_position = Vector3(0, -50, -100)
	quit()


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
