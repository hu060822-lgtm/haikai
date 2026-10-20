class_name Collector
extends CharacterBody3D
## 回收員: a stooped figure pushing a squeaking cart. Dominates by INTELLIGENCE: it
## clears loot off the floor, then lays it back out as bait and waits nearby for
## whoever comes to take it.
## Weakness players can learn: it can be bribed. Throw something down near it while
## it chases you and it stops to take it, and leaves you alone for a while.
## Tell: the cart's squeaking wheels.

const HEIGHT := 1.7
const RADIUS := 0.5
const WANDER_SPEED := 1.8
const CHASE_SPEED := 4.2
const SIGHT_LIT := 14.0
const SIGHT_DARK := 6.0
const PICK_RANGE := 1.4
const BRIBE_RANGE := 3.0
const BAIT_AT := 3  # items in the cart before it sets a trap
const LURK_TIME := 25.0
const CONTENT_TIME := 30.0
const HIT_DISTANCE := 1.1
const HIT_DAMAGE := 35.0
const HIT_COOLDOWN := 3.0
const LOSE_TIME := 4.0

enum State { WANDER, BAIT, LURK, CHASE, CONTENT }

## Replicated: what it is doing, and how full the cart is (for the clients' cart model).
var state := State.WANDER
var cart_load := 0:
	set(value):
		cart_load = value
		if is_node_ready():
			_apply_load()
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var carried: Array[Dictionary] = []

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _cart_pile: Array[Node3D] = []
var _target: Player = null
var _timer := 0.0
var _since_seen := 0.0
var _hit_cooldown := 0.0
var _bait_spot := Vector3.ZERO
var _squeak := 0.0


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
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state", ".:cart_load"])
	_apply_load()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_sounds(delta)


func _think(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_timer -= delta
	if state != State.CONTENT:
		var seen := _spot_player()
		if seen != null:
			if state != State.CHASE:
				MonsterKit.tell(seen, &"remote_warn", ["推車的輪子停了。回收員朝你過來了！（丟個東西給它？）", 0.2])
			_target = seen
			state = State.CHASE
			_since_seen = 0.0
	match state:
		State.WANDER:
			_pick_up_nearby(PICK_RANGE, false)
			if carried.size() >= BAIT_AT and not patrol_points.is_empty():
				_bait_spot = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
				_agent.target_position = _bait_spot
				state = State.BAIT
			elif _agent.is_navigation_finished() or _timer <= 0.0:
				_go_somewhere()
			_move(WANDER_SPEED)
		State.BAIT:
			if global_position.distance_to(_bait_spot) < 1.5 or _agent.is_navigation_finished():
				_lay_bait()
				# Back off a few metres and wait.
				var away := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * 5.0
				_agent.target_position = _bait_spot + away
				state = State.LURK
				_timer = LURK_TIME
			_move(WANDER_SPEED)
		State.LURK:
			if _agent.is_navigation_finished():
				_face(_bait_spot)
				_move(0.0)
			else:
				_move(WANDER_SPEED)
			if _timer <= 0.0:
				_go_somewhere()
				state = State.WANDER
		State.CHASE:
			# A bribe on the floor beats a scavenger.
			if _pick_up_nearby(BRIBE_RANGE, true):
				if _target != null and is_instance_valid(_target):
					MonsterKit.tell(_target, &"remote_warn", ["回收員撿起你丟的東西，心滿意足地推車走了。", 0.0])
				state = State.CONTENT
				_timer = CONTENT_TIME
				_target = null
				_go_somewhere()
				return
			if _target == null or not is_instance_valid(_target) or not _target.is_active():
				state = State.WANDER
				return
			_since_seen += delta
			if _since_seen > LOSE_TIME:
				state = State.WANDER
				_target = null
				return
			_agent.target_position = _target.global_position
			_move(CHASE_SPEED)
			var offset := _target.global_position - global_position
			if _hit_cooldown <= 0.0 and Vector2(offset.x, offset.z).length() < HIT_DISTANCE + Player.RADIUS and absf(offset.y) < 1.2:
				_hit_cooldown = HIT_COOLDOWN
				MonsterKit.tell(_target, &"remote_damage", [HIT_DAMAGE, "被回收員收走了", "回收員用推車撞你！丟東西給它可以收買它"])
				_play.rpc("thump")
		State.CONTENT:
			if _agent.is_navigation_finished():
				_go_somewhere()
			_move(WANDER_SPEED)
			if _timer <= 0.0:
				state = State.WANDER


func _spot_player() -> Player:
	var eye := global_position + Vector3.UP * 1.5
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


## Host: scoop up loot near the cart. Bribes are things players threw down (unfrozen).
func _pick_up_nearby(reach: float, bribes_only: bool) -> bool:
	var run := Run.instance
	if run == null:
		return false
	for node in run.loot_root.get_children():
		var item := node as LootItem
		if item == null or item.is_queued_for_deletion():
			continue
		if bribes_only and item.freeze:
			continue
		if item.global_position.distance_to(global_position) < reach:
			carried.append(item.to_data())
			item.queue_free()
			cart_load = carried.size()
			_play.rpc("pickup")
			return true
	return false


## Host: lay everything in the cart out on the floor as bait.
func _lay_bait() -> void:
	var run := Run.instance
	for i in carried.size():
		var angle := TAU * i / carried.size()
		var pos := _bait_spot + Vector3(cos(angle), 0, sin(angle)) * 0.7 + Vector3.UP * 0.3
		run.host_spawn_loot(carried[i], pos, rng.randf_range(0, TAU))
	carried.clear()
	cart_load = 0


func _go_somewhere() -> void:
	if not patrol_points.is_empty():
		_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
	_timer = 25.0


func _move(speed: float) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if state == State.CHASE and _target != null and global_position.distance_to(_target.global_position) < 3.0:
		next = _target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if speed > 0.0 and direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.2)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.1)


@rpc("authority", "call_local", "reliable")
func _play(sound: String) -> void:
	Sfx.play_3d(get_parent(), global_position, sound, -2.0, 20.0, 0.8)


func _sounds(delta: float) -> void:
	if state == State.LURK and velocity.length() < 0.1:
		return
	_squeak -= delta
	if _squeak <= 0.0:
		_squeak = rng.randf_range(0.45, 0.7) if state != State.CHASE else 0.25
		Sfx.play_3d(get_parent(), global_position, "creak", -6.0, 20.0, rng.randf_range(1.7, 2.1))


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _apply_load() -> void:
	for i in _cart_pile.size():
		_cart_pile[i].visible = i < cart_load


func _build_model() -> void:
	var coat := PS1Materials.get_material("carpet", Color(0.35, 0.32, 0.25), true)
	var skin := PS1Materials.get_material("concrete", Color(0.6, 0.62, 0.55), true)
	var metal := PS1Materials.get_material("grate", Color(0.7, 0.7, 0.7), true)
	# A stooped body in a long coat, head hanging low.
	for side in [-1.0, 1.0]:
		MonsterKit.limb(self, Vector3(0.12 * side, 0.8, 0.15), Vector3(0.13, 0.8, 0.13), coat)
		var arm := MonsterKit.limb(self, Vector3(0.25 * side, 1.35, 0), Vector3(0.09, 0.7, 0.09), skin)
		arm.rotation.x = -1.0
	var torso := MonsterKit.box(self, Vector3(0.5, 0.75, 0.32), Vector3(0, 1.2, 0.05), coat)
	torso.rotation.x = -0.45
	MonsterKit.sphere(self, 0.16, Vector3(0, 1.45, -0.32), skin, Vector3(0.9, 1.1, 1.0))
	# The cart in front of it.
	MonsterKit.box(self, Vector3(0.7, 0.5, 0.9), Vector3(0, 0.75, -1.0), metal)
	MonsterKit.box(self, Vector3(0.6, 0.04, 0.04), Vector3(0, 1.05, -0.5), metal)
	for corner in [Vector3(-0.3, 0.12, -0.6), Vector3(0.3, 0.12, -0.6), Vector3(-0.3, 0.12, -1.4), Vector3(0.3, 0.12, -1.4)]:
		MonsterKit.sphere(self, 0.1, corner, skin)
	for x in [-0.45, -0.25, -0.05]:
		MonsterKit.box(self, Vector3(0.02, 0.5, 0.02), Vector3(x + 0.25, 0.5, -0.6), metal)
	# Junk piled in the cart, shown as it fills.
	for i in 6:
		var junk := MonsterKit.box(self, Vector3(0.22, 0.18, 0.2), Vector3(-0.18 + (i % 3) * 0.18, 1.05 + (i / 3) * 0.17, -1.0 + (i % 2) * 0.2),
			PS1Materials.get_material("brass", Color.from_hsv(i * 0.17, 0.5, 0.8), true))
		_cart_pile.append(junk)
