class_name Trap
extends Node3D
## Base of every trap (see Traps.create). A trap is built the same way on every peer
## from the map seed; only the host decides when it goes off. The host broadcasts state
## changes with _state (visuals and sounds on every peer) and sends the effect on a
## player (damage, snare, slow, shove) to that player's owner with _affect.
## Monsters ignore traps; the noise a trap makes is what draws them in.

var kind := ""
var map: GameMap
var params := {}
var rng := RandomNumberGenerator.new()
## Subclass-defined; changed only through host_set_state() so every peer agrees.
var state := 0
## Host: per-player cooldowns (player name -> seconds left) for repeating hazards.
var _cooldowns := {}

static var _mesh_cache := {}


## The bit of a trap the player's interact ray can hit (E to disarm, close, cut).
## It sits on the loot layer: the ray sees it, bodies walk straight through it.
class Handle extends StaticBody3D:
	var trap: Trap

	func get_prompt(player: Player = null) -> String:
		return trap.get_prompt(player)

	func interact(player: Player) -> void:
		trap.interact(player)


func _ready() -> void:
	build()


## Subclasses build their meshes here (LowPoly parts, under 300 triangles).
func build() -> void:
	pass


func _physics_process(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			_cooldowns.erase(key)
	if multiplayer.is_server():
		host_tick(delta)
	local_tick(delta)


## Host only: watch the players and set the trap off.
func host_tick(_delta: float) -> void:
	pass


## Every peer: idle animation and tells.
func local_tick(_delta: float) -> void:
	pass


## Every peer: show a state the host set.
func apply_state(_new_state: int, _arg: int) -> void:
	pass


func get_prompt(_player: Player = null) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Host: a player asked to do something to this trap (disarm, close).
func host_request(_action: String, _player: Player) -> void:
	pass


# --- Shared helpers ------------------------------------------------------------------

## Scavengers still in the run (host: remote positions are replicated).
func players() -> Array[Player]:
	return MonsterKit.active_players(get_tree())


## True if the player's feet are inside a box around the trap (half extents in the
## trap's own space) and no higher than `up` above it (jumping over a wire clears it).
func feet_in(player: Player, half: Vector2, up := 0.5) -> bool:
	var local := to_local(player.global_position)
	return absf(local.x) <= half.x and absf(local.z) <= half.y and local.y > -0.6 and local.y < up


func feet_within(player: Player, radius: float, up := 0.5) -> bool:
	var local := to_local(player.global_position)
	return Vector2(local.x, local.z).length() <= radius and local.y > -0.6 and local.y < up


## Host: true once per `seconds` per player (and starts the wait).
func host_cooldown(player: Player, seconds: float) -> bool:
	var key := String(player.name)
	if _cooldowns.has(key):
		return false
	_cooldowns[key] = seconds
	return true


func host_set_state(new_state: int, arg := 0) -> void:
	if multiplayer.is_server():
		_state.rpc(new_state, arg)


@rpc("authority", "call_local", "reliable")
func _state(new_state: int, arg: int) -> void:
	state = new_state
	apply_state(new_state, arg)


func host_noise(radius: float, kind_id := GameNoise.Kind.IMPACT, at := Vector3.INF) -> void:
	GameNoise.emit_local(get_tree(), global_position if at == Vector3.INF else at, radius, kind_id)


## Host -> the player's owner. effect keys: damage, cause, note, snare (s), slow (s),
## slow_factor, push (velocity), shake.
func host_affect(player: Player, effect: Dictionary) -> void:
	var owner_id := player.get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		_affect(String(player.name), effect)
	else:
		_affect.rpc_id(owner_id, String(player.name), effect)


@rpc("any_peer", "call_local", "reliable")
func _affect(player_name: String, effect: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	var player: Player = null
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and String(node.name) == player_name and node.is_multiplayer_authority():
			player = node
	if player == null or not player.is_active():
		return
	if effect.has("snare"):
		player.snared = maxf(player.snared, effect.snare)
	if effect.has("slow"):
		player.trap_slow = maxf(player.trap_slow, effect.slow)
		player.trap_slow_factor = effect.get("slow_factor", 0.5)
	if effect.has("push"):
		player.velocity += effect.push
	if effect.has("shake"):
		player.add_shake(effect.shake)
	if effect.get("damage", 0.0) > 0.0:
		player.take_damage(effect.damage, effect.get("cause", "死於陷阱"))
	if effect.get("note", "") != "" and not player.is_dead:
		player.message.emit(effect.note)


## Client -> host: do `action` to this trap (the host checks it still makes sense).
func request(action: String) -> void:
	if multiplayer.is_server():
		_request(action)
	else:
		_request.rpc_id(1, action)


@rpc("any_peer", "call_local", "reliable")
func _request(action: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.get_multiplayer_authority() == sender and node.is_active():
			if node.global_position.distance_to(global_position) < 4.0:
				host_request(action, node)
			return


func add_handle(size: Vector3, offset: Vector3) -> Handle:
	var handle := Handle.new()
	handle.name = "Handle"
	handle.trap = self
	handle.collision_layer = Layers.LOOT
	handle.collision_mask = 0
	handle.position = offset
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	handle.add_child(collider)
	add_child(handle)
	return handle


## A mesh node from [mesh, transform] parts with the PS1 material (mesh UVs).
## `key` caches the merged mesh, for parts that don't depend on params or the seed.
func part(parts: Array, texture: String, tint: Color, emission := Color.BLACK, parent: Node3D = null,
		key := "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if key != "" and _mesh_cache.has(key):
		node.mesh = _mesh_cache[key]
	else:
		node.mesh = LootShapes.with_uvs(LowPoly.merge(parts), 1.0)
		if key != "":
			_mesh_cache[key] = node.mesh
	node.material_override = PS1Materials.get_material(texture, tint, true, Vector2.ONE, emission)
	(parent if parent != null else self).add_child(node)
	return node


## A cheap box part (12 triangles, square edges): [mesh, transform] for part().
static func slab(size: Vector3, pos: Vector3, rot_deg := Vector3.ZERO) -> Array:
	var square := Basis(Vector3.UP, PI / 4.0)
	var basis := Basis.from_euler(rot_deg * PI / 180.0) * Basis.from_scale(size) * square
	return [LowPoly.prism(4, 0.7071068, 0.7071068, 1.0), Transform3D(basis, pos)]


## A one-shot puff of low-poly bits (steam, sparks, splinters, splashes). Cosmetic.
func burst(at: Vector3, color: Color, amount := 12, speed := 3.0, spread := 40.0, gravity := -6.0,
		lifetime := 0.6, size := 0.05, glow := false) -> void:
	var fx := CPUParticles3D.new()
	fx.one_shot = true
	fx.amount = amount
	fx.lifetime = lifetime
	fx.explosiveness = 0.85
	fx.direction = Vector3.UP
	fx.spread = spread
	fx.initial_velocity_min = speed * 0.5
	fx.initial_velocity_max = speed
	fx.gravity = Vector3(0, gravity, 0)
	fx.mesh = LowPoly.blob(size, Vector3.ONE, 0)
	fx.material_override = PS1Materials.get_material("concrete", color, true, Vector2.ONE, color if glow else Color.BLACK)
	add_child(fx)
	fx.position = to_local(at)
	fx.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(fx.queue_free)


func sound(sound_name: String, volume_db := 0.0, max_distance := 30.0, pitch := 1.0, offset := Vector3.ZERO) -> void:
	Sfx.play_3d(self, to_global(offset), sound_name, volume_db, max_distance, pitch)
