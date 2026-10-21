class_name ShotFx
## Throwaway visuals and sounds for gunfire, played on every peer (Run broadcasts them):
## muzzle flashes, tracers, impact sparks, flame jets, tesla arcs, flying saw blades,
## explosions, and the flash / fire / bubble stuck on a monster that was hit.
## Everything is a few unshaded low-poly bits that free themselves, in keeping with
## the PS1 look.

static var _materials := {}


## An unshaded, glowing material (cached by colour and blend).
static func glow(color: Color, additive := true, through_walls := false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, additive, through_walls]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = through_walls
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_materials[key] = material
	return material


static func _expire(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())


static func _place(parent: Node, node: Node3D, pos: Vector3) -> void:
	parent.add_child(node)
	node.global_position = pos


static func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadow(child)


## A star of flat blades, the classic sprite-y muzzle flash.
static func flash_mesh(size := 0.12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := TAU * i / 5.0
		var b := a + TAU / 10.0
		var c := a - TAU / 10.0
		var tip := Vector3(cos(a), sin(a), 0.0) * size
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(c), sin(c), 0.0) * size * 0.35)
		st.add_vertex(tip)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(tip)
		st.add_vertex(Vector3(cos(b), sin(b), 0.0) * size * 0.35)
	# A cone of flame pointing forward (-z) through the star.
	for i in 4:
		var a := TAU * i / 4.0
		var b := TAU * (i + 1) / 4.0
		st.add_vertex(Vector3(cos(a), sin(a), 0.0) * size * 0.3)
		st.add_vertex(Vector3(cos(b), sin(b), 0.0) * size * 0.3)
		st.add_vertex(Vector3(0, 0, -size * 2.2))
	return st.commit()


## How big a gun's muzzle flash is, from its flash stat (Arsenal.stats): 1 for an
## ordinary 50, 0 (none at all) under 5. Dragon's breath doubles it: it lights the room.
static func flash_strength(stats: Dictionary) -> float:
	var flash := float(stats.get("flash", 50.0))
	if flash < 5.0:
		return 0.0
	var dragon: bool = Arsenal.part(stats.get("parts", {}).get("ammo", "")).get("effects", {}).has("light")
	return flash / 50.0 * (2.0 if dragon else 1.0)


## A muzzle flash; strength (flash_strength) scales its size and light, 0 shows nothing.
static func muzzle_flash(parent: Node, pos: Vector3, dir: Vector3, color := Color(1.0, 0.75, 0.3), size := 0.14,
		strength := 1.0) -> void:
	if parent == null or not parent.is_inside_tree() or strength <= 0.0:
		return
	var flash := MeshInstance3D.new()
	flash.mesh = flash_mesh(size * clampf(sqrt(strength), 0.3, 2.0))
	flash.material_override = glow(color)
	_place(parent, flash, pos)
	_aim(flash, dir)
	flash.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5 * minf(strength, 4.0)
	light.omni_range = 5.0 * clampf(sqrt(strength), 0.4, 2.0)
	flash.add_child(light)
	_no_shadow(flash)
	_expire(flash, 0.06)


static func _aim(node: Node3D, dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	node.look_at(node.global_position + dir, up)


## A thin glowing streak from muzzle to impact that fades out fast.
static func tracer(parent: Node, from: Vector3, to: Vector3, color := Color(1.0, 0.85, 0.5), width := 0.018, life := 0.07) -> void:
	var length := from.distance_to(to)
	if parent == null or not parent.is_inside_tree() or length < 0.05:
		return
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	beam.mesh = box
	beam.material_override = glow(color).duplicate()
	_place(parent, beam, (from + to) / 2.0)
	_aim(beam, to - from)
	_no_shadow(beam)
	var tween := beam.create_tween()
	tween.tween_property(beam.material_override, "albedo_color:a", 0.0, life)
	tween.tween_callback(beam.queue_free)


## Sparks and a puff of grit where a shot landed.
static func impact(parent: Node, pos: Vector3, color := Color(1.0, 0.8, 0.4), amount := 8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = amount
	sparks.lifetime = 0.3
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3(0, -9.0, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 0.025)
	sparks.mesh = mesh
	sparks.material_override = glow(color)
	_place(parent, sparks, pos)
	sparks.emitting = true
	_no_shadow(sparks)
	_expire(sparks, 0.6)


static func flames(parent: Node, origin: Vector3, dir: Vector3, reach: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fire := CPUParticles3D.new()
	fire.one_shot = true
	fire.amount = 16
	fire.lifetime = 0.45
	fire.explosiveness = 0.6
	fire.direction = Vector3.FORWARD
	fire.spread = 14.0
	fire.initial_velocity_min = reach * 1.4
	fire.initial_velocity_max = reach * 2.0
	fire.damping_min = reach * 1.5
	fire.damping_max = reach * 2.5
	fire.gravity = Vector3(0, 2.5, 0)
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.12))
	curve.add_point(Vector2(0.55, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	fire.scale_amount_curve = curve
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	gradient.set_color(1, Color(0.7, 0.1, 0.02, 0.0))
	fire.color_ramp = gradient
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 4
	mesh.rings = 2
	fire.mesh = mesh
	var material := glow(Color.WHITE).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	fire.material_override = material
	_place(parent, fire, origin)
	_aim(fire, dir)
	fire.local_coords = false
	fire.emitting = true
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = reach
	light.position = Vector3(0, 0, -reach * 0.5)
	fire.add_child(light)
	_no_shadow(fire)
	_expire(fire, 0.8)


## A jagged electric line through the given points (shooter, then each target).
static func arc(parent: Node, points: Array) -> void:
	if parent == null or not parent.is_inside_tree() or points.size() < 2:
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var steps := maxi(3, int(a.distance_to(b) / 0.6))
		var last := a
		for s in range(1, steps + 1):
			var t := float(s) / steps
			var next := a.lerp(b, t)
			if s < steps:
				# Jagged in the middle, tight where it leaves the gun and lands.
				var room := minf(a.distance_to(next), b.distance_to(next))
				next += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * minf(0.18, room * 0.12)
			tracer(holder, last, next, Color(0.55, 0.85, 1.0), 0.022, 0.12)
			tracer(holder, last, next, Color(1.0, 1.0, 1.0), 0.008, 0.08)
			last = next
		impact(holder, b, Color(0.6, 0.9, 1.0), 6)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.8, 1.0)
	light.light_energy = 2.0
	light.omni_range = 6.0
	holder.add_child(light)
	light.global_position = points[1]
	_expire(holder, 0.25)


## A spinning saw blade flying along a path (it ricochets off walls and monsters).
static func saw(parent: Node, path: Array, speed := 32.0) -> void:
	if parent == null or not parent.is_inside_tree() or path.size() < 2:
		return
	var blade := MeshInstance3D.new()
	var teeth := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var r := 0.13 if i % 2 == 0 else 0.09
		teeth.append(Vector2(cos(a), sin(a)) * r)
	blade.mesh = LowPoly.extrude(teeth, 0.012)
	blade.material_override = PS1Materials.get_material("rust_metal", Color(0.85, 0.85, 0.9), true, Vector2.ONE, Color(0.25, 0.2, 0.15))
	_place(parent, blade, path[0])
	blade.rotation.x = PI / 2.0
	_no_shadow(blade)
	var tween := blade.create_tween()
	var total := 0.0
	for i in range(1, path.size()):
		var seconds: float = maxf((path[i] as Vector3).distance_to(path[i - 1]) / speed, 0.01)
		total += seconds
		tween.tween_property(blade, "global_position", path[i], seconds)
	tween.tween_callback(blade.queue_free)
	var spin := blade.create_tween()
	spin.tween_property(blade, "rotation:y", TAU * total * 6.0, total)


static func explosion(parent: Node, pos: Vector3, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var ball := MeshInstance3D.new()
	ball.mesh = LowPoly.blob(1.0, Vector3.ONE, 1)
	ball.material_override = glow(Color(1.0, 0.6, 0.2)).duplicate()
	_place(parent, ball, pos)
	ball.scale = Vector3.ONE * 0.3
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 5.0
	light.omni_range = radius * 3.0
	ball.add_child(light)
	_no_shadow(ball)
	var tween := ball.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE * radius * 0.8, 0.25)
	tween.tween_property(ball.material_override, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(light, "light_energy", 0.0, 0.35)
	tween.chain().tween_callback(ball.queue_free)
	impact(parent, pos, Color(1.0, 0.7, 0.3), 24)


static func _meshes(node: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if child is MeshInstance3D and not child.has_meta("fx"):
			found.append(child)
	return found


## A monster that was hit flashes white for a moment (red on a kill, orange when broken).
static func flash_monster(monster: Node, result := "hit") -> void:
	if monster == null or not is_instance_valid(monster) or not monster.is_inside_tree():
		return
	var color := Color(1.0, 1.0, 1.0, 0.6)
	if result == "kill":
		color = Color(1.0, 0.2, 0.15, 0.8)
	elif result == "break":
		color = Color(1.0, 0.6, 0.1, 0.8)
	elif result == "blocked":
		color = Color(0.5, 0.6, 0.7, 0.5)
	var overlay := glow(color, false)
	var meshes := _meshes(monster)
	for mesh in meshes:
		if mesh.material_overlay == null:
			mesh.material_overlay = overlay
	monster.get_tree().create_timer(0.08).timeout.connect(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh) and mesh.material_overlay == overlay:
				mesh.material_overlay = null)


## Little flames riding on a burning monster.
static func attach_burn(monster: Node3D, seconds: float) -> void:
	if monster == null or not is_instance_valid(monster) or monster.get_node_or_null("BurnFx") != null:
		return
	var fire := CPUParticles3D.new()
	fire.name = "BurnFx"
	fire.set_meta("fx", true)
	fire.amount = 12
	fire.lifetime = 0.6
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(0.3, 0.5, 0.3)
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.initial_velocity_min = 0.8
	fire.initial_velocity_max = 1.6
	fire.gravity = Vector3(0, 1.0, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.14, 0.09)
	fire.mesh = mesh
	fire.material_override = glow(Color(1.0, 0.5, 0.12))
	fire.position = Vector3(0, 0.7, 0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 1.2
	light.omni_range = 3.5
	fire.add_child(light)
	monster.add_child(fire)
	_no_shadow(fire)
	_expire(fire, seconds)


## A soap bubble wrapped round a monster.
static func attach_bubble(monster: Node3D, seconds: float, radius := 0.8) -> void:
	if monster == null or not is_instance_valid(monster) or monster.get_node_or_null("BubbleFx") != null:
		return
	var bubble := MeshInstance3D.new()
	bubble.name = "BubbleFx"
	bubble.set_meta("fx", true)
	bubble.mesh = LowPoly.blob(radius, Vector3.ONE, 1)
	bubble.material_override = glow(Color(0.7, 0.9, 1.0, 0.35), false)
	bubble.position = Vector3(0, radius * 0.9, 0)
	monster.add_child(bubble)
	_no_shadow(bubble)
	var tween := bubble.create_tween().set_loops(int(seconds / 0.8) + 1)
	tween.tween_property(bubble, "scale", Vector3(1.06, 0.95, 1.06), 0.4)
	tween.tween_property(bubble, "scale", Vector3(0.95, 1.06, 0.95), 0.4)
	_expire(bubble, seconds)


## The bang of a shot, by frame. Suppressed guns go "thup"; a supersonic bullet still
## cracks through the air (crack).
static func fire_sound(parent: Node, pos: Vector3, frame: String, quiet: bool, crack := false) -> void:
	if quiet:
		Sfx.play_3d(parent, pos, "thump", -6.0, 18.0, randf_range(1.7, 1.9))
		if crack:
			Sfx.play_3d(parent, pos, "bang", -10.0, 45.0, randf_range(2.1, 2.4))
		return
	match frame:
		"smg":
			Sfx.play_3d(parent, pos, "bang", -3.0, 60.0, randf_range(1.45, 1.6))
		"shotgun":
			Sfx.play_3d(parent, pos, "bang", 6.0, 90.0, 0.75)
		"rifle":
			Sfx.play_3d(parent, pos, "bang", 5.0, 90.0, 0.62)
		"nail_gun":
			Sfx.play_3d(parent, pos, "tink", -4.0, 20.0, randf_range(2.0, 2.4))
			Sfx.play_3d(parent, pos, "thump", -10.0, 15.0, 2.2)
		"crossbow":
			Sfx.play_3d(parent, pos, "thump", -8.0, 10.0, 1.4)
		"flamethrower":
			Sfx.play_3d(parent, pos, "hiss", -4.0, 25.0, randf_range(0.5, 0.6))
		"tesla":
			Sfx.play_3d(parent, pos, "zap", 0.0, 35.0, randf_range(0.9, 1.2))
		"harpoon":
			Sfx.play_3d(parent, pos, "thump", 0.0, 30.0, 0.8)
			Sfx.play_3d(parent, pos, "clank", -6.0, 25.0, 1.4)
		"railgun":
			Sfx.play_3d(parent, pos, "zap", 4.0, 70.0, 0.5)
			Sfx.play_3d(parent, pos, "bang", 8.0, 90.0, 0.45)
		"duck_launcher":
			Sfx.play_3d(parent, pos, "thump", 0.0, 40.0, 0.7)
		"saw_launcher":
			Sfx.play_3d(parent, pos, "clank", -2.0, 30.0, 1.6)
		"bubble_gun":
			Sfx.play_3d(parent, pos, "tink", -8.0, 10.0, randf_range(2.4, 2.8))
		_:
			Sfx.play_3d(parent, pos, "bang", 2.0, 70.0, randf_range(1.05, 1.15))
