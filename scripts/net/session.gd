class_name Session
extends Node
## Networking for a run. The host is authoritative for monsters, loot and the clock;
## each player owns their own movement. Single player uses Godot's offline peer, so the
## exact same code paths run with nobody else connected.
##
## Flow: host() / join() -> lobby (roster) -> host calls begin_run() -> every peer builds
## the world and reports world_ready -> host spawns players, monsters and loot.
##
## Scavengers come in squads (up to SQUADS of up to SQUAD_SIZE). One squad is co-op; with
## two or more, the squads start apart and can hurt each other (PvPvE).

signal roster_changed()
signal connection_failed(reason: String)
signal disconnected(reason: String)
signal run_requested(seed: int, roster: Dictionary)
signal run_ended(summary: Dictionary)
signal world_ready_all()
signal noise_received(position: Vector3, radius: float, kind: int)
signal time_synced(seconds: float)

const PORT := 24500
const MAX_PLAYERS := 8
const SQUADS := 4
const SQUAD_SIZE := 4
const SQUAD_NAMES := ["紅隊", "藍隊", "黃隊", "綠隊"]
const SQUAD_COLORS := [Color(0.85, 0.3, 0.25), Color(0.3, 0.55, 0.95), Color(0.95, 0.8, 0.25), Color(0.35, 0.8, 0.4)]

static var instance: Session

## peer id -> {"name": String, "squad": int}
var roster := {}
## Host: money the scavengers have extracted so far this run (and per squad).
var extracted_total := 0
var squad_totals := {}
var local_name := "拾荒者"
## True between the host starting a run and everyone finishing it; joins are refused then.
var in_run := false
var _ready_peers := {}
var _run_scavengers := 0
var _finished_peers := {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(func() -> void: connection_failed.emit("連不上主機"))
	multiplayer.server_disconnected.connect(func() -> void:
		leave()
		disconnected.emit("主機離開了"))


func _exit_tree() -> void:
	if instance == self:
		instance = null


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id()


func start_offline() -> void:
	leave()
	roster = {1: _entry(local_name)}
	roster_changed.emit()


func host(port := PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	roster = {1: _entry(local_name)}
	roster_changed.emit()
	return OK


func join(address: String, port := PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = {}
	in_run = false
	extracted_total = 0
	squad_totals.clear()
	_ready_peers.clear()
	_finished_peers.clear()


## Everyone in the room goes in: there are only scavengers (pure PvPvE).
func scavenger_ids() -> Array:
	return roster.keys()


func squad_of(id: int) -> int:
	return roster.get(id, {}).get("squad", 0)


## The squads that have scavengers in them, in order.
func active_squads() -> Array:
	var squads := []
	for id in scavenger_ids():
		if not squad_of(id) in squads:
			squads.append(squad_of(id))
	squads.sort()
	return squads


func is_pvp() -> bool:
	return active_squads().size() > 1


func squad_size(squad: int) -> int:
	return scavenger_ids().filter(func(id) -> bool: return squad_of(id) == squad).size()


## Move to the next squad that has room.
func request_next_squad() -> void:
	var current := squad_of(local_id())
	for step in range(1, SQUADS):
		var squad := (current + step) % SQUADS
		if squad_size(squad) < SQUAD_SIZE:
			_to_host(&"_set_squad", [squad])
			return


@rpc("any_peer", "call_local", "reliable")
func _set_squad(squad: int) -> void:
	var id := _sender()
	if not is_host() or in_run or not roster.has(id) or squad < 0 or squad >= SQUADS:
		return
	if squad_size(squad) >= SQUAD_SIZE:
		return
	roster[id].squad = squad
	_push_roster()


## Host only: start a run for everyone in the lobby.
func begin_run() -> void:
	if not is_host() or scavenger_ids().is_empty():
		return
	_ready_peers.clear()
	_finished_peers.clear()
	extracted_total = 0
	squad_totals.clear()
	var seed := randi()
	_start_run.rpc(seed, roster)


@rpc("authority", "call_local", "reliable")
func _start_run(seed: int, new_roster: Dictionary) -> void:
	roster = new_roster
	in_run = true
	_run_scavengers = scavenger_ids().size()
	run_requested.emit(seed, roster)


## Every peer calls this once its copy of the world exists.
func report_world_ready() -> void:
	_to_host(&"_world_ready")


@rpc("any_peer", "call_local", "reliable")
func _world_ready() -> void:
	if not is_host():
		return
	_ready_peers[_sender()] = true
	if _ready_peers.size() >= roster.size():
		world_ready_all.emit()


## Every scavenger calls this when its player has extracted (with what it earned) or died.
func report_finished(earned := 0) -> void:
	_to_host(&"_player_finished", [earned])


@rpc("any_peer", "call_local", "reliable")
func _player_finished(earned: int) -> void:
	if not is_host() or _finished_peers.has(_sender()):
		return
	_finished_peers[_sender()] = true
	extracted_total += maxi(earned, 0)
	var squad := squad_of(_sender())
	squad_totals[squad] = squad_totals.get(squad, 0) + maxi(earned, 0)
	_check_all_finished()


func _check_all_finished() -> void:
	if not in_run:
		return
	for id in scavenger_ids():
		if not _finished_peers.has(id):
			return
	_end_run.rpc(summary())


## The run's outcome so far: what got out, in all and per squad.
func summary() -> Dictionary:
	return {
		"extracted": extracted_total, "scavengers": _run_scavengers,
		"squads": active_squads(), "squad_totals": squad_totals.duplicate(),
	}


@rpc("authority", "call_local", "reliable")
func _end_run(result: Dictionary) -> void:
	in_run = false
	run_ended.emit(result)


## Gameplay noise from a client is forwarded to the host, where monsters live.
func send_noise(position: Vector3, radius: float, kind: int) -> void:
	_to_host(&"_noise", [position, radius, kind])


@rpc("any_peer", "call_remote", "unreliable")
func _noise(position: Vector3, radius: float, kind: int) -> void:
	if is_host():
		noise_received.emit(position, radius, kind)


func broadcast_time(seconds: float) -> void:
	if is_host() and is_online():
		_sync_time.rpc(seconds)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_time(seconds: float) -> void:
	time_synced.emit(seconds)


func _on_peer_connected(id: int) -> void:
	if is_host() and (in_run or roster.size() >= MAX_PLAYERS):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if is_host():
		# The newcomer introduces itself; until then it shows as a placeholder.
		var squad := _open_squad()
		roster[id] = _entry("拾荒者 %d" % id)
		roster[id].squad = squad
		_push_roster()


func _on_peer_disconnected(id: int) -> void:
	roster.erase(id)
	_ready_peers.erase(id)
	if is_host():
		_push_roster()
		_check_all_finished()
	roster_changed.emit()


func _on_connected_to_server() -> void:
	_introduce.rpc_id(1, local_name)


@rpc("any_peer", "call_remote", "reliable")
func _introduce(player_name: String) -> void:
	if not is_host():
		return
	var id := _sender()
	if roster.size() > MAX_PLAYERS:
		return
	var squad: int = roster.get(id, {}).get("squad", _open_squad())
	roster[id] = _entry(player_name.substr(0, 16))
	roster[id].squad = squad
	_push_roster()


func _push_roster() -> void:
	_set_roster.rpc(roster)


@rpc("authority", "call_local", "reliable")
func _set_roster(new_roster: Dictionary) -> void:
	roster = new_roster
	roster_changed.emit()


func _entry(player_name: String) -> Dictionary:
	return {"name": player_name, "squad": 0}


## Newcomers join the host's squad until it is full.
func _open_squad() -> int:
	for squad in SQUADS:
		if squad_size(squad) < SQUAD_SIZE:
			return squad
	return 0


func _to_host(method: StringName, args := []) -> void:
	if is_host():
		callv(method, args)
	else:
		var call_args := [1, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else local_id()
