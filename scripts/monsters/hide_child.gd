class_name HideChild
extends CharacterBody3D
## 捉迷藏的孩子: a small child who wants to play hide-and-seek. Dominates by
## INTELLIGENCE: it picks hiding spots you won't think of, and if it finds you first
## it tells everything in the building where your whole team is.
## Rules players can learn:
##   - Find it first (shine your lantern on it) and it leaves you a rare present.
##   - It always hides next to a toy.
##   - Let the time run out and it comes looking: if it reaches you, your lantern
##     breaks and every scavenger's position is called out to the monsters.
## Tells: laughter far off, and counting to ten.

const HEIGHT := 1.1
const RADIUS := 0.25
const INVITE_RANGE := 20.0
const COUNT_TIME := 5.0
const HIDE_TIME := 70.0
const SEEK_SPEED := 4.8
const FOUND_RANGE := 9.0
const FOUND_HALF_ANGLE_DEG := 25.0
const TAG_DISTANCE := 1.2
const AWAY_TIME := 120.0
const REVEAL_RADIUS := 30.0

enum State { WAIT, COUNT, HIDE, SEEK, AWAY }

## Replicated: what it is doing (pose, toy, visibility).
var state := State.WAIT:
	set(value):
		state = value
		if is_node_ready():
			_apply_state()
var patrol_points: Array[Vector3] = []
var hide_spots: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _toy: Node3D
var _timer := 0.0
var _giggle := 6.0


func _ready() -> void:
	add_to_group("monsters")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD | Layers.WALKWAY
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collider.shape = capsule
	collider.position.y = HEIGHT / 2.0
	add_child(collider)
	_agent = NavigationAgent3D.new()
	_agent.radius = RADIUS
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state"])
	_apply_state()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_tells(delta)


func _think(delta: float) -> void:
	_timer -= delta
	match state:
		State.WAIT:
			_stand()
			for player in MonsterKit.active_players(get_tree()):
				if player.global_position.distance_to(global_position) < INVITE_RANGE:
					_invite()
					break
		State.COUNT:
			_stand()
			if _timer <= 0.0:
				_hide()
		State.HIDE:
			_stand()
			var finder := found_by()
			if finder != null:
				_found(finder)
			elif _timer <= 0.0:
				state = State.SEEK
				var nearest := MonsterKit.nearest_player(self)
				if nearest != null:
					MonsterKit.tell(nearest, &"remote_warn", ["「時間到了～換我來找你囉！」", 0.2])
		State.SEEK:
			var target := MonsterKit.nearest_player(self)
			if target == null:
				_stand()
				return
			_agent.target_position = target.global_position
			_move(SEEK_SPEED, target)
			var offset := target.global_position - global_position
			if Vector2(offset.x, offset.z).length() < TAG_DISTANCE + Player.RADIUS and absf(offset.y) < 1.5:
				_tagged(target)
		State.AWAY:
			if _timer <= 0.0:
				if not patrol_points.is_empty():
					global_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)] + Vector3.UP * 0.1
				velocity = Vector3.ZERO
				state = State.WAIT


## The player whose lantern is shining on it while it hides, if any.
func found_by() -> Player:
	var chest := global_position + Vector3.UP * 0.6
	for player in MonsterKit.active_players(get_tree()):
		if not player.lantern_on:
			continue
		var eye := player.head_position()
		var to := chest - eye
		var distance := to.length()
		if distance > FOUND_RANGE:
			continue
		if player.look_direction().dot(to / maxf(distance, 0.01)) < cos(deg_to_rad(FOUND_HALF_ANGLE_DEG)):
			continue
		if MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
			return player
	return null


func _invite() -> void:
	state = State.COUNT
	_timer = COUNT_TIME
	for player in MonsterKit.active_players(get_tree()):
		if player.global_position.distance_to(global_position) < INVITE_RANGE * 1.5:
			MonsterKit.tell(player, &"remote_warn", ["「一、二、三…數到十喔！」有個小孩要跟你玩捉迷藏。用提燈照到它就算你贏。", 0.0])
	_play.rpc("giggle", 1.0)


## Teleports to a hiding spot well away from everyone, with a toy beside it.
func _hide() -> void:
	var spots := hide_spots if not hide_spots.is_empty() else patrol_points
	var best := global_position
	var best_score := -1.0
	for attempt in 8:
		var spot: Vector3 = spots[rng.randi_range(0, spots.size() - 1)]
		var nearest := INF
		for player in MonsterKit.active_players(get_tree()):
			nearest = minf(nearest, player.global_position.distance_to(spot))
		if nearest > best_score:
			best = spot
			best_score = nearest
	global_position = best + Vector3.UP * 0.05
	rotation.y = rng.randf_range(0.0, TAU)
	state = State.HIDE
	_timer = HIDE_TIME


func _found(player: Player) -> void:
	var present := LootTable.roll(rng, 3.0)
	Run.instance.host_spawn_loot(present, global_position + Vector3.UP * 0.4)
	MonsterKit.tell(player, &"remote_warn", ["「被你找到了～」小孩留下一個禮物，然後不見了。", 0.0])
	_play.rpc("giggle", 1.3)
	_leave()


func _tagged(player: Player) -> void:
	MonsterKit.tell(player, &"remote_snuff")
	MonsterKit.tell(player, &"remote_warn", ["「找到你了！」小孩大聲喊出每個人的位置…", 0.5])
	_play.rpc("giggle", 0.7)
	# Everyone gets called out: monsters and the guardian hear where each scavenger is.
	for other in MonsterKit.active_players(get_tree()):
		GameNoise.emit(get_tree(), other.global_position, REVEAL_RADIUS, GameNoise.Kind.VOICE)
	_leave()


func _leave() -> void:
	state = State.AWAY
	_timer = AWAY_TIME
	global_position = Vector3(global_position.x, -40.0, global_position.z)
	velocity = Vector3.ZERO


func _move(speed: float, target: Player) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if global_position.distance_to(target.global_position) < 3.0:
		next = target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()


func _stand() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if state != State.AWAY:
		move_and_slide()


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP, sound, 0.0, 35.0, pitch)


func _tells(delta: float) -> void:
	if state != State.HIDE and state != State.SEEK:
		return
	_giggle -= delta
	if _giggle <= 0.0:
		_giggle = rng.randf_range(6.0, 12.0) if state == State.HIDE else rng.randf_range(2.0, 4.0)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP, "giggle", -10.0, 30.0, rng.randf_range(0.9, 1.2))


func _apply_state() -> void:
	visible = state != State.AWAY
	_toy.visible = state == State.HIDE
	# Crouched small while hiding, standing otherwise.
	_model.scale = Vector3(1.0, 0.65, 1.0) if state == State.HIDE else Vector3.ONE


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var shirt := PS1Materials.get_material("carpet", Color(0.9, 0.75, 0.3), true)
	var skin := PS1Materials.get_material("concrete", Color(0.95, 0.85, 0.78), true)
	var dark := PS1Materials.get_material("concrete", Color(0.05, 0.05, 0.05), true)
	MonsterKit.box(_model, Vector3(0.3, 0.4, 0.18), Vector3(0, 0.65, 0), shirt)
	for side in [-1.0, 1.0]:
		MonsterKit.limb(_model, Vector3(0.08 * side, 0.45, 0), Vector3(0.09, 0.45, 0.09), dark)
		MonsterKit.limb(_model, Vector3(0.19 * side, 0.82, 0), Vector3(0.07, 0.38, 0.07), skin)
	MonsterKit.sphere(_model, 0.14, Vector3(0, 1.0, 0), skin)
	# Two black eyes, too big, and nothing else.
	for side in [-1.0, 1.0]:
		MonsterKit.sphere(_model, 0.035, Vector3(0.05 * side, 1.02, -0.12), dark)
	# The toy it always hides next to.
	_toy = Node3D.new()
	_toy.position = Vector3(0.5, 0, 0.2)
	add_child(_toy)
	var red := PS1Materials.get_material("concrete", Color(0.9, 0.2, 0.15), true)
	var blue := PS1Materials.get_material("concrete", Color(0.2, 0.4, 0.9), true)
	MonsterKit.box(_toy, Vector3(0.2, 0.2, 0.2), Vector3(0, 0.1, 0), red)
	MonsterKit.box(_toy, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.28, 0), blue)
	MonsterKit.sphere(_toy, 0.08, Vector3(0.18, 0.08, 0.05), blue)
