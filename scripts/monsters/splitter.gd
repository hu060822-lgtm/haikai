class_name Splitter
extends CharacterBody3D
## 分裂者: a lumbering knot of grey bodies grown into one, arms and heads pushing out of
## it everywhere. Dominates by ABILITY: killing it is how it multiplies. Bring it down
## and it tears apart into a handful of fast little crawlers that all come for you.
## Weaknesses players can learn:
##   - Fire. Burned flesh can't split: a killing blow with fire (or a blast) leaves
##     nothing to crawl away, and fire hurts it twice as much.
##   - It is slow. Walk away and leave it be; it loses interest in the end.
##   - Its crawlers starve within a minute of splitting off.
## Tells: wet tearing sounds, and seams in it that glow as it takes damage.

const HEIGHT := 1.9
const RADIUS := 0.55
const WANDER_SPEED := 1.3
const CHASE_SPEED := 3.6
const SIGHT_LIT := 20.0
const SIGHT_DARK := 7.0
const HEARING := 1.2  # follows noises up to this times their radius
const HIT_DISTANCE := 1.2
const HIT_DAMAGE := 35.0
const HIT_COOLDOWN := 2.2
const LOSE_TIME := 10.0
const RECOIL_TIME := 1.2
const SPLIT_MIN := 2
const SPLIT_MAX := 3
const CRAWLER_KIND := "crawler"

## Replicated: how badly it is torn (0 whole .. 1 about to split), and whether it hunts.
var torn := 0.0
var hunting := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _lumps: Array[Node3D] = []
var _lump_rest: Array[Vector3] = []
var _seam_light: OmniLight3D
var _seam: Node3D
var _arms: Array[Node3D] = []
var _target: Player = null
var _since_seen := 0.0
var _hit_cooldown := 0.0
var _recoil := 0.0
var _wander := 0.0
var _last_effects := {}
var _groan := 3.0


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
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:torn", ".:hunting"])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func hear(position: Vector3, radius: float, _kind: int) -> void:
	if _target != null or position.distance_to(global_position) > radius * HEARING:
		return
	_agent.target_position = position
	_wander = 15.0


## Host: a weapon hit it. Fire makes it recoil; everything makes it come for you.
func on_hit(hit: Dictionary) -> float:
	_last_effects = hit.get("effects", {})
	var attacker: Player = hit.get("attacker") as Player
	if attacker != null and attacker.is_active():
		_target = attacker
		_since_seen = 0.0
	if _last_effects.has("burn") and not _last_effects.get("dot", false):
		_recoil = RECOIL_TIME
		_play.rpc("screech", 0.7)
	var hp: float = get_meta("hp", 1.0)
	var max_hp: float = get_meta("max_hp", 1.0)
	torn = clampf(1.0 - hp / maxf(max_hp, 1.0), 0.0, 1.0)
	return 1.0


## Host: brought down. Unless fire sealed it, it splits into crawlers.
func host_kill() -> void:
	if is_queued_for_deletion():
		return
	var sealed := _last_effects.has("burn") or _last_effects.has("explode")
	if sealed or Run.instance == null or not MonsterRoster.MONSTERS.has(CRAWLER_KIND):
		_die.rpc(global_position, false)
		for player in MonsterKit.active_players(get_tree()):
			if player.global_position.distance_to(global_position) < 25.0:
				MonsterKit.tell(player, &"remote_warn", ["分裂者被燒焦了，一塊一塊倒下，再也動不了。", 0.1])
		queue_free()
		return
	_die.rpc(global_position, true)
	var count := rng.randi_range(SPLIT_MIN, SPLIT_MAX)
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.4, 0.4)
		var at := global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.7 + Vector3.UP * 0.15
		spawn_crawler(at)
	for player in MonsterKit.active_players(get_tree()):
		if player.global_position.distance_to(global_position) < 25.0:
			MonsterKit.tell(player, &"remote_warn", ["分裂者裂開了——一堆小東西爬了出來！（用火燒就不會分裂）", 0.4])
	queue_free()


## Host: a crawler at this spot, through the run's monster spawner so every peer gets it.
static func spawn_crawler(at: Vector3) -> void:
	if Run.instance == null:
		return
	Run.instance.host_spawn_monster(CRAWLER_KIND, at)


func _think(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_recoil = maxf(_recoil - delta, 0.0)
	var seen := _spot()
	if seen != null:
		if _target == null:
			MonsterKit.tell(seen, &"remote_warn", ["一團黏在一起的身體朝你蠕動過來…", 0.2])
		_target = seen
		_since_seen = 0.0
	else:
		_since_seen += delta
	if _target != null and (not is_instance_valid(_target) or not _target.is_active() or _since_seen > LOSE_TIME):
		_target = null
	hunting = _target != null
	if _recoil > 0.0:
		var away := global_basis.z  # backwards, away from the flame
		velocity.x = away.x * 1.5
		velocity.z = away.z * 1.5
		move_and_slide()
		return
	if _target != null:
		# It keeps coming for a long time after losing sight: it follows the smell.
		_agent.target_position = _target.global_position
		_move(CHASE_SPEED)
		var offset := _target.global_position - global_position
		if _hit_cooldown <= 0.0 and Vector2(offset.x, offset.z).length() < HIT_DISTANCE + Player.RADIUS and absf(offset.y) < 1.4:
			_hit_cooldown = HIT_COOLDOWN
			MonsterKit.tell(_target, &"remote_damage", [HIT_DAMAGE, "被分裂者吞進去了", "分裂者的好幾隻手抓住你！"])
			_play.rpc("thump", 0.7)
		return
	_wander -= delta
	if (_agent.is_navigation_finished() or _wander <= 0.0) and not patrol_points.is_empty():
		_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
		_wander = 25.0
	_move(WANDER_SPEED)


func _spot() -> Player:
	var eye := global_position + Vector3.UP * 1.6
	var best: Player = null
	var best_distance := INF
	for player in MonsterKit.active_players(get_tree()):
		var chest := player.global_position + Vector3.UP
		var distance := eye.distance_to(chest)
		var sight := MonsterKit.sight_of(player, SIGHT_LIT, SIGHT_DARK)
		if distance < sight and distance < best_distance \
				and MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
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
	if speed > 0.0 and direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.12)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.2, sound, 0.0, 25.0, pitch)


@rpc("authority", "call_local", "reliable")
func _die(at: Vector3, split: bool) -> void:
	Sfx.play_3d(get_parent(), at, "bite" if split else "hiss", 4.0, 35.0, 0.5)
	Sfx.play_3d(get_parent(), at, "screech", 0.0, 35.0, 0.6 if split else 0.45)


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	# The lumps pull apart as it is torn, and pulse like they want out.
	for i in _lumps.size():
		var rest := _lump_rest[i]
		var out := Vector3(rest.x, 0.0, rest.z).normalized() * torn * 0.18
		_lumps[i].position = rest + out + Vector3(0, sin(t * 3.0 + i) * 0.015 * (1.0 + torn * 4.0), 0)
	_seam_light.light_energy = torn * 1.4
	_seam.scale = Vector3.ONE * (0.85 + torn * 0.35)
	var speed := Vector2(velocity.x, velocity.z).length()
	for i in _arms.size():
		_arms[i].rotation.x = -0.6 + sin(t * (3.0 + speed) + i * 1.7) * (0.5 if hunting else 0.2)
	_model.rotation.z = sin(t * 2.4) * 0.06 * (1.0 + speed * 0.3)
	_groan -= delta
	if _groan <= 0.0:
		_groan = rng.randf_range(3.0, 6.0) if not hunting else rng.randf_range(1.5, 3.0)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP, "creak", -6.0, 20.0, rng.randf_range(0.3, 0.45))


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var flesh := PS1Materials.get_material("concrete", Color(0.6, 0.5, 0.48), true)
	var flesh_dark := PS1Materials.get_material("concrete", Color(0.42, 0.33, 0.32), true)
	var pale := PS1Materials.get_material("concrete", Color(0.75, 0.68, 0.62), true)
	var black := PS1Materials.get_material("concrete", Color(0.03, 0.02, 0.02), true)
	var seam := PS1Materials.get_material("concrete", Color(0.55, 0.1, 0.07), true, Vector2.ONE, Color(0.3, 0.03, 0.01))
	# Short stumpy legs, several of them, under one heavy mass.
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var hip := Vector3(cos(a) * 0.3, 0.55, sin(a) * 0.28)
		var foot := Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.45)
		MonsterKit.part(_model, _uv(LowPoly.tube(PackedVector3Array([hip, hip.lerp(foot, 0.5) + Vector3(cos(a) * 0.08, 0.05, 0), foot]),
			PackedFloat32Array([0.14, 0.11, 0.08]), 5)), Vector3.ZERO, flesh_dark)
	# Glowing red seams where the bodies are fused (they show as it tears).
	_seam = Node3D.new()
	_seam.position = Vector3(0, 1.08, 0)
	_model.add_child(_seam)
	MonsterKit.part(_seam, LowPoly.blob(0.42, Vector3(0.95, 1.2, 0.9), 1, 0.15, 3), Vector3.ZERO, seam)
	# The lumps: torsos, a back, shoulders, all grown into each other.
	var lumps := [[0.48, Vector3(0, 0.95, 0.05), Vector3(1.05, 0.9, 0.95), flesh, 11],
		[0.36, Vector3(-0.25, 1.35, 0.05), Vector3(0.9, 1.1, 0.9), flesh, 12],
		[0.34, Vector3(0.27, 1.4, -0.02), Vector3(1.0, 1.0, 0.85), pale, 13],
		[0.3, Vector3(0.02, 1.62, 0.18), Vector3(1.0, 0.85, 0.9), flesh_dark, 14],
		[0.26, Vector3(0.35, 0.95, 0.3), Vector3(1.0, 1.0, 1.0), pale, 15],
		[0.27, Vector3(-0.38, 0.85, -0.2), Vector3(1.0, 0.9, 1.0), flesh, 16],
		[0.36, Vector3(0.04, 1.15, -0.26), Vector3(1.0, 1.05, 0.8), flesh_dark, 17]]
	for lump: Array in lumps:
		var node := Node3D.new()
		node.position = lump[1]
		_model.add_child(node)
		MonsterKit.part(node, _uv(LowPoly.blob(lump[0], lump[2], 1, 0.18, lump[4])), Vector3.ZERO, lump[3])
		_lumps.append(node)
		_lump_rest.append(lump[1])
	# Heads pushing out of it, mouths open, eyes shut.
	var heads := [[Vector3(-0.22, 1.82, -0.12), Vector3(-10, 20, 15), 0.15],
		[Vector3(0.38, 1.66, -0.25), Vector3(20, -30, -25), 0.13],
		[Vector3(-0.5, 1.1, -0.28), Vector3(0, 60, 70), 0.12],
		[Vector3(0.12, 1.2, -0.46), Vector3(35, 0, 0), 0.12]]
	for head: Array in heads:
		var node := Node3D.new()
		node.position = head[0]
		node.rotation_degrees = head[1]
		_model.add_child(node)
		var r: float = head[2]
		MonsterKit.part(node, _uv(LowPoly.blob(r, Vector3(0.85, 1.05, 0.95), 1, 0.08, 7)), Vector3.ZERO, pale)
		MonsterKit.part(node, LowPoly.blob(r * 0.4, Vector3(0.9, 1.2, 0.4), 0), Vector3(0, -r * 0.35, -r * 0.85), black)
		for side: float in [-1.0, 1.0]:
			MonsterKit.part(node, LowPoly.chamfer_box(Vector3(r * 0.45, r * 0.1, r * 0.1), 0.004), Vector3(side * r * 0.38, r * 0.15, -r * 0.88), black)
	# Too many arms, reaching forward.
	var arms := [[Vector3(-0.5, 1.5, -0.1), -1.0], [Vector3(0.52, 1.45, -0.05), 1.0],
		[Vector3(-0.4, 1.05, -0.35), -1.0], [Vector3(0.45, 1.1, -0.3), 1.0], [Vector3(0.05, 1.5, -0.38), 0.3]]
	for arm_def: Array in arms:
		var side: float = arm_def[1]
		var arm := Node3D.new()
		arm.position = arm_def[0]
		_model.add_child(arm)
		var elbow := Vector3(0.15 * side, -0.25, -0.25)
		var hand := Vector3(0.12 * side, -0.55, -0.45)
		MonsterKit.part(arm, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, elbow, hand]),
			PackedFloat32Array([0.07, 0.05, 0.04]), 5)), Vector3.ZERO, flesh)
		var fingers := []
		for k in 4:
			var a := (k - 1.5) * 0.35
			fingers.append([LowPoly.tube(PackedVector3Array([hand, hand + Vector3(sin(a) * 0.07, -0.08, -0.1)]),
				PackedFloat32Array([0.02, 0.0]), 3), Transform3D.IDENTITY])
		MonsterKit.part(arm, LowPoly.merge(fingers), Vector3.ZERO, pale)
		_arms.append(arm)
	_seam_light = OmniLight3D.new()
	_seam_light.position = Vector3(0, 1.1, -0.6)
	_seam_light.light_color = Color(1.0, 0.25, 0.1)
	_seam_light.light_energy = 0.0
	_seam_light.omni_range = 3.0
	_model.add_child(_seam_light)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 4.0)
