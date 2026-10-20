class_name GameMap
extends Node3D
## Shared shape of every map: where players and monsters start, the objective switch
## that powers the exit, the exit itself, lockers, gates the guardian can close, the
## lights a blackout kills, and the spots loot can appear. Maps are built in code.
## Subclasses fill in the fields and build their geometry in build().

signal objective_done()

## Render layer for roofs: the guardian's top-down camera leaves them out.
const ROOF_RENDER_LAYER := 1 << 9

## Shown to players: the map's name, what to do first, and what to do after.
var map_name := ""
var intro := ""
var objective_text := ""
var exit_text := ""
var objective_message := ""
var blocked_message := ""
## What the exit is called on the guardian's map, the two-minute warning, and how the
## clock kills anyone still inside.
var exit_name := "出口"
var warning_message := "只剩兩分鐘了！"
var timeout_cause := "時間到了，你沒來得及出去"

var player_spawn := Vector3.ZERO
var player_spawn_yaw := 0.0
var monster_spawn := Vector3.ZERO
var patrol_points: Array[Vector3] = []
var loot_spots: Array[Vector3] = []
var loot_count := Vector2i(14, 18)
## This run's item pool (LootTable.make_pool), set by the host before loot is rolled.
var loot_pool: Array = []
## Where the guardian may release monsters: x/z half extents and a height range.
var bounds := AABB(Vector3(-16, -0.5, -22), Vector3(32, 7.5, 44))
## The guardian's top-down camera sits this high: just under the roof.
var overview_height := 11.5

var extraction_zone: ExtractionZone
var lever: BoilerLever
var lockers: Array[Locker] = []
var gates: Array[Gate] = []
## The exit needs the objective done AND the power on (the guardian can cut it).
var objective_on := false
var power_on := true
var rng := RandomNumberGenerator.new()
## Only the host needs the navmesh (monsters run there).
var build_navigation := true

var _nav: NavigationRegion3D
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_base: Array[float] = []
var _all_lights: Array[OmniLight3D] = []
var _light_energy: Array[float] = []
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_nav = NavigationRegion3D.new()
	_nav.name = "Nav"
	add_child(_nav)
	_noise.frequency = 0.3
	build()
	for node in find_children("*", "OmniLight3D", true, false):
		_all_lights.append(node)
		_light_energy.append(node.light_energy)
	if build_navigation:
		_bake_navigation()


## Subclasses build their geometry, lever, extraction, lockers and gates here.
func build() -> void:
	pass


func _process(delta: float) -> void:
	_time += delta
	if not power_on:
		return
	for i in _flicker_lights.size():
		var n := _noise.get_noise_2d(_time * 8.0, float(i) * 50.0)
		_flicker_lights[i].light_energy = _flicker_base[i] * (0.75 + 0.35 * n)


## The objective switch was thrown (every peer runs this).
func complete_objective() -> void:
	objective_on = true
	extraction_zone.powered = objective_on and power_on
	_on_objective()
	if multiplayer.is_server():
		GameNoise.emit(get_tree(), lever.global_position, 200.0, GameNoise.Kind.MACHINE)
	objective_done.emit()


## Map-specific flourish when the objective completes.
func _on_objective() -> void:
	pass


## Blackout or power back. Runs on every peer.
func set_power(on: bool) -> void:
	power_on = on
	extraction_zone.powered = objective_on and power_on
	for i in _all_lights.size():
		var light := _all_lights[i]
		if not is_instance_valid(light):
			continue
		light.light_energy = _light_energy[i] if on else 0.0
	Sfx.play_3d(self, Vector3(0, 6, 0), "thump" if not on else "hiss", 2.0, 80.0, 0.5 if not on else 1.4)


## Picks this run's loot: [{item, pos, rot}] at shuffled spots.
func roll_loot() -> Array:
	var spots := loot_spots.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var result := []
	for i in mini(rng.randi_range(loot_count.x, loot_count.y), spots.size()):
		result.append({"item": LootTable.roll(rng, 0.0, loot_pool), "pos": spots[i], "rot": rng.randf_range(0.0, TAU)})
	return result


## A line for the local player's HUD (body heat on the ice station), or "".
func status_text() -> String:
	return ""


func random_patrol_point() -> Vector3:
	return patrol_points[rng.randi_range(0, patrol_points.size() - 1)]


func in_bounds(point: Vector3) -> bool:
	return bounds.grow(0.01).has_point(point)


func _environment(background: Color, ambient: Color, ambient_energy: float, fog: Color, fog_density: float,
		drone := "drone", drone_db := -14.0) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.fog_enabled = fog_density > 0.0
	env.fog_light_color = fog
	env.fog_density = fog_density
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)
	var ambience := AudioStreamPlayer.new()
	ambience.stream = Sfx.looped(drone)
	ambience.volume_db = drone_db
	ambience.autoplay = true
	add_child(ambience)
	return env


func _add_lever(pos: Vector3, yaw: float, prompt: String) -> void:
	lever = BoilerLever.new()
	lever.name = "Lever"
	lever.prompt = prompt
	lever.position = pos
	lever.rotation.y = yaw
	_nav.add_child(lever)


func _add_extraction(center: Vector3) -> void:
	extraction_zone = ExtractionZone.new()
	extraction_zone.position = center + Vector3(0, 1.25, 0)
	add_child(extraction_zone)


func _add_locker(pos: Vector3, yaw: float) -> void:
	var locker := Locker.new()
	locker.position = pos
	locker.rotation.y = yaw
	locker.name = "Locker%d" % lockers.size()
	_nav.add_child(locker)
	lockers.append(locker)


func _add_gate(pos: Vector3, size: Vector3) -> void:
	var gate := Gate.new()
	gate.name = "Gate%d" % gates.size()
	gate.position = pos
	gate.size = size
	add_child(gate)
	gates.append(gate)


## Axis-aligned wall from `from` to `to` (same x or same z; from.y is its base), with
## openings given as [distance along the wall to the opening's centre, width, height].
func _wall(from: Vector3, to: Vector3, height: float, texture: String, openings := [],
		thickness := 0.2, tint := Color.WHITE, layer := Layers.WORLD) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / length
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := 0.0
	for opening in sorted:
		var start: float = opening[0] - opening[1] / 2.0
		var end: float = opening[0] + opening[1] / 2.0
		if start > cursor + 0.01:
			_wall_piece(from, dir, cursor, start, 0.0, height, thickness, texture, tint, layer)
		if opening[2] < height - 0.01:
			_wall_piece(from, dir, start, end, opening[2], height, thickness, texture, tint, layer)
		cursor = end
	if cursor < length - 0.01:
		_wall_piece(from, dir, cursor, length, 0.0, height, thickness, texture, tint, layer)


func _wall_piece(from: Vector3, dir: Vector3, a: float, b: float, y0: float, y1: float,
		thickness: float, texture: String, tint: Color, layer: int) -> void:
	var center := from + dir * (a + b) / 2.0 + Vector3.UP * (y0 + y1) / 2.0
	var size := Vector3(b - a, y1 - y0, thickness) if absf(dir.x) > 0.5 else Vector3(thickness, y1 - y0, b - a)
	_box(size, center, texture, Vector3.ZERO, layer, tint)


## A roof the guardian's overview camera can see through.
func _roof(size: Vector3, pos: Vector3, texture: String, tint := Color.WHITE) -> Node3D:
	var node := _box(size, pos, texture, Vector3.ZERO, Layers.WORLD, tint)
	node.get_child(0).layers = ROOF_RENDER_LAYER
	return node


## A glowing strip: neon signs, warning lamps, the snowcat's headlights.
func _glow(size: Vector3, pos: Vector3, color: Color) -> Node3D:
	var node := _box(size, pos, "concrete", Vector3.ZERO, 0)
	node.get_child(0).material_override = PS1Materials.get_material(
		"concrete", color * 0.4, false, Vector2.ONE, color)
	return node


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
