class_name Hound
extends Prowler
## 剝皮獵犬: skinless dogs on long backward-bent legs that hunt as a pack of two or three.
## Dominates by ABILITY and INTELLIGENCE: faster than a sprint, and they coordinate. The
## big one with the spine crest howls to mark you and stays in front, holding your eyes,
## while the others circle round and bite you from behind.
## Weaknesses players can learn:
##   - Hurt the crested pack leader badly and the whole pack loses its nerve and runs.
##   - They only bite from behind: put your back to a wall or a teammate.
## Tell: a rising howl, then panting circling closer.

enum State { ROAM, HOWL, HUNT, FLEE }

const RADIUS := 0.35
const RUN_SPEED := 6.4    # a sprint is 5.5
const STALK_SPEED := 2.4
const TROT_SPEED := 2.6
const SIGHT := 20.0
const HOWL_TIME := 1.6
const BITE_RANGE := 1.6
const BITE_DAMAGE := 18.0
const BITE_COOLDOWN := 2.4
const LEADER_HOLD := 5.0   # the leader keeps this far in front of you
const FLANK_DISTANCE := 2.6
const LEADER_BREAK := 0.4  # the pack flees when the leader is below this much health
const FLEE_TIME := 25.0
const GIVE_UP := 30.0

## Replicated.
var state := State.ROAM
var is_leader := false:
	set(value):
		is_leader = value
		if is_node_ready():
			_crest.visible = value
			_model.scale = Vector3.ONE * (1.22 if value else 1.0)

var _target: Player = null
var _bite_cooldown := 0.0
var _howl := 0.0
var _flee := 0.0
var _hunt_time := 0.0
var _flank_side := 1.0
var _roam_goal := Vector3.ZERO
var _crest: Node3D
var _jaw: Node3D
var _legs: Array[Node3D] = []
var _gait := 0.0
var _last_pos := Vector3.ZERO
var _pant := 0.0


func _ready() -> void:
	setup_body(RADIUS, 0.9)
	add_to_group("hound_pack")
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state", ".:is_leader"])
	is_leader = is_leader
	_last_pos = global_position
	_roam_goal = global_position


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if multiplayer.is_server():
		_think(delta)
		move_and_slide()
	_animate(delta)


## Every hound in the pack; the leader is the oldest one still standing.
func pack() -> Array[Hound]:
	var result: Array[Hound] = []
	for node in get_tree().get_nodes_in_group("hound_pack"):
		if node is Hound and is_instance_valid(node) and not node.is_queued_for_deletion():
			result.append(node)
	result.sort_custom(func(a: Hound, b: Hound) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return result


func leader() -> Hound:
	var members := pack()
	return members[0] if not members.is_empty() else self


func on_hit(hit: Dictionary) -> float:
	# A hurt hound yelps; once the leader is badly hurt the nerve goes out of all of them.
	host_sound("screech", -4.0, 25.0, 1.9)
	if is_leader and health_ratio() - float(hit.get("amount", 0.0)) / maxf(get_meta("max_hp", 120.0), 1.0) < LEADER_BREAK:
		_pack_flee()
	elif state == State.ROAM and hit.get("attacker") is Player:
		_mark(hit.attacker)
	return 1.0


func host_kill() -> void:
	host_sound("death", 0.0, 30.0, 1.5)
	if is_leader:
		_pack_flee()
	remove_from_group("hound_pack")
	queue_free()


func _pack_flee() -> void:
	for hound in pack():
		hound._start_flee()


func _start_flee() -> void:
	if state == State.FLEE:
		return
	state = State.FLEE
	_flee = FLEE_TIME
	_target = null
	host_sound("screech", -2.0, 30.0, 2.2)
	var far := global_position
	var best := -1.0
	for point in patrol_points:
		var d := 0.0
		for player in MonsterKit.active_players(get_tree()):
			d += point.distance_to(player.global_position)
		if d > best:
			best = d
			far = point
	_roam_goal = far


## The leader saw someone: the whole pack turns to them.
func _mark(player: Player) -> void:
	for hound in pack():
		if hound.state == State.FLEE:
			continue
		hound._target = player
		hound._hunt_time = 0.0
		hound.state = State.HUNT
	var lead := leader()
	lead.state = State.HOWL
	lead._howl = HOWL_TIME
	lead.host_sound("roar", 4.0, 60.0, 1.7)
	MonsterKit.tell(player, &"remote_warn", ["一聲長嚎……牠們盯上你了。別讓背後空著！", 0.3])


func _think(delta: float) -> void:
	is_leader = leader() == self
	_bite_cooldown = maxf(_bite_cooldown - delta, 0.0)
	match state:
		State.FLEE:
			_flee -= delta
			steer(_roam_goal, RUN_SPEED, delta)
			if _flee <= 0.0:
				state = State.ROAM
		State.HOWL:
			halt()
			if _target != null and is_instance_valid(_target):
				face_point(_target.global_position, 6.0, delta)
			_howl -= delta
			if _howl <= 0.0:
				state = State.HUNT
		State.HUNT:
			_hunt(delta)
		_:
			_roam(delta)


func _roam(delta: float) -> void:
	var lead := leader()
	if lead == self:
		if global_position.distance_to(_roam_goal) < 1.5:
			_roam_goal = random_patrol_point()
		steer(_roam_goal, TROT_SPEED, delta)
		for player in MonsterKit.active_players(get_tree()):
			if sees(player, 0.8, MonsterKit.sight(SIGHT)):
				_mark(player)
				return
	else:
		# Trot at the leader's flank.
		var offset := lead.global_basis * Vector3(_side() * 1.6, 0, 1.4)
		var spot := lead.global_position + offset
		steer(spot, TROT_SPEED * 1.4 if global_position.distance_to(spot) > 2.0 else 0.0, delta)
		if lead.state == State.FLEE:
			_start_flee()


func _side() -> float:
	var members := pack()
	return 1.0 if members.find(self) % 2 == 1 else -1.0


func _hunt(delta: float) -> void:
	_hunt_time += delta
	if _target == null or not is_instance_valid(_target) or not _target.is_active() or _hunt_time > GIVE_UP \
			or global_position.distance_to(_target.global_position) > MonsterKit.sight(SIGHT) * 2.0:
		_target = null
		state = State.ROAM
		return
	var to := _target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var facing := _target.look_direction()
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	if is_leader and pack().size() > 1:
		# Hold the player's eyes from the front, stalking back and forth.
		var front := _target.global_position + facing.rotated(Vector3.UP, sin(_hunt_time * 0.8) * 0.6) * LEADER_HOLD
		if distance < BITE_RANGE:
			_bite()
		steer(front, STALK_SPEED if global_position.distance_to(front) < 3.0 else RUN_SPEED, delta)
		face_point(_target.global_position, 8.0, delta)
		return
	# Circle round to the player's back, then go in.
	var behind := -facing.dot(-to.normalized()) if distance > 0.01 else 0.0
	var at_back := behind > 0.3  # we are behind them (they are not looking at us)
	if at_back and distance < BITE_RANGE:
		_bite()
	elif at_back or pack().size() == 1 and _hunt_time > 8.0:
		steer(_target.global_position, RUN_SPEED, delta, 10.0, 6.0)
	else:
		var flank := _target.global_position - facing.rotated(Vector3.UP, 0.7 * _side()) * FLANK_DISTANCE
		# Swing wide so it doesn't cut across the player's view.
		if distance < 4.0:
			flank += facing.cross(Vector3.UP) * _side() * 2.0
		steer(flank, RUN_SPEED, delta, 10.0)


func _bite() -> void:
	halt()
	if _bite_cooldown > 0.0:
		return
	_bite_cooldown = BITE_COOLDOWN
	face_point(_target.global_position, 60.0, 1.0)
	host_sound("bite", 2.0, 25.0, 0.8)
	_snap.rpc()
	MonsterKit.tell(_target, &"remote_damage", [BITE_DAMAGE, "被剝皮獵犬從背後咬倒了", "有東西從背後咬了你一口！"])
	# Dart away and come round again.
	velocity = -forward() * 4.0


@rpc("authority", "call_local", "unreliable")
func _snap() -> void:
	if _jaw != null:
		var tween := create_tween()
		tween.tween_property(_jaw, "rotation:x", 0.9, 0.06)
		tween.tween_property(_jaw, "rotation:x", 0.25, 0.2)


func _animate(delta: float) -> void:
	var moved := (global_position - _last_pos)
	moved.y = 0.0
	_last_pos = global_position
	var speed := moved.length() / maxf(delta, 0.001)
	_gait += delta * clampf(speed * 2.6, 0.0, 18.0)
	var swing := clampf(speed / RUN_SPEED, 0.0, 1.0) * 0.8
	for i in _legs.size():
		var phase := _gait + (PI if i % 2 == 1 else 0.0) + (0.6 if i >= 2 else 0.0)
		_legs[i].rotation.x = sin(phase) * swing
	_model.position.y = absf(sin(_gait)) * 0.05 * swing
	if state == State.HOWL:
		_jaw.rotation.x = lerpf(_jaw.rotation.x, 0.8, delta * 6.0)
		_model.rotation.x = lerpf(_model.rotation.x, 0.35, delta * 4.0)
	else:
		_jaw.rotation.x = lerpf(_jaw.rotation.x, 0.25, delta * 4.0)
		_model.rotation.x = lerpf(_model.rotation.x, 0.0, delta * 4.0)
	_pant -= delta
	if _pant <= 0.0 and state == State.HUNT:
		_pant = rng.randf_range(0.5, 0.9)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP * 0.7, "hiss", -10.0, 14.0, rng.randf_range(1.6, 2.0))


func _build_model() -> void:
	var flesh := PS1Materials.get_material("concrete", Color(0.62, 0.36, 0.33))
	var sinew := PS1Materials.get_material("rust_metal", Color(0.4, 0.17, 0.15))
	var bone := PS1Materials.get_material("concrete", Color(0.86, 0.8, 0.66))
	var maw := PS1Materials.get_material("concrete", Color(0.1, 0.02, 0.02), false, Vector2.ONE, Color(0.35, 0.03, 0.02))
	# A starved barrel of a body, deep at the chest and pinched at the hips (head is -z).
	var body := PackedVector2Array([Vector2(0.0, -0.62), Vector2(0.12, -0.56), Vector2(0.17, -0.3),
		Vector2(0.22, 0.0), Vector2(0.27, 0.25), Vector2(0.24, 0.45), Vector2(0.12, 0.58), Vector2(0.0, 0.6)])
	MonsterKit.part(_model, LowPoly.lathe(body, 6), Vector3(0, 0.78, 0), flesh, Vector3(-90, 0, 0), Vector3(1.0, 1.0, 1.1))
	# Ribs showing through.
	var ribs := []
	for i in 4:
		var z := -0.3 - i * 0.12 + 0.36
		for side: float in [-1.0, 1.0]:
			ribs.append([LowPoly.tube(PackedVector3Array([Vector3(0.0, 0.98, z), Vector3(side * 0.23, 0.86, z - 0.02),
				Vector3(side * 0.2, 0.62, z - 0.06)]), PackedFloat32Array([0.025, 0.03, 0.015]), 4), Transform3D.IDENTITY])
	MonsterKit.part(_model, LowPoly.merge(ribs), Vector3.ZERO, bone)
	# A spine of knuckles down the back.
	var spine := []
	for i in 7:
		spine.append([LowPoly.prism(4, 0.04, 0.0, 0.08), LowPoly.at(Vector3(0, 0.99 - absf(i - 2.0) * 0.012, -0.45 + i * 0.15), Vector3(0, 45, 0))])
	MonsterKit.part(_model, LowPoly.merge(spine), Vector3.ZERO, bone)
	# The leader's crest: a row of long bone spines up the neck and back.
	_crest = Node3D.new()
	_model.add_child(_crest)
	var crest := []
	for i in 6:
		var h := 0.28 - absf(i - 1.5) * 0.04
		crest.append([LowPoly.prism(3, 0.045, 0.0, h), LowPoly.at(Vector3(0, 1.02 + h * 0.4, -0.55 + i * 0.13), Vector3(-25, 0, 0))])
	MonsterKit.part(_crest, LowPoly.merge(crest), Vector3.ZERO, bone)
	# Tail: a thin whip of sinew.
	MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(0, 0.82, 0.6), Vector3(0, 0.75, 0.85),
		Vector3(0, 0.55, 1.05)]), PackedFloat32Array([0.05, 0.03, 0.0]), 4), Vector3.ZERO, sinew)
	# Neck down and forward, then a long eyeless skull and a hinged jaw full of teeth.
	MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(0, 0.88, -0.5), Vector3(0, 0.85, -0.72),
		Vector3(0, 0.74, -0.86)]), PackedFloat32Array([0.15, 0.12, 0.1]), 6), Vector3.ZERO, sinew)
	var head := Node3D.new()
	head.position = Vector3(0, 0.74, -0.88)
	_model.add_child(head)
	var skull := PackedVector2Array([Vector2(0.0, -0.08), Vector2(0.11, -0.04), Vector2(0.12, 0.1),
		Vector2(0.08, 0.28), Vector2(0.05, 0.4), Vector2(0.0, 0.42)])
	MonsterKit.part(head, LowPoly.lathe(skull, 6), Vector3(0, 0.04, 0), bone, Vector3(-90, 0, 0), Vector3(1.0, 1.0, 0.8))
	MonsterKit.part(head, LowPoly.blob(0.07, Vector3(1.4, 0.6, 2.2), 0), Vector3(0, 0.0, -0.18), maw)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0.0, 0.0)
	_jaw.rotation.x = 0.25
	head.add_child(_jaw)
	MonsterKit.part(_jaw, LowPoly.tube(PackedVector3Array([Vector3(0, -0.04, 0.02), Vector3(0, -0.07, -0.2),
		Vector3(0, -0.04, -0.4)]), PackedFloat32Array([0.08, 0.06, 0.02]), 4), Vector3.ZERO, bone, Vector3.ZERO, Vector3(1.3, 1.0, 1.0))
	var teeth := []
	for i in 4:
		for side: float in [-1.0, 1.0]:
			teeth.append([LowPoly.prism(3, 0.018, 0.0, 0.07), LowPoly.at(Vector3(side * 0.05, -0.02, -0.12 - i * 0.07))])
			teeth.append([LowPoly.prism(3, 0.018, 0.0, 0.07), LowPoly.at(Vector3(side * 0.05, -0.01, -0.12 - i * 0.07), Vector3(180, 0, 0))])
	MonsterKit.part(_jaw, LowPoly.merge(teeth.slice(0, 8)), Vector3.ZERO, bone)
	MonsterKit.part(head, LowPoly.merge(teeth.slice(8)), Vector3(0, 0.0, 0.0), bone)
	# Four long legs with the knee bent backward like a hare's, hung from hip pivots.
	for i in 4:
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.17, 0.82, -0.42 if front else 0.42)
		_model.add_child(hip)
		var knee := Vector3(0.02 * side, -0.38, -0.08 if front else 0.18)
		var hock := Vector3(0.0, -0.62, 0.06 if front else -0.02)
		var foot := Vector3(0.0, -0.8, -0.1 if front else -0.14)
		MonsterKit.part(hip, LowPoly.tube(PackedVector3Array([Vector3.ZERO, knee, hock, foot]),
			PackedFloat32Array([0.09 if not front else 0.07, 0.045, 0.035, 0.03]), 5), Vector3.ZERO, sinew)
		MonsterKit.part(hip, LowPoly.blob(0.045, Vector3.ONE, 0), knee, bone)
		var claws := []
		for c in 3:
			var a := (c - 1.0) * 0.35
			claws.append([LowPoly.tube(PackedVector3Array([foot, foot + Vector3(sin(a) * 0.07, -0.01, -0.09)]),
				PackedFloat32Array([0.02, 0.0]), 3), Transform3D.IDENTITY])
		MonsterKit.part(hip, LowPoly.merge(claws), Vector3.ZERO, bone)
		_legs.append(hip)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.15)
	glow.light_energy = 0.35
	glow.omni_range = 1.2
	glow.position = Vector3(0, 0.75, -1.0)
	_model.add_child(glow)
