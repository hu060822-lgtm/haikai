class_name Spitter
extends CharacterBody3D
## 噴吐者: a stooped, long-legged thing with a throat swollen into a glowing sac of acid.
## Dominates by ABILITY: it never comes close. It keeps a room's length away and lobs
## acid that eats through boots and leaves burning puddles for a quarter of a minute.
## Weaknesses players can learn:
##   - The sac. A hit on the swollen throat does triple damage and bursts its next spit;
##     it is biggest (and easiest to hit) right while it winds up.
##   - It is a coward: hurt it and it runs off to lick its wounds. Push it.
## Tells: a wet gurgle, and a green glow under its chin.

const HEIGHT := 2.3
const RADIUS := 0.4
const WANDER_SPEED := 1.5
const MOVE_SPEED := 3.4
const BACKOFF_SPEED := 4.6
const SIGHT_LIT := 28.0
const SIGHT_DARK := 11.0
const KEEP_NEAR := 9.0
const KEEP_FAR := 16.0
const SPIT_RANGE := 22.0
const SPIT_EVERY := Vector2(2.6, 3.6)
const WINDUP := 0.8
const SPIT_SPEED := 11.0
const SPLASH_RADIUS := 1.5
const SPLASH_DAMAGE := 22.0
const SLASH_RANGE := 1.6
const SLASH_DAMAGE := 25.0
const RETREAT_TIME := 6.0
const LOSE_TIME := 6.0
## The throat sac, in local space: in front of the chest, under the chin.
const SAC_LOW := 1.25
const SAC_HIGH := 1.8
const SAC_HIT := 3.0
const BODY_HIT := 0.7

enum State { WANDER, STALK, WINDUP, RETREAT }

## Replicated: what it is doing (the sac swells while it winds up).
var state := State.WANDER
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _sac: Node3D
var _sac_light: OmniLight3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _target: Player = null
var _timer := 0.0
var _spit_timer := 2.0
var _since_seen := 0.0
var _wander := 0.0
var _slash_cooldown := 0.0
var _strafe := 1.0
var _gurgle := 2.0
var _globs: Array[Dictionary] = []  # host: acid in flight {pos, vel}


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
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state"])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
		_fly_globs(delta)
	_animate(delta)


## Host: a weapon hit it. The sac is the weak spot; anything that hurts makes it back off.
func on_hit(hit: Dictionary) -> float:
	var point: Vector3 = hit.get("point", global_position + Vector3.UP)
	var attacker: Player = hit.get("attacker") as Player
	if attacker != null and (_target == null or not is_instance_valid(_target)):
		_target = attacker
	if is_sac_hit(point):
		if attacker != null:
			MonsterKit.tell(attacker, &"remote_warn", ["打中喉囊了！酸液噴了出來！", 0.0])
		if state == State.WINDUP:
			# The swollen sac bursts all over its own feet.
			_splash(global_position + Vector3.UP * 0.05, false)
		_retreat()
		return SAC_HIT
	var hp: float = get_meta("hp", 1.0)
	var max_hp: float = get_meta("max_hp", 1.0)
	if hp < max_hp * 0.6 or (rng.randf() < 0.3 and not hit.get("effects", {}).get("dot", false)):
		_retreat()
	return BODY_HIT


## True if a hit at this world point lands on the throat sac (the front of the chest, under the chin).
func is_sac_hit(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	return local.y >= SAC_LOW and local.y <= SAC_HIGH and local.z < 0.05 and absf(local.x) < 0.38


func _think(delta: float) -> void:
	_timer -= delta
	_spit_timer -= delta
	_slash_cooldown = maxf(_slash_cooldown - delta, 0.0)
	var seen := _spot()
	if seen != null:
		if _target == null:
			MonsterKit.tell(seen, &"remote_warn", ["遠處傳來咕嚕咕嚕的水聲…有東西鼓起了喉嚨。", 0.1])
		_target = seen
		_since_seen = 0.0
	else:
		_since_seen += delta
	if _target != null and (not is_instance_valid(_target) or not _target.is_active() or _since_seen > LOSE_TIME):
		_target = null
	match state:
		State.RETREAT:
			_move(BACKOFF_SPEED)
			if _timer <= 0.0 or _agent.is_navigation_finished():
				state = State.STALK if _target != null else State.WANDER
			return
		State.WINDUP:
			_stand()
			if _target == null:
				state = State.WANDER
				return
			_face(_target.global_position)
			if _timer <= 0.0:
				_spit(_target)
				state = State.STALK
			return
	if _target == null:
		state = State.WANDER
		_wander -= delta
		if (_agent.is_navigation_finished() or _wander <= 0.0) and not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
			_wander = 20.0
		_move(WANDER_SPEED)
		return
	state = State.STALK
	var to := _target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var dir := to / maxf(distance, 0.01)
	# Cornered: one ugly slash, then away.
	if distance < SLASH_RANGE + Player.RADIUS and _slash_cooldown <= 0.0:
		_slash_cooldown = 2.0
		MonsterKit.tell(_target, &"remote_damage", [SLASH_DAMAGE, "被噴吐者的爪子撕開了", "噴吐者抓了你一把！"])
		_play.rpc("bite", 0.7)
	if distance < KEEP_NEAR:
		# Too close: back off, keeping its eyes on you.
		_agent.target_position = global_position - dir * 5.0 + dir.cross(Vector3.UP) * _strafe * 2.0
		_move(BACKOFF_SPEED, true)
	elif distance > KEEP_FAR or seen == null:
		_agent.target_position = _target.global_position
		_move(MOVE_SPEED, true)
	else:
		# In range: sidestep, never standing still for long.
		if rng.randf() < delta * 0.4:
			_strafe = -_strafe
		_agent.target_position = global_position + dir.cross(Vector3.UP) * _strafe * 3.0
		_move(WANDER_SPEED, true)
	_face(_target.global_position)
	if seen != null and distance < SPIT_RANGE and _spit_timer <= 0.0:
		state = State.WINDUP
		_timer = WINDUP
		_spit_timer = rng.randf_range(SPIT_EVERY.x, SPIT_EVERY.y)
		_play.rpc("hiss", 0.6)


func _retreat() -> void:
	if state == State.RETREAT:
		return
	state = State.RETREAT
	_timer = RETREAT_TIME
	var from := _target.global_position if _target != null and is_instance_valid(_target) else global_position
	var far := global_position
	for point in patrol_points:
		if point.distance_to(from) > far.distance_to(from) and point.distance_to(global_position) < 30.0:
			far = point
	_agent.target_position = far
	_play.rpc("screech", 1.4)


## Host: lob a glob of acid at where the target will be.
func _spit(target: Player) -> void:
	var from := _mouth_position()
	var aim := target.global_position + target.velocity * 0.5
	var flat := Vector2(aim.x - from.x, aim.z - from.z)
	var time := clampf(flat.length() / SPIT_SPEED, 0.35, 2.2)
	var vel := Vector3(flat.x / time, 0.0, flat.y / time)
	vel.y = (aim.y - from.y + 0.5 * _gravity * time * time) / time
	_globs.append({"pos": from, "vel": vel})
	_spit_fx.rpc(from, vel)


func _fly_globs(delta: float) -> void:
	for i in range(_globs.size() - 1, -1, -1):
		var glob: Dictionary = _globs[i]
		var pos: Vector3 = glob.pos
		var vel: Vector3 = glob.vel
		vel.y -= _gravity * delta
		var next := pos + vel * delta
		var landed := Vector3.INF
		var query := PhysicsRayQueryParameters3D.create(pos, next, Layers.WORLD | Layers.WALKWAY)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			landed = hit.position
		for player in MonsterKit.active_players(get_tree()):
			if (player.global_position + Vector3.UP * 0.9).distance_to(next) < 0.7:
				landed = next
		if next.y < -30.0:
			_globs.remove_at(i)
			continue
		if landed != Vector3.INF:
			_globs.remove_at(i)
			_splash(landed, true)
			continue
		glob.pos = next
		glob.vel = vel


## Host: acid hits the floor (or someone): it burns whoever is close and leaves a puddle.
func _splash(at: Vector3, hurt: bool) -> void:
	var floor_at := at
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 4.0, Layers.WORLD | Layers.WALKWAY)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and not hit.collider is Player:
		floor_at = hit.position
	if hurt:
		for player in MonsterKit.active_players(get_tree()):
			if (player.global_position + Vector3.UP * 0.5).distance_to(at) < SPLASH_RADIUS:
				MonsterKit.tell(player, &"remote_damage", [SPLASH_DAMAGE, "被噴吐者的酸液溶掉了", "酸液潑到你身上了！別站在綠色的水窪裡"])
	_splash_fx.rpc(floor_at)


func _mouth_position() -> Vector3:
	return global_transform * Vector3(0, 1.95, -0.45)


@rpc("authority", "call_local", "reliable")
func _spit_fx(from: Vector3, vel: Vector3) -> void:
	Sfx.play_3d(get_parent(), from, "hiss", 2.0, 30.0, 1.6)
	var parent := _fx_parent()
	if parent == null:
		return
	var glob := AcidGlob.new()
	glob.velocity = vel
	parent.add_child(glob)
	glob.global_position = from


@rpc("authority", "call_local", "reliable")
func _splash_fx(at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, "hiss", 0.0, 25.0, 0.9)
	var parent := _fx_parent()
	if parent == null:
		return
	var puddle := AcidPuddle.new()
	parent.add_child(puddle)
	puddle.global_position = at + Vector3.UP * 0.02


## Effects live under the run, not the monsters root (weapons look at its children).
func _fx_parent() -> Node:
	if Run.instance != null:
		return Run.instance
	return get_parent()


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.8, sound, 0.0, 30.0, pitch)


## The nearest player it can see.
func _spot() -> Player:
	var eye := global_position + Vector3.UP * 2.0
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


func _move(speed: float, keep_facing := false) -> void:
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if speed > 0.0 and direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not keep_facing:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.2)
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
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.2)


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var swell := 1.0 + sin(t * 2.0) * 0.05
	if state == State.WINDUP:
		swell = 1.45 + sin(t * 40.0) * 0.06
	elif state == State.RETREAT:
		swell = 0.8
	_sac.scale = _sac.scale.lerp(Vector3.ONE * swell, minf(delta * 8.0, 1.0))
	_sac_light.light_energy = 0.5 + (swell - 1.0) * 2.0
	var speed := Vector2(velocity.x, velocity.z).length()
	var stride := sin(t * (6.0 + speed * 1.5))
	_legs[0].rotation.x = stride * (0.4 if speed > 0.2 else 0.0)
	_legs[1].rotation.x = -stride * (0.4 if speed > 0.2 else 0.0)
	_head.rotation.x = lerpf(_head.rotation.x, -0.5 if state == State.WINDUP else 0.0, minf(delta * 6.0, 1.0))
	_gurgle -= delta
	if _gurgle <= 0.0:
		_gurgle = rng.randf_range(2.5, 5.0)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.6, "hiss", -12.0, 16.0, rng.randf_range(0.4, 0.55))


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var skin := PS1Materials.get_material("concrete", Color(0.52, 0.5, 0.4), true)
	var dark := PS1Materials.get_material("concrete", Color(0.22, 0.2, 0.15), true)
	var bone := PS1Materials.get_material("concrete", Color(0.8, 0.78, 0.65), true)
	var acid := PS1Materials.get_material("concrete", Color(0.5, 0.85, 0.2), true, Vector2.ONE, Color(0.12, 0.35, 0.02))
	var vein := PS1Materials.get_material("concrete", Color(0.18, 0.35, 0.08), true)
	# Backward-bent legs like a heron's, ending in long splayed claws.
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.2 * side, 1.15, 0.1)
		_model.add_child(leg)
		var knee := Vector3(0.05 * side, -0.45, -0.32)
		var hock := Vector3(0.02 * side, -0.85, 0.22)
		var foot := Vector3(0.0, -1.13, 0.0)
		MonsterKit.part(leg, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, knee, hock, foot]),
			PackedFloat32Array([0.12, 0.07, 0.05, 0.04]), 5)), Vector3.ZERO, skin)
		MonsterKit.part(leg, LowPoly.blob(0.07, Vector3.ONE, 0), knee, dark)
		var toes := []
		for a: float in [-0.5, 0.0, 0.5]:
			var tip := foot + Vector3(sin(a) * 0.28, -0.02, -cos(a) * 0.28)
			toes.append([LowPoly.tube(PackedVector3Array([foot, tip]), PackedFloat32Array([0.035, 0.0]), 3), Transform3D.IDENTITY])
		MonsterKit.part(leg, LowPoly.merge(toes), Vector3.ZERO, bone)
		_legs.append(leg)
	# A hunched body leaning forward, its spine knuckled through the skin.
	MonsterKit.part(_model, _uv(LowPoly.blob(0.3, Vector3(1.0, 0.75, 1.1), 1, 0.12, 21)), Vector3(0, 1.2, 0.1), skin)
	var spine := PackedVector3Array([Vector3(0, 1.2, 0.25), Vector3(0, 1.55, 0.2), Vector3(0, 1.85, 0.02), Vector3(0, 2.0, -0.3), Vector3(0, 2.02, -0.5)])
	MonsterKit.part(_model, _uv(LowPoly.tube(spine, PackedFloat32Array([0.26, 0.25, 0.18, 0.1, 0.08]), 6)), Vector3.ZERO, skin)
	var knuckles := []
	for i in 5:
		var f := i / 4.0
		var p := Vector3(0, 1.3 + f * 0.62, 0.48 - f * 0.55)
		knuckles.append([LowPoly.prism(4, 0.06, 0.0, 0.1), LowPoly.at(p, Vector3(-60 + f * 40, 45, 0))])
	MonsterKit.part(_model, LowPoly.merge(knuckles), Vector3.ZERO, bone)
	# Thin arms hanging almost to the floor.
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.27 * side, 1.78, -0.05)
		_model.add_child(arm)
		var elbow := Vector3(0.1 * side, -0.45, -0.1)
		var hand := Vector3(0.06 * side, -0.95, -0.2)
		MonsterKit.part(arm, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, elbow, hand]),
			PackedFloat32Array([0.08, 0.055, 0.04]), 5)), Vector3.ZERO, skin)
		var claws := []
		for k in 3:
			var a := (k - 1.0) * 0.35
			claws.append([LowPoly.tube(PackedVector3Array([hand, hand + Vector3(sin(a) * 0.08, -0.18, -0.06)]),
				PackedFloat32Array([0.02, 0.0]), 3), Transform3D.IDENTITY])
		MonsterKit.part(arm, LowPoly.merge(claws), Vector3.ZERO, bone)
	# The throat sac: a swollen, glowing bag hanging under the chin with dark veins over it.
	_sac = Node3D.new()
	_sac.position = Vector3(0, 1.6, -0.42)
	_model.add_child(_sac)
	MonsterKit.part(_sac, LowPoly.blob(0.19, Vector3(1.0, 1.15, 0.85), 1, 0.1, 5), Vector3.ZERO, acid)
	var veins := []
	for i in 4:
		var a := -0.9 + i * 0.6
		veins.append([LowPoly.tube(PackedVector3Array([Vector3(sin(a) * 0.12, 0.22, -cos(a) * 0.12),
			Vector3(sin(a) * 0.19, 0.0, -cos(a) * 0.17), Vector3(sin(a) * 0.11, -0.2, -cos(a) * 0.11)]),
			PackedFloat32Array([0.015, 0.013, 0.0]), 3), Transform3D.IDENTITY])
	MonsterKit.part(_sac, LowPoly.merge(veins), Vector3.ZERO, vein)
	_sac_light = OmniLight3D.new()
	_sac_light.light_color = Color(0.5, 1.0, 0.2)
	_sac_light.light_energy = 0.5
	_sac_light.omni_range = 3.0
	_sac_light.position = Vector3(0, -0.1, -0.3)
	_sac.add_child(_sac_light)
	# A small eyeless head on the end of the neck, with a long dripping jaw.
	_head = Node3D.new()
	_head.position = Vector3(0, 2.06, -0.55)
	_model.add_child(_head)
	var skull := PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.15, -0.06), Vector2(0.17, 0.1),
		Vector2(0.12, 0.28), Vector2(0.05, 0.42), Vector2(0.0, 0.44)])
	MonsterKit.part(_head, _uv(LowPoly.lathe(skull, 6)), Vector3.ZERO, skin, Vector3(-80, 0, 0), Vector3(1.0, 1.0, 0.8))
	MonsterKit.part(_head, _uv(LowPoly.tube(PackedVector3Array([Vector3(0, -0.06, 0.02), Vector3(0, -0.14, -0.15),
		Vector3(0, -0.12, -0.3)]), PackedFloat32Array([0.08, 0.06, 0.02]), 4)), Vector3.ZERO, dark)
	var teeth := []
	for i in 4:
		for side: float in [-1.0, 1.0]:
			teeth.append([LowPoly.prism(3, 0.018, 0.0, 0.06), LowPoly.at(Vector3(side * 0.045, -0.08, -0.08 - i * 0.06), Vector3(180, 0, 0))])
	MonsterKit.part(_head, LowPoly.merge(teeth), Vector3.ZERO, bone)
	MonsterKit.part(_head, LowPoly.prism(3, 0.03, 0.0, 0.18), Vector3(0, -0.24, -0.28), acid)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 4.0)


## A glob of acid in flight (visual only; the host simulates the real one).
class AcidGlob extends Node3D:
	var velocity := Vector3.ZERO
	var _life := 3.0

	func _ready() -> void:
		top_level = true
		var material := PS1Materials.get_material("concrete", Color(0.45, 0.9, 0.15), true, Vector2.ONE, Color(0.4, 0.9, 0.05))
		MonsterKit.part(self, LowPoly.blob(0.14, Vector3(1.0, 1.0, 1.3), 0), Vector3.ZERO, material)
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 1.0, 0.2)
		light.light_energy = 0.8
		light.omni_range = 2.5
		add_child(light)

	func _physics_process(delta: float) -> void:
		_life -= delta
		velocity.y -= 9.8 * delta
		var next := global_position + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(global_position, next, Layers.WORLD | Layers.WALKWAY)
		if _life <= 0.0 or not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			queue_free()
			return
		global_position = next


## A burning green puddle. The host hurts whoever stands in it; it dries up after a while.
class AcidPuddle extends Node3D:
	const LIFE := 15.0
	const RADIUS := 1.1
	const DAMAGE := 5.0
	const TICK := 0.5

	var _life := LIFE
	var _tick := TICK
	var _mesh: MeshInstance3D

	func _ready() -> void:
		add_to_group("acid_puddles")
		var material := PS1Materials.get_material("concrete", Color(0.35, 0.75, 0.1), true, Vector2.ONE, Color(0.2, 0.5, 0.02))
		_mesh = MonsterKit.part(self, LowPoly.prism(9, RADIUS, RADIUS * 0.92, 0.03), Vector3.ZERO, material)
		MonsterKit.part(self, LowPoly.prism(6, RADIUS * 0.45, RADIUS * 0.4, 0.04), Vector3(RADIUS * 0.7, 0, 0.3), material)
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 1.0, 0.2)
		light.light_energy = 0.4
		light.omni_range = 2.0
		light.position.y = 0.3
		add_child(light)

	func _physics_process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		scale = Vector3.ONE * clampf(_life / 3.0, 0.2, 1.0)
		if not multiplayer.is_server():
			return
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = TICK
		for player in MonsterKit.active_players(get_tree()):
			var offset := player.global_position - global_position
			if Vector2(offset.x, offset.z).length() < RADIUS * scale.x and absf(offset.y) < 0.8:
				MonsterKit.tell(player, &"remote_damage", [DAMAGE, "在噴吐者的酸液裡溶掉了"])
