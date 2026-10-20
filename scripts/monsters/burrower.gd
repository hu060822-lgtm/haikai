class_name Burrower
extends CharacterBody3D
## 鐵甲穿山者: a pangolin the size of a van, plated in rusted iron scales, that swims
## through the floor. Dominates by SIZE and ABILITY: it moves under the tiles faster
## than you can run, it hears every footstep on the ground, and it comes up right under
## whoever made the noise.
## Weaknesses players can learn:
##   - It only hears the ground floor. Get up on a table, a catwalk, the stairs, and it
##     loses you. Crouch-walking is too quiet for it.
##   - Its back is armour: bullets ring off it. When it bursts out it rears up for a
##     moment, and its soft pale belly is the only place that hurts.
##   - Throw something: whatever lands loudest, it goes for.
## Tells: the floor ripples and cracks where it passes, and a low rumble you feel.

const LENGTH := 4.2
const HEIGHT := 1.7
const RADIUS := 1.0
const TUNNEL_SPEED := 2.4
const HUNT_SPEED := 6.2  # faster than a sprint
const HEARING := 1.3  # hears a noise from this times its radius
const FLOOR_ONLY := 1.6  # noises higher than this above its floor go unheard
const BURST_REACH := 1.4
const BURST_RADIUS := 2.3
const BURST_DAMAGE := 60.0
const REAR_TIME := 3.0
const SLAM_TIME := 0.6
const SLAM_REACH := 3.6
const DIVE_TIME := 1.1
const QUIET_TIME := 3.0  # after diving, it lies still listening
const HUNT_GIVE_UP := 12.0
const BELLY_HIT := 2.5
const ARMOR_HIT := 0.1
const HEAD_HIT := 0.6

enum State { TUNNEL, SURFACE, SLAM, DIVE, BROKEN }

## Replicated: what it is doing (underground, rearing, slamming, diving, flipped).
var state := State.TUNNEL:
	set(value):
		var changed := value != state
		state = value
		if is_node_ready():
			_apply_state(changed)
var hunting := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _collider: CollisionShape3D
var _pivot: Node3D
var _hinge: Node3D
var _model: Node3D
var _mound: Node3D
var _rubble: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _head: Node3D
var _rumble: AudioStreamPlayer3D
var _timer := 0.0
var _quiet := 0.0
var _goal := Vector3.INF
var _hunt_time := 0.0
var _wander := 0.0
var _rear := 0.0  # 0 flat .. 1 fully reared (animated on every peer)
var _ping := 0.0


func _ready() -> void:
	add_to_group("monsters")
	add_to_group("listeners")
	collision_mask = Layers.WORLD
	_collider = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RADIUS * 2.0, HEIGHT, LENGTH)
	_collider.shape = box
	_collider.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(_collider)
	_agent = NavigationAgent3D.new()
	# Underground it fits anywhere a person does.
	_agent.radius = 0.5
	_agent.path_desired_distance = 1.0
	_agent.target_desired_distance = 1.0
	add_child(_agent)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state", ".:hunting"])
	_apply_state(false)


func _physics_process(delta: float) -> void:
	if state == State.TUNNEL:
		velocity.y = 0.0  # under the floor: it follows the navmesh, nothing to fall through
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


## Footsteps, landings, thrown things: anything on its floor that it can hear.
func hear(position: Vector3, radius: float, _kind: int) -> void:
	if state != State.TUNNEL or _quiet > 0.0:
		return
	if position.y - global_position.y > FLOOR_ONLY or position.y < global_position.y - 2.0:
		return
	if position.distance_to(global_position) > radius * HEARING:
		return
	if _goal != Vector3.INF and hunting and _goal.distance_to(global_position) < position.distance_to(global_position) - 4.0:
		return  # keep after the nearer noise
	_goal = position
	_agent.target_position = position
	_hunt_time = 0.0
	hunting = true


## Host: a weapon hit it. Armour everywhere except the belly when it rears.
func on_hit(hit: Dictionary) -> float:
	var point: Vector3 = hit.get("point", global_position + Vector3.UP)
	var from: Vector3 = hit.get("from", point)
	var attacker: Player = hit.get("attacker") as Player
	match state:
		State.TUNNEL, State.DIVE:
			return 0.0
		State.BROKEN:
			return 1.0
		State.SURFACE:
			if is_belly_hit(point, from):
				if attacker != null and _ping <= 0.0:
					_ping = 1.0
					MonsterKit.tell(attacker, &"remote_warn", ["打中肚子了！那是它唯一的弱點。", 0.0])
				return BELLY_HIT
	_ring.rpc(point)
	if attacker != null and _ping <= 0.0:
		_ping = 4.0
		MonsterKit.tell(attacker, &"remote_warn", ["子彈從鐵甲上彈開了！等它立起來，打肚子。", 0.0])
	var local := global_transform.affine_inverse() * point
	return HEAD_HIT if local.z < -LENGTH * 0.4 and local.y < 1.2 else ARMOR_HIT


## True when it is reared up and the shot comes from in front at the height of its belly.
func is_belly_hit(point: Vector3, from: Vector3) -> bool:
	if state != State.SURFACE:
		return false
	var forward := -global_basis.z
	var to_shooter := from - global_position
	to_shooter.y = 0.0
	var local := global_transform.affine_inverse() * point
	return forward.dot(to_shooter.normalized()) > 0.2 and local.y > 0.6 and local.y < 3.6 and local.z < 0.6


## Host: it hit zero. It flips over, legs kicking, then burrows off to lick its plates.
func on_broken() -> void:
	state = State.BROKEN
	_timer = 1.0
	hunting = false
	_goal = Vector3.INF
	for player in MonsterKit.active_players(get_tree()):
		if player.global_position.distance_to(global_position) < 30.0:
			MonsterKit.tell(player, &"remote_warn", ["鐵甲穿山者翻倒了，四腳朝天亂踢！趁現在離開地面！", 0.4])


func _think(delta: float) -> void:
	_timer -= delta
	_quiet = maxf(_quiet - delta, 0.0)
	_ping = maxf(_ping - delta, 0.0)
	match state:
		State.TUNNEL:
			_tunnel(delta)
		State.SURFACE:
			_stand()
			var nearest := MonsterKit.nearest_player(self, 12.0)
			if nearest != null:
				var to := nearest.global_position - global_position
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 2.0 * delta)
			if _timer <= 0.0:
				state = State.SLAM
				_timer = SLAM_TIME
		State.SLAM:
			_stand()
			if _timer <= 0.0:
				_slam()
				state = State.DIVE
				_timer = DIVE_TIME
		State.DIVE:
			_stand()
			if _timer <= 0.0:
				state = State.TUNNEL
				_quiet = QUIET_TIME
		State.BROKEN:
			_stand()
			if _timer <= 0.0:
				state = State.DIVE
				_timer = DIVE_TIME


func _tunnel(delta: float) -> void:
	var speed := TUNNEL_SPEED
	if hunting:
		speed = HUNT_SPEED
		_hunt_time += delta
		var flat := Vector2(_goal.x - global_position.x, _goal.z - global_position.z)
		if flat.length() < BURST_REACH or (_agent.is_navigation_finished() and flat.length() < 3.0):
			_burst()
			return
		if _hunt_time > HUNT_GIVE_UP or _agent.is_navigation_finished():
			hunting = false
			_goal = Vector3.INF
	else:
		# Someone walking right over it is as good as a noise.
		for player in MonsterKit.active_players(get_tree()):
			var offset := player.global_position - global_position
			if Vector2(offset.x, offset.z).length() < 1.5 and absf(offset.y) < 1.0 and player.ground_speed > 2.0 and _quiet <= 0.0:
				_goal = player.global_position
				_burst()
				return
		_wander -= delta
		if (_agent.is_navigation_finished() or _wander <= 0.0) and not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
			_wander = 25.0
	if _quiet > 0.0:
		velocity = Vector3.ZERO
		return
	# Under the floor nothing stops it: it swims straight along the navmesh path,
	# under people, through gaps far too narrow for its body.
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		var step := minf(speed * delta, direction.length())
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		global_position += direction * step
		global_position.y = lerpf(global_position.y, next.y, minf(4.0 * delta, 1.0))
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 6.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## Up through the floor under the noise: everyone close is thrown.
func _burst() -> void:
	hunting = false
	var nearest := MonsterKit.nearest_player(self, 10.0)
	if nearest != null:
		var to := nearest.global_position - global_position
		if Vector2(to.x, to.z).length() > 0.3:
			rotation.y = atan2(-to.x, -to.z)
	state = State.SURFACE
	_timer = REAR_TIME
	_goal = Vector3.INF
	for player in MonsterKit.active_players(get_tree()):
		var offset := player.global_position - global_position
		var flat := Vector2(offset.x, offset.z).length()
		if flat < BURST_RADIUS and absf(offset.y) < 2.0:
			MonsterKit.tell(player, &"remote_damage", [BURST_DAMAGE, "被鐵甲穿山者從地底頂飛", "地板炸開了！有東西從底下衝出來！"])
		elif flat < 18.0:
			MonsterKit.tell(player, &"remote_warn", ["地板炸開，一隻披著鐵甲的巨獸立了起來！打它的肚子！", 0.7])


## The fall forward: whatever is in front of it is flattened.
func _slam() -> void:
	var forward := -global_basis.z
	_slam_fx.rpc(global_position + forward * 2.5)
	for player in MonsterKit.active_players(get_tree()):
		var offset := player.global_position - global_position
		offset.y = 0.0
		var ahead := offset.dot(forward)
		var side := (offset - forward * ahead).length()
		if ahead > -0.5 and ahead < SLAM_REACH + LENGTH * 0.4 and side < RADIUS + 0.6 \
				and absf(player.global_position.y - global_position.y) < 2.0:
			MonsterKit.tell(player, &"remote_damage", [999.0, "被鐵甲穿山者壓扁了"])


func _stand() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Runs on every peer when the state changes: what's above ground, sounds, debris.
func _apply_state(changed: bool) -> void:
	var under := state == State.TUNNEL
	_model.visible = not under
	_mound.visible = under
	collision_layer = 0 if under else Layers.MONSTER
	_collider.disabled = under
	if under:
		if not _rumble.playing:
			_rumble.play()
	else:
		_rumble.stop()
	if not changed:
		return
	match state:
		State.SURFACE:
			Sfx.play_3d(get_parent(), global_position, "boom", 4.0, 60.0, 0.6)
			Sfx.play_3d(get_parent(), global_position, "roar", 2.0, 50.0, 0.5)
			_debris(global_position, 30)
		State.DIVE:
			Sfx.play_3d(get_parent(), global_position, "rumble", 2.0, 40.0, 0.7)
			_debris(global_position, 14)
		State.BROKEN:
			Sfx.play_3d(get_parent(), global_position, "clank", 6.0, 50.0, 0.4)
			Sfx.play_3d(get_parent(), global_position, "screech", 2.0, 50.0, 0.4)


@rpc("authority", "call_local", "reliable")
func _slam_fx(at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, "boom", 6.0, 60.0, 0.5)
	_debris(at, 18)


@rpc("authority", "call_local", "unreliable")
func _ring(at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, "tink", 0.0, 30.0, rng.randf_range(0.7, 0.9))


## Chunks of floor tile and dirt thrown up.
func _debris(at: Vector3, amount: int) -> void:
	var parent := Run.instance if Run.instance != null else get_parent()
	if parent == null:
		return
	var bits := CPUParticles3D.new()
	bits.one_shot = true
	bits.amount = amount
	bits.lifetime = 1.4
	bits.explosiveness = 0.9
	bits.direction = Vector3.UP
	bits.spread = 50.0
	bits.initial_velocity_min = 4.0
	bits.initial_velocity_max = 8.0
	bits.gravity = Vector3(0, -14.0, 0)
	bits.angular_velocity_min = -300.0
	bits.angular_velocity_max = 300.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.06, 0.18)
	bits.mesh = mesh
	bits.material_override = PS1Materials.get_material("tile", Color(0.55, 0.5, 0.42))
	parent.add_child(bits)
	bits.global_position = at + Vector3.UP * 0.2
	bits.emitting = true
	get_tree().create_timer(2.0).timeout.connect(bits.queue_free)


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var target_rear := 0.0
	match state:
		State.SURFACE:
			target_rear = 1.0
		State.SLAM:
			target_rear = -0.1
		State.DIVE:
			target_rear = -0.35
	_rear = lerpf(_rear, target_rear, minf(delta * (10.0 if state == State.SLAM else 4.0), 1.0))
	_hinge.rotation.x = _rear * 0.8
	if state == State.DIVE:
		_pivot.position.y = lerpf(_pivot.position.y, -HEIGHT * 1.2, minf(delta * 2.5, 1.0))
	elif state == State.BROKEN:
		_pivot.position.y = lerpf(_pivot.position.y, HEIGHT * 1.15, minf(delta * 6.0, 1.0))
	else:
		_pivot.position.y = lerpf(_pivot.position.y, 0.0, minf(delta * 8.0, 1.0))
	# Belly up while broken.
	_pivot.rotation.z = lerp_angle(_pivot.rotation.z, PI if state == State.BROKEN else 0.0, minf(delta * 5.0, 1.0))
	for i in _legs.size():
		var kick := 0.9 if state == State.BROKEN else (0.25 if state == State.SURFACE and i < 2 else 0.0)
		_legs[i].rotation.x = sin(t * (14.0 if state == State.BROKEN else 5.0) + i * 1.6) * kick
	_head.rotation.y = sin(t * 1.3) * 0.25 if state == State.SURFACE else 0.0
	# The ripple: the mound humps and its rubble jostles; faster when it hunts.
	if _mound.visible:
		var speed := Vector2(velocity.x, velocity.z).length()
		var shake := 0.04 + speed * 0.015
		_mound.scale = Vector3(1.0, 0.8 + sin(t * 9.0) * 0.15 + speed * 0.05, 1.0)
		for i in _rubble.size():
			_rubble[i].position.y = 0.06 + absf(sin(t * 13.0 + i * 2.1)) * shake
			_rubble[i].rotation.y += delta * (i - 2.5)
		_rumble.pitch_scale = 0.6 + (0.25 if hunting else 0.0)


func _build_model() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3.ZERO
	add_child(_pivot)
	# The model hangs off a pivot at its hips so it can rear up on its hind legs.
	var hips := LENGTH * 0.3
	_model = Node3D.new()
	_model.position = Vector3(0, 0, -hips)
	_hinge = Node3D.new()
	_hinge.position = Vector3(0, 0, hips)
	_pivot.add_child(_hinge)
	_hinge.add_child(_model)
	var iron := PS1Materials.get_material("rust_metal", Color(0.9, 0.7, 0.52), true)
	var iron_dark := PS1Materials.get_material("rust_metal", Color(0.55, 0.43, 0.34), true)
	var belly := PS1Materials.get_material("concrete", Color(0.86, 0.72, 0.66), true)
	var belly_fold := PS1Materials.get_material("concrete", Color(0.66, 0.5, 0.46), true)
	var claw := PS1Materials.get_material("concrete", Color(0.15, 0.13, 0.11), true)
	var mouth := PS1Materials.get_material("concrete", Color(0.25, 0.03, 0.03), true, Vector2.ONE, Color(0.3, 0.02, 0.0))
	var teeth := PS1Materials.get_material("concrete", Color(0.85, 0.82, 0.7), true)
	# The soft pale belly underneath: a long ridged sausage of a body.
	var body_path := PackedVector3Array()
	var body_radii := PackedFloat32Array()
	for i in 7:
		var f := i / 6.0
		body_path.append(Vector3(0, 0.85 + sin(f * PI) * 0.1, LENGTH * (f - 0.5)))
		body_radii.append(0.35 + sin(f * PI) * 0.45)
	MonsterKit.part(_model, _uv(LowPoly.tube(body_path, body_radii, 7)), Vector3.ZERO, belly, Vector3.ZERO, Vector3(1.0, 0.9, 1.0))
	var folds := []
	for i in 6:
		var z := LENGTH * (-0.36 + i * 0.13)
		folds.append([LowPoly.prism(8, 0.5, 0.5, 0.05), LowPoly.at(Vector3(0, 0.62, z), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.55))])
	MonsterKit.part(_model, LowPoly.merge(folds), Vector3.ZERO, belly_fold)
	# Overlapping iron plates over the back, each a thick half-ring, biggest in the middle.
	for i in 9:
		var f := i / 8.0
		var r := 0.55 + sin(f * PI) * 0.55
		var outline := PackedVector2Array()
		var steps := 7
		for k in steps + 1:
			var a := deg_to_rad(-20.0 + 220.0 * k / steps)
			outline.append(Vector2(cos(a) * r, sin(a) * r))
		for k in range(steps, -1, -1):
			var a := deg_to_rad(-20.0 + 220.0 * k / steps)
			outline.append(Vector2(cos(a) * (r - 0.13), sin(a) * (r - 0.13)))
		var z := LENGTH * (f - 0.5) * 0.92
		MonsterKit.part(_model, _uv(LowPoly.extrude(outline, 0.55)), Vector3(0, 0.8 + sin(f * PI) * 0.12, z),
			iron if i % 2 == 0 else iron_dark, Vector3(-8, 0, 0))
		# A ridge spike down the spine of each plate.
		MonsterKit.part(_model, LowPoly.prism(4, 0.09, 0.0, 0.22), Vector3(0, 0.8 + sin(f * PI) * 0.12 + r + 0.05, z + 0.1), iron_dark, Vector3(-30, 45, 0))
	# The tail: smaller plates tapering off behind.
	for i in 4:
		var r := 0.4 - i * 0.08
		var outline := PackedVector2Array()
		for k in 6:
			var a := deg_to_rad(-20.0 + 220.0 * k / 5)
			outline.append(Vector2(cos(a) * r, sin(a) * r))
		for k in range(5, -1, -1):
			var a := deg_to_rad(-20.0 + 220.0 * k / 5)
			outline.append(Vector2(cos(a) * (r - 0.1), sin(a) * (r - 0.1)))
		MonsterKit.part(_model, _uv(LowPoly.extrude(outline, 0.4)), Vector3(0, 0.6 - i * 0.12, LENGTH * 0.5 + 0.3 + i * 0.35), iron, Vector3(15 + i * 5, 0, 0))
	# Four thick legs with huge digging claws on the front pair.
	var legs := [[Vector3(0.6, 0.7, -LENGTH * 0.3), 1.0, true], [Vector3(-0.6, 0.7, -LENGTH * 0.3), -1.0, true],
		[Vector3(0.6, 0.7, LENGTH * 0.28), 1.0, false], [Vector3(-0.6, 0.7, LENGTH * 0.28), -1.0, false]]
	for leg_def: Array in legs:
		var side: float = leg_def[1]
		var front: bool = leg_def[2]
		var leg := Node3D.new()
		leg.position = leg_def[0]
		_model.add_child(leg)
		var knee := Vector3(0.25 * side, -0.35, -0.1)
		var paw := Vector3(0.3 * side, -0.68, -0.15)
		MonsterKit.part(leg, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, knee, paw]),
			PackedFloat32Array([0.26, 0.2, 0.17]), 6)), Vector3.ZERO, iron_dark)
		var claws := []
		var count := 3 if front else 2
		for k in count:
			var a := (k - (count - 1) / 2.0) * 0.35
			var length := 0.55 if front else 0.3
			var tip := paw + Vector3(sin(a) * 0.25, -0.02, -length)
			claws.append([LowPoly.tube(PackedVector3Array([paw + Vector3(sin(a) * 0.1, 0.0, -0.05), paw.lerp(tip, 0.6) + Vector3(0, 0.08, 0), tip]),
				PackedFloat32Array([0.07, 0.05, 0.0]), 4), Transform3D.IDENTITY])
		MonsterKit.part(leg, LowPoly.merge(claws), Vector3.ZERO, claw)
		_legs.append(leg)
	# A long eyeless snout ending in a round mouth ringed with teeth.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.75, -LENGTH * 0.5 - 0.1)
	_model.add_child(_head)
	var snout := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.42, 0.05), Vector2(0.4, 0.4),
		Vector2(0.3, 0.75), Vector2(0.22, 0.95), Vector2(0.2, 1.0)])
	MonsterKit.part(_head, _uv(LowPoly.lathe(snout, 7)), Vector3.ZERO, belly, Vector3(-90, 0, 0), Vector3(1.0, 1.0, 0.85))
	for i in 3:
		MonsterKit.part(_head, _uv(LowPoly.prism(7, 0.42 - i * 0.07, 0.38 - i * 0.07, 0.18)), Vector3(0, 0.08, -0.15 - i * 0.24), iron, Vector3(-90 - i * 4, 0, 0), Vector3(1.05, 1.0, 0.95))
	MonsterKit.part(_head, LowPoly.prism(8, 0.17, 0.17, 0.03), Vector3(0, 0, -1.0), mouth, Vector3(90, 0, 0))
	var ring := []
	for k in 8:
		var a := TAU * k / 8.0
		ring.append([LowPoly.prism(3, 0.04, 0.0, 0.12), LowPoly.at(Vector3(cos(a) * 0.16, sin(a) * 0.16, -1.0), Vector3(-90, 0, 0))])
	MonsterKit.part(_head, LowPoly.merge(ring), Vector3.ZERO, teeth)
	# The ripple it leaves while it swims under the floor: a hump of cracked tile and dirt.
	_mound = Node3D.new()
	add_child(_mound)
	var dirt := PS1Materials.get_material("concrete", Color(0.55, 0.45, 0.33), true)
	var tile := PS1Materials.get_material("concrete", Color(0.75, 0.72, 0.64), true)
	MonsterKit.part(_mound, _uv(LowPoly.blob(0.9, Vector3(1.0, 0.22, 1.6), 1, 0.25, 8)), Vector3(0, 0.0, 0), dirt)
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var reach := 0.45 if i % 2 == 0 else 0.85
		var bit := Node3D.new()
		bit.position = Vector3(cos(a) * reach, 0.06, sin(a) * reach * 1.6)
		_mound.add_child(bit)
		MonsterKit.part(bit, LowPoly.chamfer_box(Vector3(0.42, 0.07, 0.36), 0.015), Vector3.ZERO, tile, Vector3(rng.randf_range(-35, 35), i * 37.0, rng.randf_range(-35, 35)))
		_rubble.append(bit)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = Sfx.looped("rumble")
	_rumble.volume_db = 2.0
	_rumble.max_distance = 30.0
	_rumble.unit_size = 4.0
	_rumble.pitch_scale = 0.6
	add_child(_rumble)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 4.0)
