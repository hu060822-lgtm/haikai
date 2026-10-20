class_name Run
extends Node3D
## One run of the boiler factory, shared by every peer. Lives at the same node path on
## all machines (Main/RunView/Viewport/World) so its RPCs and spawners line up.
## The host owns loot, monsters, the lever and lockers; clients ask it for changes.

signal local_player_spawned(player: Player)
signal local_finished(result: Dictionary)
signal colossus_spawned(colossus: BoilerColossus)

const MATCH_TIME := 720.0
const BODY_SCATTER := 0.6

static var instance: Run
## Tests pin the monster kinds; empty means a random draw (see MonsterRoster).
static var forced_monsters: Array = []

var seed := 0
var roster := {}
var loadout := {}
var level: BoilerFactory
var local_player: Player
var colossus: BoilerColossus
var monster_kinds: Array[String] = []
var time_left := MATCH_TIME
var finished := false
var rng := RandomNumberGenerator.new()

var players_root: Node3D
var monsters_root: Node3D
var loot_root: Node3D
var _player_spawner: MultiplayerSpawner
var _monster_spawner: MultiplayerSpawner
var _loot_spawner: MultiplayerSpawner
var _loot_counter := 0
var _time_broadcast := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	rng.seed = seed
	level = BoilerFactory.new()
	level.name = "Level"
	level.rng.seed = seed
	level.build_navigation = _is_host()
	add_child(level)
	level.lever.interact_requested.connect(func() -> void: _to_host(&"_pull_lever"))
	for i in level.lockers.size():
		var index := i
		level.lockers[i].interact_requested.connect(func() -> void: _to_host(&"_pry_locker", [index]))

	players_root = _root("Players")
	monsters_root = _root("Monsters")
	loot_root = _root("Loot")
	_player_spawner = _spawner(players_root, _spawn_player)
	_monster_spawner = _spawner(monsters_root, _spawn_monster)
	_loot_spawner = _spawner(loot_root, _spawn_loot)

	var session := Session.instance
	if _is_host():
		session.world_ready_all.connect(_host_populate, CONNECT_ONE_SHOT)
		multiplayer.peer_disconnected.connect(func(id: int) -> void:
			var gone := players_root.get_node_or_null(str(id))
			if gone != null:
				gone.queue_free())
		session.noise_received.connect(func(pos: Vector3, radius: float, kind: int) -> void:
			GameNoise.emit_local(get_tree(), pos, radius, kind))
	else:
		session.time_synced.connect(func(seconds: float) -> void: time_left = seconds)
	session.report_world_ready.call_deferred()


func _process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and local_player != null and local_player.is_active():
		local_player.die("鍋爐爆炸了，你沒來得及出去")
	if _is_host():
		_time_broadcast -= delta
		if _time_broadcast <= 0.0:
			_time_broadcast = 1.0
			Session.instance.broadcast_time(time_left)


func all_players() -> Array[Player]:
	var result: Array[Player] = []
	for node in players_root.get_children():
		if node is Player:
			result.append(node)
	return result


# --- Host: populate the world once every peer has built it ---------------------------

func _host_populate() -> void:
	var index := 0
	for id in roster:
		_player_spawner.spawn({"id": id, "name": roster[id].name, "index": index})
		index += 1
	var loot := level.roll_loot()
	for entry in loot:
		host_spawn_loot(entry.item, entry.pos, entry.rot, true)
	_host_spawn_monsters()


func _host_spawn_monsters() -> void:
	monster_kinds.clear()
	if forced_monsters.is_empty():
		monster_kinds = MonsterRoster.pick(rng)
	else:
		monster_kinds.assign(forced_monsters)
	var spots := level.roll_loot()
	var serial := 0
	for kind in monster_kinds:
		var count_range: Array = MonsterRoster.MONSTERS[kind].count
		for i in rng.randi_range(count_range[0], count_range[1]):
			serial += 1
			var data := {"type": kind, "name": "%s%d" % [kind.capitalize(), serial], "seed": rng.randi()}
			match kind:
				"colossus":
					data.name = "Colossus"
					data.pos = level.monster_spawn
				"mannequin":
					data.pos = _far_patrol_point()
				"moth":
					data.pos = BoilerFactory.PATROL_POINTS[rng.randi_range(0, BoilerFactory.PATROL_POINTS.size() - 1)] + Vector3(0, 3.0, 0)
				"mimic":
					var spot: Dictionary = spots[serial % spots.size()]
					data.pos = spot.pos
					data.rot = spot.rot
					data.disguise = LootTable.roll(rng, 0.8)
			_monster_spawner.spawn(data)


## The patrol point farthest from where players start.
func _far_patrol_point() -> Vector3:
	var best: Vector3 = BoilerFactory.PATROL_POINTS[0]
	for point in BoilerFactory.PATROL_POINTS:
		if point.distance_to(level.player_spawn) > best.distance_to(level.player_spawn):
			best = point
	return best + Vector3.UP * 0.1


func host_spawn_loot(item: Dictionary, pos: Vector3, rot := 0.0, frozen := true, velocity := Vector3.ZERO) -> LootItem:
	_loot_counter += 1
	var node: LootItem = _loot_spawner.spawn({
		"name": "L%d" % _loot_counter, "item": item, "pos": pos, "rot": rot, "frozen": frozen,
	})
	if velocity != Vector3.ZERO:
		node.linear_velocity = velocity
	return node


# --- Spawn functions (run on every peer) ---------------------------------------------

func _spawn_player(data: Dictionary) -> Node:
	var player := Player.new()
	player.name = str(data.id)
	player.display_name = data.name
	player.set_multiplayer_authority(data.id)
	player.build_sync()
	var offset := Vector3((data.index % 2) * 1.2 - 0.6, 0.0, (data.index / 2) * 1.2)
	player.position = level.player_spawn + offset
	player.rotation.y = level.player_spawn_yaw
	if data.id == multiplayer.get_unique_id():
		local_player = player
		player.ready.connect(func() -> void:
			player.equip(loadout)
			player.died.connect(_on_local_died)
			local_player_spawned.emit(player), CONNECT_ONE_SHOT)
	return player


func _spawn_monster(data: Dictionary) -> Node:
	var monster: Node3D
	match data.type:
		"mannequin":
			var mannequin := Mannequin.new()
			mannequin.patrol_points.assign(BoilerFactory.PATROL_POINTS)
			mannequin.rng.seed = data.seed
			monster = mannequin
		"moth":
			var moth := Moth.new()
			moth.home = data.pos
			moth.rng.seed = data.seed
			monster = moth
		"mimic":
			var mimic := Mimic.new()
			mimic.disguise = data.disguise
			mimic.rotation.y = data.rot
			mimic.rng.seed = data.seed
			monster = mimic
		_:
			var giant := BoilerColossus.new()
			giant.rng.seed = data.seed
			giant.patrol_points.assign(BoilerFactory.PATROL_POINTS)
			colossus = giant
			giant.ready.connect(func() -> void: colossus_spawned.emit(giant), CONNECT_ONE_SHOT)
			monster = giant
	monster.name = data.name
	monster.position = data.pos
	return monster


func _spawn_loot(data: Dictionary) -> Node:
	var item := LootItem.from_data(data.item)
	item.name = data.name
	item.position = data.pos
	item.rotation.y = data.rot
	# Only the host simulates loot physics; clients just follow the synced transform.
	item.freeze = data.frozen or not _is_host()
	return item


# --- Requests from players -----------------------------------------------------------

func request_pickup(item: LootItem) -> void:
	_to_host(&"_pickup", [String(item.name)])


@rpc("any_peer", "call_local", "reliable")
func _pickup(item_name: String) -> void:
	if not _is_host():
		return
	var item := loot_root.get_node_or_null(item_name) as LootItem
	if item == null or item.is_queued_for_deletion():
		return
	var data := item.to_data()
	var at := item.global_position
	item.queue_free()
	_send_to(_sender(), &"_grant_item", [data, at])


@rpc("authority", "call_local", "reliable")
func _grant_item(data: Dictionary, at: Vector3) -> void:
	if local_player != null and local_player.pickup(data):
		Sfx.play_3d(self, at, "pickup", -6.0)
	elif local_player != null:
		# Couldn't carry it after all (weight changed meanwhile): put it back.
		request_drop(data, at, Vector3.ZERO)


func request_drop(data: Dictionary, pos: Vector3, velocity: Vector3) -> void:
	_to_host(&"_drop", [data, pos, velocity])


@rpc("any_peer", "call_local", "reliable")
func _drop(data: Dictionary, pos: Vector3, velocity: Vector3) -> void:
	if _is_host():
		host_spawn_loot(data, pos, 0.0, false, velocity)


## A player poked, picked up or hit a monster; the host decides what happens.
func request_monster_action(monster: Node, action: String) -> void:
	_to_host(&"_monster_action", [String(monster.name), action])


@rpc("any_peer", "call_local", "reliable")
func _monster_action(monster_name: String, action: String) -> void:
	if not _is_host():
		return
	var monster := monsters_root.get_node_or_null(monster_name)
	if monster == null or monster.is_queued_for_deletion() or not monster.has_method("host_action"):
		return
	monster.host_action(action, players_root.get_node_or_null(str(_sender())) as Player)


@rpc("any_peer", "call_local", "reliable")
func _pull_lever() -> void:
	if _is_host() and not level.lever.is_pulled:
		_lever_pulled.rpc()


@rpc("authority", "call_local", "reliable")
func _lever_pulled() -> void:
	level.lever.play_pull()
	level.restart_boiler()
	if _is_host() and colossus != null:
		colossus.enrage(level.lever.global_position)


@rpc("any_peer", "call_local", "reliable")
func _pry_locker(index: int) -> void:
	if not _is_host() or index < 0 or index >= level.lockers.size():
		return
	var locker: Locker = level.lockers[index]
	if locker.is_open:
		return
	_locker_opened.rpc(index)
	for i in rng.randi_range(1, 2):
		var pos := locker.to_global(Vector3(-0.2 + 0.4 * i, 0.2, 0.6))
		host_spawn_loot(LootTable.roll(rng, Locker.LUCK), pos)


@rpc("authority", "call_local", "reliable")
func _locker_opened(index: int) -> void:
	level.lockers[index].play_open()


## Host tells a player's owner they were caught.
func host_kill(player: Player, cause: String) -> void:
	if not _is_host() or not player.is_active():
		return
	player.remote_die.rpc_id(player.get_multiplayer_authority(), cause)


# --- Local player end of run --------------------------------------------------------

func local_extracted() -> void:
	if finished or local_player == null:
		return
	finished = true
	var taken := local_player.take_all_items()
	var payout := LootTable.payout(taken, rng)
	var gear := local_player.remaining_gear()
	local_player.set_extracted()
	GameState.record_extraction(payout.total, gear)
	Session.instance.report_finished()
	local_finished.emit({"survived": true, "items": payout.items_list, "payout": payout, "cause": "", "lost_gear": []})


func _on_local_died(cause: String) -> void:
	if finished:
		return
	finished = true
	var items := local_player.items.duplicate()
	# Your backpack spills where you fell, for teammates to pick up.
	_to_host(&"_spill_body", [items, local_player.global_position])
	GameState.record_death()
	Session.instance.report_finished()
	local_finished.emit({"survived": false, "items": items, "payout": {}, "cause": cause,
		"lost_gear": local_player.remaining_gear()})


@rpc("any_peer", "call_local", "reliable")
func _spill_body(items: Array, pos: Vector3) -> void:
	if not _is_host():
		return
	for item in items:
		var offset := Vector3(rng.randf_range(-BODY_SCATTER, BODY_SCATTER), 0.6, rng.randf_range(-BODY_SCATTER, BODY_SCATTER))
		host_spawn_loot(item, pos + offset, rng.randf_range(0.0, TAU), false)


# --- Helpers --------------------------------------------------------------------------

func _root(root_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = root_name
	add_child(node)
	return node


func _spawner(root: Node3D, spawn: Callable) -> MultiplayerSpawner:
	var spawner := MultiplayerSpawner.new()
	spawner.name = "Spawner"
	root.add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(root)
	spawner.spawn_function = spawn
	return spawner


func _is_host() -> bool:
	return multiplayer.is_server()


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _to_host(method: StringName, args := []) -> void:
	if _is_host():
		callv(method, args)
	else:
		var call_args := [1, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)


func _send_to(peer: int, method: StringName, args := []) -> void:
	if peer == multiplayer.get_unique_id():
		callv(method, args)
	else:
		var call_args := [peer, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)
