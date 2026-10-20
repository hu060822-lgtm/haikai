class_name Player
extends CharacterBody3D
## First-person scavenger: walk, sprint, crouch through pipes, carry loot.
## Carried weight slows the player down, so greed has a cost.

signal inventory_changed(items: Array, weight: float, value: int)
signal prompt_changed(text: String)
signal stamina_changed(ratio: float)
signal message(text: String)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.5
const CROUCH_SPEED := 1.6
const JUMP_VELOCITY := 4.2
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 0.9
const RADIUS := 0.3
const EYE_OFFSET := 0.15
const MAX_CARRY_WEIGHT := 30.0
const INTERACT_DISTANCE := 2.2
const MOUSE_SENSITIVITY := 0.0025
const STAMINA_DRAIN := 0.25
const STAMINA_REGEN := 0.15
const STAMINA_RECOVER_THRESHOLD := 0.3

var items: Array[Dictionary] = []
var carried_weight := 0.0
var carried_value := 0
var stamina := 1.0
var is_crouching := false
var lantern_on := true
var input_enabled := true

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


func _ready() -> void:
	add_to_group("player")
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
	_ray.collision_mask = 1 | 2  # world + loot
	_ray.add_exception(self)
	_camera.add_child(_ray)

	_ceiling_check = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS - 0.05
	_ceiling_check.shape = sphere
	_ceiling_check.position.y = CROUCH_HEIGHT
	_ceiling_check.target_position = Vector3(0.0, STAND_HEIGHT - CROUCH_HEIGHT - sphere.radius, 0.0)
	_ceiling_check.add_exception(self)
	add_child(_ceiling_check)


## Mouse look, called by the main scene so it works through the low-res SubViewport.
func look(relative: Vector2) -> void:
	if not input_enabled:
		return
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(85.0))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if input_enabled and Input.is_action_pressed("crouch"):
		_set_crouch(true)
	elif is_crouching and _can_stand():
		_set_crouch(false)

	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY * _weight_factor()

	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var sprinting := input_enabled and Input.is_action_pressed("sprint") and not is_crouching \
		and input_dir.length() > 0.1 and not _exhausted
	_update_stamina(sprinting, delta)

	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	speed *= _weight_factor()

	var accel := 10.0 if is_on_floor() else 2.0
	velocity.x = lerpf(velocity.x, direction.x * speed, accel * delta)
	velocity.z = lerpf(velocity.z, direction.z * speed, accel * delta)
	move_and_slide()

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


func _recalculate() -> void:
	carried_weight = 0.0
	carried_value = 0
	for item in items:
		carried_weight += item.weight
		carried_value += item.value
	inventory_changed.emit(items, carried_weight, carried_value)


func _weight_factor() -> float:
	return 1.0 - 0.4 * clampf(carried_weight / MAX_CARRY_WEIGHT, 0.0, 1.0)


func _update_stamina(sprinting: bool, delta: float) -> void:
	var before := stamina
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina == 0.0:
			_exhausted = true
	else:
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


func _update_focus() -> void:
	_ray.force_raycast_update()
	var target: Node = null
	var hit := _ray.get_collider()
	if hit != null and hit.has_method("interact"):
		target = hit
	if target != _focused or (_focused != null and not is_instance_valid(_focused)):
		_focused = target
		prompt_changed.emit(target.get_prompt() if target != null else "")
