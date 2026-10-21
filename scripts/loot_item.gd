class_name LootItem
extends RigidBody3D
## A pick-up-able piece of loot. Spawned frozen so it stays where it was placed;
## items the player drops are unfrozen, fall with physics, and make noise on impact.

const FRAGILE_BREAK_SPEED := 4.0
const FRAGILE_VALUE_LOSS := 0.25

var data: Dictionary = {}
## Set on bulky items: who is carrying it (see BulkyCarry).
var carry: BulkyCarry = null

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
	if Organs.is_organ(data):
		# A monster's organ: its own gory low-poly model (the same one the gun wears).
		var model := Organs.floor_model(str(data.organ), size)
		model.name = "Organ"
		add_child(model)
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = LootShapes.mesh_for(data)
		mesh_instance.material_override = PS1Materials.get_material(data.texture, data.color, true)
		add_child(mesh_instance)
		var trim := LootShapes.trim_mesh_for(data)
		if trim != null:
			var trim_instance := MeshInstance3D.new()
			trim_instance.mesh = trim
			trim_instance.material_override = LootShapes.trim_material(data)
			add_child(trim_instance)
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

	# Bulky hauls are carried in both hands (see BulkyCarry), not put in the backpack.
	if LootTable.is_bulky(data):
		mass = maxf(weight, 1.0)
		carry = BulkyCarry.new()
		carry.name = "Carry"
		add_child(carry)

	# Living loot won't stay put.
	if LootTable.has_tag(data, "alive") and multiplayer.is_server():
		freeze = false
		var hop := Timer.new()
		hop.wait_time = randf_range(2.5, 5.0)
		hop.autostart = true
		hop.timeout.connect(_hop)
		add_child(hop)

	# Organs twitch (the living ones), and glow a dull red so they read in the dark.
	if Organs.is_organ(data):
		var ember := OmniLight3D.new()
		ember.light_color = Color(1.0, 0.25, 0.15)
		ember.light_energy = 0.35
		ember.omni_range = 1.4
		add_child(ember)
		if LootTable.has_tag(data, "alive"):
			var twitch := Timer.new()
			twitch.wait_time = randf_range(3.0, 6.0)
			twitch.autostart = true
			twitch.timeout.connect(_twitch)
			add_child(twitch)
	# Rare loot glints so it reads in the dark.
	elif data.rarity >= 2:
		var glint := OmniLight3D.new()
		glint.light_color = LootTable.RARITY_COLORS[data.rarity]
		glint.light_energy = 0.4
		glint.omni_range = 1.2
		add_child(glint)


func to_data() -> Dictionary:
	return data.duplicate(true)


func get_prompt(player: Player = null) -> String:
	if carry != null:
		if player != null and player.held_bulky != null:
			return ""
		if carry.holders.size() >= BulkyCarry.MAX_HOLDERS:
			return ""
		if carry.is_held():
			return "[按住 E] 幫忙抬 %s　%.0fkg（兩個人抬輕很多）" % [item_name, weight]
	return LootTable.prompt(data)


func interact(player: Player) -> void:
	if carry != null:
		# Bulky: hold E (Player._update_grab) rather than a tap.
		return
	# The owner checks the backpack grid first; the host only decides who gets it.
	if not player.can_carry(data):
		player.say_bag_full(data)
		return
	# The host decides who gets it, so two players can't grab the same item.
	if Run.instance != null:
		Run.instance.request_pickup(self)
	elif player.pickup(to_data()):
		queue_free()


## A living organ on the floor: it jerks and squelches, and that is noise.
func _twitch() -> void:
	var model := get_node_or_null("Organ") as Node3D
	if model != null:
		var tween := create_tween()
		tween.tween_property(model, "scale", Vector3(1.15, 0.85, 1.1), 0.08)
		tween.tween_property(model, "scale", Vector3(0.92, 1.1, 0.95), 0.1)
		tween.tween_property(model, "scale", Vector3.ONE, 0.15)
	Sfx.play_3d(get_parent(), global_position, "bite", -10.0, 14.0, randf_range(0.5, 0.8))
	if multiplayer.is_server():
		Organs.host_twitch(self)


func _hop() -> void:
	if linear_velocity.length() < 0.3:
		apply_central_impulse(Vector3(randf_range(-1.0, 1.0), 2.2, randf_range(-1.0, 1.0)) * mass)


func _on_body_entered(_body: Node) -> void:
	if not multiplayer.is_server():
		return
	var speed := linear_velocity.length()
	if speed < 1.5:
		return
	if carry != null:
		# Something this big hitting the floor or a wall is a bang, not a tink.
		if speed > 3.0:
			carry.host_thud(clampf(speed / 6.0, 0.3, 1.0))
		if speed > FRAGILE_BREAK_SPEED and LootTable.has_tag(data, "fragile"):
			data.value = int(data.value * (1.0 - FRAGILE_VALUE_LOSS))
		return
	Sfx.play_3d(get_parent(), global_position, "tink", -4.0, 30.0, randf_range(0.7, 1.3))
	GameNoise.emit(get_tree(), global_position, clampf(speed * 3.0, 4.0, 16.0), GameNoise.Kind.IMPACT)
	if speed > FRAGILE_BREAK_SPEED and LootTable.has_tag(data, "fragile"):
		data.value = int(data.value * (1.0 - FRAGILE_VALUE_LOSS))
