class_name BulkyCarry
extends Node
## Hauling a bulky item (LootTable tag "bulky"): a big physical thing carried in both
## hands instead of the backpack. Lives as a child "Carry" of the LootItem on every peer.
##
## The host owns who is holding it (`holders`, peer ids, replicated). While held the item
## is frozen and every peer places it in front of its holder (or between the two holders)
## from the players' replicated transforms, so the carrier sees it rock-steady in their
## hands. Let go, it is a RigidBody again on the host: it drops, thuds and wakes the place.
## Two players holding the same item each feel only CO_CARRY_SHARE of its weight
## (see Player.bulky_load).

const MAX_HOLDERS := 2
## How close you must be to grab it (host check, a little generous for lag).
const GRAB_REACH := 3.2
## Two carriers further apart than this lose their grip (the second one lets go).
const CO_CARRY_BREAK := 3.4
## Items taller than this are carried tipped forward like a battering ram.
const TALL := 1.3

## Replicated from the host: the peers holding this item, first grabber first.
var holders := PackedInt32Array():
	set(value):
		var before := holders
		holders = value
		_holders_changed(before)

var item: LootItem


func _ready() -> void:
	item = get_parent() as LootItem
	var sync := MultiplayerSynchronizer.new()
	sync.name = "CarrySync"
	sync.root_path = NodePath("..")
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:holders")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	add_child(sync)


func _exit_tree() -> void:
	# Claimed at extraction, stolen or freed: nobody is holding it any more.
	for id in holders:
		var player := _player(id)
		if player != null and player.held_bulky == item:
			player.held_bulky = null


func is_held() -> bool:
	return not holders.is_empty()


func held_by(peer: int) -> bool:
	return peer in holders


# --- Every peer: keep it in the carriers' hands ---------------------------------------

func _process(_delta: float) -> void:
	_follow()


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server() and is_held():
		_host_check()
	_follow()


func _follow() -> void:
	if holders.is_empty():
		return
	var carriers: Array[Player] = []
	for id in holders:
		var player := _player(id)
		if player != null:
			carriers.append(player)
	if carriers.is_empty():
		return
	item.global_transform = hold_transform(carriers, item.data.size)


## Where an item of `size` sits in these players' hands.
static func hold_transform(carriers: Array[Player], size: Vector3) -> Transform3D:
	var tall := size.y > TALL
	var lift := 0.8 if tall else maxf(0.62, size.y / 2.0 + 0.15)
	if carriers.size() == 1:
		var player := carriers[0]
		var yaw := Basis(Vector3.UP, player.global_rotation.y)
		var reach := 0.45 + (size.y / 2.0 if tall else size.z / 2.0) + 0.15
		var basis := yaw * Basis(Vector3.RIGHT, deg_to_rad(-80.0)) if tall else yaw
		var pos := player.global_position + yaw * Vector3(0.0, lift, -reach)
		return Transform3D(basis, pos)
	# Two carriers: it hangs between them, its long side spanning the gap.
	var a := carriers[0].global_position
	var b := carriers[1].global_position
	var span := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if span.length() < 0.01:
		span = carriers[0].global_basis.x
	span = span.normalized()
	var basis := Basis(span, Vector3.UP, span.cross(Vector3.UP))
	if tall:
		basis = Basis(Vector3.UP, -span, span.cross(Vector3.UP)).orthonormalized()
	elif size.z > size.x:
		basis = basis * Basis(Vector3.UP, PI / 2.0)
	var mid := (a + b) / 2.0
	return Transform3D(basis.orthonormalized(), Vector3(mid.x, minf(a.y, b.y) + lift, mid.z))


func _holders_changed(before: PackedInt32Array) -> void:
	if item == null:
		item = get_parent() as LootItem
	for id in before:
		if not id in holders:
			var player := _player(id)
			if player != null and player.held_bulky == item:
				player.held_bulky = null
	for id in holders:
		var player := _player(id)
		if player != null:
			player.held_bulky = item


func _player(id: int) -> Player:
	if Run.instance == null or Run.instance.players_root == null:
		return null
	return Run.instance.players_root.get_node_or_null(str(id)) as Player


# --- Requests (any peer) -> host ---------------------------------------------------------

func request_grab() -> void:
	_to_host(&"_grab")


func request_release(push := Vector3.ZERO) -> void:
	_to_host(&"_release", [push])


## Extraction: the extracting player takes it out of the world (it is paid on their side).
func request_claim() -> void:
	_to_host(&"_claim")


@rpc("any_peer", "call_local", "reliable")
func _grab() -> void:
	if multiplayer.is_server():
		host_grab(_sender())


@rpc("any_peer", "call_local", "reliable")
func _release(push: Vector3) -> void:
	if multiplayer.is_server():
		host_release(_sender(), push)


@rpc("any_peer", "call_local", "reliable")
func _claim() -> void:
	if multiplayer.is_server() and not item.is_queued_for_deletion():
		holders = PackedInt32Array()
		item.queue_free()


# --- Host -----------------------------------------------------------------------------

## Host: `peer` takes hold (alone, or as the second carrier). False when refused.
func host_grab(peer: int) -> bool:
	if item.is_queued_for_deletion() or peer in holders or holders.size() >= MAX_HOLDERS:
		return false
	var player := _player(peer)
	if player == null or not player.is_active():
		return false
	if player.held_bulky != null and player.held_bulky != item:
		return false
	var reach := item.global_position.distance_to(player.global_position + Vector3.UP * 0.9)
	if reach > GRAB_REACH + maxf(item.data.size.x, maxf(item.data.size.y, item.data.size.z)) / 2.0:
		return false
	var list := holders.duplicate()
	list.append(peer)
	item.freeze = true
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	holders = list
	Sfx.play_3d(item.get_parent(), item.global_position, "clank", -6.0, 18.0, clampf(1.6 - item.weight / 100.0, 0.5, 1.4))
	GameNoise.emit(item.get_tree(), item.global_position, 6.0, GameNoise.Kind.TOOL)
	return true


## Host: `peer` lets go. Once nobody holds it, it falls, and that is loud.
func host_release(peer: int, push := Vector3.ZERO) -> void:
	if not peer in holders:
		return
	var list := holders.duplicate()
	list.remove_at(list.find(peer))
	holders = list
	if not list.is_empty():
		return
	# Don't let go of it inside a wall: pull it back towards the carrier if it is.
	var player := _player(peer)
	if player != null:
		var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, item.global_position, Layers.WORLD)
		var hit := item.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			item.global_position = hit.position + hit.normal * maxf(item.data.size.x, item.data.size.z) * 0.5
	item.freeze = false
	item.linear_velocity = push
	host_thud(1.0)


## Host: the bang of a heavy thing hitting the floor. Scales with weight; wakes the ruin.
func host_thud(strength: float) -> void:
	var at := item.global_position
	var weight := item.weight
	Sfx.play_3d(item.get_parent(), at, "thump", clampf(-10.0 + weight * 0.12, -10.0, 4.0), 40.0, clampf(1.3 - weight / 120.0, 0.45, 1.2))
	Sfx.play_3d(item.get_parent(), at, "clank", -8.0, 30.0, randf_range(0.5, 0.8))
	GameNoise.emit(item.get_tree(), at, clampf((8.0 + weight * 0.15) * strength, 6.0, 28.0), GameNoise.Kind.IMPACT)
	if Run.instance != null:
		var awakening = Run.instance.get("awakening")
		if awakening != null and awakening.has_method("add"):
			awakening.add(clampf(weight / 25.0 * strength, 0.5, 5.0), at)


func _host_check() -> void:
	var list := holders.duplicate()
	var changed := false
	for i in range(list.size() - 1, -1, -1):
		var player := _player(list[i])
		if player == null or not player.is_active():
			list.remove_at(i)
			changed = true
	if list.size() == 2:
		var a := _player(list[0])
		var b := _player(list[1])
		if a.global_position.distance_to(b.global_position) > CO_CARRY_BREAK:
			list.remove_at(1)
			changed = true
	if not changed:
		return
	if list.is_empty():
		holders = PackedInt32Array([holders[0]])
		host_release(holders[0])
	else:
		holders = list


func _to_host(method: StringName, args := []) -> void:
	if multiplayer.is_server():
		callv(method, args)
	else:
		var call_args := [1, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
