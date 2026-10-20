class_name Icicles
extends Trap
## A frost-burst pipe on two rusty legs, bridging a path at head height, with a fringe
## of long icicles under it. Walk under and they shiver and tinkle for a moment, then
## drop. Keep walking and they miss. One use; the broken ice stays on the floor.
## The pipe runs along local x (legs at +-0.65 m). Footprint 1.4 x 1.0, free-standing.
## Tell: the tinkle, and a glint high up if your lantern catches them.

enum { HANGING, SHIVER, FALLEN }

const TRIGGER := 0.9
const RADIUS := 0.75
const DELAY := 0.6
const DAMAGE := 25.0
const NOISE := 12.0

const PIPE_Y := 2.35

var ceiling := PIPE_Y
var _hang: Node3D
var _shards: MeshInstance3D
var _timer := 0.0
var _shiver := 0.0


func build() -> void:
	ceiling = params.get("ceiling", PIPE_Y)
	var leg := LowPoly.prism(4, 0.03, 0.03, ceiling + 0.1)
	part([[leg, LowPoly.at(Vector3(-0.65, (ceiling + 0.1) / 2.0, 0), Vector3(0, 45, 0))],
		[leg, LowPoly.at(Vector3(0.65, (ceiling + 0.1) / 2.0, 0), Vector3(0, 45, 0))],
		[LowPoly.prism(6, 0.06, 0.06, 1.45), LowPoly.at(Vector3(0, ceiling + 0.06, 0), Vector3(0, 0, 90))]],
		"rust_metal", Color(0.45, 0.42, 0.4), Color.BLACK, null, "icicle_pipe%s" % ceiling)
	_hang = Node3D.new()
	_hang.position.y = ceiling
	add_child(_hang)
	var spikes := [slab(Vector3(1.2, 0.05, 0.14), Vector3(0, -0.01, 0))]
	for i in 7:
		var length := rng.randf_range(0.35, 0.8)
		var x := -0.5 + i / 6.0 + rng.randf_range(-0.05, 0.05)
		spikes.append([LowPoly.prism(4, 0.0, rng.randf_range(0.03, 0.05), length, false),
			LowPoly.at(Vector3(x, -0.04 - length / 2.0, rng.randf_range(-0.04, 0.04)), Vector3(0, rng.randf_range(0, 90), 0))])
	part(spikes, "snow", Color(0.8, 0.9, 1.0), Color(0.08, 0.1, 0.14), _hang)
	var bits := []
	for i in 6:
		bits.append(slab(Vector3(0.14, 0.03, 0.05), Vector3(rng.randf_range(-0.6, 0.6), 0.015, rng.randf_range(-0.35, 0.35)),
			Vector3(0, rng.randf_range(0, 180), 0)))
	_shards = part(bits, "snow", Color(0.8, 0.9, 1.0), Color(0.08, 0.1, 0.14))
	_shards.visible = false


func host_tick(delta: float) -> void:
	match state:
		HANGING:
			for player in players():
				if feet_within(player, TRIGGER, 1.0):
					host_set_state(SHIVER)
					_timer = DELAY
					return
		SHIVER:
			_timer -= delta
			if _timer <= 0.0:
				host_set_state(FALLEN)
				host_noise(NOISE)
				for player in players():
					if feet_within(player, RADIUS, 1.0):
						host_affect(player, {"damage": DAMAGE, "cause": "被掉下來的冰柱刺穿了", "note": "冰柱砸在你身上！", "shake": 0.8})


func local_tick(delta: float) -> void:
	if state == SHIVER:
		_shiver += delta
		_hang.position.x = sin(_shiver * 60.0) * 0.015


func apply_state(new_state: int, _arg: int) -> void:
	match new_state:
		SHIVER:
			sound("tink", -2.0, 18.0, 1.8, Vector3(0, ceiling, 0))
			sound("tink", -4.0, 18.0, 2.4, Vector3(0.3, ceiling, 0))
		FALLEN:
			var tween := create_tween()
			tween.tween_property(_hang, "position:y", 0.3, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func() -> void:
				_hang.visible = false
				_shards.visible = true
				sound("tink", 6.0, 35.0, 0.7)
				sound("clank", -2.0, 30.0, 2.0)
				burst(global_position + Vector3.UP * 0.1, Color(0.8, 0.9, 1.0), 14, 3.0, 70.0))
