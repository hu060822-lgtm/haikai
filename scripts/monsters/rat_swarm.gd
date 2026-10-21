class_name RatSwarm
extends CharacterBody3D
## 發條鼠群: a pack of wind-up tin rats. Dominates by ABILITY (numbers): they swarm you,
## nip at your ankles and tear things out of your backpack, then drag them off to
## their nest.
## Weaknesses players can learn:
##   - They can't resist loose loot: throw something down and they all go for it.
##   - They hate vibration: land a jump or slam something near them and they scatter.
## Tell: a swarm of tiny clockwork ticks.

const RAT_COUNT := 7
const RADIUS := 0.3
const WANDER_SPEED := 1.5
const RUSH_SPEED := 5.0
const NOTICE_RANGE := 10.0
const LOOT_RANGE := 7.0
const BITE_RANGE := 1.3
const BITE_INTERVAL := 0.5
const BITE_DAMAGE := 2.0
const ROB_INTERVAL := 2.5
const SCATTER_RANGE := 7.0
const SCATTER_TIME := 6.0
const MAX_CARRY := 3

enum State { WANDER, RUSH, FETCH, HOME, SCATTER }

## Replicated so clients animate the rats and hear them.
var state := State.WANDER
## Replicated: how many rats are still running (shot ones stop).
var rats_left := RAT_COUNT:
	set(value):
		rats_left = value
		if is_node_ready():
			for i in _rats.size():
				_rats[i].visible = i < value
var home := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var carried: Array[Dictionary] = []

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _rats: Array[Node3D] = []
var _target: Player = null
var _fetch: LootItem = null
var _timer := 0.0
var _bite_timer := 0.0
var _rob_timer := ROB_INTERVAL
var _tick_timer := 0.0


func _ready() -> void:
	add_to_group("monsters")
	add_to_group("listeners")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	collider.shape = sphere
	collider.position.y = RADIUS
	add_child(collider)
	_agent = NavigationAgent3D.new()
	_agent.radius = RADIUS
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.5
	add_child(_agent)
	if home == Vector3.ZERO:
		home = global_position
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state", ".:rats_left"])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


## Vibration scares them off: a landing or an impact close by.
func hear(position: Vector3, _radius: float, kind: int) -> void:
	if kind != GameNoise.Kind.LANDING and kind != GameNoise.Kind.IMPACT:
		return
	if position.distance_to(global_position) < SCATTER_RANGE:
		scatter()


## Host: a weapon hit the pack. A few rats stop ticking; the rest scatter and regroup.
## Blasts and electricity (through all that tin) are what really work.
func on_hit(_hit: Dictionary) -> float:
	scatter()
	return 1.0


## Host: the last of them is down. Whatever they carried is left where they fell.
func host_kill() -> void:
	if is_queued_for_deletion():
		return
	var run := Run.instance
	if run != null:
		for data in carried:
			run.host_spawn_loot(data, global_position + Vector3.UP * 0.3, rng.randf_range(0, TAU))
	carried.clear()
	_play.rpc("clank", 0.8)
	queue_free()


func scatter() -> void:
	if state == State.SCATTER:
		return
	state = State.SCATTER
	_timer = SCATTER_TIME
	_target = null
	_agent.target_position = home
	_play.rpc("clank", 1.6)


func _think(delta: float) -> void:
	_timer -= delta
	if has_meta("hp"):
		var left := clampi(ceili(RAT_COUNT * float(get_meta("hp")) / maxf(float(get_meta("max_hp", 1.0)), 1.0)), 1, RAT_COUNT)
		if left != rats_left:
			rats_left = left
	match state:
		State.SCATTER:
			_move(RUSH_SPEED)
			if _timer <= 0.0:
				state = State.WANDER
			return
		State.HOME:
			_move(RUSH_SPEED * 0.8)
			if global_position.distance_to(home) < 1.0 or _agent.is_navigation_finished():
				_drop_at_home()
				state = State.WANDER
			return
		State.FETCH:
			if _fetch == null or not is_instance_valid(_fetch) or _fetch.is_queued_for_deletion():
				state = State.WANDER
				return
			_agent.target_position = _fetch.global_position
			_move(RUSH_SPEED)
			if _fetch.global_position.distance_to(global_position) < 0.9:
				carried.append(_fetch.to_data())
				_fetch.queue_free()
				_fetch = null
				_agent.target_position = home
				state = State.HOME
			return

	# Loose loot nearby beats everything (as long as they can carry more).
	if carried.size() < MAX_CARRY:
		var loot := _loose_loot()
		if loot != null:
			_fetch = loot
			_target = null
			state = State.FETCH
			return

	if _target == null or not is_instance_valid(_target) or not _target.is_active() \
			or _target.global_position.distance_to(global_position) > MonsterKit.sight(NOTICE_RANGE) * 1.5:
		_target = _notice()
		if _target != null:
			MonsterKit.tell(_target, &"remote_warn", ["一大群發條鼠衝過來了！（丟東西或跳一下嚇牠們）", 0.1])
	if _target != null:
		state = State.RUSH
		_agent.target_position = _target.global_position
		_move(RUSH_SPEED)
		var offset := _target.global_position - global_position
		if Vector2(offset.x, offset.z).length() < BITE_RANGE and absf(offset.y) < 1.0:
			_bite_timer -= delta
			_rob_timer -= delta
			if _bite_timer <= 0.0:
				_bite_timer = BITE_INTERVAL
				MonsterKit.tell(_target, &"remote_damage", [BITE_DAMAGE, "被發條鼠群啃光了"])
			if _rob_timer <= 0.0:
				_rob_timer = ROB_INTERVAL
				MonsterKit.tell(_target, &"remote_rob")
		return

	state = State.WANDER
	if _agent.is_navigation_finished() or _timer <= 0.0:
		_agent.target_position = home + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
		_timer = 8.0
	_move(WANDER_SPEED)


func _notice() -> Player:
	var best: Player = null
	var best_distance := MonsterKit.sight(NOTICE_RANGE)
	for player in MonsterKit.active_players(get_tree()):
		var distance := player.global_position.distance_to(global_position)
		if distance < best_distance and absf(player.global_position.y - global_position.y) < 2.0 \
				and MonsterKit.clear_line(get_world_3d(), global_position + Vector3.UP * 0.3, player.global_position + Vector3.UP * 0.5, [get_rid()]):
			best = player
			best_distance = distance
	return best


## Unfrozen loot (something a player dropped or threw) within reach on their level.
func _loose_loot() -> LootItem:
	var run := Run.instance
	if run == null:
		return null
	var best: LootItem = null
	var best_distance := LOOT_RANGE
	for node in run.loot_root.get_children():
		var item := node as LootItem
		if item == null or item.freeze or item.is_queued_for_deletion() or item.carry != null:
			continue
		var distance := item.global_position.distance_to(global_position)
		if distance < best_distance and absf(item.global_position.y - global_position.y) < 2.0:
			best = item
			best_distance = distance
	return best


## Host: leave what they dragged home in a little hoard.
func _drop_at_home() -> void:
	for data in carried:
		var pos := home + Vector3(rng.randf_range(-0.6, 0.6), 0.3, rng.randf_range(-0.6, 0.6))
		Run.instance.host_spawn_loot(data, pos, rng.randf_range(0, TAU))
	carried.clear()


func _move(speed: float) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if state == State.RUSH and _target != null and global_position.distance_to(_target.global_position) < 3.0:
		next = _target.global_position
	if state == State.FETCH and _fetch != null and global_position.distance_to(_fetch.global_position) < 3.0:
		next = _fetch.global_position
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


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position, sound, -4.0, 18.0, pitch)


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var spread := 1.1 if state == State.SCATTER else (0.45 if state == State.RUSH else 0.7)
	for i in _rats.size():
		var rat := _rats[i]
		var angle := t * (2.0 + i * 0.3) + i * TAU / _rats.size()
		var goal := Vector3(cos(angle) * spread * (0.5 + 0.5 * sin(i * 1.7)), 0.06, sin(angle) * spread)
		rat.position = rat.position.lerp(goal, minf(6.0 * delta, 1.0))
		rat.rotation.y = -angle
		rat.get_child(1).rotation.z = t * 12.0  # the wind-up key spins
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 0.12 if state != State.WANDER else 0.3
		Sfx.play_3d(get_parent(), global_position, "tick", -12.0, 14.0, rng.randf_range(1.3, 1.8))


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	var tin := PS1Materials.get_material("brass", Color(0.8, 0.75, 0.6), true)
	var key := PS1Materials.get_material("rust_metal", Color(0.6, 0.5, 0.4), true)
	var eye := PS1Materials.get_material("concrete", Color(0.3, 0.0, 0.0), true, Vector2.ONE, Color(1.0, 0.1, 0.05))
	var body := _rat_body()
	var key_mesh := _uv(LowPoly.merge([
		[LowPoly.prism(5, 0.006, 0.006, 0.05), LowPoly.at(Vector3(0, 0, -0.025), Vector3(90, 0, 0))],
		[LowPoly.prism(6, 0.022, 0.022, 0.008), LowPoly.at(Vector3(0.02, 0, 0.0), Vector3(90, 0, 0))],
		[LowPoly.prism(6, 0.022, 0.022, 0.008), LowPoly.at(Vector3(-0.02, 0, 0.0), Vector3(90, 0, 0))],
	]))
	var tail := LowPoly.tube(PackedVector3Array([Vector3(0, 0.035, 0.1), Vector3(0, 0.03, 0.16), Vector3(0.03, 0.015, 0.21),
		Vector3(0.01, 0.01, 0.27)]), PackedFloat32Array([0.008, 0.006, 0.004, 0.0]), 3)
	var eyes := LowPoly.merge([[LowPoly.blob(0.011, Vector3.ONE, 0), LowPoly.at(Vector3(0.022, 0.07, -0.1))],
		[LowPoly.blob(0.011, Vector3.ONE, 0), LowPoly.at(Vector3(-0.022, 0.07, -0.1))]])
	for i in RAT_COUNT:
		var rat := Node3D.new()
		add_child(rat)
		# Child 0 the tin body, child 1 the wind-up key (_animate spins it about its shaft).
		MonsterKit.part(rat, body, Vector3.ZERO, tin)
		var key_part := MonsterKit.part(rat, key_mesh, Vector3(0, 0.125, 0.05), key)
		key_part.rotation.x = deg_to_rad(-55.0)
		MonsterKit.part(rat, tail, Vector3.ZERO, key)
		MonsterKit.part(rat, eyes, Vector3.ZERO, eye)
		rat.position = Vector3(rng.randf_range(-0.5, 0.5), 0.06, rng.randf_range(-0.5, 0.5))
		_rats.append(rat)


## One tin rat: a pressed-metal teardrop body with its nose to -z, two round ears and
## a little wheel under the belly. Built once and shared by the whole swarm.
static func _rat_body() -> Mesh:
	var shell := PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.035, -0.115), Vector2(0.058, -0.07),
		Vector2(0.062, -0.01), Vector2(0.05, 0.04), Vector2(0.032, 0.08), Vector2(0.012, 0.115), Vector2(0.0, 0.125)])
	var parts := [[LowPoly.lathe(shell, 7), LowPoly.at(Vector3(0, 0.05, 0), Vector3(-90, 0, 0), Vector3(1.0, 0.8, 1.0))]]
	for side in [-1.0, 1.0]:
		parts.append([LowPoly.prism(6, 0.024, 0.024, 0.006), LowPoly.at(Vector3(0.026 * side, 0.1, -0.05), Vector3(-10, 0, 25 * side))])
		parts.append([LowPoly.prism(6, 0.016, 0.016, 0.008), LowPoly.at(Vector3(0.045 * side, 0.012, 0.0), Vector3(0, 0, 90))])
	parts.append([LowPoly.prism(4, 0.006, 0.0, 0.03), LowPoly.at(Vector3(0, 0.052, -0.135), Vector3(-90, 0, 0))])
	return _uv(LowPoly.merge(parts))


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 6.0)
