extends SceneTree
## Renders a map from straight above, unshaded and without roofs, to check the layout
## of its random wings. Patrol points show as red posts, loot spots as yellow ones.
## Run (needs a display):
##   godot --path . --rendering-driver opengl3 --resolution 1024x1024 --script res://tools/layout_shot.gd -- <out.png> <map> [seed] [compact]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://layout.png"
	var map_id: String = args[1] if args.size() > 1 else "factory"
	var seed: int = int(args[2]) if args.size() > 2 else 1
	GameMap.compact = args.size() > 3 and args[3] == "compact"
	var level: GameMap = MapRoster.create(map_id)
	level.rng.seed = seed
	level.build_navigation = true
	var started := Time.get_ticks_msec()
	root.add_child(level)
	print("built %s in %d ms: %d rooms, %d patrol points, %d loot spots, loot %s" % [map_id, Time.get_ticks_msec() - started,
		level.wings.reduce(func(n: int, w: RoomGrid) -> int: return n + w.rooms.size(), 0),
		level.patrol_points.size(), level.loot_spots.size(), level.loot_count])
	var nav_map: RID = level.get_world_3d().navigation_map
	for i in 3:
		await process_frame
	var off := level.patrol_points.filter(func(p: Vector3) -> bool:
		return NavigationServer3D.map_get_closest_point(nav_map, p).distance_to(p) > 1.0)
	print("patrol points off the navmesh: ", off)
	for point in level.patrol_points:
		_marker(point, Color(1, 0.1, 0.1), 0.6)
	for point in level.loot_spots:
		_marker(point, Color(1, 0.9, 0.1), 0.35)
	var bounds := level.bounds
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(bounds.size.x, bounds.size.z) + 4.0
	camera.position = Vector3(bounds.get_center().x, 40.0, bounds.get_center().z)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.cull_mask = ~GameMap.ROOF_RENDER_LAYER & 0xFFFFF
	camera.far = 100.0
	root.add_child(camera)
	camera.current = true
	# Everything above the room walls is cut away so the floor plan shows.
	for node in level.find_children("*", "MeshInstance3D", true, false):
		if node.global_position.y > 7.0:
			node.visible = false
	root.get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _marker(pos: Vector3, color: Color, size: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 8.0, size)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	mesh.position = pos + Vector3(0, 4.0, 0)
	root.add_child(mesh)
