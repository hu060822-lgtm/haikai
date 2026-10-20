class_name ShadowStalker
extends Prowler
## 影子跟蹤者: a long, stooped figure made of the dark itself, with too many finger joints.
## Dominates by ABILITY and INTELLIGENCE: in the dark it is invisible and bullets pass
## through it like smoke; it follows you patiently and strikes only when you look away.
## Weaknesses players can learn:
##   - Light. In a lantern beam or under a lamp it freezes where it stands, turns solid
##     and visible, and that is when it can be hurt.
##   - It only strikes from behind; walk backwards with your light on it.
## Tell: a faint shimmer in the dark and a whisper of static when it is close.

const RADIUS := 0.35
const HEIGHT := 2.2
const SPEED := 3.4
const HUNT_RANGE := 32.0
const BEHIND := 2.2
const STRIKE_RANGE := 1.5
const STRIKE_DAMAGE := 32.0
const STRIKE_COOLDOWN := 5.0
const RETREAT_TIME := 4.0
const LANTERN_RANGE := 12.0
const LANTERN_COS := 0.94   # about half the player's 35 degree spotlight, with a margin
const LAMP_REACH := 0.7     # fraction of a lamp's range that counts as lit
const DARK_DAMAGE := 0.1
const LIT_DAMAGE := 1.5

## Replicated: in the light (solid, frozen, vulnerable) or in the dark (a shimmer).
var lit := false:
	set(value):
		if lit != value:
			lit = value
			if is_node_ready():
				_apply_look()

var _target: Player = null
var _cooldown := 0.0
var _retreat := 0.0
var _retreat_goal := Vector3.ZERO
var _light_check := 0.0
var _lit_time := 0.0
var _goal := Vector3.ZERO
var _parts: Array[MeshInstance3D] = []
var _solid: Material
var _shade: StandardMaterial3D
var _eyes: MeshInstance3D
var _arms: Array[Node3D] = []
var _whisper := 0.0
var _last_pos := Vector3.ZERO
var _gait := 0.0


func _ready() -> void:
	setup_body(RADIUS, HEIGHT)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:lit"])
	_apply_look()
	_goal = global_position
	_last_pos = global_position


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if multiplayer.is_server():
		_think(delta)
		move_and_slide()
	_animate(delta)


## Host: is any lantern beam or lamp on it right now?
func in_light() -> bool:
	var chest := global_position + Vector3.UP * 1.3
	var exclude: Array[RID] = [get_rid()]
	for player in MonsterKit.active_players(get_tree()):
		if not player.lantern_on:
			continue
		var head := player.head_position()
		var to := chest - head
		if to.length() < LANTERN_RANGE and player.look_direction().dot(to.normalized()) > LANTERN_COS \
				and MonsterKit.clear_line(get_world_3d(), head, chest, exclude):
			return true
	var level = Run.instance.level if Run.instance != null else null
	if level != null and level.get("power_on") != false:
		for light: OmniLight3D in level.get("_all_lights"):
			if not is_instance_valid(light) or not light.is_visible_in_tree() or light.light_energy < 0.3:
				continue
			var d := light.global_position.distance_to(chest)
			if d < light.omni_range * LAMP_REACH and MonsterKit.clear_line(get_world_3d(), light.global_position, chest, exclude):
				return true
	return false


func on_hit(_hit: Dictionary) -> float:
	if not lit:
		host_sound("static", -8.0, 15.0, 1.6)
		return DARK_DAMAGE
	host_sound("screech", 0.0, 30.0, 0.7)
	# Hurt in the light, it flees for the dark.
	_start_retreat()
	return LIT_DAMAGE


func host_kill() -> void:
	host_sound("death", 0.0, 30.0, 0.5)
	queue_free()


func _think(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_light_check -= delta
	if _light_check <= 0.0:
		_light_check = 0.1
		lit = in_light()
	if lit:
		# Caught: it freezes like a deer and waits for the light to leave it.
		_lit_time += delta
		halt()
		return
	_lit_time = 0.0
	if _retreat > 0.0:
		_retreat -= delta
		steer(_retreat_goal, SPEED * 1.3, delta)
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_active() \
			or global_position.distance_to(_target.global_position) > HUNT_RANGE:
		_target = MonsterKit.nearest_player(self, HUNT_RANGE)
	if _target == null:
		if global_position.distance_to(_goal) < 1.5:
			_goal = random_patrol_point()
		steer(_goal, SPEED * 0.5, delta)
		return
	var facing := _target.look_direction()
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var to := _target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var behind := distance > 0.01 and facing.dot(to.normalized()) > 0.35  # they face away from it
	if behind and distance < STRIKE_RANGE and _cooldown <= 0.0:
		_strike(_target)
		return
	if behind and distance < BEHIND + 1.0:
		steer(_target.global_position, SPEED * 1.2, delta, 10.0, 4.0)
	else:
		steer(_target.global_position - facing * BEHIND, SPEED, delta, 8.0)
	_whisper -= delta
	if distance < 6.0 and _whisper <= 0.0:
		_whisper = rng.randf_range(2.0, 4.0)
		host_sound("static", -14.0, 8.0, rng.randf_range(0.5, 0.7))


func _strike(player: Player) -> void:
	halt()
	_cooldown = STRIKE_COOLDOWN
	face_point(player.global_position, 60.0, 1.0)
	host_sound("bite", 0.0, 20.0, 0.4)
	_play_strike.rpc()
	MonsterKit.tell(player, &"remote_damage", [STRIKE_DAMAGE, "被黑暗裡的影子跟蹤者撕開了", "黑暗裡有東西從背後抓了你！用燈照它！"])
	_start_retreat()


func _start_retreat() -> void:
	_retreat = RETREAT_TIME
	var away := -forward() * 8.0
	_retreat_goal = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), global_position + away) \
		if _nav_ready() else global_position + away


@rpc("authority", "call_local", "unreliable")
func _play_strike() -> void:
	for arm in _arms:
		var tween := create_tween()
		tween.tween_property(arm, "rotation:x", 1.6, 0.08)
		tween.tween_property(arm, "rotation:x", 0.2, 0.4)


func _apply_look() -> void:
	for part in _parts:
		part.material_override = _solid if lit else _shade
	_eyes.visible = true


func _animate(delta: float) -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var speed := moved.length() / maxf(delta, 0.001)
	_gait += delta * speed * 2.2
	if not lit:
		# The shimmer: the outline wavers like heat over a road.
		var t := Time.get_ticks_msec() * 0.001
		_shade.albedo_color.a = 0.16 + 0.06 * sin(t * 7.0) + 0.04 * sin(t * 23.0)
		_model.scale = Vector3(1.0 + 0.04 * sin(t * 13.0), 1.0, 1.0 + 0.04 * cos(t * 11.0))
		for i in _arms.size():
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, 0.25 + sin(_gait + i * PI) * 0.3, delta * 6.0)
	else:
		_model.scale = Vector3.ONE


func _build_model() -> void:
	_solid = PS1Materials.get_material("concrete", Color(0.36, 0.35, 0.38))
	_shade = StandardMaterial3D.new()
	_shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shade.albedo_color = Color(0.1, 0.1, 0.14, 0.16)
	_shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	var parts: Array = []
	# A stooped spine, a narrow chest bowed forward, legs bent like a crouching runner.
	var torso := PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.15, 0.0), Vector2(0.12, 0.3),
		Vector2(0.2, 0.6), Vector2(0.24, 0.8), Vector2(0.14, 0.92), Vector2(0.0, 0.95)])
	parts.append(MonsterKit.part(_model, LowPoly.lathe(torso, 6), Vector3(0, 1.05, 0.05), _solid, Vector3(-28, 0, 0), Vector3(1.0, 1.0, 0.6)))
	# A head hung low in front of the shoulders: smooth, faceless apart from two pinholes.
	parts.append(MonsterKit.part(_model, LowPoly.blob(0.15, Vector3(0.85, 1.25, 0.95), 1, 0.05, 3), Vector3(0, 1.9, -0.42), _solid))
	parts.append(MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(0, 1.78, -0.25), Vector3(0, 1.85, -0.35)]),
		PackedFloat32Array([0.06, 0.05]), 4), Vector3.ZERO, _solid))
	for side: float in [-1.0, 1.0]:
		# Legs: long thigh forward, shin back, on the balls of its feet.
		parts.append(MonsterKit.part(_model, LowPoly.tube(PackedVector3Array([Vector3(side * 0.12, 1.05, 0.05),
			Vector3(side * 0.16, 0.62, -0.25), Vector3(side * 0.14, 0.15, 0.1), Vector3(side * 0.13, 0.0, -0.08)]),
			PackedFloat32Array([0.09, 0.06, 0.04, 0.03]), 5), Vector3.ZERO, _solid))
		# Arms longer than its body, hanging from the shoulders to past the knees,
		# ending in five long jointed fingers.
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.26, 1.78, -0.25)
		arm.rotation.x = 0.25
		_model.add_child(arm)
		var elbow := Vector3(side * 0.12, -0.6, 0.05)
		var wrist := Vector3(side * 0.08, -1.15, -0.12)
		parts.append(MonsterKit.part(arm, LowPoly.tube(PackedVector3Array([Vector3.ZERO, elbow, wrist]),
			PackedFloat32Array([0.06, 0.04, 0.03]), 4), Vector3.ZERO, _solid))
		var fingers := []
		for f in 5:
			var a := (f - 2.0) * 0.28
			var k1 := wrist + Vector3(sin(a) * 0.06, -0.14, -cos(a) * 0.05)
			var k2 := wrist + Vector3(sin(a) * 0.1, -0.32, -cos(a) * 0.1 + 0.04)
			var tip := wrist + Vector3(sin(a) * 0.1, -0.5, -cos(a) * 0.04 + 0.1)
			fingers.append([LowPoly.tube(PackedVector3Array([wrist, k1, k2, tip]), PackedFloat32Array([0.018, 0.014, 0.012, 0.0]), 3), Transform3D.IDENTITY])
		parts.append(MonsterKit.part(arm, LowPoly.merge(fingers), Vector3.ZERO, _solid))
		_arms.append(arm)
	_parts.assign(parts)
	# Two pinprick eyes that always show, faintly, even in the dark.
	var eye := StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = Color(0.85, 0.9, 1.0)
	var pair := []
	for side: float in [-1.0, 1.0]:
		pair.append([LowPoly.blob(0.018, Vector3.ONE, 0), LowPoly.at(Vector3(side * 0.05, 1.93, -0.55))])
	_eyes = MonsterKit.part(_model, LowPoly.merge(pair), Vector3.ZERO, eye)
