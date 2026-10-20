class_name BearTrap
extends Trap
## A rusty bear trap left on the floor. Step on the pan and the jaws slam shut: a bite,
## a loud clang and you're held for a couple of seconds (mash E to work free). Crouch
## and press E on it to spring it safely. The host re-arms it after a while.
## Tell: two flat iron jaws and a dull brass pan that catch the lantern light.

enum { ARMED, SPRUNG, SAFE }

const RADIUS := 0.3
const DAMAGE := 12.0
const SNARE := 2.5
const NOISE := 22.0
const REARM := 45.0

var _jaws: Array[Node3D] = []
var _rearm := 0.0


func build() -> void:
	var iron := Color(0.58, 0.52, 0.46)
	part([[LowPoly.prism(8, 0.24, 0.24, 0.02), LowPoly.at(Vector3(0, 0.01, 0), Vector3(0, 22.5, 0))],
		[LowPoly.tube(PackedVector3Array([Vector3(0.24, 0.01, 0), Vector3(0.38, 0.01, 0.06), Vector3(0.52, 0.01, 0.02)]),
			PackedFloat32Array([0.012, 0.012, 0.012]), 3), Transform3D.IDENTITY]],
		"rust_metal", iron.darkened(0.25), Color.BLACK, null, "bear_base")
	part([[LowPoly.prism(6, 0.07, 0.06, 0.015), LowPoly.at(Vector3(0, 0.03, 0))]], "brass", Color(0.7, 0.6, 0.4), Color.BLACK, null, "bear_pan")
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.025, 0)
		add_child(pivot)
		var arc := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 5:
			var a := PI * i / 4.0
			arc.append(Vector3(cos(a) * 0.22, 0, sin(a) * 0.22 * side))
			radii.append(0.014)
		var parts := [[LowPoly.tube(arc, radii, 4), Transform3D.IDENTITY]]
		for i in 6:
			var a := PI * (i + 0.5) / 6.0
			parts.append([LowPoly.prism(3, 0.016, 0.0, 0.06, false), LowPoly.at(Vector3(cos(a) * 0.21, 0.03, sin(a) * 0.21 * side))])
		part(parts, "rust_metal", iron, Color.BLACK, pivot, "bear_jaw%d" % int(side))
		_jaws.append(pivot)
	add_handle(Vector3(0.5, 0.12, 0.5), Vector3(0, 0.06, 0))
	_pose(false, false)


func host_tick(delta: float) -> void:
	match state:
		ARMED:
			for player in players():
				if feet_within(player, RADIUS, 0.35):
					host_set_state(SPRUNG)
					_rearm = REARM
					host_noise(NOISE)
					host_affect(player, {"damage": DAMAGE, "cause": "被捕獸夾夾住，再也沒能掙脫", "snare": SNARE,
						"note": "踩到捕獸夾了！狂按 E 掙脫", "shake": 0.7})
					return
		_:
			_rearm -= delta
			if _rearm <= 0.0:
				for player in players():
					if feet_within(player, 1.2, 1.0):
						_rearm = 3.0
						return
				host_set_state(ARMED)


func apply_state(new_state: int, _arg: int) -> void:
	match new_state:
		ARMED:
			_pose(false, true)
			sound("tick", -12.0, 12.0, 0.6)
		SPRUNG:
			_pose(true, true)
			sound("clank", 6.0, 45.0, 0.7)
			sound("bite", 0.0, 25.0, 0.6)
			burst(global_position + Vector3.UP * 0.1, Color(0.5, 0.45, 0.4), 8, 2.0)
		SAFE:
			_pose(true, true)
			sound("clank", -4.0, 20.0, 1.1)


func _pose(closed: bool, animate: bool) -> void:
	for i in _jaws.size():
		var target := deg_to_rad(-88.0 if i == 0 else 88.0) if closed else 0.0
		if animate:
			create_tween().tween_property(_jaws[i], "rotation:x", target, 0.06 if closed else 0.8)
		else:
			_jaws[i].rotation.x = target


func get_prompt(player: Player = null) -> String:
	if state != ARMED:
		return ""
	if player != null and player.is_crouching:
		return "[E] 小心拆掉捕獸夾"
	return "捕獸夾（蹲下才能拆）"


func interact(player: Player) -> void:
	if state != ARMED:
		return
	if player.is_crouching:
		request("disarm")
	else:
		player.message.emit("站著碰它會被夾到。蹲下來再拆。")


func host_request(action: String, player: Player) -> void:
	if action == "disarm" and state == ARMED and player.is_crouching:
		host_set_state(SAFE)
		_rearm = REARM
