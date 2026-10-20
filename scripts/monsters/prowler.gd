class_name Prowler
extends CharacterBody3D
## Shared body for the walking roster-driven monsters (hound pack, web weaver, shield
## knight, shadow stalker): collider and navigation setup, host-side steering, and the
## two ways a monster reaches a player that a plain remote_damage can't: holding them
## (snare / slow / drag, run on the player's own machine) and sounds every peer hears.

var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _repath := 0.0


## Collider, nav agent and the model root. Call from _ready() before building the model.
func setup_body(radius: float, height: float, agent_radius := -1.0) -> void:
	add_to_group("monsters")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	collider.shape = capsule
	collider.position.y = capsule.height / 2.0
	add_child(collider)
	_agent = NavigationAgent3D.new()
	_agent.radius = radius if agent_radius < 0.0 else agent_radius
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0


## Steer toward `goal` along the navmesh (straight at it when close or with no navmesh).
## Returns the flat direction it is moving in.
func steer(goal: Vector3, speed: float, delta: float, turn := 8.0, direct_within := 3.0) -> Vector3:
	_repath -= delta
	if _repath <= 0.0 or _agent.target_position.distance_to(goal) > 1.5:
		_agent.target_position = goal
		_repath = 0.4
	var next := goal
	if _nav_ready() and global_position.distance_to(goal) > direct_within and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() < 0.05 or speed <= 0.0:
		halt()
		return Vector3.ZERO
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	face_direction(direction, turn, delta)
	return direction


func halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func face_point(point: Vector3, turn: float, delta: float) -> void:
	var to := point - global_position
	to.y = 0.0
	face_direction(to, turn, delta)


func face_direction(direction: Vector3, turn: float, delta: float) -> void:
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(turn * delta, 1.0))


func forward() -> Vector3:
	return -global_basis.z


func random_patrol_point() -> Vector3:
	if patrol_points.is_empty():
		return global_position
	return patrol_points[rng.randi_range(0, patrol_points.size() - 1)]


func sees(player: Player, eye_height: float, max_range: float) -> bool:
	var eye := global_position + Vector3.UP * eye_height
	var chest := player.global_position + Vector3.UP
	return player.is_active() and eye.distance_to(chest) < max_range \
		and MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()])


## Fraction of health left (1 before the first hit).
func health_ratio() -> float:
	var top: float = get_meta("max_hp", 0.0)
	return 1.0 if top <= 0.0 else clampf(float(get_meta("hp", top)) / top, 0.0, 1.0)


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


# --- Reaching players -----------------------------------------------------------------

## Host: hold or move a player on their own machine. effect keys: snare, slow,
## slow_factor, drag (a Vector3 the body is moved by), push (velocity), shake, note.
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
	if effect.has("release"):
		player.snared = 0.0
	if effect.has("slow"):
		player.trap_slow = maxf(player.trap_slow, effect.slow)
		player.trap_slow_factor = effect.get("slow_factor", 0.5)
	if effect.has("drag"):
		player.move_and_collide(effect.drag)
	if effect.has("push"):
		player.velocity += effect.push
	if effect.has("shake"):
		player.add_shake(effect.shake)
	if effect.get("note", "") != "" and not player.is_dead:
		player.message.emit(effect.note)


## Host: a sound every peer hears at this monster (or at `at`).
func host_sound(sound_name: String, volume_db := 0.0, max_distance := 25.0, pitch := 1.0, at := Vector3.INF) -> void:
	_sound.rpc(sound_name, volume_db, max_distance, pitch, global_position + Vector3.UP if at == Vector3.INF else at)


@rpc("authority", "call_local", "unreliable")
func _sound(sound_name: String, volume_db: float, max_distance: float, pitch: float, at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, sound_name, volume_db, max_distance, pitch)
