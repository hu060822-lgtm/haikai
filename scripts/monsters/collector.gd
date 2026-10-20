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
		var sight := SIGHT_LIT if player.is_lit() else SIGHT_DARK
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
	var coat := PS1Materials.get_material("carpet", Color(0.35, 0.32, 0.25))
	var patch := PS1Materials.get_material("carpet", Color(0.24, 0.22, 0.17))
	var skin := PS1Materials.get_material("concrete", Color(0.6, 0.62, 0.55))
	var dark := PS1Materials.get_material("concrete", Color(0.04, 0.04, 0.03))
	var boot := PS1Materials.get_material("concrete", Color(0.18, 0.13, 0.09))
	var metal := PS1Materials.get_material("grate", Color(0.7, 0.7, 0.7))
	var frame := PS1Materials.get_material("rust_metal", Color(0.75, 0.72, 0.68))
	var rubber := PS1Materials.get_material("concrete", Color(0.1, 0.1, 0.1))
	# Bent legs in baggy trousers and split boots, under the coat.
	var boot_outline := PackedVector2Array([Vector2(-0.08, 0.0), Vector2(0.16, 0.0), Vector2(0.17, 0.05),
		Vector2(0.08, 0.1), Vector2(0.02, 0.17), Vector2(-0.07, 0.17)])
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.12 * side, 0.8, 0.15)
		add_child(leg)
		MonsterKit.part(leg, LowPoly.tube(PackedVector3Array([Vector3(0, 0.05, 0), Vector3(0.01 * side, -0.38, -0.09),
			Vector3(0, -0.7, 0.0)]), PackedFloat32Array([0.085, 0.075, 0.062]), 6), Vector3.ZERO, patch)
		MonsterKit.part(leg, LowPoly.extrude(boot_outline, 0.12), Vector3(0, -0.8, 0.02), boot, Vector3(0, 90 + 8 * side, 0))
	# A long coat: the skirt hangs from the hips, the upper body bends over the cart.
	var skirt := PackedVector2Array([Vector2(0.3, -0.58), Vector2(0.26, -0.3), Vector2(0.21, 0.0)])
	MonsterKit.part(self, LowPoly.lathe(skirt, 7, 0.12), Vector3(0, 0.93, 0.1), coat, Vector3(-6, 0, 0), Vector3(1, 1, 0.85))
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.9, 0.1)
	torso.rotation.x = -0.5
	add_child(torso)
	var chest := PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.21, 0.0), Vector2(0.24, 0.25),
		Vector2(0.27, 0.45), Vector2(0.22, 0.58), Vector2(0.1, 0.64), Vector2(0.0, 0.65)])
	MonsterKit.part(torso, LowPoly.lathe(chest, 7), Vector3.ZERO, coat, Vector3.ZERO, Vector3(1, 1, 0.75))
	# The hump, a patched elbow of cloth on the back, a belt of rope.
	MonsterKit.part(torso, LowPoly.blob(0.2, Vector3(1.15, 0.9, 0.8), 0, 0.15, 7), Vector3(0, 0.44, 0.1), coat)
	MonsterKit.part(torso, LowPoly.chamfer_box(Vector3(0.16, 0.14, 0.03), 0.01), Vector3(0.06, 0.36, 0.22), patch, Vector3(-10, 0, 9))
	MonsterKit.part(torso, LowPoly.prism(7, 0.225, 0.225, 0.04), Vector3(0, 0.04, 0), boot, Vector3.ZERO, Vector3(1, 1, 0.78))
	# A scarf wound round the neck, and the head hanging low, a flat cap pulled down.
	MonsterKit.part(torso, LowPoly.prism(7, 0.14, 0.11, 0.1), Vector3(0, 0.62, -0.04), patch)
	MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(0, 1.42, -0.18), Vector3(0, 1.43, -0.26),
		Vector3(0, 1.4, -0.31)]), PackedFloat32Array([0.055, 0.05, 0.05]), 6), Vector3.ZERO, skin)
	var head := Node3D.new()
	head.position = Vector3(0, 1.4, -0.35)
	head.rotation.x = -0.45
	add_child(head)
	MonsterKit.part(head, LowPoly.blob(0.15, Vector3(0.85, 1.05, 0.95), 1, 0.1, 11), Vector3.ZERO, skin)
	MonsterKit.part(head, LowPoly.blob(0.06, Vector3(1.1, 0.8, 1.0), 0, 0.1, 2), Vector3(0, -0.11, -0.06), skin)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(head, LowPoly.blob(0.03, Vector3(1.2, 0.8, 0.6), 0), Vector3(0.05 * side, 0.0, -0.13), dark)
		MonsterKit.part(head, LowPoly.blob(0.035, Vector3(0.4, 1.0, 0.7), 0), Vector3(0.13 * side, 0.0, 0.0), skin)
	MonsterKit.part(head, LowPoly.prism(8, 0.135, 0.125, 0.07), Vector3(0, 0.09, 0.0), patch, Vector3.ZERO, Vector3(1, 1, 1.05))
	MonsterKit.part(head, LowPoly.prism(8, 0.11, 0.11, 0.015), Vector3(0, 0.06, -0.12), patch, Vector3(-8, 0, 0), Vector3(1.3, 1, 0.9))
	# Long arms reaching down to the handle, bony fingers wrapped round it.
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(0.25 * side, 1.34, -0.1), Vector3(0.33 * side, 1.13, -0.24),
			Vector3(0.3 * side, 1.07, -0.4)]), PackedFloat32Array([0.075, 0.062, 0.055]), 6), Vector3.ZERO, coat)
		MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(0.3 * side, 1.07, -0.39), Vector3(0.29 * side, 1.07, -0.47)]),
			PackedFloat32Array([0.038, 0.032]), 5), Vector3.ZERO, skin)
		MonsterKit.part(self, LowPoly.blob(0.045, Vector3(1.0, 0.75, 1.1), 0), Vector3(0.28 * side, 1.08, -0.49), skin)
		for f in 3:
			var x := (0.25 + 0.025 * f) * side
			MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(x, 1.09, -0.48), Vector3(x, 1.085, -0.53),
				Vector3(x, 1.035, -0.535)]), PackedFloat32Array([0.012, 0.011, 0.008]), 3), Vector3.ZERO, skin)
	_build_cart(metal, frame, rubber)
	# Junk piled in the cart, shown as it fills.
	var junk_meshes := [
		LowPoly.chamfer_box(Vector3(0.24, 0.18, 0.2), 0.03),
		LowPoly.lathe(PackedVector2Array([Vector2(0.0, -0.13), Vector2(0.06, -0.13), Vector2(0.065, 0.02),
			Vector2(0.025, 0.07), Vector2(0.022, 0.13), Vector2(0.0, 0.13)]), 6),
		LowPoly.prism(8, 0.075, 0.075, 0.17),
		LowPoly.blob(0.13, Vector3(1.0, 0.75, 0.9), 1, 0.22, 5),
		LowPoly.merge([[LowPoly.chamfer_box(Vector3(0.24, 0.14, 0.1), 0.02), Transform3D.IDENTITY],
			[LowPoly.prism(6, 0.006, 0.006, 0.2), LowPoly.at(Vector3(0.08, 0.15, 0), Vector3(0, 0, -15))]]),
		LowPoly.lathe(PackedVector2Array([Vector2(0.0, -0.1), Vector2(0.06, -0.1), Vector2(0.1, 0.0),
			Vector2(0.07, 0.08), Vector2(0.09, 0.11), Vector2(0.0, 0.11)]), 7),
	]
	var junk_rot := [Vector3(0, 12, 0), Vector3(0, 0, 70), Vector3(15, 0, 0), Vector3(0, 40, 0), Vector3(-12, -25, 0), Vector3(0, 0, -20)]
	for i in 6:
		var junk := MonsterKit.part(self, junk_meshes[i], Vector3(-0.18 + (i % 3) * 0.18, 0.98 + (i / 3) * 0.16, -1.0 + (i % 2) * 0.2),
			PS1Materials.get_material("brass", Color.from_hsv(i * 0.17, 0.5, 0.8)), junk_rot[i])
		_cart_pile.append(junk)


## A battered shopping cart in front of it: wire basket, push bar, crooked castors.
func _build_cart(metal: Material, frame: Material, rubber: Material) -> void:
	MonsterKit.part(self, _panel(Vector3(0.6, 0.03, 0.8)), Vector3(0, 0.52, -1.0), metal)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(self, _panel(Vector3(0.025, 0.48, 0.88)), Vector3(0.33 * side, 0.76, -1.0), metal, Vector3(0, 0, -7 * side))
	MonsterKit.part(self, _panel(Vector3(0.7, 0.48, 0.025)), Vector3(0, 0.76, -0.57), metal, Vector3(-7, 0, 0))
	MonsterKit.part(self, _panel(Vector3(0.7, 0.48, 0.025)), Vector3(0, 0.76, -1.43), metal, Vector3(7, 0, 0))
	# Tubular rim round the top of the basket.
	var rim := PackedVector3Array([Vector3(-0.36, 1.0, -0.54), Vector3(0.36, 1.0, -0.54), Vector3(0.36, 1.0, -1.46),
		Vector3(-0.36, 1.0, -1.46), Vector3(-0.36, 1.0, -0.54)])
	MonsterKit.part(self, LowPoly.tube(rim, PackedFloat32Array([0.018, 0.018, 0.018, 0.018, 0.018]), 5), Vector3.ZERO, frame)
	# The push bar with its rubber grips, braced down to the basket.
	MonsterKit.part(self, LowPoly.prism(6, 0.022, 0.022, 0.68), Vector3(0, 1.05, -0.5), frame, Vector3(0, 0, 90))
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(self, LowPoly.prism(6, 0.03, 0.03, 0.13), Vector3(0.27 * side, 1.05, -0.5), rubber, Vector3(0, 0, 90))
		MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(0.34 * side, 1.05, -0.5), Vector3(0.36 * side, 1.0, -0.55),
			Vector3(0.3 * side, 0.52, -0.6), Vector3(0.27 * side, 0.2, -0.6)]), PackedFloat32Array([0.018, 0.018, 0.018, 0.018]), 5), Vector3.ZERO, frame)
		MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(0.3 * side, 0.52, -1.4), Vector3(0.27 * side, 0.2, -1.4)]),
			PackedFloat32Array([0.018, 0.018]), 5), Vector3.ZERO, frame)
		MonsterKit.part(self, LowPoly.tube(PackedVector3Array([Vector3(0.27 * side, 0.2, -0.6), Vector3(0.27 * side, 0.2, -1.4)]),
			PackedFloat32Array([0.02, 0.02]), 5), Vector3.ZERO, frame)
	# The bottom tray, and four castors, one of them twisted (that's the squeak).
	MonsterKit.part(self, _panel(Vector3(0.52, 0.02, 0.7)), Vector3(0, 0.23, -1.0), metal)
	var twist := [0.0, 0.0, 0.0, 28.0]
	var corners := [Vector3(-0.27, 0.12, -0.6), Vector3(0.27, 0.12, -0.6), Vector3(-0.27, 0.12, -1.4), Vector3(0.27, 0.12, -1.4)]
	for i in 4:
		var castor := Node3D.new()
		castor.position = corners[i]
		castor.rotation_degrees.y = twist[i]
		add_child(castor)
		MonsterKit.part(castor, _panel(Vector3(0.07, 0.1, 0.03)), Vector3(0, 0.06, 0), frame)
		MonsterKit.part(castor, LowPoly.prism(8, 0.1, 0.1, 0.05), Vector3(0, -0.02, 0.02), rubber, Vector3(0, 0, 90))


## A flat sheet with square edges (12 triangles): the cart's wire panels and tray.
static func _panel(size: Vector3) -> ArrayMesh:
	var h := size / 2.0
	return LowPoly.extrude(PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]), size.z)
