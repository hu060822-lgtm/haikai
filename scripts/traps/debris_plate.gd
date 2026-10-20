class_name DebrisPlate
extends Trap
## A pressure plate under a sandbag hung from the ceiling. Step on it: a click, a short
## wait, then the bag (and the junk tied to it) drops on whoever is still standing there.
## Hear the click, keep moving. One use. params.ceiling: where the rope is tied (5.6, a wing
## room's height); the bag always hangs at about 2.4 m.
## Tell: the plate sits a finger higher than the floor; a rope goes up into the dark.

enum { ARMED, CLICKED, FALLEN }

const DELAY := 0.8
const RADIUS := 0.9
const DAMAGE := 35.0
const NOISE := 20.0

var ceiling := 5.6
const BAG_Y := 2.4
var _bag: Node3D
var _rope: MeshInstance3D
var _timer := 0.0
var _plate: MeshInstance3D


func build() -> void:
	ceiling = maxf(params.get("ceiling", 5.6), BAG_Y + 0.6)
	_plate = part([[LowPoly.chamfer_box(Vector3(0.6, 0.03, 0.6), 0.01), LowPoly.at(Vector3(0, 0.015, 0))]],
		"rust_metal", Color(0.5, 0.48, 0.42), Color.BLACK, null, "plate")
	_bag = Node3D.new()
	_bag.position = Vector3(0, BAG_Y, 0)
	add_child(_bag)
	part([[LowPoly.blob(0.3, Vector3(1.0, 1.3, 1.0), 0, 0.12, seed_value()), Transform3D.IDENTITY],
		[LowPoly.prism(4, 0.08, 0.04, 0.12), LowPoly.at(Vector3(0, 0.42, 0))]],
		"snow", Color(0.62, 0.52, 0.36), Color.BLACK, _bag)
	part([[LowPoly.chamfer_box(Vector3(0.5, 0.12, 0.2), 0.02), LowPoly.at(Vector3(0.1, -0.3, 0.12), Vector3(0, 30, 15))]],
		"wood", Color(0.5, 0.4, 0.3), Color.BLACK, _bag, "plate_plank")
	var rope := ceiling - BAG_Y - 0.45
	_rope = part([[LowPoly.prism(3, 0.012, 0.012, rope, false), LowPoly.at(Vector3(0, ceiling - rope / 2.0, 0))]],
		"wood", Color(0.7, 0.62, 0.45), Color.BLACK, null)


func seed_value() -> int:
	return rng.seed % 7


func host_tick(delta: float) -> void:
	match state:
		ARMED:
			for player in players():
				if feet_in(player, Vector2(0.32, 0.32), 0.4):
					host_set_state(CLICKED)
					_timer = DELAY
					return
		CLICKED:
			_timer -= delta
			if _timer <= 0.0:
				host_set_state(FALLEN)
				host_noise(NOISE)
				for player in players():
					if feet_within(player, RADIUS, 1.0):
						host_affect(player, {"damage": DAMAGE, "cause": "被從天而降的沙包砸死了",
							"note": "頭頂有東西砸下來了！", "shake": 0.9})


func apply_state(new_state: int, _arg: int) -> void:
	match new_state:
		CLICKED:
			_plate.position.y = -0.015
			sound("tick", 0.0, 15.0, 0.7)
			sound("creak", -6.0, 15.0, 1.4, Vector3(0, BAG_Y + 0.5, 0))
		FALLEN:
			_rope.visible = false
			var tween := create_tween()
			tween.tween_property(_bag, "position:y", 0.3, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func() -> void:
				sound("thump", 6.0, 40.0, 0.7)
				burst(global_position + Vector3.UP * 0.2, Color(0.55, 0.5, 0.4), 14, 3.0, 70.0))
			tween.tween_property(_bag, "rotation:z", 0.5, 0.15)
