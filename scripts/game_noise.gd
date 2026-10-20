class_name GameNoise
## Gameplay noise. Anything loud calls GameNoise.emit(); every node in the
## "listeners" group with a hear() method is told about it. Monsters only exist
## on the host, so noise made on a client is forwarded there.

enum Kind { FOOTSTEP, LANDING, ITEM, IMPACT, TOOL, MACHINE, VOICE, MUSIC }


static func emit(tree: SceneTree, position: Vector3, radius: float, kind := Kind.FOOTSTEP) -> void:
	if tree == null:
		return
	var session := Session.instance
	if session != null and not session.is_host():
		session.send_noise(position, radius, kind)
		return
	emit_local(tree, position, radius, kind)


static func emit_local(tree: SceneTree, position: Vector3, radius: float, kind: int) -> void:
	for listener in tree.get_nodes_in_group("listeners"):
		if listener.has_method("hear"):
			listener.hear(position, radius, kind)
