class_name Tuner
extends CharacterBody3D
## 調音師: a jointed puppet that learns. Dominates by INTELLIGENCE: it remembers where
## scavengers keep walking and waits there, it talks to you over the radio in your
## teammates' voices, and it shuts doors behind you.
## Weaknesses players can learn:
##   - Agree on a code word: a teammate who can't answer it isn't your teammate.
##   - It chases every sound. Throw something to send it the wrong way.
##   - A struck tuning fork (any tune nearby) scrambles it for a few seconds.
## Tells: an off-key tuning-fork whine and radio static.

const HEIGHT := 1.9
const RADIUS := 0.35
const SPEED := 4.6
const PROWL_SPEED := 2.2
const SIGHT := 14.0
const HIT_DISTANCE := 1.0
const HIT_DAMAGE := 45.0
const HIT_COOLDOWN := 3.0
const MEMORY_INTERVAL := 4.0
const MEMORY_SIZE := 30
const AMBUSH_TIME := 15.0
const MIMIC_INTERVAL := Vector2(25.0, 40.0)
const DOOR_RANGE := 6.0
const DOOR_TIME := 8.0
const STUN_TIME := 5.0
const MUSIC_RANGE := 15.0

const FAKE_LINES := [
	"這邊有好東西，快過來！",
	"我被困住了…救我…在那邊的房間…",
	"出口在這邊，跟我走。",
	"沒事了，怪物走了，你可以出來了。",
]

## Replicated: stunned (twitching), hunting (for the whine).
var stunned := false
var hunting := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
## Where it has seen scavengers go: its idea of your routes.
var memory: Array[Vector3] = []

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _head: Node3D
var _target: Player = null
var _memory_timer := MEMORY_INTERVAL
var _mimic_timer := 30.0
var _ambush := 0.0
var _stun := 0.0
var _hit_cooldown := 0.0
var _lost := 0.0
var _doors := {}  # gate index -> seconds until it reopens
var _whine := 2.0


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
	_agent.radius = RADIUS
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	add_child(_agent)
	_mimic_timer = rng.randf_range(MIMIC_INTERVAL.x, MIMIC_INTERVAL.y)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:stunned", ".:hunting"])


## Every sound pulls it; a tune scrambles it.
func hear(position: Vector3, radius: float, kind: int) -> void:
	if not multiplayer.is_server():
		return
	var distance := position.distance_to(global_position)
	if kind == GameNoise.Kind.MUSIC and distance < MUSIC_RANGE:
		_stun = STUN_TIME
		return
	if kind == GameNoise.Kind.MACHINE or _target != null or distance > radius * 1.2:
		return
	_agent.target_position = position
	_ambush = 0.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func _think(delta: float) -> void:
	_stun = maxf(_stun - delta, 0.0)
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_tick_doors(delta)
	_learn(delta)
	_mimic(delta)
	stunned = _stun > 0.0
	if stunned:
		_stop()
		return

	var seen := _spot()
	if seen != null:
		_target = seen
		_lost = 0.0
	elif _target != null:
		_lost += delta
		if _lost > 3.0 or not is_instance_valid(_target) or not _target.is_active():
			_target = null
	hunting = _target != null
	var speed := PROWL_SPEED
	if _target != null:
		speed = SPEED
		_agent.target_position = _target.global_position
		_shut_door_on(_target)
	elif _agent.is_navigation_finished():
		# Wait where scavengers keep coming, then try the next likely spot.
		_ambush -= delta
		if _ambush <= 0.0:
			_agent.target_position = likely_spot()
			_ambush = AMBUSH_TIME
	_move(speed)
	if _target != null and _hit_cooldown <= 0.0:
		var offset := _target.global_position - global_position
		if Vector2(offset.x, offset.z).length() < HIT_DISTANCE + Player.RADIUS and absf(offset.y) < 1.2:
			_hit_cooldown = HIT_COOLDOWN
			MonsterKit.tell(_target, &"remote_damage", [HIT_DAMAGE, "被調音師拆掉了", "調音師抓到你了！它會學你們的路線"])
			_play.rpc("clank", 0.7)


## The remembered spot with the most visits around it: where it lies in wait.
func likely_spot() -> Vector3:
	if memory.is_empty():
		return patrol_points[rng.randi_range(0, patrol_points.size() - 1)] if not patrol_points.is_empty() else global_position
	var best := memory[0]
	var best_score := -1
	for spot in memory:
		var score := 0
		for other in memory:
			if spot.distance_to(other) < 5.0:
				score += 1
		if score > best_score:
			best = spot
			best_score = score
	return best


func _learn(delta: float) -> void:
	_memory_timer -= delta
	if _memory_timer > 0.0:
		return
	_memory_timer = MEMORY_INTERVAL
	for player in MonsterKit.active_players(get_tree()):
		memory.append(player.global_position)
	while memory.size() > MEMORY_SIZE:
		memory.remove_at(0)


## Talks to someone over the radio, in a teammate's voice if it can.
func _mimic(delta: float) -> void:
	_mimic_timer -= delta
	if _mimic_timer > 0.0:
		return
	_mimic_timer = rng.randf_range(MIMIC_INTERVAL.x, MIMIC_INTERVAL.y)
	var players := MonsterKit.active_players(get_tree())
	if players.is_empty():
		return
	var victim: Player = players[rng.randi_range(0, players.size() - 1)]
	var voice := "？？？"
	for player in players:
		if player != victim:
			voice = player.display_name
			break
	var line: String = FAKE_LINES[rng.randi_range(0, FAKE_LINES.size() - 1)]
	MonsterKit.tell(victim, &"remote_warn", ["（對講機・%s）「%s」" % [voice, line], 0.0])
	_play.rpc("static", 1.0)


func _shut_door_on(player: Player) -> void:
	var run := Run.instance
	if run == null:
		return
	for i in run.level.gates.size():
		var gate: Gate = run.level.gates[i]
		if gate.closed or _doors.has(i):
			continue
		if gate.global_position.distance_to(player.global_position) < DOOR_RANGE \
				and gate.global_position.distance_to(global_position) > 2.0 \
				and not gate.is_blocked(run.all_players()):
			_doors[i] = DOOR_TIME
			run.host_set_gate(i, true)
			return


func _tick_doors(delta: float) -> void:
	for i in _doors.keys():
		_doors[i] -= delta
		if _doors[i] <= 0.0:
			_doors.erase(i)
			if Run.instance != null and Run.instance.level.gates[i].closed:
				Run.instance.host_set_gate(i, false)


func _spot() -> Player:
	var eye := global_position + Vector3.UP * 1.7
	var best: Player = null
	var best_distance := SIGHT
	for player in MonsterKit.active_players(get_tree()):
		var chest := player.global_position + Vector3.UP
		var distance := eye.distance_to(chest)
		if distance < best_distance and MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
			best = player
			best_distance = distance
	return best


func _move(speed: float) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if _target != null and global_position.distance_to(_target.global_position) < 3.0:
		next = _target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		rotation.y = atan2(-direction.x, -direction.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.5, sound, -2.0, 24.0, pitch)


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if stunned:
		_head.rotation = Vector3(sin(t * 40.0) * 0.4, cos(t * 33.0) * 0.6, 0)
	else:
		_head.rotation = _head.rotation.lerp(Vector3(0, 0, sin(t * 0.7) * 0.3), delta * 3.0)
	_whine -= delta
	if _whine <= 0.0:
		_whine = rng.randf_range(1.5, 2.5) if hunting else rng.randf_range(5.0, 9.0)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.6, "static", -8.0 if not hunting else -2.0, 20.0, rng.randf_range(0.95, 1.05))


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var wood := PS1Materials.get_material("wood", Color(0.75, 0.6, 0.45), true)
	var brass := PS1Materials.get_material("brass", Color(0.9, 0.8, 0.5), true)
	var string := PS1Materials.get_material("concrete", Color(0.9, 0.9, 0.85), true)
	# A marionette body, joints showing, with its strings cut and trailing up.
	MonsterKit.box(_model, Vector3(0.36, 0.55, 0.2), Vector3(0, 1.3, 0), wood)
	MonsterKit.sphere(_model, 0.06, Vector3(0, 1.62, 0), brass)
	for side in [-1.0, 1.0]:
		var leg := MonsterKit.limb(_model, Vector3(0.1 * side, 1.0, 0), Vector3(0.08, 1.0, 0.08), wood)
		MonsterKit.sphere(leg, 0.06, Vector3(0, -0.5, 0), brass)
		var arm := MonsterKit.limb(_model, Vector3(0.24 * side, 1.55, 0), Vector3(0.06, 0.9, 0.06), wood)
		arm.rotation.z = 0.2 * side
		MonsterKit.box(_model, Vector3(0.01, 1.2, 0.01), Vector3(0.24 * side, 2.3, 0), string)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.7, 0)
	_model.add_child(_head)
	# The head is a tuning fork.
	MonsterKit.box(_head, Vector3(0.06, 0.25, 0.06), Vector3(0, 0.12, 0), brass)
	for side in [-1.0, 1.0]:
		MonsterKit.box(_head, Vector3(0.04, 0.4, 0.04), Vector3(0.07 * side, 0.45, 0), brass)
	MonsterKit.box(_head, Vector3(0.18, 0.04, 0.04), Vector3(0, 0.25, 0), brass)
