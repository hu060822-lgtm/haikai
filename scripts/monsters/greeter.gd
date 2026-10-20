class_name Greeter
extends CharacterBody3D
## 迎賓員: a smiling attendant in a pressed suit that politely falls in behind you.
## Dominates by INTELLIGENCE and ABILITY: it never lets you out of its sight, and the
## moment you run its face changes and it is simply behind you.
## Weaknesses players can learn:
##   - Walk. It only snaps when you run.
##   - Answer its question ("今天要買點什麼嗎？") with something in your pack to show
##     it, and it bows and leaves. Empty-handed is the wrong answer.
## Tell: a little shop bell, and "歡迎光臨".

const HEIGHT := 1.85
const RADIUS := 0.35
const FOLLOW_RANGE := 14.0
const FOLLOW_DISTANCE := 2.6
const FOLLOW_SPEED := 3.0
const WANDER_SPEED := 1.4
const RUN_SPEED := 4.3  # faster than a walk: that's running
const RUN_GRACE := 0.3
const HIT_DAMAGE := 55.0
const ANGRY_TIME := 1.2
const COOLDOWN := 20.0
const LEAVE_TIME := 60.0

## Replicated: its face, and whether it is trailing someone (for the bell).
var angry := false:
	set(value):
		angry = value
		if is_node_ready():
			_smile.visible = not value
			_scream.visible = value
var following := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _smile: Node3D
var _scream: Node3D
var _target: Player = null
var _run_time := 0.0
var _angry_time := 0.0
var _cooldown := 0.0
var _ignore := {}  # Player -> seconds it leaves them alone
var _bell_timer := 0.0
var _wander_time := 0.0


func _ready() -> void:
	add_to_group("monsters")
	# On the loot layer too, so players can look at it and answer it.
	collision_layer = Layers.MONSTER | Layers.LOOT
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
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:angry", ".:following"])
	angry = angry


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_sounds(delta)


func get_prompt(_player: Player = null) -> String:
	return "[E] 回答迎賓員：「今天要買點什麼嗎？」"


func interact(player: Player) -> void:
	# The answer is what you have to show it: the pack lives on your own machine.
	if Run.instance != null:
		Run.instance.request_monster_action(self, "show" if not player.items.is_empty() else "empty")


func host_action(action: String, player: Player) -> void:
	if player == null or not player.is_active():
		return
	match action:
		"show":
			_ignore[player] = LEAVE_TIME
			MonsterKit.tell(player, &"remote_warn", ["迎賓員看了看你帶的東西，深深一鞠躬：「謝謝光臨。」然後走開了。", 0.0])
			_bow.rpc()
			if player == _target:
				_target = null
				following = false
			_wander_to_far(player)
		"empty":
			MonsterKit.tell(player, &"remote_warn", ["「什麼都不買的話……」", 0.3])
			_snap(player)


func _think(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	for player in _ignore.keys():
		_ignore[player] -= delta
		if _ignore[player] <= 0.0 or not is_instance_valid(player):
			_ignore.erase(player)
	if _angry_time > 0.0:
		_angry_time -= delta
		if _angry_time <= 0.0:
			angry = false
		_stand()
		return

	if _target != null and (not is_instance_valid(_target) or not _target.is_active() \
			or _ignore.has(_target) or global_position.distance_to(_target.global_position) > FOLLOW_RANGE * 1.4):
		_target = null
	if _target == null and _cooldown <= 0.0:
		for player in MonsterKit.active_players(get_tree()):
			if _ignore.has(player):
				continue
			var chest := player.global_position + Vector3.UP
			if global_position.distance_to(player.global_position) < FOLLOW_RANGE \
					and MonsterKit.clear_line(get_world_3d(), global_position + Vector3.UP * 1.6, chest, [get_rid()]):
				_target = player
				MonsterKit.tell(player, &"remote_warn", ["「歡迎光臨～」有個一直微笑的店員跟在你後面。", 0.0])
				break
	following = _target != null

	if _target != null:
		# Running gives it permission.
		if _target.ground_speed > RUN_SPEED:
			_run_time += delta
			if _run_time >= RUN_GRACE:
				_snap(_target)
				return
		else:
			_run_time = 0.0
		var distance := global_position.distance_to(_target.global_position)
		_agent.target_position = _target.global_position
		_move_toward(FOLLOW_SPEED if distance > FOLLOW_DISTANCE else 0.0, delta)
		var to := _target.global_position - global_position
		rotation.y = atan2(-to.x, -to.z)
		return

	_wander_time -= delta
	if (_agent.is_navigation_finished() or _wander_time <= 0.0) and not patrol_points.is_empty():
		_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
		_wander_time = 20.0
	_move_toward(WANDER_SPEED, delta)


## The smile drops and it is right behind you.
func _snap(player: Player) -> void:
	var facing := player.look_direction()
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var behind := player.global_position - facing * 1.1
	global_position = Vector3(behind.x, player.global_position.y + 0.05, behind.z)
	var to := player.global_position - global_position
	rotation.y = atan2(-to.x, -to.z)
	angry = true
	_angry_time = ANGRY_TIME
	_cooldown = COOLDOWN
	_run_time = 0.0
	_target = null
	following = false
	MonsterKit.tell(player, &"remote_damage", [HIT_DAMAGE, "迎賓員不喜歡有人在店裡奔跑", "迎賓員變臉了！在它面前別用跑的"])
	_play_snap.rpc()


func _wander_to_far(player: Player) -> void:
	var far := global_position
	for point in patrol_points:
		if point.distance_to(player.global_position) > far.distance_to(player.global_position):
			far = point
	_agent.target_position = far
	_wander_time = 30.0


func _move_toward(speed: float, _delta: float) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if _target != null and global_position.distance_to(_target.global_position) < 4.0:
		next = _target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if speed > 0.0 and direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if _target == null:
			rotation.y = atan2(-direction.x, -direction.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _stand() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


@rpc("authority", "call_local", "reliable")
func _play_snap() -> void:
	Sfx.play_3d(get_parent(), global_position, "screech", 0.0, 25.0, 1.6)


@rpc("authority", "call_local", "reliable")
func _bow() -> void:
	Sfx.play_3d(get_parent(), global_position, "tink", -4.0, 15.0, 2.0)
	var tween := create_tween()
	var body: Node3D = get_node("Body")
	tween.tween_property(body, "rotation:x", -0.6, 0.4)
	tween.tween_property(body, "rotation:x", 0.0, 0.6)


func _sounds(delta: float) -> void:
	if not following:
		return
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		_bell_timer = rng.randf_range(2.5, 4.0)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.2, "tink", -10.0, 14.0, 2.4)


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	var suit := PS1Materials.get_material("carpet", Color(0.2, 0.2, 0.28), true)
	var shirt := PS1Materials.get_material("concrete", Color(0.95, 0.95, 0.92), true)
	var skin := PS1Materials.get_material("concrete", Color(0.98, 0.9, 0.85), true)
	var black := PS1Materials.get_material("concrete", Color(0.05, 0.03, 0.03), true)
	var red := PS1Materials.get_material("concrete", Color(0.3, 0.0, 0.0), true, Vector2.ONE, Color(0.9, 0.05, 0.02))
	for side in [-1.0, 1.0]:
		MonsterKit.limb(body, Vector3(0.11 * side, 0.85, 0), Vector3(0.14, 0.85, 0.16), suit)
		var arm := MonsterKit.limb(body, Vector3(0.28 * side, 1.5, 0), Vector3(0.1, 0.66, 0.12), suit)
		arm.rotation.x = -0.35  # hands clasped in front, the way staff are taught
	MonsterKit.box(body, Vector3(0.46, 0.68, 0.26), Vector3(0, 1.2, 0), suit)
	MonsterKit.box(body, Vector3(0.16, 0.5, 0.02), Vector3(0, 1.3, -0.135), shirt)
	MonsterKit.box(body, Vector3(0.12, 0.06, 0.03), Vector3(0, 1.52, -0.14), red)  # bow tie
	# A head a little too big, with a smile a little too wide.
	MonsterKit.sphere(body, 0.19, Vector3(0, 1.78, 0), skin, Vector3(1.05, 1.15, 1.0))
	for side in [-1.0, 1.0]:
		MonsterKit.box(body, Vector3(0.05, 0.015, 0.02), Vector3(0.07 * side, 1.84, -0.185), black)
	_smile = Node3D.new()
	body.add_child(_smile)
	for i in 7:
		var x := (i - 3) * 0.035
		MonsterKit.box(_smile, Vector3(0.04, 0.02, 0.02), Vector3(x, 1.7 + absf(x) * 0.9, -0.19), black)
	_scream = Node3D.new()
	body.add_child(_scream)
	MonsterKit.box(_scream, Vector3(0.22, 0.18, 0.03), Vector3(0, 1.7, -0.19), red)
	for side in [-1.0, 1.0]:
		MonsterKit.box(_scream, Vector3(0.07, 0.05, 0.02), Vector3(0.07 * side, 1.84, -0.19), red)
	_scream.visible = false
