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
	mesh_instance.mesh = LootShapes.mesh_for(data)
	mesh_instance.material_override = PS1Materials.get_material(data.texture, data.color, true)
	add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	add_child(collider)

	# The host simulates loot physics; everyone else follows its transform.
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for path in [NodePath(".:position"), NodePath(".:rotation")]:
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	add_child(sync)

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
	return LootTable.prompt(data)


func interact(player: Player) -> void:
	if not player.can_carry(data):
		player.message.emit("太重了，背不動")
		return
	# The host decides who gets it, so two players can't grab the same item.
	if Run.instance != null:
		Run.instance.request_pickup(self)
	elif player.pickup(to_data()):
		queue_free()


func _on_body_entered(_body: Node) -> void:
	if not multiplayer.is_server():
		return
	var speed := linear_velocity.length()
	if speed < 1.5:
		return
	Sfx.play_3d(get_parent(), global_position, "tink", -4.0, 30.0, randf_range(0.7, 1.3))
	GameNoise.emit(get_tree(), global_position, clampf(speed * 3.0, 4.0, 16.0), GameNoise.Kind.IMPACT)
	if speed > FRAGILE_BREAK_SPEED and LootTable.has_tag(data, "fragile"):
		data.value = int(data.value * (1.0 - FRAGILE_VALUE_LOSS))
