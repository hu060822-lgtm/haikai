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
## The host confirmed one of this player's shots or stabs landed. result: hit, kill,
## break (a large monster went down for a while), blocked (armour), player.
signal hit_confirmed(damage: float, result: String)

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
## Seconds the trigger is held to charge a "charge" frame (the railgun).
const CHARGE_TIME := 2.0
## Every scavenger's knife (V): short reach, a little damage, stuns small monsters.
const KNIFE_COOLDOWN := 0.55
const AIM_WALK := 0.6
const BASE_FOV := 70.0
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
# Bulky hauls (LootTable tag "bulky", see BulkyCarry): held in both hands.
const BULKY_GRAB_TIME := 0.6
## Each of two carriers feels this share of the weight (the exoskeleton takes off more).
const CO_CARRY_SHARE := 0.35
const EXO_BULKY_SHARE := 0.6
## A hit at least this hard knocks it out of your hands.
const BULKY_DROP_DAMAGE := 15.0
const FAKE_RADIO := ["快來這邊…", "我找到出口了，跟著我的聲音。", "你身後…不，沒事。", "別相信其他人。"]

var items: Array[Dictionary] = []
## The bulky item in this player's hands (set on every peer by BulkyCarry), or null.
var held_bulky: LootItem = null:
	set(value):
		if held_bulky == value:
			return
		held_bulky = value
		_on_held_changed()
var _grab_hold := 0.0
var _sway_time := 0.0
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
			_gun_light.visible = value and weapon.get("effects", {}).has("light")
var display_name := "拾荒者"
## Which squad this scavenger is in (set by the spawner on every peer). See Session.SQUADS.
var squad := 0
var input_enabled := true
## The gun this run: an Arsenal build and its finished stats (Arsenal.stats).
var build: Dictionary = Arsenal.STARTER.duplicate(true)
var weapon: Dictionary = {}
var mag_ammo := 0
var reserve_ammo := 0
## Seconds left on a reload; 0..1 of a railgun-style charge.
var reloading := 0.0
var charge := 0.0
var aiming := false
## Scripts and tests can hold the trigger or the aim button without real input.
var hold_trigger := false
var force_aim := false
## Replicated: the build as JSON, so other players see the gun in this player's hand.
var gun_code := "":
	set(value):
		gun_code = value
		_show_body_gun()
## A light bolted under the barrel, on whenever the lantern is (light-seeking monsters notice either).
var gun_light_on: bool:
	get: return lantern_on and gun_code.contains("flashlight")
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
var _prompt_text := ""
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
var _fire_cooldown := 0.0
var _melee_cooldown := 0.0
var _trigger_was_held := false
var _shot_count := 0
var _recoil := 0.0
var _bloom := 0.0
var _view: ViewModel
var _gun_light: SpotLight3D
var _body_gun: Node3D
var _body_muzzle := Vector3(0, 0.08, -0.6)
var _thermal := false
var _thermal_timer := 0.0
var _squeal_timer := 0.0
var _motion_timer := 0.0
var _motion_seen := {}  # monsters the watcher's eye is showing right now
var _shot_rng := RandomNumberGenerator.new()
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
var _cat_eye := 0.0
var _cat_eye_after := 0.0
var _rewind: Array[Vector3] = []
var _rewind_timer := 0.0
## Traps (scripts/traps/) set these on the owner's machine: seconds held in place
## (mash E to work free), and seconds of slowed walking at trap_slow_factor.
var snared := 0.0
var trap_slow := 0.0
var trap_slow_factor := 1.0


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

	_view = ViewModel.new()
	_view.name = "ViewModel"
	_camera.add_child(_view)

	_gun_light = SpotLight3D.new()
	_gun_light.light_color = Color(0.9, 0.95, 1.0)
	_gun_light.light_energy = 2.4
	_gun_light.spot_range = 22.0
	_gun_light.spot_angle = 13.0
	_gun_light.shadow_enabled = true
	_gun_light.position = Vector3(0.1, -0.12, -0.2)
	_gun_light.visible = false
	_camera.add_child(_gun_light)

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
	_view.visible = local
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
			".:is_dead", ".:extracted", ".:display_name", ".:carried_ids", ".:carried_tags", ".:gun_code"]:
		var node_path := NodePath(path)
		config.add_property(node_path)
		# Child nodes don't exist yet when spawn state is applied; sync them afterwards only.
		config.property_set_spawn(node_path, not path.begins_with("Head"))
		config.property_set_replication_mode(node_path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
			if path == ".:gun_code" else SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	sync.set_multiplayer_authority(get_multiplayer_authority())
	add_child(sync)


## What other players see: a hunched scavenger in a long coat and a cap, with a scarf
## over the chin, a heavy backpack and the lantern in hand, plus a name tag. Faceted
## low-poly parts facing -z (the way the player looks).
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
	var cloth := PS1Materials.get_material("concrete", Color(0.36, 0.34, 0.3), true)
	var dark := PS1Materials.get_material("concrete", Color(0.08, 0.07, 0.06), true)
	var brass := PS1Materials.get_material("brass", Color.WHITE, true)
	var glass := PS1Materials.get_material("concrete", Color(1.0, 0.9, 0.6), true)
	var add := func(mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> void:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = LootShapes.with_uvs(mesh, 2.0)
		mesh_instance.material_override = material
		mesh_instance.transform = LowPoly.at(pos, rot, scale)
		_body.add_child(mesh_instance)
	# Legs and boots.
	for side in [-1.0, 1.0]:
		add.call(LowPoly.prism(5, 0.075, 0.095, 0.5), leather, Vector3(0.12 * side, 0.33, 0.0), Vector3(-4, 0, 0))
		add.call(LowPoly.chamfer_box(Vector3(0.14, 0.11, 0.26), 0.035), dark, Vector3(0.12 * side, 0.055, -0.04))
	# The long coat: a lathed shell, flared at the hem, leaning forward into a hunch.
	var coat_profile := PackedVector2Array([Vector2(0.0, -0.52), Vector2(0.31, -0.52), Vector2(0.29, -0.3),
		Vector2(0.25, 0.0), Vector2(0.26, 0.25), Vector2(0.27, 0.4), Vector2(0.2, 0.52), Vector2(0.1, 0.56), Vector2(0.0, 0.56)])
	add.call(LowPoly.lathe(coat_profile, 8), coat, Vector3(0, 0.9, 0.02), Vector3(-9, 22.5, 0), Vector3(1.0, 1.0, 0.7))
	# Coat flaps down the front and a belt.
	add.call(LowPoly.chamfer_box(Vector3(0.05, 0.62, 0.03), 0.012), coat, Vector3(0.0, 0.66, -0.2), Vector3(-6, 0, 0))
	add.call(LowPoly.prism(8, 0.255, 0.255, 0.06), leather, Vector3(0, 0.95, 0.0), Vector3(-9, 22.5, 0), Vector3(1.0, 1.0, 0.72))
	add.call(LowPoly.chamfer_box(Vector3(0.07, 0.06, 0.03), 0.01), brass, Vector3(0, 0.95, -0.2))
	# Scarf round the neck, pulled up over the chin.
	add.call(LowPoly.lathe(PackedVector2Array([Vector2(0, -0.06), Vector2(0.15, -0.06), Vector2(0.16, 0.0),
		Vector2(0.13, 0.08), Vector2(0, 0.08)]), 7), cloth, Vector3(0, 1.46, -0.06), Vector3(-12, 0, 0), Vector3(1.0, 1.0, 0.9))
	# Head, pushed forward by the hunch: a lathed skull with a nose and two dark eyes.
	var head_profile := PackedVector2Array([Vector2(0.0, -0.13), Vector2(0.08, -0.12), Vector2(0.12, -0.04),
		Vector2(0.125, 0.05), Vector2(0.1, 0.12), Vector2(0.0, 0.15)])
	add.call(LowPoly.lathe(head_profile, 7), skin, Vector3(0, 1.6, -0.09), Vector3(-8, 0, 0), Vector3(0.95, 1.0, 1.05))
	add.call(LowPoly.prism(3, 0.025, 0.0, 0.05), skin, Vector3(0, 1.585, -0.215), Vector3(-80, 0, 0))
	for side in [-1.0, 1.0]:
		add.call(LowPoly.blob(0.018, Vector3(1.3, 0.8, 0.6), 0), dark, Vector3(0.048 * side, 1.625, -0.2))
		# Ears.
		add.call(LowPoly.blob(0.025, Vector3(0.5, 1.0, 0.8), 0), skin, Vector3(0.122 * side, 1.6, -0.08))
	# A knit cap with a short brim.
	add.call(LowPoly.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.135, 0.0), Vector2(0.14, 0.05),
		Vector2(0.12, 0.11), Vector2(0.06, 0.15), Vector2(0.0, 0.16)]), 8), leather, Vector3(0, 1.67, -0.08), Vector3(-10, 22.5, 0))
	add.call(LowPoly.extrude(PackedVector2Array([Vector2(-0.12, 0.0), Vector2(0.12, 0.0), Vector2(0.09, 0.08),
		Vector2(0.0, 0.1), Vector2(-0.09, 0.08)]), 0.02), leather, Vector3(0, 1.69, -0.2), Vector3(-80, 0, 0))
	# Arms in the coat's sleeves: the left holds the gun forward, the right the lantern.
	add.call(LowPoly.prism(5, 0.06, 0.085, 0.36), coat, Vector3(-0.27, 1.24, -0.1), Vector3(-45, 0, -6))
	add.call(LowPoly.prism(5, 0.055, 0.065, 0.32), coat, Vector3(-0.25, 1.12, -0.3), Vector3(-82, 0, 0))
	add.call(LowPoly.blob(0.055, Vector3(0.9, 1.1, 0.9), 0), skin, Vector3(-0.24, 1.1, -0.46))
	_body_gun = Node3D.new()
	_body_gun.name = "Gun"
	_body_gun.position = Vector3(-0.24, 1.09, -0.47)
	_body.add_child(_body_gun)
	add.call(LowPoly.prism(5, 0.06, 0.085, 0.36), coat, Vector3(0.27, 1.22, -0.1), Vector3(-35, 0, 8))
	add.call(LowPoly.prism(5, 0.055, 0.065, 0.34), coat, Vector3(0.29, 1.02, -0.29), Vector3(-75, 0, 0))
	add.call(LowPoly.blob(0.055, Vector3(0.9, 1.1, 0.9), 0), skin, Vector3(0.29, 0.98, -0.47))
	# The lantern hangs from that hand by its ring.
	var lantern := Vector3(0.29, 0.78, -0.48)
	add.call(LootShapes.torus(0.05, 0.008, 6, 3), brass, lantern + Vector3(0, 0.15, 0), Vector3(90, 0, 0))
	add.call(LowPoly.prism(6, 0.07, 0.03, 0.05), brass, lantern + Vector3(0, 0.09, 0))
	add.call(LowPoly.prism(6, 0.05, 0.05, 0.13), glass, lantern)
	add.call(LowPoly.prism(6, 0.07, 0.07, 0.03), brass, lantern + Vector3(0, -0.08, 0))
	for corner in 3:
		var angle := TAU * corner / 3.0 + 0.5
		add.call(LowPoly.prism(4, 0.008, 0.008, 0.14), brass, lantern + Vector3(cos(angle) * 0.058, 0, sin(angle) * 0.058))
	# The backpack: a scuffed canvas sack with a bedroll on top and two straps.
	add.call(LowPoly.chamfer_box(Vector3(0.4, 0.5, 0.22), 0.06), leather, Vector3(0, 1.06, 0.28), Vector3(-9, 0, 0))
	add.call(LowPoly.chamfer_box(Vector3(0.3, 0.16, 0.06), 0.03), leather, Vector3(0, 0.95, 0.4), Vector3(-9, 0, 0))
	add.call(LowPoly.prism(7, 0.08, 0.08, 0.46), cloth, Vector3(0, 1.38, 0.31), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		add.call(LowPoly.chamfer_box(Vector3(0.05, 0.42, 0.03), 0.01), dark, Vector3(0.14 * side, 1.16, -0.19), Vector3(-14, 0, 0))
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


## Host -> owner: one of your shots landed (drives the HUD hit marker).
@rpc("any_peer", "call_local", "reliable")
func remote_hit(damage: float, result: String) -> void:
	if not _from_host():
		return
	hit_confirmed.emit(damage, result)
	if result == "kill" or result == "break":
		Sfx.play_2d(self, "tick", -4.0, 0.6)
	elif result != "blocked":
		Sfx.play_2d(self, "tick", -12.0, 1.7)


## Host -> owner: the vampire charm feeds you a little of the damage you dealt.
@rpc("any_peer", "call_local", "reliable")
func remote_heal(amount: float) -> void:
	if not _from_host() or is_dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(health / MAX_HEALTH)


## Host -> owner: a monster or a blast shoved you.
@rpc("any_peer", "call_local", "reliable")
func remote_push(push: Vector3) -> void:
	if not _from_host() or is_dead:
		return
	velocity += push


## Host -> owner: a monster put the lantern out.
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


## Equips carry-in gear for this run. loadout = {"build": Arsenal build, "boosts": [ids]}.
## A loadout with no build (or an old {"weapon": ...} one) gets the free revolver.
func equip(loadout: Dictionary) -> void:
	var given = loadout.get("build")
	build = Arsenal.clean(given if typeof(given) == TYPE_DICTIONARY else Arsenal.STARTER)
	weapon = Arsenal.stats(build)
	mag_ammo = weapon.mag
	reserve_ammo = weapon.reserve
	reloading = 0.0
	charge = 0.0
	_fire_cooldown = 0.0
	_shot_count = 0
	boosts.clear()
	for id in loadout.get("boosts", []):
		boosts.append(id)
	gun_code = JSON.stringify(build)
	if _view != null:
		_view.set_build(build)
	lantern_on = lantern_on
	_recalculate()
	gear_changed.emit()
	if has_gear("rabbit_foot") and is_multiplayer_authority() and Run.instance != null:
		Run.instance.request_lucky.call_deferred()
		message.emit("幸運符在發燙…這局好東西比較多，但怪物也多了一隻。")


## Gear the player still has (consumed items are gone), returned on extraction:
## the weapon's frame and parts, then the boosts. The free revolver never counts.
func remaining_gear() -> Array[String]:
	var ids: Array[String] = []
	for id in Arsenal.ids(build):
		if Arsenal.price_of(id) > 0 or Arsenal.is_organ(id):
			ids.append(id)
	ids.append_array(boosts)
	return ids


func has_gear(id: String) -> bool:
	return id in boosts or id in Arsenal.ids(build)


## Mouse look, called by the main scene so it works through the low-res SubViewport.
func look(relative: Vector2) -> void:
	if not input_enabled or is_dead:
		return
	# Something heavy in your arms turns you slowly.
	var turn := 1.0 - clampf(bulky_load() / 180.0, 0.0, 0.6)
	rotate_y(-relative.x * MOUSE_SENSITIVITY * turn)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(85.0))


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func head_position() -> Vector3:
	return _head.global_position


func take_damage(amount: float, cause: String) -> void:
	if is_dead:
		return
	if aiming and weapon.get("effects", {}).has("guard"):
		amount *= 1.0 - float(weapon.effects.guard)  # the knight's door, held up in front
	health = maxf(health - amount, 0.0)
	health_changed.emit(health / MAX_HEALTH)
	add_shake(0.4)
	if amount >= BULKY_DROP_DAMAGE and held_bulky != null and health > 0.0:
		message.emit("被打得鬆手了！%s掉在地上。" % held_bulky.item_name)
		release_bulky()
	if health <= 0.0:
		die(cause)


func die(cause: String) -> void:
	if is_dead:
		return
	if "second_life" in boosts and not _rewind.is_empty():
		_rewind_time()
		return
	release_bulky()
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
	_bitten = maxf(_bitten - delta, 0.0)
	_update_boost_timers(delta)
	_update_weapon(delta)
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

	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and snared <= 0.0 \
			and held_bulky == null:
		var jump := JUMP_VELOCITY * _weight_factor()
		if has_gear("spring_boots"):
			jump *= SPRING_JUMP_MULT
		velocity.y = jump

	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var sprinting := input_enabled and Input.is_action_pressed("sprint") and not is_crouching \
		and input_dir.length() > 0.1 and not _exhausted and _crash <= 0.0 and held_bulky == null
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
	speed *= bulky_factor()
	if aiming:
		speed *= AIM_WALK
	if trap_slow > 0.0:
		trap_slow -= delta
		speed *= trap_slow_factor
	if snared > 0.0:
		snared = maxf(snared - delta, 0.0)
		speed = 0.0
		if input_enabled and Input.is_action_just_pressed("interact"):
			snared = maxf(snared - 0.45, 0.0)

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
	if held_bulky != null and not is_instance_valid(held_bulky):
		held_bulky = null
	if held_bulky != null and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("drop")):
		release_bulky()
		_grab_hold = -1.0  # don't start grabbing it again until E is let go
	else:
		_update_grab(delta)
		if Input.is_action_just_pressed("interact") and is_instance_valid(_focused):
			_focused.interact(self)
			_focused = null
		if Input.is_action_just_pressed("drop"):
			drop_last()
	if Input.is_action_just_pressed("lantern"):
		set_lantern(not lantern_on)
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


## Empties the backpack and returns what was in it (used by extraction), plus the bulky
## item in your hands and any bulky item set down (not held) inside the extraction pad.
func take_all_items() -> Array[Dictionary]:
	var taken: Array[Dictionary] = items.duplicate()
	for haul in bulky_to_extract():
		taken.append(haul.to_data())
		haul.carry.request_claim()
	held_bulky = null
	items.clear()
	_recalculate()
	return taken


# --- Bulky hauls -----------------------------------------------------------------------

## Hold E on a bulky item to lift it (or to take the other end from a teammate).
func _update_grab(delta: float) -> void:
	if not Input.is_action_pressed("interact"):
		_grab_hold = 0.0
		return
	var target := _focused as LootItem
	if target == null or target.carry == null or held_bulky != null or _grab_hold < 0.0:
		return
	_grab_hold += delta
	if _grab_hold >= BULKY_GRAB_TIME:
		_grab_hold = -1.0
		grab_bulky(target)


## Ask the host to put this bulky item in our hands.
func grab_bulky(target: LootItem) -> void:
	if target == null or target.carry == null or held_bulky != null or not is_active():
		return
	target.carry.request_grab()


## Let go of the bulky item: it drops in front of you (with a bang).
func release_bulky() -> void:
	if held_bulky == null:
		return
	if is_instance_valid(held_bulky) and held_bulky.carry != null and is_inside_tree():
		held_bulky.carry.request_release(velocity * 0.5)
	held_bulky = null


## How many kilograms of bulky haul this player feels in their arms right now.
func bulky_load() -> float:
	if held_bulky == null or not is_instance_valid(held_bulky):
		return 0.0
	var felt := held_bulky.weight
	if held_bulky.carry != null and held_bulky.carry.holders.size() >= 2:
		felt *= CO_CARRY_SHARE
	if has_gear("exoskeleton"):
		felt *= EXO_BULKY_SHARE
	return felt


## Walking speed multiplier from the bulky haul (1 with empty hands).
func bulky_factor() -> float:
	if held_bulky == null:
		return 1.0
	return 1.0 - clampf(0.12 + bulky_load() / 150.0, 0.0, 0.72)


## Bulky items this player takes out when extracting: the one in hand, and any left
## lying (not held by anyone) on the extraction pad.
func bulky_to_extract() -> Array[LootItem]:
	var result: Array[LootItem] = []
	if held_bulky != null and is_instance_valid(held_bulky) and not held_bulky.is_queued_for_deletion():
		result.append(held_bulky)
	var zone: ExtractionZone = null
	if Run.instance != null and Run.instance.level != null:
		zone = Run.instance.level.extraction_zone
	if zone == null or not zone.is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group("loot"):
		var haul := node as LootItem
		if haul == null or haul.carry == null or haul.carry.is_held() or haul in result or haul.is_queued_for_deletion():
			continue
		var local := zone.to_local(haul.global_position).abs()
		if local.x < zone.size.x / 2.0 + 0.3 and local.z < zone.size.z / 2.0 + 0.3 and local.y < zone.size.y / 2.0 + 0.5:
			result.append(haul)
	return result


func _on_held_changed() -> void:
	_grab_hold = -1.0 if held_bulky != null else _grab_hold
	if _view != null:
		_view.visible = is_multiplayer_authority() and held_bulky == null
	if _body_gun != null:
		_body_gun.visible = held_bulky == null
	if not is_multiplayer_authority() or not is_inside_tree():
		return
	if held_bulky != null:
		aiming = false
		charge = 0.0
		var share := " 有人幫你抬，輕多了。" if held_bulky.carry != null and held_bulky.carry.holders.size() >= 2 else ""
		message.emit("搬起了%s（%.0fkg）。不能開槍、不能跑。E 放下。%s" % [held_bulky.item_name, held_bulky.weight, share])
		if held_bulky.data.has("note") and (held_bulky.carry == null or held_bulky.carry.holders.size() < 2):
			message.emit(held_bulky.data.note)
	_recalculate()


## Whether monsters see this player as lit: lantern on, or on a map with no shadows.
func is_lit() -> bool:
	return lantern_on or (Run.instance != null and Run.instance.level != null and Run.instance.level.bright)


func set_lantern(on: bool) -> void:
	lantern_on = on


# --- Weapon: the build's gun and the knife ------------------------------------------

## One pull of the trigger. Host resolves what it hits (Run.request_shot). False when
## it didn't fire (cooling down, reloading, empty: an empty pull starts a reload).
func fire() -> bool:
	if weapon.is_empty() or reloading > 0.0 or _fire_cooldown > 0.0 or is_dead:
		return false
	if _bitten > 0.0:
		message.emit("手被咬住了，開不了槍！")
		_fire_cooldown = 0.5
		return false
	if mag_ammo <= 0:
		_fire_cooldown = 0.3
		Sfx.play_2d(self, "tick", -6.0, 1.3)
		if reserve_ammo > 0:
			reload()
		else:
			message.emit("%s沒有子彈了。只剩小刀（V）。" % Arsenal.name_of(build.frame))
		return false
	_fire_cooldown = 1.0 / maxf(weapon.rate, 0.05)
	_shot_count += 1
	var ghost := int(weapon.effects.get("ghost", 0))
	if ghost <= 0 or _shot_count % ghost != 0:
		mag_ammo -= 1
	var origin := _camera.global_position
	var forward := -_camera.global_basis.z
	var spread := current_spread()
	var directions: Array[Vector3] = []
	for i in int(weapon.pellets):
		directions.append(Run.scatter(forward, spread, _shot_rng))
	if Run.instance != null:
		Run.instance.request_shot(build, origin, directions)
	var kick: float = weapon.recoil * (0.6 if aiming else 1.0)
	_recoil = minf(_recoil + kick, 25.0)
	_bloom = minf(_bloom + kick * 0.35 + weapon.spread * 0.15, 8.0)
	rotate_y(deg_to_rad(_shot_rng.randf_range(-1.0, 1.0) * kick * 0.15))
	add_shake(clampf(kick * 0.03, 0.0, 0.35))
	if _view != null:
		_view.kick(weapon.recoil, weapon.kind != "cone")
	return true


## R: refill the magazine from the reserve.
func reload() -> bool:
	if weapon.is_empty() or reloading > 0.0 or mag_ammo >= int(weapon.mag) or reserve_ammo <= 0 or is_dead:
		return false
	reloading = weapon.reload
	charge = 0.0
	if _view != null:
		_view.reload(weapon.reload)
	Sfx.play_3d(get_parent(), global_position, "clank", -12.0, 12.0, 1.5)
	GameNoise.emit(get_tree(), global_position, 4.0, GameNoise.Kind.TOOL)
	return true


func _finish_reload() -> void:
	var take := mini(int(weapon.mag) - mag_ammo, reserve_ammo)
	mag_ammo += take
	reserve_ammo -= take
	Sfx.play_3d(get_parent(), global_position, "clank", -10.0, 12.0, 2.0)


## V: the knife. Pries open lockers (and pokes mimics) when you're looking at one;
## otherwise a short stab the host resolves. The bayonet part makes it hit harder.
func melee() -> bool:
	if _melee_cooldown > 0.0 or is_dead:
		return false
	if _bitten > 0.0:
		message.emit("手被咬住了！")
		return false
	_melee_cooldown = KNIFE_COOLDOWN
	if _view != null:
		_view.stab()
	if reloading > 0.0:
		reloading = 0.0
		if _view != null:
			_view.cancel_reload()
	Sfx.play_3d(get_parent(), global_position, "thump", -14.0, 10.0, 2.2)
	GameNoise.emit(get_tree(), global_position, 3.0, GameNoise.Kind.TOOL)
	if is_instance_valid(_focused) and _focused.has_method("pry"):
		_focused.pry(self)
		return true
	if Run.instance != null:
		Run.instance.request_melee(_camera.global_position, -_camera.global_basis.z, weapon.get("effects", {}).has("bayonet"),
				weapon.get("effects", {}).has("fang"))
	return true


## Degrees of random cone the next shot gets: aiming halves it, moving and firing widen it.
func current_spread() -> float:
	if weapon.is_empty():
		return 0.0
	var base: float = weapon.spread * (0.5 if aiming else 1.0)
	var moving := clampf(ground_speed / SPRINT_SPEED, 0.0, 1.0)
	return base * (1.0 + moving * 0.8) + _bloom * (0.5 if aiming else 1.0)


## The camera's field of view right now (narrower while aiming a zoomed sight).
func view_fov() -> float:
	return _camera.fov


## Where the barrel is: the viewmodel's muzzle for the local player, the gun in the
## hand for everyone else.
func muzzle_position() -> Vector3:
	if is_multiplayer_authority() and _view != null and _view.visible:
		return _view.muzzle_global()
	if _body_gun != null and _body_gun.is_inside_tree():
		return _body_gun.to_global(_body_muzzle)
	return head_position()


## Trigger, aim, reload and knife input, charging, recoil recovery. Owner only.
func _update_weapon(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	_recoil = move_toward(_recoil, 0.0, delta * (5.0 + _recoil * 5.0))
	_bloom = move_toward(_bloom, 0.0, delta * (2.0 + _bloom * 3.0))
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			reloading = 0.0
			_finish_reload()
	var can_act := input_enabled and not is_dead and held_bulky == null
	aiming = can_act and reloading <= 0.0 and (force_aim or Input.is_action_pressed("aim"))
	var held := can_act and (hold_trigger or Input.is_action_pressed("use_weapon"))
	var pressed := held and not _trigger_was_held
	_trigger_was_held = held
	if can_act and Input.is_action_just_pressed("reload"):
		reload()
	if can_act and Input.is_action_just_pressed("melee"):
		melee()
	if weapon.is_empty():
		return
	if weapon.kind == "charge":
		if held and mag_ammo > 0 and reloading <= 0.0 and _fire_cooldown <= 0.0 and _bitten <= 0.0:
			if charge == 0.0:
				Sfx.play_2d(self, "zap", -8.0, 0.5)
			charge = minf(charge + delta / CHARGE_TIME, 1.0)
			add_shake(0.02 + charge * 0.04)
			if charge >= 1.0:
				charge = 0.0
				fire()
		else:
			charge = 0.0
			if pressed:
				fire()
	elif pressed or (held and weapon.auto):
		fire()
	if _view != null:
		_view.aiming = aiming
	_update_thermal(delta)
	_update_organ_sight(delta)


## A thermal sight shows every monster through walls (and the invisible ones) while aiming.
func _update_thermal(delta: float) -> void:
	var want: bool = aiming and weapon.get("effects", {}).has("thermal")
	_thermal_timer -= delta
	if want == _thermal and (not want or _thermal_timer > 0.0):
		return
	_thermal_timer = 0.5
	_thermal = want
	var overlay := ShotFx.glow(Color(1.0, 0.45, 0.1, 0.55), false, true)
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("set_spotted"):
			monster.set_spotted(want or _cat_eye > 0.0)
		for mesh in monster.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			if want and instance.material_overlay == null:
				instance.material_overlay = overlay
			elif not want and instance.material_overlay == overlay:
				instance.material_overlay = null


## Organ sights. The watcher's eye shows, while aiming, every monster that is moving
## (through walls); the drift eye's lens squeals while you aim it, and things hear that.
func _update_organ_sight(delta: float) -> void:
	var effects: Dictionary = weapon.get("effects", {})
	if aiming and effects.has("squeal"):
		_squeal_timer -= delta
		if _squeal_timer <= 0.0:
			_squeal_timer = 1.6
			GameNoise.emit(get_tree(), global_position, 16.0, GameNoise.Kind.VOICE)
			Sfx.play_3d(get_parent(), global_position, "screech", -14.0, 18.0, 2.4)
	var want: bool = aiming and effects.has("motion_sight")
	if not want and _motion_seen.is_empty():
		return
	_motion_timer -= delta
	if want and _motion_timer > 0.0:
		return
	_motion_timer = 0.2
	var overlay := ShotFx.glow(Color(1.0, 0.95, 0.3, 0.6), false, true)
	var seen := {}
	if want:
		for monster in get_tree().get_nodes_in_group("monsters"):
			if not monster is Node3D:
				continue
			var at: Vector3 = (monster as Node3D).global_position
			var last: Vector3 = monster.get_meta("eye_last", at)
			monster.set_meta("eye_last", at)
			if at.distance_to(last) > 0.08 and at.distance_to(global_position) < 60.0:
				seen[monster] = true
	for monster in _motion_seen.keys() + seen.keys():
		if not is_instance_valid(monster):
			continue
		var show: bool = seen.has(monster)
		for mesh in monster.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			if show and instance.material_overlay == null:
				instance.material_overlay = overlay
			elif not show and instance.material_overlay == overlay:
				instance.material_overlay = null
	_motion_seen = seen


## Remote copies: the gun in the left hand, rebuilt when the replicated build changes.
func _show_body_gun() -> void:
	if _body_gun == null:
		return
	for child in _body_gun.get_children():
		child.queue_free()
	if gun_code == "":
		return
	var parsed = JSON.parse_string(gun_code)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var model := GunModels.build(parsed)
	_body_muzzle = GunModels.muzzle_point(parsed)
	_body_gun.add_child(model)
	_body_gun.scale = Vector3.ONE * 0.85


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
	# What's in your arms counts for monsters (a noisy crate, a cursed statue) but not
	# for the backpack's weight.
	if held_bulky != null and is_instance_valid(held_bulky):
		ids.append(held_bulky.data.id)
		for tag in held_bulky.data.get("tags", []):
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
	for id in boosts:
		total += float(Gear.info(id).get("weight", 0.0))
	total += float(weapon.get("weight", 0.0))
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
	# Recoil kicks the view up; it settles back as the gun recovers.
	_camera.rotation.x = deg_to_rad(_recoil)
	# A heavy haul sways the view side to side with every step, and a little when still.
	var heft := clampf(bulky_load() / 90.0, 0.0, 1.0)
	_sway_time += delta * (1.0 + speed * 1.1)
	var sway := sin(_sway_time * 1.3) * heft
	_camera.rotation.z = lerpf(_camera.rotation.z, deg_to_rad(sway * 4.5), minf(6.0 * delta, 1.0))
	_camera.position += Vector3(sway * 0.05, -heft * 0.06 + absf(sway) * -0.03, 0.0)
	var zoom: float = weapon.get("zoom", 1.0) if aiming else 1.0
	_camera.fov = lerpf(_camera.fov, BASE_FOV / maxf(zoom, 1.0), minf(14.0 * delta, 1.0))


func _update_focus() -> void:
	_ray.force_raycast_update()
	var target: Node = null
	var hit := _ray.get_collider()
	if hit != null and hit.has_method("interact"):
		target = hit
	_focused = target
	# Compare the text, not the node: a picked-up item can vanish (freed, or hidden while
	# the host confirms) without the ray ever reporting a different target, and prompts
	# like lockers change while you look at them.
	var text: String = target.get_prompt(self) if target != null else ""
	if text != _prompt_text:
		_prompt_text = text
		prompt_changed.emit(text)


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


## Cat-eye drops and the rewind watch's memory of where you were.
func _update_gadgets(delta: float) -> void:
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
