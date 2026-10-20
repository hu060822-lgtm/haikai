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
	var wood := PS1Materials.get_material("wood", Color(0.75, 0.6, 0.45))
	var dark_wood := PS1Materials.get_material("wood", Color(0.42, 0.3, 0.2))
	var brass := PS1Materials.get_material("brass", Color(0.9, 0.8, 0.5))
	var string := PS1Materials.get_material("concrete", Color(0.9, 0.9, 0.85))
	var black := PS1Materials.get_material("concrete", Color(0.05, 0.03, 0.02))
	var glow := PS1Materials.get_material("concrete", Color(0.4, 0.25, 0.1), false, Vector2.ONE, Color(1.0, 0.55, 0.15))
	# A marionette carved like an instrument: a pelvis block, a ball at the waist and
	# a hollow chest with sound holes cut in it.
	MonsterKit.part(_model, LowPoly.prism(6, 0.13, 0.15, 0.14), Vector3(0, 1.05, 0), wood, Vector3(0, 30, 0), Vector3(1, 1, 0.7))
	MonsterKit.part(_model, LowPoly.blob(0.06, Vector3.ONE, 0), Vector3(0, 1.15, 0), brass)
	var chest := PackedVector2Array([Vector2(0.0, 1.18), Vector2(0.12, 1.18), Vector2(0.165, 1.3),
		Vector2(0.18, 1.45), Vector2(0.16, 1.55), Vector2(0.1, 1.6), Vector2(0.0, 1.61)])
	MonsterKit.part(_model, LowPoly.lathe(chest, 6), Vector3.ZERO, wood, Vector3(0, 30, 0), Vector3(1, 1, 0.65))
	for side: float in [-1.0, 1.0]:
		var hole := PackedVector3Array()
		for i in 5:
			var t := i / 4.0
			hole.append(Vector3(side * (0.07 + sin(t * TAU) * 0.012), 1.48 - t * 0.2, -0.104 + absf(t - 0.5) * 0.012))
		MonsterKit.part(_model, LowPoly.tube(hole, PackedFloat32Array([0.01, 0.007, 0.007, 0.007, 0.01]), 4), Vector3.ZERO, black)
		# Tuning pegs screwed into its back.
		MonsterKit.part(_model, LowPoly.prism(6, 0.015, 0.015, 0.14), Vector3(0.06 * side, 1.45, 0.12), dark_wood, Vector3(0, 0, 90))
		MonsterKit.part(_model, LowPoly.chamfer_box(Vector3(0.025, 0.06, 0.04), 0.008), Vector3(0.15 * side, 1.45, 0.12), dark_wood)
	MonsterKit.part(_model, LowPoly.blob(0.055, Vector3.ONE, 0), Vector3(0, 1.63, 0), brass)
	for side: float in [-1.0, 1.0]:
		# Jointed legs: thigh, brass knee, shin, brass ankle, a wooden clog.
		var leg := Node3D.new()
		leg.position = Vector3(0.1 * side, 1.0, 0)
		_model.add_child(leg)
		MonsterKit.part(leg, LowPoly.blob(0.05, Vector3.ONE, 0), Vector3(0, -0.01, 0), brass)
		MonsterKit.part(leg, LowPoly.prism(6, 0.038, 0.05, 0.4), Vector3(0, -0.24, 0), wood)
		MonsterKit.part(leg, LowPoly.blob(0.06, Vector3.ONE, 0), Vector3(0, -0.5, 0), brass)
		MonsterKit.part(leg, LowPoly.prism(6, 0.03, 0.04, 0.38), Vector3(0, -0.72, 0), wood)
		MonsterKit.part(leg, LowPoly.blob(0.035, Vector3.ONE, 0), Vector3(0, -0.92, 0), brass)
		var clog := PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.13, 0.0), Vector2(0.15, 0.03),
			Vector2(0.1, 0.06), Vector2(-0.05, 0.06)])
		MonsterKit.part(leg, LowPoly.extrude(clog, 0.075), Vector3(0, -1.0, 0), dark_wood, Vector3(0, 90, 0))
		# Arms hanging slack, with splayed carved hands.
		var arm := Node3D.new()
		arm.position = Vector3(0.24 * side, 1.55, 0)
		arm.rotation.z = 0.2 * side
		_model.add_child(arm)
		MonsterKit.part(arm, LowPoly.blob(0.045, Vector3.ONE, 0), Vector3.ZERO, brass)
		MonsterKit.part(arm, LowPoly.prism(6, 0.03, 0.038, 0.36), Vector3(0, -0.21, 0), wood)
		MonsterKit.part(arm, LowPoly.blob(0.042, Vector3.ONE, 0), Vector3(0, -0.41, 0), brass)
		MonsterKit.part(arm, LowPoly.prism(6, 0.024, 0.03, 0.32), Vector3(0, -0.6, 0), wood)
		MonsterKit.part(arm, LowPoly.blob(0.03, Vector3.ONE, 0), Vector3(0, -0.78, 0), brass)
		var hand := PackedVector2Array([Vector2(-0.03, 0.0), Vector2(0.03, 0.0), Vector2(0.035, -0.05),
			Vector2(0.04, -0.13), Vector2(0.028, -0.13), Vector2(0.02, -0.07), Vector2(0.012, -0.15),
			Vector2(0.0, -0.15), Vector2(-0.004, -0.07), Vector2(-0.014, -0.14), Vector2(-0.026, -0.135),
			Vector2(-0.025, -0.06), Vector2(-0.06, -0.08), Vector2(-0.065, -0.065), Vector2(-0.035, -0.035)])
		MonsterKit.part(arm, LowPoly.extrude(hand, 0.022), Vector3(0, -0.8, 0), wood, Vector3(0, -90, 0))
		# Its strings are cut, but they still trail up out of sight, from shoulder and knee.
		MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(0.24 * side, 1.6, 0), Vector3(0.25 * side, 2.2, 0.03),
			Vector3(0.23 * side, 2.9, 0.0)]), PackedFloat32Array([0.006, 0.006, 0.004]), 3), Vector3.ZERO, string)
		MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(0.1 * side, 0.5, -0.06), Vector3(0.12 * side, 1.5, -0.17),
			Vector3(0.1 * side, 2.7, -0.3)]), PackedFloat32Array([0.005, 0.005, 0.003]), 3), Vector3.ZERO, string)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.7, 0)
	_model.add_child(_head)
	# The head is a tuning fork, with one ember of an eye at the root of the prongs.
	MonsterKit.part(_head, LowPoly.prism(8, 0.045, 0.035, 0.05), Vector3(0, 0.0, 0), brass)
	MonsterKit.part(_head, LowPoly.prism(6, 0.028, 0.034, 0.22), Vector3(0, 0.12, 0), brass)
	var fork := PackedVector3Array([Vector3(-0.07, 0.66, 0), Vector3(-0.07, 0.36, 0), Vector3(-0.058, 0.27, 0),
		Vector3(0.0, 0.225, 0), Vector3(0.058, 0.27, 0), Vector3(0.07, 0.36, 0), Vector3(0.07, 0.66, 0)])
	MonsterKit.part(_head, LowPoly.tube(fork, PackedFloat32Array([0.018, 0.024, 0.026, 0.03, 0.026, 0.024, 0.018]), 6), Vector3.ZERO, brass)
	MonsterKit.part(_head, LowPoly.blob(0.02, Vector3(1.0, 0.7, 0.6), 0), Vector3(0, 0.23, -0.028), glow)
