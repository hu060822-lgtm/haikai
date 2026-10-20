class_name LullabyMother
extends CharacterBody3D
## 哄睡的母親: a huge, faceless woman who drifts after you humming a lullaby and wants
## to rock you to sleep. Dominates by SIZE and INTELLIGENCE: she never stops coming,
## and once she holds you, you don't get up.
## Weaknesses players can learn:
##   - Music stops her. While something plays a tune nearby she stands and listens.
##   - Don't run where she can see you: it upsets her, and she comes faster.
##   - Never take her cradle. She will always find you.
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
const CRADLE_ID := 96

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
	# Whoever took her cradle, she always knows where they are.
	for player in MonsterKit.active_players(get_tree()):
		if player.carries(CRADLE_ID):
			var distance := global_position.distance_to(player.global_position)
			if distance < best_distance:
				best = player
				best_distance = distance
	if best != null:
		return best
	for player in MonsterKit.active_players(get_tree()):
		var chest := player.global_position + Vector3.UP
		var distance := eye.distance_to(chest)
		var sight := SIGHT_LIT if player.is_lit() else SIGHT_DARK
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
	var dress := PS1Materials.get_material("carpet", Color(0.85, 0.78, 0.7))
	var skin := PS1Materials.get_material("concrete", Color(0.95, 0.88, 0.82))
	var hair := PS1Materials.get_material("carpet", Color(0.15, 0.1, 0.08))
	var trim := PS1Materials.get_material("concrete", Color(0.8, 0.72, 0.66))
	# A long pleated nightgown down to the floor (no feet): it flares at the hem,
	# pinches at the waist and closes over narrow shoulders.
	var gown := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.8, 0.0), Vector2(0.76, 0.35),
		Vector2(0.64, 1.1), Vector2(0.52, 1.8), Vector2(0.42, 2.3), Vector2(0.5, 2.7),
		Vector2(0.52, 2.95), Vector2(0.36, 3.18), Vector2(0.12, 3.28), Vector2(0.0, 3.3)])
	MonsterKit.part(_model, _pleated_lathe(gown, 12, 0.07, 1.0, 2.3), Vector3.ZERO, dress, Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
	# Ruffled hem, a sash at the waist and a high collar.
	MonsterKit.part(_model, _pleated_lathe(PackedVector2Array([Vector2(0.84, 0.0), Vector2(0.88, 0.1),
		Vector2(0.8, 0.2)]), 12, 0.06, 0.0, 0.2), Vector3.ZERO, trim, Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
	MonsterKit.part(_model, LowPoly.prism(10, 0.46, 0.45, 0.12), Vector3(0, 2.32, 0), trim, Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
	MonsterKit.part(_model, LowPoly.prism(8, 0.2, 0.14, 0.16), Vector3(0, 3.25, 0), trim)
	# A long thin neck.
	MonsterKit.part(_model, LowPoly.prism(6, 0.1, 0.08, 0.36), Vector3(0, 3.38, 0), skin)
	_head = Node3D.new()
	_head.position = Vector3(0, 3.45, 0)
	_model.add_child(_head)
	# A smooth face with nothing on it, framed by long hair that falls down her back.
	MonsterKit.part(_head, LowPoly.blob(0.32, Vector3(0.9, 1.2, 0.95), 1, 0.03, 21), Vector3(0, 0.3, -0.02), skin)
	MonsterKit.part(_head, LowPoly.blob(0.35, Vector3(0.95, 1.12, 0.9), 1, 0.06, 22), Vector3(0, 0.36, 0.1), hair)
	var strands := []
	for i in 5:
		var a := lerpf(-1.9, 1.9, i / 4.0)
		var top := Vector3(sin(a) * 0.28, 0.4, cos(a) * 0.24 + 0.08)
		var sway := sin(i * 1.7) * 0.06
		var fall := 1.0 - absf(a) * 0.25
		strands.append([LowPoly.tube(PackedVector3Array([top, top + Vector3(sin(a) * 0.08 + sway, -0.45, cos(a) * 0.08),
			top + Vector3(sin(a) * 0.12 - sway, -0.95 * fall, cos(a) * 0.1 + 0.04),
			top + Vector3(sin(a) * 0.1, -1.35 * fall, cos(a) * 0.12 + 0.02)]),
			PackedFloat32Array([0.12, 0.1, 0.07, 0.0]), 4), LowPoly.at(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.6))])
	MonsterKit.part(_head, LowPoly.merge(strands), Vector3.ZERO, hair)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.6 * side, 3.1, 0)
		_model.add_child(arm)
		# Shoulder, a bell sleeve and a long pale hand with too-long fingers.
		MonsterKit.part(arm, LowPoly.blob(0.2, Vector3(1.0, 0.85, 1.0), 0, 0.05, 23), Vector3(-0.04 * side, 0.02, 0), dress)
		MonsterKit.part(arm, LowPoly.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, -0.05),
			Vector2(0.14, -0.45), Vector2(0.17, -0.85), Vector2(0.24, -1.05), Vector2(0.2, -1.1), Vector2(0.0, -1.1)]), 7), Vector3.ZERO, dress)
		MonsterKit.part(arm, LowPoly.prism(6, 0.07, 0.08, 0.4), Vector3(0, -1.15, 0), skin)
		MonsterKit.part(arm, LowPoly.chamfer_box(Vector3(0.18, 0.2, 0.08), 0.03), Vector3(0, -1.42, 0), skin)
		var fingers := []
		for k in 3:
			var x := (k - 1.0) * 0.06
			var base := Vector3(x, -1.5, 0.0)
			fingers.append([LowPoly.tube(PackedVector3Array([base, base + Vector3(x * 0.3, -0.12, -0.02),
				base + Vector3(x * 0.4, -0.24 + absf(k - 1.0) * 0.03, 0.02)]),
				PackedFloat32Array([0.026, 0.02, 0.0]), 3), Transform3D.IDENTITY])
		fingers.append([LowPoly.tube(PackedVector3Array([Vector3(side * 0.08, -1.4, -0.02), Vector3(side * 0.12, -1.5, -0.06),
			Vector3(side * 0.1, -1.6, -0.08)]), PackedFloat32Array([0.025, 0.018, 0.0]), 3), Transform3D.IDENTITY])
		MonsterKit.part(arm, LowPoly.merge(fingers), Vector3.ZERO, skin)
		_arms.append(arm)
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


## A lathe whose rings push in and out around the axis, like cloth hanging in folds.
## The folds are deepest at `deep_y` and fade out by `flat_y`.
static func _pleated_lathe(profile: PackedVector2Array, sides: int, depth: float, deep_y: float, flat_y: float) -> ArrayMesh:
	var bent := PackedVector2Array()
	var rings: Array = []
	for p in profile:
		var fold := depth * clampf((flat_y - p.y) / maxf(flat_y - deep_y, 0.001), 0.0, 1.0) if deep_y < flat_y \
			else depth * clampf((p.y - flat_y) / maxf(deep_y - flat_y, 0.001), 0.0, 1.0)
		var ring: Array[Vector3] = []
		for s in sides:
			var t := TAU * s / sides
			var r := p.x + (fold if s % 2 == 0 else -fold * 0.5) if p.x > 0.0001 else 0.0
			ring.append(Vector3(cos(t) * r, p.y, sin(t) * r))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var centre := Vector3(0, (profile[i].y + profile[i + 1].y) / 2.0, 0)
		for s in sides:
			var n := (s + 1) % sides
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][n]
			var c: Vector3 = rings[i + 1][n]
			var d: Vector3 = rings[i + 1][s]
			LowPoly._tri_outward(st, a, b, c, centre)
			LowPoly._tri_outward(st, a, c, d, centre)
	return st.commit()
