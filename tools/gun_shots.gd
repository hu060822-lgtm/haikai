extends SceneTree
## Contact sheets of GunModels for the gunsmith: every bare frame (true scale and zoomed),
## a set of heavily modded builds from three sides, and a page per slot with every part of
## that slot fitted. A magenta ball marks each model's Muzzle marker.
## Run (needs a display):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . \
##     --script res://tools/gun_shots.gd -- <out_dir> [frames|builds|parts|all]
## Files: models-frames-*.png, models-build-*.png, models-parts-*.png.

const CELL := Vector2i(560, 300)

const BUILDS := {
	"carbine_full": {"frame": "carbine", "parts": {"receiver": "upper_billet", "barrel": "fluted_barrel", "muzzle": "flash_hider",
		"silencer": "can_heavy", "gas": "adjustable_gas", "handguard": "quad_rail", "rail_l": "flashlight", "rail_r": "strobe_light",
		"foregrip": "angled_grip", "underbarrel": "bayonet", "mount": "canted_dot", "sight": "variable_scope", "grip": "rubber_grip",
		"trigger": "match_trigger", "bolt": "nickel_bolt", "charging": "ambi_charging", "magazine": "coupled_mag", "ammo": "tracer",
		"stock": "adjustable_stock", "buttpad": "cheek_riser", "gadget": "rabbit_foot"}, "tune": {"stock": 0.4, "sight": 0.5, "gas": -0.5}},
	"ak_modern": {"frame": "ak", "parts": {"receiver": "ak_modern", "muzzle": "muzzle_brake", "gas": "piston_kit",
		"handguard": "long_handguard", "rail_l": "laser", "rail_r": "flashlight", "foregrip": "vertical_grip", "mount": "backup_irons",
		"sight": "red_dot", "grip": "stippled_grip", "charging": "extended_latch", "magazine": "polymer_mag", "ammo": "ap_rounds",
		"stock": "hydraulic_stock", "buttpad": "gel_pad", "gadget": "oil_can"}},
	"rifle_338": {"frame": "rifle", "parts": {"receiver": "precision_chassis", "barrel": "bbl_338", "muzzle": "muzzle_brake",
		"rail_r": "laser_ir", "foregrip": "bipod", "mount": "riser", "sight": "scope", "trigger": "double_set", "bolt": "bolt_knob",
		"magazine": "extended_mag", "ammo": "match_ammo", "stock": "precision_stock", "buttpad": "rubber_pad"}},
	"shotgun_saddle": {"frame": "shotgun", "parts": {"muzzle": "breacher", "handguard": "pump_rail", "rail_l": "flashlight",
		"foregrip": "stubby_grip", "underbarrel": "bayonet", "mount": "canted_dot", "sight": "holo", "magazine": "side_saddle",
		"ammo": "dragon_breath", "stock": "heavy_stock", "buttpad": "ammo_sleeve", "gadget": "lucky_cat"}},
	"pistol_braced": {"frame": "service_pistol", "parts": {"barrel": "threaded_barrel", "muzzle": "suppressor", "rail_l": "combo_light",
		"sight": "pistol_dot", "grip": "tape_grip", "trigger": "hair_trigger", "magazine": "extended_mag", "ammo": "subsonic",
		"stock": "pistol_brace", "gadget": "echo_bell"}},
	"lmg_belt": {"frame": "lmg", "parts": {"muzzle": "flash_hider", "gas": "adjustable_gas", "handguard": "heatshield",
		"rail_l": "laser", "foregrip": "bipod", "sight": "acog", "magazine": "belt_box", "ammo": "tracer", "stock": "light_stock",
		"gadget": "heatsink_fins", "charging": "side_charging"}},
	"amr_kit": {"frame": "anti_materiel", "parts": {"muzzle": "muzzle_brake", "silencer": "can_wet", "rail_l": "rail_counter",
		"foregrip": "bipod", "mount": "canted_dot", "sight": "variable_scope", "ammo": "api_rounds",
		"buttpad": "gel_pad"}},
	"double_cans": {"frame": "double_barrel", "parts": {"barrel": "short_barrel", "muzzle": "flash_hider", "silencer": "can_titanium",
		"rail_l": "flashlight", "sight": "peep_sight", "trigger": "double_set", "ammo": "slug", "stock": "wire_stock", "buttpad": "gel_pad"}},
	"bullpup_kit": {"frame": "bullpup", "parts": {"barrel": "heavy_barrel", "muzzle": "linear_comp", "rail_l": "combo_light",
		"rail_r": "rail_counter", "foregrip": "grip_pod", "underbarrel": "spike_bayonet", "sight": "acog", "magazine": "casket_mag",
		"ammo": "incendiary", "gadget": "vampire_charm"}},
	"lever_loop": {"frame": "lever_action", "parts": {"barrel": "threaded_barrel", "muzzle": "thread_adapter", "silencer": "can_light",
		"rail_l": "flashlight", "mount": "backup_irons", "sight": "night_vision", "bolt": "lever_loop", "magazine": "tube_extension",
		"ammo": "hollow_point", "buttpad": "ammo_sleeve"}},
	"pdw_kit": {"frame": "pdw", "parts": {"muzzle": "flash_hider", "silencer": "can_titanium", "rail_l": "laser", "foregrip": "handstop",
		"sight": "holo", "magazine": "extended_mag", "ammo": "ap_rounds"}},
	"auto_shotgun_box": {"frame": "auto_shotgun", "parts": {"barrel": "rifled_slug_barrel", "muzzle": "choke", "gas": "piston_kit",
		"handguard": "short_handguard", "rail_l": "strobe_light", "foregrip": "vertical_grip", "sight": "red_dot",
		"magazine": "box_mag_conv", "ammo": "slug", "stock": "folding_stock", "charging": "extended_latch"}},
	"heavy_pistol_comp": {"frame": "heavy_pistol", "parts": {"barrel": "long_barrel", "sight": "pistol_dot", "rail_l": "flashlight",
		"grip": "wood_grip", "magazine": "drum_mag", "ammo": "plus_p", "trigger": "match_trigger"}},
	"battle_rifle_kit": {"frame": "battle_rifle", "parts": {"barrel": "integral_suppressor", "handguard": "wood_handguard",
		"underbarrel": "chainsaw_bayonet", "sight": "scope", "mount": "cantilever", "magazine": "drum_mag", "stock": "bump_stock",
		"ammo": "fmj"}},
	"dmr_kit": {"frame": "dmr", "parts": {"receiver": "upper_light", "barrel": "match_barrel", "muzzle": "compensator",
		"handguard": "long_handguard", "rail_l": "laser_ir", "foregrip": "bipod", "sight": "thermal", "trigger": "match_trigger",
		"magazine": "quick_mag", "stock": "precision_stock", "buttpad": "cheek_riser", "ammo": "match_ammo"}},
	"sawed_off_kit": {"frame": "sawed_off", "parts": {"rail_l": "laser", "grip": "skeleton_grip", "trigger": "binary_trigger",
		"ammo": "buckshot_mag", "gadget": "ghost_chamber"}},
}

## For each slot: the frame and the parent parts its parts are shown on.
const HOSTS := {
	"receiver": [["carbine", {}], ["ak", {}], ["rifle", {}], ["revolver", {}]],
	"barrel": [["carbine", {}], ["service_pistol", {}], ["shotgun", {}], ["nail_gun", {}], ["tesla", {}], ["rifle", {}]],
	"muzzle": [["carbine", {}], ["shotgun", {}], ["flamethrower", {}]],
	"silencer": [["carbine", {"muzzle": "flash_hider"}]],
	"gas": [["carbine", {"handguard": "short_handguard"}]],
	"handguard": [["carbine", {}], ["shotgun", {}]],
	"rail": [["carbine", {"handguard": "long_handguard"}]],
	"foregrip": [["carbine", {"handguard": "quad_rail"}]],
	"underbarrel": [["carbine", {"handguard": "long_handguard"}]],
	"mount": [["carbine", {"sight": "red_dot"}]],
	"sight": [["carbine", {}], ["service_pistol", {}]],
	"grip": [["carbine", {}]],
	"trigger": [["carbine", {}], ["rifle", {}]],
	"bolt": [["carbine", {}], ["rifle", {}], ["lever_action", {}]],
	"charging": [["carbine", {}]],
	"magazine": [["carbine", {}], ["service_pistol", {}], ["shotgun", {}], ["lmg", {}], ["revolver", {}], ["nail_gun", {}], ["flamethrower", {}], ["tesla", {}]],
	"ammo": [["carbine", {}], ["shotgun", {}], ["crossbow", {}], ["nail_gun", {}]],
	"stock": [["carbine", {}], ["service_pistol", {}], ["rifle", {}]],
	"buttpad": [["rifle", {"stock": "heavy_stock"}], ["lever_action", {}]],
	"gadget": [["carbine", {}]],
}

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://gun_shots"
	var which: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.save_enabled = false
	GunModels.snap = 1400.0
	if which in ["frames", "all"]:
		await _frame_sheets()
	if which in ["builds", "all"]:
		await _build_sheets()
	if which in ["parts", "all"]:
		await _part_sheets()
	if which in ["ps1", "all"]:
		GunModels.snap = 180.0
		var cells: Array = []
		for key: String in ["carbine_full", "ak_modern", "rifle_338", "shotgun_saddle"]:
			cells.append({"build": BUILDS[key], "label": key, "yaw": -60.0, "pitch": 18.0})
		await _sheet("models-ps1-look", cells, 2)
	quit()


## Bare frames: at one shared scale (proportions), then each zoomed to fit (detail).
func _frame_sheets() -> void:
	var ids: Array = Arsenal.FRAMES.keys()
	var cells: Array = []
	for id: String in ids:
		cells.append({"build": {"frame": id, "parts": {}}, "label": "%s  %dcm" % [id, int(Arsenal.frame(id).length)],
				"yaw": -90.0, "pitch": 0.0, "window": 1.6, "focus": Vector3(0, 0.05, -0.15)})
	await _sheet("models-frames-scale", cells, 4, Vector2i(480, 220))
	for page in 4:
		var zoomed: Array = []
		for id: String in ids.slice(page * 8, page * 8 + 8):
			zoomed.append({"build": {"frame": id, "parts": {}}, "label": id, "yaw": -90.0, "pitch": 0.0})
			zoomed.append({"build": {"frame": id, "parts": {}}, "label": id + " (left, from above)", "yaw": 125.0, "pitch": 25.0})
		if not zoomed.is_empty():
			await _sheet("models-frames-%d" % (page + 1), zoomed, 4)


func _build_sheets() -> void:
	for key: String in BUILDS:
		var b: Dictionary = BUILDS[key]
		var cleaned := Arsenal.clean(b)
		var dropped: Array = []
		for slot: String in b.parts:
			if not cleaned.parts.has(slot):
				dropped.append(slot + "=" + str(b.parts[slot]))
		if not dropped.is_empty():
			print("  ", key, " drops ", dropped)
		var cells := [
			{"build": b, "label": key + "  right", "yaw": -90.0, "pitch": 0.0},
			{"build": b, "label": "left", "yaw": 90.0, "pitch": 0.0},
			{"build": b, "label": "three-quarter", "yaw": -50.0, "pitch": 22.0},
			{"build": b, "label": "from the front-left, above", "yaw": 140.0, "pitch": 30.0},
		]
		await _sheet("models-build-" + key, cells, 2, Vector2i(800, 420))


## One page per slot: every part of it on its host frame, cropped round the slot.
func _part_sheets() -> void:
	var by_slot := {}
	for id: String in Arsenal.PARTS:
		var slot: String = Arsenal.part(id).slot
		if not by_slot.has(slot):
			by_slot[slot] = []
		by_slot[slot].append(id)
	for slot: String in by_slot:
		var cells: Array = []
		for id: String in by_slot[slot]:
			var b := _host_build(slot, id)
			if b.is_empty():
				print("  no host for ", id)
				continue
			var real_slot := slot
			for s: String in b.parts:
				if b.parts[s] == id:
					real_slot = s
			var yaw := 90.0 if real_slot == "rail_l" or slot == "gadget" and false else -90.0
			if slot in ["rail", "mount", "charging"]:
				yaw = -40.0 if slot != "rail" else 140.0
			var cell := {"build": b, "label": "%s  (%s)" % [id, b.frame], "yaw": yaw, "pitch": 15.0 if slot in ["rail", "mount", "charging", "silencer"] else 0.0}
			if slot in ["stock", "buttpad", "magazine", "sight", "muzzle", "silencer", "underbarrel", "foregrip", "barrel", "handguard"]:
				pass  # whole gun
			else:
				cell.zoom_slot = real_slot
			cells.append(cell)
		await _sheet("models-parts-" + slot, cells, 4)


## A build that shows `id` in its slot type: the slot's hosts first, then any frame it fits.
func _host_build(slot_type: String, id: String) -> Dictionary:
	for host: Array in HOSTS.get(slot_type, []):
		var b := {"frame": host[0], "parts": (host[1] as Dictionary).duplicate()}
		for slot in Arsenal.SLOTS:
			if Arsenal.slot_type(slot) == slot_type and not b.parts.has(slot) and Arsenal.fits_in(b, slot, id):
				b.parts[slot] = id
				if Arsenal.clean(b).parts.get(slot, "") == id:
					return b
				b.parts.erase(slot)
	var helper = load("res://tests/model_tests.gd").new()
	return helper._build_with(id)


## Renders cells (each its own little world) and pastes them into one PNG.
func _sheet(file: String, cells: Array, cols: int, cell_size := CELL) -> void:
	var rows := ceili(cells.size() / float(cols))
	var sheet := Image.create(cell_size.x * cols, cell_size.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.06))
	var batch := 8
	for start in range(0, cells.size(), batch):
		var vps: Array[SubViewport] = []
		for i in range(start, mini(start + batch, cells.size())):
			vps.append(_cell(cells[i], cell_size))
		for f in 4:
			await process_frame
		for k in vps.size():
			var i := start + k
			var img := vps[k].get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell_size), Vector2i((i % cols) * cell_size.x, (i / cols) * cell_size.y))
			vps[k].queue_free()
		await process_frame
	var path := _out.path_join(file + ".png")
	sheet.save_png(path)
	print("saved ", path)


## One cell: a model in its own world, lit, turned by yaw and tilted by pitch, framed on
## the whole gun (or on one slot), with a label and the Muzzle marked.
func _cell(c: Dictionary, size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.11, 0.105, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var holder := Node3D.new()
	holder.rotation_degrees.x = float(c.get("pitch", 0.0))
	vp.add_child(holder)
	var model := GunModels.build(c.build)
	model.rotation_degrees.y = float(c.get("yaw", -90.0))
	holder.add_child(model)
	var marker := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.006
	dot.height = 0.012
	marker.mesh = dot
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.1, 0.9)
	glow.no_depth_test = true
	marker.material_override = glow
	marker.position = model.get_meta("muzzle")
	model.add_child(marker)
	# Frame it: the whole gun, a given window, or round one slot.
	var box := AABB()
	var first := true
	for child in model.get_children():
		if child is MeshInstance3D and child != marker:
			var b: AABB = child.transform * (child as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
	var focus: Vector3 = c.get("focus", box.get_center())
	var window: float = c.get("window", 0.0)
	if c.has("zoom_slot"):
		focus = model.get_meta("slots").get(c.zoom_slot, focus)
		window = 0.32
	if window <= 0.0:
		var flat := maxf(box.size.z, maxf(box.size.y * size.x / size.y, box.size.x))
		window = flat * 1.12
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = window
	var world_focus := holder.transform * (model.transform * focus)
	cam.position = world_focus + Vector3(0, 0, 3)
	cam.near = 0.05
	cam.far = 10.0
	vp.add_child(cam)
	cam.make_current()
	var label := Label.new()
	label.text = str(c.get("label", ""))
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.16))
	vp.add_child(label)
	return vp
