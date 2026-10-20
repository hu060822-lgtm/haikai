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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_enabled = false
	GameState.reset()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.show_menus = false
	root.add_child(_main)
	await _frames(2)
	_main.session.run_ended.connect(func() -> void: _ended = true)
	var role: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "host"
	if role == "host":
		await _host()
	else:
		await _client()
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
	_check(await _wait(func() -> bool: return _main.level.lever.is_pulled), "client pulls the lever")
	_check(_main.level.extraction_zone.powered, "lever powers the elevator for the host too")
	_check(_main.colossus.enraged, "client's lever enrages the host's colossus")
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
	_check(_main.colossus != null, "the colossus replicates to the client")
	player.global_position = SAFE_SPOT
	player.velocity = Vector3.ZERO
	await _frames(30)

	var loot_before := get_nodes_in_group("loot").size()
	var item: LootItem = get_nodes_in_group("loot")[0]
	var value := item.value
	item.interact(player)
	_check(await _wait(func() -> bool: return player.items.size() == 1), "client picks up an item through the host")
	_check(player.carried_value == value, "picked item has the right value")
	_check(await _wait(func() -> bool: return get_nodes_in_group("loot").size() == loot_before - 1),
		"picked item disappears for the client")

	_main.level.lever.interact(player)
	_check(await _wait(func() -> bool: return _main.level.extraction_zone.powered), "client's lever powers the elevator")
	await _frames(60)
	_check(_main.colossus.enraged, "colossus rage replicates to the client")
	player.global_position = SAFE_SPOT
	await _frames(30)
	player.die("test")
	_check(not _ended, "run waits for the host after the client dies")
	_check(await _wait(func() -> bool: return get_nodes_in_group("loot").size() >= loot_before),
		"dead client's backpack spills onto the floor")
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
