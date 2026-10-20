extends SceneTree
## Renders the gunsmith bench (stash screen) in several states, and a contact sheet of
## every Arsenal frame built by GunModels.
## Run (needs a display):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --script res://tools/loadout_shot.gd -- <out_dir> [screen|guns|all]

const SHEET_BUILDS := [
	{"frame": "revolver", "parts": {}},
	{"frame": "revolver", "parts": {"muzzle": "suppressor", "sight": "red_dot", "underbarrel": "laser", "ammo": "incendiary", "gadget": "lucky_cat"}},
	{"frame": "smg", "parts": {}},
	{"frame": "smg", "parts": {"muzzle": "suppressor", "sight": "red_dot", "magazine": "drum_mag", "stock": "light_stock", "underbarrel": "flashlight", "gadget": "vampire_charm"}},
	{"frame": "shotgun", "parts": {"muzzle": "choke", "stock": "heavy_stock", "ammo": "rock_salt", "underbarrel": "flashlight"}},
	{"frame": "rifle", "parts": {"sight": "scope", "barrel": "long_barrel", "stock": "heavy_stock", "ammo": "ap_rounds", "gadget": "echo_bell"}},
	{"frame": "nail_gun", "parts": {"barrel": "long_barrel", "sight": "red_dot", "underbarrel": "laser", "gadget": "ghost_chamber"}},
	{"frame": "crossbow", "parts": {"sight": "scope", "stock": "light_stock", "ammo": "explosive_bolt", "gadget": "lucky_cat"}},
	{"frame": "flamethrower", "parts": {"muzzle": "wide_nozzle", "magazine": "big_tank", "gadget": "spring_bolt"}},
	{"frame": "tesla", "parts": {"barrel": "coil_barrel", "magazine": "capacitor", "stock": "heavy_stock"}},
	{"frame": "harpoon", "parts": {"sight": "red_dot", "stock": "heavy_stock", "ammo": "net_bolt", "gadget": "echo_bell"}},
	{"frame": "railgun", "parts": {"sight": "thermal", "stock": "heavy_stock", "gadget": "vampire_charm"}},
	{"frame": "duck_launcher", "parts": {"sight": "red_dot", "magazine": "extended_mag", "gadget": "lucky_cat"}},
	{"frame": "saw_launcher", "parts": {"magazine": "extended_mag", "stock": "light_stock", "underbarrel": "bayonet"}},
	{"frame": "bubble_gun", "parts": {"magazine": "capacitor", "gadget": "ghost_chamber"}},
	{"frame": "shotgun", "parts": {"magazine": "drum_mag", "barrel": "short_barrel", "muzzle": "compensator", "underbarrel": "bayonet", "ammo": "shock_rounds", "gadget": "spring_bolt"}},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var mode: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	if mode in ["guns", "all"]:
		await _gun_sheet(out_dir, "guns_side", -90.0, 0.0)
		await _gun_sheet(out_dir, "guns_three_quarter", -55.0, 22.0)
		await _gun_sheet(out_dir, "guns_back", -150.0, 18.0)
	if mode in ["zoom", "all"]:
		GunModels.snap = 2000.0
		await _gun_sheet(out_dir, "guns_zoom_a", -60.0, 20.0, 0)
		await _gun_sheet(out_dir, "guns_zoom_b", -60.0, 20.0, 8)
		await _gun_sheet(out_dir, "guns_zoom_c", 60.0, 15.0, 0)
		await _gun_sheet(out_dir, "guns_zoom_d", 60.0, 15.0, 8)
		GunModels.snap = 180.0
	if mode in ["screen", "all"]:
		await _screens(out_dir)
	quit()


## A 4x4 grid of models under one light, turned by yaw and tilted toward the camera by pitch.
## With `first` >= 0 it draws a closer 4x2 page of eight builds starting there.
func _gun_sheet(out_dir: String, shot_name: String, yaw: float, pitch: float, first := -1) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 1200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.085, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 50, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var cell := 1.0
	var builds: Array = SHEET_BUILDS if first < 0 else SHEET_BUILDS.slice(first, first + 8)
	var rows := 4 if first < 0 else 2
	for i in builds.size():
		var b: Dictionary = builds[i]
		var holder := Node3D.new()
		var col := i % 4
		var row := i / 4
		holder.position = Vector3((col - 1.5) * cell, -(row - (rows - 1) / 2.0) * cell * 0.75, 0)
		vp.add_child(holder)
		var model := GunModels.build(b)
		holder.add_child(model)
		var tilt := Node3D.new()
		tilt.rotation_degrees.x = pitch
		holder.add_child(tilt)
		holder.remove_child(model)
		tilt.add_child(model)
		model.rotation_degrees.y = yaw
		model.position = model.basis * Vector3(0, -0.03, 0.14)
		var label := Label3D.new()
		label.text = Arsenal.name_of(b.frame) + ("" if b.parts.is_empty() else "（%d 件）" % b.parts.size())
		label.font_size = 40
		label.pixel_size = 0.0016
		label.position = Vector3(0, -0.3, 0.2)
		label.modulate = Color(0.78, 1.0, 0.16)
		label.outline_size = 8
		holder.add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2 if first < 0 else 1.75
	if first >= 0:
		vp.size = Vector2i(1600, 700)
		cam.size = 1.75
	cam.position = Vector3(0, 0, 5)
	vp.add_child(cam)
	cam.make_current()
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
	vp.queue_free()
	await process_frame


func _screens(out_dir: String) -> void:
	GameState.reset()
	GameState.money = 2400
	# The screen on its own (main.gd would host it the same way: a full-rect Control).
	var screen := LoadoutScreen.new()
	root.add_child(screen)
	await _frames(20)
	_save(out_dir, "bench_starter")
	for state: String in ["modded_smg", "picker", "plans", "frames", "boosts"]:
		screen.shot_state(state)
		await _frames(12)
		_save(out_dir, "bench_" + state)
	screen.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(out_dir: String, shot_name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
