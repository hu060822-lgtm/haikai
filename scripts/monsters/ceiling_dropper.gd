class_name CeilingDropper
extends CharacterBody3D
## 吊頂者: a long grey shape that clings upside down to the ceilings of dark rooms, limbs
## spread flat against the plaster. Dominates by ABILITY and patience: it waits for
## someone to walk underneath, drops onto them, knocks their light out and drags them off
## into the dark, and if nobody helps, it hauls them up into the ceiling.
## Weaknesses players can learn:
##   - Light. It won't drop on anyone carrying a lit lantern; grabbed, relight it (F)
##     and it lets go. A teammate's light on it works too.
##   - Fire makes it let go at once, and hurts it three times over.
## Tells: plaster dust trickling down, and a soft clicking overhead.

const HEIGHT := 1.6
const RADIUS := 0.35
const CEILING_SEARCH := 8.0
const MIN_HANG := 2.4
const DEFAULT_HANG := 3.2
const TRIGGER_RADIUS := 1.1
const DROP_TIME := 0.35
const GRAB_TIME := 6.0
const GRAB_DAMAGE := 5.0
const GRAB_TICK := 0.5
const DRAG_SPEED := 1.4
const LIGHT_RANGE := 7.0
const RELEASE_DAMAGE := 30.0
const CRAWL_SPEED := 1.8
const RELOCATE_TIME := Vector2(35.0, 60.0)
const COOLDOWN := 8.0

enum State { HANG, CRAWL, DROP, GRAB, CLIMB }

## Replicated: what it is doing (pose), and who it holds (for the drag on their machine).
var state := State.HANG:
	set(value):
		state = value
		if is_node_ready():
			_apply_pose()
var victim_name := ""
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _model: Node3D
var _limbs: Array[Node3D] = []
var _head: Node3D
var _collider: CollisionShape3D
var _victim: Player = null
var _timer := 0.0
var _tick := 0.0
var _grab_hurt := 0.0
var _relocate := 40.0
var _cooldown := 0.0
var _crawl_goal := Vector3.ZERO
var _drag_goal := Vector3.ZERO
var _dust := 3.0
var _click := 2.0


func _ready() -> void:
	add_to_group("monsters")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	_collider = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.5, 1.5)
	_collider.shape = box
	_collider.position.y = -0.25  # flat against the ceiling, below its origin
	add_child(_collider)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state", ".:victim_name"])
	_apply_pose()
	if multiplayer.is_server():
		_relocate = rng.randf_range(RELOCATE_TIME.x, RELOCATE_TIME.y)
		global_position = ceiling_above(global_position)


## Where it would hang above a floor point: on the ceiling if there is one in reach,
## otherwise on whatever beam is at a believable height.
func ceiling_above(floor_point: Vector3) -> Vector3:
	var from := floor_point + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * CEILING_SEARCH, Layers.WORLD | Layers.WALKWAY)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.position.y - floor_point.y >= MIN_HANG:
		return hit.position - Vector3.UP * 0.05
	return floor_point + Vector3.UP * DEFAULT_HANG


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


## Host: a weapon hit it. Fire or a jolt makes it let go; enough damage does too.
func on_hit(hit: Dictionary) -> float:
	var effects: Dictionary = hit.get("effects", {})
	var amount: float = hit.get("amount", 0.0)
	if state == State.GRAB:
		_grab_hurt += amount
		if effects.has("burn") or effects.has("stun") or effects.has("explode") or _grab_hurt >= RELEASE_DAMAGE:
			_release("燒到它了！吊頂者鬆手逃走了。" if effects.has("burn") else "吊頂者被打得鬆開了手！")
	elif state == State.HANG or state == State.CRAWL:
		# Shot on the ceiling: it skitters away to another dark spot.
		if effects.has("burn") or rng.randf() < 0.5:
			_start_crawl(true)
	return 1.0


## Host: it's dead. Whoever it held drops free.
func host_kill() -> void:
	if is_queued_for_deletion():
		return
	if state == State.GRAB:
		_release("")
	_died.rpc(global_position)
	queue_free()


func _think(delta: float) -> void:
	_timer -= delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.HANG:
			_relocate -= delta
			var below := _player_below()
			if below != null and _cooldown <= 0.0:
				if lit(below):
					# It hates the light: it pulls back and finds somewhere darker.
					MonsterKit.tell(below, &"remote_warn", ["頭頂傳來喀噠一聲，灰塵掉了下來…有東西縮回了黑暗裡。", 0.1])
					_start_crawl(true)
				else:
					_victim = below
					state = State.DROP
					_timer = DROP_TIME
					_play.rpc("screech", 1.8)
			elif _relocate <= 0.0 and MonsterKit.nearest_player(self, 18.0) == null:
				_start_crawl(false)
		State.CRAWL:
			var to := _crawl_goal - global_position
			if to.length() < 0.2 or _timer <= 0.0:
				state = State.HANG
				_relocate = rng.randf_range(RELOCATE_TIME.x, RELOCATE_TIME.y)
				return
			global_position += to.normalized() * minf(CRAWL_SPEED * delta, to.length())
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.2)
		State.DROP:
			if _victim == null or not is_instance_valid(_victim) or not _victim.is_active():
				_climb()
				return
			var f := clampf(1.0 - _timer / DROP_TIME, 0.0, 1.0)
			var onto := _victim.global_position + Vector3.UP * (HEIGHT + 0.3)
			global_position = global_position.lerp(onto, f)
			if _timer <= 0.0:
				_grab()
		State.GRAB:
			_hold(delta)
		State.CLIMB:
			global_position = global_position.move_toward(_crawl_goal, 5.0 * delta)
			if global_position.distance_to(_crawl_goal) < 0.1:
				state = State.HANG
				_cooldown = COOLDOWN
				# Then somewhere else, where it was not seen.
				_start_crawl(true)


## The player standing under it, if any.
func _player_below() -> Player:
	for player in MonsterKit.active_players(get_tree()):
		var offset := player.global_position - global_position
		if Vector2(offset.x, offset.z).length() < TRIGGER_RADIUS and offset.y < -0.5 and offset.y > -CEILING_SEARCH \
				and MonsterKit.clear_line(get_world_3d(), global_position + Vector3.DOWN * 0.2, player.head_position(), [get_rid()]):
			return player
	return null


## A player's own light: the lantern, or a light bolted under the barrel.
static func lit(player: Player) -> bool:
	return player.is_lit() or player.get("gun_light_on") == true


func _grab() -> void:
	state = State.GRAB
	victim_name = String(_victim.name)
	_timer = GRAB_TIME
	_tick = GRAB_TICK
	_grab_hurt = 0.0
	_drag_goal = _darkest_corner(_victim.global_position)
	MonsterKit.tell(_victim, &"remote_snuff")
	MonsterKit.tell(_victim, &"remote_damage", [GRAB_DAMAGE * 2.0, "被吊頂者拖進天花板", "有東西從天花板掉到你身上！快點亮提燈（F）！"])
	_play.rpc("bite", 0.7)


## Host: holding someone. Drag them off; light or teammates make it let go.
func _hold(delta: float) -> void:
	if _victim == null or not is_instance_valid(_victim) or not _victim.is_active():
		_release("")
		return
	if lit(_victim):
		_release("光照到它了！吊頂者尖叫著放開你，爬回天花板。")
		return
	for player in MonsterKit.active_players(get_tree()):
		if player == _victim or not lit(player):
			continue
		var to := global_position - player.head_position()
		if to.length() < LIGHT_RANGE and player.look_direction().dot(to.normalized()) > 0.85 \
				and MonsterKit.clear_line(get_world_3d(), player.head_position(), global_position, [get_rid()]):
			MonsterKit.tell(player, &"remote_warn", ["你的光照到吊頂者，它放開了隊友！", 0.0])
			_release("隊友的光照到它了！吊頂者放開了你。")
			return
	_tick -= delta
	if _tick <= 0.0:
		_tick = GRAB_TICK
		MonsterKit.tell(_victim, &"remote_damage", [GRAB_DAMAGE, "被吊頂者拖進天花板"])
	# Drag towards the dark, riding on their back.
	var at := _victim.global_position
	var to_goal := _drag_goal - at
	to_goal.y = 0.0
	if to_goal.length() > 0.3:
		at += to_goal.normalized() * DRAG_SPEED * delta
	_drag_to.rpc(victim_name, at)
	global_position = at + Vector3.UP * (HEIGHT + 0.3)
	if _timer <= 0.0:
		MonsterKit.tell(_victim, &"remote_damage", [999.0, "被吊頂者拖進天花板"])
		_play.rpc("screech", 0.6)
		_victim = null
		victim_name = ""
		_climb()


func _release(note: String) -> void:
	if _victim != null and is_instance_valid(_victim) and note != "":
		MonsterKit.tell(_victim, &"remote_warn", [note, 0.3])
	_victim = null
	victim_name = ""
	_play.rpc("screech", 2.2)
	_climb()


func _climb() -> void:
	state = State.CLIMB
	_crawl_goal = ceiling_above(global_position + Vector3.DOWN * (HEIGHT + 1.2))
	if _crawl_goal.y < global_position.y:
		_crawl_goal = global_position + Vector3.UP * 1.0


## Start crawling along the ceiling to another spot (fleeing: away from people).
func _start_crawl(fleeing: bool) -> void:
	if patrol_points.is_empty():
		return
	var best := Vector3.INF
	for attempt in 6:
		var point: Vector3 = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
		if point.distance_to(global_position) > 25.0 and fleeing:
			continue
		var spot := ceiling_above(point)
		if not MonsterKit.clear_line(get_world_3d(), global_position + Vector3.DOWN * 0.3, spot + Vector3.DOWN * 0.3, [get_rid()]):
			continue
		best = spot
		break
	if best == Vector3.INF:
		if fleeing and MonsterKit.nearest_player(self, 25.0) == null:
			return
		# No straight way along the ceiling: it slips into the vents and comes out elsewhere.
		best = ceiling_above(patrol_points[rng.randi_range(0, patrol_points.size() - 1)])
		global_position = best
	_crawl_goal = best
	state = State.CRAWL
	_timer = 20.0


## The corner of the room furthest from any light (in practice: away from the others).
func _darkest_corner(from: Vector3) -> Vector3:
	var best := from
	var best_score := -INF
	for i in 8:
		var angle := TAU * i / 8.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var reach := 5.0
		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.8, from + Vector3.UP * 0.8 + dir * reach, Layers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var length := reach if hit.is_empty() else from.distance_to(hit.position) - 0.6
		var spot := from + dir * maxf(length, 0.0)
		var score := length
		for player in MonsterKit.active_players(get_tree()):
			if player != _victim:
				score += minf(player.global_position.distance_to(spot), 15.0) * 0.3
		if score > best_score:
			best_score = score
			best = spot
	return best


## On the victim's own machine: their body goes where it drags them.
@rpc("authority", "call_local", "unreliable_ordered")
func _drag_to(player_name: String, at: Vector3) -> void:
	if Run.instance == null:
		return
	var player := Run.instance.players_root.get_node_or_null(player_name) as Player
	if player != null and player.is_multiplayer_authority() and player.is_active():
		player.global_position = at
		player.velocity = Vector3.ZERO


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position, sound, 0.0, 25.0, pitch)


@rpc("authority", "call_local", "reliable")
func _died(at: Vector3) -> void:
	Sfx.play_3d(get_parent(), at, "screech", 2.0, 30.0, 0.9)


func _apply_pose() -> void:
	# Hanging/crawling: flat against the ceiling, face down. Grabbing: wrapped round a back.
	match state:
		State.DROP, State.GRAB:
			_model.rotation = Vector3(PI * 0.5, 0, 0)
			_model.position = Vector3(0, -0.5, 0.35)
		_:
			_model.rotation = Vector3(PI, 0, 0)
			_model.position = Vector3.ZERO


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var busy := state == State.CRAWL or state == State.GRAB or state == State.CLIMB
	for i in _limbs.size():
		var base: float = 0.0
		_limbs[i].rotation.x = base + sin(t * (10.0 if busy else 0.8) + i * 1.3) * (0.4 if busy else 0.05)
	_head.rotation.y = sin(t * 0.4) * 0.5 if state == State.HANG else 0.0
	if state == State.HANG:
		_dust -= delta
		if _dust <= 0.0:
			_dust = rng.randf_range(4.0, 9.0)
			_sprinkle()
		_click -= delta
		if _click <= 0.0:
			_click = rng.randf_range(3.0, 7.0)
			Sfx.play_3d(get_parent(), global_position, "tick", -12.0, 12.0, rng.randf_range(1.4, 1.8))


## A trickle of plaster dust from where it clings.
func _sprinkle() -> void:
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 10
	dust.lifetime = 1.4
	dust.explosiveness = 0.3
	dust.direction = Vector3.DOWN
	dust.spread = 10.0
	dust.initial_velocity_min = 0.2
	dust.initial_velocity_max = 0.6
	dust.gravity = Vector3(0, -3.0, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 0.025)
	dust.mesh = mesh
	dust.material_override = PS1Materials.get_material("concrete", Color(0.8, 0.78, 0.72))
	add_child(dust)
	dust.position = Vector3(rng.randf_range(-0.3, 0.3), -0.1, rng.randf_range(-0.4, 0.4))
	dust.emitting = true
	get_tree().create_timer(2.0).timeout.connect(dust.queue_free)


func _build_model() -> void:
	# Built lying face-up along -z (head forward); flipped to hang face-down from the ceiling.
	_model = Node3D.new()
	add_child(_model)
	var skin := PS1Materials.get_material("concrete", Color(0.72, 0.71, 0.66), true)
	var dark := PS1Materials.get_material("concrete", Color(0.25, 0.25, 0.24), true)
	var hair := PS1Materials.get_material("carpet", Color(0.06, 0.05, 0.05), true)
	var black := PS1Materials.get_material("concrete", Color(0.02, 0.02, 0.02), true)
	var eye := PS1Materials.get_material("concrete", Color(0.9, 0.9, 0.8), true, Vector2.ONE, Color(0.6, 0.6, 0.5))
	# A long starved torso, ribs and spine showing, lying flat (y is "away from the ceiling").
	var torso := PackedVector3Array([Vector3(0, 0.12, 0.55), Vector3(0, 0.15, 0.2), Vector3(0, 0.16, -0.2), Vector3(0, 0.13, -0.5)])
	MonsterKit.part(_model, _uv(LowPoly.tube(torso, PackedFloat32Array([0.19, 0.22, 0.24, 0.14]), 6)), Vector3.ZERO, skin, Vector3.ZERO, Vector3(1.3, 0.75, 1.0))
	# A narrow pelvis and the knobs of the spine (against the ceiling).
	MonsterKit.part(_model, _uv(LowPoly.blob(0.17, Vector3(1.4, 0.7, 1.0), 1, 0.1, 6)), Vector3(0, 0.12, 0.55), skin)
	var ribs := []
	for i in 4:
		var z := -0.3 + i * 0.13
		for side: float in [-1.0, 1.0]:
			ribs.append([LowPoly.tube(PackedVector3Array([Vector3(0.05 * side, 0.27, z), Vector3(0.21 * side, 0.2, z + 0.03), Vector3(0.25 * side, 0.1, z + 0.06)]),
				PackedFloat32Array([0.02, 0.02, 0.0]), 3), Transform3D.IDENTITY])
	MonsterKit.part(_model, LowPoly.merge(ribs), Vector3.ZERO, dark)
	# Four limbs spread wide like a gecko's, elbows up, long fingers splayed on the plaster.
	var limbs := [[Vector3(0.22, 0.1, -0.4), 1.0, -1.0], [Vector3(-0.22, 0.1, -0.4), -1.0, -1.0],
		[Vector3(0.18, 0.1, 0.5), 1.0, 1.0], [Vector3(-0.18, 0.1, 0.5), -1.0, 1.0]]
	for limb: Array in limbs:
		var side: float = limb[1]
		var front: float = limb[2]
		var joint := Node3D.new()
		joint.position = limb[0]
		_model.add_child(joint)
		var elbow := Vector3(0.45 * side, 0.25, 0.15 * front)
		var hand := Vector3(0.75 * side, -0.08, 0.45 * front)
		MonsterKit.part(joint, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, elbow, hand]),
			PackedFloat32Array([0.095, 0.065, 0.045]), 5)), Vector3.ZERO, skin)
		MonsterKit.part(joint, LowPoly.blob(0.075, Vector3.ONE, 0), elbow, dark)
		var fingers := []
		for k in 4:
			var a := (k - 1.5) * 0.4
			var dir := Vector3(sin(a) * front * -1.0 + side * 0.6, 0, cos(a) * front).normalized()
			fingers.append([LowPoly.tube(PackedVector3Array([hand, hand + dir * 0.22 + Vector3(0, -0.02, 0)]),
				PackedFloat32Array([0.018, 0.0]), 3), Transform3D.IDENTITY])
		MonsterKit.part(joint, LowPoly.merge(fingers), Vector3.ZERO, dark)
		_limbs.append(joint)
	# The head, twisted to look down at you (up from the model), with a gaping mouth
	# and long black hair hanging off it.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.2, -0.68)
	_model.add_child(_head)
	MonsterKit.part(_head, _uv(LowPoly.tube(PackedVector3Array([Vector3(0, -0.05, 0.2), Vector3(0, 0.0, 0.05)]),
		PackedFloat32Array([0.06, 0.06]), 5)), Vector3.ZERO, skin)
	MonsterKit.part(_head, _uv(LowPoly.blob(0.15, Vector3(0.9, 1.0, 1.15), 1, 0.06, 4)), Vector3(0, 0.04, -0.05), skin)
	MonsterKit.part(_head, LowPoly.blob(0.06, Vector3(0.8, 0.4, 1.3), 0), Vector3(0, 0.16, -0.08), black)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_head, LowPoly.blob(0.028, Vector3.ONE, 0), Vector3(0.06 * side, 0.15, -0.15), eye)
	var strands := []
	for i in 9:
		var x := (i - 4) * 0.03
		var top := Vector3(x, 0.0, 0.05 + absf(x) * 0.5)
		var tip := Vector3(x * 1.6, 0.55 + (i % 3) * 0.12, 0.0 + (i % 2) * 0.06)
		strands.append([LowPoly.tube(PackedVector3Array([top, top.lerp(tip, 0.5) + Vector3(0, 0, 0.05), tip]),
			PackedFloat32Array([0.025, 0.018, 0.0]), 3), Transform3D.IDENTITY])
	MonsterKit.part(_head, LowPoly.merge(strands), Vector3(0, -0.05, -0.05), hair)
	# Pale eyes catch any light.
	var glint := OmniLight3D.new()
	glint.position = Vector3(0, 0.35, -0.2)
	glint.light_color = Color(0.8, 0.85, 0.7)
	glint.light_energy = 0.2
	glint.omni_range = 1.0
	_head.add_child(glint)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 4.0)
