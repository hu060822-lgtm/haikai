class_name BoilerColossus
extends CharacterBody3D
## 鍋爐巨像: a two-storey steam machine. Dominates by SIZE: kills on contact,
## shakes the floor, outpaces a walking player.
## Weaknesses players can learn:
##   - Too big for ducts, small rooms with narrow doors, catwalks and pipes.
##   - Must vent every ~40 s: for 5 s it stands still, blind and deaf.
##   - Sees far only if you are lit; with the lantern off it barely sees you.

signal state_changed(state: State)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, VENT }

const HEIGHT := 4.5
const RADIUS := 1.2
const PATROL_SPEED := 2.0
const INVESTIGATE_SPEED := 3.2
const CHASE_SPEED := 4.6
const ENRAGED_MULT := 1.15
const SIGHT_RANGE_LIT := 26.0
const SIGHT_RANGE_DARK := 8.0
const SIGHT_HALF_ANGLE_DEG := 65.0
const NEAR_SENSE := 3.0  # feels anyone this close, any direction
const KILL_DISTANCE := 2.0
const KILL_HEIGHT := 2.6
const LOSE_SIGHT_TIME := 5.0
const SEARCH_TIME := 6.0
const VENT_INTERVAL_MIN := 35.0
const VENT_INTERVAL_MAX := 45.0
const VENT_DURATION := 5.0
const UNREACHABLE_GIVE_UP := 10.0
const WHISTLE_COOLDOWN := 10.0

var state := State.PATROL
var enraged := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _goal := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _since_seen := 999.0
var _state_time := 0.0
var _vent_timer := 40.0
var _step_timer := 0.0
var _walk_phase := 0.0
var _unreachable_time := 0.0
var _whistle_cooldown := 0.0
var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _eye_light: OmniLight3D
var _eye_material: ShaderMaterial
var _steam: CPUParticles3D


func _ready() -> void:
	add_to_group("listeners")
	add_to_group("monsters")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	floor_max_angle = deg_to_rad(40.0)

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collider.shape = capsule
	collider.position.y = HEIGHT / 2.0
	add_child(collider)

	_agent = NavigationAgent3D.new()
	_agent.radius = RADIUS
	_agent.height = HEIGHT
	_agent.path_desired_distance = 1.0
	_agent.target_desired_distance = 1.5
	_agent.path_max_distance = 4.0
	add_child(_agent)

	_build_model()
	_vent_timer = rng.randf_range(VENT_INTERVAL_MIN, VENT_INTERVAL_MAX)


## Called by the level when the boiler restarts: everything is awake now.
func enrage(noise_position: Vector3) -> void:
	enraged = true
	_eye_material.set_shader_parameter("emission_color", Color(1.0, 0.15, 0.05))
	_eye_light.light_color = Color(1.0, 0.2, 0.05)
	if state != State.CHASE:
		_investigate(noise_position)


func hear(position: Vector3, radius: float, _kind: int) -> void:
	if state == State.VENT:
		return
	if global_position.distance_to(position) > radius:
		return
	if state == State.CHASE:
		if _since_seen > 0.5:
			_last_seen = position
		return
	_investigate(position)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_whistle_cooldown = maxf(_whistle_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if state != State.VENT:
		_vent_timer -= delta
		if _vent_timer <= 0.0:
			_enter(State.VENT)

	var player := _find_player()
	if player != null and state != State.VENT and _can_sense(player):
		_last_seen = player.global_position
		_since_seen = 0.0
		if state != State.CHASE:
			_enter(State.CHASE)
	else:
		_since_seen += delta

	var speed := 0.0
	match state:
		State.PATROL:
			speed = PATROL_SPEED
			if _agent.is_navigation_finished() or _state_time > 25.0:
				_pick_patrol_point()
		State.INVESTIGATE:
			speed = INVESTIGATE_SPEED
			if _agent.is_navigation_finished() and _state_time > 1.0:
				_enter(State.SEARCH)
		State.CHASE:
			speed = CHASE_SPEED
			_set_goal(_last_seen)
			if _since_seen > LOSE_SIGHT_TIME:
				_enter(State.SEARCH)
			elif _is_goal_unreachable():
				_unreachable_time += delta
				if _unreachable_time > UNREACHABLE_GIVE_UP:
					_play_whistle()
					_enter(State.PATROL)
			else:
				_unreachable_time = 0.0
		State.SEARCH:
			rotate_y(delta * 0.8)
			if _state_time > SEARCH_TIME:
				_enter(State.PATROL)
		State.VENT:
			if _state_time > VENT_DURATION:
				_vent_timer = rng.randf_range(VENT_INTERVAL_MIN, VENT_INTERVAL_MAX)
				_enter(State.SEARCH if _since_seen < 10.0 else State.PATROL)

	if enraged:
		speed *= ENRAGED_MULT
	_move(speed, delta, player)
	_check_kill(player)
	_animate(delta)


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_unreachable_time = 0.0
	match new_state:
		State.CHASE:
			_play_whistle()
		State.VENT:
			_steam.emitting = true
			_eye_light.light_energy = 0.2
			Sfx.play_3d(get_parent(), global_position + Vector3.UP * HEIGHT, "hiss", 4.0, 50.0)
		State.PATROL:
			_pick_patrol_point()
	if new_state != State.VENT:
		_steam.emitting = false
		_eye_light.light_energy = 1.5
	state_changed.emit(new_state)


func _investigate(position: Vector3) -> void:
	_set_goal(position)
	_enter(State.INVESTIGATE)


func _pick_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	_set_goal(patrol_points[rng.randi_range(0, patrol_points.size() - 1)])
	_state_time = 0.0


func _set_goal(position: Vector3) -> void:
	_goal = position
	_agent.target_position = position


func _is_goal_unreachable() -> bool:
	if not _agent.is_navigation_finished():
		return false
	var flat := Vector2(_goal.x - global_position.x, _goal.z - global_position.z)
	return flat.length() > 2.5 or absf(_goal.y - global_position.y) > KILL_HEIGHT


func _move(speed: float, delta: float, player: Player) -> void:
	var direction := Vector3.ZERO
	if speed > 0.0 and state != State.VENT and _nav_ready():
		var next := _agent.get_next_path_position()
		# Close to a visible player on the same level, go straight at them.
		if state == State.CHASE and player != null and _since_seen == 0.0 \
				and global_position.distance_to(player.global_position) < 4.0 \
				and absf(player.global_position.y - global_position.y) < 1.0:
			next = player.global_position
		direction = next - global_position
		direction.y = 0.0
		if direction.length() > 0.1:
			direction = direction.normalized()
		else:
			direction = Vector3.ZERO
	velocity.x = lerpf(velocity.x, direction.x * speed, 6.0 * delta)
	velocity.z = lerpf(velocity.z, direction.z * speed, 6.0 * delta)
	if direction != Vector3.ZERO:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)
	move_and_slide()


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _find_player() -> Player:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and not node.is_dead:
			return node
	return null


func _can_sense(player: Player) -> bool:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance < NEAR_SENSE and absf(to_player.y) < KILL_HEIGHT:
		return true
	var sight := SIGHT_RANGE_LIT if player.lantern_on else SIGHT_RANGE_DARK
	if player.is_crouching and not player.lantern_on:
		sight *= 0.6
	if distance > sight:
		return false
	var forward := -global_basis.z
	var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()
	if forward.dot(flat) < cos(deg_to_rad(SIGHT_HALF_ANGLE_DEG)):
		return false
	var eye := global_position + Vector3.UP * (HEIGHT - 0.5)
	var query := PhysicsRayQueryParameters3D.create(eye, player.head_position())
	query.collision_mask = Layers.WORLD | Layers.WALKWAY
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


func _check_kill(player: Player) -> void:
	if player == null or state == State.VENT:
		return
	var offset := player.global_position - global_position
	if absf(offset.y) > KILL_HEIGHT:
		return
	if Vector2(offset.x, offset.z).length() < KILL_DISTANCE:
		player.die("被鍋爐巨像抓住了")


func _play_whistle() -> void:
	if _whistle_cooldown > 0.0:
		return
	_whistle_cooldown = WHISTLE_COOLDOWN
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * HEIGHT, "whistle", 6.0, 80.0, rng.randf_range(0.8, 0.95))


func _animate(delta: float) -> void:
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	_walk_phase += delta * flat_speed * 1.4
	var swing := sin(_walk_phase) * clampf(flat_speed / 3.0, 0.0, 1.0) * 0.55
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	var reach := -0.9 if state == State.CHASE else 0.0
	_arms[0].rotation.x = lerpf(_arms[0].rotation.x, -swing * 0.6 + reach, 6.0 * delta)
	_arms[1].rotation.x = lerpf(_arms[1].rotation.x, swing * 0.6 + reach, 6.0 * delta)
	_model.position.y = absf(sin(_walk_phase)) * 0.08 * clampf(flat_speed, 0.0, 1.0)
	if flat_speed > 0.5:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = PI / (1.4 * maxf(flat_speed, 0.5))
			_footstep()


func _footstep() -> void:
	Sfx.play_3d(get_parent(), global_position, "thump", 4.0, 70.0, rng.randf_range(0.85, 1.05))
	for node in get_tree().get_nodes_in_group("player"):
		var distance: float = node.global_position.distance_to(global_position)
		node.add_shake(clampf(1.0 - distance / 30.0, 0.0, 1.0) * 0.7)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var iron := PS1Materials.get_material("rust_metal", Color(0.85, 0.8, 0.75), true)
	var dark := PS1Materials.get_material("rust_metal", Color(0.45, 0.4, 0.38), true)
	var copper := PS1Materials.get_material("pipe", Color.WHITE, true)

	# Boiler torso and furnace head.
	_cylinder(_model, 0.95, 2.0, Vector3(0, 2.6, 0), iron)
	_box(_model, Vector3(2.1, 0.3, 1.4), Vector3(0, 3.55, 0), dark)
	_box(_model, Vector3(1.0, 0.8, 0.9), Vector3(0, 4.05, 0), dark)
	_cylinder(_model, 0.18, 0.9, Vector3(0.25, 4.6, 0.3), copper)
	_cylinder(_model, 0.25, 1.6, Vector3(0, 2.6, 0.95), copper)

	_eye_material = ShaderMaterial.new()
	_eye_material.shader = PS1Materials.SHADER
	_eye_material.set_shader_parameter("albedo_texture", load("res://textures/brass.png"))
	_eye_material.set_shader_parameter("albedo_color", Color(0.2, 0.1, 0.0))
	_eye_material.set_shader_parameter("use_mesh_uv", true)
	_eye_material.set_shader_parameter("emission_color", Color(1.0, 0.45, 0.05))
	_box(_model, Vector3(0.7, 0.12, 0.05), Vector3(0, 4.1, -0.47), _eye_material)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(1.0, 0.5, 0.15)
	_eye_light.light_energy = 1.5
	_eye_light.omni_range = 7.0
	_eye_light.position = Vector3(0, 4.1, -0.9)
	_model.add_child(_eye_light)

	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.5 * side, 1.65, 0)
		_model.add_child(hip)
		_box(hip, Vector3(0.5, 1.65, 0.5), Vector3(0, -0.82, 0), dark)
		_box(hip, Vector3(0.7, 0.2, 0.9), Vector3(0, -1.6, -0.15), iron)
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(1.2 * side, 3.35, 0)
		_model.add_child(shoulder)
		_box(shoulder, Vector3(0.4, 2.3, 0.4), Vector3(0, -1.15, 0), iron)
		_box(shoulder, Vector3(0.6, 0.5, 0.6), Vector3(0, -2.45, 0), dark)
		_arms.append(shoulder)

	_steam = CPUParticles3D.new()
	_steam.position = Vector3(0.25, 5.1, 0.3)
	_steam.emitting = false
	_steam.amount = 40
	_steam.lifetime = 1.6
	_steam.direction = Vector3.UP
	_steam.spread = 25.0
	_steam.initial_velocity_min = 3.0
	_steam.initial_velocity_max = 5.0
	_steam.gravity = Vector3(0, 0.5, 0)
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.4
	var puff := QuadMesh.new()
	puff.size = Vector2(0.8, 0.8)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff_material.albedo_color = Color(0.75, 0.75, 0.72, 0.35)
	puff_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	puff.material = puff_material
	_steam.mesh = puff
	_model.add_child(_steam)


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
