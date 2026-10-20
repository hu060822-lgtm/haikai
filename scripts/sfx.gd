class_name Sfx
## Fire-and-forget sound helpers. Streams are cached after the first load.

static var _cache := {}


static func stream(sound_name: String) -> AudioStream:
	if not _cache.has(sound_name):
		_cache[sound_name] = load("res://sounds/%s.wav" % sound_name)
	return _cache[sound_name]


static func play_3d(parent: Node, position: Vector3, sound_name: String, volume_db := 0.0,
		max_distance := 40.0, pitch := 1.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.pitch_scale = pitch
	player.unit_size = 6.0
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	return player


static func play_2d(parent: Node, sound_name: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## A looping copy of a sound, for ambience.
static func looped(sound_name: String) -> AudioStreamWAV:
	var wav: AudioStreamWAV = stream(sound_name).duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / 2  # 16-bit mono frames
	return wav
