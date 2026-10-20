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

var items: Array[Dictionary] = []
var carried_weight := 0.0
var carried_value := 0
var health := MAX_HEALTH
var stamina := 1.0
var is_crouching := false
var is_dead := false
var lantern_on := true
var input_enabled := true
var weapon_id := ""
var weapon_ammo := 0
var boosts: Array[String] = []

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
	_head.position.y = STAND_HEIGHT - EYE_OFFSET
	add_child(_head)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.05
	_camera.far = 60.0
	_camera.current = true
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


## Equips carry-in gear for this run. loadout = {"weapon": id, "boosts": [ids]}.
func equip(loadout: Dictionary) -> void:
	weapon_id = loadout.get("weapon", "")
	weapon_ammo = Gear.info(weapon_id).get("ammo", 0)
	boosts.clear()
	for id in loadout.get("boosts", []):
		boosts.append(id)
	_recalculate()
	gear_changed.emit()


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

	_weapon_cooldown = maxf(_weapon_cooldown - delta, 0.0)
	_update_boost_timers(delta)
	var climbing := _ladders > 0

	if not is_on_floor() and not climbing:
		velocity.y -= _gravity * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	if input_enabled and Input.is_action_pressed("crouch"):
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
	speed *= _weight_factor()

	if climbing:
		# Forward climbs, back descends; you can still step off sideways or forward at the top.
		velocity.y = -input_dir.y * CLIMB_SPEED
		speed *= 0.6
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity = transform.basis.z * 3.0
			_ladders = 0

	var accel := 10.0 if is_on_floor() or climbing else 2.0
	velocity.x = lerpf(velocity.x, direction.x * speed, accel * delta)
	velocity.z = lerpf(velocity.z, direction.z * speed, accel * delta)
	move_and_slide()

	_handle_landing()
	_update_footsteps(delta, input_dir.length() > 0.1 and is_on_floor(), sprinting)
	_update_noisy_items(delta)
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


func pickup(data: Dictionary) -> bool:
	if carried_weight + data.weight > MAX_CARRY_WEIGHT:
		message.emit("太重了，背不動")
		return false
	items.append(data)
	_recalculate()
	return true


func drop_last() -> void:
	if items.is_empty():
		return
	var data: Dictionary = items.pop_back()
	_recalculate()
	var item := LootItem.from_data(data)
	get_parent().add_child(item)
	item.global_position = _camera.global_position - _camera.global_basis.z * 0.8
	item.linear_velocity = -_camera.global_basis.z * 2.0


## Empties the backpack and returns what was in it (used by extraction).
func take_all_items() -> Array[Dictionary]:
	var taken: Array[Dictionary] = items.duplicate()
	items.clear()
	_recalculate()
	return taken


func set_lantern(on: bool) -> void:
	lantern_on = on
	_lantern.visible = on
	_lantern_glow.visible = on


func use_weapon() -> void:
	if weapon_id == "" or _weapon_cooldown > 0.0:
		return
	match weapon_id:
		"crowbar":
			_weapon_cooldown = 0.6
			if is_instance_valid(_focused) and _focused.has_method("pry"):
				_focused.pry(self)
			else:
				Sfx.play_3d(get_parent(), global_position, "clank", -10.0, 20.0, 1.4)
				GameNoise.emit(get_tree(), global_position, 6.0, GameNoise.Kind.TOOL)
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


func use_boost() -> void:
	if "adrenaline" in boosts:
		boosts.erase("adrenaline")
		_adrenaline = ADRENALINE_TIME
		stamina = 1.0
		_exhausted = false
		stamina_changed.emit(stamina)
		Sfx.play_2d(self, "heartbeat", -2.0, 1.3)
		message.emit("腎上腺素！")
		_recalculate()
		gear_changed.emit()


func _update_boost_timers(delta: float) -> void:
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
		GameNoise.emit(get_tree(), global_position, STEP_NOISE[gait], GameNoise.Kind.FOOTSTEP)
		var volume := -22.0 if is_crouching else (-8.0 if sprinting else -14.0)
		Sfx.play_3d(get_parent(), global_position, "step", volume, 20.0, randf_range(0.85, 1.15))


func _update_noisy_items(delta: float) -> void:
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


func _recalculate() -> void:
	carried_weight = 0.0
	carried_value = 0
	for item in items:
		carried_weight += item.weight
		carried_value += item.value
	inventory_changed.emit(items, carried_weight, carried_value)


func _gear_weight() -> float:
	var total := 0.0
	for id in remaining_gear():
		total += Gear.info(id).get("weight", 0.0)
	return total


func _weight_factor() -> float:
	var total_load := carried_weight + _gear_weight()
	return 1.0 - 0.4 * clampf(total_load / MAX_CARRY_WEIGHT, 0.0, 1.0)


func _update_stamina(sprinting: bool, delta: float) -> void:
	var before := stamina
	if sprinting and _adrenaline <= 0.0:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina == 0.0:
			_exhausted = true
	elif not sprinting:
		stamina = minf(stamina + STAMINA_REGEN * delta, 1.0)
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
