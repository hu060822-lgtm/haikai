class_name Session
extends Node
## Networking for a run. The host is authoritative for monsters, loot and the clock;
## each player owns their own movement. Single player uses Godot's offline peer, so the
## exact same code paths run with nobody else connected.
##
## Flow: host() / join() -> lobby (roster) -> host calls begin_run() -> every peer builds
## the world and reports world_ready -> host spawns players, monsters and loot.

signal roster_changed()
signal connection_failed(reason: String)
signal disconnected(reason: String)
signal run_requested(seed: int, roster: Dictionary)
signal run_ended()
signal world_ready_all()
signal noise_received(position: Vector3, radius: float, kind: int)
signal time_synced(seconds: float)

const PORT := 24500
const MAX_PLAYERS := 4

static var instance: Session

## peer id -> {"name": String}
var roster := {}
var local_name := "拾荒者"
## True between the host starting a run and everyone finishing it; joins are refused then.
var in_run := false
var _ready_peers := {}
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
	roster = {1: {"name": local_name}}
	roster_changed.emit()


func host(port := PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	roster = {1: {"name": local_name}}
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
	_ready_peers.clear()
	_finished_peers.clear()


## Host only: start a run for everyone in the lobby.
func begin_run() -> void:
	if not is_host():
		return
	_ready_peers.clear()
	_finished_peers.clear()
	var seed := randi()
	_start_run.rpc(seed, roster)


@rpc("authority", "call_local", "reliable")
func _start_run(seed: int, new_roster: Dictionary) -> void:
	roster = new_roster
	in_run = true
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


## Every peer calls this when its player has extracted or died.
func report_finished() -> void:
	_to_host(&"_player_finished")


@rpc("any_peer", "call_local", "reliable")
func _player_finished() -> void:
	if not is_host():
		return
	_finished_peers[_sender()] = true
	_check_all_finished()


func _check_all_finished() -> void:
	if not in_run:
		return
	for id in roster:
		if not _finished_peers.has(id):
			return
	_end_run.rpc()


@rpc("authority", "call_local", "reliable")
func _end_run() -> void:
	in_run = false
	run_ended.emit()


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
		roster[id] = {"name": "拾荒者 %d" % id}
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
	roster[id] = {"name": player_name.substr(0, 16)}
	_push_roster()


func _push_roster() -> void:
	_set_roster.rpc(roster)


@rpc("authority", "call_local", "reliable")
func _set_roster(new_roster: Dictionary) -> void:
	roster = new_roster
	roster_changed.emit()


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
