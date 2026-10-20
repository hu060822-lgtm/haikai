class_name MusicBox
extends Trap
## A child's music box left on the floor. Come close and the lid springs open by itself
## and it plays its lullaby, loud and on and on, calling every monster in earshot.
## Press E to snap it shut. Some time later it's ready to go off again.
## Footprint 0.3 m; can sit on a table (pass the table-top height in pos.y).
## Tell: a faint ticking of the wound spring as you approach.

enum { WAITING, PLAYING, SHUT }

const WAKE_RANGE := 3.0
const NOISE := 28.0
const NOISE_INTERVAL := 1.5
const PLAY_TIME := 40.0
const RESET := 25.0

var _lid: Node3D
var _crank: Node3D
var _music: AudioStreamPlayer3D
var _timer := 0.0
var _noise := 0.0
var _tick := 0.0


func build() -> void:
	var pink := Color(0.95, 0.72, 0.78)
	part([slab(Vector3(0.26, 0.13, 0.18), Vector3(0, 0.065, 0)),
		slab(Vector3(0.28, 0.02, 0.2), Vector3(0, 0.01, 0))], "wood", pink, Color.BLACK, null, "musicbox_body")
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.13, -0.09)
	add_child(_lid)
	part([slab(Vector3(0.27, 0.03, 0.19), Vector3(0, 0.015, 0.095))], "wood", pink.lightened(0.15), Color.BLACK, _lid, "musicbox_lid")
	# A tiny brass dancer that stands up when the lid opens.
	part([[LowPoly.prism(5, 0.035, 0.0, 0.07, false), LowPoly.at(Vector3(0, 0.15, 0))],
		[LowPoly.prism(4, 0.008, 0.008, 0.05), LowPoly.at(Vector3(0, 0.2, 0))],
		[LowPoly.blob(0.012, Vector3.ONE, 0), LowPoly.at(Vector3(0, 0.235, 0))]], "brass", Color(1.0, 0.9, 0.6), Color(0.1, 0.08, 0.04), null, "musicbox_dancer")
	_crank = Node3D.new()
	_crank.position = Vector3(0.14, 0.07, 0)
	add_child(_crank)
	part([[LowPoly.prism(4, 0.006, 0.006, 0.04), LowPoly.at(Vector3(0.02, 0, 0), Vector3(0, 0, 90))],
		[LowPoly.prism(4, 0.006, 0.006, 0.04), LowPoly.at(Vector3(0.04, 0.02, 0))]], "brass", Color.WHITE, Color.BLACK, _crank, "musicbox_crank")
	_music = AudioStreamPlayer3D.new()
	_music.stream = Sfx.looped("lullaby")
	_music.volume_db = 0.0
	_music.max_distance = 35.0
	_music.unit_size = 5.0
	_music.pitch_scale = 1.25
	add_child(_music)
	add_handle(Vector3(0.35, 0.3, 0.3), Vector3(0, 0.12, 0))


func host_tick(delta: float) -> void:
	match state:
		WAITING:
			for player in players():
				if player.global_position.distance_to(global_position) < WAKE_RANGE:
					host_set_state(PLAYING)
					_timer = PLAY_TIME
					_noise = 0.0
					return
		PLAYING:
			_timer -= delta
			_noise -= delta
			if _noise <= 0.0:
				_noise = NOISE_INTERVAL
				host_noise(NOISE, GameNoise.Kind.MUSIC)
			if _timer <= 0.0:
				host_set_state(SHUT)
				_timer = RESET
		SHUT:
			_timer -= delta
			if _timer <= 0.0:
				host_set_state(WAITING)


func local_tick(delta: float) -> void:
	if state == PLAYING:
		_crank.rotation.x += delta * 4.0
		return
	if state != WAITING:
		return
	# The wound spring ticks when someone is close to waking it.
	var local := _local_player()
	if local != null and local.global_position.distance_to(global_position) < WAKE_RANGE + 3.0:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.9
			sound("tick", -18.0, 7.0, 1.8)


func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.is_multiplayer_authority():
			return node
	return null


func apply_state(new_state: int, _arg: int) -> void:
	var open := new_state == PLAYING
	create_tween().tween_property(_lid, "rotation:x", deg_to_rad(-105.0) if open else 0.0, 0.25 if open else 0.1)
	if open:
		_music.play()
	else:
		_music.stop()
		if new_state == SHUT:
			sound("thump", -8.0, 12.0, 2.0)


func get_prompt(_player: Player = null) -> String:
	return "[E] 闔上音樂盒" if state == PLAYING else ""


func interact(_player: Player) -> void:
	if state == PLAYING:
		request("close")


func host_request(action: String, _player: Player) -> void:
	if action == "close" and state == PLAYING:
		host_set_state(SHUT)
		_timer = RESET
