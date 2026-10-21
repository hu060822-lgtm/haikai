class_name WebWeaver
extends Prowler
## 蛛網織者: a spider the size of a armchair with a bloated, pale-marked abdomen. Dominates
## by INTELLIGENCE and ABILITY: it strings sticky webs across doorways and corridors, then
## waits in the dark beside them. Whoever blunders into a web is stuck, and it reels
## them in on a thread to bite.
## Weaknesses players can learn:
##   - Fire: a burning hit sets its webs alight and hurts it double.
##   - Webs glint in the lantern light: walk with it on and look before a doorway.
##   - Shoot it while it reels and the thread snaps; it scuttles back to its lair.
## Tell: dry creaking as it spins, and the many little eyes in the dark.

enum State { SPIN, WAIT, REEL, HUNT, RETREAT }

const RADIUS := 0.55
const SPEED := 2.2
const RUSH_SPEED := 4.6
const MAX_WEBS := 4
const WEB_RANGE := 26.0       # it webs doorways this close to its home
const WEB_HEIGHT := 2.3
const WEB_SNARE := 3.0
const SPIN_TIME := 3.0
const RESPIN := 20.0          # seconds before it replaces a burnt web
const REEL_RANGE := 18.0
const REEL_STEP := 0.22       # metres per tick (ten ticks a second)
const REEL_TIME := 6.0
const BITE_DAMAGE := 34.0
const NEAR_BITE := 24.0
const BITE_RANGE := 1.5
const AMBUSH_RANGE := 3.5
const FLEE_BELOW := 0.35

## Replicated: the webs (centre, and x = yaw, y = width, z = 1 while intact) and the thread.
var web_pos := PackedVector3Array():
	set(value):
		web_pos = value
		_webs_dirty = true
var web_info := PackedVector3Array():
	set(value):
		web_info = value
		_webs_dirty = true
var reel_to := Vector3.ZERO
var state := State.SPIN
var home := Vector3.ZERO

var _webs_dirty := true
var _web_nodes: Array[Node3D] = []
var _web_root: Node3D
var _thread: MeshInstance3D
var _legs: Array[Node3D] = []
var _abdomen: Node3D
var _spots: Array = []          # [pos, yaw, width] doorways it wants webbed
var _searched := false
var _spin := 0.0
var _spin_index := -1
var _lair := Vector3.ZERO
var _victim: Player = null
var _reel_tick := 0.0
var _reel_time := 0.0
var _bite_cooldown := 0.0
var _retreat := 0.0
var _grace := {}                # Player -> seconds before a web can catch them again
var _respin := 0.0
var _gait := 0.0
var _last_pos := Vector3.ZERO
var _creak := 0.0


func _ready() -> void:
	setup_body(RADIUS, 1.1, 0.5)
	_build_model()
	_model.scale = Vector3.ONE * 1.3
	_web_root = Node3D.new()
	_web_root.top_level = true
	add_child(_web_root)
	_thread = MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.025, 0.025, 1.0)
	_thread.mesh = line
	_thread.material_override = PS1Materials.get_material("concrete", Color(0.9, 0.9, 0.85), false, Vector2.ONE, Color(0.25, 0.25, 0.22))
	_thread.top_level = true
	_thread.visible = false
	add_child(_thread)
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:web_pos", ".:web_info", ".:reel_to", ".:state"])
	if home == Vector3.ZERO:
		home = global_position
	_lair = global_position
	_last_pos = global_position


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if multiplayer.is_server():
		_think(delta)
		move_and_slide()
	_animate(delta)


# --- Webs -----------------------------------------------------------------------------

func web_count() -> int:
	var count := 0
	for info in web_info:
		if info.z > 0.5:
			count += 1
	return count


## Host: put a web up (used by the AI; tests can call it too).
func host_add_web(pos: Vector3, yaw: float, width: float) -> void:
	var p := web_pos.duplicate()
	var i := web_info.duplicate()
	# Reuse a burnt slot at the same place.
	for k in p.size():
		if p[k].distance_to(pos) < 0.5:
			i[k] = Vector3(yaw, width, 1.0)
			web_pos = p
			web_info = i
			return
	p.append(pos)
	i.append(Vector3(yaw, width, 1.0))
	web_pos = p
	web_info = i


## Host: fire reaches webs near this point. Returns how many burnt.
func host_burn_webs(near: Vector3, radius: float) -> int:
	var i := web_info.duplicate()
	var burnt := 0
	for k in web_pos.size():
		if i[k].z > 0.5 and web_pos[k].distance_to(near) < radius:
			i[k].z = 0.0
			burnt += 1
			host_sound("hiss", 2.0, 25.0, 0.7, web_pos[k])
	if burnt > 0:
		web_info = i
		_respin = RESPIN
	return burnt


## True if this point is inside an intact web's sheet.
func web_at(point: Vector3) -> int:
	for k in web_pos.size():
		var info := web_info[k]
		if info.z < 0.5:
			continue
		var local := point - web_pos[k]
		if local.y < -0.3 or local.y > WEB_HEIGHT:
			continue
		var along := Vector3(cos(info.x), 0, -sin(info.x))  # the web's width runs along its local x
		var normal := Vector3(sin(info.x), 0, cos(info.x))
		if absf(local.dot(normal)) < 0.4 and absf(local.dot(along)) < info.y / 2.0:
			return k
	return -1


func on_hit(hit: Dictionary) -> float:
	var effects: Dictionary = hit.get("effects", {})
	if effects.has("burn"):
		host_burn_webs(global_position, 12.0)
		if hit.get("from") is Vector3:
			host_burn_webs(hit.from, 6.0)
		host_sound("screech", 2.0, 30.0, 1.3)
	if state == State.REEL:
		_release("線斷了！你掙脫了蛛網。")
		_retreat = 4.0
		state = State.RETREAT
	elif health_ratio() < FLEE_BELOW + 0.15:
		_retreat = 6.0
		state = State.RETREAT
	host_sound("creak", 0.0, 20.0, 1.8)
	return 1.0  # fire's double damage comes from the roster's weak.burn


func host_kill() -> void:
	_release("")
	host_sound("death", 2.0, 30.0, 0.7)
	queue_free()


# --- AI -------------------------------------------------------------------------------

func _think(delta: float) -> void:
	_bite_cooldown = maxf(_bite_cooldown - delta, 0.0)
	_respin = maxf(_respin - delta, 0.0)
	for player in _grace.keys():
		_grace[player] -= delta
		if _grace[player] <= 0.0 or not is_instance_valid(player):
			_grace.erase(player)
	if not _searched and _nav_ready():
		_searched = true
		_find_spots()
	_check_webs()
	match state:
		State.SPIN:
			_spin_webs(delta)
		State.REEL:
			_reel(delta)
		State.HUNT:
			_hunt(delta)
		State.RETREAT:
			_retreat -= delta
			steer(_lair, RUSH_SPEED, delta)
			if _retreat <= 0.0 and global_position.distance_to(_lair) < 1.5:
				state = State.WAIT
		_:
			_wait(delta)


func _check_webs() -> void:
	for player in MonsterKit.active_players(get_tree()):
		if _grace.has(player) or player == _victim:
			continue
		if web_at(player.global_position + Vector3.UP * 0.5) < 0 and web_at(player.global_position + Vector3.UP * 1.3) < 0:
			continue
		_grace[player] = 6.0
		host_affect(player, {"snare": WEB_SNARE, "slow": 6.0, "slow_factor": 0.45, "shake": 0.3,
			"note": "你撞進一張黏稠的網！狂按 E 掙脫"})
		host_sound("creak", 4.0, 30.0, 0.6, player.global_position + Vector3.UP)
		if state != State.REEL and state != State.RETREAT and global_position.distance_to(player.global_position) < REEL_RANGE * 1.5:
			_victim = player
			_reel_time = 0.0
			state = State.HUNT
		return


func _wait(delta: float) -> void:
	if web_count() < mini(MAX_WEBS, _spots.size()) and _respin <= 0.0:
		state = State.SPIN
		return
	if global_position.distance_to(_lair) > 1.2:
		steer(_lair, SPEED, delta)
		return
	halt()
	# Face the nearest web, hunched down, still.
	if not web_pos.is_empty():
		face_point(web_pos[_nearest_web()], 2.0, delta)
	for player in MonsterKit.active_players(get_tree()):
		if global_position.distance_to(player.global_position) < AMBUSH_RANGE and sees(player, 0.6, AMBUSH_RANGE):
			_victim = player
			state = State.HUNT
			return


func _nearest_web() -> int:
	var best := 0
	for k in web_pos.size():
		if web_pos[k].distance_to(global_position) < web_pos[best].distance_to(global_position):
			best = k
	return best


func _spin_webs(delta: float) -> void:
	if _spin_index < 0:
		_spin_index = -1
		for k in _spots.size():
			var spot: Array = _spots[k]
			var have := false
			for w in web_pos.size():
				if web_pos[w].distance_to(spot[0]) < 0.5 and web_info[w].z > 0.5:
					have = true
			if not have:
				_spin_index = k
				break
		if _spin_index < 0:
			_choose_lair()
			state = State.WAIT
			return
		_spin = SPIN_TIME
	var spot: Array = _spots[_spin_index]
	var at: Vector3 = spot[0]
	if global_position.distance_to(at) > 1.2:
		steer(at, SPEED, delta)
		return
	halt()
	face_point(at + Vector3(sin(spot[1]), 0, cos(spot[1])), 4.0, delta)
	_spin -= delta
	_creak -= delta
	if _creak <= 0.0:
		_creak = 0.7
		host_sound("creak", -6.0, 18.0, rng.randf_range(1.3, 1.7))
	if _spin <= 0.0:
		host_add_web(at, spot[1], spot[2])
		_spin_index = -1


func _choose_lair() -> void:
	if web_pos.is_empty():
		_lair = home
		return
	var k := _nearest_web()
	var info := web_info[k]
	var normal := Vector3(sin(info.x), 0, cos(info.x))
	# Sit a few metres back from the web on whichever side is darker and reachable.
	var best := web_pos[k]
	var best_light := INF
	for side: float in [-1.0, 1.0]:
		var p := NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), web_pos[k] + normal * side * 3.5)
		if p.distance_to(web_pos[k] + normal * side * 3.5) > 1.5:
			continue
		var light := _light_at(p)
		if light < best_light:
			best_light = light
			best = p
	_lair = best


func _light_at(point: Vector3) -> float:
	var total := 0.0
	var level = Run.instance.level if Run.instance != null else null
	if level == null:
		return 0.0
	for light: OmniLight3D in level.get("_all_lights"):
		if is_instance_valid(light) and light.visible:
			var d := light.global_position.distance_to(point)
			if d < light.omni_range:
				total += light.light_energy * (1.0 - d / light.omni_range)
	return total


## Doorways and corridors near home: narrow one way, open the other.
func _find_spots() -> void:
	var map := _agent.get_navigation_map()
	var candidates: Array[Vector3] = []
	for point in patrol_points:
		if point.distance_to(home) > WEB_RANGE:
			continue
		candidates.append(point)
		for i in 10:
			var offset := Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7))
			candidates.append(NavigationServer3D.map_get_closest_point(map, point + offset))
	for i in 30:
		var offset := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		candidates.append(NavigationServer3D.map_get_closest_point(map, home + offset))
	var space := get_world_3d().direct_space_state
	for c: Vector3 in candidates:
		if _spots.size() >= MAX_WEBS:
			break
		var probe := c + Vector3.UP * 1.0
		var reach := {}
		for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var query := PhysicsRayQueryParameters3D.create(probe, probe + axis * 2.2, Layers.WORLD)
			query.exclude = [get_rid()]
			var hit := space.intersect_ray(query)
			reach[axis] = 2.2 if hit.is_empty() or hit.collider is Player else probe.distance_to(hit.position)
		var spot: Array = []
		var x_span: float = reach[Vector3.RIGHT] + reach[Vector3.LEFT]
		var z_span: float = reach[Vector3.FORWARD] + reach[Vector3.BACK]
		if x_span < 4.2 and reach[Vector3.RIGHT] < 2.2 and reach[Vector3.LEFT] < 2.2 and z_span >= 4.4:
			var mid: Vector3 = c + Vector3.RIGHT * (reach[Vector3.RIGHT] - reach[Vector3.LEFT]) / 2.0
			spot = [mid, 0.0, x_span]           # width along x, faces along z
		elif z_span < 4.2 and reach[Vector3.FORWARD] < 2.2 and reach[Vector3.BACK] < 2.2 and x_span >= 4.4:
			var mid: Vector3 = c + Vector3.BACK * (reach[Vector3.BACK] - reach[Vector3.FORWARD]) / 2.0
			spot = [mid, PI / 2.0, z_span]
		if spot.is_empty():
			continue
		var far_enough := true
		for other: Array in _spots:
			if (other[0] as Vector3).distance_to(spot[0]) < 6.0:
				far_enough = false
		if far_enough:
			_spots.append(spot)


func _hunt(delta: float) -> void:
	if _victim == null or not is_instance_valid(_victim) or not _victim.is_active():
		_victim = null
		state = State.RETREAT
		_retreat = 1.0
		return
	var distance := global_position.distance_to(_victim.global_position)
	if distance < BITE_RANGE:
		_bite(_victim, NEAR_BITE)
		return
	if _victim.snared > 0.0 or _grace.has(_victim) and _grace[_victim] > 3.0:
		# Stuck in a web: if it can see them, shoot a thread and reel them in.
		if distance < REEL_RANGE and sees(_victim, 0.7, REEL_RANGE):
			state = State.REEL
			_reel_time = 0.0
			host_sound("whistle", -2.0, 20.0, 0.5)
			return
	_reel_time += delta
	if _reel_time > 12.0:
		state = State.RETREAT
		_retreat = 2.0
		_victim = null
		return
	steer(_victim.global_position, RUSH_SPEED, delta, 8.0)


func _reel(delta: float) -> void:
	if _victim == null or not is_instance_valid(_victim) or not _victim.is_active():
		_release("")
		state = State.WAIT
		return
	halt()
	face_point(_victim.global_position, 8.0, delta)
	reel_to = _victim.global_position + Vector3.UP * 1.0
	_reel_time += delta
	var distance := global_position.distance_to(_victim.global_position)
	if distance < BITE_RANGE + 0.2:
		_bite(_victim, BITE_DAMAGE)
		return
	if _reel_time > REEL_TIME or not sees(_victim, 0.7, REEL_RANGE + 2.0):
		_release("蛛絲鬆開了。")
		state = State.HUNT
		return
	_reel_tick -= delta
	if _reel_tick <= 0.0:
		_reel_tick = 0.1
		var pull := global_position - _victim.global_position
		pull.y = 0.0
		pull = pull.normalized() * REEL_STEP
		host_affect(_victim, {"snare": 0.6, "drag": pull})
		if int(_reel_time * 10.0) % 6 == 0:
			host_sound("creak", -2.0, 20.0, 1.1, _victim.global_position + Vector3.UP)


func _bite(player: Player, damage: float) -> void:
	halt()
	if _bite_cooldown > 0.0:
		return
	_bite_cooldown = 2.5
	face_point(player.global_position, 60.0, 1.0)
	host_sound("bite", 3.0, 25.0, 0.55)
	_release("")
	MonsterKit.tell(player, &"remote_damage", [damage, "被蛛網織者拖進黑暗裡吃掉了", "牠咬了你！快逃，用火燒牠的網！"])
	_grace[player] = 6.0
	_victim = null
	state = State.RETREAT
	_retreat = 3.0


func _release(note: String) -> void:
	if _victim != null and is_instance_valid(_victim) and _victim.is_active() and state == State.REEL:
		var effect := {"release": true}
		if note != "":
			effect.note = note
		host_affect(_victim, effect)
	reel_to = Vector3.ZERO


# --- Looks ----------------------------------------------------------------------------

func _animate(delta: float) -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var speed := moved.length() / maxf(delta, 0.001)
	_gait += delta * clampf(speed * 4.0, 0.0, 20.0)
	for i in _legs.size():
		var phase := _gait + (PI if (i % 2 == 0) != (i < 4) else 0.0)
		_legs[i].rotation.x = sin(phase) * 0.35 * clampf(speed, 0.0, 1.0)
		_legs[i].rotation.z = -cos(phase) * 0.15 * clampf(speed, 0.0, 1.0)
	_abdomen.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.03)
	if _webs_dirty:
		_webs_dirty = false
		_rebuild_webs()
	_thread.visible = reel_to != Vector3.ZERO
	if _thread.visible:
		var from := global_position + Vector3.UP * 0.75 + forward() * 0.6
		var length := from.distance_to(reel_to)
		if length > 0.1:
			_thread.global_transform = Transform3D(Basis.looking_at(reel_to - from, Vector3.UP).scaled(Vector3(1, 1, length)), from.lerp(reel_to, 0.5))


func _rebuild_webs() -> void:
	for node in _web_nodes:
		node.queue_free()
	_web_nodes.clear()
	for k in web_pos.size():
		var info := web_info[k]
		if info.z < 0.5:
			continue
		var web := WebWeaver.make_web(info.y, WEB_HEIGHT)
		_web_root.add_child(web)
		web.global_position = web_pos[k]
		web.rotation.y = info.x
		_web_nodes.append(web)


## A web filling a doorway `width` wide: anchor lines to the frame, radial strands
## and a sagging spiral, catching the light pale.
static func make_web(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	var silk := PS1Materials.get_material("concrete", Color(0.92, 0.92, 0.86), false, Vector2.ONE, Color(0.22, 0.22, 0.2))
	var centre := Vector3(0, height * 0.55, 0)
	var parts := []
	var spokes := 9
	var anchors: Array[Vector3] = []
	for s in spokes:
		var a := TAU * s / spokes + 0.2
		var dir := Vector3(cos(a), sin(a), 0)
		# Stretch each spoke to the doorway's edge (floor, jambs or lintel).
		var reach := minf(absf((width / 2.0) / dir.x) if absf(dir.x) > 0.01 else INF,
			(height - centre.y) / dir.y if dir.y > 0.01 else (centre.y / -dir.y if dir.y < -0.01 else INF))
		var tip := centre + dir * reach * 0.98
		anchors.append(tip)
		parts.append([LowPoly.tube(PackedVector3Array([centre, tip]), PackedFloat32Array([0.018, 0.012]), 3), Transform3D.IDENTITY])
	for ring in 4:
		var f := 0.22 + ring * 0.2
		for s in spokes:
			var a := centre.lerp(anchors[s], f)
			var b := centre.lerp(anchors[(s + 1) % spokes], f)
			var sag := (a + b) / 2.0 + Vector3(0, -0.04 - ring * 0.02, 0)
			parts.append([LowPoly.tube(PackedVector3Array([a, sag, b]), PackedFloat32Array([0.012, 0.012, 0.012]), 3), Transform3D.IDENTITY])
	# A few torn hanging strands and a wrapped bundle stuck in it.
	for i in 3:
		var top := centre.lerp(anchors[i * 3], 0.6)
		parts.append([LowPoly.tube(PackedVector3Array([top, top + Vector3(0.05, -0.45, 0.0)]), PackedFloat32Array([0.012, 0.0]), 3), Transform3D.IDENTITY])
	parts.append([LowPoly.blob(0.13, Vector3(0.8, 1.6, 0.8), 0, 0.15, 3), LowPoly.at(centre.lerp(anchors[2], 0.45))])
	MonsterKit.part(root, LowPoly.merge(parts), Vector3.ZERO, silk)
	return root


func _build_model() -> void:
	var chitin := PS1Materials.get_material("rust_metal", Color(0.34, 0.27, 0.24))
	var hair := PS1Materials.get_material("concrete", Color(0.5, 0.42, 0.34))
	var pale := PS1Materials.get_material("concrete", Color(0.86, 0.82, 0.7))
	var eye := PS1Materials.get_material("concrete", Color(0.1, 0.1, 0.1), false, Vector2.ONE, Color(0.9, 0.75, 0.3))
	# Cephalothorax (front, -z) and a swollen abdomen behind with a bone-white skull mark.
	MonsterKit.part(_model, LowPoly.blob(0.36, Vector3(1.0, 0.65, 1.15), 1, 0.12, 2), Vector3(0, 0.64, -0.18), chitin)
	_abdomen = Node3D.new()
	_abdomen.position = Vector3(0, 0.82, 0.55)
	_model.add_child(_abdomen)
	MonsterKit.part(_abdomen, LowPoly.blob(0.62, Vector3(1.0, 0.85, 1.2), 1, 0.15, 5), Vector3(0, 0.05, 0.12), hair)
	MonsterKit.part(_abdomen, LowPoly.blob(0.22, Vector3(1.1, 0.4, 1.3), 0, 0.05, 1), Vector3(0, 0.55, 0.12), pale, Vector3(-15, 0, 0))
	for stripe in 3:
		MonsterKit.part(_abdomen, LowPoly.blob(0.1, Vector3(2.6, 0.25, 0.6), 0, 0.0, stripe), Vector3(0, 0.36 - stripe * 0.18, 0.62 + stripe * 0.06), pale, Vector3(-55 + stripe * 18, 0, 0))
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_abdomen, LowPoly.blob(0.07, Vector3(1, 0.4, 1), 0), Vector3(side * 0.1, 0.56, -0.04), chitin)
	MonsterKit.part(_abdomen, LowPoly.prism(5, 0.06, 0.0, 0.16), Vector3(0, -0.05, 0.86), chitin, Vector3(80, 0, 0))
	# A cluster of eyes and two curved fangs.
	var eyes := []
	for p: Vector3 in [Vector3(-0.07, 0.8, -0.46), Vector3(0.07, 0.8, -0.46), Vector3(-0.15, 0.76, -0.42),
			Vector3(0.15, 0.76, -0.42), Vector3(-0.04, 0.86, -0.42), Vector3(0.04, 0.86, -0.42),
			Vector3(-0.2, 0.7, -0.36), Vector3(0.2, 0.7, -0.36)]:
		eyes.append([LowPoly.blob(0.035 if absf(p.x) < 0.1 else 0.025, Vector3.ONE, 0), LowPoly.at(p)])
	MonsterKit.part(_model, LowPoly.merge(eyes), Vector3.ZERO, eye)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(side * 0.08, 0.62, -0.46),
			Vector3(side * 0.1, 0.48, -0.56), Vector3(side * 0.04, 0.36, -0.52)]), PackedFloat32Array([0.05, 0.035, 0.0]), 4), Vector3.ZERO, chitin)
		MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(side * 0.14, 0.58, -0.44),
			Vector3(side * 0.24, 0.5, -0.66), Vector3(side * 0.2, 0.34, -0.72)]), PackedFloat32Array([0.035, 0.03, 0.02]), 4), Vector3.ZERO, hair)
	# Eight legs: up to a high knee, then down to the floor in a wide ring.
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var k := i % 4
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.22, 0.62, -0.34 + k * 0.13)
		_model.add_child(hip)
		var spread := (k - 1.5) * 0.55  # front legs reach forward, back legs back
		var out := Vector3(side * cos(spread), 0, sin(spread))
		var knee := out * 0.62 + Vector3(0, 0.55, 0)
		var ankle := out * 1.08 + Vector3(0, 0.05, 0)
		var foot := out * 1.18 + Vector3(0, -0.6, 0)
		MonsterKit.part(hip, LowPoly.tube(PackedVector3Array([Vector3.ZERO, knee, ankle, foot]),
			PackedFloat32Array([0.08, 0.06, 0.04, 0.0]), 4), Vector3.ZERO, chitin)
		MonsterKit.part(hip, LowPoly.blob(0.05, Vector3.ONE, 0), knee, hair)
		# Bristles on the upper leg.
		var hairs := []
		for h in 3:
			var p := knee * (0.3 + h * 0.2)
			hairs.append([LowPoly.prism(3, 0.012, 0.0, 0.1), LowPoly.at(p + Vector3(0, 0.03, 0), Vector3(0, 0, -30 * side))])
		MonsterKit.part(hip, LowPoly.merge(hairs), Vector3.ZERO, hair)
		_legs.append(hip)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.35)
	glow.light_energy = 0.3
	glow.omni_range = 1.0
	glow.position = Vector3(0, 0.8, -0.6)
	_model.add_child(glow)
