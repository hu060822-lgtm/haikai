class_name ThinIce
extends Trap
## A frozen-over pool of meltwater, drifted over with a little snow. The first step
## cracks it; the next one (or standing on it too long) breaks through into knee-deep
## freezing water: slow wading, and on the ice station your body heat drains fast while
## you're in it. The hole stays open. Footprint ~1.7 m across.
## Tell: it's smoother and bluer than the snow round it, and it cracks loudly first.

enum { SOLID, CRACKED, BROKEN }

const RADIUS := 0.8
const BREAK_TIME := 1.5
const DAMAGE := 5.0
const NOISE := 14.0
const CHILL_PER_SECOND := 12.0
const WADE := 0.45

var _ice: MeshInstance3D
var _cracks: MeshInstance3D
var _water: MeshInstance3D
var _shards: MeshInstance3D
var _on := {}
var _stand := 0.0
var _tick := 0.0


func build() -> void:
	var outline := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var r := RADIUS * rng.randf_range(0.85, 1.1)
		outline.append(Vector2(cos(a) * r, sin(a) * r))
	var flat := LowPoly.at(Vector3(0, 0.025, 0), Vector3(-90, 0, 0))
	_ice = part([[LowPoly.extrude(outline, 0.05), flat]], "snow", Color(0.72, 0.86, 1.0), Color(0.04, 0.06, 0.08))
	_water = part([[LowPoly.extrude(outline, 0.03), LowPoly.at(Vector3(0, 0.015, 0), Vector3(-90, 0, 0))]],
		"concrete", Color(0.06, 0.09, 0.13), Color(0.0, 0.01, 0.02))
	_water.visible = false
	var lines := []
	for i in 5:
		var a := rng.randf_range(0.0, TAU)
		var length := rng.randf_range(0.4, 0.75)
		lines.append([LowPoly.prism(3, 0.008, 0.008, length, false),
			LowPoly.at(Vector3(cos(a), 0, sin(a)) * length * 0.45 + Vector3(0, 0.052, 0), Vector3(0, -rad_to_deg(a), 90))])
	_cracks = part(lines, "concrete", Color(0.9, 0.95, 1.0), Color(0.3, 0.35, 0.4))
	_cracks.visible = false
	var bits := []
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var at := Vector3(cos(a), 0, sin(a)) * RADIUS * rng.randf_range(0.75, 0.95)
		bits.append(slab(Vector3(0.28, 0.03, 0.2), at + Vector3(0, 0.045, 0), Vector3(rng.randf_range(-25, 25), rad_to_deg(-a), rng.randf_range(-20, 20))))
	_shards = part(bits, "snow", Color(0.75, 0.88, 1.0), Color(0.04, 0.06, 0.08))
	_shards.visible = false


func host_tick(delta: float) -> void:
	var anyone := false
	for player in players():
		var key := String(player.name)
		var inside := feet_within(player, RADIUS, 0.4)
		var entered: bool = inside and not _on.get(key, false)
		_on[key] = inside
		if not inside:
			continue
		anyone = true
		match state:
			SOLID:
				if entered:
					host_set_state(CRACKED)
					host_noise(6.0)
					_stand = 0.0
			CRACKED:
				if entered or _stand > BREAK_TIME:
					host_set_state(BROKEN)
					host_noise(NOISE)
					_tick = 0.0
					for victim in players():
						if feet_within(victim, RADIUS, 0.4):
							host_affect(victim, {"damage": DAMAGE, "cause": "掉進冰窟窿，凍死在水裡", "note": "冰面破了！你掉進刺骨的冰水裡！",
								"slow": 0.6, "slow_factor": WADE, "chill": 15.0, "shake": 0.6})
					return
	if state == CRACKED and anyone:
		_stand += delta
	if state == BROKEN:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for player in players():
				if feet_within(player, RADIUS, 0.4):
					host_affect(player, {"slow": 0.6, "slow_factor": WADE, "chill": CHILL_PER_SECOND * 0.5})


func apply_state(new_state: int, _arg: int) -> void:
	match new_state:
		CRACKED:
			_cracks.visible = true
			sound("creak", 0.0, 25.0, 2.2)
			sound("tink", -4.0, 20.0, 0.6)
		BROKEN:
			_ice.visible = false
			_cracks.visible = false
			_water.visible = true
			_shards.visible = true
			sound("tink", 4.0, 35.0, 0.5)
			sound("thump", 0.0, 30.0, 1.5)
			burst(global_position + Vector3.UP * 0.05, Color(0.6, 0.75, 0.9), 16, 3.0, 50.0, -9.0, 0.6, 0.05)
