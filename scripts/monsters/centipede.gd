class_name Centipede
extends Node3D
## 蜈蚣列車: a creature as long as a train that tears around a fixed loop at full
## speed, crushing anything in its way. Dominates by SIZE and ABILITY: you can't
## outrun it and you can't stop it.
## Weakness players can learn: its route never changes. Learn the loop and step
## aside, into a room or a gap, before it comes through.
## Tells: a rumble that grows, and its headlamp sweeping down the corridor first.

const SEGMENTS := 14
const SEGMENT_SPACING := 1.1
const RUN_SPEED := 10.0
const REST_TIME := 9.0
const KILL_RADIUS := 1.3
const WARN_DISTANCE := 22.0

## The loop it runs, built once from the map's patrol points (the same every time).
var route: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
## Replicated: whether it is running (clients play the rumble), and its body trail.
var running := false:
	set(value):
		running = value
		if is_node_ready():
			if value and not _rumble.playing:
				_rumble.play()
			elif not value:
				_rumble.stop()
var trail: PackedVector3Array = PackedVector3Array()

var _agent_path: PackedVector3Array = PackedVector3Array()
var _path_index := 0
var _leg := 0
var _rest := 4.0
var _segments: Array[Node3D] = []
var _head: Node3D
var _rumble: AudioStreamPlayer3D
var _warned := {}


func _ready() -> void:
	add_to_group("monsters")
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:running", ".:trail"])
	if trail.is_empty():
		for i in SEGMENTS:
			trail.append(global_position)


## Orders patrol points into a loop around their centre: a fixed, learnable route.
static func make_route(points: Array[Vector3]) -> Array[Vector3]:
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= maxf(points.size(), 1)
	var loop: Array[Vector3] = points.duplicate()
	loop.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2(a.z - center.z, a.x - center.x) < atan2(b.z - center.z, b.x - center.x))
	return loop


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_think(delta)
	_pose_body()


func _think(delta: float) -> void:
	if route.size() < 2:
		return
	if _rest > 0.0:
		_rest -= delta
		running = false
		if _rest <= 0.0:
			_plan_leg()
		return
	running = true
	var step := RUN_SPEED * delta
	while step > 0.0 and _path_index < _agent_path.size():
		var target := _agent_path[_path_index]
		var to := target - global_position
		to.y = 0.0
		if to.length() <= step:
			global_position = Vector3(target.x, global_position.y, target.z)
			step -= to.length()
			_path_index += 1
		else:
			global_position += to.normalized() * step
			step = 0.0
	_record_trail()
	_crush()
	_warn_ahead()
	if _path_index >= _agent_path.size():
		_leg = (_leg + 1) % route.size()
		# A breather at every other stop, so the loop has a rhythm you can learn.
		if _leg % 2 == 0:
			_rest = REST_TIME
		else:
			_plan_leg()


func _plan_leg() -> void:
	var from := route[_leg]
	var to := route[(_leg + 1) % route.size()]
	var map := get_world_3d().navigation_map
	_agent_path = NavigationServer3D.map_get_path(map, global_position, to, true)
	if _agent_path.is_empty():
		_agent_path = PackedVector3Array([from, to])
	_path_index = 0
	_warned.clear()


func _record_trail() -> void:
	var head := global_position
	if trail.is_empty() or trail[0].distance_to(head) >= SEGMENT_SPACING * 0.5:
		trail.insert(0, head)
		while trail.size() > SEGMENTS * 2:
			trail.remove_at(trail.size() - 1)


## Anyone the head or body passes over is flattened.
func _crush() -> void:
	for player in MonsterKit.active_players(get_tree()):
		var at := player.global_position
		for i in range(0, mini(trail.size(), SEGMENTS * 2), 2):
			var segment := trail[i]
			if Vector2(at.x - segment.x, at.z - segment.z).length() < KILL_RADIUS and absf(at.y - segment.y) < 2.0:
				MonsterKit.tell(player, &"remote_damage", [999.0, "被蜈蚣列車輾過去了"])
				break


func _warn_ahead() -> void:
	for player in MonsterKit.active_players(get_tree()):
		if _warned.has(player):
			continue
		if player.global_position.distance_to(global_position) < WARN_DISTANCE:
			_warned[player] = true
			MonsterKit.tell(player, &"remote_warn", ["地板在震…有很長的東西衝過來了！閃進旁邊的房間！", 0.6])


func _pose_body() -> void:
	for i in _segments.size():
		var index := mini(i * 2, trail.size() - 1)
		if index < 0:
			continue
		var at := trail[index]
		var ahead := trail[maxi(index - 1, 0)]
		_segments[i].global_position = at + Vector3.UP * 0.6
		var dir := ahead - at
		if index == 0 and trail.size() > 1:
			dir = at - trail[1]  # the head has nothing ahead of it, so it faces away from the next point
		dir.y = 0.0
		if dir.length() > 0.01:
			_segments[i].global_rotation.y = atan2(-dir.x, -dir.z)
		var t := Time.get_ticks_msec() * 0.02 + i
		for leg in _segments[i].get_children():
			if leg.name.begins_with("Leg"):
				leg.rotation.x = sin(t) * 0.6 if running else 0.0


func _build_model() -> void:
	var shell := PS1Materials.get_material("rust_metal", Color(0.7, 0.5, 0.38))
	var leg_mat := PS1Materials.get_material("concrete", Color(0.2, 0.15, 0.12))
	var lamp := PS1Materials.get_material("concrete", Color(0.3, 0.3, 0.2), false, Vector2.ONE, Color(1.0, 0.95, 0.6))
	var flesh := PS1Materials.get_material("concrete", Color(0.42, 0.26, 0.22))
	# Every body segment shares the same few meshes: an arched carapace like a carriage
	# roof, the overlapping rim of the plate in front, a riveted spine plate and a soft belly.
	var body_shell := _segment_shell(1.0)
	var body_dark := _segment_trim(1.0)
	var body_belly := LowPoly.blob(0.5, Vector3(1.2, 0.45, 0.85), 0, 0.12, 11)
	var leg_mesh := _leg_mesh(1.0)
	var leg_mesh_l := _leg_mesh(-1.0)
	for i in SEGMENTS:
		var segment := Node3D.new()
		segment.name = "Segment%d" % i
		add_child(segment)
		segment.top_level = true
		var size := 1.0 if i > 0 else 1.2
		if i > 0:
			MonsterKit.part(segment, body_shell, Vector3.ZERO, shell)
			MonsterKit.part(segment, body_dark, Vector3.ZERO, leg_mat)
			MonsterKit.part(segment, body_belly, Vector3(0, -0.3, 0.05), flesh)
		else:
			MonsterKit.part(segment, _segment_shell(size), Vector3.ZERO, shell)
			MonsterKit.part(segment, _segment_trim(size), Vector3.ZERO, leg_mat)
			MonsterKit.part(segment, body_belly, Vector3(0, -0.36, 0.05), flesh, Vector3.ZERO, Vector3.ONE * 1.1)
		for side in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(0.7 * side, 0.0, 0)
			segment.add_child(leg)
			leg.name = "Leg%d" % (1 if side > 0 else 0)
			leg.rotation.z = 0.5 * side
			MonsterKit.part(leg, leg_mesh if side > 0 else leg_mesh_l, Vector3.ZERO, leg_mat)
		_segments.append(segment)
	_head = _segments[0]
	# The head: a sloped cow-catcher of a face with a round headlamp, clusters of eyes,
	# feelers and a pair of hooked mandibles.
	MonsterKit.part(_head, LowPoly.prism(8, 0.26, 0.3, 0.14), Vector3(0, 0.1, -0.58), leg_mat, Vector3(-90, 22.5, 0))
	MonsterKit.part(_head, LowPoly.prism(8, 0.2, 0.2, 0.08), Vector3(0, 0.1, -0.66), lamp, Vector3(-90, 22.5, 0))
	var eye := PS1Materials.get_material("concrete", Color(0.15, 0.05, 0.05), false, Vector2.ONE, Color(0.6, 0.08, 0.04))
	var eyes := []
	for side in [-1.0, 1.0]:
		for k in 3:
			eyes.append([LowPoly.blob(0.06 - k * 0.012, Vector3.ONE, 0),
				LowPoly.at(Vector3(side * (0.42 + k * 0.1), 0.32 - k * 0.07, -0.5 + k * 0.06))])
	MonsterKit.part(_head, LowPoly.merge(eyes), Vector3.ZERO, eye)
	var feelers := []
	for side in [-1.0, 1.0]:
		feelers.append([LowPoly.tube(PackedVector3Array([Vector3(side * 0.3, 0.55, -0.45), Vector3(side * 0.5, 0.95, -0.85),
			Vector3(side * 0.75, 1.05, -1.35), Vector3(side * 0.95, 0.85, -1.75)]),
			PackedFloat32Array([0.04, 0.03, 0.02, 0.0]), 4), Transform3D.IDENTITY])
		feelers.append([LowPoly.tube(PackedVector3Array([Vector3(side * 0.42, -0.2, -0.5), Vector3(side * 0.55, -0.25, -0.85),
			Vector3(side * 0.38, -0.27, -1.12), Vector3(side * 0.12, -0.3, -1.18)]),
			PackedFloat32Array([0.09, 0.08, 0.05, 0.0]), 5), Transform3D.IDENTITY])
	MonsterKit.part(_head, LowPoly.merge(feelers), Vector3.ZERO, leg_mat)
	var beam := SpotLight3D.new()
	beam.position = Vector3(0, 0.1, -0.6)
	beam.light_color = Color(1.0, 0.95, 0.7)
	beam.light_energy = 3.0
	beam.spot_range = 20.0
	beam.spot_angle = 30.0
	_head.add_child(beam)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = Sfx.looped("rumble")
	_rumble.unit_size = 14.0
	_rumble.max_distance = 60.0
	_rumble.volume_db = 4.0
	_head.add_child(_rumble)


## The armoured shell of one segment, `size` times the body size (the head is bigger):
## a faceted barrel tapering front and back, like a carriage with its ends rounded off.
static func _segment_shell(size: float) -> ArrayMesh:
	var barrel := PackedVector2Array([Vector2(0.0, -0.44), Vector2(0.42, -0.42), Vector2(0.55, -0.12),
		Vector2(0.55, 0.22), Vector2(0.4, 0.46), Vector2(0.0, 0.48)])
	var parts := [[LowPoly.lathe(barrel, 8), LowPoly.at(Vector3(0, 0.02, 0), Vector3(90, 0, 22.5), Vector3(1.32, 1.0, 0.95) * size)]]
	if size > 1.0:
		# The head's cow-catcher: a plough of a lower lip under the lamp.
		var plough := PackedVector2Array([Vector2(0.0, -0.46), Vector2(0.5, -0.46), Vector2(0.0, -0.05)])
		parts.append([LowPoly.extrude(plough, 1.3), LowPoly.at(Vector3(0, 0, -0.38), Vector3(0, 90, 0))])
	return LowPoly.merge(parts)


## The dark trim of one segment: the lip of the plate, spine plate, rivets and spiracles.
static func _segment_trim(size: float) -> ArrayMesh:
	var parts := [[LowPoly.prism(8, 0.57, 0.53, 0.14, false), LowPoly.at(Vector3(0, 0.02, -0.4 * size), Vector3(90, 0, 22.5), Vector3(1.34, 1.0, 0.97) * size)]]
	# A ridged spine plate along the top.
	parts.append([LowPoly.prism(4, 0.3, 0.14, 0.14), LowPoly.at(Vector3(0, 0.53 * size, 0.05), Vector3(0, 45, 0), Vector3(0.7, 1.0, 1.2))])
	for side in [-1.0, 1.0]:
		parts.append([LowPoly.prism(4, 0.08, 0.05, 0.06), LowPoly.at(Vector3(side * 0.69 * size, 0.1, 0.05), Vector3(0, 0, -90 * side))])
	return LowPoly.merge(parts)


## A jointed leg hanging from its pivot, bending outward at the knee to a hooked tip.
static func _leg_mesh(side: float) -> ArrayMesh:
	return LowPoly.tube(PackedVector3Array([Vector3.ZERO, Vector3(side * 0.2, -0.3, -0.05),
		Vector3(side * 0.12, -0.55, 0.0), Vector3(side * 0.02, -0.74, 0.05)]),
		PackedFloat32Array([0.1, 0.075, 0.05, 0.0]), 4)
