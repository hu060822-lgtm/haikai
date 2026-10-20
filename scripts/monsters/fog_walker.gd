class_name FogWalker
extends CharacterBody3D
## 霧行者: a man-shaped hole in the haze. Dominates by ABILITY: you can't see it, and it
## moves twice as fast as you walk.
## Weaknesses players can learn:
##   - Make it visible: hit it (crowbar, slingshot) or throw powder on it, and for a
##     while it shows up chalk-white and slows down.
##   - It hates the cold: it won't follow you out into the snow, or near anything icy.
## Tells: a dry cough, and now and then a flicker of a shape that isn't there.

const HEIGHT := 1.8
const RADIUS := 0.35
const SPEED := 6.4
const REVEALED_SPEED := 3.0
const NOTICE_RANGE := 25.0
const HIT_DISTANCE := 1.0
const HIT_DAMAGE := 40.0
const RETREAT_TIME := 10.0
const REVEAL_TIME := 10.0
const COLD_RANGE := 6.0
## Hit effects that make it show up (and so let it be hurt).
const REVEALING := ["reveal", "burn", "explode", "bubble", "melee", "bayonet"]

## Replicated: whether it is showing (powdered or struck).
var revealed := false:
	set(value):
		revealed = value
		if is_node_ready():
			_apply_visibility()
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _chalk: Material
var _shadow: Material
var _parts: Array[MeshInstance3D] = []
var _reveal := 0.0
var _retreat := 0.0
var _flicker := 1.5
var _flicker_on := 0.0
var _cough := 4.0
var _wander := 0.0
var _spotted := false
var _shrug := 0.0


func _ready() -> void:
	add_to_group("monsters")
	# On the loot layer too, so a crowbar swing or a marble can find it.
	collision_layer = Layers.MONSTER | Layers.LOOT
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
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:revealed"])
	_apply_visibility()


func get_prompt(_player: Player = null) -> String:
	return "（霧裡好像有什麼…）" if not revealed else ""


func interact(_player: Player) -> void:
	pass


func pry(_player: Player) -> void:
	weapon_hit()


func weapon_hit() -> void:
	if Run.instance != null:
		Run.instance.request_monster_action(self, "reveal")


## Host: struck, or powder thrown on it.
func host_action(action: String, _player: Player) -> void:
	if action == "reveal":
		reveal()


## Local only: cat-eye drops let this player see its outline.
func set_spotted(on: bool) -> void:
	if on == _spotted:
		return
	_spotted = on
	_model.visible = on or revealed


## Host: a weapon hit it. A bullet through the haze hits nothing: only once it shows
## (powder, rock salt, fire, a blast, a blade) can it be hurt.
func on_hit(hit: Dictionary) -> float:
	var effects: Dictionary = hit.get("effects", {})
	for effect in REVEALING:
		if effects.has(effect):
			reveal()
			break
	if revealed:
		return 1.0
	var attacker: Player = hit.get("attacker") as Player
	if attacker != null and _shrug <= 0.0:
		_shrug = 6.0
		MonsterKit.tell(attacker, &"remote_warn", ["子彈穿過了霧，什麼都沒打到。（粗鹽彈、火、刀子能逼它現形）", 0.0])
	return 0.0


func reveal() -> void:
	_reveal = REVEAL_TIME
	revealed = true
	_retreat = maxf(_retreat, 3.0)
	_play.rpc("cough", 0.7)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_tells(delta)


func _think(delta: float) -> void:
	_reveal = maxf(_reveal - delta, 0.0)
	_retreat = maxf(_retreat - delta, 0.0)
	_shrug = maxf(_shrug - delta, 0.0)
	revealed = _reveal > 0.0
	var speed := REVEALED_SPEED if revealed else SPEED
	var target: Player = null
	if _retreat <= 0.0:
		target = _find_target()
	if target != null:
		_agent.target_position = target.global_position
	else:
		_wander -= delta
		if (_agent.is_navigation_finished() or _wander <= 0.0) and not patrol_points.is_empty():
			_agent.target_position = patrol_points[rng.randi_range(0, patrol_points.size() - 1)]
			_wander = 12.0
		if _retreat <= 0.0:
			speed = 2.0
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if target != null and global_position.distance_to(target.global_position) < 3.0:
		next = target.global_position
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
	if target != null:
		var offset := target.global_position - global_position
		if Vector2(offset.x, offset.z).length() < HIT_DISTANCE + Player.RADIUS and absf(offset.y) < 1.2:
			MonsterKit.tell(target, &"remote_damage", [HIT_DAMAGE, "被霧裡看不見的東西殺死了", "霧裡有東西打了你！打它或灑粉讓它現形"])
			_play.rpc("bite", 0.7)
			_retreat = RETREAT_TIME
			var far := global_position
			for point in patrol_points:
				if point.distance_to(target.global_position) > far.distance_to(target.global_position):
					far = point
			_agent.target_position = far


func _find_target() -> Player:
	var best: Player = null
	var best_distance := NOTICE_RANGE
	var station: Node = Run.instance.level if Run.instance != null else null
	for player in MonsterKit.active_players(get_tree()):
		var distance := player.global_position.distance_to(global_position)
		if distance >= best_distance or is_cold(player, station) or player.has_effect("diving"):
			continue
		best = player
		best_distance = distance
	return best


## Out in the snow, or carrying something icy: it keeps away.
## Any map may have an outdoors (is_outdoors); out there is cold.
func is_cold(player: Player, station: Node = null) -> bool:
	if station != null and station.has_method("is_outdoors") and station.is_outdoors(player.global_position):
		return true
	if player.carries_tag("cold"):
		return player.global_position.distance_to(global_position) < COLD_RANGE * 3.0
	return false


@rpc("authority", "call_local", "reliable")
func _play(sound: String, pitch: float) -> void:
	Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.5, sound, -2.0, 20.0, pitch)


func _tells(delta: float) -> void:
	_cough -= delta
	if _cough <= 0.0:
		_cough = rng.randf_range(4.0, 8.0)
		Sfx.play_3d(get_parent(), global_position + Vector3.UP * 1.6, "cough", -6.0, 18.0, rng.randf_range(0.8, 1.0))
	if revealed or _spotted:
		return
	# Now and then the haze shows its outline for a blink.
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = rng.randf_range(1.2, 2.4)
		_flicker_on = 0.08
		_model.visible = true
	if _flicker_on > 0.0:
		_flicker_on -= delta
		if _flicker_on <= 0.0:
			_model.visible = false


func _apply_visibility() -> void:
	_model.visible = revealed
	for part in _parts:
		part.material_override = _chalk if revealed else _shadow


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	_chalk = PS1Materials.get_material("concrete", Color(0.95, 0.95, 0.92), false, Vector2.ONE, Color(0.3, 0.3, 0.3))
	_shadow = PS1Materials.get_material("concrete", Color(0.12, 0.12, 0.14))
	# Too tall and too thin: a narrow pelvis, a pinched waist, a cage of a chest.
	var torso := PackedVector2Array([Vector2(0.0, 0.86), Vector2(0.13, 0.88), Vector2(0.15, 0.95),
		Vector2(0.105, 1.08), Vector2(0.15, 1.28), Vector2(0.195, 1.46), Vector2(0.17, 1.57),
		Vector2(0.08, 1.63), Vector2(0.0, 1.64)])
	_shape(_model, LowPoly.lathe(torso, 7), Vector3.ZERO, Vector3(0, 0, 0), Vector3(1, 1, 0.55))
	# Ribs standing out of the chest.
	for i in 3:
		var y := 1.3 + i * 0.075
		var r := 0.152 + i * 0.016
		var rib := PackedVector3Array()
		for a: float in [-80.0, -40.0, 0.0, 40.0, 80.0]:
			var t := deg_to_rad(a)
			rib.append(Vector3(sin(t) * r, y - absf(a) * 0.0006, -cos(t) * r * 0.58))
		_shape(_model, LowPoly.tube(rib, PackedFloat32Array([0.006, 0.011, 0.012, 0.011, 0.006]), 4), Vector3.ZERO)
	# Bony shoulders hunched up round a long neck, the head hanging forward.
	for side: float in [-1.0, 1.0]:
		_shape(_model, LowPoly.blob(0.07, Vector3(1.2, 0.8, 0.9), 0, 0.1, 4), Vector3(0.22 * side, 1.56, 0.0))
	_shape(_model, LowPoly.tube(PackedVector3Array([Vector3(0, 1.6, 0.02), Vector3(0, 1.68, 0.0),
		Vector3(0, 1.74, -0.05)]), PackedFloat32Array([0.05, 0.04, 0.038]), 6), Vector3.ZERO)
	# A long smooth skull without a face, and the jaw hanging open beneath it.
	var skull := PackedVector2Array([Vector2(0.0, -0.13), Vector2(0.055, -0.12), Vector2(0.095, -0.04),
		Vector2(0.11, 0.06), Vector2(0.095, 0.15), Vector2(0.045, 0.2), Vector2(0.0, 0.21)])
	_shape(_model, LowPoly.lathe(skull, 7), Vector3(0, 1.8, -0.07), Vector3(-14, 0, 0), Vector3(0.95, 1, 1.05))
	_shape(_model, LowPoly.blob(0.06, Vector3(1.0, 1.5, 0.9), 0, 0.12, 9), Vector3(0, 1.66, -0.13), Vector3(-25, 0, 0))
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.12 * side, 0.9, 0)
		_model.add_child(leg)
		_shape(leg, LowPoly.tube(PackedVector3Array([Vector3(0, 0.02, 0), Vector3(0, -0.2, -0.01),
			Vector3(0, -0.44, 0.0)]), PackedFloat32Array([0.065, 0.055, 0.042]), 6), Vector3.ZERO)
		_shape(leg, LowPoly.blob(0.048, Vector3(1.0, 1.1, 1.0), 0), Vector3(0, -0.45, -0.01))
		_shape(leg, LowPoly.tube(PackedVector3Array([Vector3(0, -0.45, 0), Vector3(0, -0.66, 0.015),
			Vector3(0, -0.86, 0.02)]), PackedFloat32Array([0.042, 0.035, 0.026]), 6), Vector3.ZERO)
		_shape(leg, LowPoly.tube(PackedVector3Array([Vector3(0, -0.85, 0.04), Vector3(0, -0.885, -0.06),
			Vector3(0, -0.895, -0.17)]), PackedFloat32Array([0.04, 0.032, 0.0]), 5), Vector3.ZERO)
		var arm := Node3D.new()
		arm.position = Vector3(0.3 * side, 1.55, 0)
		arm.rotation.z = 0.12 * side
		_model.add_child(arm)
		_shape(arm, LowPoly.tube(PackedVector3Array([Vector3(0, 0.02, 0), Vector3(0, -0.2, 0.02),
			Vector3(0, -0.4, 0.02)]), PackedFloat32Array([0.045, 0.04, 0.033]), 6), Vector3.ZERO)
		_shape(arm, LowPoly.blob(0.036, Vector3.ONE, 0), Vector3(0, -0.4, 0.025))
		_shape(arm, LowPoly.tube(PackedVector3Array([Vector3(0, -0.4, 0.02), Vector3(0, -0.6, -0.01),
			Vector3(0, -0.8, -0.04)]), PackedFloat32Array([0.033, 0.028, 0.022]), 6), Vector3.ZERO)
		# Hands with fingers far too long, hanging open.
		_shape(arm, LowPoly.blob(0.04, Vector3(0.55, 1.0, 0.9), 0), Vector3(0, -0.84, -0.04))
		for f in 4:
			var fz := -0.07 + f * 0.022
			var fx := (0.012 if f == 0 else -0.004) * side
			_shape(arm, LowPoly.tube(PackedVector3Array([Vector3(fx, -0.86, fz), Vector3(fx * 1.5, -0.97, fz - 0.012 * (1.5 - f)),
				Vector3(fx * 2.0 - 0.01 * side, -1.06, fz - 0.02 * (1.5 - f) + 0.02)]), PackedFloat32Array([0.011, 0.008, 0.0]), 3), Vector3.ZERO)


## One part of the body: every part swaps between shadow and chalk together.
func _shape(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var part := MonsterKit.part(parent, mesh, pos, _shadow, rot_deg, scale)
	_parts.append(part)
	return part
