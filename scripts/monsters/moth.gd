class_name Moth
extends Node3D
## 撲燈蛾: a moth the size of a hand. Dominates by ABILITY: it flies straight at any lit
## lantern, beats it out, then screams loud enough to bring every monster nearby.
## Weakness players can learn: with the lantern off it has nothing to fly at.

const FLY_SPEED := 4.2
const WANDER_SPEED := 1.2
const NOTICE_RANGE := 16.0
const SNUFF_DISTANCE := 0.6
const SCREAM_RADIUS := 30.0
const REST_TIME := 18.0

## Replicated so clients can play the flutter and scream.
var resting := false
var home := Vector3.ZERO
var rng := RandomNumberGenerator.new()

var _target: Player = null
var _rest_timer := 0.0
var _wander_goal := Vector3.ZERO
var _flutter_timer := 0.0
var _wings: Array[Node3D] = []
var _flap := 0.0


func _ready() -> void:
	add_to_group("monsters")
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:resting"])
	_wander_goal = global_position if home == Vector3.ZERO else home


func _process(delta: float) -> void:
	if multiplayer.is_server():
		_think(delta)
	_flap += delta * (30.0 if not resting else 6.0)
	_wings[0].rotation.z = sin(_flap) * 0.9
	_wings[1].rotation.z = -sin(_flap) * 0.9
	if not resting:
		_flutter_timer -= delta
		if _flutter_timer <= 0.0:
			_flutter_timer = 0.55
			Sfx.play_3d(get_parent(), global_position, "flutter", -12.0, 12.0, rng.randf_range(0.9, 1.3))


func _think(delta: float) -> void:
	if _rest_timer > 0.0:
		_rest_timer -= delta
		if _rest_timer <= 0.0:
			resting = false
		return

	if _target == null or not is_instance_valid(_target) or not _wants(_target):
		_target = _find_lantern()
	var goal: Vector3
	var speed := FLY_SPEED
	if _target != null:
		goal = _target.head_position()
		if global_position.distance_to(goal) < SNUFF_DISTANCE:
			_snuff(_target)
			return
	else:
		speed = WANDER_SPEED
		if global_position.distance_to(_wander_goal) < 0.5:
			_wander_goal = home + Vector3(rng.randf_range(-4, 4), rng.randf_range(-0.8, 1.2), rng.randf_range(-4, 4))
		goal = _wander_goal
	# A jittery, drunken flight path.
	var to := goal - global_position
	var wobble := Vector3(sin(_flap * 0.21), cos(_flap * 0.17) * 0.6, sin(_flap * 0.13 + 1.0)) * 0.6
	var step := (to.normalized() + wobble).normalized() * speed * delta
	if step.length() > to.length():
		step = to
	var next := global_position + step
	if MonsterKit.clear_line(get_world_3d(), global_position, next + step.normalized() * 0.15):
		global_position = next
	else:
		_wander_goal = home
		_target = null
	if step.length() > 0.001 and absf(step.normalized().y) < 0.95:
		look_at(global_position + step, Vector3.UP)


func _wants(player: Player) -> bool:
	return player.is_active() and player.lantern_on \
		and global_position.distance_to(player.head_position()) < NOTICE_RANGE * 1.3 \
		and MonsterKit.clear_line(get_world_3d(), global_position, player.head_position())


func _find_lantern() -> Player:
	var best: Player = null
	var best_distance := NOTICE_RANGE
	for player in MonsterKit.active_players(get_tree()):
		if not player.lantern_on:
			continue
		var distance := global_position.distance_to(player.head_position())
		if distance < best_distance and MonsterKit.clear_line(get_world_3d(), global_position, player.head_position()):
			best = player
			best_distance = distance
	return best


func _snuff(player: Player) -> void:
	MonsterKit.tell(player, &"remote_snuff")
	_target = null
	_rest_timer = REST_TIME
	resting = true
	_scream.rpc()
	GameNoise.emit_local(get_tree(), global_position, SCREAM_RADIUS, GameNoise.Kind.MACHINE)
	# Flutter off somewhere to rest.
	global_position += Vector3(rng.randf_range(-1.5, 1.5), 1.2, rng.randf_range(-1.5, 1.5))


@rpc("authority", "call_local", "reliable")
func _scream() -> void:
	Sfx.play_3d(get_parent(), global_position, "screech", 6.0, 60.0, rng.randf_range(0.9, 1.1))


func _build_model() -> void:
	var body_material := PS1Materials.get_material("concrete", Color(0.55, 0.5, 0.42), true)
	var wing_material := PS1Materials.get_material("concrete", Color(0.8, 0.74, 0.6), true)
	MonsterKit.sphere(self, 0.07, Vector3.ZERO, body_material, Vector3(0.8, 0.8, 2.2))
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		add_child(hinge)
		MonsterKit.box(hinge, Vector3(0.3, 0.01, 0.22), Vector3(0.15 * side, 0, 0.02), wing_material)
		_wings.append(hinge)
	# Two dim eyes so it reads in the dark.
	var eyes := OmniLight3D.new()
	eyes.light_color = Color(1.0, 0.85, 0.5)
	eyes.light_energy = 0.25
	eyes.omni_range = 0.8
	add_child(eyes)
