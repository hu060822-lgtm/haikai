extends SceneTree
## Renders a lineup of models on a neutral floor, to check low-poly meshes by eye.
## Run (needs a display):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/model_studio.gd -- <out.png> [set]
## Sets: "primitives" (default), "player", "loot".

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://studio.png"
	var set_name: String = args[1] if args.size() > 1 else "primitives"
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	stage.add_child(LowPoly.instance(LowPoly.chamfer_box(Vector3(30, 0.2, 12), 0.05), "concrete",
		Color(0.6, 0.6, 0.6), LowPoly.at(Vector3(0, -0.1, 0))))
	var models: Array = _models(set_name)
	var spacing := 2.2
	for i in models.size():
		var node: Node3D = models[i]
		node.position.x += (i - (models.size() - 1) / 2.0) * spacing
		stage.add_child(node)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.6, 6.5 + models.size() * 0.55)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	camera.fov = 55
	stage.add_child(camera)
	camera.current = true
	for i in 8:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(out)
	print("saved ", out)
	quit()


func _models(set_name: String) -> Array:
	var list := []
	match set_name:
		"player":
			for squad in 3:
				var player := Player.new()
				player.squad = squad
				player.set_physics_process(false)
				list.append(player)
		"loot":
			for item in LootTable.ITEMS.slice(0, 12):
				var node := Node3D.new()
				var mesh := MeshInstance3D.new()
				mesh.mesh = LootShapes.mesh_for(item)
				mesh.material_override = PS1Materials.get_material(item.get("texture", "brass"), item.get("tint", Color.WHITE))
				mesh.scale = Vector3.ONE * 2.0
				mesh.position.y = 0.6
				node.add_child(mesh)
				list.append(node)
		_:
			var meshes := [
				LowPoly.prism(6, 0.6, 0.6, 1.4),
				LowPoly.prism(8, 0.7, 0.0, 1.6),
				LowPoly.prism(5, 0.7, 0.35, 1.2),
				LowPoly.lathe(PackedVector2Array([Vector2(0, -0.8), Vector2(0.45, -0.8), Vector2(0.55, -0.2),
					Vector2(0.4, 0.3), Vector2(0.15, 0.45), Vector2(0.15, 0.8), Vector2(0, 0.8)]), 8),
				LowPoly.chamfer_box(Vector3(1.2, 1.2, 1.2), 0.15),
				LowPoly.blob(0.7, Vector3(1, 0.8, 1), 1, 0.15, 3),
				LowPoly.tube(PackedVector3Array([Vector3(0, -0.8, 0), Vector3(0.3, 0, 0.1), Vector3(0, 0.6, 0.3), Vector3(-0.2, 0.9, 0.2)]),
					PackedFloat32Array([0.3, 0.25, 0.18, 0.0]), 6),
				LowPoly.extrude(LowPoly.arch_outline(1.2, 1.8), 0.3),
			]
			for mesh in meshes:
				var node := Node3D.new()
				var instance := LowPoly.instance(mesh, "rust_metal", Color(0.9, 0.8, 0.7))
				instance.position.y = 0.9
				node.add_child(instance)
				list.append(node)
	return list
