class_name DriftEye
extends Node3D
## 窺視眼: bloodshot eyeballs the size of a head, drifting near the ceiling on little
## leathery wings with their nerves trailing beneath. They come in twos to fours.
## Dominates by ABILITY: they fly, they never lose sight of you, and while one stares at
## you it shrieks your position to everything in the building.
## Now and then one dives at your face.
## Weaknesses players can learn:
##   - Fragile: one or two good hits pop them, and a stun or shock drops them to the
##     floor where they flop helplessly.
##   - They dodge erratically when you aim right at them: wait until it dives, then shoot.
##   - They only follow what they can see: break line of sight and they lose you.
## Tell: wet flapping overhead and a rising whine as one locks on.

enum State { DRIFT, WATCH, DIVE, CLIMB, DOWNED }

const DRIFT_SPEED := 1.4
const WATCH_SPEED := 3.2
const DIVE_SPEED := 8.5
const SIGHT := 18.0
const HOVER_HEIGHT := 2.4
const HOVER_DISTANCE := 3.5
const MARK_INTERVAL := 3.5
const MARK_RADIUS := 30.0
const DIVE_AFTER := Vector2(4.0, 7.0)
const DIVE_DAMAGE := 12.0
const DOWNED_TIME := 4.0
const LOSE_TIME := 3.0

## Replicated.
var state := State.DRIFT
var home := Vector3.ZERO
var rng := RandomNumberGenerator.new()

var _target: Player = null
var _mark := 0.0
var _dive_timer := 0.0
var _lost := 0.0
var _downed := 0.0
var _fall_speed := 0.0
var _goal := Vector3.ZERO
var _jink := Vector3.ZERO
var _jink_timer := 0.0
var _dive_from := Vector3.ZERO
var _climb := 0.0
var _model: Node3D
var _iris: Node3D
var _wings: Array[Node3D] = []
var _tendrils: Array[Node3D] = []
var _flap := 0.0
var _flap_sound := 0.0


func _ready() -> void:
	add_to_group("monsters")
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state"])
	if home == Vector3.ZERO:
		home = global_position
	_goal = global_position
	_flap = rng.randf() * TAU


func _process(delta: float) -> void:
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func on_hit(hit: Dictionary) -> float:
	var effects: Dictionary = hit.get("effects", {})
	if state == State.DOWNED:
		return 2.0
	if effects.has("stun") or effects.has("chain"):
		_knock_down()
		return 1.0
	# Startled into a jink.
	_jink = Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized() * 4.0
	_jink_timer = 0.4
	_play_cry.rpc(1.8)
	return 1.0


func host_kill() -> void:
	_pop.rpc()
	queue_free()


func _knock_down() -> void:
	state = State.DOWNED
	_downed = DOWNED_TIME
	_fall_speed = 0.0
	_play_cry.rpc(0.8)


func _think(delta: float) -> void:
	match state:
		State.DOWNED:
			_downed -= delta
			# Fall to the floor and lie there.
			_fall_speed = minf(_fall_speed + 9.8 * delta, 12.0)
			var down := Vector3.DOWN * _fall_speed * delta
			if MonsterKit.clear_line(get_world_3d(), global_position, global_position + down + Vector3.DOWN * 0.3):
				global_position += down
			else:
				_fall_speed = 0.0
			if _downed <= 0.0:
				state = State.CLIMB
				_climb = 1.5
				_dive_from = global_position + Vector3.UP * HOVER_HEIGHT
			return
		State.DIVE:
			_dive(delta)
			return
		State.CLIMB:
			_climb -= delta
			_fly_to(_dive_from, WATCH_SPEED, delta)
			if _climb <= 0.0 or global_position.distance_to(_dive_from) < 0.4:
				state = State.WATCH if _target != null else State.DRIFT
			return
	if _target != null and (not is_instance_valid(_target) or not _target.is_active()):
		_target = null
	if _target != null:
		_watch(delta)
		return
	state = State.DRIFT
	if global_position.distance_to(_goal) < 0.6:
		_goal = home + Vector3(rng.randf_range(-6, 6), rng.randf_range(-0.8, 0.8), rng.randf_range(-6, 6))
	_fly_to(_goal, DRIFT_SPEED, delta)
	for player in MonsterKit.active_players(get_tree()):
		if _sees(player):
			_target = player
			_lost = 0.0
			_mark = 0.5
			_dive_timer = rng.randf_range(DIVE_AFTER.x, DIVE_AFTER.y)
			state = State.WATCH
			_play_cry.rpc(1.2)
			MonsterKit.tell(player, &"remote_warn", ["頭頂有濕濕的拍翅聲……一顆眼球盯著你，牠在尖叫通報你的位置！", 0.2])
			return


func _sees(player: Player) -> bool:
	var eye := player.head_position()
	return global_position.distance_to(eye) < MonsterKit.sight(SIGHT) and MonsterKit.clear_line(get_world_3d(), global_position, eye)


func _watch(delta: float) -> void:
	if _sees(_target):
		_lost = 0.0
	else:
		_lost += delta
		if _lost > LOSE_TIME:
			_target = null
			home = global_position
			state = State.DRIFT
			return
	# Hover above and in front of the player, keeping its distance, never still.
	var head := _target.head_position()
	var flat := global_position - head
	flat.y = 0.0
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.BACK
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 97)
	var orbit := flat.rotated(Vector3.UP, sin(t * 0.7) * 0.6)
	var spot := head + orbit * HOVER_DISTANCE + Vector3.UP * (HOVER_HEIGHT - 1.0 + sin(t * 1.3) * 0.4)
	# Erratic when aimed at: a sharp sideways jink.
	var aimed := _target.look_direction().dot((global_position - head).normalized()) > 0.985
	_jink_timer -= delta
	if aimed and _jink_timer <= 0.0:
		_jink = orbit.cross(Vector3.UP) * (1.0 if rng.randf() < 0.5 else -1.0) * 5.0 + Vector3.UP * rng.randf_range(-1.5, 1.5)
		_jink_timer = rng.randf_range(0.35, 0.7)
	_fly_to(spot, WATCH_SPEED, delta)
	_look(head, delta)
	_mark -= delta
	if _mark <= 0.0:
		_mark = MARK_INTERVAL
		# The shriek: every monster nearby hears where you are.
		GameNoise.emit_local(get_tree(), _target.global_position, MARK_RADIUS, GameNoise.Kind.VOICE)
		_play_cry.rpc(1.0)
	_dive_timer -= delta
	if _dive_timer <= 0.0 and _lost <= 0.0:
		state = State.DIVE
		_dive_from = global_position
		_play_cry.rpc(1.6)


func _dive(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_active():
		state = State.CLIMB
		_climb = 1.0
		return
	var head := _target.head_position() + Vector3.DOWN * 0.15
	var to := head - global_position
	if to.length() < 0.6:
		MonsterKit.tell(_target, &"remote_damage", [DIVE_DAMAGE, "被窺視眼撞進了眼窩", "一顆眼球撞上你的臉！"])
		_play_cry.rpc(2.0)
		state = State.CLIMB
		_climb = 1.6
		_dive_timer = rng.randf_range(DIVE_AFTER.x, DIVE_AFTER.y)
		return
	var step := to.normalized() * DIVE_SPEED * delta
	var next := global_position + step
	if MonsterKit.clear_line(get_world_3d(), global_position, next + step.normalized() * 0.2):
		global_position = next
	else:
		state = State.CLIMB
		_climb = 1.0
	_look(head, delta)


func _fly_to(goal: Vector3, speed: float, delta: float) -> void:
	var to := goal - global_position
	var wobble := Vector3(sin(_flap * 0.13), cos(_flap * 0.11) * 0.5, sin(_flap * 0.07 + 2.0)) * 0.5
	var velocity := (to.normalized() + wobble).normalized() * speed if to.length() > 0.05 else wobble * speed
	if _jink_timer > 0.0:
		velocity += _jink
		_jink = _jink.lerp(Vector3.ZERO, minf(delta * 4.0, 1.0))
	var step := velocity * delta
	if step.length() > to.length() + 0.2 and _jink_timer <= 0.0:
		step = to
	var next := global_position + step
	if MonsterKit.clear_line(get_world_3d(), global_position, next + step.normalized() * 0.3):
		global_position = next
	else:
		_goal = home
		_jink = Vector3.ZERO
	if state == State.DRIFT and step.length() > 0.001:
		_look(global_position + Vector3(step.x, 0, step.z) * 10.0 + Vector3.DOWN * 0.5, delta)


func _look(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if to.length() < 0.05 or absf(to.normalized().y) > 0.98:
		return
	var target := global_transform.looking_at(point, Vector3.UP)
	global_basis = global_basis.slerp(target.basis, minf(delta * 6.0, 1.0)).orthonormalized()


@rpc("authority", "call_local", "unreliable")
func _play_cry(pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position, "screech", -4.0 if pitch < 1.5 else 0.0, 35.0, pitch * rng.randf_range(1.5, 1.8))


@rpc("authority", "call_local", "reliable")
func _pop() -> void:
	Sfx.play_3d(get_parent(), global_position, "bite", 2.0, 25.0, 1.6)
	Sfx.play_3d(get_parent(), global_position, "death", -4.0, 25.0, 2.2)


func _animate(delta: float) -> void:
	var flying := state != State.DOWNED
	_flap += delta * (26.0 if flying else 2.0)
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = (sin(_flap) * 0.8 + 0.15) * side if flying else 1.2 * side
	for i in _tendrils.size():
		_tendrils[i].rotation.x = sin(_flap * 0.2 + i) * 0.35 + (0.9 if state == State.DIVE else 0.0)
	# The iris twitches; in a dive it shrinks to a pinpoint.
	_iris.scale = Vector3.ONE * (0.55 if state == State.DIVE else 1.0 + sin(_flap * 0.05) * 0.08)
	_model.position.y = 0.35 if flying else 0.0
	if flying:
		_flap_sound -= delta
		if _flap_sound <= 0.0:
			_flap_sound = 0.45
			Sfx.play_3d(get_parent(), global_position, "flutter", -8.0, 16.0, rng.randf_range(0.5, 0.7))


func _build_model() -> void:
	# The model floats a little above the node, inside the shot window for small monsters.
	_model = Node3D.new()
	_model.position.y = 0.35
	add_child(_model)
	var white := PS1Materials.get_material("concrete", Color(0.92, 0.88, 0.8), false, Vector2.ONE, Color(0.12, 0.1, 0.08))
	var vein := PS1Materials.get_material("concrete", Color(0.7, 0.12, 0.1))
	var iris := PS1Materials.get_material("concrete", Color(0.55, 0.15, 0.08), false, Vector2.ONE, Color(0.6, 0.12, 0.05))
	var pupil := PS1Materials.get_material("concrete", Color(0.02, 0.02, 0.02))
	var skin := PS1Materials.get_material("concrete", Color(0.45, 0.3, 0.28))
	MonsterKit.part(_model, LowPoly.blob(0.24, Vector3.ONE, 1, 0.03, 7), Vector3.ZERO, white)
	# Veins crawling forward over the white.
	var veins := []
	for i in 7:
		var a := TAU * i / 7.0
		var back := Vector3(cos(a) * 0.15, sin(a) * 0.15, 0.18)
		var mid := Vector3(cos(a + 0.2) * 0.23, sin(a + 0.2) * 0.23, 0.0)
		var front := Vector3(cos(a - 0.1) * 0.16, sin(a - 0.1) * 0.16, -0.17)
		veins.append([LowPoly.tube(PackedVector3Array([back, mid, front]), PackedFloat32Array([0.016, 0.012, 0.0]), 3), Transform3D.IDENTITY])
	MonsterKit.part(_model, LowPoly.merge(veins), Vector3.ZERO, vein)
	_iris = Node3D.new()
	_iris.position = Vector3(0, 0, -0.2)
	_model.add_child(_iris)
	MonsterKit.part(_iris, LowPoly.prism(8, 0.12, 0.12, 0.05), Vector3.ZERO, iris, Vector3(90, 0, 0))
	MonsterKit.part(_iris, LowPoly.prism(8, 0.055, 0.055, 0.06), Vector3(0, 0, -0.008), pupil, Vector3(90, 0, 0))
	# Leathery bat wings on hinges either side.
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.18, 0.08, 0.06)
		_model.add_child(hinge)
		var outline := PackedVector2Array()
		for p: Vector2 in [Vector2(0.0, -0.06), Vector2(0.18, -0.16), Vector2(0.36, -0.12), Vector2(0.46, 0.02),
				Vector2(0.38, 0.06), Vector2(0.3, 0.14), Vector2(0.2, 0.08), Vector2(0.12, 0.16), Vector2(0.02, 0.06)]:
			outline.append(Vector2(p.x * side, p.y))
		if side < 0.0:
			outline.reverse()
		MonsterKit.part(hinge, LowPoly.extrude(outline, 0.012), Vector3.ZERO, skin, Vector3(90, 0, 0))
		MonsterKit.part(hinge, LowPoly.tube(PackedVector3Array([Vector3.ZERO, Vector3(side * 0.2, 0.0, -0.16), Vector3(side * 0.46, 0, 0.0)]),
			PackedFloat32Array([0.015, 0.012, 0.0]), 3), Vector3(0, 0.01, 0), vein)
		_wings.append(hinge)
	# The optic nerve and a few dangling tendrils.
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var root := Node3D.new()
		root.position = Vector3(cos(a) * 0.08, -0.12 + sin(a) * 0.04, 0.18)
		_model.add_child(root)
		var length := 0.45 if i == 0 else 0.3
		MonsterKit.part(root, LowPoly.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.02, -length * 0.5, 0.1),
			Vector3(-0.02, -length, 0.12)]), PackedFloat32Array([0.035 if i == 0 else 0.02, 0.015, 0.0]), 4), Vector3.ZERO, vein)
		_tendrils.append(root)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.3, 0.2)
	glow.light_energy = 0.3
	glow.omni_range = 1.2
	glow.position = Vector3(0, 0, -0.35)
	_model.add_child(glow)
