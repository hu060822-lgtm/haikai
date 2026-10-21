extends SceneTree
## Two-process multiplayer test over localhost. Start the host first, then the client:
##   godot --headless --path . --script res://tests/net_test.gd -- host
##   godot --headless --path . --script res://tests/net_test.gd -- client
## Each process prints its own checks and exits non-zero on failure.

const PORT := 24555
const SAFE_SPOT := Vector3(13.5, 6.1, 10.0)  # east catwalk, out of the colossus' reach
const TIMEOUT_FRAMES := 1200

var _failures := 0
var _main: Node
var _ended := false
var _summary := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_enabled = false
	GameState.reset()
	Run.forced_monsters = ["colossus", "mimic"]
	Run.forced_map = "factory"
	Awakening.frozen = true  # stages are forced below, never set off by stray noise
	_main = load("res://scenes/main.tscn").instantiate()
	_main.show_menus = false
	root.add_child(_main)
	await _frames(2)
	_main.session.run_ended.connect(func(summary: Dictionary) -> void:
		_summary = summary
		_ended = true)
	var role: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "host"
	match role:
		"host":
			await _host()
		"client":
			await _client()
		"pvp-host":
			await _pvp_host()
		"pvp-client":
			await _pvp_client()
	print("NET TEST %s %s (%d failures)" % [role.to_upper(), "PASSED" if _failures == 0 else "FAILED", _failures])
	# Let the last reliable messages go out before closing the connection.
	await _frames(90)
	_main.session.leave()
	await _frames(5)
	quit(1 if _failures > 0 else 0)


func _host() -> void:
	print("host")
	_main.session.local_name = "主機"
	_check(_main.session.host(PORT) == OK, "host opens a room")
	_check(await _wait(func() -> bool: return _main.session.roster.size() == 2), "client joins the lobby")
	_check(await _wait(func() -> bool: return _main.session.roster.values().any(
		func(entry) -> bool: return entry.name == "客人")), "client's name arrives")
	_main.session.begin_run()
	_check(await _wait(func() -> bool: return _main.run != null and _main.run.all_players().size() == 2),
		"both players spawn on the host")
	_main.player.global_position = SAFE_SPOT + Vector3(0, 0, -2)
	var loot_start := get_nodes_in_group("loot").size()
	var client_id: int = _remote_player().get_multiplayer_authority()
	var carried_by_client := func() -> bool:
		for node in get_nodes_in_group("loot"):
			if node.carry != null and node.carry.held_by(client_id):
				return true
		return false
	_check(await _wait(carried_by_client), "the host sees the client hauling a bulky item")
	_check(await _wait(func() -> bool: return not carried_by_client.call()), "the host sees the client put it down")
	_check(await _wait(func() -> bool: return _main.level.lever.is_pulled), "client pulls the lever")
	_check(_main.level.extraction_zone.powered, "lever powers the elevator for the host too")
	_check(_main.colossus.enraged, "client's lever enrages the host's colossus")
	_main.run.awakening.host_force_stage(1)
	_check(_main.run.awakening.stage == 1, "the host's ruin wakes up (驚醒)")
	_check(get_nodes_in_group("loot").size() < loot_start, "client's pickup removed loot on the host")
	var remote := _remote_player()
	_check(remote != null and remote.global_position.distance_to(SAFE_SPOT) < 2.0,
		"client's movement replicates to the host (%s)" % (remote.global_position if remote else Vector3.ZERO))
	_check(await _wait(func() -> bool: return remote == null or not is_instance_valid(remote) or remote.is_dead),
		"client's death replicates to the host")
	_check(not _ended, "run keeps going while the host is alive")
	_main.player.die("test")
	_check(await _wait(func() -> bool: return _ended), "run ends once everyone is done")


func _client() -> void:
	print("client")
	_main.session.local_name = "客人"
	var joined := false
	for attempt in 20:
		if _main.session.join("127.0.0.1", PORT) == OK:
			if await _wait(func() -> bool: return _main.session.roster.size() == 2, 120):
				joined = true
				break
		await _frames(30)
	_check(joined, "client connects to the host")
	_check(await _wait(func() -> bool: return _main.player != null and _main.run.all_players().size() == 2),
		"client sees both players")
	var player: Player = _main.player
	_check(player.get_multiplayer_authority() == _main.session.local_id(), "client owns its own player")
	_check(await _wait(func() -> bool: return get_nodes_in_group("loot").size() >= BoilerFactory.LOOT_MIN),
		"loot replicates to the client (%d)" % get_nodes_in_group("loot").size())
	_check(await _wait(func() -> bool: return _main.colossus != null), "the colossus replicates to the client")
	player.global_position = SAFE_SPOT
	player.velocity = Vector3.ZERO
	await _frames(30)

	var loot_before := get_nodes_in_group("loot").size()
	var item: LootItem = get_nodes_in_group("loot")[0]
	var value := item.value
	item.interact(player)
	_check(await _wait(func() -> bool: return player.items.size() == 1), "client picks up an item through the host")
	_check(player.carried_value == value, "picked item has the right value")
	_check(player.items[0].has("bag") and GridBag.placed_cells(player.items[0]).size() == GridBag.footprint(player.items[0]).size()
		and player.bag_cells.size() == GridBag.CELLS, "the granted item is placed in the client's own grid backpack")
	_check(await _wait(func() -> bool: return get_nodes_in_group("loot").size() == loot_before - 1),
		"picked item disappears for the client")

	var haul: LootItem = null
	for node in get_nodes_in_group("loot"):
		if node.carry != null:
			haul = node
			break
	_check(haul != null, "bulky hauls replicate to the client")
	if haul != null:
		player.global_position = haul.global_position + Vector3(0.0, 0.3 - haul.data.size.y / 2.0, 1.0)
		player.velocity = Vector3.ZERO
		await _frames(40)
		player.grab_bulky(haul)
		_check(await _wait(func() -> bool: return player.held_bulky == haul), "client lifts a bulky haul through the host")
		await _frames(20)
		_check(haul.global_position.distance_to(player.global_position) < 2.2, "the haul is in the client's hands")
		_check(player.bulky_factor() < 1.0, "the haul slows the client")
		player.release_bulky()
		_check(await _wait(func() -> bool: return not haul.carry.is_held()), "client puts the haul down")
		player.global_position = SAFE_SPOT
		player.velocity = Vector3.ZERO
		await _frames(30)

	var mimic: Mimic = null
	for node in _main.run.monsters_root.get_children():
		if node is Mimic:
			mimic = node
	_check(mimic != null, "mimics replicate to the client")
	if mimic != null:
		mimic.interact(player)
		_check(await _wait(func() -> bool: return player.health < Player.MAX_HEALTH), "a mimic on the host bites the client")
		_check(await _wait(func() -> bool: return not mimic.disguised), "the bitten mimic's reveal replicates")

	_main.level.lever.interact(player)
	_check(await _wait(func() -> bool: return _main.level.extraction_zone.powered), "client's lever powers the elevator")
	await _frames(60)
	_check(_main.colossus.enraged, "colossus rage replicates to the client")
	_check(await _wait(func() -> bool: return _main.run.awakening.stage == 1 and _main.run.awakening.level >= 34.0),
		"the awakening's stage and level reach the client")
	player.global_position = SAFE_SPOT
	await _frames(30)
	player.die("test")
	_check(not _ended, "run waits for the host after the client dies")
	_check(await _wait(func() -> bool: return get_nodes_in_group("loot").size() >= loot_before),
		"dead client's backpack spills onto the floor")
	_check(await _wait(func() -> bool: return _ended), "client sees the run end")


## Two squads: the client joins the blue squad, they start apart, and the host shoots them.
func _pvp_host() -> void:
	print("pvp host")
	_main.session.local_name = "紅"
	_check(_main.session.host(PORT) == OK, "host opens a room")
	_check(await _wait(func() -> bool: return _main.session.roster.size() == 2), "client joins the lobby")
	_check(await _wait(func() -> bool: return _main.session.is_pvp()), "the client moves to another squad")
	await _frames(10)
	_main.session.begin_run()
	_check(await _wait(func() -> bool: return _main.run != null and _main.run.all_players().size() == 2),
		"both players spawn")
	var rival := _remote_player()
	_check(rival.squad == 1 and _main.player.squad == 0, "each player knows its squad")
	_check(rival.global_position.distance_to(_main.player.global_position) > 12.0,
		"the squads start apart (%.1f m)" % rival.global_position.distance_to(_main.player.global_position))
	_main.player.global_position = SAFE_SPOT + Vector3(0, 0, -3)
	# Wait for the client to settle on the catwalk, then shoot down at it from just above its head.
	_check(await _wait(func() -> bool: return rival.global_position.distance_to(SAFE_SPOT) < 1.0), "the rival walks into view")
	await _frames(30)
	for shot in 2:
		var head := rival.global_position + Vector3.UP * 1.6
		var pellets := []
		for i in int(Arsenal.FRAMES.shotgun.pellets):
			pellets.append(Vector3.DOWN)
		_main.run.request_shot({"frame": "shotgun", "parts": {}}, head, pellets)
		await _frames(20)
	_check(await _wait(func() -> bool: return rival.is_dead), "two shotgun hits kill the rival")
	_main.player.die("test")
	_check(await _wait(func() -> bool: return _ended), "the run ends")
	_check(_summary.get("squads", []).size() == 2, "the result knows there were two squads")


func _pvp_client() -> void:
	print("pvp client")
	_main.session.local_name = "藍"
	var joined := false
	for attempt in 20:
		if _main.session.join("127.0.0.1", PORT) == OK:
			if await _wait(func() -> bool: return _main.session.roster.size() == 2, 120):
				joined = true
				break
		await _frames(30)
	_check(joined, "client connects to the host")
	await _frames(10)
	_main.session.request_next_squad()
	_check(await _wait(func() -> bool: return _main.session.squad_of(_main.session.local_id()) == 1), "the client is in the blue squad")
	_check(await _wait(func() -> bool: return _main.player != null and _main.run.all_players().size() == 2),
		"client sees both players")
	var player: Player = _main.player
	var cause := [""]
	player.died.connect(func(text: String) -> void: cause[0] = text)
	await _frames(10)
	var rival := _remote_player()
	_check(rival != null and not rival._name_label.visible, "the rival has no name tag")
	player.global_position = SAFE_SPOT
	player.velocity = Vector3.ZERO
	_check(await _wait(func() -> bool: return player.health < Player.MAX_HEALTH), "the host's shot hurts the client")
	_check(await _wait(func() -> bool: return player.is_dead), "the client dies")
	_check("紅隊" in cause[0], "the death names the squad that did it (%s)" % cause[0])
	_check(await _wait(func() -> bool: return _ended), "client sees the run end")


func _remote_player() -> Player:
	for other in _main.run.all_players():
		if other != _main.player:
			return other
	return null


func _wait(condition: Callable, frames := TIMEOUT_FRAMES) -> bool:
	for i in frames:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
