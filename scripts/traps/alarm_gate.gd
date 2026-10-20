class_name AlarmGate
extends Trap
## A pair of shop security pedestals at a store's entrance. Still powered: walk between
## them carrying anything and they scream for the whole floor to hear. Empty-handed is
## fine. Placed at the doorway centre with yaw along the wall: the pedestals stand on
## local x at +-width/2 (params.width, 1.6). Each pedestal is solid (~0.1 x 0.5 m).
## Tell: a faint red standby light on top of each pedestal.

enum { STANDBY, ALARM }

const NOISE := 45.0
const ALARM_TIME := 4.0

var width := 1.6
var _lamps: Array[MeshInstance3D] = []
var _timer := 0.0
var _blink := 0.0
var _inside := {}


func build() -> void:
	# The pedestals stand just inside the opening's jambs.
	width = maxf(params.get("width", 1.6) - 0.3, 0.9)
	var body := LowPoly.chamfer_box(Vector3(0.08, 1.4, 0.45), 0.025)
	var foot := LowPoly.prism(4, 0.2, 0.17, 0.05)
	var lamp := LowPoly.prism(4, 0.025, 0.025, 0.03)
	for side in [-1.0, 1.0]:
		var x: float = side * width / 2.0
		part([[body, LowPoly.at(Vector3(x, 0.75, 0))], [foot, LowPoly.at(Vector3(x, 0.025, 0), Vector3(0, 45, 0), Vector3(0.7, 1, 1.6))]],
			"panel", Color(0.82, 0.84, 0.86), Color.BLACK, null, "alarm_body%s" % x)
		var led := part([[lamp, LowPoly.at(Vector3(x, 1.465, 0))]], "concrete", Color(0.4, 0.05, 0.05), Color(0.25, 0.0, 0.0))
		_lamps.append(led)
		var block := StaticBody3D.new()
		block.collision_layer = Layers.WORLD
		block.collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.1, 1.45, 0.45)
		collider.shape = shape
		block.add_child(collider)
		block.position = Vector3(x, 0.725, 0)
		add_child(block)


func host_tick(delta: float) -> void:
	if state == ALARM:
		_timer -= delta
		if _timer <= 0.0:
			host_set_state(STANDBY)
	for player in players():
		var key := String(player.name)
		var between := feet_in(player, Vector2(width / 2.0 - 0.05, 0.3), 1.0)
		if between and not _inside.get(key, false) and player.carried_ids.size() > 0:
			host_noise(NOISE, GameNoise.Kind.MACHINE)
			_timer = ALARM_TIME
			if state != ALARM:
				host_set_state(ALARM)
			host_affect(player, {"note": "防盜門大聲尖叫！整層樓都聽到了！", "shake": 0.3})
		_inside[key] = between


func local_tick(delta: float) -> void:
	if state != ALARM:
		return
	_blink -= delta
	if _blink <= 0.0:
		_blink = 0.5
		sound("whistle", 2.0, 55.0, 2.2, Vector3(0, 1.4, 0))
	var on := fmod(_blink, 0.25) > 0.12
	for lamp in _lamps:
		lamp.material_override = PS1Materials.get_material("concrete", Color(1, 0.2, 0.2), true, Vector2.ONE,
			Color(1.0, 0.1, 0.05) if on else Color(0.25, 0, 0))


func apply_state(new_state: int, _arg: int) -> void:
	_blink = 0.0
	if new_state == STANDBY:
		for lamp in _lamps:
			lamp.material_override = PS1Materials.get_material("concrete", Color(0.4, 0.05, 0.05), true, Vector2.ONE, Color(0.25, 0.0, 0.0))
