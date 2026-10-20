class_name LivePuddle
extends Trap
## A dark puddle with a torn power cable lying in it. While the map's power is on, the
## water is live: standing in it shocks you over and over. A blackout makes it safe.
## Tell: the cable end spits sparks every few seconds, and buzzes.

const RADIUS := 0.95
const DAMAGE := 9.0
const INTERVAL := 0.6
const NOISE := 8.0

var _spark := 0.0


func build() -> void:
	_spark = rng.randf_range(0.5, 3.0)
	var outline := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0
		var r := RADIUS * rng.randf_range(0.8, 1.15)
		outline.append(Vector2(cos(a) * r, sin(a) * r))
	part([[LowPoly.extrude(outline, 0.03), LowPoly.at(Vector3(0, 0.015, 0), Vector3(-90, 0, 0))]],
		"concrete", Color(0.1, 0.12, 0.15), Color(0.01, 0.015, 0.02))
	var cable := PackedVector3Array([Vector3(-1.6, 0.03, 0.5), Vector3(-1.1, 0.03, 0.2), Vector3(-0.6, 0.04, 0.25), Vector3(-0.15, 0.045, 0.0)])
	part([[LowPoly.tube(cable, PackedFloat32Array([0.025, 0.025, 0.025, 0.02]), 4), Transform3D.IDENTITY],
		[LowPoly.prism(4, 0.012, 0.0, 0.08, false), LowPoly.at(Vector3(-0.1, 0.05, 0.0), Vector3(0, 0, -70))]],
		"rust_metal", Color(0.15, 0.13, 0.12), Color.BLACK, null, "puddle_cable")


func is_live() -> bool:
	return map == null or map.power_on


func host_tick(_delta: float) -> void:
	if not is_live():
		return
	for player in players():
		if feet_within(player, RADIUS, 0.3) and host_cooldown(player, INTERVAL):
			host_noise(NOISE, GameNoise.Kind.IMPACT)
			_spark_fx.rpc()
			host_affect(player, {"damage": DAMAGE, "cause": "在積水裡被電死了", "note": "水裡有電！",
				"slow": 0.5, "slow_factor": 0.4, "shake": 0.5})


func local_tick(delta: float) -> void:
	if not is_live():
		return
	_spark -= delta
	if _spark <= 0.0:
		_spark = rng.randf_range(1.5, 4.0)
		_sparks()


@rpc("authority", "call_local", "unreliable")
func _spark_fx() -> void:
	_sparks()


func _sparks() -> void:
	burst(to_global(Vector3(-0.15, 0.05, 0)), Color(0.7, 0.85, 1.0), 6, 2.0, 60.0, -8.0, 0.3, 0.025, true)
	sound("zap", -8.0, 14.0, randf_range(0.9, 1.3))
