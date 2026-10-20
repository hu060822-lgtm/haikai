class_name MidnightMall
extends GameMap
## 午夜購物中心. A dead 90s mall after closing: a two-storey atrium with a dry fountain,
## two stopped escalators crossing it, shops behind roll-down shutters on both sides and
## a staff corridor at the back that leads to the loading dock. The open atrium floor is
## the big monsters' ground; shops and the upper floor are where scavengers hide.
## The mall still half-runs itself: shutters drop on their own now and then, and the PA
## chimes out announcements that carry through the whole building.

const UPPER_Y := 5.0
const ROOF_Y := 10.0
const SHOP_DEPTH := 7.0
## Ground-floor shops on each side: z ranges.
const SHOPS := [Vector2(-17.8, -8.0), Vector2(-6.0, 4.0), Vector2(6.0, 16.0)]
const SHUTTER_INTERVAL := Vector2(25.0, 45.0)
const SHUTTER_TIME := 10.0
const ANNOUNCE_INTERVAL := Vector2(40.0, 75.0)
const ANNOUNCE_RADIUS := 26.0

const LOOT_SPOTS := [
	# Ground-floor shops.
	Vector3(-15.0, 0.95, -15.0), Vector3(-13.0, 0.2, -10.0), Vector3(-16.5, 0.2, -2.0),
	Vector3(-13.5, 0.2, 1.0), Vector3(-15.0, 0.2, 9.0), Vector3(-12.5, 0.2, 14.0),
	Vector3(15.0, 0.95, -15.0), Vector3(13.0, 0.2, -10.5), Vector3(16.0, 0.2, -3.0),
	Vector3(13.5, 0.2, 0.5), Vector3(15.5, 0.2, 9.5), Vector3(12.5, 0.2, 13.5),
	# Atrium, lobby and staff corridor.
	Vector3(1.5, 0.8, 0.0), Vector3(-5.0, 0.2, 5.0), Vector3(5.5, 0.2, -4.0),
	Vector3(-3.0, 0.2, 19.0), Vector3(6.0, 0.2, 21.5), Vector3(-15.0, 0.2, -22.5),
	Vector3(-4.0, 0.2, -21.0), Vector3(16.0, 0.2, -22.0),
	# Upper floor: arcade, toy shop, food court, electrical room.
	Vector3(-16.0, 5.2, -16.0), Vector3(-13.0, 5.2, -7.0), Vector3(-15.5, 5.2, 4.0),
	Vector3(-12.5, 5.2, 12.0), Vector3(10.0, 5.95, -2.0), Vector3(14.0, 5.95, 6.0),
	Vector3(14.0, 5.95, 14.0), Vector3(16.5, 5.2, -11.5), Vector3(-3.0, 5.2, 18.0),
	Vector3(4.0, 5.2, -15.0),
]

const PATROL_POINTS := [
	Vector3(0, 0, -6), Vector3(-3.5, 0, 3), Vector3(5, 0, 2), Vector3(0, 0, 7),
	Vector3(-9, 0, -12), Vector3(9, 0, -12), Vector3(-9, 0, 10), Vector3(9, 0, 10),
	Vector3(0, 0, 18), Vector3(-10, 0, 21), Vector3(10, 0, 21), Vector3(0, 0, -21),
	Vector3(-12, 0, -21), Vector3(8, 0, -21),
]

const ANNOUNCEMENTS := [
	"「親愛的顧客您好，本商場已經打烊。請儘速離開。」",
	"「走失的小朋友請到一樓服務台…你的家人在等你。」",
	"「今日特價：所有商品一律免費。數量有限，帶得走就是你的。」",
	"「請勿奔跑。請勿奔跑。請勿奔跑。」",
	"「感謝您的光臨。我們一直都在。」",
]

var _speakers: Array[Vector3] = []
var _shutter_timer := 30.0
var _announce_timer := 50.0
var _auto_closed := {}  # gate index -> seconds until the mall rolls it back up
var _neon: Array[Node3D] = []


func build() -> void:
	map_name = "午夜購物中心"
	intro = "打烊後的商場。裝卸區的貨梯要先在二樓配電室恢復供電。"
	objective_text = "到二樓配電室恢復供電（東北角）"
	exit_text = "到後場裝卸區的貨梯撤離"
	objective_message = "配電室的閘刀推上去了。招牌一盞盞亮起來…商場醒了。"
	blocked_message = "貨梯沒電。先去二樓配電室恢復供電。"
	exit_name = "貨梯"
	warning_message = "廣播：「本商場將於兩分鐘後完全封閉。」"
	timeout_cause = "鐵捲門全部落下，你被關在商場裡了"
	player_spawn = Vector3(0.0, 0.1, 21.0)
	monster_spawn = Vector3(0.0, 0.1, -4.0)
	patrol_points.assign(PATROL_POINTS)
	loot_spots.assign(LOOT_SPOTS)
	loot_count = Vector2i(15, 19)
	bounds = AABB(Vector3(-17.8, -0.5, -23.8), Vector3(35.6, 11.0, 47.6))
	overview_height = ROOF_Y - 0.5
	_speakers.assign([Vector3(0, 8, 0), Vector3(-12, 4, -21), Vector3(0, 4, 20), Vector3(13, 8, 4)])
	_environment(Color(0.015, 0.012, 0.02), Color(0.32, 0.27, 0.38), 0.55, Color(0.06, 0.045, 0.07), 0.04, "drone", -18.0)
	_build_shell()
	_build_atrium()
	_build_upper_floor()
	_build_escalators()
	_build_shops()
	_build_upper_rooms()
	_build_staff_area()
	_build_lights()


func _process(delta: float) -> void:
	super(delta)
	if not multiplayer.is_server() or Run.instance == null:
		return
	_tick_shutters(delta)
	_announce_timer -= delta
	if _announce_timer <= 0.0:
		_announce_timer = rng.randf_range(ANNOUNCE_INTERVAL.x, ANNOUNCE_INTERVAL.y)
		var speaker := rng.randi_range(0, _speakers.size() - 1)
		_announce.rpc(speaker, rng.randi_range(0, ANNOUNCEMENTS.size() - 1))
		# Loud enough to pull monsters toward that speaker.
		GameNoise.emit(get_tree(), Vector3(_speakers[speaker].x, 0.5, _speakers[speaker].z),
			ANNOUNCE_RADIUS, GameNoise.Kind.MACHINE)


## Host: the mall drops a shop shutter by itself now and then, then rolls it back up.
func _tick_shutters(delta: float) -> void:
	var run := Run.instance
	for index in _auto_closed.keys():
		_auto_closed[index] -= delta
		if _auto_closed[index] <= 0.0:
			_auto_closed.erase(index)
			if gates[index].closed:
				run.host_set_gate(index, false)
	_shutter_timer -= delta
	if _shutter_timer > 0.0 or not power_on:
		return
	_shutter_timer = rng.randf_range(SHUTTER_INTERVAL.x, SHUTTER_INTERVAL.y)
	var index := rng.randi_range(0, SHOPS.size() * 2 - 1)  # shop shutters come first
	if not gates[index].closed and not gates[index].is_blocked(run.all_players()):
		_auto_closed[index] = SHUTTER_TIME
		run.host_set_gate(index, true)


@rpc("authority", "call_local", "reliable")
func _announce(speaker: int, line: int) -> void:
	var pos := _speakers[speaker]
	Sfx.play_3d(self, pos, "chime", 4.0, 70.0, 1.0)
	var local := Run.instance.local_player if Run.instance != null else null
	if local != null and local.is_active():
		local.message.emit("廣播：" + ANNOUNCEMENTS[line])


func _on_objective() -> void:
	for board in _neon:
		board.visible = true


func _build_shell() -> void:
	_box(Vector3(36, 1, 48), Vector3(0, -0.5, 0), "tile", Vector3.ZERO, Layers.WORLD, Color(0.85, 0.82, 0.78), 1.5)
	_box(Vector3(36, 1, 48), Vector3(0, ROOF_Y + 0.5, 0), "panel", Vector3.ZERO, Layers.WORLD, Color(0.5, 0.48, 0.5))
	_box(Vector3(36, ROOF_Y, 1), Vector3(0, ROOF_Y / 2.0, -24.5), "concrete")
	_box(Vector3(1, ROOF_Y, 48), Vector3(18.5, ROOF_Y / 2.0, 0), "concrete", Vector3.ZERO, Layers.WORLD, Color(0.8, 0.75, 0.8))
	_box(Vector3(1, ROOF_Y, 48), Vector3(-18.5, ROOF_Y / 2.0, 0), "concrete", Vector3.ZERO, Layers.WORLD, Color(0.8, 0.75, 0.8))
	# Main entrance: glass doors chained shut, with the dark car park behind them.
	_box(Vector3(36, ROOF_Y, 1), Vector3(0, ROOF_Y / 2.0, 24.5), "concrete", Vector3.ZERO, Layers.WORLD, Color(0.8, 0.75, 0.8))
	for x in [-3.0, -1.0, 1.0, 3.0]:
		_box(Vector3(1.9, 3.0, 0.08), Vector3(x, 1.5, 23.9), "panel", Vector3.ZERO, 0, Color(0.25, 0.35, 0.4))
	_box(Vector3(0.1, 0.1, 0.12), Vector3(0, 1.1, 23.8), "rust_metal", Vector3(0, 0, 10), 0)
	_box(Vector3(4.2, 0.1, 0.12), Vector3(0, 1.1, 23.8), "rust_metal", Vector3(0, 0, -6), 0)


func _build_atrium() -> void:
	# Dry fountain with a stained mascot statue in the middle of the atrium.
	_cylinder(Vector3(0, 0, 0), Vector3(0, 0.6, 0), 2.6, "tile", Vector2(6, 1))
	_cylinder(Vector3(0, 0.6, 0), Vector3(0, 0.7, 0), 2.2, "concrete", Vector2(4, 1), 0)
	_cylinder(Vector3(0, 0.6, 0), Vector3(0, 2.2, 0), 0.35, "concrete")
	_box(Vector3(0.9, 1.1, 0.7), Vector3(0, 2.75, 0), "concrete", Vector3(0, 30, 0), Layers.WORLD, Color(0.9, 0.7, 0.6))
	_box(Vector3(0.7, 0.7, 0.7), Vector3(0, 3.65, 0), "concrete", Vector3(0, 30, 0), Layers.WORLD, Color(0.9, 0.7, 0.6))
	# Benches and planters around the atrium floor.
	for spec in [[Vector3(-5, 0.25, -6), 0.0], [Vector3(5, 0.25, 6), 0.0], [Vector3(-5.5, 0.25, 7), 90.0], [Vector3(5.5, 0.25, -6.5), 90.0]]:
		_box(Vector3(2.4, 0.5, 0.6), spec[0], "wood", Vector3(0, spec[1], 0))
	for pos in [Vector3(-6, 0.5, 0), Vector3(6, 0.5, 0), Vector3(0, 0.5, 11.5), Vector3(0, 0.5, -11.5)]:
		_box(Vector3(1.2, 1.0, 1.2), pos, "tile", Vector3.ZERO, Layers.WORLD, Color(0.6, 0.55, 0.5))
		_box(Vector3(0.9, 1.4, 0.9), pos + Vector3(0, 1.1, 0), "carpet", Vector3(0, 45, 0), 0, Color(0.3, 0.45, 0.25))
	# Information desk in the lobby.
	_box(Vector3(4, 1.1, 1.2), Vector3(-6, 0.55, 18), "wood")
	_glow(Vector3(2.0, 0.4, 0.05), Vector3(-6, 1.6, 17.35), Color(0.3, 0.6, 1.0))


func _build_upper_floor() -> void:
	# The upper floor is a ring of slabs around the atrium void (x -7..7, z -10..10).
	var y := UPPER_Y - 0.15
	_box(Vector3(11, 0.3, 42), Vector3(-12.5, y, 3), "carpet", Vector3.ZERO, Layers.WALKWAY, Color(0.55, 0.3, 0.35), 1.5)
	_box(Vector3(11, 0.3, 42), Vector3(12.5, y, 3), "carpet", Vector3.ZERO, Layers.WALKWAY, Color(0.55, 0.3, 0.35), 1.5)
	_box(Vector3(14, 0.3, 8), Vector3(0, y, -14), "carpet", Vector3.ZERO, Layers.WALKWAY, Color(0.55, 0.3, 0.35), 1.5)
	_box(Vector3(14, 0.3, 14), Vector3(0, y, 17), "carpet", Vector3.ZERO, Layers.WALKWAY, Color(0.55, 0.3, 0.35), 1.5)
	# Railings round the void, open where the escalators arrive.
	var rail_h := 1.0
	var ry := UPPER_Y + rail_h / 2.0
	for span in [Vector2(-10, 7.5), Vector2(9.5, 10)]:
		_box(Vector3(0.1, rail_h, span.y - span.x), Vector3(-7, ry, (span.x + span.y) / 2.0), "brass", Vector3.ZERO, Layers.WALKWAY)
	for span in [Vector2(-10, -9.5), Vector2(-7.5, 10)]:
		_box(Vector3(0.1, rail_h, span.y - span.x), Vector3(7, ry, (span.x + span.y) / 2.0), "brass", Vector3.ZERO, Layers.WALKWAY)
	for z in [-10.0, 10.0]:
		_box(Vector3(14, rail_h, 0.1), Vector3(0, ry, z), "brass", Vector3.ZERO, Layers.WALKWAY)
	# Columns holding the upper floor up.
	for x in [-7.3, 7.3]:
		for z in [-10.3, 0.0, 10.3]:
			_box(Vector3(0.5, UPPER_Y - 0.3, 0.5), Vector3(x, (UPPER_Y - 0.3) / 2.0, z), "tile", Vector3.ZERO, Layers.WORLD, Color(0.75, 0.72, 0.7))


func _build_escalators() -> void:
	# Two stopped escalators crossing the void: too narrow for anything big.
	_escalator(Vector3(3.0, 0, 8.5), Vector3(-7.0, UPPER_Y, 8.5))
	_escalator(Vector3(-3.0, 0, -8.5), Vector3(7.0, UPPER_Y, -8.5))


func _escalator(bottom: Vector3, top: Vector3) -> void:
	var run := top.x - bottom.x
	var length := Vector2(run, top.y - bottom.y).length()
	var angle := rad_to_deg(atan2(top.y - bottom.y, absf(run))) * signf(run)
	var mid := (bottom + top) / 2.0 - Vector3(0, 0.17, 0)
	_box(Vector3(length, 0.3, 1.4), mid, "grate", Vector3(0, 0, angle), Layers.WALKWAY, Color(0.7, 0.7, 0.75), 1.5)
	for side in [-0.8, 0.8]:
		_box(Vector3(length, 1.0, 0.12), mid + Vector3(0, 0.6, side), "panel", Vector3(0, 0, angle), Layers.WALKWAY, Color(0.4, 0.4, 0.45))
	# A support pillar under the middle.
	_box(Vector3(0.4, mid.y - 0.2, 0.4), Vector3(mid.x, (mid.y - 0.2) / 2.0, mid.z), "panel", Vector3.ZERO, Layers.WORLD, Color(0.35, 0.35, 0.4))


func _build_shops() -> void:
	var names := [["錄影帶出租", Color(1.0, 0.25, 0.5)], ["電玩天地", Color(0.3, 1.0, 0.5)], ["日日美髮", Color(1.0, 0.8, 0.3)],
		["光華唱片", Color(0.4, 0.7, 1.0)], ["喜福眼鏡", Color(1.0, 0.4, 0.2)], ["天使婚紗", Color(0.9, 0.5, 1.0)]]
	var i := 0
	for side in [-1.0, 1.0]:
		var front_x: float = 11.0 * side
		var back_x: float = 18.0 * side
		for shop in SHOPS:
			var center_z: float = (shop.x + shop.y) / 2.0
			var length: float = shop.y - shop.x
			# Front wall with a 3 m shutter opening, and side walls between shops.
			_wall(Vector3(front_x, 0, shop.x), Vector3(front_x, 0, shop.y), UPPER_Y - 0.3, "tile",
				[[length / 2.0, 3.0, 3.0]], 0.2, Color(0.8, 0.78, 0.75))
			for z in [shop.x, shop.y]:
				_box(Vector3(SHOP_DEPTH, UPPER_Y - 0.3, 0.2), Vector3((front_x + back_x) / 2.0, (UPPER_Y - 0.3) / 2.0, z), "tile",
					Vector3.ZERO, Layers.WORLD, Color(0.8, 0.78, 0.75))
			_box(Vector3(SHOP_DEPTH - 0.2, 0.02, length - 0.2), Vector3((front_x + back_x) / 2.0, 0.01, center_z), "carpet",
				Vector3.ZERO, 0, names[i][1].darkened(0.6))
			# Counter and a shelf inside.
			_box(Vector3(1.0, 0.9, 3.0), Vector3(front_x + 3.5 * side, 0.45, center_z - 1.5), "wood")
			_box(Vector3(0.6, 2.2, length - 5.0), Vector3(back_x - 0.5 * side, 1.1, center_z - 1.5), "wood", Vector3.ZERO, Layers.WORLD, Color(0.7, 0.6, 0.5))
			# Neon sign over the shutter: dark until the power comes back.
			var board := _glow(Vector3(0.05, 0.5, 2.6), Vector3(front_x - 0.15 * side, 3.6, center_z), names[i][1])
			board.visible = false
			_neon.append(board)
			var lamp := _light(Vector3(front_x + 3.0 * side, 3.6, center_z), Color(0.9, 0.95, 0.8), 0.45, 6.0, true)
			lamp.omni_attenuation = 1.8
			_add_gate(Vector3(front_x, 1.5, center_z), Vector3(0.15, 3.0, 3.0))
			i += 1
	for spec in [[Vector3(-17.4, 0, -10.5), PI / 2.0], [Vector3(17.4, 0, 2.0), -PI / 2.0]]:
		_add_locker(spec[0], spec[1])


func _build_upper_rooms() -> void:
	var y := UPPER_Y
	var h := ROOF_Y - UPPER_Y
	# West: arcade and toy shop with wide open fronts.
	_wall(Vector3(-11, y, -18), Vector3(-11, y, -3), h, "tile", [[5.0, 3.0, 2.8], [11.0, 3.0, 2.8]], 0.2, Color(0.7, 0.6, 0.8))
	_wall(Vector3(-11, y, -1), Vector3(-11, y, 16), h, "tile", [[8.5, 4.0, 2.8]], 0.2, Color(0.7, 0.6, 0.8))
	for z in [-3.0, -1.0, 16.0]:
		_box(Vector3(7, h, 0.2), Vector3(-14.5, y + h / 2.0, z), "tile", Vector3.ZERO, Layers.WALKWAY, Color(0.7, 0.6, 0.8))
	for z in [-16.0, -13.5, -11.0, -8.5, -6.0]:
		_box(Vector3(1.0, 1.9, 0.9), Vector3(-17.0, y + 0.95, z), "panel", Vector3(0, 90, 0), Layers.WALKWAY, Color(0.3, 0.3, 0.6))
		_glow(Vector3(0.05, 0.5, 0.6), Vector3(-16.45, y + 1.45, z), Color(0.3 + 0.1 * z / -16.0, 1.0, 0.7))
	for z in [3.0, 7.0, 11.0]:
		_box(Vector3(0.8, 1.8, 3.0), Vector3(-17.2, y + 0.9, z), "wood", Vector3.ZERO, Layers.WALKWAY, Color(0.9, 0.5, 0.5))
	_box(Vector3(1.6, 0.8, 1.6), Vector3(-13.5, y + 0.4, 8.0), "carpet", Vector3(0, 20, 0), Layers.WALKWAY, Color(0.9, 0.8, 0.3))
	# East: the food court, tables in rows under a dead menu board.
	for x in [10.0, 14.0]:
		for z in [-2.0, 2.0, 6.0, 10.0, 14.0]:
			_box(Vector3(1.4, 0.75, 1.4), Vector3(x, y + 0.375, z), "wood", Vector3.ZERO, Layers.WALKWAY, Color(0.85, 0.85, 0.8))
	_box(Vector3(0.6, 1.1, 12.0), Vector3(17.4, y + 0.55, 6.0), "tile", Vector3.ZERO, Layers.WALKWAY, Color(0.9, 0.5, 0.3))
	var menu := _glow(Vector3(0.05, 0.8, 10.0), Vector3(17.6, y + 2.6, 6.0), Color(1.0, 0.55, 0.2))
	menu.visible = false
	_neon.append(menu)
	# East corner: the electrical room with the objective switch. A 1 m door.
	_wall(Vector3(11, y, -18), Vector3(11, y, -9), h, "concrete", [[4.0, 1.0, 2.2]])
	_wall(Vector3(11, y, -9), Vector3(18, y, -9), h, "concrete")
	_box(Vector3(0.6, 2.0, 2.0), Vector3(17.4, y + 1.0, -12.0), "panel", Vector3.ZERO, Layers.WALKWAY, Color(0.5, 0.55, 0.5))
	_light(Vector3(14.5, y + 3.0, -13.5), Color(0.6, 1.0, 0.7), 0.4, 5.0, true)
	_add_lever(Vector3(14.5, y, -17.5), 0.0, "[E] 推上總電源閘刀（貨梯會通電，但整座商場也會醒來）")
	_add_gate(Vector3(11, y + 1.1, -14.0), Vector3(0.15, 2.2, 1.0))


func _build_staff_area() -> void:
	# Back wall of the sales floor, with two staff doors and a wide roll-up dock door.
	_wall(Vector3(-18, 0, -18), Vector3(18, 0, -18), ROOF_Y, "concrete",
		[[9.0, 1.0, 2.2], [18.0, 4.0, 4.8], [27.0, 1.0, 2.2]], 0.3, Color(0.7, 0.7, 0.65))
	_add_gate(Vector3(-9.0, 1.1, -18.0), Vector3(1.0, 2.2, 0.15))
	_add_gate(Vector3(9.0, 1.1, -18.0), Vector3(1.0, 2.2, 0.15))
	_add_gate(Vector3(0.0, 2.4, -18.0), Vector3(4.0, 4.8, 0.15))
	_box(Vector3(35.6, 0.02, 5.6), Vector3(0, 0.01, -21), "concrete", Vector3.ZERO, 0, Color(0.6, 0.6, 0.55))
	# Pallets, cages and bins.
	_box(Vector3(1.6, 1.2, 1.2), Vector3(-14.5, 0.6, -20.5), "wood")
	_box(Vector3(1.6, 2.0, 1.2), Vector3(-6.0, 1.0, -22.8), "grate", Vector3.ZERO, Layers.WORLD, Color.WHITE, 1.0)
	_box(Vector3(1.2, 1.2, 1.2), Vector3(5.0, 0.6, -20.0), "rust_metal", Vector3(0, 20, 0))
	_add_locker(Vector3(-17.4, 0, -22.0), PI / 2.0)
	_add_locker(Vector3(-17.4, 0, -20.6), PI / 2.0)
	# The freight lift in the north-east corner of the dock.
	var center := Vector3(13.5, 0, -21.2)
	_box(Vector3(3.2, 0.1, 3.2), center + Vector3(0, 0.05, 0), "grate", Vector3.ZERO, 0, Color(0.7, 1.0, 0.8))
	for corner in [Vector3(1.5, 0, 1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, -1.5)]:
		_box(Vector3(0.15, 3.0, 0.15), center + corner + Vector3(0, 1.5, 0), "rust_metal")
	_box(Vector3(3.2, 0.2, 3.2), center + Vector3(0, 3.1, 0), "panel")
	_glow(Vector3(1.6, 0.3, 0.05), Vector3(13.5, 3.6, -18.2), Color(1.0, 0.2, 0.15))
	_add_extraction(center)


func _build_lights() -> void:
	# Half the ceiling lights are dead; the rest buzz and flicker.
	_light(Vector3(0, 9.0, 0), Color(0.8, 0.9, 1.0), 1.1, 16.0, true)
	_light(Vector3(-9, 4.2, -12), Color(0.85, 0.9, 1.0), 0.5, 8.0, true)
	_light(Vector3(9, 4.2, 10), Color(0.85, 0.9, 1.0), 0.5, 8.0, false)
	_light(Vector3(0, 4.0, 19), Color(1.0, 0.9, 0.75), 0.6, 10.0, true)
	_light(Vector3(-13, 9.0, -10), Color(0.5, 0.4, 1.0), 0.5, 9.0, true)
	_light(Vector3(13, 9.0, 6), Color(1.0, 0.7, 0.5), 0.5, 10.0, false)
	_light(Vector3(-13, 9.0, 8), Color(1.0, 0.75, 0.8), 0.4, 8.0, true)
	_light(Vector3(-2, 3.8, -21), Color(1.0, 0.85, 0.6), 0.5, 9.0, true)
	_light(Vector3(13.5, 2.8, -21.2), Color(1.0, 0.85, 0.6), 0.4, 6.0, false)
