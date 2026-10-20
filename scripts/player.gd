class_name Player
extends CharacterBody3D
## First-person scavenger: walk, sprint, crouch through ducts, climb ladders, carry loot,
## use carry-in gear. Everything the player does makes some amount of noise.

signal inventory_changed(items: Array, weight: float, value: int)
signal prompt_changed(text: String)
signal stamina_changed(ratio: float)
signal health_changed(ratio: float)
signal gear_changed()
signal message(text: String)
## Gadget readouts for the HUD (thermometer, heartbeat detector), one per line.
signal readout_changed(text: String)
signal died(cause: String)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.5
const CROUCH_SPEED := 1.6
const CLIMB_SPEED := 2.6
const JUMP_VELOCITY := 4.2
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 0.9
const RADIUS := 0.3
const EYE_OFFSET := 0.15
const MAX_HEALTH := 100.0
const MAX_CARRY_WEIGHT := 30.0
const INTERACT_DISTANCE := 2.2
const MOUSE_SENSITIVITY := 0.0025
const STAMINA_DRAIN := 0.25
const STAMINA_REGEN := 0.15
const STAMINA_RECOVER_THRESHOLD := 0.3
const SAFE_FALL_SPEED := 9.0
const FALL_DAMAGE_PER_SPEED := 15.0
const FRAGILE_FALL_LOSS := 0.25
# Footstep noise radius (metres) by gait.
const STEP_NOISE := {"crouch": 2.0, "walk": 6.0, "sprint": 14.0}
const NOISY_ITEM_RADIUS := 8.0
const NOISY_ITEM_INTERVAL := 1.6
const ADRENALINE_TIME := 10.0
const ADRENALINE_CRASH_TIME := 10.0
const SPRING_JUMP_MULT := 1.42  # sqrt(2): double jump height
const VOICE_RATE := 11025.0
const HOT_INTERVAL := 2.5
const HOT_DAMAGE := 3.0
const EXO_EXTRA_CARRY := 15.0
const IRON_LUNG_DRAIN := 0.67
const GLIDE_FALL_SPEED := 1.2
const HEART_RANGE := 15.0
const RAILGUN_CHARGE := 3.0
const CAT_EYE_TIME := 30.0
const REWIND_TIME := 5.0
const REWIND_STEP := 0.25
# Loot that does something (see LootTable "use", "effect" and tags).
const ALIVE_INTERVAL := Vector2(12.0, 25.0)
const ALIVE_ESCAPE_CHANCE := 0.4
const HEAVY_FACTOR := 0.55
const HEAVY_HELP_DISTANCE := 2.5
const UMBRELLA_FALL_SPEED := 3.5
const CURSE_INTERVAL := 18.0
const THAW_TIME := 90.0
const WALKMAN_TIME := 12.0
const MUSIC_INTERVAL := 1.5
const FAKE_RADIO := ["快來這邊…", "我找到出口了，跟著我的聲音。", "你身後…不，沒事。", "別相信其他人。"]

var items: Array[Dictionary] = []
var carried_weight := 0.0
var carried_value := 0
var health := MAX_HEALTH
var stamina := 1.0
var is_crouching := false
var is_dead := false
var extracted := false:
	set(value):
		extracted = value
		if value:
			visible = false
			collision_layer = 0
var lantern_on := true:
	set(value):
		lantern_on = value
		if _lantern != null:
			_lantern.visible = value
			_lantern_glow.visible = value
var display_name := "拾荒者"
## Which squad this scavenger is in (set by the spawner on every peer). See Session.SQUADS.
var squad := 0
var input_enabled := true
var weapon_id := ""
var weapon_ammo := 0
var boosts: Array[String] = []
## Replicated: what's in the backpack, so the host's monsters can react to it.
var carried_ids := PackedInt32Array()
var carried_tags := PackedStringArray()
## Read by the main scene's post shader: 0 = normal, 1 = soft, drifting, dreamlike.
var dream := 0.0
## Set by the map (the dreamcore afternoon raises it as your mind slips).
var map_dream := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _exhausted := false
var _head: Node3D
var _camera: Camera3D
var _lantern: SpotLight3D
var _lantern_glow: OmniLight3D
var _ray: RayCast3D
var _shape: CapsuleShape3D
var _collider: CollisionShape3D
var _ceiling_check: ShapeCast3D
var _focused: Node = null
var _body: Node3D
var _remote_last_pos := Vector3.ZERO
## How fast this player is moving across the ground, on every peer (monsters that only
## see movement, or punish running, read it on the host).
var ground_speed := 0.0
var _name_label: Label3D
var _voice_playback: AudioStreamGeneratorPlayback
var _bob_time := 0.0
var _step_timer := 0.0
var _noisy_timer := 0.0
var _ladders := 0
var _was_on_floor := true
var _fall_speed := 0.0
var _shake := 0.0
var _adrenaline := 0.0
var _crash := 0.0
var _weapon_cooldown := 0.0
var _bitten := 0.0
var _hot_timer := HOT_INTERVAL
var _use_cooldown := {}
var _alive_timer := 15.0
var _curse_timer := CURSE_INTERVAL
var _music_timer := 0.0
var _walkman := 0.0
var _dream_time := 0.0
var _readout_timer := 0.0
var _readout := ""
var _candle: OmniLight3D
var _candle_on := false
var _charge := 0.0
var _cat_eye := 0.0
var _cat_eye_after := 0.0
var _rewind: Array[Vector3] = []
var _rewind_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.WORLD
	collision_mask = Layers.WORLD | Layers.WALKWAY | Layers.MONSTER
	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape.height = STAND_HEIGHT
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	_collider.position.y = STAND_HEIGHT / 2.0
	add_child(_collider)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = STAND_HEIGHT - EYE_OFFSET
	add_child(_head)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.05
	_camera.far = 60.0
	_head.add_child(_camera)

	_lantern = SpotLight3D.new()
	_lantern.light_color = Color(1.0, 0.78, 0.5)
	_lantern.light_energy = 1.6
	_lantern.spot_range = 12.0
	_lantern.spot_angle = 35.0
	_lantern.shadow_enabled = true
	_lantern.position = Vector3(0.2, -0.2, 0.0)
	_camera.add_child(_lantern)

	_lantern_glow = OmniLight3D.new()
	_lantern_glow.light_color = _lantern.light_color
	_lantern_glow.light_energy = 0.35
	_lantern_glow.omni_range = 3.0
	_camera.add_child(_lantern_glow)

	_candle = OmniLight3D.new()
	_candle.light_color = Color(1.0, 0.7, 0.4)
	_candle.light_energy = 0.7
	_candle.omni_range = 4.0
	_candle.position = Vector3(-0.2, -0.25, -0.3)
	_candle.visible = false
	_camera.add_child(_candle)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0.0, 0.0, -INTERACT_DISTANCE)
	_ray.collision_mask = Layers.WORLD | Layers.LOOT | Layers.WALKWAY
	_ray.add_exception(self)
	_camera.add_child(_ray)

	_ceiling_check = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS - 0.05
	_ceiling_check.shape = sphere
	_ceiling_check.position.y = CROUCH_HEIGHT
	_ceiling_check.target_position = Vector3(0.0, STAND_HEIGHT - CROUCH_HEIGHT - sphere.radius, 0.0)
	_ceiling_check.collision_mask = Layers.WORLD | Layers.WALKWAY
	_ceiling_check.add_exception(self)
	add_child(_ceiling_check)

	_build_body()
	if get_node_or_null("Sync") == null:
		build_sync()
	lantern_on = lantern_on
	# Children created above default to the host; hand them to this player's owner.
	# The synchronizer already has it (changing it after it registered breaks replication).
	for child in get_children():
		if child.name != "Sync":
			child.set_multiplayer_authority(get_multiplayer_authority(), true)
	var local := is_multiplayer_authority()
	_camera.current = local
	_body.visible = not local
	_name_label.text = display_name
	set_physics_process(local)
	if not local:
		_build_voice()


## Where a teammate's voice comes out: their mouth, fading with distance.
func _build_voice() -> void:
	var voice := AudioStreamPlayer3D.new()
	voice.name = "Voice"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = VOICE_RATE
	generator.buffer_length = 0.4
	voice.stream = generator
	voice.position.y = STAND_HEIGHT - 0.2
	voice.unit_size = 5.0
	voice.max_distance = 28.0
	voice.volume_db = 2.0
	add_child(voice)
	voice.play()
	_voice_playback = voice.get_stream_playback()


## Local player: send a chunk of 8-bit mic audio to everyone else.
func send_voice(data: PackedByteArray) -> void:
	_voice_packet.rpc(data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _voice_packet(data: PackedByteArray) -> void:
	# The dead don't talk to the living.
	if _voice_playback == null or is_dead:
		return
	if _voice_playback.get_frames_available() < data.size():
		return
	var frames := PackedVector2Array()
	frames.resize(data.size())
	for i in data.size():
		var value := (data[i] - 128) / 127.0
		frames[i] = Vector2(value, value)
	_voice_playback.push_buffer(frames)


## Movement and look are owned by the player's own machine and replicated to others.
## The spawner calls this before the player enters the tree, after setting its authority.
func build_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for path in [".:position", ".:rotation", "Head:rotation", ".:is_crouching", ".:lantern_on",
			".:is_dead", ".:extracted", ".:display_name", ".:carried_ids", ".:carried_tags"]:
		var node_path := NodePath(path)
		config.add_property(node_path)
		# Child nodes don't exist yet when spawn state is applied; sync them afterwards only.
		config.property_set_spawn(node_path, not path.begins_with("Head"))
		config.property_set_replication_mode(node_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	sync.set_multiplayer_authority(get_multiplayer_authority())
	add_child(sync)


## What other players see: a hunched scavenger in a long coat, with a name tag.
func _build_body() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	# In a match with several squads, coats take the squad's colour so you can tell friend from foe.
	var coat_color := Color(0.45, 0.38, 0.3)
	if Session.instance != null and Session.instance.is_pvp():
		coat_color = coat_color.lerp(Session.SQUAD_COLORS[squad], 0.7)
	var coat := PS1Materials.get_material("concrete", coat_color, true)
	var skin := PS1Materials.get_material("concrete", Color(0.85, 0.72, 0.6), true)
	var leather := PS1Materials.get_material("rust_metal", Color(0.5, 0.4, 0.3), true)
	for part in [
		[Vector3(0.5, 0.95, 0.32), Vector3(0, 0.95, 0), coat],
		[Vector3(0.28, 0.3, 0.28), Vector3(0, 1.58, 0), skin],
		[Vector3(0.34, 0.08, 0.34), Vector3(0, 1.75, 0), leather],
		[Vector3(0.16, 0.5, 0.16), Vector3(-0.13, 0.25, 0), leather],
		[Vector3(0.16, 0.5, 0.16), Vector3(0.13, 0.25, 0), leather],
		[Vector3(0.42, 0.5, 0.22), Vector3(0, 1.05, 0.25), leather],
	]:
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh_instance.mesh = box
		mesh_instance.position = part[1]
		mesh_instance.material_override = part[2]
		_body.add_child(mesh_instance)
	_name_label = Label3D.new()
	_name_label.position.y = 2.05
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.font_size = 48
	_name_label.pixel_size = 0.004
	_name_label.modulate = Color(0.95, 0.88, 0.7, 0.85)
	_name_label.outline_size = 8
	# Only your own squad's names float over their heads.
	_name_label.visible = is_teammate_of_local()
	_body.add_child(_name_label)


## Where this player is looking. Valid on every peer: the head rotation is replicated.
func look_direction() -> Vector3:
	return -_head.global_basis.z


## Host -> owner: something hurt this player.
@rpc("any_peer", "call_local", "reliable")
func remote_damage(amount: float, cause: String, note := "") -> void:
	if not _from_host():
		return
	take_damage(amount, cause)
	if note != "" and not is_dead:
		message.emit(note)


## Host -> owner: a moth put the lantern out.
@rpc("any_peer", "call_local", "reliable")
func remote_snuff() -> void:
	if not _from_host() or not lantern_on:
		return
	set_lantern(false)
	add_shake(0.2)
	message.emit("有東西撲滅了你的提燈！（F 重新點亮）")


## Host -> owner: a mimic bit this player's hand.
@rpc("any_peer", "call_local", "reliable")
func remote_bitten(seconds: float, damage: float) -> void:
	if not _from_host():
		return
	_bitten = seconds
	take_damage(damage, "被擬態蟲咬死了")
	if not is_dead:
		message.emit("那不是寶物！它咬住你的手了，%d 秒內用不了武器和道具" % int(seconds))


## Host -> owner: a monster has noticed you (no damage, just the dread).
@rpc("any_peer", "call_local", "reliable")
func remote_warn(text: String, shake := 0.2) -> void:
	if not _from_host() or is_dead:
		return
	add_shake(shake)
	message.emit(text)


## Host -> owner: clockwork rats tore something out of the backpack. It drops at your feet.
@rpc("any_peer", "call_local", "reliable")
func remote_rob() -> void:
	if not _from_host() or is_dead or items.is_empty():
		return
	var data: Dictionary = items.pop_at(randi_range(0, items.size() - 1))
	_recalculate()
	message.emit("發條鼠從背包叼走了「%s」！" % data.name)
	var at := global_position + Vector3.UP * 0.3
	if Run.instance != null:
		Run.instance.request_drop(data, at, Vector3.ZERO)


## Host -> owner: the "don't press" button did something to you.
@rpc("any_peer", "call_local", "reliable")
func remote_event(kind: String, at: Vector3) -> void:
	if not _from_host() or is_dead:
		return
	match kind:
		"heal":
			health = MAX_HEALTH
			stamina = 1.0
			health_changed.emit(1.0)
			stamina_changed.emit(1.0)
			message.emit("按鈕發出愉快的「叮」。你覺得精神百倍！")
		"gift":
			message.emit("按鈕吐出了一個東西。")
		"alarm":
			add_shake(0.6)
			message.emit("警報大作！整棟建築都聽到了！")
		"teleport":
			global_position = at
			velocity = Vector3.ZERO
			add_shake(0.5)
			message.emit("眨眼之間，你站在完全不同的地方。")
		_:
			set_lantern(false)
			add_shake(0.3)
			message.emit("按鈕「喀」了一聲。你的提燈熄了。")


func _from_host() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == 1


func is_active() -> bool:
	return not is_dead and not extracted


func is_teammate_of_local() -> bool:
	if Run.instance == null or Run.instance.local_player == null:
		return true
	return Run.instance.local_player.squad == squad


## Called on the local player after a successful extraction.
func set_extracted() -> void:
	input_enabled = false
	extracted = true


## Spectating: look through this (remote) player's eyes after your own run ended.
func set_viewed(viewed: bool) -> void:
	_camera.current = viewed
	_body.visible = not viewed and not is_multiplayer_authority()


func can_carry(data: Dictionary) -> bool:
	return carried_weight + data.weight <= max_carry(self)


## How much a player can carry (the exoskeleton adds to it).
static func max_carry(player: Player) -> float:
	return MAX_CARRY_WEIGHT + (EXO_EXTRA_CARRY if player != null and player.has_gear("exoskeleton") else 0.0)


## The host tells the owner they were caught by something.
@rpc("any_peer", "call_local", "reliable")
func remote_die(cause: String) -> void:
	if _from_host():
		die(cause)


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return
	# Remote players: pose the body from replicated state.
	_body.scale.y = lerpf(_body.scale.y, 0.6 if is_crouching else 1.0, 10.0 * delta)
	_body.rotation.x = lerpf(_body.rotation.x, -PI / 2.0 if is_dead else 0.0, 4.0 * delta)
	_name_label.text = display_name
	_name_label.visible = is_teammate_of_local()
	# Footsteps of teammates, inferred from how fast their replicated position moves.
	var moved := Vector2(position.x - _remote_last_pos.x, position.z - _remote_last_pos.z).length()
	_remote_last_pos = position
	var speed := moved / maxf(delta, 0.001)
	ground_speed = lerpf(ground_speed, clampf(speed, 0.0, 12.0), minf(8.0 * delta, 1.0))
	if speed > 0.5 and speed < 12.0 and not is_dead:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.32 if speed > 4.5 else (0.7 if is_crouching else 0.48)
			var volume := -22.0 if is_crouching else (-8.0 if speed > 4.5 else -14.0)
			Sfx.play_3d(get_parent(), global_position, "step", volume, 20.0, randf_range(0.85, 1.15))


## Equips carry-in gear for this run. loadout = {"weapon": id, "boosts": [ids]}.
func equip(loadout: Dictionary) -> void:
	weapon_id = loadout.get("weapon", "")
	weapon_ammo = Gear.info(weapon_id).get("ammo", 0)
	_weapon_cooldown = 0.0
	_charge = 0.0
	boosts.clear()
	for id in loadout.get("boosts", []):
		boosts.append(id)
	_recalculate()
	gear_changed.emit()
	if has_gear("rabbit_foot") and is_multiplayer_authority() and Run.instance != null:
		Run.instance.request_lucky.call_deferred()
		message.emit("幸運符在發燙…這局好東西比較多，但怪物也多了一隻。")


## Gear the player still has (consumed items are gone), returned on extraction.
func remaining_gear() -> Array[String]:
	var ids: Array[String] = []
	if weapon_id != "":
		ids.append(weapon_id)
	ids.append_array(boosts)
	return ids


func has_gear(id: String) -> bool:
	return weapon_id == id or id in boosts


## Mouse look, called by the main scene so it works through the low-res SubViewport.
func look(relative: Vector2) -> void:
	if not input_enabled or is_dead:
		return
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(85.0))


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func head_position() -> Vector3:
	return _head.global_position


func take_damage(amount: float, cause: String) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health / MAX_HEALTH)
	add_shake(0.4)
	if health <= 0.0:
		die(cause)


func die(cause: String) -> void:
	if is_dead:
		return
	if "second_life" in boosts and not _rewind.is_empty():
		_rewind_time()
		return
	is_dead = true
	health = 0.0
	health_changed.emit(0.0)
	input_enabled = false
	velocity = Vector3.ZERO
	Sfx.play_2d(self, "death", -2.0)
	died.emit(cause)


func _physics_process(delta: float) -> void:
	if is_dead:
		_head.position.y = lerpf(_head.position.y, 0.3, 4.0 * delta)
		_head.rotation.z = lerpf(_head.rotation.z, 1.2, 3.0 * delta)
		return

	if is_multiplayer_authority():
		ground_speed = Vector2(velocity.x, velocity.z).length()
	_weapon_cooldown = maxf(_weapon_cooldown - delta, 0.0)
	_bitten = maxf(_bitten - delta, 0.0)
	_update_boost_timers(delta)
	var climbing := _ladders > 0

	if not is_on_floor() and not climbing:
		velocity.y -= _gravity * delta
		if velocity.y < -UMBRELLA_FALL_SPEED and has_effect("umbrella"):
			velocity.y = -UMBRELLA_FALL_SPEED
		if velocity.y < -GLIDE_FALL_SPEED and gliding():
			velocity.y = -GLIDE_FALL_SPEED
		_fall_speed = maxf(_fall_speed, -velocity.y)

	if input_enabled and Input.is_action_pressed("crouch") and not has_gear("exoskeleton"):
		_set_crouch(true)
	elif is_crouching and _can_stand():
		_set_crouch(false)

	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		var jump := JUMP_VELOCITY * _weight_factor()
		if has_gear("spring_boots"):
			jump *= SPRING_JUMP_MULT
		velocity.y = jump

	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var sprinting := input_enabled and Input.is_action_pressed("sprint") and not is_crouching \
		and input_dir.length() > 0.1 and not _exhausted and _crash <= 0.0
	_update_stamina(sprinting, delta)

	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if _crash > 0.0:
		speed *= 0.5
	if _heavy_slowed():
		speed *= HEAVY_FACTOR
	speed *= _weight_factor()

	if climbing:
		# Forward climbs, back descends; you can still step off sideways or forward at the top.
		velocity.y = -input_dir.y * CLIMB_SPEED
		speed *= 0.6
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity = transform.basis.z * 3.0
			_ladders = 0

	var accel := 10.0 if is_on_floor() or climbing else (5.0 if gliding() else 2.0)
	velocity.x = lerpf(velocity.x, direction.x * speed, accel * delta)
	velocity.z = lerpf(velocity.z, direction.z * speed, accel * delta)
	move_and_slide()

	_handle_landing()
	_update_footsteps(delta, input_dir.length() > 0.1 and is_on_floor(), sprinting)
	_update_noisy_items(delta)
	_update_item_effects(delta)
	_update_head(delta, input_dir.length() > 0.1 and is_on_floor(), speed)
	_update_focus()

	if not input_enabled:
		return
	if Input.is_action_just_pressed("interact") and is_instance_valid(_focused):
		_focused.interact(self)
		_focused = null
	if Input.is_action_just_pressed("lantern"):
		set_lantern(not lantern_on)
	if Input.is_action_just_pressed("drop"):
		drop_last()
	if Input.is_action_just_pressed("use_weapon"):
		use_weapon()
	if Input.is_action_just_pressed("use_boost"):
		use_boost()
	if Input.is_action_just_pressed("use_item"):
		use_item()


func pickup(data: Dictionary) -> bool:
	if not can_carry(data):
		message.emit("太重了，背不動")
		return false
	items.append(data)
	_recalculate()
	if data.has("note"):
		message.emit(data.note)
	elif LootTable.has_tag(data, "heavy") and not has_gear("exoskeleton"):
		message.emit("好重！找個隊友站在旁邊一起抬，才走得快。")
	return true


func drop_last() -> void:
	if items.is_empty():
		return
	var data: Dictionary = items.pop_back()
	_recalculate()
	var at := _camera.global_position - _camera.global_basis.z * 0.8
	var velocity_out := -_camera.global_basis.z * 2.0
	if Run.instance != null:
		Run.instance.request_drop(data, at, velocity_out)
	else:
		var item := LootItem.from_data(data)
		get_parent().add_child(item)
		item.global_position = at
		item.linear_velocity = velocity_out


## Empties the backpack and returns what was in it (used by extraction).
func take_all_items() -> Array[Dictionary]:
	var taken: Array[Dictionary] = items.duplicate()
	items.clear()
	_recalculate()
	return taken


## Whether monsters see this player as lit: lantern on, or on a map with no shadows.
func is_lit() -> bool:
	return lantern_on or (Run.instance != null and Run.instance.level != null and Run.instance.level.bright)


func set_lantern(on: bool) -> void:
	lantern_on = on


func use_weapon() -> void:
	if weapon_id == "" or _weapon_cooldown > 0.0:
		return
	if _bitten > 0.0:
		message.emit("手被咬住了，用不了武器！")
		return
	match weapon_id:
		"crowbar":
			_weapon_cooldown = 0.6
			if is_instance_valid(_focused) and _focused.has_method("pry"):
				_focused.pry(self)
			else:
				Sfx.play_3d(get_parent(), global_position, "clank", -10.0, 20.0, 1.4)
				_fire()
		"slingshot":
			if weapon_ammo <= 0:
				message.emit("彈珠用完了")
				return
			_weapon_cooldown = 0.5
			weapon_ammo -= 1
			var marble := Marble.new()
			get_parent().add_child(marble)
			marble.global_position = _camera.global_position - _camera.global_basis.z * 0.5
			marble.linear_velocity = -_camera.global_basis.z * 22.0
			gear_changed.emit()
		"boomerang":
			_weapon_cooldown = 1.5
			_fire()
			if randf() < 0.15:
				weapon_id = ""
				message.emit("扳手飛回來的時候沒接住…它不見了。")
				gear_changed.emit()
		"nail_gun", "flamethrower", "shotgun":
			if not _spend_ammo():
				return
			_weapon_cooldown = {"nail_gun": 0.25, "flamethrower": 0.8, "shotgun": 1.2}[weapon_id]
			_fire()
			if weapon_id == "shotgun":
				add_shake(0.5)
		"shock_glove":
			_weapon_cooldown = 15.0
			_fire()
			message.emit("滋——！手套沒電了，充電中（15 秒）")
		"megaphone":
			_weapon_cooldown = 12.0
			_fire()
			add_shake(0.3)
		"rubber_duck":
			if not _spend_ammo():
				return
			_weapon_cooldown = 1.0
			if Run.instance != null:
				Run.instance.request_duck(_camera.global_position - _camera.global_basis.z * 0.5,
					-_camera.global_basis.z * 9.0 + Vector3.UP * 2.0)
		"railgun":
			if weapon_ammo <= 0:
				message.emit("加農炮已經沒有彈藥了")
				return
			if _charge <= 0.0:
				_charge = RAILGUN_CHARGE
				Sfx.play_2d(self, "zap", -6.0, 0.5)
				message.emit("磁軌加農炮充能中…（3 秒）")


## Q: uses the first consumable boost in the loadout.
func use_boost() -> void:
	if _bitten > 0.0:
		message.emit("手被咬住了，用不了道具！")
		return
	var id := ""
	for boost in boosts:
		if Gear.info(boost).get("consumable", false):
			id = boost
			break
	if id == "":
		return
	boosts.erase(id)
	match id:
		"adrenaline":
			_adrenaline = ADRENALINE_TIME
			stamina = 1.0
			_exhausted = false
			stamina_changed.emit(stamina)
			Sfx.play_2d(self, "heartbeat", -2.0, 1.3)
			message.emit("腎上腺素！")
		"cat_eye":
			_cat_eye = CAT_EYE_TIME
			Sfx.play_2d(self, "tink", -4.0, 0.5)
			message.emit("眼睛一陣刺痛…你看得到平常看不到的東西了。")
	_recalculate()
	gear_changed.emit()


func _update_boost_timers(delta: float) -> void:
	_update_gadgets(delta)
	if _adrenaline > 0.0:
		_adrenaline -= delta
		if _adrenaline <= 0.0:
			_crash = ADRENALINE_CRASH_TIME
			message.emit("藥效退了…腳好重")
	elif _crash > 0.0:
		_crash -= delta


func enter_ladder() -> void:
	_ladders += 1


func exit_ladder() -> void:
	_ladders = maxi(_ladders - 1, 0)


func _handle_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := _fall_speed
		var springs := has_gear("spring_boots")
		if impact > 3.0:
			var radius := clampf(impact * 1.5, 4.0, 18.0) * (1.6 if springs else 1.0)
			GameNoise.emit(get_tree(), global_position, radius, GameNoise.Kind.LANDING)
			Sfx.play_3d(get_parent(), global_position, "step", 0.0, 25.0, 0.6)
		if impact > SAFE_FALL_SPEED and not springs:
			_damage_fragile_items()
			take_damage((impact - SAFE_FALL_SPEED) * FALL_DAMAGE_PER_SPEED, "摔死了")
	if on_floor or _ladders > 0:
		_fall_speed = 0.0
	_was_on_floor = on_floor


func _damage_fragile_items() -> void:
	var broke := false
	for item in items:
		if LootTable.has_tag(item, "fragile"):
			item.value = int(item.value * (1.0 - FRAGILE_FALL_LOSS))
			broke = true
	if broke:
		_recalculate()
		message.emit("有東西摔壞了…")


func _update_footsteps(delta: float, moving: bool, sprinting: bool) -> void:
	if not moving:
		_step_timer = 0.0
		return
	var gait := "crouch" if is_crouching else ("sprint" if sprinting else "walk")
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.32 if sprinting else (0.7 if is_crouching else 0.48)
		var radius: float = STEP_NOISE[gait]
		if sprinting and has_gear("iron_lung"):
			radius *= 1.4  # wheezing
		GameNoise.emit(get_tree(), global_position, radius, GameNoise.Kind.FOOTSTEP)
		var volume := -22.0 if is_crouching else (-8.0 if sprinting else -14.0)
		Sfx.play_3d(get_parent(), global_position, "step", volume, 20.0, randf_range(0.85, 1.15))


func _update_noisy_items(delta: float) -> void:
	_update_hot_items(delta)
	var noisy := 0
	for item in items:
		if LootTable.has_tag(item, "noisy"):
			noisy += 1
	if noisy == 0:
		return
	_noisy_timer -= delta
	if _noisy_timer <= 0.0:
		_noisy_timer = NOISY_ITEM_INTERVAL / noisy
		GameNoise.emit(get_tree(), global_position, NOISY_ITEM_RADIUS, GameNoise.Kind.ITEM)
		Sfx.play_3d(get_parent(), global_position, "tink", -16.0, 15.0, randf_range(0.6, 1.4))


## Hot items (a glowing coal) burn a little every couple of seconds while carried.
func _update_hot_items(delta: float) -> void:
	var hot := 0
	for item in items:
		if LootTable.has_tag(item, "hot"):
			hot += 1
	if hot == 0:
		_hot_timer = HOT_INTERVAL
		return
	_hot_timer -= delta
	if _hot_timer <= 0.0:
		_hot_timer = HOT_INTERVAL
		take_damage(HOT_DAMAGE * hot, "被滾燙的煤塊燙死了")


func _recalculate() -> void:
	carried_weight = 0.0
	carried_value = 0
	var ids := PackedInt32Array()
	var tags := PackedStringArray()
	for item in items:
		carried_weight += item.weight
		carried_value += item.value
		ids.append(item.id)
		for tag in item.get("tags", []):
			if not tag in tags:
				tags.append(tag)
	carried_ids = ids
	carried_tags = tags
	if _candle_on and usable_index("candle") < 0:
		_candle_on = false
		_candle.visible = false
	inventory_changed.emit(items, carried_weight, carried_value)


func _gear_weight() -> float:
	var total := 0.0
	for id in remaining_gear():
		total += Gear.info(id).get("weight", 0.0)
	return total


func _weight_factor() -> float:
	var total_load := carried_weight + _gear_weight()
	return 1.0 - 0.4 * clampf(total_load / max_carry(self), 0.0, 1.0)


func _update_stamina(sprinting: bool, delta: float) -> void:
	var before := stamina
	if sprinting and _adrenaline <= 0.0:
		var drain := STAMINA_DRAIN * (IRON_LUNG_DRAIN if has_gear("iron_lung") else 1.0)
		stamina = maxf(stamina - drain * delta, 0.0)
		if stamina == 0.0:
			_exhausted = true
	elif not sprinting:
		var regen := STAMINA_REGEN * (0.5 if has_effect("chill") else 1.0)
		stamina = minf(stamina + regen * delta, 1.0)
		if _exhausted and stamina >= STAMINA_RECOVER_THRESHOLD:
			_exhausted = false
	if stamina != before:
		stamina_changed.emit(stamina)


func _set_crouch(crouch: bool) -> void:
	if crouch == is_crouching:
		return
	is_crouching = crouch
	var height := CROUCH_HEIGHT if crouch else STAND_HEIGHT
	_shape.height = height
	_collider.position.y = height / 2.0


func _can_stand() -> bool:
	_ceiling_check.force_shapecast_update()
	return not _ceiling_check.is_colliding()


func _update_head(delta: float, moving: bool, speed: float) -> void:
	var target_height := (CROUCH_HEIGHT if is_crouching else STAND_HEIGHT) - EYE_OFFSET
	var bob := 0.0
	if moving:
		_bob_time += delta * speed * 2.2
		bob = sin(_bob_time) * 0.04
	_head.position.y = lerpf(_head.position.y, target_height + bob, 12.0 * delta)
	_shake = maxf(_shake - delta * 1.5, 0.0)
	_camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.08


func _update_focus() -> void:
	_ray.force_raycast_update()
	var target: Node = null
	var hit := _ray.get_collider()
	if hit != null and hit.has_method("interact"):
		target = hit
	if target != _focused or (_focused != null and not is_instance_valid(_focused)):
		_focused = target
		prompt_changed.emit(target.get_prompt(self) if target != null else "")


# --- Loot that does something --------------------------------------------------------

## Valid on every peer (the backpack's contents are replicated).
func carries(id: int) -> bool:
	return id in carried_ids


func carries_tag(tag: String) -> bool:
	return tag in carried_tags


## A passive effect from something in the backpack (LootTable "effect").
func has_effect(effect: String) -> bool:
	for id in carried_ids:
		if LootTable.find(id).get("effect", "") == effect:
			return true
	return false


## The backpack item R uses: the latest usable one (or the latest with that use).
func usable_index(use := "") -> int:
	for i in range(items.size() - 1, -1, -1):
		if items[i].has("use") and (use == "" or items[i].use == use):
			return i
	return -1


func use_item() -> void:
	var index := usable_index()
	if index < 0:
		return
	if _bitten > 0.0:
		message.emit("手被咬住了，用不了東西！")
		return
	var data: Dictionary = items[index]
	var use: String = data.use
	if _use_cooldown.get(use, 0.0) > 0.0:
		return
	var tree := get_tree()
	match use:
		"milk":
			stamina = 1.0
			_exhausted = false
			stamina_changed.emit(stamina)
			_dream_time = 20.0
			message.emit("牛奶是溫的，甜甜的…周圍變得好柔和。")
			_consume(index)
		"eat":
			stamina = minf(stamina + 0.35, 1.0)
			stamina_changed.emit(stamina)
			message.emit("吃掉了。到底是誰咬的…")
			_consume(index)
		"remote":
			_use_cooldown[use] = 10.0
			var spot := aim_point(14.0)
			Sfx.play_3d(get_parent(), spot, "static", 0.0, 35.0, 0.8)
			GameNoise.emit(tree, spot, 18.0, GameNoise.Kind.MACHINE)
			message.emit("遠處有台電視突然打開了。")
		"candle":
			_candle_on = not _candle_on
			_candle.visible = _candle_on
		"powder":
			_puff(aim_point(3.0))
			for monster in _monsters_in_cone(7.0, 0.5):
				if monster is FogWalker and Run.instance != null:
					Run.instance.request_monster_action(monster, "reveal")
			GameNoise.emit(tree, global_position, 4.0, GameNoise.Kind.TOOL)
			message.emit("你把洗衣粉灑了出去。")
			_consume(index)
		"key":
			if _focused is Locker and not _focused.is_open:
				_focused.pry(self)
				message.emit("鑰匙轉了一下，櫃子開了。")
				_consume(index)
			else:
				message.emit("備用鑰匙…要對著上鎖的櫃子用。")
		"fork":
			_use_cooldown[use] = 8.0
			Sfx.play_3d(get_parent(), global_position, "chime", -4.0, 30.0, 2.0)
			GameNoise.emit(tree, global_position, 15.0, GameNoise.Kind.MUSIC)
			message.emit("嗡——音叉的聲音久久不散。")
		"walkman":
			_use_cooldown[use] = WALKMAN_TIME + 8.0
			_walkman = WALKMAN_TIME
			message.emit("隨身聽開始放歌。")
		"camera":
			_use_cooldown[use] = 6.0
			_flash()
			var seen := 0
			for monster in _monsters_in_cone(15.0, 0.6):
				seen += 1
				if monster is FogWalker and Run.instance != null:
					Run.instance.request_monster_action(monster, "reveal")
			message.emit("照片慢慢浮現…裡面多了一個不該在那裡的東西。" if seen > 0 else "喀嚓。照片裡什麼都沒有。大概吧。")
		"button":
			_use_cooldown[use] = 45.0
			if Run.instance != null:
				Run.instance.request_item_effect("button", global_position)
		"hourglass":
			_use_cooldown[use] = 30.0
			Sfx.play_3d(get_parent(), global_position, "chime", -6.0, 20.0, 0.5)
			message.emit("沙漏翻過來了…附近的東西慢了下來。")
			if Run.instance != null:
				Run.instance.request_item_effect("hourglass", global_position)
	gear_changed.emit()


## Where the player is aiming, up to max_distance (stops at walls).
func aim_point(max_distance: float) -> Vector3:
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.WALKWAY, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position - (to - from).normalized() * 0.3 if not hit.is_empty() else to


func _monsters_in_cone(max_distance: float, min_dot: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var eye := _camera.global_position
	var forward := -_camera.global_basis.z
	for node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Node3D
		if monster == null:
			continue
		var to := monster.global_position + Vector3.UP * 0.8 - eye
		if to.length() < max_distance and forward.dot(to.normalized()) > min_dot:
			found.append(monster)
	return found


func _consume(index: int) -> void:
	items.remove_at(index)
	_recalculate()


func _puff(at: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = 24
	puff.lifetime = 1.2
	puff.explosiveness = 0.9
	puff.direction = -_camera.global_basis.z
	puff.spread = 40.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 3.0
	puff.gravity = Vector3(0, -1.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 4
	mesh.rings = 2
	puff.mesh = mesh
	puff.material_override = PS1Materials.get_material("concrete", Color(0.9, 0.95, 1.0), true)
	get_parent().add_child(puff)
	puff.global_position = at
	puff.emitting = true
	get_tree().create_timer(2.0).timeout.connect(puff.queue_free)


func _flash() -> void:
	var flash := OmniLight3D.new()
	flash.light_energy = 6.0
	flash.omni_range = 12.0
	_camera.add_child(flash)
	flash.position = Vector3(0, 0, -0.5)
	Sfx.play_2d(self, "tick", -2.0, 0.6)
	get_tree().create_timer(0.12).timeout.connect(flash.queue_free)


## Heavy loot: slow, unless the exoskeleton carries it or a teammate is helping.
func _heavy_slowed() -> bool:
	if not carries_tag("heavy") or has_gear("exoskeleton"):
		return false
	for other in get_tree().get_nodes_in_group("player"):
		if other != self and other is Player and other.is_active() \
				and other.global_position.distance_to(global_position) < HEAVY_HELP_DISTANCE:
			return false
	return true


func _update_item_effects(delta: float) -> void:
	for use in _use_cooldown.keys():
		_use_cooldown[use] -= delta
		if _use_cooldown[use] <= 0.0:
			_use_cooldown.erase(use)
	_dream_time = maxf(_dream_time - delta, 0.0)
	dream = maxf(clampf(_dream_time / 5.0, 0.0, 1.0), map_dream)
	_update_alive_items(delta)
	_update_thaw(delta)
	_update_curses(delta)
	_update_music(delta)
	_readout_timer -= delta
	if _readout_timer <= 0.0:
		_readout_timer = 0.5
		var text := _readout_text()
		if text != _readout:
			_readout = text
			readout_changed.emit(text)


## Living loot wriggles free now and then and drops at your feet.
func _update_alive_items(delta: float) -> void:
	if not carries_tag("alive"):
		return
	_alive_timer -= delta
	if _alive_timer > 0.0:
		return
	_alive_timer = randf_range(ALIVE_INTERVAL.x, ALIVE_INTERVAL.y)
	for i in range(items.size() - 1, -1, -1):
		if LootTable.has_tag(items[i], "alive") and randf() < ALIVE_ESCAPE_CHANCE:
			var data: Dictionary = items.pop_at(i)
			_recalculate()
			message.emit("「%s」從你手上溜走了！" % data.name)
			var out := Vector3(randf_range(-1.0, 1.0), 2.0, randf_range(-1.0, 1.0))
			if Run.instance != null:
				Run.instance.request_drop(data, global_position + Vector3.UP, out)
			return


## The frozen thing in the backpack thaws, and then it's alive.
func _update_thaw(delta: float) -> void:
	for item in items:
		if item.get("effect", "") != "thaw" or not LootTable.has_tag(item, "cold"):
			continue
		item.thaw = item.get("thaw", THAW_TIME) - delta
		if item.thaw <= 0.0:
			item.tags.erase("cold")
			item.tags.append("alive")
			_recalculate()
			message.emit("「%s」解凍了…它在動。" % item.name)


## Cursed loot: someone keeps calling your name, the radio talks to you.
func _update_curses(delta: float) -> void:
	if not carries_tag("cursed"):
		_curse_timer = CURSE_INTERVAL
		return
	_curse_timer -= delta
	if _curse_timer > 0.0:
		return
	_curse_timer = CURSE_INTERVAL
	if has_effect("name_tag"):
		GameNoise.emit(get_tree(), global_position, 16.0, GameNoise.Kind.VOICE)
		Sfx.play_2d(self, "giggle", -14.0, 0.6)
		message.emit("有人在叫「%s」…是你的名字。附近的東西都聽到了。" % display_name)
	elif has_effect("radio"):
		Sfx.play_2d(self, "static", -6.0)
		message.emit("（對講機・？？？）「%s」" % FAKE_RADIO[randi_range(0, FAKE_RADIO.size() - 1)])


## A music box in the backpack, or the walkman playing: monsters that care about
## music hear it.
func _update_music(delta: float) -> void:
	_walkman = maxf(_walkman - delta, 0.0)
	var box := carries_tag("music")
	if _walkman <= 0.0 and not box:
		return
	_music_timer -= delta
	if _music_timer > 0.0:
		return
	_music_timer = MUSIC_INTERVAL
	var radius := 22.0 if _walkman > 0.0 else 18.0
	GameNoise.emit(get_tree(), global_position, radius, GameNoise.Kind.MUSIC)
	if _walkman > 0.0:
		GameNoise.emit(get_tree(), global_position, 8.0, GameNoise.Kind.ITEM)
	Sfx.play_3d(get_parent(), global_position, "tune", -12.0, 18.0)


## Post-shader colour: 1 normal, 0 black and white (after the cat-eye drops wear off).
func view_saturation() -> float:
	return 0.0 if _cat_eye_after > 0.0 else 1.0


## Post-shader brightness: above 1 means night vision (goggles, lantern off, not on a
## map that's already bright).
func view_gain() -> float:
	if not has_gear("night_goggles") or lantern_on or is_dead:
		return 1.0
	if Run.instance != null and Run.instance.level.bright:
		return 1.0
	return 2.6


## Holding jump in the air with the feather cloak.
func gliding() -> bool:
	return has_gear("feather_cloak") and input_enabled and not is_on_floor() and _ladders == 0 \
		and Input.is_action_pressed("jump") and velocity.y < 0.0


func _spend_ammo() -> bool:
	if weapon_ammo <= 0:
		message.emit("%s用完了" % Gear.info(weapon_id).name)
		return false
	weapon_ammo -= 1
	gear_changed.emit()
	return true


func _fire() -> void:
	if Run.instance != null:
		Run.instance.request_weapon(weapon_id, _camera.global_position, -_camera.global_basis.z)


## Railgun charge, cat-eye drops and the rewind watch's memory of where you were.
func _update_gadgets(delta: float) -> void:
	if _charge > 0.0:
		_charge -= delta
		add_shake(0.05)
		if _charge <= 0.0 and weapon_id == "railgun" and weapon_ammo > 0:
			weapon_ammo -= 1
			_fire()
			add_shake(0.8)
			gear_changed.emit()
	if _cat_eye > 0.0:
		_cat_eye -= delta
		_spot_hidden(_cat_eye > 0.0)
		if _cat_eye <= 0.0:
			_cat_eye_after = CAT_EYE_TIME
			message.emit("藥效退了…眼前的顏色全都不見了。")
	elif _cat_eye_after > 0.0:
		_cat_eye_after -= delta
	if "second_life" in boosts:
		_rewind_timer -= delta
		if _rewind_timer <= 0.0:
			_rewind_timer = REWIND_STEP
			_rewind.append(global_position)
			while _rewind.size() > int(REWIND_TIME / REWIND_STEP):
				_rewind.remove_at(0)


## Locally show what the cat-eye drops let you see.
func _spot_hidden(on: bool) -> void:
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("set_spotted"):
			monster.set_spotted(on)


## The second-life watch: back to where you were five seconds ago, and it shatters.
func _rewind_time() -> void:
	boosts.erase("second_life")
	global_position = _rewind[0]
	velocity = Vector3.ZERO
	_rewind.clear()
	health = MAX_HEALTH * 0.5
	health_changed.emit(health / MAX_HEALTH)
	_fall_speed = 0.0
	add_shake(0.6)
	Sfx.play_2d(self, "chime", -2.0, 0.6)
	message.emit("懷錶的指針倒轉了 5 秒…然後碎了。")
	_recalculate()
	gear_changed.emit()


func _readout_text() -> String:
	var lines := []
	if has_gear("heart_detector"):
		var count := 0
		var nearest: Node3D = null
		for node in get_tree().get_nodes_in_group("monsters"):
			var monster := node as Node3D
			if monster == null or monster is Mimic or monster is Mannequin:
				continue
			var distance := monster.global_position.distance_to(global_position)
			if distance < HEART_RANGE:
				count += 1
				if nearest == null or distance < nearest.global_position.distance_to(global_position):
					nearest = monster
		if nearest == null:
			lines.append("心跳偵測：沒有")
		else:
			lines.append("心跳偵測：%d 個　最近 %dm %s" % [count, int(nearest.global_position.distance_to(global_position)), _direction_word(nearest.global_position)])
	if has_effect("thermometer"):
		var nearest := INF
		for node in get_tree().get_nodes_in_group("monsters"):
			if node is Node3D:
				nearest = minf(nearest, node.global_position.distance_to(global_position))
		var degrees := int(clampf(-6.0 + nearest * 1.6, -6.0, 18.0))
		lines.append("溫度計 %d°C%s" % [degrees, "　↓" if degrees < 6 else ""])
	return "\n".join(lines)


func _direction_word(at: Vector3) -> String:
	var to := at - global_position
	var local := global_basis.inverse() * to
	if absf(local.z) > absf(local.x):
		return "前方" if local.z < 0.0 else "後方"
	return "右邊" if local.x > 0.0 else "左邊"
