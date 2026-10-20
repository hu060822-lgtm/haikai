class_name Tripwire
extends Trap
## A thin wire across a doorway or corridor at ankle height, tied to a string of tin
## cans and a little bell. Walk through it and the cans rattle loud enough to draw
## every monster nearby. Jump over it, or crouch and press E to cut it quietly.
## Placed at the doorway centre with yaw along the wall: the wire runs along local x
## (yaw 0 = a wall running along world x, 90 = along world z). params.width (1.6).
## Tell: a glint of wire between two nails, and the cans hung on one side.

enum { ARMED, TRIPPED, CUT }

const HEIGHT := 0.16
const NOISE := 40.0
const RESET := 60.0

var width := 1.6
var _wire: MeshInstance3D
var _cans: Node3D
var _reset := 0.0
var _rattle := 0.0


func build() -> void:
	width = params.get("width", 1.6)
	var half := width / 2.0
	var nail := LowPoly.prism(4, 0.015, 0.012, HEIGHT + 0.06)
	part([[nail, LowPoly.at(Vector3(-half, (HEIGHT + 0.06) / 2.0, 0))], [nail, LowPoly.at(Vector3(half, (HEIGHT + 0.06) / 2.0, 0))]],
		"rust_metal", Color(0.5, 0.45, 0.4), Color.BLACK, null, "wire_nails%s" % width)
	_wire = part([[LowPoly.prism(3, 0.004, 0.004, width, false), LowPoly.at(Vector3(0, HEIGHT, 0), Vector3(0, 0, 90))]],
		"brass", Color(0.85, 0.85, 0.8), Color(0.08, 0.08, 0.07), null, "wire%s" % width)
	# The rattle: three tin cans and a bell on a short cord, by the left nail.
	_cans = Node3D.new()
	_cans.position = Vector3(-half + 0.14, 0.0, 0.12)
	add_child(_cans)
	var can := LowPoly.prism(6, 0.04, 0.04, 0.1)
	part([[can, LowPoly.at(Vector3(0, 0.05, 0))], [can, LowPoly.at(Vector3(0.07, 0.05, 0.05), Vector3(0, 0, 90))],
		[can, LowPoly.at(Vector3(0.0, 0.15, 0.0), Vector3(12, 0, 0))],
		[LowPoly.prism(5, 0.04, 0.0, 0.06, false), LowPoly.at(Vector3(-0.07, 0.04, -0.03))]],
		"rust_metal", Color(0.75, 0.72, 0.65), Color.BLACK, _cans, "wire_cans")
	add_handle(Vector3(width, 0.1, 0.12), Vector3(0, HEIGHT, 0))


func host_tick(delta: float) -> void:
	if state == ARMED:
		for player in players():
			if feet_in(player, Vector2(width / 2.0, 0.22), 0.12):
				host_set_state(TRIPPED)
				_reset = RESET
				host_noise(NOISE, GameNoise.Kind.MACHINE)
				host_affect(player, {"note": "你絆到一條線，罐子叮叮噹噹響成一片！", "shake": 0.3})
				return
	else:
		_reset -= delta
		if _reset <= 0.0:
			for player in players():
				if feet_within(player, width, 1.0):
					_reset = 3.0
					return
			host_set_state(ARMED)


func local_tick(delta: float) -> void:
	if _rattle > 0.0:
		_rattle -= delta
		_cans.rotation.z = sin(_rattle * 40.0) * 0.4 * _rattle


func apply_state(new_state: int, _arg: int) -> void:
	_wire.visible = new_state == ARMED
	match new_state:
		TRIPPED:
			_rattle = 1.5
			sound("chime", 4.0, 50.0, 1.6, _cans.position)
			sound("clank", 4.0, 50.0, 1.8, _cans.position)
			sound("tink", 2.0, 40.0, 0.9, _cans.position)
		CUT:
			sound("tink", -14.0, 8.0, 2.0)


func get_prompt(player: Player = null) -> String:
	if state != ARMED:
		return ""
	return "[E] 剪斷絆線" if player != null and player.is_crouching else "絆線（蹲下才能剪）"


func interact(player: Player) -> void:
	if state != ARMED:
		return
	if player.is_crouching:
		request("cut")
	else:
		player.message.emit("蹲下來才剪得到，不然會扯動罐子。")


func host_request(action: String, player: Player) -> void:
	if action == "cut" and state == ARMED and player.is_crouching:
		host_set_state(CUT)
		_reset = RESET * 2.0
