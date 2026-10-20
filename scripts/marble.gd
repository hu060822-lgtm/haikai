class_name Marble
extends RigidBody3D
## Slingshot ammo. The first hard impact makes a loud noise at the landing spot,
## which is the whole point: throw your voice across the room.

const NOISE_RADIUS := 20.0

var _sounded := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.WALKWAY | Layers.MONSTER | Layers.LOOT
	mass = 0.05
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	# A faceted glass marble (a split icosahedron) with a coloured swirl band.
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = LootShapes.with_uvs(LowPoly.blob(0.04, Vector3.ONE, 1), 12.0)
	mesh_instance.material_override = PS1Materials.get_material("brass", Color(0.6, 0.9, 1.0), true)
	add_child(mesh_instance)
	var swirl := MeshInstance3D.new()
	swirl.mesh = LowPoly.prism(8, 0.041, 0.041, 0.012)
	swirl.rotation = Vector3(0.6, 0.0, 0.9)
	swirl.material_override = PS1Materials.get_material("concrete", Color(0.15, 0.4, 0.9), true)
	mesh_instance.add_child(swirl)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.04
	collider.shape = shape
	add_child(collider)
	get_tree().create_timer(8.0).timeout.connect(queue_free)


func _on_body_entered(body: Node) -> void:
	if _sounded:
		return
	_sounded = true
	if body.has_method("weapon_hit"):
		body.weapon_hit()
	Sfx.play_3d(get_parent(), global_position, "tink", 2.0, 45.0)
	GameNoise.emit(get_tree(), global_position, NOISE_RADIUS, GameNoise.Kind.IMPACT)
