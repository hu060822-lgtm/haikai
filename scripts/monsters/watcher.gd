class_name Watcher
extends CharacterBody3D
## 長頸觀察者: a thin thing on stilt legs with a neck long enough to look down over the
## walls. Dominates by SIZE: it sees half the map from up there, and whatever it stares
## at for three seconds it simply picks up and takes away.
## Weaknesses players can learn:
##   - It only sees things that MOVE. Freeze and its stare slides off you.
##   - It can't see under a roof: ceilings, catwalks and upper floors hide you.
## Tell: joints clicking somewhere overhead.

const RADIUS := 0.45
const WALK_SPEED := 1.6
const SIGHT_RANGE := 28.0
const MOVE_THRESHOLD := 0.6  # metres per second: slower than this and it can't see you
const STARE_TO_GRAB := 3.0
const STARE_DECAY := 1.2
const COVER_HEIGHT := 4.0
const PAUSE_TIME := 4.0
const GRAB_COOLDOWN := 12.0
const MAX_HEAD_HEIGHT := 9.0

## Replicated: what it is looking at, and whether it has locked on to someone.
var aim := Vector3.ZERO
var staring := false:
	set(value):
		staring = value
		if is_node_ready():
			_eye_light.light_color = Color(1.0, 0.15, 0.1) if value else Color(0.9, 0.95, 0.7)
var walking := false
var head_height := MAX_HEAD_HEIGHT
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _eye_light: OmniLight3D
var _stare := {}  # Player -> seconds stared at
var _warned := {}
var _pause := 0.0
var _cooldown := 0.0
var _click_timer := 0.0
var _scan := 0.0


func _ready() -> void:
	add_to_group("monsters")
	add_to_group("listeners")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = 3.0
	collider.shape = capsule
	collider.position.y = 1.5
	add_child(collider)
	_agent = NavigationAgent3D.new()
	_agent.radius = BoilerColossus.RADIUS
	_agent.path_desired_distance = 1.0
	_agent.target_desired_distance = 1.2
	add_child(_agent)
	if Run.instance != null and Run.instance.level != null:
		head_height = minf(MAX_HEAD_HEIGHT, Run.instance.level.overview_height - 1.5)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:aim", ".:staring", ".:walking"])
	aim = global_position + Vector3(0, head_height - 2.0, -5.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func head_position() -> Vector3:
	return global_position + Vector3.UP * head_height


## True if this player is somewhere it can see them: moving, in the open, in sight.
func can_see(player: Player) -> bool:
	if not player.is_active() or player.ground_speed < MOVE_THRESHOLD:
		return false
	var head := head_position()
	var chest := player.global_position + Vector3.UP * 1.0
	if head.distance_to(chest) > SIGHT_RANGE or is_covered(player):
		return false
	return MonsterKit.clear_line(get_world_3d(), head, chest, [get_rid()])


## A roof, catwalk or upper floor right overhead hides you from it.
func is_covered(player: Player) -> bool:
	var top := player.head_position() + Vector3.UP * 0.3
	return not MonsterKit.clear_line(get_world_3d(), top, top + Vector3.UP * COVER_HEIGHT, [get_rid()])


func hear(position: Vector3, radius: float, _kind: int) -> void:
	if staring or radius < 8.0 or global_position.distance_to(position) > radius * 1.5:
		return
	_agent.target_position = position
	_pause = 0.0


func _think(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target: Player = null
	for player in MonsterKit.active_players(get_tree()):
		if _cooldown <= 0.0 and can_see(player):
			_stare[player] = _stare.get(player, 0.0) + delta
		elif _stare.has(player):
			_stare[player] = maxf(_stare[player] - STARE_DECAY * delta, 0.0)
		if _stare.get(player, 0.0) > 0.0 and (target == null or _stare[player] > _stare[target]):
			target = player
	for player in _stare.keys():
		if not is_instance_valid(player) or _stare[player] <= 0.0:
			_stare.erase(player)
			_warned.erase(player)

	staring = target != null
	if staring:
		aim = target.global_position + Vector3.UP
		walking = false
		velocity.x = 0.0
		velocity.z = 0.0
		var to := target.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 2.0 * delta)
		if not _warned.has(target):
			_warned[target] = true
			MonsterKit.tell(target, &"remote_warn", ["頭頂傳來喀喀聲…有東西從上面盯著你。別動！", 0.3])
		if _stare[target] >= STARE_TO_GRAB:
			_grab(target)
		move_and_slide()
		return

	# Wander from point to point, stopping to look around.
	if _pause > 0.0:
		_pause -= delta
		_scan += delta * 0.6
		aim = head_position() + Vector3(sin(_scan) * 6.0, -4.0, cos(_scan) * 6.0)
		walking = false
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _agent.is_navigation_finished():
		if not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
		_pause = PAUSE_TIME
		return
	var next := _agent.get_next_path_position() if _nav_ready() else global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 3.0 * delta)
		aim = head_position() + direction * 6.0 + Vector3.DOWN * 3.0
		walking = true
	move_and_slide()


func _grab(player: Player) -> void:
	MonsterKit.tell(player, &"remote_damage", [999.0, "被長頸觀察者抓走了"])
	_play_grab.rpc(player.global_position)
	_stare.erase(player)
	_warned.erase(player)
	_cooldown = GRAB_COOLDOWN
	staring = false
	if not patrol_points.is_empty():
		_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]


@rpc("authority", "call_local", "reliable")
func _play_grab(at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, "screech", 4.0, 50.0, 0.45)


func _animate(delta: float) -> void:
	if aim != Vector3.ZERO and aim.distance_to(_head.global_position) > 0.2:
		var look := _head.global_transform.looking_at(aim, Vector3.UP)
		_head.global_basis = _head.global_basis.slerp(look.basis, minf(4.0 * delta, 1.0)).orthonormalized()
	var t := Time.get_ticks_msec() * 0.002
	if walking:
		_legs[0].rotation.x = sin(t * 1.6) * 0.25
		_legs[1].rotation.x = -sin(t * 1.6) * 0.25
	else:
		_legs[0].rotation.x = lerpf(_legs[0].rotation.x, 0.0, delta * 2.0)
		_legs[1].rotation.x = lerpf(_legs[1].rotation.x, 0.0, delta * 2.0)
	# The clicking joints: faster while it stares at someone.
	_click_timer -= delta
	if _click_timer <= 0.0:
		_click_timer = rng.randf_range(0.15, 0.3) if staring else rng.randf_range(1.2, 2.5)
		Sfx.play_3d(get_parent(), head_position(), "tick", 2.0 if staring else -4.0, 40.0, rng.randf_range(0.4, 0.6))


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var skin := PS1Materials.get_material("concrete", Color(0.75, 0.72, 0.68), true)
	var dark := PS1Materials.get_material("rust_metal", Color(0.25, 0.22, 0.2), true)
	var hip_y := head_height * 0.55
	for side in [-1.0, 1.0]:
		var leg := MonsterKit.limb(_model, Vector3(0.35 * side, hip_y, 0), Vector3(0.14, hip_y, 0.14), skin)
		MonsterKit.box(leg, Vector3(0.22, 0.2, 0.22), Vector3(0, -hip_y * 0.5, 0), dark)  # knee
		_legs.append(leg)
		var arm := MonsterKit.limb(_model, Vector3(0.45 * side, hip_y + 1.2, 0), Vector3(0.08, hip_y + 0.6, 0.08), skin)
		arm.rotation.z = 0.08 * side
	MonsterKit.box(_model, Vector3(0.9, 1.4, 0.4), Vector3(0, hip_y + 0.7, 0), skin)
	var neck_length := head_height - hip_y - 1.5
	MonsterKit.box(_model, Vector3(0.12, neck_length, 0.12), Vector3(0, hip_y + 1.4 + neck_length / 2.0, 0), skin)
	_head = Node3D.new()
	_head.position = Vector3(0, head_height, 0)
	_model.add_child(_head)
	MonsterKit.sphere(_head, 0.3, Vector3(0, 0, -0.15), skin, Vector3(0.8, 0.9, 1.6))
	var eye := MonsterKit.sphere(_head, 0.08, Vector3(0, 0.02, -0.6), skin)
	eye.material_override = PS1Materials.get_material("concrete", Color(0.2, 0.2, 0.2), true, Vector2.ONE, Color(1.0, 0.9, 0.6))
	_eye_light = OmniLight3D.new()
	_eye_light.position = Vector3(0, 0, -0.7)
	_eye_light.light_color = Color(0.9, 0.95, 0.7)
	_eye_light.light_energy = 0.8
	_eye_light.omni_range = 4.0
	_head.add_child(_eye_light)
