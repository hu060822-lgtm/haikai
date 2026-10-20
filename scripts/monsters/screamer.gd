class_name Screamer
extends CharacterBody3D
## 尖叫面具: a bundle of rags the size of a child, crouched under a cracked porcelain
## mask. Harmless on its own. Dominates by INTELLIGENCE: the moment it sees a scavenger
## it draws a long breath and SCREAMS, and every monster on the map comes to that spot.
## It knows what a gun is: the instant one is pointed at it, it bolts for cover.
## Weaknesses players can learn:
##   - It can't scream with a barrel on it: keep it in your sights and it only runs.
##   - It is fragile. One clean hit and it is gone; kill it before the breath ends.
## Tells: a thin wheeze as it breathes in, and a mask that sometimes isn't where it was.

const HEIGHT := 0.9
const RADIUS := 0.25
const WANDER_SPEED := 1.6
const FLEE_SPEED := 6.4
const SIGHT_LIT := 22.0
const SIGHT_DARK := 9.0
const AIM_RANGE := 26.0
const AIM_DOT := 0.965  # about 15 degrees off the barrel
const WINDUP := 1.3
const SCREAM_RADIUS := 220.0  # the whole map
const SCREAM_COOLDOWN := 14.0
const FLEE_TIME := 2.5
const WATCH_DISTANCE := 9.0

enum State { WANDER, WATCH, WINDUP, FLEE }

## Replicated: what it is doing (mask, breathing), and how far its mouth is open.
var state := State.WANDER
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _mask: Node3D
var _mouth: Node3D
var _limbs: Array[Node3D] = []
var _target: Player = null
var _timer := 0.0
var _cooldown := 0.0
var _wander := 0.0
var _flee_from := Vector3.ZERO
var _wheeze := 0.0


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
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state"])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


## Host: a weapon hit it. Anything that doesn't kill it sends it running.
func on_hit(hit: Dictionary) -> float:
	var attacker: Player = hit.get("attacker") as Player
	_flee(attacker.global_position if attacker != null else hit.get("from", global_position))
	return 1.0


## Host: it's dead. The mask drops and cracks.
func host_kill() -> void:
	if is_queued_for_deletion():
		return
	_died.rpc(global_position)
	queue_free()


func _think(delta: float) -> void:
	_timer -= delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	# A gun on it beats everything: it runs.
	var aimer := _aimed_at_by()
	if aimer != null and state != State.FLEE:
		_flee(aimer.global_position)
		if aimer == _target or _target == null:
			MonsterKit.tell(aimer, &"remote_warn", ["面具縮了一下，逃走了。（槍口對著它，它就叫不出來）", 0.0])
	match state:
		State.FLEE:
			var away := global_position - _flee_from
			away.y = 0.0
			away = away.normalized() if away.length() > 0.01 else -global_basis.z
			_agent.target_position = global_position + away * 6.0
			_move(FLEE_SPEED)
			if _timer <= 0.0:
				state = State.WATCH if _target != null else State.WANDER
			return
		State.WINDUP:
			_stand()
			if _target == null or not is_instance_valid(_target) or not _target.is_active():
				state = State.WANDER
				return
			_face(_target.global_position)
			if _timer <= 0.0:
				_scream()
			return
	var seen := _spot()
	if seen != null:
		if _target != seen:
			MonsterKit.tell(seen, &"remote_warn", ["一張白色面具從暗處盯著你…它在吸氣！", 0.15])
		_target = seen
		if _cooldown <= 0.0:
			state = State.WINDUP
			_timer = WINDUP
			_breathe.rpc()
			return
		state = State.WATCH
	elif _target != null and (not is_instance_valid(_target) or not _target.is_active() \
			or global_position.distance_to(_target.global_position) > SIGHT_LIT * 1.5):
		_target = null
	if state == State.WATCH and _target != null:
		# Keep a safe distance and keep looking.
		var distance := global_position.distance_to(_target.global_position)
		_agent.target_position = _target.global_position
		_face(_target.global_position)
		_move(WANDER_SPEED * 1.5 if distance > WATCH_DISTANCE else 0.0)
		return
	state = State.WANDER
	_wander -= delta
	if (_agent.is_navigation_finished() or _wander <= 0.0) and not patrol_points.is_empty():
		_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
		_wander = 18.0
	_move(WANDER_SPEED)


## The scream: everything on the map is told where this is.
func _scream() -> void:
	_cooldown = SCREAM_COOLDOWN
	state = State.WATCH
	_play_scream.rpc()
	GameNoise.emit_local(get_tree(), global_position, SCREAM_RADIUS, GameNoise.Kind.VOICE)
	for player in MonsterKit.active_players(get_tree()):
		if player.global_position.distance_to(global_position) < 60.0:
			MonsterKit.tell(player, &"remote_warn", ["尖叫面具放聲尖叫！整張地圖的怪物都聽到了！", 0.6])


func _flee(from: Vector3) -> void:
	state = State.FLEE
	_timer = FLEE_TIME
	_flee_from = from


## The nearest player it can see (lantern-lit ones from much further).
func _spot() -> Player:
	var eye := global_position + Vector3.UP * 0.75
	var best: Player = null
	var best_distance := INF
	for player in MonsterKit.active_players(get_tree()):
		var chest := player.global_position + Vector3.UP
		var distance := eye.distance_to(chest)
		var sight := SIGHT_LIT if player.is_lit() else SIGHT_DARK
		if distance < sight and distance < best_distance \
				and MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
			best = player
			best_distance = distance
	return best


## A player pointing a gun at it (everyone carries at least the revolver).
func _aimed_at_by() -> Player:
	var middle := global_position + Vector3.UP * 0.5
	for player in MonsterKit.active_players(get_tree()):
		var eye := player.head_position()
		var to := middle - eye
		var distance := to.length()
		if distance > AIM_RANGE or distance < 0.01:
			continue
		if player.look_direction().dot(to / distance) < AIM_DOT:
			continue
		if MonsterKit.clear_line(get_world_3d(), eye, middle, [get_rid()]):
			return player
	return null


func _move(speed: float) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if speed > 0.0 and direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if state != State.WATCH:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.3)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _stand() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.25)


@rpc("authority", "call_local", "reliable")
func _breathe() -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 0.7, "hiss", -4.0, 18.0, 1.8)


@rpc("authority", "call_local", "reliable")
func _play_scream() -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 0.7, "screech", 10.0, 120.0, 1.35)
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 0.7, "screech", 6.0, 120.0, 0.8)


@rpc("authority", "call_local", "reliable")
func _died(at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, "tink", 0.0, 25.0, 0.6)
	Sfx.play_3d(get_parent(), at, "screech", -8.0, 25.0, 2.4)


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var open := 0.15
	match state:
		State.WINDUP:
			open = 0.6 + sin(t * 30.0) * 0.05
			_mask.position.y = 0.72 + sin(t * 3.0) * 0.01
			_mask.rotation.x = lerpf(_mask.rotation.x, -0.35, delta * 4.0)
		State.WATCH:
			open = 1.0 if _cooldown_hint() else 0.25
			_mask.rotation.x = lerpf(_mask.rotation.x, 0.0, delta * 4.0)
			# A slow, curious head tilt.
			_mask.rotation.z = sin(t * 0.7) * 0.35
		_:
			_mask.rotation.x = lerpf(_mask.rotation.x, 0.0, delta * 4.0)
			_mask.rotation.z = lerpf(_mask.rotation.z, 0.0, delta * 2.0)
	_mouth.scale = Vector3(1.0, lerpf(_mouth.scale.y, open * 2.2 + 0.3, minf(delta * 10.0, 1.0)), 1.0)
	var speed := Vector2(velocity.x, velocity.z).length()
	for i in _limbs.size():
		var phase := t * (14.0 if speed > 3.0 else 6.0) + i * PI * 0.5
		_limbs[i].rotation.x = sin(phase) * (0.5 if speed > 0.2 else 0.05)
	if state == State.WINDUP:
		_wheeze -= delta
		if _wheeze <= 0.0:
			_wheeze = 0.35
			Sfx.play_3d(get_parent(), global_position + Vector3.UP * 0.7, "hiss", -14.0, 12.0, 2.4)


## Clients don't know the cooldown; the open mouth just lingers right after a scream.
func _cooldown_hint() -> bool:
	return _cooldown > SCREAM_COOLDOWN - 1.5


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var rags := PS1Materials.get_material("carpet", Color(0.36, 0.32, 0.27), true)
	var rag_light := PS1Materials.get_material("carpet", Color(0.55, 0.5, 0.42), true)
	var skin := PS1Materials.get_material("concrete", Color(0.6, 0.56, 0.52), true)
	var porcelain := PS1Materials.get_material("concrete", Color(1.0, 0.98, 0.92), true, Vector2.ONE, Color(0.12, 0.11, 0.1))
	var black := PS1Materials.get_material("concrete", Color(0.02, 0.02, 0.02), true)
	var crack := PS1Materials.get_material("concrete", Color(0.25, 0.2, 0.18), true)
	var lips := PS1Materials.get_material("concrete", Color(0.35, 0.02, 0.03), true, Vector2.ONE, Color(0.25, 0.0, 0.0))
	# A hunched heap of rags, wider at the bottom, with a hood that the mask sits in.
	var heap := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.3, 0.02), Vector2(0.32, 0.12),
		Vector2(0.26, 0.32), Vector2(0.22, 0.5), Vector2(0.17, 0.62), Vector2(0.08, 0.7), Vector2(0.0, 0.71)])
	MonsterKit.part(_model, _uv(LowPoly.lathe(heap, 7, 0.4)), Vector3(0, 0.0, 0.05), rags, Vector3(-12, 0, 0), Vector3(1.0, 1.0, 0.85))
	MonsterKit.part(_model, _uv(LowPoly.blob(0.2, Vector3(1.0, 1.0, 1.1), 1, 0.2, 9)), Vector3(0, 0.7, 0.06), rags)
	# Torn strips hanging off it.
	var strips := []
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var top := Vector3(sin(a) * 0.24, 0.4 + (i % 3) * 0.06, cos(a) * 0.22 + 0.05)
		var tip := Vector3(sin(a) * 0.36, 0.02, cos(a) * 0.33 + 0.05)
		strips.append([LowPoly.tube(PackedVector3Array([top, top.lerp(tip, 0.5) + Vector3(0, 0, 0.02), tip]),
			PackedFloat32Array([0.04, 0.03, 0.0]), 3), Transform3D.IDENTITY])
	MonsterKit.part(_model, _uv(LowPoly.merge(strips)), Vector3.ZERO, rag_light)
	# Four long grey limbs folded like a spider's, poking out of the rags.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := -1.0 if i < 2 else 1.0
		var joint := Node3D.new()
		joint.position = Vector3(0.2 * side, 0.35, 0.08 * front + 0.05)
		_model.add_child(joint)
		var knee := Vector3(0.28 * side, 0.32, 0.12 * front)
		var foot := Vector3(0.36 * side, -0.35, 0.2 * front)
		MonsterKit.part(joint, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, knee, foot]),
			PackedFloat32Array([0.035, 0.025, 0.012]), 4)), Vector3.ZERO, skin)
		MonsterKit.part(joint, LowPoly.blob(0.03, Vector3.ONE, 0), knee, skin)
		_limbs.append(joint)
	# The mask: a too-big porcelain face, two black eye holes, a long screaming mouth.
	_mask = Node3D.new()
	_mask.position = Vector3(0, 0.74, -0.13)
	_mask.scale = Vector3.ONE * 1.25
	_model.add_child(_mask)
	var face := PackedVector2Array([Vector2(0.0, -0.24), Vector2(0.1, -0.22), Vector2(0.16, -0.12),
		Vector2(0.19, 0.02), Vector2(0.18, 0.13), Vector2(0.12, 0.22), Vector2(0.0, 0.25)])
	MonsterKit.part(_mask, _uv(LowPoly.lathe(face, 8)), Vector3.ZERO, porcelain, Vector3.ZERO, Vector3(1.0, 1.0, 0.45))
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_mask, LowPoly.blob(0.045, Vector3(0.8, 1.25, 0.4), 0), Vector3(0.075 * side, 0.06, -0.075), black)
		# Painted tear streaks below the eyes.
		MonsterKit.part(_mask, LowPoly.chamfer_box(Vector3(0.012, 0.09, 0.01), 0.002), Vector3(0.078 * side, -0.04, -0.079), crack, Vector3(0, 0, 6 * side))
	var cracks := PackedVector3Array([Vector3(0.02, 0.24, -0.04), Vector3(0.05, 0.16, -0.075),
		Vector3(0.02, 0.1, -0.084), Vector3(0.06, 0.02, -0.084)])
	MonsterKit.part(_mask, LowPoly.tube(cracks, PackedFloat32Array([0.006, 0.006, 0.005, 0.0]), 3), Vector3.ZERO, crack)
	_mouth = Node3D.new()
	_mouth.position = Vector3(0, -0.11, -0.075)
	_mask.add_child(_mouth)
	MonsterKit.part(_mouth, LowPoly.blob(0.04, Vector3(1.0, 0.5, 0.3), 0), Vector3.ZERO, lips)
	MonsterKit.part(_mouth, LowPoly.blob(0.032, Vector3(0.8, 0.45, 0.3), 0), Vector3(0, 0, -0.004), black)
	# A faint glow in the eye holes so it reads in the dark.
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 0.05, -0.25)
	glow.light_color = Color(0.9, 0.85, 0.75)
	glow.light_energy = 0.35
	glow.omni_range = 1.4
	_mask.add_child(glow)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 4.0)
