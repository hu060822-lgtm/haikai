class_name Mannequin
extends CharacterBody3D
## 假人: a shop-window dummy. Dominates by ABILITY: while nobody is looking at it, it
## moves faster than anyone can run, and its touch knocks you flat.
## Weakness players can learn: it cannot move while any player is watching it,
## so a team can keep it frozen by taking turns staring.

const HEIGHT := 1.9
const RADIUS := 0.35
const SPEED := 7.0
const WANDER_SPEED := 2.5
const HUNT_RANGE := 30.0
const SEEN_RANGE_LIT := 22.0
const SEEN_RANGE_DARK := 6.0
const VIEW_HALF_ANGLE_DEG := 38.0
const HIT_DISTANCE := 0.9
const HIT_DAMAGE := 70.0
const HIT_COOLDOWN := 4.0
const POSE_COUNT := 5

## Replicated: which frozen pose it holds, and whether it is moving (for the creaks).
var pose := 0:
	set(value):
		pose = value
		if is_node_ready():
			_apply_pose()
var moving := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _head: Node3D
var _creak_timer := 0.0
var _hit_cooldown := 0.0
var _wander_time := 0.0
var _shrug := 0.0


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
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:pose", ".:moving"])
	_apply_pose()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_sounds(delta)


## Host: a weapon hit it. While anyone watches it, it is only a dummy: plaster that
## won't break. Caught moving (nobody looking, or shot from the dark), it shatters easily.
func on_hit(hit: Dictionary) -> float:
	if is_watched():
		var attacker: Player = hit.get("attacker") as Player
		if attacker != null and _shrug <= 0.0:
			_shrug = 6.0
			MonsterKit.tell(attacker, &"remote_warn", ["子彈打在石膏上彈開了…被看著的時候，它只是個假人。", 0.0])
		_play_chip.rpc()
		return 0.0
	return 1.5


@rpc("authority", "call_local", "unreliable")
func _play_chip() -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.2, "tink", -4.0, 20.0, 1.4)


func _think(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_shrug = maxf(_shrug - delta, 0.0)
	if is_watched():
		if moving:
			moving = false
			pose = (pose + 1 + rng.randi_range(0, POSE_COUNT - 2)) % POSE_COUNT
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var target := MonsterKit.nearest_player(self, MonsterKit.sight(HUNT_RANGE))
	var speed := SPEED
	if target != null:
		_agent.target_position = target.global_position
	else:
		speed = WANDER_SPEED
		_wander_time -= delta
		if (_agent.is_navigation_finished() or _wander_time <= 0.0) and not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
			_wander_time = 15.0

	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if target != null and global_position.distance_to(target.global_position) < 3.0 \
			and absf(target.global_position.y - global_position.y) < 1.0:
		next = target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# It snaps to face you instead of turning: there is nothing natural about it.
		rotation.y = atan2(-direction.x, -direction.z)
		moving = true
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		moving = false
	move_and_slide()

	if target != null and _hit_cooldown <= 0.0:
		var offset := target.global_position - global_position
		if Vector2(offset.x, offset.z).length() < HIT_DISTANCE + Player.RADIUS and absf(offset.y) < 1.2:
			_hit(target)


## True while any active player has it in view and in the light.
func is_watched() -> bool:
	var chest := global_position + Vector3.UP * (HEIGHT * 0.6)
	for player in MonsterKit.active_players(get_tree()):
		var eye := player.head_position()
		var to := chest - eye
		var distance := to.length()
		var seen_range := SEEN_RANGE_LIT if player.is_lit() else SEEN_RANGE_DARK
		if distance > seen_range:
			continue
		if player.look_direction().dot(to / maxf(distance, 0.01)) < cos(deg_to_rad(VIEW_HALF_ANGLE_DEG)):
			continue
		if MonsterKit.clear_line(get_world_3d(), eye, chest, [get_rid()]):
			return true
	return false


func _hit(player: Player) -> void:
	_hit_cooldown = HIT_COOLDOWN
	MonsterKit.tell(player, &"remote_damage", [HIT_DAMAGE, "被假人碰到了", "假人撞倒了你！別讓它離開視線"])
	_play_hit.rpc()
	# It isn't there anymore when you get up.
	if not patrol_points.is_empty():
		var far := global_position
		for point in patrol_points:
			if point.distance_to(player.global_position) > far.distance_to(player.global_position):
				far = point
		global_position = far + Vector3.UP * 0.1
	moving = false


@rpc("authority", "call_local", "reliable")
func _play_hit() -> void:
	Sfx.play_3d(get_parent(), global_position, "bite", 0.0, 25.0, 0.6)


func _sounds(delta: float) -> void:
	if not moving:
		_creak_timer = 0.0
		return
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = rng.randf_range(0.35, 0.6)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP, "creak", -4.0, 22.0, rng.randf_range(0.8, 1.2))
	# Arms swing stiffly while it runs.
	var t := Time.get_ticks_msec() * 0.02
	_legs[0].rotation.x = sin(t) * 0.7
	_legs[1].rotation.x = -sin(t) * 0.7


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Five frozen poses; each time you look back it holds a different one.
func _apply_pose() -> void:
	var poses := [
		[Vector3(0, 0, 0.15), Vector3(0, 0, -0.15), 0.0, 0.0],
		[Vector3(-1.4, 0, 0.2), Vector3(-1.4, 0, -0.2), 0.0, 0.2],      # reaching
		[Vector3(-2.9, 0, 0.1), Vector3(0.3, 0, -0.3), 0.6, -0.1],      # one arm up
		[Vector3(-0.6, 0.4, 0.9), Vector3(-0.6, -0.4, -0.9), -0.5, 0.3], # crouched, head tilted
		[Vector3(0.4, 0, 1.4), Vector3(0.4, 0, -1.4), 0.0, -0.4],        # arms out like a cross
	]
	var p: Array = poses[pose % poses.size()]
	_arms[0].rotation = p[0]
	_arms[1].rotation = p[1]
	_head.rotation.z = p[2]
	_model.rotation.x = p[3] * 0.3
	_legs[0].rotation.x = 0.0
	_legs[1].rotation.x = 0.0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var plastic := PS1Materials.get_material("concrete", Color(0.92, 0.88, 0.82))
	var joint := PS1Materials.get_material("rust_metal", Color(0.4, 0.35, 0.3))
	var paper := PS1Materials.get_material("concrete", Color(0.85, 0.8, 0.62))
	# One moulded shell from hips to shoulders, flattened front to back like a shop dummy.
	var torso := PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.15, 0.82), Vector2(0.19, 0.9),
		Vector2(0.16, 0.99), Vector2(0.145, 1.08), Vector2(0.19, 1.24), Vector2(0.215, 1.4),
		Vector2(0.205, 1.52), Vector2(0.12, 1.6), Vector2(0.0, 1.63)])
	MonsterKit.part(_model, LowPoly.lathe(torso, 8), Vector3.ZERO, plastic, Vector3(0, 22.5, 0), Vector3(1, 1, 0.6))
	# The seam where the torso twists off the hips, and the bolt-on neck.
	MonsterKit.part(_model, LowPoly.prism(8, 0.158, 0.158, 0.03), Vector3(0, 1.035, 0), joint, Vector3(0, 22.5, 0), Vector3(1, 1, 0.62))
	MonsterKit.part(_model, LowPoly.prism(6, 0.05, 0.042, 0.14), Vector3(0, 1.67, 0), joint)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.74, 0)
	_model.add_child(_head)
	# A smooth egg with no face: only the ghost of a nose and a chin.
	var egg := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.07, 0.015), Vector2(0.12, 0.07),
		Vector2(0.14, 0.15), Vector2(0.135, 0.23), Vector2(0.1, 0.3), Vector2(0.05, 0.34), Vector2(0.0, 0.355)])
	MonsterKit.part(_head, LowPoly.lathe(egg, 8), Vector3.ZERO, plastic, Vector3(0, 22.5, 0), Vector3(1, 1, 1.05))
	MonsterKit.part(_head, LowPoly.blob(0.032, Vector3(0.55, 1.3, 0.8), 0), Vector3(0, 0.16, -0.132), plastic)
	MonsterKit.part(_head, LowPoly.blob(0.05, Vector3(1.0, 0.6, 0.8), 0), Vector3(0, 0.05, -0.1), plastic)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.27 * side, 1.6, 0)
		_model.add_child(arm)
		_arms.append(arm)
		_build_arm(arm, side, plastic, joint, paper)
		var leg := Node3D.new()
		leg.position = Vector3(0.11 * side, 0.84, 0)
		_model.add_child(leg)
		_legs.append(leg)
		_build_leg(leg, plastic, joint)
	# The pole stand it was taken off of still sticks out of its back.
	MonsterKit.part(_model, LowPoly.prism(8, 0.06, 0.06, 0.025), Vector3(0, 1.1, 0.1), joint, Vector3(90, 0, 0))
	MonsterKit.part(_model, LowPoly.prism(6, 0.022, 0.022, 0.34), Vector3(0, 1.1, 0.27), joint, Vector3(90, 0, 0))
	MonsterKit.part(_model, LowPoly.chamfer_box(Vector3(0.08, 0.06, 0.05), 0.012), Vector3(0, 1.1, 0.44), joint)


## A jointed plastic arm hanging from its shoulder pivot, hand and all.
func _build_arm(arm: Node3D, side: float, plastic: Material, joint: Material, paper: Material) -> void:
	MonsterKit.part(arm, LowPoly.blob(0.058, Vector3.ONE, 0), Vector3.ZERO, joint)
	MonsterKit.part(arm, LowPoly.tube(PackedVector3Array([Vector3(0, 0.0, 0), Vector3(0, -0.17, 0.005),
		Vector3(0, -0.34, 0)]), PackedFloat32Array([0.055, 0.05, 0.042]), 6), Vector3.ZERO, plastic)
	MonsterKit.part(arm, LowPoly.tube(PackedVector3Array([Vector3(0, -0.34, 0), Vector3(0, -0.5, -0.025),
		Vector3(0, -0.63, -0.035)]), PackedFloat32Array([0.042, 0.037, 0.029]), 6), Vector3.ZERO, plastic)
	# The hands twist off at the wrist.
	MonsterKit.part(arm, LowPoly.prism(6, 0.034, 0.034, 0.018), Vector3(0, -0.632, -0.035), joint)
	var hand := PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.032, -0.07), Vector2(0.026, -0.13),
		Vector2(0.006, -0.15), Vector2(-0.018, -0.13), Vector2(-0.026, -0.07), Vector2(-0.05, -0.085),
		Vector2(-0.058, -0.065), Vector2(-0.03, -0.012)])
	MonsterKit.part(arm, LowPoly.extrude(hand, 0.03), Vector3(0, -0.638, -0.035), plastic, Vector3(0, -90, 0))
	if side < 0.0:
		# A price tag still hangs off one wrist.
		MonsterKit.part(arm, LowPoly.prism(3, 0.004, 0.004, 0.06), Vector3(0.035, -0.66, -0.035), paper)
		MonsterKit.part(arm, LowPoly.chamfer_box(Vector3(0.006, 0.05, 0.035), 0.003), Vector3(0.04, -0.71, -0.035), paper, Vector3(0, 0, 8))


## A leg hanging from its hip pivot: thigh, knee, shin and a pointed display foot.
func _build_leg(leg: Node3D, plastic: Material, joint: Material) -> void:
	MonsterKit.part(leg, LowPoly.tube(PackedVector3Array([Vector3(0, 0.03, 0), Vector3(0, -0.2, -0.008),
		Vector3(0, -0.41, 0)]), PackedFloat32Array([0.085, 0.075, 0.055]), 6), Vector3.ZERO, plastic)
	MonsterKit.part(leg, LowPoly.blob(0.056, Vector3(1.0, 0.9, 1.05), 0), Vector3(0, -0.41, -0.005), plastic)
	MonsterKit.part(leg, LowPoly.tube(PackedVector3Array([Vector3(0, -0.41, 0), Vector3(0, -0.56, 0.012),
		Vector3(0, -0.77, 0)]), PackedFloat32Array([0.054, 0.048, 0.034]), 6), Vector3.ZERO, plastic)
	MonsterKit.part(leg, LowPoly.prism(6, 0.037, 0.037, 0.016), Vector3(0, -0.765, 0), joint)
	var foot := PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.15, 0.0), Vector2(0.18, 0.015),
		Vector2(0.1, 0.045), Vector2(0.03, 0.085), Vector2(-0.03, 0.09), Vector2(-0.06, 0.05)])
	MonsterKit.part(leg, LowPoly.extrude(foot, 0.08), Vector3(0, -0.84, 0), plastic, Vector3(0, 90, 0))
