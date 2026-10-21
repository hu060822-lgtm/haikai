class_name ShieldKnight
extends Prowler
## 盾甲騎士: a hunched giant in welded plate that carries a whole steel security door as a
## shield. Dominates by SIZE: nothing you carry gets through that door, and when it sees
## you down a straight line it lowers its head and charges like a train.
## Weaknesses players can learn:
##   - The door only covers its front. Flank it: its back is bare, hunched flesh.
##   - It charges in a dead straight line and can't stop. Stand in front of a wall,
##     sidestep at the last moment, and it slams in and staggers with its guard down.
## Tell: the door scraping along the floor, and a grinding roar before a charge.

enum State { PATROL, ADVANCE, WINDUP, CHARGE, STAGGER, RECOVER }

const RADIUS := 0.9
const BODY_SCALE := 1.6
const WALK_SPEED := 1.4
const ADVANCE_SPEED := 1.9
const CHARGE_SPEED := 9.5
const SIGHT := 24.0
const CHARGE_MIN := 4.0
const CHARGE_MAX := 20.0
const WINDUP_TIME := 1.3
const CHARGE_TIME := 3.0
const STAGGER_TIME := 5.5
const RECOVER_TIME := 1.8
const CHARGE_DAMAGE := 65.0
const SHOVE_DAMAGE := 25.0
const SHIELD_COVER := 0.3   # how far round the front the door covers (dot of the hit direction)

## Replicated.
var state := State.PATROL:
	set(value):
		state = value
var downed := false

var _target: Player = null
var _timer := 0.0
var _charge_dir := Vector3.FORWARD
var _charge_hit := {}
var _shove_cooldown := 0.0
var _goal := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _stuck := 0.0
var _shield: Node3D
var _legs: Array[Node3D] = []
var _torso: Node3D
var _gait := 0.0
var _scrape := 0.0


func _ready() -> void:
	setup_body(RADIUS, 3.8, BoilerColossus.RADIUS)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:state", ".:downed"])
	_goal = global_position
	_last_pos = global_position


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func is_guarding() -> bool:
	return state != State.STAGGER and not downed


## True if a shot from `from` lands on the door.
func blocks_from(from: Vector3) -> bool:
	var to := from - global_position
	to.y = 0.0
	return is_guarding() and to.length() > 0.01 and forward().dot(to.normalized()) > SHIELD_COVER


func on_hit(hit: Dictionary) -> float:
	var from: Vector3 = hit.get("from", global_position + forward() * 5.0)
	if blocks_from(from):
		host_sound("clank", 6.0, 40.0, rng.randf_range(0.55, 0.7), global_position + Vector3.UP * 1.6 + forward() * 1.0)
		_spark.rpc()
		# Being shot at from the front only tells it where you are.
		if hit.get("attacker") is Player and state == State.PATROL:
			_target = hit.attacker
			state = State.ADVANCE
		return 0.0
	host_sound("roar", 0.0, 40.0, 1.3)
	if state == State.STAGGER:
		return 2.0
	# Hit in the back: it wheels round toward the shooter.
	if state == State.PATROL or state == State.ADVANCE:
		if hit.get("attacker") is Player:
			_target = hit.attacker
		state = State.RECOVER
		_timer = 0.6
	return 1.25


func on_broken() -> void:
	downed = true
	state = State.STAGGER
	_timer = STAGGER_TIME + 8.0
	host_sound("boom", 4.0, 60.0, 0.5)


func _think(delta: float) -> void:
	_shove_cooldown = maxf(_shove_cooldown - delta, 0.0)
	if downed and state != State.STAGGER:
		downed = false
	match state:
		State.WINDUP:
			halt()
			_timer -= delta
			face_direction(_charge_dir, 6.0, delta)
			if _timer <= 0.0:
				state = State.CHARGE
				_timer = CHARGE_TIME
				_charge_hit.clear()
				rotation.y = atan2(-_charge_dir.x, -_charge_dir.z)
				host_sound("roar", 6.0, 60.0, 0.6)
		State.CHARGE:
			_charge(delta)
			return
		State.STAGGER:
			halt()
			_timer -= delta
			if _timer <= 0.0:
				downed = false
				state = State.RECOVER
				_timer = RECOVER_TIME
		State.RECOVER:
			halt()
			_timer -= delta
			if _target != null and is_instance_valid(_target):
				face_point(_target.global_position, 2.5, delta)
			if _timer <= 0.0:
				state = State.ADVANCE if _target != null else State.PATROL
		State.ADVANCE:
			_advance(delta)
		_:
			_patrol(delta)
	move_and_slide()


func _patrol(delta: float) -> void:
	if global_position.distance_to(_goal) < 2.0 or _goal == global_position:
		_goal = random_patrol_point()
	steer(_goal, WALK_SPEED, delta, 1.5)
	for player in MonsterKit.active_players(get_tree()):
		if _in_view(player):
			_target = player
			state = State.ADVANCE
			MonsterKit.tell(player, &"remote_warn", ["鐵門刮著地板……有個扛著門的巨人朝你轉過來了。", 0.3])
			return


func _in_view(player: Player) -> bool:
	var to := player.global_position - global_position
	to.y = 0.0
	var sight := MonsterKit.sight(SIGHT)
	return to.length() < sight and forward().dot(to.normalized()) > -0.2 and sees(player, 2.6, sight)


func _advance(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_active() \
			or global_position.distance_to(_target.global_position) > MonsterKit.sight(SIGHT) * 1.5:
		_target = null
		state = State.PATROL
		return
	var to := _target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	if distance < 2.4:
		halt()
		_shove(_target)
		face_point(_target.global_position, 2.0, delta)
		return
	if distance > CHARGE_MIN and distance < CHARGE_MAX and _clear_lane(_target) \
			and forward().dot(to.normalized()) > 0.8:
		state = State.WINDUP
		_timer = WINDUP_TIME
		_charge_dir = to.normalized()
		host_sound("clank", 2.0, 40.0, 0.35)
		_play_windup.rpc()
		return
	steer(_target.global_position, ADVANCE_SPEED, delta, 1.2, 0.0)


## A straight run at the player with room for its body: no wall in the way.
func _clear_lane(player: Player) -> bool:
	var space := get_world_3d().direct_space_state
	var side := Vector3.UP.cross(player.global_position - global_position).normalized() * (RADIUS * 0.8)
	for offset: Vector3 in [Vector3.ZERO, side, -side]:
		var from := global_position + Vector3.UP * 1.0 + offset
		var to := player.global_position + Vector3.UP * 1.0 + offset
		var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and not hit.collider is Player:
			return false
	return true


func _shove(player: Player) -> void:
	if _shove_cooldown > 0.0:
		return
	_shove_cooldown = 2.5
	host_sound("bang", 4.0, 35.0, 0.6)
	MonsterKit.tell(player, &"remote_damage", [SHOVE_DAMAGE, "被盾甲騎士的鐵門壓扁了", "鐵門撞在你身上！"])
	var push := (player.global_position - global_position)
	push.y = 0.0
	host_affect(player, {"push": push.normalized() * 9.0 + Vector3.UP * 2.0, "shake": 0.6})


func _charge(delta: float) -> void:
	_timer -= delta
	velocity.x = _charge_dir.x * CHARGE_SPEED
	velocity.z = _charge_dir.z * CHARGE_SPEED
	var before := global_position
	move_and_slide()
	var moved := (global_position - before).length()
	# Trample anyone in front of the door.
	for player in MonsterKit.active_players(get_tree()):
		if _charge_hit.has(player):
			continue
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < RADIUS + 1.0 and _charge_dir.dot(to.normalized()) > 0.0 \
				and absf(player.global_position.y - global_position.y) < 2.0:
			_charge_hit[player] = true
			host_sound("bang", 6.0, 40.0, 0.5, player.global_position)
			MonsterKit.tell(player, &"remote_damage", [CHARGE_DAMAGE, "被衝鋒的盾甲騎士撞飛了", "你被整扇鐵門撞飛了！"])
			var side := Vector3.UP.cross(_charge_dir) * (1.0 if _charge_dir.cross(to).y < 0.0 else -1.0)
			host_affect(player, {"push": _charge_dir * 10.0 + side * 4.0 + Vector3.UP * 3.0, "shake": 1.0})
	# Into a wall: it staggers with its guard down.
	var walled := false
	var bumped_player := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider() is Player:
			bumped_player = true
			continue
		var normal := collision.get_normal()
		if normal.dot(_charge_dir) < -0.5 and absf(normal.y) < 0.5:
			walled = true
	if moved < CHARGE_SPEED * delta * 0.25 and _timer < CHARGE_TIME - 0.3 and not bumped_player:
		_stuck += delta
		walled = walled or _stuck > 0.15
	else:
		_stuck = 0.0
	if walled:
		_stagger()
	elif _timer <= 0.0:
		state = State.RECOVER
		_timer = RECOVER_TIME


func _stagger() -> void:
	state = State.STAGGER
	_timer = STAGGER_TIME
	_stuck = 0.0
	halt()
	host_sound("boom", 6.0, 70.0, 0.6, global_position + Vector3.UP * 1.5 + _charge_dir * 1.2)
	GameNoise.emit_local(get_tree(), global_position, 30.0, GameNoise.Kind.IMPACT)
	for player in MonsterKit.active_players(get_tree()):
		if player.global_position.distance_to(global_position) < 14.0:
			MonsterKit.tell(player, &"remote_warn", ["轟！它一頭撞上牆，鐵門垂下來了。現在打牠！", 0.6])


@rpc("authority", "call_local", "unreliable")
func _spark() -> void:
	if _shield == null:
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.5)
	flash.light_energy = 2.5
	flash.omni_range = 3.0
	_shield.add_child(flash)
	flash.position = Vector3(randf_range(-0.5, 0.5), randf_range(0.6, 2.2), -0.25)
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)


@rpc("authority", "call_local", "unreliable")
func _play_windup() -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP, "rumble", 2.0, 40.0, 0.7)


func _animate(delta: float) -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var speed := moved.length() / maxf(delta, 0.001)
	_gait += delta * clampf(speed * 1.6, 0.0, 14.0)
	var swing := clampf(speed / 2.0, 0.0, 1.0) * 0.35
	_legs[0].rotation.x = sin(_gait) * swing
	_legs[1].rotation.x = -sin(_gait) * swing
	var guard_y := 0.0
	var guard_tilt := 0.0
	var lean := 0.0
	match state:
		State.WINDUP:
			lean = 0.3
			guard_y = -0.15
		State.CHARGE:
			lean = 0.4
		State.STAGGER:
			guard_y = -1.1
			guard_tilt = 0.9
			lean = -0.15
	if downed:
		lean = 0.6
		guard_y = -1.3
		guard_tilt = 1.3
	_torso.rotation.x = lerpf(_torso.rotation.x, -lean, delta * 5.0)
	_shield.position.y = lerpf(_shield.position.y, guard_y, delta * 6.0)
	_shield.rotation.x = lerpf(_shield.rotation.x, -guard_tilt, delta * 4.0)
	if speed > 0.3 and is_guarding():
		_scrape -= delta
		if _scrape <= 0.0:
			_scrape = 0.6 if state != State.CHARGE else 0.15
			Sfx.play_3d(get_parent(), global_position + forward() * 1.0, "creak", -6.0 if state != State.CHARGE else 2.0, 30.0, rng.randf_range(0.4, 0.55))


func _build_model() -> void:
	var plate := PS1Materials.get_material("rust_metal", Color(0.62, 0.58, 0.52))
	var dark := PS1Materials.get_material("rust_metal", Color(0.2, 0.18, 0.17))
	var flesh := PS1Materials.get_material("concrete", Color(0.68, 0.5, 0.45))
	var door := PS1Materials.get_material("panel", Color(0.3, 0.34, 0.34))
	var glass := PS1Materials.get_material("concrete", Color(0.2, 0.25, 0.25), false, Vector2.ONE, Color(0.25, 0.35, 0.3))
	var eye := PS1Materials.get_material("concrete", Color(0.1, 0.1, 0.1), false, Vector2.ONE, Color(1.0, 0.45, 0.15))
	# The body is built at human proportions and scaled up: it towers over its door.
	var body := Node3D.new()
	body.scale = Vector3.ONE * BODY_SCALE
	_model.add_child(body)
	# Short thick legs in riveted greaves.
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.45, 1.25, 0.1)
		body.add_child(hip)
		MonsterKit.part(hip, LowPoly.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.02 * side, -0.6, -0.12),
			Vector3(0, -1.15, 0.0)]), PackedFloat32Array([0.26, 0.22, 0.2]), 6), Vector3.ZERO, plate)
		MonsterKit.part(hip, LowPoly.chamfer_box(Vector3(0.42, 0.22, 0.62), 0.05), Vector3(0, -1.15, -0.1), dark)
		MonsterKit.part(hip, LowPoly.blob(0.17, Vector3.ONE, 0, 0.05, 2), Vector3(0.02 * side, -0.6, -0.16), dark)
		_legs.append(hip)
	# A hunched torso leaning into the door: plate on the front, raw back with spikes of rebar.
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.3, 0.1)
	body.add_child(_torso)
	var chest := PackedVector2Array([Vector2(0.0, -0.1), Vector2(0.48, 0.0), Vector2(0.62, 0.5),
		Vector2(0.72, 1.0), Vector2(0.6, 1.35), Vector2(0.25, 1.5), Vector2(0.0, 1.52)])
	MonsterKit.part(_torso, LowPoly.lathe(chest, 7), Vector3(0, 0, 0), flesh, Vector3(-18, 0, 0), Vector3(1.0, 1.0, 0.8))
	MonsterKit.part(_torso, LowPoly.chamfer_box(Vector3(1.25, 1.0, 0.25), 0.08), Vector3(0, 0.85, -0.5), plate, Vector3(-18, 0, 0))
	MonsterKit.part(_torso, LowPoly.chamfer_box(Vector3(0.8, 0.4, 0.2), 0.06), Vector3(0, 0.2, -0.4), plate, Vector3(-10, 0, 0))
	var rebar := []
	for i in 5:
		var x := (i - 2) * 0.22
		rebar.append([LowPoly.prism(4, 0.035, 0.0, 0.5), LowPoly.at(Vector3(x, 1.15 - absf(x) * 0.6, 0.5), Vector3(55, 0, x * 25))])
	MonsterKit.part(_torso, LowPoly.merge(rebar), Vector3.ZERO, dark)
	# Pauldrons and a small sunken helmet with one glowing slit.
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_torso, LowPoly.blob(0.36, Vector3(1.1, 0.75, 1.1), 0, 0.08, 4), Vector3(side * 0.78, 1.25, -0.15), plate)
	MonsterKit.part(_torso, LowPoly.chamfer_box(Vector3(0.42, 0.42, 0.45), 0.1), Vector3(0, 1.55, -0.42), plate)
	# A crest of bent rebar on the helmet and spikes on the pauldrons: the silhouette
	# that shows over the top of the door.
	var spikes := []
	for i in 4:
		spikes.append([LowPoly.prism(4, 0.05, 0.0, 0.5 - i * 0.07), LowPoly.at(Vector3(0, 1.9 - i * 0.05, -0.5 + i * 0.16), Vector3(-30 + i * 25, 45, 0))])
	for side: float in [-1.0, 1.0]:
		for i in 3:
			spikes.append([LowPoly.prism(4, 0.06, 0.0, 0.42), LowPoly.at(Vector3(side * (0.7 + i * 0.12), 1.55, -0.3 + i * 0.12), Vector3(-15, 0, -side * (20 + i * 15)))])
	MonsterKit.part(_torso, LowPoly.merge(spikes), Vector3.ZERO, dark)
	MonsterKit.part(_torso, LowPoly.chamfer_box(Vector3(0.3, 0.05, 0.05), 0.01), Vector3(0, 1.58, -0.66), eye)
	# Arms: the left braces the door from behind, the right grips its edge.
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_torso, LowPoly.tube(PackedVector3Array([Vector3(side * 0.85, 1.2, -0.15), Vector3(side * 0.95, 0.7, -0.5),
			Vector3(side * 0.62, 0.62, -1.05)]), PackedFloat32Array([0.2, 0.17, 0.15]), 6), Vector3.ZERO, flesh)
		MonsterKit.part(_torso, LowPoly.blob(0.17, Vector3(1.0, 0.8, 1.2), 0, 0.1, 5), Vector3(side * 0.62, 0.64, -1.08), dark)
	# The shield: a full steel security door, two metres tall, with a wired window,
	# a push bar and dents. It hangs from a pivot so it can drop when staggered.
	_shield = Node3D.new()
	_shield.position = Vector3.ZERO
	_model.add_child(_shield)
	var door_root := Node3D.new()
	door_root.position = Vector3(0, 0.15, -1.6)
	_shield.add_child(door_root)
	MonsterKit.part(door_root, LowPoly.chamfer_box(Vector3(1.55, 2.5, 0.12), 0.03), Vector3(0, 1.25, 0), door)
	MonsterKit.part(door_root, LowPoly.chamfer_box(Vector3(1.7, 0.1, 0.18), 0.02), Vector3(0, 2.5, 0), dark)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(door_root, LowPoly.chamfer_box(Vector3(0.1, 2.6, 0.18), 0.02), Vector3(side * 0.82, 1.25, 0), dark)
	MonsterKit.part(door_root, LowPoly.chamfer_box(Vector3(0.4, 0.5, 0.04), 0.01), Vector3(0.25, 1.85, -0.06), glass)
	var wire := []
	for i in 3:
		wire.append([LowPoly.prism(4, 0.008, 0.008, 0.5), LowPoly.at(Vector3(0.13 + i * 0.12, 1.85, -0.09))])
		wire.append([LowPoly.prism(4, 0.008, 0.008, 0.4), LowPoly.at(Vector3(0.25, 1.68 + i * 0.12, -0.09), Vector3(0, 0, 90))])
	MonsterKit.part(door_root, LowPoly.merge(wire), Vector3.ZERO, dark)
	MonsterKit.part(door_root, LowPoly.chamfer_box(Vector3(1.1, 0.08, 0.08), 0.02), Vector3(0, 1.1, -0.1), plate)
	MonsterKit.part(door_root, LowPoly.chamfer_box(Vector3(1.3, 0.2, 0.03), 0.01), Vector3(0, 0.35, -0.065),
		PS1Materials.get_material("concrete", Color(0.75, 0.6, 0.15)))
	var dents := []
	for p: Vector3 in [Vector3(-0.4, 1.6, -0.07), Vector3(0.3, 0.8, -0.07), Vector3(-0.2, 0.6, -0.07), Vector3(-0.5, 2.1, -0.07)]:
		dents.append([LowPoly.prism(6, 0.09, 0.06, 0.02), LowPoly.at(p, Vector3(90, 0, 0))])
	MonsterKit.part(door_root, LowPoly.merge(dents), Vector3.ZERO, dark)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 0.5
	glow.omni_range = 2.0
	glow.position = Vector3(0, 1.6, -0.75)
	_torso.add_child(glow)
