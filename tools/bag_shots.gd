extends SceneTree
## Screenshots of the grid backpack: a few random bag shapes packed with loot, hovering an
## item, dragging (fits / doesn't fit, turned), and the 「包包塞不下」 message.
## Run (needs a display):
##   godot --path . --rendering-driver opengl3 --script res://tools/bag_shots.gd -- <out_dir>

const PACKS := [
	[1, 17, 73, 11, 32, 122, 63, 26, 44, 90, 12, 5, 79, 55],
	[85, 29, 13, 67, 21, 96, 43, 40, 20, 59, 93],
	[83, 49, 81, 22, 18, 8, 76, 4, 53, 14, 61, 66],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://bag"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset()
	Awakening.frozen = true
	Run.forced_monsters = ["colossus"]
	Run.forced_map = "factory"
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	main.start_run({"build": Arsenal.STARTER, "boosts": []})
	await _frames(40)
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, -50, -100)
	var player: Player = main.player
	player.global_position = Vector3(4.0, 0.1, 19.0)
	player.rotation.y = 0.0
	var bag: BagScreen = main.hud.bag
	main.hud._help_timer = 0.0

	var seeds := [11, 7, 1234]
	for i in PACKS.size():
		player.take_all_items()
		player.bag_cells = GridBag.generate(hash([seeds[i], 1]))
		if i == 1:
			player.pickup(Organs.loot_data("hound_fang"))
		for id: int in PACKS[i]:
			player.pickup(LootTable.make(id))
		main.set_bag_open(true)
		bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[0])[0]) + Vector2(0.5, 0.5))
		await _frames(6)
		_save(out_dir, "bag_%d" % i)
		main.set_bag_open(false)
		await _frames(2)

	# Dragging the guitar: over a free spot (green), turned over other loot (red), outside.
	player.take_all_items()
	player.bag_cells = GridBag.generate(hash([seeds[0], 1]))
	for id: int in [73, 1, 17, 11, 90]:
		player.pickup(LootTable.make(id))
	main.set_bag_open(true)
	await _frames(2)
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[0])[0]) + Vector2(0.5, 0.5))
	bag.begin_drag()
	var spot := Vector2i(-1, -1)
	var home: Vector3i = player.items[0].bag
	var best := -1
	for cell in player.bag_cells:
		bag.point_at_cell(Vector2(cell) + Vector2(0.5, 0.5))
		var lands := bag.drag_origin()
		var away := lands.distance_squared_to(Vector2i(home.x, home.y))
		if bag.drag_fits() and away > best:
			spot = cell
			best = away
	bag.point_at_cell(Vector2(spot) + Vector2(0.62, 0.4))
	await _frames(4)
	_save(out_dir, "drag_fits")
	bag.turn()
	var busy: Vector2i = GridBag.placed_cells(player.items[1])[0]
	bag.point_at_cell(Vector2(busy) + Vector2(0.6, 0.45))
	await _frames(4)
	_save(out_dir, "drag_turned_blocked")
	bag.point_at_cell(Vector2(-2.6, 2.2))
	await _frames(4)
	_save(out_dir, "drag_outside")
	bag._cancel_drag()
	main.set_bag_open(false)
	await _frames(2)

	# Full: a big thing on the floor in front of you that won't go in.
	player.take_all_items()
	player.bag_cells = GridBag.generate(hash([seeds[0], 1]))
	for id: int in [85, 82, 96, 89, 74, 1, 3]:
		player.pickup(LootTable.make(id))
	var item: LootItem = main.run.host_spawn_loot(LootTable.make(83), player.global_position + Vector3(0.0, 0.3, -1.4), 0.4, true)
	await _frames(10)
	item.interact(player)
	await _frames(12)
	_save(out_dir, "full_message")
	main.set_bag_open(true)
	await _frames(6)
	_save(out_dir, "full_bag")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, shot])
	print("saved ", shot)
