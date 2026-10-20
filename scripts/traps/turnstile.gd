class_name Turnstile
extends Trap
## A pair of old ticket turnstiles fitted across a doorway, still on the station's power.
## Push through the bars standing up and they clack round and the fare alarm shrieks
## for the whole level to hear. Duck under the bars (crouch) and they never notice.
## Placed at the doorway centre with yaw along the wall: the two cabinets stand on local
## x just inside the jambs (params.width, the opening). Each cabinet is solid.
## Tell: a little green 「請刷卡」 lamp on each cabinet; the arms are at hip height.

enum { IDLE, ALARM }

const NOISE := 40.0
const ALARM_TIME := 3.5

var width := 3.4
var _arms: Array[Node3D] = []
var _lamps: Array[MeshInstance3D] = []
var _inside := {}
var _timer := 0.0
var _blink := 0.0


func build() -> void:
	width = maxf(params.get("width", 3.4) - 0.3, 1.2)
	for side: float in [-1.0, 1.0]:
		var x := side * (width / 2.0 - 0.15)
		part([slab(Vector3(0.3, 1.0, 1.1), Vector3(x, 0.5, 0))], "panel", Color(0.62, 0.64, 0.6), Color.BLACK, null, "stile_body%s" % x)
		part([slab(Vector3(0.34, 0.06, 1.14), Vector3(x, 1.03, 0))], "brass", Color(0.8, 0.8, 0.75), Color.BLACK, null, "stile_top%s" % x)
		_lamps.append(part([slab(Vector3(0.12, 0.05, 0.12), Vector3(x, 1.08, 0.35))], "concrete", Color(0.2, 0.6, 0.25), Color(0.05, 0.35, 0.1)))
		# A tripod of bars on the inner face, reaching across the gap.
		var hub := Node3D.new()
		hub.position = Vector3(x - side * 0.15, 0.85, 0)
		add_child(hub)
		var reach := minf(width / 2.0 - 0.3, 0.75)
		var axis := Vector3(-side, -1.0, 0).normalized()
		hub.set_meta("axis", axis)
		var first := axis.cross(Vector3.BACK).normalized()
		var bars := []
		for i in 3:
			var arm := first.rotated(axis, TAU * i / 3.0)
			bars.append([LowPoly.prism(4, 0.025, 0.025, reach), Transform3D(Basis(Quaternion(Vector3.UP, arm)), arm * reach / 2.0)])
		part(bars, "brass", Color(0.85, 0.85, 0.8), Color.BLACK, hub)
		_arms.append(hub)
		var block := StaticBody3D.new()
		block.collision_layer = Layers.WORLD
		block.collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.3, 1.05, 1.1)
		collider.shape = shape
		block.add_child(collider)
		block.position = Vector3(x, 0.525, 0)
		add_child(block)


func host_tick(delta: float) -> void:
	if state == ALARM:
		_timer -= delta
		if _timer <= 0.0:
			host_set_state(IDLE)
	for player in players():
		var key := String(player.name)
		var between := feet_in(player, Vector2(width / 2.0 - 0.3, 0.35), 1.0)
		if between and not _inside.get(key, false) and not player.is_crouching:
			host_noise(NOISE, GameNoise.Kind.MACHINE)
			_timer = ALARM_TIME
			host_set_state(ALARM, 1)
			host_affect(player, {"note": "閘門「喀啦」轉了一圈，票務警報大響！（蹲下可以從橫桿底下鑽過去）", "shake": 0.25})
		_inside[key] = between


func local_tick(delta: float) -> void:
	if state != ALARM:
		return
	_blink -= delta
	if _blink <= 0.0:
		_blink = 0.45
		sound("whistle", 0.0, 50.0, 2.8, Vector3(0, 1.1, 0))
	var on := fmod(_blink, 0.22) > 0.11
	for lamp in _lamps:
		lamp.material_override = PS1Materials.get_material("concrete", Color(1, 0.2, 0.2), true, Vector2.ONE,
			Color(1.0, 0.1, 0.05) if on else Color(0.2, 0.0, 0.0))


func apply_state(new_state: int, arg: int) -> void:
	_blink = 0.0
	if new_state == ALARM and arg == 1:
		sound("clank", 0.0, 25.0, 1.5, Vector3(0, 0.85, 0))
		for arm in _arms:
			var axis: Vector3 = arm.get_meta("axis")
			var from := arm.basis
			var tween := create_tween()
			tween.tween_method(func(t: float) -> void: arm.basis = Basis(axis, t * TAU / 3.0) * from, 0.0, 1.0, 0.25)
	if new_state == IDLE:
		for lamp in _lamps:
			lamp.material_override = PS1Materials.get_material("concrete", Color(0.2, 0.6, 0.25), true, Vector2.ONE, Color(0.05, 0.35, 0.1))
