class_name ViewModel
extends Node3D
## The first-person gun: the equipped build (GunModels) held at the lower right of the
## view, with sway, a recoil kick, a reload dip, aiming down the middle, the knife
## stab and a muzzle flash. Lives under the local player's camera.
## The model is drawn small and close (SCALE) so it looks full size but almost never
## pokes into walls.

const SCALE := 0.6
const HIP := Vector3(0.12, -0.14, -0.27)
const AIM := Vector3(0.0, -0.083, -0.31)

## How far the sights are up: the player's aim blend (0 hip, 1 aimed).
var aim := 0.0
var _rig: Node3D
var _gun: Node3D
var _knife: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _muzzle := Vector3(0, 0.08, -0.6)
var _kick := 0.0
var _kick_strength := 1.0
var _reload := 0.0
var _reload_total := 1.0
var _stab := 0.0
var _flash_time := 0.0
var _aim := 0.0
var _sway := Vector2.ZERO
var _bob := 0.0
var _last_basis := Basis.IDENTITY
## Magnifying sights: at full aim the gun drops out of view so you look down the scope.
var _scoped := false


func _ready() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_flash = MeshInstance3D.new()
	_flash.mesh = ShotFx.flash_mesh(0.09)
	_flash.material_override = ShotFx.glow(Color(1.0, 0.75, 0.3))
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.7, 0.35)
	_flash_light.light_energy = 2.2
	_flash_light.omni_range = 6.0
	_flash_light.visible = false
	# A soft fill so the gun reads in the dark (the lantern sits beside it).
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.65)
	fill.light_energy = 1.4
	fill.omni_range = 0.6
	fill.position = Vector3(-0.04, 0.08, -0.1)
	add_child(fill)
	_knife = _build_knife()
	_knife.visible = false
	add_child(_knife)


func set_build(build: Dictionary) -> void:
	if _gun != null:
		_gun.queue_free()
	_gun = GunModels.build(build)
	_scoped = float(Arsenal.stats(build).zoom) >= 2.0
	_gun.scale = Vector3.ONE * SCALE
	_rig.add_child(_gun)
	_no_shadow(_gun)
	_muzzle = GunModels.muzzle_point(build)
	if _flash.get_parent() != null:
		_flash.get_parent().remove_child(_flash)
		_flash_light.get_parent().remove_child(_flash_light)
	_gun.add_child(_flash)
	_gun.add_child(_flash_light)
	_flash.position = _muzzle + Vector3(0, 0, -0.02)
	_flash.scale = Vector3.ONE * 0.6
	_flash_light.position = _muzzle


## Where shots leave the barrel, in world space (for tracers).
func muzzle_global() -> Vector3:
	if _gun == null or not is_inside_tree():
		return global_position
	return _gun.to_global(_muzzle)


## A shot went off: recoil in degrees, flash = ShotFx.flash_strength (0: no flash).
func kick(recoil: float, flash := 1.0) -> void:
	_kick = 1.0
	_kick_strength = clampf(recoil / 4.0, 0.25, 2.5)
	if flash > 0.0:
		_flash_time = 0.05
		_flash.rotation.z = randf() * TAU
		_flash.scale = Vector3.ONE * 0.6 * clampf(sqrt(flash), 0.3, 2.0)
		_flash_light.light_energy = 2.2 * minf(flash, 4.0)


func reload(seconds: float) -> void:
	_reload = seconds
	_reload_total = maxf(seconds, 0.01)


func cancel_reload() -> void:
	_reload = 0.0


func stab() -> void:
	_stab = 0.32


func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 7.0)
	_reload = maxf(_reload - delta, 0.0)
	_stab = maxf(_stab - delta, 0.0)
	_flash_time = maxf(_flash_time - delta, 0.0)
	_flash.visible = _flash_time > 0.0
	_flash_light.visible = _flash_time > 0.0
	_aim = clampf(aim, 0.0, 1.0)
	# Sway: the gun lags behind how fast the view turns.
	var basis_now := global_basis.orthonormalized()
	var turned := _last_basis.inverse() * basis_now
	_last_basis = basis_now
	var turn := turned.get_euler()
	_sway = _sway.lerp(Vector2(clampf(-turn.y * 3.0, -0.6, 0.6), clampf(turn.x * 3.0, -0.6, 0.6)), minf(delta * 10.0, 1.0))
	var parent_body := get_parent()
	while parent_body != null and not parent_body is Player:
		parent_body = parent_body.get_parent()
	var speed := 0.0
	if parent_body is Player:
		speed = (parent_body as Player).ground_speed
	_bob += delta * speed * 2.2
	var bob_amount := clampf(speed / 5.0, 0.0, 1.0) * (1.0 - _aim * 0.8)
	var pos := HIP.lerp(AIM, _ease(_aim))
	pos += Vector3(sin(_bob * 0.5) * 0.006, -absf(cos(_bob * 0.5)) * 0.006, 0.0) * bob_amount
	pos += Vector3(_sway.x * 0.02, _sway.y * 0.02, 0.0) * (1.0 - _aim * 0.7)
	var kick_curve := _kick * _kick
	pos.z += kick_curve * 0.03 * _kick_strength
	var rot := Vector3(kick_curve * 0.25 * _kick_strength, _sway.x * 0.3, 0.0)
	if _reload > 0.0:
		# Dip down and roll the gun over, then bring it back up.
		var t := 1.0 - _reload / _reload_total
		var dip := sin(clampf(t, 0.0, 1.0) * PI)
		pos += Vector3(-0.02, -0.07, 0.02) * dip
		rot += Vector3(-0.6, 0.2, 0.9) * dip
	if _stab > 0.0:
		var s := 1.0 - _stab / 0.32
		var lunge := sin(s * PI)
		pos += Vector3(0.03, -0.08, 0.02) * lunge
		rot += Vector3(-0.5, 0.0, -0.3) * lunge
		_knife.visible = true
		_knife.position = Vector3(0.06, -0.09, -0.12).lerp(Vector3(0.0, -0.05, -0.32), lunge)
		_knife.rotation = Vector3(-0.15 + lunge * 0.2, 0.35 - lunge * 0.35, -0.3)
	else:
		_knife.visible = false
	_rig.position = pos
	_rig.rotation = rot
	if _gun != null:
		_gun.visible = not (_scoped and _aim > 0.9)


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _build_knife() -> Node3D:
	var knife := Node3D.new()
	knife.name = "Knife"
	var steel := PS1Materials.get_material("rust_metal", Color(0.85, 0.87, 0.9), true, Vector2.ONE, Color(0.12, 0.12, 0.14))
	var grip := PS1Materials.get_material("concrete", Color(0.18, 0.12, 0.08), true)
	var blade := MeshInstance3D.new()
	blade.mesh = LowPoly.extrude(PackedVector2Array([Vector2(-0.006, 0.0), Vector2(0.008, 0.0), Vector2(0.008, -0.11),
		Vector2(0.0, -0.14), Vector2(-0.006, -0.12)]), 0.003)
	blade.rotation.x = -PI / 2.0
	blade.material_override = steel
	knife.add_child(blade)
	var handle := MeshInstance3D.new()
	handle.mesh = LowPoly.prism(6, 0.008, 0.009, 0.07)
	handle.rotation.x = PI / 2.0
	handle.position = Vector3(0.001, 0.0, 0.035)
	handle.material_override = grip
	knife.add_child(handle)
	var guard := MeshInstance3D.new()
	guard.mesh = LowPoly.chamfer_box(Vector3(0.03, 0.008, 0.008), 0.002)
	guard.material_override = steel
	knife.add_child(guard)
	knife.scale = Vector3.ONE * 0.75
	_no_shadow(knife)
	return knife


static func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadow(child)
