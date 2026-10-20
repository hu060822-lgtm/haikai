class_name MonsterKit
## Shared helpers for monsters: low-poly parts, replication setup and player queries.


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_instance.scale = squash
	parent.add_child(mesh_instance)
	return mesh_instance


## A pivot node with a limb hanging down from it, for simple joint animation.
static func limb(parent: Node3D, pivot: Vector3, size: Vector3, material: Material) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	parent.add_child(joint)
	box(joint, size, Vector3(0, -size.y / 2.0, 0), material)
	return joint


## Any LowPoly mesh as a part of a model.
static func part(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material,
		rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.transform = LowPoly.at(pos, rot_deg, scale)
	parent.add_child(mesh_instance)
	return mesh_instance


## A pivot node with a tapered n-sided limb hanging down from it (top radius at the joint).
static func taper_limb(parent: Node3D, pivot: Vector3, length: float, top: float, bottom: float,
		material: Material, sides := 5) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	parent.add_child(joint)
	part(joint, LowPoly.prism(sides, bottom, top, length), Vector3(0, -length / 2.0, 0), material)
	return joint


## Host-authoritative replication of the given properties (".:position" style paths).
static func add_sync(node: Node, properties: Array) -> MultiplayerSynchronizer:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for path in properties:
		var node_path := NodePath(path)
		config.add_property(node_path)
		config.property_set_spawn(node_path, true)
		config.property_set_replication_mode(node_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	node.add_child(sync)
	return sync


static func active_players(tree: SceneTree) -> Array[Player]:
	var result: Array[Player] = []
	for node in tree.get_nodes_in_group("player"):
		if node is Player and node.is_active():
			result.append(node)
	return result


static func nearest_player(from: Node3D, max_distance := INF) -> Player:
	var best: Player = null
	var best_distance := max_distance
	for player in active_players(from.get_tree()):
		var distance := from.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


## True if no level geometry is between the two points (players don't block).
static func clear_line(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = Layers.WORLD | Layers.WALKWAY
	query.exclude = exclude
	var hit := world.direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider is Player


## Ask the owner of a player to run one of its host-only RPCs (remote_damage etc).
static func tell(player: Player, method: StringName, args := []) -> void:
	var call_args := [player.get_multiplayer_authority(), method]
	call_args.append_array(args)
	player.callv("rpc_id", call_args)
