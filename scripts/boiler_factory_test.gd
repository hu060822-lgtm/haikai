class_name BoilerFactoryTest
extends Node3D
## Phase 0 greybox of the boiler factory: a dark hall with a central boiler,
## catwalks on both sides joined by walkable pipes, and a crawl duct at floor level.
## Built in code so layout tweaks are quick; real levels will be modular scenes.

const LOOT_COUNT := 9

const LOOT_SPOTS := [
	Vector3(0.0, 3.25, -4.0),     # on the north walkway pipe, exposed
	Vector3(0.0, 3.25, 6.0),      # on the south walkway pipe
	Vector3(-5.0, 0.2, 1.0),      # inside the crawl duct
	Vector3(-5.0, 0.2, 6.0),      # inside the crawl duct
	Vector3(13.5, 3.2, -10.0),    # east catwalk
	Vector3(-13.5, 3.2, -12.0),   # west catwalk
	Vector3(2.5, 0.2, -9.5),      # in front of the furnace
	Vector3(-9.0, 0.2, -15.0),
	Vector3(10.0, 0.2, 4.0),
	Vector3(-10.0, 0.2, 18.0),
	Vector3(6.0, 2.2, 10.0),      # on top of a crate
	Vector3(-6.0, 1.2, 15.0),     # on the conveyor
]

var player_spawn := Vector3(0.0, 0.1, 18.0)
var player_spawn_yaw := 0.0
var extraction_zone: ExtractionZone

var _rng := RandomNumberGenerator.new()
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_base: Array[float] = []
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_shell()
	_build_boiler()
	_build_catwalks()
	_build_pipes()
	_build_crawl_duct()
	_build_props()
	_build_lights()
	_build_extraction()
	_spawn_loot()


func _process(delta: float) -> void:
	_time += delta
	for i in _flicker_lights.size():
		var n := _noise.get_noise_2d(_time * 8.0, float(i) * 50.0)
		_flicker_lights[i].light_energy = _flicker_base[i] * (0.75 + 0.35 * n)


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


func _build_shell() -> void:
	_box(Vector3(32, 1, 44), Vector3(0, -0.5, 0), "concrete")
	_box(Vector3(32, 1, 44), Vector3(0, 10.5, 0), "rust_metal")
	_box(Vector3(32, 11, 1), Vector3(0, 5, -22.5), "brick")
	_box(Vector3(32, 11, 1), Vector3(0, 5, 22.5), "brick")
	_box(Vector3(1, 11, 44), Vector3(16.5, 5, 0), "brick")
	_box(Vector3(1, 11, 44), Vector3(-16.5, 5, 0), "brick")


func _build_boiler() -> void:
	_cylinder(Vector3(0, 0, -14), Vector3(0, 7, -14), 3.2, "rust_metal", Vector2(4, 2))
	_box(Vector3(7.5, 0.6, 7.5), Vector3(0, 0.3, -14), "rust_metal")
	# Furnace door glows; the boiler is the room's main light and landmark.
	var door := _box(Vector3(1.6, 1.2, 0.3), Vector3(0, 1.4, -10.75), "rust_metal", Vector3.ZERO, false)
	door.get_child(0).material_override = PS1Materials.get_material(
		"rust_metal", Color(0.3, 0.2, 0.1), false, Vector2.ONE, Color(1.0, 0.35, 0.05))
	_cylinder(Vector3(-1.5, 7, -14), Vector3(-1.5, 10, -14), 0.5, "pipe")
	_cylinder(Vector3(1.8, 7, -13), Vector3(1.8, 10, -13), 0.35, "pipe")
	_cylinder(Vector3(3.0, 6.5, -14), Vector3(15.9, 6.5, -14), 0.5, "pipe")
	_cylinder(Vector3(-3.0, 5.5, -15), Vector3(-15.9, 5.5, -15), 0.4, "pipe")


func _build_catwalks() -> void:
	for side in [1.0, -1.0]:
		var x: float = 13.5 * side
		_box(Vector3(4, 0.2, 30), Vector3(x, 2.9, -3), "grate", Vector3.ZERO, true, Color.WHITE, 1.0)
		# Ramp from the floor at the south end up to the catwalk.
		_box(Vector3(3, 0.2, 8.6), Vector3(x, 1.4, 16), "grate", Vector3(20.6, 0, 0), true, Color.WHITE, 1.0)
		# Inner railing, with gaps where the walkway pipes join.
		var rail_x: float = 11.55 * side
		for span in [Vector2(-18, -4.8), Vector2(-3.2, 5.2), Vector2(6.8, 12)]:
			var length: float = span.y - span.x
			_box(Vector3(0.1, 1.0, length), Vector3(rail_x, 3.5, (span.x + span.y) / 2.0), "rust_metal")
		# Support posts.
		for z in [-15.0, -8.0, 0.0, 8.0]:
			_box(Vector3(0.3, 2.8, 0.3), Vector3(rail_x + 0.3 * side, 1.4, z), "rust_metal")


func _build_pipes() -> void:
	# Two walkway pipes crossing the hall at catwalk height (top surface at y = 3).
	for z in [-4.0, 6.0]:
		_cylinder(Vector3(-11.6, 2.4, z), Vector3(11.6, 2.4, z), 0.6, "pipe", Vector2(3, 6))
		for x in [-6.0, 0.0, 6.0]:
			_box(Vector3(0.4, 1.8, 0.4), Vector3(x, 0.9, z), "rust_metal")
	# Overhead clutter.
	_cylinder(Vector3(-15.9, 8.0, 2), Vector3(15.9, 8.0, 2), 0.3, "pipe")
	_cylinder(Vector3(-15.9, 7.4, 12), Vector3(15.9, 7.4, 12), 0.45, "pipe")
	_cylinder(Vector3(9, 0, 20), Vector3(9, 10, 20), 0.4, "pipe")
	_cylinder(Vector3(-9, 0, -20), Vector3(-9, 10, -20), 0.4, "pipe")


func _build_crawl_duct() -> void:
	# Interior 1.2 m wide and 1.1 m tall: only passable while crouching.
	_box(Vector3(0.2, 1.3, 10), Vector3(-5.7, 0.65, 3), "rust_metal")
	_box(Vector3(0.2, 1.3, 10), Vector3(-4.3, 0.65, 3), "rust_metal")
	_box(Vector3(1.6, 0.2, 10), Vector3(-5.0, 1.2, 3), "rust_metal")


func _build_props() -> void:
	_box(Vector3(2, 2, 2), Vector3(6, 1, 10), "rust_metal")
	_box(Vector3(1.5, 1.5, 3), Vector3(-8, 0.75, 13), "rust_metal")
	_box(Vector3(3, 1, 1.5), Vector3(4, 0.5, -6.5), "rust_metal")
	_box(Vector3(8, 1, 1.5), Vector3(-6, 0.5, 15), "rust_metal")
	_box(Vector3(1.2, 2.4, 1.2), Vector3(9, 1.2, -9), "brass", Vector3(0, 25, 0))


func _build_lights() -> void:
	_noise.frequency = 0.3
	_light(Vector3(0, 1.3, -10.0), Color(1.0, 0.45, 0.15), 2.2, 10.0, true)
	_light(Vector3(6, 8, 10), Color(1.0, 0.8, 0.5), 0.8, 10.0, true)
	_light(Vector3(-8, 8, 0), Color(1.0, 0.8, 0.5), 0.6, 10.0, false)
	_light(Vector3(8, 8, -4), Color(1.0, 0.8, 0.5), 0.6, 9.0, true)
	_light(Vector3(0, 8, 17), Color(0.9, 0.85, 0.7), 0.5, 9.0, false)


func _build_extraction() -> void:
	var center := Vector3(8, 0, -18.5)
	_box(Vector3(3.2, 0.1, 3.2), center + Vector3(0, 0.05, 0), "grate", Vector3.ZERO, false, Color(0.7, 1.0, 0.8))
	for corner in [Vector3(1.5, 0, 1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, -1.5)]:
		_box(Vector3(0.15, 3.0, 0.15), center + corner + Vector3(0, 1.5, 0), "brass")
	_box(Vector3(3.2, 0.2, 3.2), center + Vector3(0, 3.1, 0), "rust_metal")
	_light(center + Vector3(0, 2.6, 0), Color(0.5, 1.0, 0.6), 1.0, 6.0, false)
	extraction_zone = ExtractionZone.new()
	extraction_zone.position = center + Vector3(0, 1.25, 0)
	add_child(extraction_zone)


func _spawn_loot() -> void:
	var spots := LOOT_SPOTS.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for i in mini(LOOT_COUNT, spots.size()):
		var item := LootItem.from_data(LootTable.roll(_rng))
		item.freeze = true
		item.position = spots[i]
		item.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(item)


func _box(size: Vector3, pos: Vector3, texture: String, rot_deg := Vector3.ZERO,
		collide := true, tint := Color.WHITE, density := 0.5) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
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
	if collide:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	add_child(root)
	return root


func _cylinder(from: Vector3, to: Vector3, radius: float, texture: String,
		uv_scale := Vector2(2, 2), collide := true) -> Node3D:
	var axis := to - from
	var length := axis.length()
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
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
	if collide:
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = length
		collider.shape = shape
		root.add_child(collider)
	add_child(root)
	return root


func _light(pos: Vector3, color: Color, energy: float, light_range: float, flicker: bool) -> void:
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
