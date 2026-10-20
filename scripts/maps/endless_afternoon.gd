class_name EndlessAfternoon
extends GameMap
## 無盡的午後 (dreamcore). A house that is too big and too clean, in an afternoon that
## never ends: a white corridor that goes on forever, an empty playground indoors, a long
## dining table laid for a party nobody came to, a giant child's bedroom and a tiled
## pool room. Bright, soft and pastel: the fear here is the opposite of the dark.
## Rules:
##   - The corridor loops. Walk far enough either way and you're back where you were.
##   - The white door never opens onto the same room twice.
##   - Clarity (清醒度) drains while you're here; the dream gets softer and stranger,
##     and at zero you are woken up: thrown out with half your loot left behind.
##   - Lanterns and night vision are useless: everything is lit.

const ROOM_H := 4.8
const CORRIDOR_HALF := 1.6
const CORRIDOR_END := 36.0
## Past this distance along the corridor you are quietly moved back by LOOP_PERIOD.
const LOOP_AT := 17.0
const LOOP_PERIOD := 8.0
const CLARITY_DRAIN := 100.0 / 540.0  # gone in nine minutes
const POOL_DRAIN_MULT := 1.6
const COMFORT_DRAIN_MULT := 0.5
const PASTEL := {
	"wall": Color(0.97, 0.95, 0.93),
	"pink": Color(1.0, 0.82, 0.86),
	"mint": Color(0.78, 0.95, 0.86),
	"sky": Color(0.75, 0.86, 1.0),
	"butter": Color(1.0, 0.95, 0.72),
	"lilac": Color(0.88, 0.8, 1.0),
}

const LOOT_SPOTS := [
	# Corridor and living room.
	Vector3(-12.0, 0.2, 0.8), Vector3(4.0, 0.2, -0.9), Vector3(13.0, 0.2, 0.7),
	Vector3(-3.0, 0.2, -10.0), Vector3(3.5, 0.65, -6.0), Vector3(-3.5, 0.2, -4.0),
	# Playground.
	Vector3(-20.0, 0.2, -20.0), Vector3(-14.0, 0.2, -10.0), Vector3(-9.0, 0.2, -17.0),
	Vector3(-18.0, 0.6, -12.5), Vector3(-21.5, 0.2, -6.0), Vector3(-12.0, 1.75, -20.5),
	# Dining room.
	Vector3(12.0, 0.95, -14.0), Vector3(17.0, 0.95, -14.0), Vector3(20.0, 0.95, -15.0),
	Vector3(9.5, 0.2, -21.0), Vector3(22.0, 0.2, -6.0), Vector3(16.0, 0.2, -21.5),
	# Bedroom (giant furniture).
	Vector3(-20.0, 1.45, 10.0), Vector3(-10.0, 0.2, 20.0), Vector3(-21.5, 0.2, 21.0),
	Vector3(-12.0, 1.25, 6.5), Vector3(-17.0, 0.2, 17.0),
	# Pool room.
	Vector3(9.5, 0.2, 6.5), Vector3(21.5, 0.2, 21.0), Vector3(15.0, 0.2, 14.0),
	Vector3(22.0, 0.2, 8.0), Vector3(10.0, 0.2, 21.0),
	# Entrance hall.
	Vector3(-3.5, 0.2, 9.0), Vector3(3.5, 0.95, 6.0),
]

const PATROL_POINTS := [
	Vector3(-12, 0, 0), Vector3(0, 0, 0), Vector3(12, 0, 0), Vector3(0, 0, -7),
	Vector3(-15, 0, -14), Vector3(-10, 0, -20), Vector3(-20, 0, -8),
	Vector3(15, 0, -11), Vector3(10, 0, -20), Vector3(21, 0, -8),
	Vector3(10, 0, 8), Vector3(21, 0, 20), Vector3(9.5, 0, 20),
	Vector3(0, 0, 8),
]

const WAKE_LINES := [
	"「…起床了喔。」",
	"遠處有人在叫你的名字。是你媽媽的聲音嗎？",
	"「再睡五分鐘就好…」",
	"你想不起來自己是怎麼進來的。",
]

## Clarity of THIS machine's player (every peer tracks its own).
var clarity := 100.0
## Where the white door can open onto.
var dream_rooms: Array[Vector3] = [
	Vector3(-15, 0.2, -14), Vector3(15, 0.2, -11), Vector3(-16, 0.2, 15),
	Vector3(10, 0.2, 8), Vector3(0, 0.2, 8), Vector3(0, 0.2, -7),
]

var _pool_room := AABB(Vector3(5, -1, 1.6), Vector3(19, 5, 22.4))
var _woken := false
var _whisper := 40.0
var _last_door := -1


func build() -> void:
	map_name = "無盡的午後"
	intro = "好亮。太安靜了。這裡好像是你小時候的家，但大了好多。在這裡待太久，你會忘記自己在作夢。"
	objective_text = "到餐廳吹熄生日蛋糕的蠟燭（東北）"
	exit_text = "回到玄關，從大門出去"
	objective_message = "蠟燭熄了。所有人都轉過頭來看你…玄關的大門打開了。"
	blocked_message = "大門打不開。好像還有什麼事情沒做完…（餐廳的蛋糕）"
	exit_name = "大門"
	warning_message = "窗外的太陽一動也不動。只剩兩分鐘了。"
	timeout_cause = "午後永遠不會結束。你留在這裡了"
	bright = true
	player_spawn = Vector3(0.0, 0.1, 5.0)
	player_spawn_yaw = 0.0
	monster_spawn = Vector3(15.0, 0.1, -11.0)
	patrol_points.assign(PATROL_POINTS)
	loot_spots.assign(LOOT_SPOTS)
	loot_count = Vector2i(15, 19)
	bounds = AABB(Vector3(-24, -1.5, -24), Vector3(48, 8.0, 48))
	overview_height = 7.0
	_environment(PASTEL.sky, Color(1.0, 0.94, 0.9), 0.7, Color(1.0, 0.96, 0.94), 0.018, "lullaby", -24.0)
	_build_corridor()
	_build_living_room()
	_build_entrance()
	_build_playground()
	_build_dining()
	_build_bedroom()
	_build_pool()


func _physics_process(delta: float) -> void:
	var local := _local_player()
	if local == null or not local.is_active():
		return
	_loop_corridor(local)
	update_clarity(local, delta)


## The endless corridor: past the loop point you're back a stretch, looking the same way.
func _loop_corridor(player: Player) -> void:
	var pos := player.global_position
	if absf(pos.z) > CORRIDOR_HALF or pos.y > ROOM_H:
		return
	if pos.x > LOOP_AT:
		player.global_position.x -= LOOP_PERIOD
	elif pos.x < -LOOP_AT:
		player.global_position.x += LOOP_PERIOD


## Runs for the local player only: the dream thickens, and at zero you wake up.
func update_clarity(player: Player, delta: float) -> void:
	var rate := CLARITY_DRAIN
	if _pool_room.has_point(player.global_position):
		rate *= POOL_DRAIN_MULT
	if player.has_effect("comfort"):
		rate *= COMFORT_DRAIN_MULT
	clarity = maxf(clarity - rate * delta, 0.0)
	player.map_dream = clampf((75.0 - clarity) / 75.0, 0.0, 1.0)
	if clarity < 35.0:
		_whisper -= delta
		if _whisper <= 0.0:
			_whisper = rng.randf_range(20.0, 35.0)
			player.message.emit(WAKE_LINES[rng.randi_range(0, WAKE_LINES.size() - 1)])
	if clarity <= 0.0 and not _woken and Run.instance != null:
		_woken = true
		Run.instance.local_woken()


## The white door: opens onto a different room every time (never the same one twice).
func open_dream_door(player: Player) -> void:
	var index := rng.randi_range(0, dream_rooms.size() - 1)
	if index == _last_door:
		index = (index + 1) % dream_rooms.size()
	_last_door = index
	player.global_position = dream_rooms[index]
	player.velocity = Vector3.ZERO
	player.add_shake(0.3)
	Sfx.play_2d(player, "chime", -8.0, 0.7)
	player.message.emit("門後不是你記得的那個房間。")


func status_text() -> String:
	var local := _local_player()
	if local == null or not local.is_active():
		return ""
	var feel := "清醒" if clarity > 70.0 else ("有點恍惚" if clarity > 35.0 else ("快睡著了" if clarity > 10.0 else "要被叫醒了…"))
	return "清醒度 %d%%　%s" % [int(ceil(clarity)), feel]


func _local_player() -> Player:
	if Run.instance == null or Run.instance.local_player == null:
		return null
	return Run.instance.local_player


# --- Building -------------------------------------------------------------------------

func _room(min_corner: Vector2, max_corner: Vector2, floor_texture: String, floor_tint: Color,
		wall_tint: Color, height := ROOM_H) -> void:
	var size := Vector2(max_corner.x - min_corner.x, max_corner.y - min_corner.y)
	var center := Vector3((min_corner.x + max_corner.x) / 2.0, 0, (min_corner.y + max_corner.y) / 2.0)
	_box(Vector3(size.x, 1.0, size.y), center + Vector3(0, -0.5, 0), floor_texture, Vector3.ZERO, Layers.WORLD, floor_tint, 1.0)
	_roof(Vector3(size.x, 0.2, size.y), center + Vector3(0, height + 0.1, 0), "panel", wall_tint)


func _build_corridor() -> void:
	# The white corridor runs far past the house in both directions (and loops).
	_room(Vector2(-CORRIDOR_END, -CORRIDOR_HALF), Vector2(CORRIDOR_END, CORRIDOR_HALF), "snow", PASTEL.wall, PASTEL.wall)
	var doors_north := [[CORRIDOR_END - 9.0, 3.0, ROOM_H], [CORRIDOR_END, 3.0, ROOM_H], [CORRIDOR_END + 9.0, 3.0, ROOM_H]]
	# The bedroom door is child-sized: nothing big gets in there.
	var doors_south := [[CORRIDOR_END - 9.0, 1.4, 2.2], [CORRIDOR_END, 3.0, ROOM_H], [CORRIDOR_END + 9.0, 3.0, ROOM_H]]
	_wall(Vector3(-CORRIDOR_END, 0, -CORRIDOR_HALF), Vector3(CORRIDOR_END, 0, -CORRIDOR_HALF), ROOM_H, "snow", doors_north, 0.2, PASTEL.wall)
	_wall(Vector3(-CORRIDOR_END, 0, CORRIDOR_HALF), Vector3(CORRIDOR_END, 0, CORRIDOR_HALF), ROOM_H, "snow", doors_south, 0.2, PASTEL.wall)
	for x in [-CORRIDOR_END, CORRIDOR_END]:
		_box(Vector3(0.2, ROOM_H, CORRIDOR_HALF * 2.0), Vector3(x, ROOM_H / 2.0, 0), "panel", Vector3.ZERO, Layers.WORLD, PASTEL.wall)
	# Soft ceiling panels every 4 m (the same every loop period, so the loop is seamless).
	var x := -CORRIDOR_END + 2.0
	while x < CORRIDOR_END:
		_glow(Vector3(1.2, 0.05, 0.8), Vector3(x, ROOM_H - 0.03, 0), Color(1.0, 0.98, 0.92))
		if int(round(x)) % 8 == 0:
			_light(Vector3(x, ROOM_H - 0.4, 0), Color(1.0, 0.97, 0.9), 0.6, 7.0, false)
		x += 4.0


func _build_living_room() -> void:
	_room(Vector2(-5, -12), Vector2(5, -1.6), "tile", PASTEL.pink, PASTEL.wall)
	_wall(Vector3(-5, 0, -12), Vector3(5, 0, -12), ROOM_H, "snow", [], 0.2, PASTEL.wall)
	_wall(Vector3(-5, 0, -12), Vector3(-5, 0, -1.6), ROOM_H, "snow", [], 0.2, PASTEL.wall)
	_wall(Vector3(5, 0, -12), Vector3(5, 0, -1.6), ROOM_H, "snow", [], 0.2, PASTEL.wall)
	# A sofa facing a TV that only shows the same afternoon.
	_box(Vector3(3.0, 0.5, 1.0), Vector3(0, 0.25, -4.0), "snow", Vector3.ZERO, Layers.WORLD, PASTEL.lilac)
	_box(Vector3(3.0, 0.6, 0.3), Vector3(0, 0.8, -3.6), "snow", Vector3.ZERO, Layers.WORLD, PASTEL.lilac)
	_box(Vector3(1.6, 0.5, 0.8), Vector3(3.5, 0.25, -6.0), "wood", Vector3.ZERO, Layers.WORLD, Color(0.95, 0.85, 0.7))
	_box(Vector3(1.4, 1.0, 0.6), Vector3(0, 0.5, -9.5), "wood", Vector3.ZERO, Layers.WORLD, Color(0.9, 0.8, 0.7))
	_glow(Vector3(1.0, 0.7, 0.05), Vector3(0, 1.4, -9.15), Color(1.0, 0.85, 0.55))
	# The window: always the same golden afternoon.
	_glow(Vector3(0.05, 1.4, 2.4), Vector3(-4.85, 1.7, -7.0), Color(1.0, 0.85, 0.5))
	_light(Vector3(-3.5, 2.0, -7.0), Color(1.0, 0.85, 0.6), 0.9, 8.0, false)
	# The white door in the north wall.
	var door := DreamDoor.new()
	door.map = self
	door.position = Vector3(0, 0, -11.85)
	_nav.add_child(door)
	_add_gate(Vector3(0, ROOM_H / 2.0, -1.6), Vector3(3.0, ROOM_H, 0.15))


func _build_entrance() -> void:
	_room(Vector2(-5, 1.6), Vector2(5, 14), "wood", Color(0.95, 0.85, 0.72), PASTEL.wall)
	_wall(Vector3(-5, 0, 14), Vector3(5, 0, 14), ROOM_H, "snow", [], 0.2, PASTEL.wall)
	_wall(Vector3(-5, 0, 1.6), Vector3(-5, 0, 14), ROOM_H, "snow", [], 0.2, PASTEL.wall)
	_wall(Vector3(5, 0, 1.6), Vector3(5, 0, 14), ROOM_H, "snow", [], 0.2, PASTEL.wall)
	# Shoe rack, a coat stand and small shoes, all neatly lined up.
	_box(Vector3(2.0, 0.9, 0.5), Vector3(3.5, 0.45, 6.0), "wood", Vector3.ZERO, Layers.WORLD, Color(0.95, 0.9, 0.8))
	for i in 4:
		_box(Vector3(0.18, 0.1, 0.3), Vector3(-4.2 + i * 0.3, 0.05, 11.5), "carpet", Vector3.ZERO, 0, PASTEL.values()[i + 1])
	# The front door: a bright rectangle of light that opens after the cake.
	_glow(Vector3(2.4, 2.6, 0.05), Vector3(0, 1.3, 13.85), Color(1.0, 1.0, 0.95))
	_light(Vector3(0, 2.6, 11.0), Color(1.0, 0.98, 0.9), 0.8, 9.0, false)
	_add_extraction(Vector3(0, 0, 12.0))
	_add_gate(Vector3(0, ROOM_H / 2.0, 1.6), Vector3(3.0, ROOM_H, 0.15))
	_add_locker(Vector3(-4.6, 0, 4.0), PI / 2.0)


func _build_playground() -> void:
	# Indoors, under a painted sky ceiling, much too big.
	_room(Vector2(-24, -24), Vector2(-5, -1.6), "snow", Color(1.0, 0.93, 0.78), PASTEL.sky, 6.5)
	_wall(Vector3(-24, 0, -24), Vector3(-5, 0, -24), 6.5, "panel", [], 0.2, PASTEL.sky)
	_wall(Vector3(-24, 0, -24), Vector3(-24, 0, -1.6), 6.5, "panel", [], 0.2, PASTEL.sky)
	_wall(Vector3(-5, 0, -24), Vector3(-5, 0, -12), 6.5, "panel", [], 0.2, PASTEL.sky)
	_box(Vector3(19, 1.7, 0.2), Vector3(-14.5, ROOM_H + 0.85, -1.6), "panel", Vector3.ZERO, Layers.WORLD, PASTEL.sky)
	# Slide.
	_box(Vector3(1.2, 1.6, 1.2), Vector3(-12, 0.8, -20.5), "panel", Vector3.ZERO, Layers.WORLD, PASTEL.pink)
	_box(Vector3(1.0, 0.1, 3.4), Vector3(-12, 0.85, -18.2), "panel", Vector3(-28, 0, 0), Layers.WORLD, PASTEL.butter)
	# Swings.
	for x in [-20.0, -18.5]:
		_box(Vector3(0.6, 0.08, 0.3), Vector3(x, 0.6, -12.5), "wood", Vector3.ZERO, 0, PASTEL.butter)
		for side in [-0.25, 0.25]:
			_box(Vector3(0.03, 2.2, 0.03), Vector3(x + side, 1.7, -12.5), "pipe", Vector3.ZERO, 0)
	_box(Vector3(3.6, 0.15, 0.15), Vector3(-19.25, 2.8, -12.5), "pipe", Vector3.ZERO, 0, PASTEL.lilac)
	for x in [-21.0, -17.5]:
		_box(Vector3(0.15, 2.8, 0.15), Vector3(x, 1.4, -12.5), "pipe", Vector3.ZERO, Layers.WORLD, PASTEL.lilac)
	# Sandbox and a merry-go-round nobody is turning.
	_box(Vector3(4.0, 0.3, 4.0), Vector3(-9, 0.15, -9), "concrete", Vector3.ZERO, Layers.WORLD, PASTEL.butter)
	_cylinder(Vector3(-16, 0, -6), Vector3(-16, 0.3, -6), 1.6, "panel", Vector2(4, 1))
	_light(Vector3(-14, 6.0, -12), Color(1.0, 0.95, 0.85), 1.1, 18.0, false)
	_add_gate(Vector3(-9.0, ROOM_H / 2.0, -1.6), Vector3(3.0, ROOM_H, 0.15))


func _build_dining() -> void:
	_room(Vector2(5, -24), Vector2(24, -1.6), "wood", Color(0.95, 0.88, 0.78), PASTEL.butter)
	_wall(Vector3(5, 0, -24), Vector3(24, 0, -24), ROOM_H, "panel", [], 0.2, PASTEL.butter)
	_wall(Vector3(24, 0, -24), Vector3(24, 0, -1.6), ROOM_H, "panel", [], 0.2, PASTEL.butter)
	_wall(Vector3(5, 0, -24), Vector3(5, 0, -12), ROOM_H, "panel", [], 0.2, PASTEL.butter)
	# The long table, laid for a party nobody came to.
	_box(Vector3(10.0, 0.1, 1.8), Vector3(15.5, 0.8, -14.5), "wood", Vector3.ZERO, Layers.WORLD, Color(1.0, 1.0, 0.98))
	for x in [11.0, 20.0]:
		for z in [-15.2, -13.8]:
			_box(Vector3(0.1, 0.8, 0.1), Vector3(x, 0.4, z), "wood", Vector3.ZERO, 0)
	for i in 8:
		var x := 11.5 + i * 1.2
		for side in [-1.0, 1.0]:
			_box(Vector3(0.5, 0.5, 0.5), Vector3(x, 0.25, -14.5 + side * 1.4), "wood", Vector3.ZERO, Layers.WORLD, PASTEL.pink)
			_box(Vector3(0.5, 0.7, 0.08), Vector3(x, 0.85, -14.5 + side * 1.65), "wood", Vector3.ZERO, 0, PASTEL.pink)
			_cylinder(Vector3(x, 0.85, -14.5 + side * 0.55), Vector3(x, 0.87, -14.5 + side * 0.55), 0.2, "concrete", Vector2.ONE, 0)
	# The birthday cake at the head of the table: the objective.
	_cylinder(Vector3(21.0, 0.85, -14.5), Vector3(21.0, 1.2, -14.5), 0.35, "concrete", Vector2.ONE, 0)
	_glow(Vector3(0.04, 0.12, 0.04), Vector3(21.0, 1.28, -14.5), Color(1.0, 0.7, 0.3))
	_light(Vector3(21.0, 1.6, -14.5), Color(1.0, 0.75, 0.4), 0.7, 4.0, true)
	_add_lever(Vector3(22.2, 0, -14.5), -PI / 2.0, "[E] 吹熄蠟燭（大門會打開，但所有人都會醒來）")
	_light(Vector3(15, 2.8, -12), Color(1.0, 0.95, 0.85), 0.9, 12.0, false)
	_glow(Vector3(0.05, 1.4, 3.0), Vector3(23.85, 1.7, -8.0), Color(1.0, 0.85, 0.5))
	_add_locker(Vector3(23.6, 0, -20.0), -PI / 2.0)
	_add_gate(Vector3(9.0, ROOM_H / 2.0, -1.6), Vector3(3.0, ROOM_H, 0.15))


func _build_bedroom() -> void:
	# A child's bedroom where everything is twice as big. The door is child-sized.
	_room(Vector2(-24, 1.6), Vector2(-5, 24), "concrete", PASTEL.lilac, PASTEL.wall, 6.0)
	_wall(Vector3(-24, 0, 24), Vector3(-5, 0, 24), 6.0, "panel", [], 0.2, PASTEL.pink)
	_wall(Vector3(-24, 0, 1.6), Vector3(-24, 0, 24), 6.0, "panel", [], 0.2, PASTEL.pink)
	_wall(Vector3(-5, 0, 14), Vector3(-5, 0, 24), 6.0, "panel", [], 0.2, PASTEL.pink)
	_box(Vector3(19, 1.2, 0.2), Vector3(-14.5, ROOM_H + 0.6, 1.6), "panel", Vector3.ZERO, Layers.WORLD, PASTEL.pink)
	# The giant bed you can climb onto, a giant toy box, a nightlight.
	_box(Vector3(5.0, 1.2, 8.0), Vector3(-20, 0.6, 10), "carpet", Vector3.ZERO, Layers.WORLD, PASTEL.sky)
	_box(Vector3(5.0, 2.5, 0.4), Vector3(-20, 1.25, 5.8), "wood", Vector3.ZERO, Layers.WORLD, Color(0.95, 0.9, 0.85))
	_box(Vector3(3.0, 1.0, 2.0), Vector3(-12, 0.5, 6.5), "wood", Vector3.ZERO, Layers.WORLD, PASTEL.butter)
	_box(Vector3(1.0, 1.0, 1.0), Vector3(-9, 0.5, 18), "carpet", Vector3(0, 30, 0), Layers.WORLD, PASTEL.pink)
	_box(Vector3(0.8, 0.8, 0.8), Vector3(-10, 0.4, 16.5), "carpet", Vector3(0, 10, 0), Layers.WORLD, PASTEL.mint)
	_glow(Vector3(0.05, 1.6, 2.6), Vector3(-23.85, 2.2, 16.0), Color(1.0, 0.85, 0.5))
	_light(Vector3(-15, 5.0, 13), Color(1.0, 0.92, 0.88), 1.0, 16.0, false)
	# The closet is another white door.
	var door := DreamDoor.new()
	door.map = self
	door.position = Vector3(-14, 0, 23.85)
	_nav.add_child(door)
	_add_locker(Vector3(-5.4, 0, 20.0), -PI / 2.0)


func _build_pool() -> void:
	# A pool room of small white tiles, the water perfectly still and ankle-deep.
	_room(Vector2(5, 1.6), Vector2(24, 24), "snow", Color(0.92, 0.97, 1.0), PASTEL.wall)
	_wall(Vector3(5, 0, 24), Vector3(24, 0, 24), ROOM_H, "snow", [], 0.2, Color(0.9, 0.96, 1.0))
	_wall(Vector3(24, 0, 1.6), Vector3(24, 0, 24), ROOM_H, "snow", [], 0.2, Color(0.9, 0.96, 1.0))
	_wall(Vector3(5, 0, 14), Vector3(5, 0, 24), ROOM_H, "snow", [], 0.2, Color(0.9, 0.96, 1.0))
	_glow(Vector3(8, 0.02, 8), Vector3(15, 0.02, 14), Color(0.55, 0.85, 1.0))
	for side in [-1.0, 1.0]:
		_box(Vector3(8.4, 0.06, 0.2), Vector3(15, 0.03, 14 + 4.1 * side), "tile", Vector3.ZERO, 0, Color(0.8, 0.92, 1.0))
		_box(Vector3(0.2, 0.06, 8.4), Vector3(15 + 4.1 * side, 0.03, 14), "tile", Vector3.ZERO, 0, Color(0.8, 0.92, 1.0))
	# Pillars, too many of them.
	for x in [8.0, 22.0]:
		for z in [6.0, 14.0, 22.0]:
			_box(Vector3(0.6, ROOM_H, 0.6), Vector3(x, ROOM_H / 2.0, z), "snow", Vector3.ZERO, Layers.WORLD, Color(0.95, 0.98, 1.0))
	_light(Vector3(15, 2.8, 14), Color(0.85, 0.95, 1.0), 1.0, 14.0, false)
	_light(Vector3(15, 2.8, 5), Color(0.9, 0.97, 1.0), 0.5, 8.0, false)
	_add_gate(Vector3(9.0, ROOM_H / 2.0, 1.6), Vector3(3.0, ROOM_H, 0.15))
