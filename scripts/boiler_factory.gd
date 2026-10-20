class_name BoilerFactory
extends Node3D
## 黑暗鍋爐工廠 (phase 1 greybox). A tall dark hall with the main boiler at the north end,
## catwalks along both walls at 6 m reached by ladders, two walkable pipes joining them,
## a crawl duct, and two small rooms with narrow doors. Big monsters can only use the
## open floor, so height and tight spaces are where the player is safe.
## Built in code so layout tweaks are quick; real levels will be modular scenes.

signal boiler_restarted()

const CATWALK_Y := 6.0
const LOOT_MIN := 14
const LOOT_MAX := 18

const LOOT_SPOTS := [
	Vector3(0.0, 6.25, -4.0), Vector3(-6.0, 6.25, 6.0), Vector3(5.0, 6.25, 6.0),   # on the pipes
	Vector3(13.5, 6.2, -10.0), Vector3(13.5, 6.2, 2.0), Vector3(-13.5, 6.2, -12.0),
	Vector3(-13.5, 6.2, 0.0), Vector3(-13.5, 6.2, 9.0), Vector3(13.5, 6.2, -16.0),  # catwalks
	Vector3(-5.0, 0.2, 0.0), Vector3(-5.0, 0.2, 5.0),                                # crawl duct
	Vector3(-13.0, 0.2, 19.0), Vector3(-11.0, 0.2, 15.5), Vector3(13.0, 0.2, 19.5),  # small rooms
	Vector3(11.0, 0.2, 16.0),
	Vector3(2.5, 0.2, -9.0), Vector3(-9.0, 0.2, -15.0), Vector3(10.0, 0.2, 4.0),
	Vector3(-2.0, 0.2, -6.0), Vector3(7.0, 0.2, -2.0), Vector3(-8.0, 0.2, 8.0),
	Vector3(6.0, 2.2, 10.0), Vector3(-3.0, 1.2, 15.0), Vector3(2.0, 0.2, 13.0),
	Vector3(-12.0, 0.2, -20.0), Vector3(12.0, 0.2, -8.0),
]

const PATROL_POINTS := [
	Vector3(0, 0, 10), Vector3(6, 0, -6), Vector3(-6, 0, -6), Vector3(8, 0, 2),
	Vector3(-8, 0, 2), Vector3(0, 0, -8), Vector3(8, 0, -17), Vector3(-9, 0, -18),
	Vector3(4, 0, 17), Vector3(-6, 0, 18), Vector3(0, 0, 0),
]

var player_spawn := Vector3(4.0, 0.1, 19.0)
var player_spawn_yaw := 0.0
var monster_spawn := Vector3(0.0, 0.1, -6.0)
var extraction_zone: ExtractionZone
var lever: BoilerLever
var lockers: Array[Locker] = []
var rng := RandomNumberGenerator.new()
## Only the host needs the navmesh (monsters run there).
var build_navigation := true

var _nav: NavigationRegion3D
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_base: Array[float] = []
var _furnace_light: OmniLight3D
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_nav = NavigationRegion3D.new()
	_nav.name = "Nav"
	add_child(_nav)
	_build_environment()
	_build_shell()
	_build_boiler()
	_build_catwalks()
	_build_pipes()
	_build_crawl_duct()
	_build_rooms()
	_build_props()
	_build_lights()
	_build_extraction()
	if build_navigation:
		_bake_navigation()


func _process(delta: float) -> void:
	_time += delta
	for i in _flicker_lights.size():
		var n := _noise.get_noise_2d(_time * 8.0, float(i) * 50.0)
		_flicker_lights[i].light_energy = _flicker_base[i] * (0.75 + 0.35 * n)


func restart_boiler() -> void:
	extraction_zone.powered = true
	_flicker_base[0] = 4.0
	_furnace_light.omni_range = 16.0
	if multiplayer.is_server():
		GameNoise.emit(get_tree(), lever.global_position, 200.0, GameNoise.Kind.MACHINE)
	boiler_restarted.emit()


## Picks this run's loot: [{item, pos, rot}] at shuffled spots.
func roll_loot() -> Array:
	var spots := LOOT_SPOTS.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var result := []
	for i in mini(rng.randi_range(LOOT_MIN, LOOT_MAX), spots.size()):
		result.append({"item": LootTable.roll(rng), "pos": spots[i], "rot": rng.randf_range(0.0, TAU)})
	return result


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.018, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.2, 0.26)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.06
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var ambience := AudioStreamPlayer.new()
	ambience.stream = Sfx.looped("drone")
	ambience.volume_db = -14.0
	ambience.autoplay = true
	add_child(ambience)


func _build_shell() -> void:
	_box(Vector3(32, 1, 44), Vector3(0, -0.5, 0), "concrete")
	_box(Vector3(32, 1, 44), Vector3(0, 12.5, 0), "rust_metal")
	_box(Vector3(32, 13, 1), Vector3(0, 6, -22.5), "brick")
	_box(Vector3(32, 13, 1), Vector3(0, 6, 22.5), "brick")
	_box(Vector3(1, 13, 44), Vector3(16.5, 6, 0), "brick")
	_box(Vector3(1, 13, 44), Vector3(-16.5, 6, 0), "brick")


func _build_boiler() -> void:
	_cylinder(Vector3(0, 0, -15), Vector3(0, 9, -15), 3.4, "rust_metal", Vector2(4, 2))
	_box(Vector3(8, 0.6, 8), Vector3(0, 0.3, -15), "rust_metal")
	var door := _box(Vector3(1.6, 1.2, 0.3), Vector3(0, 1.4, -11.55), "rust_metal", Vector3.ZERO, 0)
	door.get_child(0).material_override = PS1Materials.get_material(
		"rust_metal", Color(0.3, 0.2, 0.1), false, Vector2.ONE, Color(1.0, 0.35, 0.05))
	_cylinder(Vector3(-1.5, 9, -15), Vector3(-1.5, 12, -15), 0.5, "pipe")
	_cylinder(Vector3(1.8, 9, -14), Vector3(1.8, 12, -14), 0.35, "pipe")
	_cylinder(Vector3(3.2, 8.5, -15), Vector3(15.9, 8.5, -15), 0.5, "pipe")
	_cylinder(Vector3(-3.2, 7.8, -16), Vector3(-15.9, 7.8, -16), 0.4, "pipe")

	lever = BoilerLever.new()
	lever.name = "Lever"
	lever.position = Vector3(3.5, 0, -10.5)
	_nav.add_child(lever)


func _build_catwalks() -> void:
	for side in [1.0, -1.0]:
		var x: float = 13.5 * side
		_box(Vector3(4, 0.2, 34), Vector3(x, CATWALK_Y - 0.1, -3), "grate", Vector3.ZERO, Layers.WALKWAY, Color.WHITE, 1.0)
		# Inner railing, with gaps where the walkway pipes and ladders join.
		var rail_x: float = 11.55 * side
		for span in [Vector2(-20, -16.8), Vector2(-15.2, -4.8), Vector2(-3.2, 5.2), Vector2(6.8, 11.2), Vector2(12.8, 14)]:
			var length: float = span.y - span.x
			_box(Vector3(0.1, 1.0, length), Vector3(rail_x, CATWALK_Y + 0.5, (span.x + span.y) / 2.0),
				"rust_metal", Vector3.ZERO, Layers.WALKWAY)
		for z in [-16.0, 12.0]:
			var ladder := Ladder.new()
			ladder.height = CATWALK_Y + 1.2
			ladder.position = Vector3(11.1 * side, 0, z)
			ladder.rotation.y = PI / 2.0
			add_child(ladder)
			# Backing plate so you can't walk past the ladder under the catwalk.
			_box(Vector3(0.1, CATWALK_Y - 0.2, 1.2), Vector3(11.55 * side, (CATWALK_Y - 0.2) / 2.0, z), "rust_metal")
		for z in [-19.0, -10.0, 0.0, 10.0]:
			_box(Vector3(0.3, CATWALK_Y - 0.2, 0.3), Vector3(rail_x + 0.4 * side, (CATWALK_Y - 0.2) / 2.0, z), "rust_metal")


func _build_pipes() -> void:
	# Two walkway pipes crossing the hall at catwalk height (top surface at y = 6).
	for z in [-4.0, 6.0]:
		_cylinder(Vector3(-11.6, CATWALK_Y - 0.6, z), Vector3(11.6, CATWALK_Y - 0.6, z), 0.6, "pipe",
			Vector2(3, 6), Layers.WALKWAY)
		for x in [-6.0, 0.0, 6.0]:
			_box(Vector3(0.4, CATWALK_Y - 1.2, 0.4), Vector3(x, (CATWALK_Y - 1.2) / 2.0, z), "rust_metal")
	_cylinder(Vector3(-15.9, 10.0, 2), Vector3(15.9, 10.0, 2), 0.3, "pipe")
	_cylinder(Vector3(-15.9, 9.4, 12), Vector3(15.9, 9.4, 12), 0.45, "pipe")
	_cylinder(Vector3(9, 0, 21), Vector3(9, 12, 21), 0.4, "pipe")
	_cylinder(Vector3(-9, 0, -21), Vector3(-9, 12, -21), 0.4, "pipe")


func _build_crawl_duct() -> void:
	# Interior 1.2 m wide and 1.1 m tall: only passable while crouching.
	_box(Vector3(0.2, 1.3, 10), Vector3(-5.7, 0.65, 3), "rust_metal")
	_box(Vector3(0.2, 1.3, 10), Vector3(-4.3, 0.65, 3), "rust_metal")
	_box(Vector3(1.6, 0.2, 10), Vector3(-5.0, 1.2, 3), "rust_metal")


func _build_rooms() -> void:
	# Tool room (south-west) and control room (south-east). 1 m doors: too narrow for big monsters.
	_room(Vector3(-15.5, 0, 14), Vector3(-9.5, 0, 21.5), "east", 16.5)
	_room(Vector3(9.5, 0, 14), Vector3(15.5, 0, 21.5), "west", 18.0)
	for spec in [[Vector3(-14.8, 0, 17.5), PI / 2.0], [Vector3(-14.8, 0, 19.5), PI / 2.0], [Vector3(14.8, 0, 16.0), -PI / 2.0]]:
		var locker := Locker.new()
		locker.position = spec[0]
		locker.rotation.y = spec[1]
		locker.name = "Locker%d" % lockers.size()
		_nav.add_child(locker)
		lockers.append(locker)


func _room(min_corner: Vector3, max_corner: Vector3, door_side: String, door_z: float) -> void:
	var h := 3.0
	var t := 0.2
	var size := max_corner - min_corner
	var center := (min_corner + max_corner) / 2.0
	_box(Vector3(size.x + t, t, size.z + t), Vector3(center.x, h, center.z), "rust_metal")
	_box(Vector3(size.x, h, t), Vector3(center.x, h / 2.0, min_corner.z), "brick")
	var door_x := max_corner.x if door_side == "east" else min_corner.x
	var solid_x := min_corner.x if door_side == "east" else max_corner.x
	_box(Vector3(t, h, size.z), Vector3(solid_x, h / 2.0, center.z), "brick")
	# Door wall split around a 1 m opening, with a lintel above it.
	var lower := door_z - 0.5 - min_corner.z
	var upper := max_corner.z - (door_z + 0.5)
	_box(Vector3(t, h, lower), Vector3(door_x, h / 2.0, min_corner.z + lower / 2.0), "brick")
	_box(Vector3(t, h, upper), Vector3(door_x, h / 2.0, max_corner.z - upper / 2.0), "brick")
	_box(Vector3(t, 0.8, 1.0), Vector3(door_x, h - 0.4, door_z), "brick")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(center.x, h - 0.5, center.z)
	lamp.light_color = Color(0.9, 0.85, 0.6)
	lamp.light_energy = 0.5
	lamp.omni_range = 5.0
	add_child(lamp)
	_flicker_lights.append(lamp)
	_flicker_base.append(0.5)


func _build_props() -> void:
	_box(Vector3(2, 2, 2), Vector3(6, 1, 10), "rust_metal")
	_box(Vector3(1.5, 1.5, 3), Vector3(-8, 0.75, 11), "rust_metal")
	_box(Vector3(3, 1, 1.5), Vector3(4, 0.5, -7), "rust_metal")
	_box(Vector3(8, 1, 1.5), Vector3(-3, 0.5, 15), "rust_metal")
	_box(Vector3(1.2, 2.4, 1.2), Vector3(9, 1.2, -9), "brass", Vector3(0, 25, 0))
	_box(Vector3(2.5, 1.2, 1.2), Vector3(-9, 0.6, -4), "rust_metal", Vector3(0, -15, 0))


func _build_lights() -> void:
	_noise.frequency = 0.3
	_furnace_light = _light(Vector3(0, 1.3, -10.8), Color(1.0, 0.45, 0.15), 2.2, 10.0, true)
	_light(Vector3(6, 10, 10), Color(1.0, 0.8, 0.5), 0.9, 12.0, true)
	_light(Vector3(-8, 10, 0), Color(1.0, 0.8, 0.5), 0.7, 12.0, false)
	_light(Vector3(8, 10, -4), Color(1.0, 0.8, 0.5), 0.7, 11.0, true)
	_light(Vector3(0, 10, 17), Color(0.9, 0.85, 0.7), 0.6, 11.0, false)


func _build_extraction() -> void:
	var center := Vector3(8, 0, -19)
	_box(Vector3(3.2, 0.1, 3.2), center + Vector3(0, 0.05, 0), "grate", Vector3.ZERO, 0, Color(0.7, 1.0, 0.8))
	for corner in [Vector3(1.5, 0, 1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, -1.5)]:
		_box(Vector3(0.15, 3.0, 0.15), center + corner + Vector3(0, 1.5, 0), "brass")
	_box(Vector3(3.2, 0.2, 3.2), center + Vector3(0, 3.1, 0), "rust_metal")
	extraction_zone = ExtractionZone.new()
	extraction_zone.position = center + Vector3(0, 1.25, 0)
	add_child(extraction_zone)


func _bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	mesh.agent_radius = BoilerColossus.RADIUS
	mesh.agent_height = BoilerColossus.HEIGHT
	mesh.agent_max_climb = 0.4
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	_nav.navigation_mesh = mesh
	_nav.bake_navigation_mesh(false)


## Static box. layer 0 = visual only; geometry lives under the nav region so it gets baked.
func _box(size: Vector3, pos: Vector3, texture: String, rot_deg := Vector3.ZERO,
		layer := Layers.WORLD, tint := Color.WHITE, density := 0.5) -> Node3D:
	var root: Node3D = StaticBody3D.new() if layer != 0 else Node3D.new()
	if layer != 0:
		root.collision_layer = layer
		root.collision_mask = 0
	root.position = pos
	root.rotation_degrees = rot_deg
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	# Subdivide large faces so vertex snapping and affine warping stay subtle.
	mesh.subdivide_width = int(size.x / 2.0)
	mesh.subdivide_height = int(size.y / 2.0)
	mesh.subdivide_depth = int(size.z / 2.0)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = PS1Materials.get_material(texture, tint, false, Vector2.ONE, Color.BLACK, density)
	root.add_child(mesh_instance)
	if layer != 0:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	_nav.add_child(root)
	return root


func _cylinder(from: Vector3, to: Vector3, radius: float, texture: String,
		uv_scale := Vector2(2, 2), layer := Layers.WORLD) -> Node3D:
	var axis := to - from
	var length := axis.length()
	var root: Node3D = StaticBody3D.new() if layer != 0 else Node3D.new()
	if layer != 0:
		root.collision_layer = layer
		root.collision_mask = 0
	root.position = (from + to) / 2.0
	root.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = maxi(int(length / 2.0), 1)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = PS1Materials.get_material(
		texture, Color.WHITE, true, Vector2(uv_scale.x, uv_scale.y * length / 4.0))
	root.add_child(mesh_instance)
	if layer != 0:
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = length
		collider.shape = shape
		root.add_child(collider)
	_nav.add_child(root)
	return root


func _light(pos: Vector3, color: Color, energy: float, light_range: float, flicker: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	add_child(light)
	if flicker:
		_flicker_lights.append(light)
		_flicker_base.append(energy)
	return light
