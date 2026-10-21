extends RefCounted
## Smoke tests for the grid backpack: random bag shapes, item footprints, auto-placing and
## refusing, rotating, moving and dropping from the grid (also through the Tab screen),
## monsters stealing out of it, the weight slowdown with the exoskeleton, and the 2x3
## 保險箱 (moving in and out, what fits, paid out on death, safe from thieves).
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/bag_tests.gd").new().run(self)

const SEEDS := 300

var tree: SceneTree
var failures := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("grid backpack")
	_test_shapes()
	_test_footprints()
	await _test_packing()
	await _test_screen()
	await _test_stealing()
	await _test_box()
	await _test_box_death()
	await _test_box_extract()
	await _test_box_woken()
	return failures


func _test_shapes() -> void:
	var count_ok := true
	var linked := true
	var bounded := true
	var same := true
	var unique := {}
	var long := 0
	var compact := 0
	var notched := 0
	for seed in SEEDS:
		var shape := GridBag.generate(seed)
		var lookup := {}
		for cell in shape:
			lookup[cell] = true
		count_ok = count_ok and shape.size() == GridBag.CELLS and lookup.size() == GridBag.CELLS
		linked = linked and GridBag.is_linked(shape)
		var size := GridBag.extent(shape)
		bounded = bounded and size.x <= GridBag.MAX_SIZE.x and size.y <= GridBag.MAX_SIZE.y
		same = same and GridBag.generate(seed) == shape
		unique[str(shape)] = true
		if maxi(size.x, size.y) >= 7:
			long += 1
		if size.x * size.y <= 30:
			compact += 1
		if size.x * size.y - shape.size() >= 8:
			notched += 1
	_check(count_ok, "every bag has exactly %d cells" % GridBag.CELLS)
	_check(linked, "every bag's cells are connected")
	_check(bounded, "every bag fits in %dx%d" % [GridBag.MAX_SIZE.x, GridBag.MAX_SIZE.y])
	_check(same, "the same seed gives the same bag")
	_check(unique.size() > SEEDS * 0.9, "bags are varied (%d different shapes of %d)" % [unique.size(), SEEDS])
	_check(long > 20 and compact > 20 and notched > 20, "some bags are long, some blobby, some notched (%d / %d / %d)" % [long, compact, notched])
	_check(GridBag.generate(hash([1, 1])) != GridBag.generate(hash([1, 2])), "two scavengers in one run get different bags")


func _test_footprints() -> void:
	var items: Array[Dictionary] = []
	for item: Dictionary in LootTable.ITEMS:
		if not LootTable.is_bulky(item):
			items.append(LootTable.make(item.id))
	for letter in LootTable.NEON_LETTERS:
		var neon := LootTable.make(LootTable.NEON_ID)
		neon.letter = letter
		items.append(neon)
	for part_id: String in Organs.LOOT:
		items.append(Organs.loot_data(part_id))
	var shaped := true
	var fits_all := true
	var misfit := ""
	var sizes := {}
	for data in items:
		var cells := GridBag.footprint(data)
		var size := GridBag.extent(cells)
		shaped = shaped and not cells.is_empty() and GridBag.is_linked(cells) and size.x <= 3 and size.y <= 3
		sizes[cells.size()] = sizes.get(cells.size(), 0) + 1
	for seed in SEEDS:
		var shape := GridBag.generate(seed)
		for data in items:
			if GridBag.find_spot(shape, [], data) == GridBag.NONE:
				fits_all = false
				misfit = "%s in bag %d" % [data.name, seed]
	_check(shaped, "every footprint is one connected piece no bigger than 3x3")
	_check(fits_all, "every item (and organ) fits every empty bag in some rotation %s" % misfit)
	_check(sizes.get(1, 0) >= 20 and sizes.get(2, 0) >= 10 and sizes.get(4, 0) >= 5 and sizes.get(9, 0) >= 2,
		"footprints range from 1-cell trinkets to 3x3 lumps (%s)" % str(sizes))
	_check(GridBag.footprint(LootTable.make(17)).size() == 2 and GridBag.footprint(LootTable.make(11)).size() == 1
		and GridBag.footprint(LootTable.make(74)).size() == 6, "a bottle is 1x2, a key 1x1, a crate of noodles 3x2")
	var toy_gun := GridBag.footprint(LootTable.make(32))
	_check(toy_gun.size() == 3 and GridBag.extent(toy_gun) == Vector2i(2, 2), "odd items get L shapes (the toy gun)")
	var guitar := GridBag.footprint(LootTable.make(73))
	_check(GridBag.extent(GridBag.rotated(guitar, 1)) == Vector2i(2, 3) and GridBag.rotated(guitar, 4) == guitar
		and GridBag.rotated(guitar, 2) != guitar, "turning a footprint a quarter swaps its size; four turns is the same")
	_check(GridBag.find_spot(GridBag.generate(1), [], LootTable.make(101)) == GridBag.NONE, "bulky hauls never go in the bag")
	# Auto-placing packs tight enough that a handful of small things (13 cells) nearly always fits.
	var packed := 0
	for seed in SEEDS:
		var shape := GridBag.generate(seed)
		var carried: Array = []
		for id in [1, 2, 3, 4]:
			var data := LootTable.make(id)
			var spot := GridBag.find_spot(shape, carried, data)
			if spot == GridBag.NONE:
				break
			data.bag = spot
			carried.append(data)
		if carried.size() == 4:
			packed += 1
	_check(packed >= SEEDS * 0.98, "quick pickups pack tight: 13 cells of small loot fit %d of %d bags" % [packed, SEEDS])


func _test_packing() -> void:
	var main = await _new_run()
	var player: Player = main.player
	_check(player.bag_cells.size() == GridBag.CELLS and GridBag.is_linked(player.bag_cells), "you start the run with a %d-cell bag" % GridBag.CELLS)
	_check(player.bag_cells == GridBag.generate(hash([main.run.seed, player.get_multiplayer_authority()])),
		"the bag comes from the run seed and the player")
	var said: Array[String] = []
	player.message.connect(func(text: String) -> void: said.append(text))

	# A 3x2 bag: a 2x2 gear goes in, a second one doesn't, a bottle only fits turned.
	player.bag_cells.assign(_rect(3, 2))
	_check(player.pickup(LootTable.make(1)) and player.items[0].bag == Vector3i(0, 0, 0), "pickup puts it in the first spot it fits")
	_check(not player.pickup(LootTable.make(1)) and player.items.size() == 1 and _said_full(said),
		"no room: it's refused with 「包包塞不下」")
	_check(player.pickup(LootTable.make(17)) and player.items[1].bag.z % 2 == 1, "the bottle is turned to fit the last column")
	_check(GridBag.free_cells(player.bag_cells, player.items) == 0 and not player.can_carry(LootTable.make(11)), "a full bag takes nothing more")
	_check(main.hud._inventory.text.begins_with("背包 6 / 6 格"), "the HUD counts cells (%s)" % main.hud._inventory.text)

	# On the floor: E on loot that doesn't fit leaves it there.
	var floor_item: LootItem = main.run.host_spawn_loot(LootTable.make(11), player.global_position + Vector3(0, 0.3, -0.8), 0.0, true)
	await _frames(2)
	said.clear()
	floor_item.interact(player)
	await _frames(5)
	_check(is_instance_valid(floor_item) and not floor_item.is_queued_for_deletion() and _said_full(said),
		"E on loot that won't fit leaves it on the floor")

	# The host granted it but it no longer fits (something went in meanwhile): it goes back down.
	var loot_before: int = main.run.loot_root.get_child_count()
	main.run._grant_item(LootTable.make(5), player.global_position)
	await _frames(3)
	_check(main.run.loot_root.get_child_count() == loot_before + 1 and player.items.size() == 2, "a grant that no longer fits is dropped back")

	# G: the last thing in comes out first, and its cells are free again.
	player.drop_last()
	await _frames(3)
	_check(player.items.size() == 1 and GridBag.free_cells(player.bag_cells, player.items) == 2, "G drops it out of the grid")
	var dropped_bag := false
	for node in main.run.loot_root.get_children():
		if node is LootItem and (node as LootItem).data.has("bag"):
			dropped_bag = true
	_check(not dropped_bag, "loot on the floor forgets its place in the bag")

	# Moving and turning in a 4x4 bag.
	player.take_all_items()
	player.bag_cells.assign(_rect(4, 4))
	player.pickup(LootTable.make(32))  # toy gun, an L of three
	player.pickup(LootTable.make(1))   # gear, 2x2
	_check(player.bag_move(0, Vector2i(2, 2), 1) and player.items[0].bag == Vector3i(2, 2, 1), "an item can be moved and turned")
	_check(not player.bag_move(0, Vector2i(1, 1), 0) and player.items[0].bag == Vector3i(2, 2, 1), "it can't be moved onto another item")
	_check(not player.bag_move(1, Vector2i(3, 0), 0), "or hang off the edge of the bag")
	var taken := GridBag.occupancy(player.items)
	_check(taken.size() == 7, "occupied cells add up (%d)" % taken.size())

	# Weight slows you, the grid caps you; the exoskeleton takes the weight better.
	_check(Player.full_load(player) == Player.FULL_LOAD, "the load that slows you most is %d kg" % Player.FULL_LOAD)
	await _end_run(main)
	main = await _new_run({"build": Arsenal.STARTER, "boosts": ["exoskeleton"]})
	player = main.player
	_check(Player.full_load(player) == Player.EXO_FULL_LOAD and Player.EXO_FULL_LOAD > Player.FULL_LOAD, "the exoskeleton makes weight slow you less")
	player.take_all_items()
	player.bag_cells.assign(_rect(6, 4))
	for i in 3:
		player.pickup(LootTable.make(122))  # lead blocks: 12 kg in one cell
	var free_exo := player._weight_factor()
	await _end_run(main)
	main = await _new_run()
	player = main.player
	player.bag_cells.assign(_rect(6, 4))
	for i in 3:
		player.pickup(LootTable.make(122))
	_check(player.items.size() == 3 and player.carried_weight == 36.0, "36 kg of lead fits in three cells (no kg cap)")
	_check(free_exo > player._weight_factor(), "and you walk faster with it in the exoskeleton (%.2f vs %.2f)" % [free_exo, player._weight_factor()])
	await _end_run(main)


func _test_screen() -> void:
	var main = await _new_run()
	var player: Player = main.player
	player.take_all_items()
	player.bag_cells.assign(_rect(4, 3))
	player.pickup(LootTable.make(73))  # guitar: neck along the top, body under the end
	player.pickup(LootTable.make(11))  # a key
	var bag: BagScreen = main.hud.bag
	await _press_tab()
	_check(bag.visible and player.bag_open and main.hud.bag_open, "Tab opens the backpack screen")
	_check(not main.get_tree().paused, "the game keeps running behind it")
	player.hold_trigger = true
	var ammo := player.mag_ammo
	await _frames(10)
	player.hold_trigger = false
	_check(player.mag_ammo == ammo, "clicking in the bag doesn't fire the gun")
	_check(bag._stats.text.contains("總值 $%d" % player.carried_value), "it shows the total value (%s)" % bag._stats.text)

	# Hover: name, value, weight, tags.
	var guitar: Dictionary = player.items[0]
	var first: Vector2i = GridBag.placed_cells(guitar)[0]
	bag.point_at_cell(Vector2(first) + Vector2(0.5, 0.5))
	_check(bag.hovered == 0 and bag._info_name.text == guitar.name and bag._info_body.text.contains("$120") and bag._info_body.text.contains("kg")
		and bag._info_body.text.contains("吵鬧"), "hovering shows what it is (%s)" % bag._info_body.text.replace("\n", " / "))

	# Drag the key, turn it (a 1x1 turns to itself), drop it into the far corner.
	var key_cell: Vector2i = GridBag.placed_cells(player.items[1])[0]
	bag.point_at_cell(Vector2(key_cell) + Vector2(0.5, 0.5))
	_check(bag.begin_drag() and bag.drag == 1, "press on an item to drag it")
	var free_corner := Vector2i(-1, -1)
	for cell in player.bag_cells:
		if not GridBag.occupancy(player.items).has(cell):
			free_corner = cell
	bag.point_at_cell(Vector2(free_corner) + Vector2(0.5, 0.5))
	_check(bag.drag_fits() and bag.end_drag() == "moved" and GridBag.placed_cells(player.items[1])[0] == free_corner, "drop it on a free cell to move it")

	# Drag the guitar and turn it: R while dragging.
	bag.point_at_cell(Vector2(first) + Vector2(0.5, 0.5))
	bag.begin_drag()
	var turns := bag.drag_turns
	bag.turn()
	_check(bag.drag_turns == (turns + 1) % 4, "R turns the dragged item")
	bag.point_at_cell(Vector2(-4, -4))
	_check(bag.end_drag() == "dropped" and player.items.size() == 1 and player.items[0].id == 11, "dropping it outside the grid throws it on the floor")
	await _frames(3)
	var on_floor := false
	for node in main.run.loot_root.get_children():
		if node is LootItem and (node as LootItem).data.id == 73 and (node as LootItem).global_position.distance_to(player.global_position) < 3.0:
			on_floor = true
	_check(on_floor, "it lands in front of you")

	# Right click turns a hovered item in place; G drops the hovered item.
	player.pickup(LootTable.make(17))
	var bottle := player.items.size() - 1
	var before: Vector3i = player.items[bottle].bag
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[bottle])[0]) + Vector2(0.5, 0.5))
	bag.turn()
	_check(player.items[bottle].bag.z != before.z, "turning a hovered item turns it in place")
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[0])[0]) + Vector2(0.5, 0.5))
	var hovered_id: int = player.items[bag.hovered].id
	bag.drop_hovered()
	_check(player.items.size() == 1 and player.items[0].id != hovered_id, "G drops the item under the mouse")

	await _press_tab()
	_check(not bag.visible and not player.bag_open, "Tab again closes it")
	await _end_run(main)


func _test_stealing() -> void:
	var main = await _new_run()
	var player: Player = main.player
	player.take_all_items()
	player.bag_cells.assign(_rect(6, 4))
	for id in [1, 17, 11, 73]:
		player.pickup(LootTable.make(id))
	main.set_bag_open(true)
	var bag: BagScreen = main.hud.bag
	# Drag something, then rats tear something out of the pack.
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[3])[0]) + Vector2(0.5, 0.5))
	bag.begin_drag()
	var loot_before: int = main.run.loot_root.get_child_count()
	seed(3)
	player.remote_rob()
	await _frames(3)
	var taken := GridBag.occupancy(player.items)
	var cells := 0
	for item in player.items:
		cells += GridBag.placed_cells(item).size()
	_check(player.items.size() == 3 and taken.size() == cells and main.run.loot_root.get_child_count() == loot_before + 1,
		"stolen loot leaves the grid (no overlaps, %d cells used)" % taken.size())
	_check(bag.drag < 0 or is_same(player.items[bag.drag], bag._drag_data), "the drag lets go of a stolen item")
	bag.end_drag()
	# Something living wriggles out of the grid.
	player.pickup(LootTable.make(14))
	for i in 40:
		player._alive_timer = 0.0
		await _frames(1)
		if not player.carries(14):
			break
	_check(not player.carries(14) and GridBag.occupancy(player.items).size() == cells, "a living item escaping frees its cells")
	main.set_bag_open(false)
	await _end_run(main)


func _test_box() -> void:
	var main = await _new_run()
	var player: Player = main.player
	player.take_all_items()
	player.bag_cells.assign(_rect(4, 4))
	_check(player.box_cells.size() == 6 and GridBag.extent(player.box_cells) == Vector2i(2, 3), "every scavenger has a 2x3 保險箱")
	_check(GridBag.fits_box(LootTable.make(73)) and GridBag.fits_box(Organs.loot_data("hound_fang")),
		"a 3-long piece fits it turned on end (the guitar, a hound fang)")
	_check(not GridBag.fits_box(LootTable.make(83)) and not GridBag.fits_box(LootTable.make(101)),
		"a 3x3 lump and bulky hauls never fit it")

	# Pickup goes to the bag, never the box, even when the bag is full.
	player.bag_cells.assign(_rect(2, 1))
	player.pickup(LootTable.make(17))  # a bottle fills the 2x1 bag
	var said: Array[String] = []
	player.message.connect(func(text: String) -> void: said.append(text))
	_check(not player.pickup(LootTable.make(11)) and _said_full(said) and GridBag.free_cells(player.box_cells, player.items, "box") == 6,
		"a full bag still says 「包包塞不下」: the box only fills by hand")

	# Bag -> box -> bag.
	player.bag_cells.assign(_rect(4, 4))
	player.pickup(LootTable.make(11))
	_check(player.bag_move(0, Vector2i(0, 0), 1, true) and player.items[0].box == Vector3i(0, 0, 1) and not player.items[0].has("bag"),
		"an item moves from the bag into the box")
	_check(GridBag.occupancy(player.items).size() == 1 and GridBag.occupancy(player.items, -1, "box").size() == 2,
		"it leaves the bag's cells and takes the box's")
	_check(not player.bag_move(1, Vector2i(0, 1), 0, true), "the box refuses a spot that's taken")
	_check(player.bag_move(0, Vector2i(2, 2), 0) and player.items[0].has("bag") and not player.items[0].has("box"),
		"and moves back from the box to the bag")
	player.take_all_items()
	player.pickup(LootTable.make(83))  # the diving helmet, 3x3
	_check(not player.box_put(0) and not player.bag_move(0, Vector2i(0, 0), 0, true) and player.items[0].has("bag"),
		"too big for 2x3: it stays in the bag")
	player.take_all_items()
	player.pickup(LootTable.make(122))  # a 12 kg lead block
	player.box_put(0)
	_check(player.carried_weight == 12.0 and player.box_value == 35 and player.carried_value == 35, "box items still weigh, and count as carried value")
	_check(main.hud._inventory.text.contains("保險箱 $35"), "the HUD shows the box's worth (%s)" % main.hud._inventory.text)

	# Through the Tab screen: drag a key into the box, and back out.
	player.take_all_items()
	player.pickup(LootTable.make(11))
	player.pickup(LootTable.make(83))
	main.set_bag_open(true)
	await _frames(2)
	var bag: BagScreen = main.hud.bag
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[0])[0]) + Vector2(0.5, 0.5))
	bag.begin_drag()
	bag.point_at_box_cell(Vector2(1.5, 2.5))
	_check(bag.drag_fits() and bag.end_drag() == "moved" and player.items[0].box == Vector3i(1, 2, 0), "drag an item into the box on the bag screen")
	bag.point_at_box_cell(Vector2(1.5, 2.5))
	_check(bag.hovered == 0 and bag._info_body.text.contains("保險箱"), "hovering it says it's in the box (%s)" % bag._info_body.text.replace("\n", " / "))
	bag.turn()
	_check(player.items[0].has("box"), "turning it in place keeps it in the box")
	bag.begin_drag()
	var free_cell := Vector2i(-1, -1)
	for cell in player.bag_cells:
		if not GridBag.occupancy(player.items).has(cell):
			free_cell = cell
	bag.point_at_cell(Vector2(free_cell) + Vector2(0.5, 0.5))
	_check(bag.end_drag() == "moved" and player.items[0].has("bag"), "and drag it back into the bag")
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[1])[0]) + Vector2(0.5, 0.5))
	bag.begin_drag()
	bag.point_at_box_cell(Vector2(0.5, 0.5))
	_check(not bag.drag_fits() and bag.end_drag() == "back" and player.items[1].has("bag"), "the helmet won't drop into the box")
	# Letting go in the gap between the grids puts it back instead of throwing it away.
	bag.point_at_cell(Vector2(GridBag.placed_cells(player.items[0])[0]) + Vector2(0.5, 0.5))
	bag.begin_drag()
	bag.point_at(bag._box_corner() - Vector2(BagScreen.BOX_GAP * 0.5, -20.0))
	_check(bag.end_drag() == "back" and player.items.size() == 2, "letting go between the bag and the box puts it back")
	main.set_bag_open(false)

	# Thieves skip the box; G with the bag shut drops from the bag, not the box.
	player.take_all_items()
	for id in [11, 4, 1]:
		player.pickup(LootTable.make(id))
	player.box_put(0)
	player.box_put(1)
	seed(5)
	for i in 4:
		player.remote_rob()
	_check(player.items.size() == 2 and player.items[0].has("box") and player.items[1].has("box"), "rats only tear things out of the bag, never the box")
	player.drop_last()
	_check(player.items.size() == 2, "G with nothing in the bag leaves the box alone")
	player.pickup(LootTable.make(14))  # a living thing, in the box
	player.box_put(2)
	for i in 30:
		player._alive_timer = 0.0
		await _frames(1)
	_check(player.carries(14), "living loot can't wriggle out of the box")
	await _end_run(main)


func _test_box_death() -> void:
	GameState.reset()
	GameState.money = 500
	var main = await _new_run()
	var player: Player = main.player
	player.take_all_items()
	player.bag_cells.assign(_rect(6, 4))
	player.pickup(LootTable.make(1))   # gear $35, stays in the bag
	player.pickup(LootTable.make(3))   # copper $45, stays in the bag
	player.pickup(LootTable.make(11))  # key $25, into the box
	player.pickup(Organs.loot_data("hound_fang"))
	player.box_put(2)
	player.box_put(3)
	var loot_before: int = main.run.loot_root.get_child_count()
	player.take_damage(1000.0, "測試")
	await _frames(5)
	var result: Dictionary = main.last_result
	_check(not result.get("survived", true) and result.payout.get("total", 0) == 25 and GameState.money == 525,
		"dying pays out the box (+$%d, money $%d)" % [result.payout.get("total", 0), GameState.money])
	_check(GameState.owned("hound_fang") == 1 and result.get("organs", []) == ["hound_fang"], "an organ in the box goes to the stash")
	_check(result.items.size() == 2 and main.run.loot_root.get_child_count() == loot_before + 2,
		"only the bag spills with the body (%d items)" % result.items.size())
	var spilled_box := false
	for node in main.run.loot_root.get_children():
		if node is LootItem and ((node as LootItem).data.id == 11 or (node as LootItem).data.has("organ")):
			spilled_box = true
	_check(not spilled_box, "the box's things aren't on the floor")
	var screen := ResultScreen.new()
	screen.survived = false
	screen.cause = "測試"
	screen.items = result.items
	screen.payout = result.payout
	screen.organs = result.organs
	main.add_child(screen)
	await _frames(1)
	var texts := ""
	for label in screen.find_children("*", "Label", true, false):
		texts += (label as Label).text + "|"
	_check(texts.contains("保險箱保住了：發條鑰匙") and texts.contains("$25"), "the death screen says what the box saved")
	screen.queue_free()
	await _end_run(main)


func _test_box_extract() -> void:
	GameState.reset()
	var money := GameState.money
	var main = await _new_run()
	var player: Player = main.player
	player.take_all_items()
	player.bag_cells.assign(_rect(6, 4))
	for id in [1, 3, 11, 4]:
		player.pickup(LootTable.make(id))
	player.box_put(2)
	player.box_put(3)
	main.run.local_extracted()
	await _frames(3)
	_check(main.last_result.payout.total == 125 and GameState.money == money + 125, "extracting pays the bag and the box ($%d)" % main.last_result.payout.total)
	await _end_run(main)


func _test_box_woken() -> void:
	var main = await _new_run()
	var player: Player = main.player
	player.take_all_items()
	player.bag_cells.assign(_rect(6, 4))
	for id in [11, 4, 1, 2, 3, 122]:
		player.pickup(LootTable.make(id))
	player.box_put(0)
	player.box_put(1)
	main.run.local_woken()
	await _frames(3)
	var ids := []
	for item in main.last_result.items:
		ids.append(item.id)
	_check(main.last_result.items.size() == 4 and 11 in ids and 4 in ids, "woken up: half the bag is lost, the box keeps everything (%s)" % str(ids))
	await _end_run(main)


func _said_full(said: Array[String]) -> bool:
	for text in said:
		if text.begins_with(Player.BAG_FULL_MESSAGE):
			return true
	return false


## Tab, then wait until the input has been handled: parsed events are flushed on idle
## frames, and a slow run can fit several physics frames into one.
func _press_tab() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_TAB
	press.pressed = true
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	for i in 3:
		await tree.process_frame
	await _frames(1)


func _rect(w: int, h: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in h:
		for x in w:
			cells.append(Vector2i(x, y))
	return cells


func _new_run(loadout := {}) -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	tree.root.add_child(main)
	main.start_run(loadout)
	await _frames(40)
	return main


func _end_run(main: Node) -> void:
	main.queue_free()
	await _frames(5)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)
