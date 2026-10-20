class_name GameNoise
## Gameplay noise. Anything loud calls GameNoise.emit(); every node in the
## "listeners" group with a hear() method is told about it.

enum Kind { FOOTSTEP, LANDING, ITEM, IMPACT, TOOL, MACHINE, VOICE }


static func emit(tree: SceneTree, position: Vector3, radius: float, kind := Kind.FOOTSTEP) -> void:
	if tree == null:
		return
	for listener in tree.get_nodes_in_group("listeners"):
		if listener.has_method("hear"):
			listener.hear(position, radius, kind)
