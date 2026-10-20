class_name Mannequin
extends CharacterBody3D
## 假人: a shop-window dummy. Dominates by ABILITY: while nobody is looking at it, it
## moves faster than anyone can run, and its touch knocks you flat.
## Weakness players can learn: it cannot move while any player is watching it,
## so a team can keep it frozen by taking turns staring.

const HEIGHT := 1.9
const RADIUS := 0.35
const SPEED := 7.0
const WANDER_SPEED := 2.5
const HUNT_RANGE := 30.0
const SEEN_RANGE_LIT := 22.0
const SEEN_RANGE_DARK := 6.0
const VIEW_HALF_ANGLE_DEG := 38.0
const HIT_DISTANCE := 0.9
const HIT_DAMAGE := 70.0
const HIT_COOLDOWN := 4.0
const POSE_COUNT := 5

## Replicated: which frozen pose it holds, and whether it is moving (for the creaks).
var pose := 0:
	set(value):
		pose = value
		if is_node_ready():
			_apply_pose()
var moving := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _head: Node3D
var _creak_timer := 0.0
var _hit_cooldown := 0.0
var _wander_time := 0.0


func _ready() -> void:
	add_to_group("monsters")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collider.shape = capsule
	collider.position.y = HEIGHT / 2.0
	add_child(collider)
	_agent = NavigationAgent3D.new()
	_agent.radius = RADIUS
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:pose", ".:moving"])
	_apply_pose()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_sounds(delta)


func _think(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if is_watched():
		if moving:
			moving = false
			pose = (pose + 1 + rng.randi_range(0, POSE_COUNT - 2)) % POSE_COUNT
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var target := MonsterKit.nearest_player(self, HUNT_RANGE)
	var speed := SPEED
	if target != null:
		_agent.target_position = target.global_position
	else:
		speed = WANDER_SPEED
		_wander_time -= delta
		if (_agent.is_navigation_finished() or _wander_time <= 0.0) and not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
			_wander_time = 15.0

	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if target != null and global_position.distance_to(target.global_position) < 3.0 \
			and absf(target.global_position.y - global_position.y) < 1.0:
		next = target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# It snaps to face you instead of turning: there is nothing natural about it.
		rotation.y = atan2(-direction.x, -direction.z)
		moving = true
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		moving = false
	move_and_slide()

	if target != null and _hit_cooldown <= 0.0:
		var offset := target.global_position - global_position
		if Vector2(offset.x, offset.z).length() < HIT_DISTANCE + Player.RADIUS and absf(offset.y) < 1.2:
			_hit(target)


## True while any active player has it in view and in the light.
func is_watched() -> bool:
	var chest := global_position + Vector3.UP * (HEIGHT * 0.6)
	for player in MonsterKit.active_players(get_tree()):
		var eye := player.head_position()
		var to := chest - eye
		var distance := to.length()
		var seen_range := SEEN_RANGE_LIT if player.lantern_on else SEEN_RANGE_DARK
		if distance > seen_range:
			continue
		if player.look_direction().dot(to / maxf(distance, 0.01)) < cos(deg_to_rad(VIEW_HALF_ANGLE_DEG)):
			continue
		if MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
			return true
	return false


func _hit(player: Player) -> void:
	_hit_cooldown = HIT_COOLDOWN
	MonsterKit.tell(player, &"remote_damage", [HIT_DAMAGE, "被假人碰到了", "假人撞倒了你！別讓它離開視線"])
	_play_hit.rpc()
	# It isn't there anymore when you get up.
	if not patrol_points.is_empty():
		var far := global_position
		for point in patrol_points:
			if point.distance_to(player.global_position) > far.distance_to(player.global_position):
				far = point
		global_position = far + Vector3.UP * 0.1
	moving = false


@rpc("authority", "call_local", "reliable")
func _play_hit() -> void:
	Sfx.play_3d(get_parent(), global_position, "bite", 0.0, 25.0, 0.6)


func _sounds(delta: float) -> void:
	if not moving:
		_creak_timer = 0.0
		return
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = rng.randf_range(0.35, 0.6)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP, "creak", -4.0, 22.0, rng.randf_range(0.8, 1.2))
	# Arms swing stiffly while it runs.
	var t := Time.get_ticks_msec() * 0.02
	_legs[0].rotation.x = sin(t) * 0.7
	_legs[1].rotation.x = -sin(t) * 0.7


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Five frozen poses; each time you look back it holds a different one.
func _apply_pose() -> void:
	var poses := [
		[Vector3(0, 0, 0.15), Vector3(0, 0, -0.15), 0.0, 0.0],
		[Vector3(-1.4, 0, 0.2), Vector3(-1.4, 0, -0.2), 0.0, 0.2],      # reaching
		[Vector3(-2.9, 0, 0.1), Vector3(0.3, 0, -0.3), 0.6, -0.1],      # one arm up
		[Vector3(-0.6, 0.4, 0.9), Vector3(-0.6, -0.4, -0.9), -0.5, 0.3], # crouched, head tilted
		[Vector3(0.4, 0, 1.4), Vector3(0.4, 0, -1.4), 0.0, -0.4],        # arms out like a cross
	]
	var p: Array = poses[pose % poses.size()]
	_arms[0].rotation = p[0]
	_arms[1].rotation = p[1]
	_head.rotation.z = p[2]
	_model.rotation.x = p[3] * 0.3
	_legs[0].rotation.x = 0.0
	_legs[1].rotation.x = 0.0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var plastic := PS1Materials.get_material("concrete", Color(0.92, 0.88, 0.82), true)
	var joint := PS1Materials.get_material("rust_metal", Color(0.4, 0.35, 0.3), true)
	MonsterKit.box(_model, Vector3(0.42, 0.62, 0.24), Vector3(0, 1.32, 0), plastic)
	MonsterKit.box(_model, Vector3(0.36, 0.2, 0.22), Vector3(0, 0.92, 0), plastic)
	MonsterKit.box(_model, Vector3(0.06, 0.12, 0.06), Vector3(0, 1.68, 0), joint)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.74, 0)
	_model.add_child(_head)
	# A smooth egg with no face.
	MonsterKit.sphere(_head, 0.14, Vector3(0, 0.13, 0), plastic, Vector3(1.0, 1.35, 1.05))
	for side in [-1.0, 1.0]:
		_arms.append(MonsterKit.limb(_model, Vector3(0.27 * side, 1.6, 0), Vector3(0.09, 0.72, 0.09), plastic))
		_legs.append(MonsterKit.limb(_model, Vector3(0.11 * side, 0.84, 0), Vector3(0.12, 0.84, 0.12), plastic))
	# The pole stand it was taken off of still sticks out of its back.
	MonsterKit.box(_model, Vector3(0.04, 0.04, 0.35), Vector3(0, 1.1, 0.25), joint)
