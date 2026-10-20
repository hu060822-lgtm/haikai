class_name LullabyMother
extends CharacterBody3D
## 哄睡的母親: a huge, faceless woman who drifts after you humming a lullaby and wants
## to rock you to sleep. Dominates by SIZE and INTELLIGENCE: she never stops coming,
## and once she holds you, you don't get up.
## Weaknesses players can learn:
##   - Music stops her. While something plays a tune nearby she stands and listens.
##   - Don't run where she can see you: it upsets her, and she comes faster.
## Tells: the lullaby, and the air turning warm.

const HEIGHT := 4.0
const RADIUS := 1.0
const DRIFT_SPEED := 1.6
const SEEK_SPEED := 2.6
const UPSET_SPEED := 5.0
const UPSET_TIME := 4.0
const SIGHT_LIT := 30.0
const SIGHT_DARK := 10.0
const HOLD_DISTANCE := 1.9
const LISTEN_TIME := 8.0
const MUSIC_RANGE := 22.0
const RUN_SPEED := 4.3

## Replicated: listening (frozen, head tilted), upset (faster, arms out).
var listening := false
var upset := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _song: AudioStreamPlayer3D
var _target: Player = null
var _listen := 0.0
var _upset := 0.0
var _wander := 0.0
var _warned := {}


func _ready() -> void:
	add_to_group("monsters")
	add_to_group("listeners")
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
	_agent.radius = BoilerColossus.RADIUS
	_agent.height = HEIGHT
	_agent.path_desired_distance = 1.0
	_agent.target_desired_distance = 1.2
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:listening", ".:upset"])


func hear(position: Vector3, _radius: float, kind: int) -> void:
	if kind == GameNoise.Kind.MUSIC and position.distance_to(global_position) < MUSIC_RANGE:
		_listen = LISTEN_TIME


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func _think(delta: float) -> void:
	_listen = maxf(_listen - delta, 0.0)
	_upset = maxf(_upset - delta, 0.0)
	listening = _listen > 0.0
	upset = _upset > 0.0 and not listening
	if listening:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_target = _find_target()
	var speed := DRIFT_SPEED
	if _target != null:
		if _target.ground_speed > RUN_SPEED and _upset <= 0.0:
			_upset = UPSET_TIME
			MonsterKit.tell(_target, &"remote_warn", ["搖籃曲停了一拍。她看到你在跑了。", 0.4])
		if not _warned.has(_target):
			_warned[_target] = true
			MonsterKit.tell(_target, &"remote_warn", ["遠處傳來搖籃曲，空氣變得好溫暖…", 0.0])
		_agent.target_position = _target.global_position
		speed = UPSET_SPEED if _upset > 0.0 else SEEK_SPEED
	else:
		_wander -= delta
		if (_agent.is_navigation_finished() or _wander <= 0.0) and not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
			_wander = 20.0
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if _target != null and global_position.distance_to(_target.global_position) < 4.0:
		next = _target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 3.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

	if _target != null:
		var offset := _target.global_position - global_position
		if Vector2(offset.x, offset.z).length() < HOLD_DISTANCE and absf(offset.y) < 2.5:
			MonsterKit.tell(_target, &"remote_damage", [999.0, "被哄睡的母親抱住，再也沒醒來"])
			_warned.erase(_target)
			_target = null


func _find_target() -> Player:
	var eye := global_position + Vector3.UP * (HEIGHT - 0.4)
	var best: Player = null
	var best_distance := INF
	for player in MonsterKit.active_players(get_tree()):
		var chest := player.global_position + Vector3.UP
		var distance := eye.distance_to(chest)
		var sight := SIGHT_LIT if player.lantern_on else SIGHT_DARK
		if distance < sight and distance < best_distance \
				and MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
			best = player
			best_distance = distance
	return best


func _animate(delta: float) -> void:
	_song.stream_paused = listening
	var t := Time.get_ticks_msec() * 0.001
	# Rocking, as if there were a baby in her arms; arms open wide when she's upset.
	_model.rotation.z = sin(t * 1.2) * 0.06
	var open := 1.2 if upset else 0.0
	_arms[0].rotation.x = lerpf(_arms[0].rotation.x, -1.1 + sin(t * 1.2) * 0.1 - open * 0.3, delta * 3.0)
	_arms[1].rotation.x = _arms[0].rotation.x
	_arms[0].rotation.z = lerpf(_arms[0].rotation.z, -0.3 - open, delta * 3.0)
	_arms[1].rotation.z = -_arms[0].rotation.z
	_head.rotation.z = lerpf(_head.rotation.z, 0.5 if listening else 0.0, delta * 2.0)


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var dress := PS1Materials.get_material("carpet", Color(0.85, 0.78, 0.7), true)
	var skin := PS1Materials.get_material("concrete", Color(0.95, 0.88, 0.82), true)
	var hair := PS1Materials.get_material("carpet", Color(0.15, 0.1, 0.08), true)
	# A long nightgown down to the floor (no feet).
	MonsterKit.box(_model, Vector3(1.4, 2.2, 1.0), Vector3(0, 1.1, 0), dress)
	MonsterKit.box(_model, Vector3(1.0, 1.0, 0.7), Vector3(0, 2.7, 0), dress)
	MonsterKit.box(_model, Vector3(0.2, 0.3, 0.2), Vector3(0, 3.3, 0), skin)
	_head = Node3D.new()
	_head.position = Vector3(0, 3.45, 0)
	_model.add_child(_head)
	# A smooth face with nothing on it, under long hair.
	MonsterKit.sphere(_head, 0.32, Vector3(0, 0.3, 0), skin, Vector3(0.9, 1.2, 0.95))
	MonsterKit.box(_head, Vector3(0.7, 0.9, 0.5), Vector3(0, 0.25, 0.15), hair)
	for side in [-1.0, 1.0]:
		_arms.append(MonsterKit.limb(_model, Vector3(0.6 * side, 3.1, 0), Vector3(0.18, 1.6, 0.18), skin))
	# The warmth: a soft orange glow around her.
	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 2.0, 0)
	warm.light_color = Color(1.0, 0.7, 0.45)
	warm.light_energy = 0.6
	warm.omni_range = 7.0
	_model.add_child(warm)
	_song = AudioStreamPlayer3D.new()
	_song.stream = Sfx.looped("lullaby")
	_song.unit_size = 8.0
	_song.max_distance = 40.0
	_song.volume_db = -2.0
	_song.autoplay = true
	_song.position = Vector3(0, 3.0, 0)
	add_child(_song)
