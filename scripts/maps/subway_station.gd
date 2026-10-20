class_name SubwayStation
extends GameMap
## 廢棄地鐵站「末班車」. A dead underground station: a long island platform between two
## sunken tracks, a ticket hall on a mezzanine at the west end reached by stopped
## escalators, the signal box at the east tunnel mouth (the objective) and the
## maintenance lift at the west one (the exit). The back rooms, tunnels and old side
## platforms of the random sprawl open off the narrow walkways behind the tracks, so
## every trip out for loot means crossing a line.
##
## Every few minutes the last train comes through. A horn far off down the tunnel,
## warning lamps along the platform edge and headlights swelling in the dark give about
## ten seconds' notice of WHICH line it is on; then a phantom train tears through the
## whole length of the station. Anything in that trench is thrown aside and badly hurt;
## monsters it catches take a huge hit. Stand on the platform or on the walkway behind
## the track and it roars past a metre away. The host times the trains from the run seed
## and tells every peer when one starts.

const END_X := 47.0  # the core's ends: black tunnel voids
const HALL_X := 34.0  # where the platform hall ends and the tunnels begin
const ISLAND_Z := 6.0  # the island platform's half width
const TRACK_Z := 8.5  # the middle of each track
const BED_OUT_Z := 11.0  # the trench's outer edge; then the walkway
const WALL_Z := 13.0  # inner face of the outer walls
const RAIL_Y := -0.9  # the track bed
const ROOF_Y := 9.0
const TUNNEL_TOP := 4.5
const CONC_Y := 5.0  # the ticket hall mezzanine
const CONC_X := Vector2(-HALL_X, -15.0)
## Level crossings over each track, lined up with the doorways behind them: [track, x].
const CROSSINGS := [[0, -26.0], [0, -4.0], [0, 20.0], [1, -20.0], [1, 4.0], [1, 26.0]]

## The last train.
const TRAIN_SPEED := 26.0
const CHUNK := 4.6
const CHUNKS := 9
const TRAIN_LEN := CHUNK * CHUNKS
const WARN_TIME := 10.0
const HIT_HALF_WIDTH := 2.6
const HIT_DAMAGE := 60.0
const MONSTER_DAMAGE := 520.0
const FIRST_TRAIN := Vector2(75.0, 100.0)
const INTERVAL := Vector2(120.0, 170.0)
## Once the station has its power back the trains run more often.
const INTERVAL_POWERED := Vector2(70.0, 100.0)
const TRACK_NAMES := ["南側", "北側"]

const LOOT_SPOTS := [
	# Ticket hall: the office, the ticket machines, the paid side of the gates.
	Vector3(-30.5, 5.95, 11.6), Vector3(-28.0, 5.2, 9.6), Vector3(-32.0, 5.2, -11.6), Vector3(-26.5, 5.2, -11.8),
	Vector3(-18.5, 5.2, 9.5), Vector3(-19.0, 5.2, -9.0), Vector3(-33.0, 5.2, 3.0),
	# The platform.
	Vector3(9.0, 0.65, 3.6), Vector3(-26.0, 0.65, -3.6), Vector3(19.0, 0.2, -5.0), Vector3(29.0, 0.2, 2.0),
	Vector3(-8.0, 0.2, 5.0), Vector3(-31.0, 0.2, 4.8), Vector3(0.0, 0.2, -5.0), Vector3(-14.0, 0.2, -5.0),
	# Down on the tracks (risky) and on the walkways behind them.
	Vector3(-14.0, -0.7, 8.5), Vector3(14.0, -0.7, -8.5), Vector3(38.0, -0.7, 8.5), Vector3(-39.0, -0.7, -8.5),
	Vector3(2.0, 0.2, 12.2), Vector3(-10.0, 0.2, -12.2), Vector3(41.0, 0.2, -12.2), Vector3(-43.0, 0.2, 12.2),
	# The signal box and the lift room.
	Vector3(36.5, 0.95, -4.6), Vector3(39.8, 0.2, 4.8), Vector3(-40.0, 0.2, -5.0), Vector3(-35.6, 0.2, 5.0),
]

const PATROL_POINTS := [
	Vector3(-27, 0, 3.2), Vector3(-18, 0, -3.6), Vector3(-9, 0, 4.0), Vector3(0, 0, -2.0), Vector3(9, 0, 2.0),
	Vector3(19, 0, -2.5), Vector3(29, 0, 2.5), Vector3(-4, 0, -8.5), Vector3(4, 0, 8.5), Vector3(20, 0, -8.5),
	Vector3(26, 0, 8.5),
]

## Where the train is: "idle", "warning" (horn, lamps, headlights) or "passing".
var train_state := "idle"
var train_track := 0
var train_dir := 1
## Seconds until the host calls the next train.
var next_train := 90.0
## Seconds of warning before the train arrives (tests shorten it).
var warn_time := WARN_TIME
var trains_passed := 0
var lift_called := false

var _train_rng := RandomNumberGenerator.new()
var _warn_left := 0.0
var _sweep_t := 0.0
var _hit := {}
var _second_horn := false
var _train: Node3D
var _chunks: Array[Node3D] = []
var _rumble: AudioStreamPlayer3D
var _headlight: OmniLight3D
var _beam: OmniLight3D
var _warn_lamps := [[], []]
var _blink := 0.0
var _powered_lights: Array[Node3D] = []
var _lift_lamp: Node3D
var _lift_cage: Node3D


func build() -> void:
	map_name = "廢棄地鐵站「末班車」"
	intro = "封閉多年的地鐵站。末班車還在跑——聽到汽笛就離開軌道。先到東端號誌室恢復供電，才叫得動維修電梯。"
	objective_text = "到月台東端的號誌室恢復供電"
	exit_text = "到月台西端搭維修電梯撤離"
	objective_message = "號誌室的總閘拉下去了。燈一排排亮起來，維修電梯開始往下降…整座車站都聽到了。"
	blocked_message = "維修電梯沒電。先去月台東端的號誌室恢復供電。"
	exit_name = "維修電梯"
	warning_message = "廣播：「末班車即將進站，請旅客儘速離開。兩分鐘後車站關閉。」"
	timeout_cause = "車站關閉了，你和末班車一起留在了這裡"
	player_spawn = Vector3(-28.0, CONC_Y + 0.1, 0.0)
	player_spawn_yaw = -PI / 2.0
	monster_spawn = Vector3(10.0, 0.1, -3.0)
	patrol_points.assign(PATROL_POINTS)
	loot_spots.assign(LOOT_SPOTS)
	loot_count = Vector2i(15, 19)
	bounds = AABB(Vector3(-END_X, -1.5, -WALL_Z - 1.0), Vector3(END_X * 2.0, ROOF_Y + 1.5, WALL_Z * 2.0 + 2.0))
	overview_height = ROOF_Y - 0.4
	_train_rng.seed = rng.seed ^ 0x7A1B
	next_train = _train_rng.randf_range(FIRST_TRAIN.x, FIRST_TRAIN.y)
	_environment(Color(0.008, 0.01, 0.01), Color(0.34, 0.4, 0.38), 0.72, Color(0.025, 0.035, 0.032), 0.04, "drone", -15.0)
	_plan_wings()
	_build_shell()
	_build_tracks()
	_build_platform()
	_build_concourse()
	_build_signal_box()
	_build_lift()
	_build_lights()
	_build_train()
	_build_wings()


# --- The last train ----------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	match train_state:
		"warning":
			_warn_left -= delta
			var k := clampf(1.0 - _warn_left / maxf(warn_time, 0.01), 0.0, 1.0)
			_beam.light_energy = 4.0 * k * k
			_rumble.volume_db = lerpf(-30.0, 2.0, k)
			if not _second_horn and _warn_left < 3.0:
				_second_horn = true
				_horn()
			_blink -= delta
			if _blink <= 0.0:
				_blink = 0.35
				for lamp in _warn_lamps[train_track]:
					lamp.visible = not lamp.visible
			if _warn_left <= 0.0:
				_start_sweep()
		"passing":
			_sweep_t += delta
			_place_train()
			if _sweep_t * TRAIN_SPEED > END_X * 2.0 + TRAIN_LEN:
				_end_sweep()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or Run.instance == null or Run.instance.level != self:
		return
	match train_state:
		"idle":
			next_train -= _delta
			if next_train <= 0.0:
				host_call_train()
		"passing":
			_host_hits()


## Host: send the last train down a line now (random line and direction when not given).
func host_call_train(track := -1, dir := 0) -> void:
	if not multiplayer.is_server() or train_state != "idle":
		return
	if track < 0:
		track = _train_rng.randi_range(0, 1)
	if dir == 0:
		dir = 1 if _train_rng.randf() < 0.5 else -1
	var gap := INTERVAL_POWERED if objective_on else INTERVAL
	next_train = _train_rng.randf_range(gap.x, gap.y)
	_train_coming.rpc(track, dir, warn_time)
	GameNoise.emit(get_tree(), Vector3(-dir * (END_X - 2.0), 0.5, _track_z(track)), 60.0, GameNoise.Kind.MACHINE)


@rpc("authority", "call_local", "reliable")
func _train_coming(track: int, dir: int, warning: float) -> void:
	train_state = "warning"
	train_track = track
	train_dir = dir
	warn_time = warning
	_warn_left = warning
	_second_horn = false
	_blink = 0.0
	_hit.clear()
	var mouth := Vector3(-dir * (END_X - 1.5), RAIL_Y + 1.8, _track_z(track))
	_beam.position = mouth
	_beam.light_energy = 0.0
	_beam.visible = true
	_rumble.position = mouth
	_rumble.volume_db = -30.0
	_rumble.play()
	_horn()
	var local := _local_player()
	if local != null and local.is_active():
		local.message.emit("隧道深處傳來汽笛聲…末班車要進站了！快離開%s軌道！" % TRACK_NAMES[track])
		local.add_shake(0.15)


func _horn() -> void:
	Sfx.play_3d(self, Vector3(-train_dir * (END_X - 2.0), 1.0, _track_z(train_track)), "horn", 10.0, 160.0, 1.0)


func _start_sweep() -> void:
	train_state = "passing"
	_sweep_t = 0.0
	_beam.visible = false
	for lamp in _warn_lamps[train_track]:
		lamp.visible = true
	_train.visible = true
	_train.rotation.y = 0.0 if train_dir > 0 else PI
	_place_train()


func _end_sweep() -> void:
	train_state = "idle"
	trains_passed += 1
	_train.visible = false
	_rumble.stop()
	for lamp in _warn_lamps[train_track]:
		lamp.visible = false
	if multiplayer.is_server() and Run.instance != null and Run.instance.level == self and not loot_pool.is_empty() \
			and _train_rng.randf() < 0.5:
		# A door slid open on the way through and something was left on the platform.
		var at := Vector3(_train_rng.randf_range(-HALL_X + 4.0, HALL_X - 4.0), 0.3,
			(ISLAND_Z - 0.8) * (1.0 if train_track == 1 else -1.0))
		Run.instance.host_spawn_loot(LootTable.roll(_train_rng, 0.6, loot_pool), at, _train_rng.randf_range(0, TAU))
		_lost_luggage.rpc(at)


@rpc("authority", "call_local", "reliable")
func _lost_luggage(at: Vector3) -> void:
	Sfx.play_3d(self, at, "thump", -4.0, 25.0, 1.3)
	var local := _local_player()
	if local != null and local.is_active() and local.global_position.distance_to(at) < 30.0:
		local.message.emit("車門開了一下又關上。月台上多了一件不知道是誰的行李。")


## Where the train's nose is along x right now.
func train_front() -> float:
	return -train_dir * END_X + train_dir * TRAIN_SPEED * _sweep_t


func _place_train() -> void:
	_train.position = Vector3(train_front(), RAIL_Y, _track_z(train_track))
	_rumble.position = _train.position + Vector3(0, 1.5, 0)
	for chunk in _chunks:
		chunk.visible = absf(chunk.global_position.x) + CHUNK / 2.0 <= END_X - 0.4
	var local := _local_player()
	if local != null and local.is_active():
		var near := Vector2(local.global_position.x - clampf(local.global_position.x, minf(train_front(), train_front() - train_dir * TRAIN_LEN),
			maxf(train_front(), train_front() - train_dir * TRAIN_LEN)), local.global_position.z - _train.position.z).length()
		if near < 8.0:
			local.add_shake(0.06 * (8.0 - near) / 8.0)


## True if a point is in the swept trench right now (only while the train passes).
func on_train_path(pos: Vector3) -> bool:
	if train_state != "passing":
		return false
	return absf(pos.z - _track_z(train_track)) < HIT_HALF_WIDTH and pos.y < RAIL_Y + 3.6 and _in_train(pos.x)


func _in_train(x: float) -> bool:
	var front := train_front()
	var back := front - train_dir * TRAIN_LEN
	return x >= minf(front, back) - 0.5 and x <= maxf(front, back) + 0.5


## Host: everything the train catches this pass gets hit once.
func _host_hits() -> void:
	var run := Run.instance
	for player in run.all_players():
		if not player.is_active() or _hit.has(player.name) or not on_train_path(player.global_position):
			continue
		_hit[player.name] = true
		var side := -1.0 if absf(player.global_position.z) < TRACK_Z else 1.0
		var push := Vector3(train_dir * 9.0, 4.5, signf(player.global_position.z) * side * 7.0)
		var owner_id := player.get_multiplayer_authority()
		if owner_id == multiplayer.get_unique_id():
			_train_hit(String(player.name), push)
		else:
			_train_hit.rpc_id(owner_id, String(player.name), push)
	for node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Node3D
		if monster == null or not is_instance_valid(monster) or _hit.has(monster.name) or not on_train_path(monster.global_position):
			continue
		_hit[monster.name] = true
		var from := Vector3(train_front(), 1.0, _track_z(train_track))
		if run.has_method("host_damage_monster"):
			run.call("host_damage_monster", monster, MONSTER_DAMAGE, {"train": 1.0}, from, null)
		else:
			TimeWarp.stun(monster, 8.0)


## Host -> the player's owner: the train hit you.
@rpc("any_peer", "call_local", "reliable")
func _train_hit(player_name: String, push: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and String(node.name) == player_name and node.is_multiplayer_authority() and node.is_active():
			var player: Player = node
			player.velocity += push
			player.add_shake(1.2)
			player.take_damage(HIT_DAMAGE, "被末班車撞飛了")
			if not player.is_dead:
				player.message.emit("末班車從你身上呼嘯而過！")
			return


func status_text() -> String:
	match train_state:
		"warning":
			return "末班車進站！%s軌道（%d 秒）——離開軌道" % [TRACK_NAMES[train_track], int(ceil(maxf(_warn_left, 0.0)))]
		"passing":
			return "末班車通過中！"
	return ""


func _on_objective() -> void:
	lift_called = true
	for node in _powered_lights:
		node.visible = true
	_lift_lamp.get_child(0).material_override = PS1Materials.get_material("concrete", Color(0.3, 1.0, 0.4) * 0.4, false,
		Vector2.ONE, Color(0.3, 1.0, 0.4))
	var tween := create_tween()
	tween.tween_property(_lift_cage, "position:y", 0.0, 6.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: Sfx.play_3d(self, Vector3(-38.5, 1.5, 0), "chime", 0.0, 40.0, 0.8))
	Sfx.play_3d(self, Vector3(-38.5, 3.0, 0), "creak", 2.0, 40.0, 0.6)
	# The next train won't be long.
	if multiplayer.is_server():
		next_train = minf(next_train, 35.0)


func _track_z(track: int) -> float:
	return TRACK_Z if track == 1 else -TRACK_Z


func _local_player() -> Player:
	if Run.instance == null or Run.instance.local_player == null or Run.instance.level != self:
		return null
	return Run.instance.local_player


# --- Layout --------------------------------------------------------------------------

## Back rooms, tunnels and old platforms behind both tracks.
func _plan_wings() -> void:
	var theme := {"clutter": "industrial", "floor": "concrete", "floor_tint": Color(0.55, 0.56, 0.54), "wall": "tile",
		"wall_tint": Color(0.78, 0.8, 0.72), "inner_wall": "concrete", "roof": "concrete", "roof_tint": Color(0.4, 0.42, 0.42),
		"light": Color(0.8, 1.0, 0.9), "light_energy": 0.75, "density": 1.0, "wall_density": 1.0, "clutter_chance": 0.35}
	var kits := [
		FacilityKits.kit("rail_tunnel", 4.0, {"shape": "corridor", "floor_tint": Color(0.42, 0.4, 0.38)}),
		FacilityKits.kit("flooded_tunnel", 1.0, {"shape": "corridor", "max_count": 3, "floor_tint": Color(0.3, 0.32, 0.3)}),
		FacilityKits.kit("side_platform", 2.0, {"shape": ["room", "hall"], "floor": "tile", "floor_tint": Color(0.6, 0.6, 0.55)}),
		FacilityKits.kit("staff_room", 1.5, {"floor": "tile", "floor_tint": Color(0.5, 0.55, 0.5), "lit": true}),
		FacilityKits.kit("collapsed_section", 1.5, {"shape": ["room", "hall"]}),
		FacilityKits.kit("flooded_tunnel", 0.6, {"shape": "hall", "max_count": 1, "floor_tint": Color(0.3, 0.32, 0.3)}),
		FacilityKits.kit("kiosk", 1.0, {"max_count": 3, "floor": "tile", "floor_tint": Color(0.7, 0.65, 0.55), "lit": true}),
		FacilityKits.kit("lost_and_found", 1.0, {"deep": true, "min_depth": 2, "floor": "tile", "floor_tint": Color(0.55, 0.5, 0.45)}),
		RoomKits.kit("restroom", 1.0, {"max_count": 2, "floor": "tile", "floor_tint": Color(0.75, 0.8, 0.78)}),
		RoomKits.kit("pump_room", 1.5), RoomKits.kit("storage", 1.5), RoomKits.kit("locker_room", 0.8, {"max_count": 2}),
		RoomKits.kit("office", 0.8, {"floor": "carpet", "floor_tint": Color(0.35, 0.38, 0.4)}),
	]
	var grid := _plan_sprawl("subway", Rect2(-END_X, -WALL_Z - 1.0, END_X * 2.0, WALL_Z * 2.0 + 2.0), _port_specs(), theme, kits)
	# A station is mostly long tunnels and passages with rooms off them.
	grid.shape_weights = {"corridor": 4.5, "room": 3.5, "hall": 1.4}
	grid.height = 5.2
	grid.hall_height = Vector2(6.0, 8.0)
	grid.dark_chance = 0.3


func _port_specs() -> Array:
	var specs := []
	for crossing in CROSSINGS:
		var side := 1.0 if crossing[0] == 1 else -1.0
		specs.append([Vector3(crossing[1], 0, side * (WALL_Z + 1.0)), Vector2i(0, int(side))])
	return specs


func _build_shell() -> void:
	var concrete := Color(0.5, 0.5, 0.48)
	# The island platform (lift room and signal box on its ends), in pieces.
	_floor_strip(-41.0, 41.0, -ISLAND_Z, ISLAND_Z, 0.0, -1.9, "concrete", Color(0.66, 0.64, 0.6), 1.0)
	# The track beds, and the walkways behind them.
	for side: float in [-1.0, 1.0]:
		var a := ISLAND_Z * side
		var b := BED_OUT_Z * side
		_floor_strip(-END_X, END_X, minf(a, b), maxf(a, b), RAIL_Y, -1.9, "concrete", Color(0.28, 0.27, 0.25), 1.0)
		_floor_strip(-END_X, END_X, minf(b, WALL_Z * side), maxf(b, WALL_Z * side), 0.0, -1.9, "concrete", concrete, 1.0)
		_wall_with_ports(Vector3(-END_X, 0, (WALL_Z + 0.5) * side), Vector3(END_X, 0, (WALL_Z + 0.5) * side), ROOF_Y,
			"tile", 1.0, Color(0.85, 0.86, 0.76), [], 1.0)
	# The black ends of the tunnels: the train comes out of there.
	for end: float in [-1.0, 1.0]:
		_box(Vector3(0.6, ROOF_Y + 1.9, WALL_Z * 2.0 + 2.0), Vector3(end * (END_X - 0.3), (ROOF_Y - 1.9) / 2.0, 0), "concrete",
			Vector3.ZERO, Layers.WORLD, Color(0.0, 0.0, 0.0))
		# The rock above the tunnels, and the solid core between them past the end rooms.
		var mid_x := end * (HALL_X + END_X - 0.6) / 2.0
		_roof(Vector3(END_X - 0.6 - HALL_X, ROOF_Y - TUNNEL_TOP + 1.0, WALL_Z * 2.0), Vector3(mid_x, (ROOF_Y + 1.0 + TUNNEL_TOP) / 2.0, 0),
			"concrete", Color(0.42, 0.42, 0.4))
		_box(Vector3(END_X - 0.6 - 41.0, TUNNEL_TOP + 1.9, ISLAND_Z * 2.0), Vector3(end * (41.0 + END_X - 0.6) / 2.0, (TUNNEL_TOP - 1.9) / 2.0, 0),
			"brick", Vector3.ZERO, Layers.WORLD, Color(0.4, 0.38, 0.36))
		# The portal face over the tunnel mouths, with the station's tiled band.
		_box(Vector3(0.3, ROOF_Y - TUNNEL_TOP, WALL_Z * 2.0), Vector3(end * (HALL_X + 0.15), (ROOF_Y + TUNNEL_TOP) / 2.0, 0), "tile",
			Vector3.ZERO, Layers.WORLD, Color(0.85, 0.86, 0.76), 1.0)
	# The hall roof, which the guardian's camera sees through.
	for i in 4:
		var x0 := -HALL_X + i * HALL_X / 2.0
		_roof(Vector3(HALL_X / 2.0, 1.0, WALL_Z * 2.0 + 2.0), Vector3(x0 + HALL_X / 4.0, ROOF_Y + 0.5, 0), "concrete", Color(0.35, 0.37, 0.36))


## A floor slab from y `bottom` up to `top`, cut every ~12 m along x.
func _floor_strip(x0: float, x1: float, z0: float, z1: float, top: float, bottom: float, texture: String, tint: Color,
		density: float) -> void:
	var pieces := maxi(1, ceili((x1 - x0) / 12.0))
	var step := (x1 - x0) / pieces
	for i in pieces:
		_box(Vector3(step, top - bottom, z1 - z0), Vector3(x0 + step * (i + 0.5), (top + bottom) / 2.0, (z0 + z1) / 2.0),
			texture, Vector3.ZERO, Layers.WORLD, tint, density)


func _build_tracks() -> void:
	for track in 2:
		var z := _track_z(track)
		var side := 1.0 if track == 1 else -1.0
		FacilityKits.rails(self, Vector3(-END_X + 0.6, RAIL_Y, z), Vector3(END_X - 0.6, RAIL_Y, z))
		# The live rail's yellow guard boards, on the walkway side.
		for i in 8:
			var x0 := -END_X + 0.6 + i * (END_X * 2.0 - 1.2) / 8.0
			_box(Vector3((END_X * 2.0 - 1.2) / 8.0 - 0.3, 0.06, 0.4), Vector3(x0 + (END_X * 2.0 - 1.2) / 16.0, RAIL_Y + 0.42,
				z + side * 1.6), "wood", Vector3.ZERO, 0, Color(0.75, 0.6, 0.12))
		# Warning lamps along the platform face: they blink when a train is coming on this line.
		for i in 12:
			var x := -44.0 + i * 8.0
			if absf(x) > HALL_X - 1.0:
				continue
			var lamp := _glow(Vector3(0.5, 0.12, 0.05), Vector3(x, -0.3, side * (ISLAND_Z + 0.03)), Color(1.0, 0.15, 0.05))
			lamp.visible = false
			_warn_lamps[track].append(lamp)
			var back := _glow(Vector3(0.5, 0.12, 0.05), Vector3(x + 4.0, -0.3, side * (BED_OUT_Z - 0.03)), Color(1.0, 0.15, 0.05))
			back.visible = false
			_warn_lamps[track].append(back)
		# Steps cut into the trench walls, so you can climb out anywhere quickly.
		for x: float in [-30.0, -12.0, 12.0, 30.0, 40.0, -40.0]:
			for face: float in [ISLAND_Z + 0.35, BED_OUT_Z - 0.35]:
				if absf(x) > HALL_X and face < TRACK_Z:
					continue
				_box(Vector3(1.4, 0.45, 0.7), Vector3(x, RAIL_Y + 0.225, side * face), "concrete", Vector3.ZERO, Layers.WORLD,
					Color(0.55, 0.5, 0.4))
	# Level crossings: timber decking across the trench, in line with a doorway.
	for crossing in CROSSINGS:
		var z := _track_z(crossing[0])
		var side := 1.0 if crossing[0] == 1 else -1.0
		_box(Vector3(4.0, -RAIL_Y, BED_OUT_Z - ISLAND_Z), Vector3(crossing[1], RAIL_Y / 2.0, z), "wood", Vector3.ZERO,
			Layers.WORLD, Color(0.42, 0.33, 0.24))
		for edge: float in [-2.0, 2.0]:
			_box(Vector3(0.12, 0.02, BED_OUT_Z - ISLAND_Z), Vector3(crossing[1] + edge * 0.95, 0.01, z), "concrete", Vector3.ZERO, 0,
				Color(0.95, 0.8, 0.15))
		FacilityKits.station_sign(self, Vector3(crossing[1], 3.6, side * (WALL_Z - 0.06)), 180.0 if side > 0 else 0.0, "維修通道", Color(0.12, 0.3, 0.2))


func _build_platform() -> void:
	# Yellow lines along both platform edges.
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var x0 := -41.0 + i * 82.0 / 6.0
			_box(Vector3(82.0 / 6.0 - 0.1, 0.02, 0.3), Vector3(x0 + 41.0 / 6.0, 0.01, side * (ISLAND_Z - 0.6)), "concrete", Vector3.ZERO, 0,
				Color(0.9, 0.75, 0.12))
	# Tiled columns down the middle; the ones at the west end hold up the ticket hall.
	for x: float in [-30.0, -22.0, 4.0, 14.0, 24.0]:
		_box(Vector3(0.9, ROOF_Y, 0.9), Vector3(x, ROOF_Y / 2.0, 0), "tile", Vector3.ZERO, Layers.WORLD, Color(0.85, 0.86, 0.76), 1.5)
		_box(Vector3(0.95, 0.5, 0.95), Vector3(x, 1.6, 0), "tile", Vector3.ZERO, 0, Color(0.2, 0.45, 0.35), 2.5)
	# Benches facing the tracks, bins, a vending machine with a dying light.
	for spec in [[9.0, 1.0], [19.0, -1.0], [29.0, 1.0], [-26.0, -1.0], [-1.0, 1.0], [-18.0, 1.0]]:
		FacilityKits.bench(self, Vector3(spec[0], 0, spec[1] * 3.4), 0.0 if spec[1] > 0 else 180.0)
	Props.vending(self, Vector3(4.0, 0, -1.0), 180.0, Color(0.6, 1.0, 0.8))
	Props.vending(self, Vector3(24.0, 0, 1.0), 0.0, Color(1.0, 0.85, 0.5))
	for pos in [Vector3(14.0, 0, 1.3), Vector3(-22.0, 0, -1.3), Vector3(31.0, 0, -3.5)]:
		Props.barrel(self, pos, Color(0.3, 0.38, 0.35))
	# Station name boards on the walls across the tracks, and over the platform.
	for side: float in [-1.0, 1.0]:
		var yaw := 180.0 if side > 0 else 0.0
		for x: float in [-26.0, -10.0, 10.0, 28.0]:
			if CROSSINGS.any(func(c: Array) -> bool: return absf(c[1] - x) < 3.0 and (c[0] == 1) == (side > 0)):
				continue
			FacilityKits.station_sign(self, Vector3(x, 2.6, side * (WALL_Z - 0.06)), yaw, "永夜站", Color(0.1, 0.32, 0.22), 4.2, false)
			_powered_lights.append(_glow(Vector3(4.0, 0.05, 0.05), Vector3(x, 3.0, side * (WALL_Z - 0.12)), Color(0.8, 1.0, 0.85)))
			_powered_lights[-1].visible = false
		# The green tile band along the walls.
		for i in 8:
			var x0 := -END_X + i * END_X / 4.0
			_box(Vector3(END_X / 4.0 - 0.05, 0.35, 0.03), Vector3(x0 + END_X / 8.0, 1.35, side * (WALL_Z - 0.02)), "tile", Vector3.ZERO, 0,
				Color(0.18, 0.42, 0.32), 2.5)
		for spec in [[-6.0, 0], [16.0, 3], [-30.0, 5], [36.0, 1], [-38.0, 7]]:
			FacilityKits.graffiti(self, Vector3(spec[0], 1.9, side * (WALL_Z - 0.04)), yaw, FacilityKits.GRAFFITI[(spec[1] + int(side + 1)) % 10],
				Color(0.85, 0.15, 0.12) if side > 0 else Color(0.25, 0.75, 0.9), 1.4)
	for spec in [[10.0, 1.0], [1.0, -1.0], [20.0, -1.0]]:
		FacilityKits.station_sign(self, Vector3(spec[0], 3.4, spec[1] * 3.0), 90.0 if spec[1] > 0 else -90.0,
			"往 終點  →" if spec[1] > 0 else "←  往 舊城", Color(0.12, 0.25, 0.45))
	# The timetable by the escalators: only one train is listed.
	FacilityKits.station_sign(self, Vector3(-3.0, 2.2, 2.9), 90.0, "末班車 23:59", Color(0.45, 0.1, 0.08), 2.6)
	FacilityKits.station_sign(self, Vector3(-3.0, 2.2, -2.9), 90.0, "請勿跨越黃線", Color(0.5, 0.42, 0.05), 2.6)


func _build_concourse() -> void:
	var y := CONC_Y
	var width := CONC_X.y - CONC_X.x
	_box(Vector3(width, 0.3, WALL_Z * 2.0), Vector3((CONC_X.x + CONC_X.y) / 2.0, y - 0.15, 0), "tile", Vector3.ZERO, Layers.WALKWAY,
		Color(0.7, 0.68, 0.62), 1.5)
	_box(Vector3(0.2, 0.6, WALL_Z * 2.0), Vector3(CONC_X.y - 0.1, y - 0.6, 0), "tile", Vector3.ZERO, 0, Color(0.2, 0.42, 0.32))
	# Glass-and-brass railing along the edge over the platform, open where the escalators land.
	for span in [Vector2(-WALL_Z, -2.3), Vector2(2.3, WALL_Z)]:
		_box(Vector3(0.1, 1.0, span.y - span.x), Vector3(CONC_X.y - 0.1, y + 0.5, (span.x + span.y) / 2.0), "brass", Vector3.ZERO,
			Layers.WALKWAY, Color(0.75, 0.72, 0.6))
	# Two dead escalators down to the platform, too narrow for anything big.
	for z: float in [-1.45, 1.45]:
		_escalator(Vector3(-4.0, 0, z), Vector3(CONC_X.y, y, z))
	_box(Vector3(0.5, 2.4, 0.5), Vector3(-10.0, 1.2, 0), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.35, 0.36, 0.38))
	FacilityKits.station_sign(self, Vector3(CONC_X.y - 0.2, y + 2.2, 0), 90.0, "往月台", Color(0.1, 0.32, 0.22), 2.4)
	# The fare gates: a row of turnstile cabinets across the hall. People slip between
	# them; nothing big does.
	var gate_x := -22.0
	var z := -WALL_Z + 0.6
	while z < WALL_Z - 0.4:
		_prop([[LowPoly.chamfer_box(Vector3(1.2, 1.0, 0.3), 0.04), "panel", Color(0.6, 0.62, 0.58), LowPoly.at(Vector3(0, 0.5, 0))],
			[LowPoly.chamfer_box(Vector3(1.24, 0.05, 0.34), 0.02), "brass", Color(0.8, 0.78, 0.7), LowPoly.at(Vector3(0, 1.02, 0))],
			[LowPoly.chamfer_box(Vector3(0.12, 0.04, 0.12), 0.01), "concrete", Color(0.2, 0.6, 0.25), LowPoly.at(Vector3(0.35, 1.06, 0)),
				Color(0.05, 0.4, 0.1)],
			[LowPoly.prism(5, 0.025, 0.025, 0.55), "brass", Color(0.85, 0.85, 0.8), LowPoly.at(Vector3(0, 0.85, 0.42), Vector3(90, 0, 0))]],
			Vector3(gate_x, y, z), 0.0, Vector3(1.2, 1.05, 0.3), Vector3(INF, INF, INF), Layers.WALKWAY)
		z += 1.2
	FacilityKits.station_sign(self, Vector3(gate_x - 0.1, y + 2.8, 5.0), -90.0, "售票處 · 出口", Color(0.12, 0.25, 0.45), 4.0)
	FacilityKits.station_sign(self, Vector3(gate_x + 0.1, y + 2.8, 5.0), 90.0, "往 月台", Color(0.1, 0.32, 0.22), 3.0)
	# Ticket machines against the south wall, still glowing.
	for x: float in [-32.5, -30.5, -28.5, -26.5]:
		Props.vending(self, Vector3(x, y, -WALL_Z + 0.5), 0.0, Color(0.5, 0.75, 1.0))
	FacilityKits.station_sign(self, Vector3(-29.5, y + 2.7, -WALL_Z + 0.06), 0.0, "自動售票機", Color(0.12, 0.25, 0.45), 4.0)
	# The station office: a booth with a counter window and a narrow door.
	var ox := Vector2(-34.0, -26.0)
	var oz := 8.0
	_wall(Vector3(ox.x, y, oz), Vector3(ox.y, y, oz), 3.0, "panel", [[6.5, 1.0, 2.2]], 0.15, Color(0.5, 0.55, 0.5))
	_wall(Vector3(ox.y, y, oz), Vector3(ox.y, y, WALL_Z), 3.0, "panel", [], 0.15, Color(0.5, 0.55, 0.5))
	_glow(Vector3(3.0, 0.9, 0.04), Vector3(-30.0, y + 1.6, oz - 0.09), Color(0.35, 0.45, 0.4))
	_box(Vector3(8.0, 0.1, 5.0), Vector3(-30.0, y + 3.05, (oz + WALL_Z) / 2.0), "panel", Vector3.ZERO, 0, Color(0.4, 0.42, 0.4))
	_add_gate(Vector3(-27.5, y + 1.1, oz), Vector3(1.0, 2.2, 0.15))
	Props.desk(self, Vector3(-30.5, y, WALL_Z - 1.4), 180.0, Color(0.45, 0.42, 0.38))
	Props.tv(self, Vector3(-31.2, y + 0.78, WALL_Z - 1.4), 180.0, true)
	Props.chair(self, Vector3(-30.5, y, WALL_Z - 2.4), 0.0, Color(0.3, 0.35, 0.45))
	_add_locker(Vector3(-33.5, y, 10.5), PI / 2.0)
	_light(Vector3(-30.0, y + 2.6, 10.5), Color(1.0, 0.85, 0.6), 0.6, 6.0, true)
	FacilityKits.station_sign(self, Vector3(-30.0, y + 2.4, oz - 0.1), 180.0, "站務室", Color(0.45, 0.1, 0.08), 2.4)
	# The way out to the street: a shutter, chained.
	_box(Vector3(0.1, 3.0, 4.0), Vector3(-HALL_X + 0.1, y + 1.5, -3.0), "rust_metal", Vector3.ZERO, Layers.WALKWAY, Color(0.5, 0.5, 0.5))
	for k in 6:
		_box(Vector3(0.12, 0.05, 4.0), Vector3(-HALL_X + 0.2, y + 0.3 + k * 0.5, -3.0), "rust_metal", Vector3.ZERO, 0, Color(0.35, 0.35, 0.35))
	_box(Vector3(0.1, 0.1, 2.2), Vector3(-HALL_X + 0.3, y + 1.2, -3.0), "rust_metal", Vector3(25, 0, 0), 0, Color(0.6, 0.55, 0.4))
	FacilityKits.station_sign(self, Vector3(-HALL_X + 0.2, y + 3.5, -3.0), 90.0, "出口 EXIT", Color(0.15, 0.4, 0.15), 3.0)
	FacilityKits.graffiti(self, Vector3(-HALL_X + 0.2, y + 1.6, -3.0), 90.0, "出不去", Color(0.85, 0.15, 0.12), 1.6)
	FacilityKits.graffiti(self, Vector3(-24.0, y + 1.8, -WALL_Z + 0.04), 0.0, "他們還在月台上等", Color(0.9, 0.85, 0.2), 1.0)
	FacilityKits.bench(self, Vector3(-18.5, y, 11.8), 180.0)
	FacilityKits.bench(self, Vector3(-18.5, y, -11.8), 0.0)


func _escalator(bottom: Vector3, top: Vector3) -> void:
	var run_x := top.x - bottom.x
	var length := Vector2(run_x, top.y - bottom.y).length()
	var angle := rad_to_deg(atan2(top.y - bottom.y, absf(run_x))) * signf(run_x)
	var mid := (bottom + top) / 2.0 - Vector3(0, 0.17, 0)
	_box(Vector3(length, 0.3, 1.3), mid, "grate", Vector3(0, 0, angle), Layers.WALKWAY, Color(0.62, 0.62, 0.66), 1.5)
	# Step lines, and the balustrades either side.
	var dir := Vector3(run_x, top.y - bottom.y, 0).normalized()
	for i in int(length / 0.4):
		_box(Vector3(0.04, 0.02, 1.25), bottom + dir * (0.2 + i * 0.4) + Vector3(0, 0.0, 0), "rust_metal", Vector3(0, 0, angle), 0,
			Color(0.85, 0.75, 0.2))
	for side: float in [-0.75, 0.75]:
		_box(Vector3(length, 1.0, 0.12), mid + Vector3(0, 0.6, side), "panel", Vector3(0, 0, angle), Layers.WALKWAY, Color(0.32, 0.33, 0.35))
		_box(Vector3(length, 0.06, 0.16), mid + Vector3(0, 1.12, side), "rust_metal", Vector3(0, 0, angle), 0, Color(0.1, 0.1, 0.1))


func _build_signal_box() -> void:
	var x0 := HALL_X
	var x1 := 41.0
	var h := TUNNEL_TOP
	# A narrow door from the platform, windows over both lines.
	_wall(Vector3(x0, 0, -ISLAND_Z), Vector3(x0, 0, ISLAND_Z), h, "brick", [[ISLAND_Z, 1.1, 2.2]], 0.3, Color(0.6, 0.5, 0.45))
	_add_gate(Vector3(x0, 1.1, 0), Vector3(0.15, 2.2, 1.1))
	for side: float in [-1.0, 1.0]:
		var z := side * (ISLAND_Z - 0.15)
		_box(Vector3(x1 - x0, 1.1, 0.3), Vector3((x0 + x1) / 2.0, 0.55, z), "brick", Vector3.ZERO, Layers.WORLD, Color(0.6, 0.5, 0.45))
		_box(Vector3(x1 - x0, h - 2.3, 0.3), Vector3((x0 + x1) / 2.0, (h + 2.3) / 2.0, z), "brick", Vector3.ZERO, Layers.WORLD, Color(0.6, 0.5, 0.45))
		for x: float in [x0 + 0.2, (x0 + x1) / 2.0, x1 - 0.2]:
			_box(Vector3(0.2, 1.2, 0.3), Vector3(x, 1.7, z), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.3, 0.3, 0.3))
	_box(Vector3(x1 - x0, 0.3, ISLAND_Z * 2.0), Vector3((x0 + x1) / 2.0, h - 0.15, 0), "concrete", Vector3.ZERO, 0, Color(0.35, 0.36, 0.35))
	# The lever frame and the track diagram above it.
	var diagram := _glow(Vector3(0.05, 1.2, 5.0), Vector3(x1 - 0.05, 2.4, 0), Color(0.12, 0.16, 0.14))
	diagram.scale = Vector3.ONE
	for z: float in [-TRACK_Z / 4.0, TRACK_Z / 4.0]:
		_glow(Vector3(0.04, 0.05, 4.6), Vector3(x1 - 0.09, 2.4 + z * 0.15, 0), Color(0.9, 0.9, 0.85))
	for i in 6:
		_glow(Vector3(0.04, 0.09, 0.09), Vector3(x1 - 0.1, 2.25 + (i % 2) * 0.32, -2.0 + i * 0.8),
			Color(1.0, 0.15, 0.1) if i % 3 != 1 else Color(0.2, 1.0, 0.3))
	for i in 7:
		_box(Vector3(0.08, 1.0, 0.08), Vector3(x1 - 0.8, 0.9, -2.4 + i * 0.5), "rust_metal", Vector3(0, 0, -15 + (i % 3) * 15), 0,
			Color(0.75, 0.2, 0.15) if i % 2 == 0 else Color(0.2, 0.3, 0.6))
	_box(Vector3(0.6, 0.4, 4.2), Vector3(x1 - 0.8, 0.2, 0), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.3, 0.3, 0.3))
	_add_lever(Vector3(x1 - 1.6, 0, 2.9), -PI / 2.0, "[E] 拉下號誌室總閘（恢復車站供電、叫維修電梯下來，但整座車站都會聽到）")
	Props.desk(self, Vector3(36.5, 0, -ISLAND_Z + 1.4), 0.0, Color(0.45, 0.42, 0.38))
	Props.chair(self, Vector3(36.5, 0, -ISLAND_Z + 2.4), 180.0, Color(0.4, 0.3, 0.25))
	_add_locker(Vector3(x0 + 0.6, 0, 4.0), PI / 2.0)
	FacilityKits.station_sign(self, Vector3(x0 - 0.17, 2.9, 0), -90.0, "號誌室", Color(0.45, 0.1, 0.08), 2.0)
	_light(Vector3(38.0, h - 0.6, 0), Color(0.6, 1.0, 0.7), 0.55, 7.0, true)


func _build_lift() -> void:
	var x0 := -41.0
	var x1 := -HALL_X
	var h := TUNNEL_TOP
	_wall(Vector3(x1, 0, -ISLAND_Z), Vector3(x1, 0, ISLAND_Z), h, "brick", [[ISLAND_Z, 3.4, 3.2]], 0.3, Color(0.55, 0.5, 0.48))
	_add_gate(Vector3(x1, 1.6, 0), Vector3(0.15, 3.2, 3.4))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(x1 - x0, h, 0.3), Vector3((x0 + x1) / 2.0, h / 2.0, side * (ISLAND_Z - 0.15)), "brick", Vector3.ZERO,
			Layers.WORLD, Color(0.55, 0.5, 0.48))
	_box(Vector3(x1 - x0, 0.3, ISLAND_Z * 2.0), Vector3((x0 + x1) / 2.0, h - 0.15, 0), "concrete", Vector3.ZERO, 0, Color(0.35, 0.36, 0.35))
	# The maintenance lift: a cage in a shaft. Its car sits up the shaft until the power is back.
	var centre := Vector3(-38.5, 0, 0)
	_box(Vector3(3.2, 0.1, 3.2), centre + Vector3(0, 0.05, 0), "grate", Vector3.ZERO, 0, Color(0.7, 1.0, 0.8))
	for corner in [Vector3(1.6, 0, 1.6), Vector3(-1.6, 0, 1.6), Vector3(1.6, 0, -1.6), Vector3(-1.6, 0, -1.6)]:
		_box(Vector3(0.15, h, 0.15), centre + corner + Vector3(0, h / 2.0, 0), "rust_metal", Vector3.ZERO, Layers.WORLD, Color(0.55, 0.5, 0.2))
	_lift_cage = Node3D.new()
	_lift_cage.position.y = h - 0.4
	add_child(_lift_cage)
	var cage := LowPoly.merge([[LowPoly.chamfer_box(Vector3(3.0, 0.15, 3.0), 0.03), LowPoly.at(Vector3(0, 2.6, 0))],
		[LowPoly.chamfer_box(Vector3(3.0, 0.1, 3.0), 0.03), LowPoly.at(Vector3(0, 0.05, 0))]])
	_lift_cage.add_child(LowPoly.instance(cage, "grate", Color(0.6, 0.6, 0.55), LowPoly.at(centre)))
	_lift_lamp = _glow(Vector3(0.05, 0.3, 0.6), Vector3(x1 + 0.17, 3.6, 0), Color(1.0, 0.15, 0.1))
	FacilityKits.station_sign(self, Vector3(x1 + 0.17, 4.05, 0), 90.0, "維修電梯", Color(0.45, 0.35, 0.05), 2.4)
	_add_extraction(centre)
	_add_locker(Vector3(x0 + 0.5, 0, -4.0), PI / 2.0)
	_add_locker(Vector3(x0 + 0.5, 0, 4.0), PI / 2.0)
	Props.crate(self, Vector3(-36.0, 0, -4.6), 10.0, Vector3(1.0, 0.8, 0.8), Color(0.5, 0.45, 0.35))
	_light(Vector3(-37.0, h - 0.6, 0), Color(1.0, 0.8, 0.5), 0.45, 7.0, true)
	var lit := _light(Vector3(-38.5, 2.8, 0), Color(0.7, 1.0, 0.8), 0.9, 7.0, false)
	lit.visible = false
	_powered_lights.append(lit)


func _build_lights() -> void:
	# Fluorescent tubes over the platform; the ones under the ticket hall hang lower.
	var i := 0
	for x: float in [-31.0, -25.0, -19.0, -9.0, -1.0, 7.0, 15.0, 23.0, 31.0]:
		var under := x < CONC_X.y
		var z := 2.5 if i % 2 == 0 else -2.5
		FacilityKits.tube_light(self, Vector3(x, 4.3 if under else 5.2, z), 0.0, 1.1 if under else 1.6, 11.0 if under else 14.0, i % 3 != 1)
		i += 1
	# Dim lamps over the walkways behind the tracks.
	for side: float in [-1.0, 1.0]:
		for x: float in [-28.0, -12.0, 4.0, 20.0]:
			var x2 := x + (6.0 if side > 0 else 0.0)
			FacilityKits.tube_light(self, Vector3(x2, 3.6, side * (WALL_Z - 0.5)), 0.0, 0.55, 8.0, true, Color(1.0, 0.88, 0.6))
		# Red signal lamps deep in each tunnel.
		for end: float in [-1.0, 1.0]:
			_glow(Vector3(0.2, 0.2, 0.08), Vector3(end * 44.0, 2.4, side * (BED_OUT_Z - 0.1)), Color(1.0, 0.1, 0.05))
			_light(Vector3(end * 43.5, 2.4, side * (BED_OUT_Z - 0.6)), Color(1.0, 0.15, 0.08), 0.5, 6.0, false)
	# The ticket hall.
	for spec in [Vector3(-31.0, 0, -5.0), Vector3(-25.0, 0, 4.0), Vector3(-18.5, 0, -5.0), Vector3(-18.5, 0, 6.0)]:
		FacilityKits.tube_light(self, Vector3(spec.x, ROOF_Y - 0.6, spec.z), 90.0, 0.8, 11.0, spec.z > 0.0)
	# Strip lights that only come on when the power is restored.
	for x: float in [-12.0, 0.0, 12.0, 24.0]:
		var light := _light(Vector3(x, 7.0, 0), Color(0.85, 1.0, 0.92), 1.0, 16.0, false)
		light.visible = false
		_powered_lights.append(light)
		var strip := _glow(Vector3(9.0, 0.08, 0.3), Vector3(x, ROOF_Y - 0.05, 0), Color(0.85, 1.0, 0.9))
		strip.visible = false
		_powered_lights.append(strip)


func _build_train() -> void:
	_train = Node3D.new()
	_train.name = "LastTrain"
	_train.visible = false
	add_child(_train)
	var body := Color(0.45, 0.52, 0.5)
	var window := Color(0.55, 0.9, 0.85)
	for c in CHUNKS:
		var chunk := Node3D.new()
		chunk.position.x = -(c + 0.5) * CHUNK
		_train.add_child(chunk)
		_chunks.append(chunk)
		var car_end := c % 3 == 2
		var length := CHUNK - (0.6 if car_end else 0.0)
		var offset := -0.3 if car_end else 0.0
		var shell := [[LowPoly.chamfer_box(Vector3(length, 2.9, 2.9), 0.12), LowPoly.at(Vector3(offset, 1.95, 0))],
			[LowPoly.chamfer_box(Vector3(length, 0.5, 2.5), 0.05), LowPoly.at(Vector3(offset, 0.4, 0))]]
		chunk.add_child(LowPoly.instance(LowPoly.merge(shell), "panel", body, Transform3D.IDENTITY, Color(0.08, 0.13, 0.12)))
		var stripes := [[LowPoly.chamfer_box(Vector3(length - 0.4, 0.75, 2.96), 0.02), LowPoly.at(Vector3(offset, 2.25, 0))]]
		chunk.add_child(LowPoly.instance(LowPoly.merge(stripes), "panel", window * 0.4, Transform3D.IDENTITY, window * 0.75))
		# Passengers in the windows, all facing forward.
		var riders := []
		for k in 3:
			var rx := offset - length / 2.0 + 0.8 + k * (length - 1.6) / 2.0
			for side: float in [-1.0, 1.0]:
				if (c * 3 + k + int(side)) % 4 == 0:
					continue
				riders.append([LowPoly.chamfer_box(Vector3(0.45, 0.5, 0.05), 0.08), LowPoly.at(Vector3(rx, 2.1, side * 1.49))])
				riders.append([LowPoly.chamfer_box(Vector3(0.24, 0.26, 0.05), 0.08), LowPoly.at(Vector3(rx, 2.5, side * 1.49))])
		if not riders.is_empty():
			chunk.add_child(LowPoly.instance(LowPoly.merge(riders), "panel", Color(0.02, 0.03, 0.03)))
		if c == 0:
			var nose := [[LowPoly.chamfer_box(Vector3(0.2, 1.2, 2.4), 0.05), LowPoly.at(Vector3(CHUNK / 2.0 + 0.05, 2.3, 0))]]
			chunk.add_child(LowPoly.instance(LowPoly.merge(nose), "panel", window * 0.2, Transform3D.IDENTITY, window * 0.3))
			var lamps := [[LowPoly.chamfer_box(Vector3(0.1, 0.3, 0.4), 0.03), LowPoly.at(Vector3(CHUNK / 2.0 + 0.06, 0.9, 0.9))],
				[LowPoly.chamfer_box(Vector3(0.1, 0.3, 0.4), 0.03), LowPoly.at(Vector3(CHUNK / 2.0 + 0.06, 0.9, -0.9))]]
			chunk.add_child(LowPoly.instance(LowPoly.merge(lamps), "concrete", Color.WHITE, Transform3D.IDENTITY, Color(1.0, 0.98, 0.85)))
			var label := Label3D.new()
			label.text = "末班車"
			label.font_size = 128
			label.pixel_size = 0.0045
			label.modulate = Color(1.0, 0.55, 0.2)
			label.shaded = false
			label.double_sided = false
			label.position = Vector3(CHUNK / 2.0 + 0.17, 3.15, 0)
			label.rotation.y = PI / 2.0
			chunk.add_child(label)
			_headlight = OmniLight3D.new()
			_headlight.light_color = Color(1.0, 0.95, 0.8)
			_headlight.light_energy = 4.0
			_headlight.omni_range = 16.0
			_headlight.position = Vector3(CHUNK / 2.0 + 2.5, 1.5, 0)
			chunk.add_child(_headlight)
			for k in 3:
				var cabin := OmniLight3D.new()
				cabin.light_color = window
				cabin.light_energy = 1.6
				cabin.omni_range = 8.0
				cabin.position = Vector3(-CHUNK * (1.0 + k * 3.0), 2.2, 0)
				chunk.add_child(cabin)
		if c == CHUNKS - 1:
			var tail := [[LowPoly.chamfer_box(Vector3(0.1, 0.25, 0.3), 0.03), LowPoly.at(Vector3(-CHUNK / 2.0 - 0.05, 0.9, 0.9))],
				[LowPoly.chamfer_box(Vector3(0.1, 0.25, 0.3), 0.03), LowPoly.at(Vector3(-CHUNK / 2.0 - 0.05, 0.9, -0.9))]]
			chunk.add_child(LowPoly.instance(LowPoly.merge(tail), "concrete", Color(1, 0.2, 0.1), Transform3D.IDENTITY, Color(1.0, 0.1, 0.05)))
	_beam = OmniLight3D.new()
	_beam.light_color = Color(1.0, 0.95, 0.8)
	_beam.omni_range = 22.0
	_beam.omni_attenuation = 1.2
	_beam.visible = false
	add_child(_beam)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = Sfx.looped("rumble")
	_rumble.max_distance = 120.0
	_rumble.unit_size = 12.0
	add_child(_rumble)
