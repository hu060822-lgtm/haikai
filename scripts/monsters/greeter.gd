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


## Host: a weapon hit it. Shooting in the shop is worse than running: the smile drops
## and it is behind the shooter. With its real face showing it is easier to hurt.
func on_hit(hit: Dictionary) -> float:
	if angry:
		return 1.5
	var attacker: Player = hit.get("attacker") as Player
	if attacker != null and attacker.is_active() and _cooldown <= 0.0:
		MonsterKit.tell(attacker, &"remote_warn", ["「店內禁止開槍。」", 0.3])
		_snap(attacker)
		return 0.6
	return 1.0


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
	var suit := PS1Materials.get_material("carpet", Color(0.2, 0.2, 0.28))
	var lapel := PS1Materials.get_material("carpet", Color(0.12, 0.12, 0.18))
	var shirt := PS1Materials.get_material("concrete", Color(0.95, 0.95, 0.92))
	var skin := PS1Materials.get_material("concrete", Color(0.98, 0.9, 0.85))
	var black := PS1Materials.get_material("concrete", Color(0.05, 0.03, 0.03))
	var hair := PS1Materials.get_material("concrete", Color(0.1, 0.08, 0.07))
	var brass := PS1Materials.get_material("brass", Color(1.0, 0.9, 0.6))
	var red := PS1Materials.get_material("concrete", Color(0.3, 0.0, 0.0), false, Vector2.ONE, Color(0.9, 0.05, 0.02))
	# Pressed trousers and polished shoes.
	var shoe := PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.16, 0.0), Vector2(0.19, 0.025),
		Vector2(0.15, 0.07), Vector2(0.04, 0.09), Vector2(-0.07, 0.09)])
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.11 * side, 0.85, 0)
		body.add_child(leg)
		MonsterKit.part(leg, LowPoly.tube(PackedVector3Array([Vector3(0, 0.03, 0), Vector3(0, -0.4, -0.01),
			Vector3(0, -0.79, 0)]), PackedFloat32Array([0.09, 0.075, 0.066]), 6), Vector3.ZERO, suit)
		MonsterKit.part(leg, LowPoly.extrude(shoe, 0.105), Vector3(0, -0.85, 0), black, Vector3(0, 90, 0))
	# The jacket: one lathed shell, squared at the shoulders and nipped at the waist.
	var jacket := PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.2, 0.8), Vector2(0.215, 0.95),
		Vector2(0.2, 1.08), Vector2(0.235, 1.3), Vector2(0.255, 1.44), Vector2(0.24, 1.54),
		Vector2(0.12, 1.6), Vector2(0.0, 1.62)])
	MonsterKit.part(body, LowPoly.lathe(jacket, 8), Vector3.ZERO, suit, Vector3(0, 22.5, 0), Vector3(1, 1, 0.62))
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(body, LowPoly.blob(0.085, Vector3(1.1, 0.65, 1.0), 0), Vector3(0.22 * side, 1.5, 0), suit)
	# Shirt front in the V of the lapels, the bow tie, buttons and a brass name badge.
	var vee := PackedVector2Array([Vector2(-0.085, 0.0), Vector2(0.085, 0.0), Vector2(0.0, -0.32)])
	MonsterKit.part(body, LowPoly.extrude(vee, 0.02), Vector3(0, 1.56, -0.142), shirt)
	for side: float in [-1.0, 1.0]:
		var flap := PackedVector2Array([Vector2(0.085 * side, 0.0), Vector2(0.125 * side, -0.03),
			Vector2(0.03 * side, -0.33), Vector2(0.0, -0.32)])
		MonsterKit.part(body, LowPoly.extrude(flap, 0.02), Vector3(0, 1.56, -0.15), lapel)
	var bow := PackedVector2Array([Vector2(-0.075, 0.04), Vector2(0.0, 0.01), Vector2(0.075, 0.04),
		Vector2(0.075, -0.04), Vector2(0.0, -0.01), Vector2(-0.075, -0.04)])
	MonsterKit.part(body, LowPoly.extrude(bow, 0.03), Vector3(0, 1.53, -0.168), red)
	MonsterKit.part(body, LowPoly.blob(0.02, Vector3.ONE, 0), Vector3(0, 1.53, -0.18), red)
	for y: float in [1.17, 1.06]:
		MonsterKit.part(body, LowPoly.prism(6, 0.016, 0.016, 0.012), Vector3(0, y, -0.128), black, Vector3(90, 0, 0))
	MonsterKit.part(body, LowPoly.chamfer_box(Vector3(0.075, 0.028, 0.012), 0.004), Vector3(-0.105, 1.35, -0.135), brass, Vector3(0, -12, 0))
	# Arms bent at the elbow, white-gloved hands clasped in front, the way staff are taught.
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.28 * side, 1.5, 0)
		body.add_child(arm)
		MonsterKit.part(arm, LowPoly.tube(PackedVector3Array([Vector3(0, 0.02, 0), Vector3(0.01 * side, -0.3, 0.03),
			Vector3(-0.17 * side, -0.49, -0.16)]), PackedFloat32Array([0.068, 0.058, 0.05]), 6), Vector3.ZERO, suit)
		MonsterKit.part(arm, LowPoly.prism(6, 0.042, 0.042, 0.035), Vector3(-0.19 * side, -0.505, -0.175), shirt, Vector3(50, 0, -40 * side))
		MonsterKit.part(arm, LowPoly.blob(0.056, Vector3(0.85, 1.0, 1.15), 0), Vector3(-0.23 * side, -0.53, -0.2), shirt)
	# A head a little too big, with a smile a little too wide.
	MonsterKit.part(body, LowPoly.prism(6, 0.075, 0.07, 0.05), Vector3(0, 1.59, 0), shirt)
	MonsterKit.part(body, LowPoly.prism(6, 0.058, 0.054, 0.1), Vector3(0, 1.64, 0), skin)
	var head := PackedVector2Array([Vector2(0.0, -0.2), Vector2(0.08, -0.19), Vector2(0.15, -0.14),
		Vector2(0.195, -0.05), Vector2(0.205, 0.04), Vector2(0.19, 0.12), Vector2(0.14, 0.19),
		Vector2(0.07, 0.225), Vector2(0.0, 0.235)])
	MonsterKit.part(body, LowPoly.lathe(head, 10), Vector3(0, 1.79, 0), skin, Vector3(0, 18, 0), Vector3(1, 1, 0.95))
	var cap := PackedVector2Array([Vector2(0.212, 0.0), Vector2(0.208, 0.07), Vector2(0.162, 0.15),
		Vector2(0.088, 0.205), Vector2(0.0, 0.222)])
	MonsterKit.part(body, LowPoly.lathe(cap, 10), Vector3(0, 1.815, 0.012), hair, Vector3(16, 18, 0), Vector3(1, 1, 0.97))
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(body, LowPoly.blob(0.04, Vector3(0.4, 1.0, 0.7), 0), Vector3(0.2 * side, 1.8, 0.01), skin)
	MonsterKit.part(body, LowPoly.blob(0.026, Vector3(0.8, 1.0, 1.0), 0), Vector3(0, 1.78, -0.198), skin)
	_smile = Node3D.new()
	body.add_child(_smile)
	# Happy, closed eyes and a grin that runs nearly ear to ear.
	for side: float in [-1.0, 1.0]:
		var lid := PackedVector3Array()
		for i in 5:
			var x := 0.07 * side + (i - 2) * 0.018
			lid.append(_on_face(x, 1.855 + 0.02 - absf(i - 2) * absf(i - 2) * 0.006))
		MonsterKit.part(_smile, LowPoly.tube(lid, PackedFloat32Array([0.006, 0.009, 0.01, 0.009, 0.006]), 4), Vector3.ZERO, black)
	var grin := PackedVector3Array()
	var grin_r := PackedFloat32Array()
	for i in 11:
		var x := (i - 5) * 0.03
		grin.append(_on_face(x, 1.695 + x * x * 3.2))
		grin_r.append(0.017 - absf(i - 5) * 0.0018)
	MonsterKit.part(_smile, LowPoly.tube(grin, grin_r, 4), Vector3.ZERO, black)
	_scream = Node3D.new()
	body.add_child(_scream)
	MonsterKit.part(_scream, LowPoly.blob(0.1, Vector3(0.95, 1.05, 0.4), 1, 0.12, 3), Vector3(0, 1.7, -0.165), red)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_scream, LowPoly.blob(0.04, Vector3(1.2, 0.85, 0.45), 0), Vector3(0.07 * side, 1.85, -0.183), red)
	_scream.visible = false


## A point just proud of the front of the head (centred at y 1.79, radius ~0.2).
static func _on_face(x: float, y: float) -> Vector3:
	var r := 0.205 - maxf(1.79 - y, 0.0) * 0.45
	return Vector3(x, y, -sqrt(maxf(r * r - x * x, 0.0)) * 0.95 - 0.004)
