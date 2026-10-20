class_name LootItem
extends RigidBody3D
## A pick-up-able piece of loot. Spawned frozen so it stays where it was placed;
## items the player drops are unfrozen, fall with physics, and make noise on impact.

const FRAGILE_BREAK_SPEED := 4.0
const FRAGILE_VALUE_LOSS := 0.25

var data: Dictionary = {}

var item_name: String:
	get: return data.name
var value: int:
	get: return data.value
var weight: float:
	get: return data.weight


static func from_data(item_data: Dictionary) -> LootItem:
	var item := LootItem.new()
	item.data = item_data.duplicate(true)
	return item


func _ready() -> void:
	add_to_group("loot")
	# Loot sits on its own layer so it never blocks the player's movement.
	collision_layer = Layers.LOOT
	collision_mask = Layers.WORLD | Layers.WALKWAY
	mass = maxf(weight, 0.2)
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)

	var size: Vector3 = data.size
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = PS1Materials.get_material(data.texture, data.color, true)
	add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	add_child(collider)

	# Rare loot glints so it reads in the dark.
	if data.rarity >= 2:
		var glint := OmniLight3D.new()
		glint.light_color = LootTable.RARITY_COLORS[data.rarity]
		glint.light_energy = 0.4
		glint.omni_range = 1.2
		add_child(glint)


func to_data() -> Dictionary:
	return data.duplicate(true)


func get_prompt(_player: Player = null) -> String:
	var tags := ""
	if LootTable.has_tag(data, "fragile"):
		tags += "　易碎"
	if LootTable.has_tag(data, "noisy"):
		tags += "　吵鬧"
	return "[E] 撿起 %s　$%d　%.1fkg%s" % [item_name, value, weight, tags]


func interact(player: Player) -> void:
	if player.pickup(to_data()):
		Sfx.play_3d(get_parent(), global_position, "pickup", -6.0)
		queue_free()


func _on_body_entered(_body: Node) -> void:
	var speed := linear_velocity.length()
	if speed < 1.5:
		return
	Sfx.play_3d(get_parent(), global_position, "tink", -4.0, 30.0, randf_range(0.7, 1.3))
	GameNoise.emit(get_tree(), global_position, clampf(speed * 3.0, 4.0, 16.0), GameNoise.Kind.IMPACT)
	if speed > FRAGILE_BREAK_SPEED and LootTable.has_tag(data, "fragile"):
		data.value = int(data.value * (1.0 - FRAGILE_VALUE_LOSS))
