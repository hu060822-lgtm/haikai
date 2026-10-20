class_name ResearchStation
extends GameMap
## 冰封研究站. A polar research station in a blizzard: a handful of huts scattered over
## open snow, joined by guide ropes. Outside, the cold eats your body heat and the snow
## hides everything past a few metres; inside, a stove or radiator warms you back up.
## The guardian can shut a door and leave you out there. The open snow belongs to the
## big monsters; the huts' narrow doors keep them out.

const COLD_RATE := 2.0  # body heat lost per second outdoors
const SPRINT_COLD_RATE := 1.4  # running keeps you a little warmer
const HEATER_RANGE := 4.5
const HEATER_RATE := 12.0
const FREEZE_INTERVAL := 1.5
const FREEZE_DAMAGE := 6.0
const FOG_OUTSIDE := 0.11
const FOG_INSIDE := 0.035

const LOOT_SPOTS := [
	# Main hut: bunks and mess.
	Vector3(-24.5, 0.2, -4.5), Vector3(-22.0, 0.95, 4.5), Vector3(-25.0, 0.2, 2.0),
	Vector3(-15.0, 0.95, -1.0), Vector3(-13.5, 0.2, 4.5), Vector3(-16.5, 0.2, -4.5),
	# Lab.
	Vector3(-22.5, 0.95, 16.5), Vector3(-18.0, 0.95, 24.5), Vector3(-12.0, 0.2, 24.5),
	Vector3(-14.0, 0.95, 16.0), Vector3(-20.0, 0.2, 20.0),
	# Generator shed, garage and radio hut.
	Vector3(20.5, 0.2, -22.5), Vector3(13.5, 0.2, -15.5), Vector3(24.5, 0.2, 24.5),
	Vector3(10.5, 0.2, 23.5), Vector3(24.0, 0.8, 12.0), Vector3(-0.5, 0.95, -26.0),
	Vector3(2.5, 0.2, -21.0),
	# Out in the snow.
	Vector3(0.0, 0.2, 6.0), Vector3(-6.0, 0.2, -12.0), Vector3(6.0, 0.2, -6.0),
	Vector3(-4.0, 0.2, 22.0), Vector3(16.0, 0.2, 2.0), Vector3(-26.0, 0.2, -20.0),
	Vector3(26.0, 0.2, -4.0), Vector3(3.0, 2.2, 12.5),
]

const PATROL_POINTS := [
	Vector3(0, 0, 0), Vector3(-6, 0, -14), Vector3(8, 0, -8), Vector3(-6, 0, 10),
	Vector3(4, 0, 20), Vector3(18, 0, 0), Vector3(-26, 0, -18), Vector3(-26, 0, 11),
	Vector3(26, 0, -10), Vector3(0, 0, -16), Vector3(12, 0, 18), Vector3(-4, 0, 27),
]

## Body heat of THIS machine's player (every peer tracks its own).
var body_heat := 100.0

var _indoors: Array[AABB] = []
var _heaters: Array[Vector3] = []
var _env: Environment
var _snow: CPUParticles3D
var _wind: AudioStreamPlayer
var _freeze_timer := FREEZE_INTERVAL
var _warned := false
var _outside := false
var _snowcat_lights: Array[Node3D] = []


func build() -> void:
	map_name = "冰封研究站"
	intro = "暴風雪裡的研究站。外面很冷，待太久會凍死，進有暖爐的屋子回溫。雪地車要先修好發電機。"
	objective_text = "到發電機房重啟發電機（東北）"
	exit_text = "到車庫坐雪地車撤離（東南）"
	objective_message = "發電機轟的一聲轉起來了。整片雪地都聽到了。"
	blocked_message = "雪地車沒油沒電。先去發電機房重啟發電機。"
	exit_name = "雪地車"
	warning_message = "暴風雪越來越大！兩分鐘後，外面誰都撐不住。"
	timeout_cause = "暴風雪吞掉了整座研究站"
	player_spawn = Vector3(-17.0, 0.1, 0.0)
	player_spawn_yaw = -PI / 2.0
	monster_spawn = Vector3(6.0, 0.1, 2.0)
	patrol_points.assign(PATROL_POINTS)
	loot_spots.assign(LOOT_SPOTS)
	loot_count = Vector2i(15, 19)
	bounds = AABB(Vector3(-29.5, -0.5, -29.5), Vector3(59, 9, 59))
	overview_height = 14.0
	_env = _environment(Color(0.16, 0.17, 0.2), Color(0.5, 0.55, 0.65), 0.45, Color(0.55, 0.58, 0.64), FOG_OUTSIDE, "drone", -20.0)
	_build_ground()
	_build_main_hut()
	_build_lab()
	_build_generator_shed()
	_build_garage()
	_build_radio_hut()
	_build_yard()
	_build_weather()


func _process(delta: float) -> void:
	super(delta)
	var local := _local_player()
	if local == null:
		return
	# The snow and the wind follow you; the fog closes in when you step outside.
	_snow.global_position = local.global_position + Vector3(0, 4.0, 0)
	_outside = is_outdoors(local.global_position)
	_snow.emitting = _outside
	_env.fog_density = move_toward(_env.fog_density, FOG_OUTSIDE if _outside else FOG_INSIDE, delta * 0.08)
	_wind.volume_db = move_toward(_wind.volume_db, -6.0 if _outside else -22.0, delta * 20.0)


func _physics_process(delta: float) -> void:
	var local := _local_player()
	if local == null or not local.is_active():
		return
	update_body_heat(local, delta)


## Runs for the local player only: cold outside, warm by a heater, freezing at zero.
func update_body_heat(player: Player, delta: float) -> void:
	var pos := player.global_position
	if is_outdoors(pos):
		var rate := COLD_RATE
		if Input.is_action_pressed("sprint") and player.velocity.length() > Player.WALK_SPEED:
			rate = SPRINT_COLD_RATE
		# Glowing coals in your pack keep the cold off.
		for item in player.items:
			if LootTable.has_tag(item, "hot"):
				rate *= 0.5
		body_heat = maxf(body_heat - rate * delta, 0.0)
	elif near_heater(pos):
		body_heat = minf(body_heat + HEATER_RATE * delta, 100.0)
	if body_heat < 40.0 and not _warned:
		_warned = true
		player.message.emit("好冷…手開始不聽使喚。快進有暖爐的屋子。")
	elif body_heat > 70.0:
		_warned = false
	if body_heat <= 0.0:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_freeze_timer = FREEZE_INTERVAL
			player.take_damage(FREEZE_DAMAGE, "在暴風雪裡凍死了")
	else:
		_freeze_timer = FREEZE_INTERVAL


func is_outdoors(pos: Vector3) -> bool:
	for room in _indoors:
		if room.has_point(pos + Vector3.UP * 0.5):
			return false
	return true


func near_heater(pos: Vector3) -> bool:
	for heater in _heaters:
		if heater.distance_to(pos) < HEATER_RANGE:
			return true
	return false


func status_text() -> String:
	var local := _local_player()
	if local == null or not local.is_active():
		return ""
	var feel := "暖和" if body_heat > 70.0 else ("發冷" if body_heat > 40.0 else ("凍僵" if body_heat > 0.0 else "失溫！"))
	var where := "（室外）" if _outside else ("（暖爐旁）" if near_heater(local.global_position) else "")
	return "體溫 %d%%　%s%s" % [int(ceil(body_heat)), feel, where]


func _on_objective() -> void:
	for light in _snowcat_lights:
		light.visible = true


func _local_player() -> Player:
	if Run.instance == null or Run.instance.local_player == null:
		return null
	return Run.instance.local_player


## A hut: floor, walls with doorways ([wall, distance along it, width, height]), a roof
## the guardian can see through, and an indoor volume that keeps the cold out.
func _hut(min_corner: Vector2, max_corner: Vector2, height: float, doors: Array,
		wall_texture := "panel", tint := Color(0.75, 0.7, 0.62)) -> void:
	var a := Vector3(min_corner.x, 0, min_corner.y)
	var b := Vector3(max_corner.x, 0, max_corner.y)
	var walls := {
		"north": [Vector3(a.x, 0, a.z), Vector3(b.x, 0, a.z)],
		"south": [Vector3(a.x, 0, b.z), Vector3(b.x, 0, b.z)],
		"west": [Vector3(a.x, 0, a.z), Vector3(a.x, 0, b.z)],
		"east": [Vector3(b.x, 0, a.z), Vector3(b.x, 0, b.z)],
	}
	var openings := {"north": [], "south": [], "west": [], "east": []}
	for door in doors:
		openings[door[0]].append([door[1], door[2], door[3]])
	for side in walls:
		_wall(walls[side][0], walls[side][1], height, wall_texture, openings[side], 0.25, tint)
	var size := b - a
	var center := (a + b) / 2.0
	_box(Vector3(size.x - 0.2, 0.02, size.z - 0.2), center + Vector3(0, 0.01, 0), "wood", Vector3.ZERO, 0, Color(0.7, 0.6, 0.5))
	_roof(Vector3(size.x + 0.6, 0.3, size.z + 0.6), center + Vector3(0, height + 0.15, 0), "snow", Color(0.9, 0.92, 0.95))
	_indoors.append(AABB(a + Vector3(0.1, -0.5, 0.1), size - Vector3(0.2, -height - 0.5, 0.2)))


func _heater(pos: Vector3) -> void:
	_box(Vector3(0.9, 1.0, 0.7), pos + Vector3(0, 0.5, 0), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.5, 0.35, 0.3))
	var mouth := _glow(Vector3(0.5, 0.3, 0.05), pos + Vector3(0, 0.45, 0.36), Color(1.0, 0.45, 0.1))
	mouth.rotation.y = 0.0
	_light(pos + Vector3(0, 1.2, 0.6), Color(1.0, 0.55, 0.25), 1.0, 6.0, true)
	_heaters.append(pos)


func _build_ground() -> void:
	_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), "snow", Vector3.ZERO, Layers.WORLD, Color.WHITE, 2.0)
	# Ice cliffs all the way round.
	for spec in [[Vector3(60, 8, 1), Vector3(0, 4, -30.5)], [Vector3(60, 8, 1), Vector3(0, 4, 30.5)],
			[Vector3(1, 8, 60), Vector3(-30.5, 4, 0)], [Vector3(1, 8, 60), Vector3(30.5, 4, 0)]]:
		_box(spec[0], spec[1], "snow", Vector3.ZERO, Layers.WORLD, Color(0.7, 0.78, 0.85))
	for spec in [[Vector3(-28, 1.5, -10), 20.0, 5.0], [Vector3(28, 2.0, 8), -15.0, 7.0], [Vector3(-8, 1.2, -29), 5.0, 9.0],
			[Vector3(12, 1.6, 29), -8.0, 8.0], [Vector3(-29, 1.8, 26), 40.0, 6.0], [Vector3(29, 1.4, -26), 30.0, 6.0]]:
		_box(Vector3(spec[2], spec[0].y * 2.0, 3.0), Vector3(spec[0].x, spec[0].y, spec[0].z), "snow",
			Vector3(0, spec[1], 0), Layers.WORLD, Color(0.75, 0.82, 0.9))


func _build_main_hut() -> void:
	# Spawn hut: bunk room (west, with the stove) and mess (east), doors east and south.
	_hut(Vector2(-26, -6), Vector2(-12, 6), 3.4, [["east", 6.0, 1.4, 2.3], ["south", 10.0, 1.4, 2.3]])
	_wall(Vector3(-19, 0, -6), Vector3(-19, 0, 6), 3.4, "panel", [[4.0, 1.2, 2.3]], 0.2, Color(0.7, 0.65, 0.58))
	_add_gate(Vector3(-12, 1.15, 0), Vector3(0.15, 2.3, 1.4))
	_add_gate(Vector3(-16, 1.15, 6), Vector3(1.4, 2.3, 0.15))
	_heater(Vector3(-25.2, 0, 0))
	for z in [-4.5, -1.8, 2.2, 4.8]:
		_box(Vector3(2.0, 0.5, 0.9), Vector3(-22.5, 0.45, z), "wood", Vector3.ZERO, Layers.WORLD, Color(0.6, 0.5, 0.4))
	_box(Vector3(2.2, 0.8, 1.2), Vector3(-15.0, 0.4, -1.0), "wood")
	_box(Vector3(0.7, 2.0, 2.4), Vector3(-12.6, 1.0, -4.0), "panel", Vector3.ZERO, Layers.WORLD, Color(0.6, 0.65, 0.7))
	_add_locker(Vector3(-25.5, 0, -5.2), PI / 2.0)
	_light(Vector3(-15.5, 3.0, 0), Color(1.0, 0.9, 0.7), 0.6, 7.0, true)


func _build_lab() -> void:
	_hut(Vector2(-24, 14), Vector2(-10, 26), 3.4, [["east", 6.0, 1.4, 2.3], ["north", 4.0, 1.2, 2.3]],
		"panel", Color(0.65, 0.72, 0.75))
	_add_gate(Vector3(-10, 1.15, 20), Vector3(0.15, 2.3, 1.4))
	# Benches, a sample freezer and something in a tank.
	_box(Vector3(4.0, 0.9, 1.0), Vector3(-21.0, 0.45, 16.5), "panel", Vector3.ZERO, Layers.WORLD, Color(0.8, 0.82, 0.85))
	_box(Vector3(4.0, 0.9, 1.0), Vector3(-18.0, 0.45, 24.5), "panel", Vector3.ZERO, Layers.WORLD, Color(0.8, 0.82, 0.85))
	_box(Vector3(1.0, 0.9, 3.0), Vector3(-14.0, 0.45, 16.5), "panel", Vector3.ZERO, Layers.WORLD, Color(0.8, 0.82, 0.85))
	_cylinder(Vector3(-15, 0, 22), Vector3(-15, 2.4, 22), 0.7, "panel")
	_glow(Vector3(0.9, 1.4, 0.9), Vector3(-15, 1.2, 22), Color(0.3, 1.0, 0.7)).scale = Vector3(1.05, 1.0, 1.05)
	_heater(Vector3(-23.2, 0, 21))
	_light(Vector3(-17, 3.0, 20), Color(0.8, 0.95, 1.0), 0.5, 8.0, true)


func _build_generator_shed() -> void:
	_hut(Vector2(12, -24), Vector2(22, -14), 4.0, [["west", 5.0, 1.4, 2.3]], "rust_metal", Color(0.65, 0.6, 0.55))
	_add_gate(Vector3(12, 1.15, -19), Vector3(0.15, 2.3, 1.4))
	_box(Vector3(3.0, 1.8, 2.0), Vector3(18.5, 0.9, -19.5), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.55, 0.6, 0.5))
	_cylinder(Vector3(18.5, 1.8, -19.5), Vector3(18.5, 4.4, -19.5), 0.25, "pipe")
	_cylinder(Vector3(20.5, 0.6, -21.5), Vector3(20.5, 0.6, -16.5), 0.6, "rust_metal")
	_add_lever(Vector3(16.0, 0, -22.8), 0.0, "[E] 拉動發電機啟動繩（雪地車會有電，但聲音整片雪地都聽得到）")
	_light(Vector3(16, 3.4, -18), Color(1.0, 0.8, 0.5), 0.4, 6.0, true)


func _build_garage() -> void:
	# Big door on the west side wide enough for the snowcat; a side door on the north.
	_hut(Vector2(8, 10), Vector2(26, 26), 5.4, [["west", 8.0, 6.0, 5.0], ["north", 12.0, 1.2, 2.3]],
		"rust_metal", Color(0.6, 0.62, 0.66))
	_add_gate(Vector3(8, 2.5, 18), Vector3(0.15, 5.0, 6.0))
	_add_gate(Vector3(20, 1.15, 10), Vector3(1.2, 2.3, 0.15))
	# The snowcat: a boxy cabin on two tracks, waiting by the back wall.
	var center := Vector3(19, 0, 19)
	for side in [-1.4, 1.4]:
		_box(Vector3(4.6, 1.0, 0.8), center + Vector3(0, 0.5, side), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.3, 0.3, 0.3))
	_box(Vector3(4.6, 0.3, 2.0), center + Vector3(0, 1.15, 0), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.35, 0.33, 0.3))
	_box(Vector3(2.2, 1.4, 2.0), center + Vector3(-1.2, 2.0, 0), "panel", Vector3.ZERO, Layers.WORLD, Color(0.9, 0.35, 0.15))
	_box(Vector3(0.05, 0.6, 1.6), center + Vector3(-2.32, 2.3, 0), "panel", Vector3.ZERO, 0, Color(0.15, 0.2, 0.25))
	for side in [-0.7, 0.7]:
		var lamp := _glow(Vector3(0.05, 0.25, 0.3), center + Vector3(-2.33, 1.55, side), Color(1.0, 0.95, 0.7))
		lamp.visible = false
		_snowcat_lights.append(lamp)
	# Climb on behind the snowcat.
	_add_extraction(Vector3(23.4, 0, 19))
	_box(Vector3(2.0, 0.6, 2.0), Vector3(24, 0.3, 12), "wood")
	_box(Vector3(1.0, 2.0, 3.0), Vector3(25.3, 1.0, 24), "wood", Vector3.ZERO, Layers.WORLD, Color(0.6, 0.5, 0.4))
	_add_locker(Vector3(9.0, 0, 25.2), PI)
	_light(Vector3(17, 4.8, 18), Color(0.9, 0.9, 0.8), 0.5, 10.0, true)


func _build_radio_hut() -> void:
	_hut(Vector2(-4, -27), Vector2(4, -20), 3.0, [["south", 4.0, 1.2, 2.3]], "wood", Color(0.7, 0.55, 0.45))
	_box(Vector3(3.0, 0.9, 0.9), Vector3(-1.5, 0.45, -26.0), "wood")
	_box(Vector3(1.0, 0.8, 0.6), Vector3(-2.0, 1.3, -26.1), "panel", Vector3.ZERO, Layers.WORLD, Color(0.4, 0.45, 0.4))
	_glow(Vector3(0.6, 0.15, 0.05), Vector3(-2.0, 1.4, -25.78), Color(1.0, 0.3, 0.2))
	# Radio mast with a blinking light on top.
	_cylinder(Vector3(6, 0, -24), Vector3(6, 8, -24), 0.15, "rust_metal")
	_light(Vector3(6, 8.2, -24), Color(1.0, 0.2, 0.15), 0.8, 6.0, true)
	_light(Vector3(0, 2.6, -23.5), Color(1.0, 0.85, 0.6), 0.35, 5.0, true)


func _build_yard() -> void:
	# Fuel tanks, crates and a half-buried tracked wagon between the huts.
	_cylinder(Vector3(-2, 1.0, 12.5), Vector3(8, 1.0, 12.5), 1.0, "rust_metal")
	for x in [-1.0, 7.0]:
		_box(Vector3(0.3, 0.5, 1.6), Vector3(x, 0.25, 12.5), "rust_metal")
	for spec in [[Vector3(-5, 0.6, -6), 15.0], [Vector3(-4, 0.6, -4.5), -20.0], [Vector3(10, 0.6, -2), 40.0],
			[Vector3(2, 0.6, 24), 10.0], [Vector3(-8, 0.6, 4), 0.0]]:
		_box(Vector3(1.2, 1.2, 1.2), spec[0], "wood", Vector3(0, spec[1], 0))
	_box(Vector3(4.5, 1.6, 2.4), Vector3(-6, 0.6, -18), "rust_metal", Vector3(6, 25, -4), Layers.WORLD, Color(0.5, 0.4, 0.35))
	# Snow drifts.
	for spec in [[Vector3(4, 0.4, -12), 30.0, 5.0], [Vector3(-8, 0.4, 16), -10.0, 4.0], [Vector3(20, 0.4, 4), 60.0, 6.0],
			[Vector3(-20, 0.4, 10), 0.0, 7.0], [Vector3(0, 0.4, -4), 75.0, 3.5]]:
		_box(Vector3(spec[2], 0.8, 1.8), spec[0], "snow", Vector3(0, spec[1], 0), Layers.WORLD, Color(0.95, 0.97, 1.0))
	# Guide ropes on posts between the huts, and lamp posts that barely cut the snow.
	var rope := [Vector3(-12, 0, 2), Vector3(-4, 0, 3), Vector3(4, 0, 0), Vector3(10, 0, -10),
		Vector3(11, 0, -19)]
	_rope(rope)
	_rope([Vector3(-4, 0, 3), Vector3(-6, 0, 12), Vector3(-10, 0, 19)])
	_rope([Vector3(4, 0, 0), Vector3(7, 0, 9), Vector3(7, 0, 17)])
	_rope([Vector3(-4, 0, 3), Vector3(-2, 0, -10), Vector3(0, 0, -19)])
	for pos in [Vector3(-4, 0, 3), Vector3(10, 0, -10), Vector3(7, 0, 17), Vector3(-10, 0, 19), Vector3(0, 0, -19)]:
		_cylinder(pos, pos + Vector3(0, 3.5, 0), 0.08, "rust_metal")
		_light(pos + Vector3(0, 3.6, 0), Color(1.0, 0.85, 0.55), 0.7, 7.0, true)


func _rope(points: Array) -> void:
	for i in points.size():
		var post: Vector3 = points[i]
		_cylinder(post, post + Vector3(0, 1.2, 0), 0.06, "wood", Vector2(1, 1), 0)
		if i > 0:
			var prev: Vector3 = points[i - 1]
			_cylinder(prev + Vector3(0, 1.1, 0), post + Vector3(0, 1.1, 0), 0.02, "wood", Vector2(1, 4), 0)


func _build_weather() -> void:
	_snow = CPUParticles3D.new()
	_snow.amount = 400
	_snow.lifetime = 2.5
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(9, 1, 9)
	_snow.direction = Vector3(0.6, -1, 0.2)
	_snow.spread = 15.0
	_snow.gravity = Vector3(1.5, -2.0, 0.4)
	_snow.initial_velocity_min = 2.0
	_snow.initial_velocity_max = 4.0
	var flake := QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.95, 0.97, 1.0)
	flake.material = material
	_snow.mesh = flake
	_snow.local_coords = false
	_snow.emitting = false
	add_child(_snow)
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.looped("wind")
	_wind.volume_db = -22.0
	_wind.autoplay = true
	add_child(_wind)
