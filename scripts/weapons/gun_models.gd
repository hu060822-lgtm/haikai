class_name GunModels
## Low-poly PS1 models of Arsenal builds: every frame is its own cobbled-together
## scavenger contraption, and every part bolts on where it belongs (suppressor on the
## muzzle, scope on top, drum under, stock at the back, light / laser / bayonet under the
## barrel, ammo tints the rounds you can see, gadgets dangle as charms).
##
##   var model := GunModels.build(build)   # Node3D, points -Z, grip at the origin
##   model.get_node("Muzzle")             # Marker3D at the end of the barrel (moves with the gun)
##   GunModels.muzzle_point(build)        # the same point as a Vector3 in model space
##   model.get_meta("slots")              # {slot: Vector3} where each slot's part sits
##
## Sizes are real-ish metres: pistols ~0.3 m, long guns 0.5-0.8 m. Textures are projected
## in each mesh's own space (not world space), so they don't swim on a held gun.

const SHADER_CODE := """
shader_type spatial;
render_mode cull_back, specular_disabled, diffuse_lambert;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float texel_density = 7.0;
uniform float snap_height = 180.0;
varying vec2 v_uv;
varying vec3 v_affine;
void vertex() {
	vec3 n = abs(NORMAL);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) { uv = VERTEX.xz; }
	else if (n.x >= n.z) { uv = vec2(VERTEX.z, -VERTEX.y); }
	else { uv = vec2(VERTEX.x, -VERTEX.y); }
	uv *= texel_density;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 grid = vec2(snap_height * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_height) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
	v_uv = uv;
	v_affine = vec3(uv * clip.w, clip.w);
}
void fragment() {
	vec2 uv = mix(v_uv, v_affine.xy / v_affine.z, 0.5);
	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = tex.rgb * albedo_color.rgb;
	EMISSION = emission_color;
}
"""

# Palette (tints over the shared 64px textures).
const STEEL := Color(0.62, 0.66, 0.72)
const DARK := Color(0.3, 0.31, 0.34)
const BLACK := Color(0.16, 0.16, 0.18)
const WOOD := Color(1.15, 0.9, 0.7)
const RUST := Color(1.3, 1.05, 0.9)
const TAPE := Color(0.72, 0.74, 0.72)
const ORANGE := Color(1.35, 0.62, 0.12)
const YELLOW := Color(1.4, 1.2, 0.2)
const RED := Color(1.2, 0.22, 0.18)
const OLIVE := Color(0.62, 0.7, 0.42)
const PINK := Color(1.4, 0.5, 0.85)
const TEAL := Color(0.3, 1.1, 1.0)
const BONE := Color(1.25, 1.2, 1.05)
const COPPER := Color(1.25, 0.72, 0.45)
const ZAP := Color(0.35, 0.9, 1.0)
const FIRE := Color(1.0, 0.45, 0.08)

## Colour of the rounds each ammo part shows, and whether they glow.
const AMMO_LOOK := {
	"hollow_point": [Color(1.2, 0.62, 0.38), Color.BLACK],
	"ap_rounds": [Color(0.25, 0.32, 0.22), Color(0.1, 0.35, 0.05)],
	"incendiary": [Color(1.2, 0.3, 0.1), Color(0.75, 0.22, 0.0)],
	"shock_rounds": [Color(0.4, 0.9, 1.1), Color(0.1, 0.45, 0.7)],
	"rock_salt": [Color(1.4, 1.4, 1.35), Color(0.12, 0.12, 0.12)],
	"explosive_bolt": [Color(1.3, 0.15, 0.1), Color(0.5, 0.05, 0.0)],
	"net_bolt": [Color(0.5, 1.2, 0.35), Color(0.05, 0.2, 0.0)],
}

## Vertex snapping grid height of new materials (the PS1 wobble). Tools raise it for crisp shots.
static var snap := 180.0
static var _shader: Shader
static var _mats := {}


## A finished model of `build` (any Arsenal build; it is cleaned first).
static func build(build: Dictionary) -> Node3D:
	build = Arsenal.clean(build)
	var r := Rig.new()
	r.root = Node3D.new()
	r.root.name = "Gun_" + str(build.frame)
	r.frame = build.frame
	r.parts = build.parts
	match r.frame:
		"revolver": _revolver(r)
		"smg": _smg(r)
		"shotgun": _shotgun(r)
		"rifle": _rifle(r)
		"nail_gun": _nail_gun(r)
		"crossbow": _crossbow(r)
		"flamethrower": _flamethrower(r)
		"tesla": _tesla(r)
		"harpoon": _harpoon(r)
		"railgun": _railgun(r)
		"duck_launcher": _duck_launcher(r)
		"saw_launcher": _saw_launcher(r)
		"bubble_gun": _bubble_gun(r)
	var bare_muzzle := r.muzzle
	_attach_parts(r)
	# Where each slot's part sits, so a menu can point at it.
	r.root.set_meta("slots", {
		"muzzle": r.muzzle.lerp(bare_muzzle, 0.5), "barrel": r.barrel_start.lerp(bare_muzzle, 0.5), "sight": r.top + Vector3(0, 0.02, 0),
		"magazine": r.mag + Vector3(0, -0.03, 0), "stock": r.stock + Vector3(0, -0.02, 0.08), "underbarrel": r.under,
		"ammo": r.side, "gadget": r.gadget + Vector3(0, -0.04, 0.01),
	})
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = r.muzzle
	r.root.add_child(marker)
	r.root.set_meta("muzzle", r.muzzle)
	r.root.set_meta("frame", r.frame)
	return r.root


## Where the shot leaves the gun (after any muzzle device or barrel), in model space.
static func muzzle_point(build: Dictionary) -> Vector3:
	var model := build(build)
	var point: Vector3 = model.get_meta("muzzle")
	model.free()
	return point


## The PS1 gun material (object-space texturing). Cached.
static func mat(texture: String, tint := Color.WHITE, glow := Color.BLACK, density := 7.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s" % [texture, tint, glow, snap, density]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo_texture", load("res://textures/%s.png" % texture))
	m.set_shader_parameter("albedo_color", tint)
	m.set_shader_parameter("emission_color", glow)
	m.set_shader_parameter("snap_height", snap)
	m.set_shader_parameter("texel_density", density)
	_mats[key] = m
	return m


## Everything a frame builder tells the part step: where each slot's part bolts on.
class Rig:
	var root: Node3D
	var frame := ""
	var parts := {}
	var muzzle := Vector3(0, 0.07, -0.3)   # end of the bare barrel
	var barrel_start := Vector3(0, 0.07, -0.1)
	var barrel_r := 0.012
	var top := Vector3(0, 0.1, 0.0)        # top of the rail, sights sit on it
	var mag := Vector3(0, 0.04, -0.06)     # bottom of the magwell, mags hang from it
	var stock := Vector3(0, 0.07, 0.08)    # back of the receiver, stocks go +Z from it
	var under := Vector3(0, 0.04, -0.25)   # under the barrel
	var gadget := Vector3(0, 0.03, 0.05)   # charms hang from here
	var side := Vector3(0.03, 0.07, -0.05) # right side of the receiver (ammo holder)
	var mag_style := "box"                 # how magazine parts look on this frame
	var rounds: Array[MeshInstance3D] = [] # visible rounds that ammo parts recolour


# --- Shape helpers ----------------------------------------------------------------

static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO,
		bevel := 0.004) -> MeshInstance3D:
	return _put(p, LowPoly.chamfer_box(size, bevel), pos, m, rot)


## A rod along Z centred at `pos` (front radius, back radius).
static func _rod(p: Node3D, r_front: float, r_back: float, length: float, pos: Vector3, m: Material,
		sides := 8, rot := Vector3(90, 0, 0)) -> MeshInstance3D:
	return _put(p, LowPoly.prism(sides, r_front, r_back, length), pos, m, rot)


## A rod from point a to point b.
static func _rod_between(p: Node3D, a: Vector3, b: Vector3, radius: float, m: Material, sides := 6) -> MeshInstance3D:
	var path := PackedVector3Array([a, b])
	return _put(p, LowPoly.tube(path, PackedFloat32Array([radius, radius]), sides), Vector3.ZERO, m)


## A disc / drum with its axis along X.
static func _disc_x(p: Node3D, radius: float, thick: float, pos: Vector3, m: Material, sides := 10) -> MeshInstance3D:
	return _put(p, LowPoly.prism(sides, radius, radius, thick), pos, m, Vector3(0, 0, 90))


## A lathed profile along Z: points are (radius, z) listed front (-z) to back.
static func _lathe_z(p: Node3D, profile: Array, pos: Vector3, m: Material, sides := 8) -> MeshInstance3D:
	var packed := PackedVector2Array()
	for v: Vector2 in profile:
		packed.append(v)
	return _put(p, LowPoly.lathe(packed, sides), pos, m, Vector3(90, 0, 0))


## A side silhouette: points are (forward, up), extruded `thick` across X.
static func _profile(p: Node3D, points: Array, thick: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var packed := PackedVector2Array()
	for v: Vector2 in points:
		packed.append(v)
	return _put(p, LowPoly.extrude(packed, thick), pos, m, Vector3(0, 90, 0))


static func _ball(p: Node3D, radius: float, pos: Vector3, m: Material, squash := Vector3.ONE, lump := 0.0) -> MeshInstance3D:
	return _put(p, LowPoly.blob(radius, squash, 1, lump, 3), pos, m)


static func _tube(p: Node3D, points: Array, radius: float, m: Material, sides := 5) -> MeshInstance3D:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for v: Vector3 in points:
		path.append(v)
		radii.append(radius)
	return _put(p, LowPoly.tube(path, radii, sides), Vector3.ZERO, m)


static func _put(p: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.transform = LowPoly.at(pos, rot)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(node)
	return node


## A pistol grip whose top is at `top` (raked back), with a strip of tape round it.
static func _grip(r: Rig, top: Vector3, m: Material, size := Vector3(0.032, 0.105, 0.042), rake := -16.0) -> void:
	var down := Vector3(0, -cos(deg_to_rad(rake)), -sin(deg_to_rad(rake)))
	_box(r.root, size, top + down * size.y * 0.5, m, Vector3(rake, 0, 0), 0.008)
	_box(r.root, Vector3(size.x + 0.004, 0.018, size.z + 0.004), top + down * size.y * 0.62,
			mat("panel", TAPE), Vector3(rake, 0, 0), 0.002)


## A trigger and a bent-wire guard in front of a grip at the origin.
static func _trigger(r: Rig, y := 0.03, z := -0.015) -> void:
	_box(r.root, Vector3(0.006, 0.022, 0.008), Vector3(0, y - 0.012, z - 0.012), mat("panel", BLACK), Vector3(-15, 0, 0))
	_tube(r.root, [Vector3(0, y, z - 0.045), Vector3(0, y - 0.035, z - 0.04), Vector3(0, y - 0.04, z - 0.005),
			Vector3(0, y - 0.03, z + 0.02)], 0.003, mat("panel", DARK), 4)


## How much the barrel part stretches or cuts this frame's barrel.
static func _barrel_scale(r: Rig) -> float:
	match r.parts.get("barrel", ""):
		"long_barrel": return 1.5
		"short_barrel": return 0.6
	return 1.0


## A plain barrel from `start` forward; sets the rig's muzzle and barrel anchors.
static func _barrel(r: Rig, start: Vector3, length: float, radius: float, m: Material, sight := true) -> float:
	var len := length * _barrel_scale(r)
	_rod(r.root, radius, radius, len, start + Vector3(0, 0, -len / 2.0), m, 6)
	if r.parts.get("barrel", "") == "long_barrel":
		# The extension is a second pipe welded on, with a hose clamp over the joint.
		var joint := start + Vector3(0, 0, -length * 0.95)
		_rod(r.root, radius * 1.6, radius * 1.6, 0.02, joint, mat("panel", TAPE), 8)
		_rod(r.root, radius * 1.15, radius * 1.15, len - length, joint + Vector3(0, 0, -(len - length) / 2.0),
				mat("rust_metal", RUST), 6)
	elif r.parts.get("barrel", "") == "short_barrel":
		_rod(r.root, radius * 1.4, radius * 1.4, 0.012, start + Vector3(0, 0, -len + 0.006), mat("brass", COPPER), 6)
	if sight:
		_box(r.root, Vector3(0.004, 0.014, 0.008), start + Vector3(0, radius + 0.006, -len + 0.012), mat("panel", DARK))
	r.barrel_start = start
	r.barrel_r = radius
	r.muzzle = start + Vector3(0, 0, -len)
	return len


## A visible round (a cartridge tip, shell, bolt head): recoloured by the ammo part.
static func _round(r: Rig, node: MeshInstance3D) -> MeshInstance3D:
	r.rounds.append(node)
	return node


## A straight box magazine hanging from `top`, with the top round showing.
static func _box_mag(r: Rig, top: Vector3, length: float, m: Material, width := 0.022, depth := 0.034, tilt := 8.0) -> void:
	var down := Vector3(0, -cos(deg_to_rad(tilt)), -sin(deg_to_rad(tilt)))
	_box(r.root, Vector3(width + 0.008, 0.02, depth + 0.008), top + Vector3(0, -0.006, 0), mat("panel", DARK))
	_box(r.root, Vector3(width, length, depth), top + down * length * 0.5, m, Vector3(tilt, 0, 0))
	_box(r.root, Vector3(width + 0.004, 0.012, depth + 0.006), top + down * (length - 0.006), mat("panel", BLACK),
			Vector3(tilt, 0, 0))
	_round(r, _rod(r.root, 0.006, 0.006, depth * 0.8, top + Vector3(0, 0.004, -0.004), mat("brass"), 5))


# --- Frames ---------------------------------------------------------------------------

static func _revolver(r: Rig) -> void:
	var steel := mat("panel", DARK)
	var y := 0.07
	_grip(r, Vector3(0, 0.035, 0.012), mat("wood", WOOD), Vector3(0.03, 0.1, 0.044), -20.0)
	_box(r.root, Vector3(0.028, 0.055, 0.1), Vector3(0, 0.055, -0.02), steel)
	_box(r.root, Vector3(0.02, 0.012, 0.11), Vector3(0, y + 0.02, -0.035), steel)
	# Cylinder with six chamber mouths showing the rounds.
	_rod(r.root, 0.025, 0.025, 0.05, Vector3(0, y - 0.006, -0.04), mat("panel", STEEL), 8)
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var pos := Vector3(cos(a) * 0.015, y - 0.006 + sin(a) * 0.015, -0.04)
		_round(r, _rod(r.root, 0.0055, 0.0055, 0.052, pos, mat("brass"), 5))
	_barrel(r, Vector3(0, y, -0.066), 0.15, 0.011, mat("panel", STEEL))
	_rod(r.root, 0.006, 0.006, 0.1 * _barrel_scale(r), Vector3(0, y - 0.017, -0.066 - 0.05 * _barrel_scale(r)), steel, 5)
	_box(r.root, Vector3(0.012, 0.022, 0.016), Vector3(0, y + 0.024, 0.03), steel, Vector3(35, 0, 0))
	_trigger(r, 0.03, -0.0)
	# A lanyard ring at the butt.
	_tube(r.root, [Vector3(0, -0.085, 0.045), Vector3(0, -0.1, 0.05), Vector3(0, -0.095, 0.065), Vector3(0, -0.082, 0.058)],
			0.003, mat("brass"), 4)
	r.top = Vector3(0, y + 0.026, -0.03)
	r.under = Vector3(0, y - 0.03, r.muzzle.z + 0.06)
	r.gadget = Vector3(0, -0.098, 0.055)
	r.side = Vector3(0.018, 0.0, 0.025)
	r.stock = Vector3(0, 0.04, 0.06)


static func _smg(r: Rig) -> void:
	var y := 0.075
	var pipe := mat("pipe", Color(1.1, 1.0, 0.95))
	_grip(r, Vector3(0, 0.05, 0.02), mat("panel", BLACK), Vector3(0.03, 0.1, 0.04), -14.0)
	# Receiver: a length of water pipe with end caps.
	_rod(r.root, 0.028, 0.028, 0.27, Vector3(0, y, -0.04), pipe, 8)
	_rod(r.root, 0.033, 0.033, 0.024, Vector3(0, y, 0.095), mat("panel", DARK), 8)
	_rod(r.root, 0.032, 0.032, 0.018, Vector3(0, y, -0.172), mat("panel", DARK), 8)
	# Sewing-machine hand wheel bolted on the side (it cocks the thing).
	_disc_x(r.root, 0.036, 0.008, Vector3(0.034, y, 0.03), mat("brass", COPPER), 12)
	_disc_x(r.root, 0.012, 0.016, Vector3(0.038, y, 0.03), mat("panel", DARK), 6)
	for i in 4:
		var a := TAU * i / 4.0
		_box(r.root, Vector3(0.004, 0.05, 0.006), Vector3(0.039, y, 0.03), mat("panel", DARK), Vector3(rad_to_deg(a), 0, 0), 0.001)
	# Welded plate and charging knob.
	_box(r.root, Vector3(0.006, 0.04, 0.1), Vector3(-0.03, y - 0.008, -0.06), mat("rust_metal", RUST))
	_rod_between(r.root, Vector3(0.026, y + 0.01, -0.1), Vector3(0.05, y + 0.012, -0.1), 0.004, mat("panel", DARK))
	_ball(r.root, 0.009, Vector3(0.052, y + 0.012, -0.1), mat("panel", RED))
	# Barrel inside a perforated shroud.
	var start := Vector3(0, y, -0.18)
	_barrel(r, start, 0.13, 0.009, mat("panel", STEEL))
	var shroud := minf(0.1, 0.13 * _barrel_scale(r) - 0.01)
	_rod(r.root, 0.02, 0.02, shroud, start + Vector3(0, 0, -shroud / 2.0), mat("grate", Color(1.6, 1.6, 1.6)), 8)
	_trigger(r, 0.045, 0.0)
	if not r.parts.has("magazine"):
		_box_mag(r, Vector3(0, 0.048, -0.075), 0.12, mat("panel", DARK))
	r.mag = Vector3(0, 0.048, -0.075)
	r.top = Vector3(0, y + 0.028, -0.04)
	r.stock = Vector3(0, y - 0.005, 0.105)
	r.under = Vector3(0, y - 0.025, start.z - 0.06)
	r.gadget = Vector3(0, y - 0.03, 0.07)
	r.side = Vector3(0.028, y, -0.13)


static func _shotgun(r: Rig) -> void:
	var y := 0.08
	var wood := mat("wood", WOOD)
	_grip(r, Vector3(0, 0.05, 0.02), wood, Vector3(0.034, 0.1, 0.045), -20.0)
	_box(r.root, Vector3(0.042, 0.066, 0.17), Vector3(0, y - 0.004, -0.04), mat("panel", DARK), Vector3.ZERO, 0.008)
	_box(r.root, Vector3(0.044, 0.02, 0.06), Vector3(0, y - 0.0, -0.03), mat("grate", Color(1.5, 1.5, 1.5)))
	var len := _barrel(r, Vector3(0, y + 0.012, -0.125), 0.34, 0.013, mat("panel", STEEL))
	# Tube magazine under the barrel, and the pump on it.
	var tube := minf(len - 0.03, 0.27)
	_rod(r.root, 0.011, 0.011, tube, Vector3(0, y - 0.016, -0.125 - tube / 2.0), mat("panel", DARK), 6)
	_box(r.root, Vector3(0.042, 0.036, 0.12), Vector3(0, y - 0.016, -0.22), wood, Vector3.ZERO, 0.01)
	for i in 4:
		_box(r.root, Vector3(0.044, 0.004, 0.006), Vector3(0, y - 0.006, -0.18 - i * 0.025), mat("panel", BLACK), Vector3.ZERO, 0.001)
	# Duct tape holding barrel and tube together.
	_box(r.root, Vector3(0.032, 0.05, 0.022), Vector3(0, y - 0.002, -0.125 - tube + 0.02), mat("panel", TAPE), Vector3.ZERO, 0.006)
	# Side saddle of red shells.
	_box(r.root, Vector3(0.006, 0.05, 0.075), Vector3(-0.024, y - 0.004, -0.04), mat("panel", BLACK))
	for i in 4:
		var z := -0.065 + i * 0.017
		_round(r, _rod(r.root, 0.0075, 0.0075, 0.04, Vector3(-0.031, y, z), mat("panel", RED), 6, Vector3.ZERO))
		_rod(r.root, 0.008, 0.008, 0.01, Vector3(-0.031, y - 0.024, z), mat("brass"), 6, Vector3.ZERO)
	_trigger(r, 0.045, 0.0)
	r.mag = Vector3(0, y - 0.036, -0.07)
	r.top = Vector3(0, y + 0.03, -0.05)
	r.stock = Vector3(0, y - 0.01, 0.045)
	r.under = Vector3(0, y - 0.04, -0.33 if tube > 0.2 else r.muzzle.z + 0.05)
	r.gadget = Vector3(0, y - 0.035, 0.04)
	r.side = Vector3(0.022, y, -0.06)


static func _rifle(r: Rig) -> void:
	var y := 0.08
	var wood := mat("wood", WOOD)
	# Fore-end and wrist carved from one plank.
	_profile(r.root, [Vector2(-0.06, 0.03), Vector2(0.06, 0.0), Vector2(0.36, 0.0), Vector2(0.37, 0.03),
			Vector2(0.36, 0.055), Vector2(-0.06, 0.06), Vector2(-0.08, 0.04)], 0.036, Vector3(0, 0.02, 0), wood)
	_grip(r, Vector3(0, 0.04, 0.03), wood, Vector3(0.034, 0.09, 0.05), -28.0)
	_rod(r.root, 0.016, 0.016, 0.16, Vector3(0, y + 0.002, -0.02), mat("panel", DARK), 8)
	# Bolt handle with a knob, sticking out to the right.
	_rod_between(r.root, Vector3(0.012, y + 0.004, 0.03), Vector3(0.05, y - 0.012, 0.04), 0.004, mat("panel", STEEL))
	_ball(r.root, 0.01, Vector3(0.052, y - 0.014, 0.042), mat("panel", STEEL))
	_barrel(r, Vector3(0, y + 0.002, -0.1), 0.42, 0.009, mat("panel", STEEL))
	for z: float in [-0.2, -0.34]:
		_rod(r.root, 0.022, 0.022, 0.012, Vector3(0, y - 0.01, z), mat("brass"), 6)
	_trigger(r, 0.04, 0.0)
	if not r.parts.has("magazine"):
		_box_mag(r, Vector3(0, 0.025, -0.05), 0.035, mat("panel", DARK), 0.02, 0.05, 0.0)
	r.mag = Vector3(0, 0.025, -0.05)
	r.top = Vector3(0, y + 0.018, -0.02)
	r.stock = Vector3(0, y - 0.012, 0.075)
	r.under = Vector3(0, 0.012, -0.3)
	r.gadget = Vector3(0, 0.022, 0.06)
	r.side = Vector3(0.019, 0.05, -0.18)


static func _nail_gun(r: Rig) -> void:
	var y := 0.075
	var body := mat("panel", ORANGE)
	_grip(r, Vector3(0, 0.035, 0.022), body, Vector3(0.036, 0.11, 0.046), -10.0)
	_box(r.root, Vector3(0.04, 0.03, 0.05), Vector3(0, -0.012, 0.03), mat("panel", BLACK))
	_box(r.root, Vector3(0.054, 0.085, 0.17), Vector3(0, y, -0.03), body, Vector3.ZERO, 0.014)
	_box(r.root, Vector3(0.058, 0.02, 0.12), Vector3(0, y + 0.03, -0.03), mat("panel", BLACK), Vector3.ZERO, 0.006)
	# Motor housing at the back with vents.
	_rod(r.root, 0.038, 0.038, 0.05, Vector3(0, y + 0.005, 0.07), mat("panel", BLACK), 10)
	_disc_x(r.root, 0.026, 0.062, Vector3(0, y + 0.005, 0.07), mat("grate", Color(1.4, 1.4, 1.4)), 8)
	# Battery pack under the grip, green charge light.
	_box(r.root, Vector3(0.05, 0.032, 0.075), Vector3(0, -0.1, 0.035), mat("panel", BLACK), Vector3.ZERO, 0.006)
	_box(r.root, Vector3(0.052, 0.008, 0.012), Vector3(0, -0.09, 0.0), mat("panel", BLACK, Color(0.2, 1.0, 0.3)))
	# Nose and safety tip.
	var start := Vector3(0, y - 0.01, -0.115)
	var len := _barrel(r, start, 0.08, 0.012, mat("panel", STEEL), false)
	_rod(r.root, 0.012, 0.024, 0.04, start + Vector3(0, 0, -0.02), mat("panel", DARK), 6)
	_box(r.root, Vector3(0.03, 0.01, 0.016), r.muzzle + Vector3(0, -0.012, 0.008), mat("panel", YELLOW))
	_trigger(r, 0.035, -0.01)
	if not r.parts.has("magazine"):
		# Coil canister of nails under the nose.
		_disc_x(r.root, 0.04, 0.034, Vector3(0, 0.0, -0.09), mat("panel", DARK), 10)
		_round(r, _disc_x(r.root, 0.03, 0.036, Vector3(0, 0.0, -0.09), mat("panel", STEEL), 10))
		_box(r.root, Vector3(0.02, 0.035, 0.02), Vector3(0, 0.04, -0.1), mat("panel", DARK))
	r.mag = Vector3(0, 0.032, -0.09)
	r.top = Vector3(0, y + 0.04, -0.03)
	r.under = Vector3(0, y - 0.04, r.muzzle.z + 0.04 + len * 0.3)
	r.gadget = Vector3(0, -0.116, 0.06)
	r.side = Vector3(0.027, y - 0.005, -0.05)
	r.stock = Vector3(0, y, 0.095)


static func _crossbow(r: Rig) -> void:
	var y := 0.085
	var wood := mat("wood", WOOD)
	_box(r.root, Vector3(0.034, 0.038, 0.42), Vector3(0, y - 0.025, -0.1), wood, Vector3.ZERO, 0.008)
	_grip(r, Vector3(0, 0.05, 0.03), wood, Vector3(0.032, 0.09, 0.045), -22.0)
	_box(r.root, Vector3(0.012, 0.008, 0.36), Vector3(0, y - 0.004, -0.12), mat("panel", STEEL))
	# The prod: two car leaf springs bolted to the front, bent back.
	var front := -0.28
	for sx: float in [-1.0, 1.0]:
		var path := [Vector3(0, y - 0.01, front), Vector3(sx * 0.08, y - 0.01, front + 0.004),
				Vector3(sx * 0.16, y - 0.01, front + 0.03), Vector3(sx * 0.21, y - 0.01, front + 0.075)]
		var radii := PackedFloat32Array([0.012, 0.011, 0.009, 0.006])
		var packed := PackedVector3Array()
		for v: Vector3 in path:
			packed.append(v)
		_put(r.root, LowPoly.tube(packed, radii, 4), Vector3.ZERO, mat("rust_metal", RUST))
		# String from the limb tip to the latch.
		_rod_between(r.root, Vector3(sx * 0.21, y - 0.006, front + 0.075), Vector3(0, y + 0.002, -0.02), 0.0018, mat("panel", BONE), 3)
	_box(r.root, Vector3(0.05, 0.03, 0.03), Vector3(0, y - 0.015, front), mat("panel", DARK))
	# Stirrup loop at the front.
	_tube(r.root, [Vector3(-0.02, y - 0.02, front - 0.012), Vector3(-0.025, y - 0.04, front - 0.06),
			Vector3(0.025, y - 0.04, front - 0.06), Vector3(0.02, y - 0.02, front - 0.012)], 0.004, mat("panel", DARK), 4)
	# The loaded bolt with its head showing the ammo.
	_rod(r.root, 0.004, 0.004, 0.27, Vector3(0, y + 0.004, -0.15), mat("wood", BONE), 4)
	_round(r, _rod(r.root, 0.0, 0.009, 0.03, Vector3(0, y + 0.004, -0.3), mat("panel", STEEL), 5))
	for sx: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.002, 0.012, 0.03), Vector3(sx * 0.005, y + 0.01, -0.03), mat("panel", RED), Vector3(0, 0, sx * 30.0), 0.0)
	_trigger(r, 0.05, 0.0)
	r.muzzle = Vector3(0, y + 0.004, -0.315)
	r.top = Vector3(0, y + 0.004, 0.05)
	r.stock = Vector3(0, y - 0.025, 0.11)
	r.under = Vector3(0, y - 0.05, -0.22)
	r.gadget = Vector3(0, y - 0.046, 0.06)
	r.side = Vector3(0.018, y - 0.025, -0.13)
	r.mag_style = "none"


static func _flamethrower(r: Rig) -> void:
	var y := 0.06
	var pipe := mat("pipe", Color(1.1, 1.0, 0.95))
	_grip(r, Vector3(0, 0.045, 0.02), mat("panel", BLACK), Vector3(0.03, 0.095, 0.04), -12.0)
	_rod(r.root, 0.014, 0.014, 0.4, Vector3(0, y, -0.12), pipe, 6)
	_rod(r.root, 0.02, 0.02, 0.03, Vector3(0, y, 0.08), mat("panel", DARK), 6)
	# Nozzle with a pilot flame under it.
	_rod(r.root, 0.022, 0.016, 0.04, Vector3(0, y, -0.335), mat("panel", DARK), 6)
	_ball(r.root, 0.006, Vector3(0, y - 0.03, -0.34), mat("panel", BLACK, FIRE * 1.4), Vector3(1, 1.6, 1))
	_rod_between(r.root, Vector3(0, y - 0.016, -0.32), Vector3(0, y - 0.028, -0.34), 0.003, mat("brass"))
	r.muzzle = Vector3(0, y, -0.355)
	# Carry handle over the wand (the second hand goes here).
	_tube(r.root, [Vector3(0, y + 0.012, -0.08), Vector3(0, y + 0.05, -0.1), Vector3(0, y + 0.05, -0.17), Vector3(0, y + 0.012, -0.19)],
			0.006, mat("panel", BLACK), 5)
	if not r.parts.has("magazine"):
		_tank(r, Vector3(0, -0.005, -0.17), 0.045, 0.2, mat("panel", OLIVE))
	_trigger(r, 0.04, 0.0)
	r.mag = Vector3(0, -0.005, -0.17)
	r.gadget = Vector3(0, y - 0.02, 0.09)
	r.side = Vector3(0.016, y, -0.03)
	r.under = Vector3(0, y - 0.03, -0.25)
	r.top = Vector3(0, y + 0.02, -0.02)
	r.stock = Vector3(0, y, 0.095)
	r.mag_style = "tank"


## A capsule fuel tank lying along Z with a valve wheel, a hazard band and a hose.
static func _tank(r: Rig, pos: Vector3, radius: float, length: float, m: Material) -> void:
	var h := length / 2.0
	_lathe_z(r.root, [Vector2(0, -h), Vector2(radius * 0.7, -h + 0.008), Vector2(radius, -h + 0.03),
			Vector2(radius, h - 0.03), Vector2(radius * 0.7, h - 0.008), Vector2(0, h)], pos, m, 10)
	_rod(r.root, radius * 1.03, radius * 1.03, 0.03, pos + Vector3(0, 0, -h * 0.3), mat("panel", YELLOW), 10)
	_rod(r.root, radius * 1.04, radius * 1.04, 0.012, pos + Vector3(0, 0, -h * 0.3), mat("panel", BLACK), 10)
	_rod(r.root, 0.006, 0.006, 0.02, pos + Vector3(0, radius + 0.008, h * 0.4), mat("brass"), 5, Vector3.ZERO)
	_put(r.root, LowPoly.prism(8, 0.014, 0.014, 0.004), pos + Vector3(0, radius + 0.02, h * 0.4), mat("panel", RED))
	_tube(r.root, [pos + Vector3(0, 0, h), pos + Vector3(0, 0.0, h + 0.03), Vector3(0, 0.045, 0.1), Vector3(0, 0.06, 0.08)],
			0.007, mat("panel", BLACK), 5)


static func _tesla(r: Rig) -> void:
	var y := 0.075
	var copper := mat("brass", COPPER)
	_grip(r, Vector3(0, 0.045, 0.02), mat("wood", WOOD), Vector3(0.032, 0.1, 0.044), -16.0)
	_box(r.root, Vector3(0.05, 0.06, 0.16), Vector3(0, y, -0.02), mat("brass", Color(0.9, 0.8, 0.7)), Vector3.ZERO, 0.01)
	for z: float in [-0.08, 0.0, 0.05]:
		for sx: float in [-1.0, 1.0]:
			_ball(r.root, 0.004, Vector3(sx * 0.026, y + 0.02, z), mat("panel", DARK))
	# Coil stack around a glowing core.
	_rod(r.root, 0.01, 0.01, 0.12, Vector3(0, y, -0.15), mat("panel", BLACK, ZAP * 0.9), 6)
	for i in 4:
		_rod(r.root, 0.036 - i * 0.004, 0.036 - i * 0.004, 0.012, Vector3(0, y, -0.11 - i * 0.026), copper, 10)
	# Prongs converging on a spark ball.
	for a: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var off := Vector3(cos(a), sin(a), 0) * 0.026
		_rod_between(r.root, Vector3(0, y, -0.2) + off, Vector3(0, y, -0.25) + off * 0.25, 0.003, mat("panel", STEEL))
	_ball(r.root, 0.012, Vector3(0, y, -0.255), mat("panel", BLACK, ZAP * 1.3))
	# Glass bulb on top.
	_rod(r.root, 0.014, 0.016, 0.012, Vector3(0, y + 0.036, 0.0), copper, 8, Vector3.ZERO)
	_ball(r.root, 0.018, Vector3(0, y + 0.058, 0.0), mat("panel", Color(0.2, 0.3, 0.35), ZAP * 0.6), Vector3(1, 1.25, 1))
	if not r.parts.has("magazine"):
		# A car battery strapped under the front, with the wires to the coil.
		_box(r.root, Vector3(0.05, 0.045, 0.065), Vector3(0, y - 0.055, -0.065), mat("panel", BLACK), Vector3.ZERO, 0.004)
		_box(r.root, Vector3(0.012, 0.01, 0.012), Vector3(0.014, y - 0.028, -0.085), mat("panel", RED))
		_box(r.root, Vector3(0.012, 0.01, 0.012), Vector3(-0.014, y - 0.028, -0.085), mat("panel", DARK))
	_tube(r.root, [Vector3(0.014, y - 0.025, -0.09), Vector3(0.03, y - 0.02, -0.12), Vector3(0.03, y - 0.01, -0.15)],
			0.003, mat("panel", RED), 4)
	_trigger(r, 0.045, 0.0)
	r.barrel_start = Vector3(0, y, -0.1)
	r.barrel_r = 0.036
	r.muzzle = Vector3(0, y, -0.265)
	r.mag = Vector3(0, y - 0.03, -0.065)
	r.stock = Vector3(0, y - 0.005, 0.06)
	r.gadget = Vector3(0, y - 0.03, 0.05)
	r.side = Vector3(0.025, y, -0.03)
	r.top = Vector3(0, y + 0.03, -0.05)
	r.under = Vector3(0, y - 0.04, -0.2)
	r.mag_style = "cell"


static func _harpoon(r: Rig) -> void:
	var y := 0.07
	var hull := mat("panel", Color(0.45, 0.6, 0.5))
	_grip(r, Vector3(0, 0.045, 0.02), mat("wood", WOOD), Vector3(0.032, 0.1, 0.045), -16.0)
	_rod(r.root, 0.021, 0.021, 0.46, Vector3(0, y, -0.15), hull, 8)
	_rod(r.root, 0.025, 0.025, 0.02, Vector3(0, y, 0.08), mat("panel", DARK), 8)
	_rod(r.root, 0.025, 0.025, 0.02, Vector3(0, y, -0.375), mat("panel", DARK), 8)
	# Compressed-air bottle under the tube.
	_lathe_z(r.root, [Vector2(0, -0.07), Vector2(0.014, -0.065), Vector2(0.018, -0.05), Vector2(0.018, 0.06),
			Vector2(0.01, 0.07), Vector2(0, 0.075)], Vector3(0, y - 0.04, -0.16), mat("panel", YELLOW), 8)
	_box(r.root, Vector3(0.012, 0.02, 0.012), Vector3(0, y - 0.022, -0.1), mat("panel", DARK))
	# The loaded harpoon with its barbed head (the round).
	_rod(r.root, 0.005, 0.005, 0.14, Vector3(0, y, -0.43), mat("panel", STEEL), 5)
	_round(r, _rod(r.root, 0.0, 0.014, 0.05, Vector3(0, y, -0.52), mat("panel", STEEL), 4))
	for sx: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.003, 0.004, 0.03), Vector3(sx * 0.012, y, -0.495), mat("panel", STEEL), Vector3(0, -sx * 30.0, 0), 0.0)
	# Rope spool on the side, the line running to the harpoon.
	_disc_x(r.root, 0.03, 0.03, Vector3(0.036, y - 0.01, -0.03), mat("panel", DARK), 10)
	_disc_x(r.root, 0.024, 0.032, Vector3(0.036, y - 0.01, -0.03), mat("wood", Color(1.3, 1.2, 0.9)), 10)
	_tube(r.root, [Vector3(0.036, y + 0.01, -0.05), Vector3(0.03, y + 0.016, -0.2), Vector3(0.02, y + 0.01, -0.38),
			Vector3(0.006, y + 0.004, -0.44)], 0.0022, mat("wood", Color(1.3, 1.2, 0.9)), 3)
	_trigger(r, 0.045, 0.0)
	r.muzzle = Vector3(0, y, -0.385)
	r.top = Vector3(0, y + 0.022, -0.05)
	r.stock = Vector3(0, y - 0.005, 0.09)
	r.gadget = Vector3(0, y - 0.022, 0.06)
	r.side = Vector3(-0.02, y, -0.2)
	r.under = Vector3(0, y - 0.03, -0.3)
	r.mag_style = "none"


static func _railgun(r: Rig) -> void:
	var y := 0.08
	var housing := mat("panel", Color(0.4, 0.42, 0.46))
	_grip(r, Vector3(0, 0.045, 0.02), mat("panel", BLACK), Vector3(0.034, 0.1, 0.045), -14.0)
	_box(r.root, Vector3(0.07, 0.09, 0.27), Vector3(0, y, 0.0), housing, Vector3.ZERO, 0.012)
	_box(r.root, Vector3(0.074, 0.02, 0.04), Vector3(0, y + 0.02, -0.08), mat("panel", YELLOW), Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.05, 0.012, 0.09), Vector3(0, y + 0.046, 0.06), mat("grate", Color(1.5, 1.5, 1.5)))
	# The rails, with the charge glowing between them, clamped every so often.
	var front := -0.6
	var len := absf(front + 0.13)
	for sy: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.016, 0.018, len), Vector3(0, y + sy * 0.022, -0.13 - len / 2.0), mat("panel", STEEL), Vector3.ZERO, 0.003)
	_box(r.root, Vector3(0.006, 0.02, len - 0.02), Vector3(0, y, -0.13 - len / 2.0), mat("panel", BLACK, ZAP), Vector3.ZERO, 0.0)
	for i in 4:
		_box(r.root, Vector3(0.03, 0.07, 0.014), Vector3(0, y, -0.17 - i * 0.12), mat("rust_metal", RUST), Vector3.ZERO, 0.003)
	# Front grip and the fat orange cables.
	_box(r.root, Vector3(0.026, 0.07, 0.03), Vector3(0, y - 0.07, -0.18), mat("panel", BLACK), Vector3(-10, 0, 0), 0.006)
	for sx: float in [-1.0, 1.0]:
		_tube(r.root, [Vector3(sx * 0.035, y + 0.01, -0.1), Vector3(sx * 0.05, y + 0.0, -0.22),
				Vector3(sx * 0.03, y + 0.0, -0.36), Vector3(sx * 0.016, y, -0.42)], 0.006, mat("panel", ORANGE), 5)
	if not r.parts.has("magazine"):
		_cells(r, Vector3(0, y - 0.045, -0.03), 2, 0.018, 0.1, mat("panel", Color(0.3, 0.5, 0.8)))
	_trigger(r, 0.045, 0.0)
	r.barrel_start = Vector3(0, y, -0.13)
	r.barrel_r = 0.034
	r.muzzle = Vector3(0, y, front)
	r.top = Vector3(0, y + 0.045, -0.02)
	r.mag = Vector3(0, y - 0.045, -0.03)
	r.stock = Vector3(0, y, 0.135)
	r.gadget = Vector3(0, y - 0.045, 0.1)
	r.side = Vector3(0.035, y, -0.05)
	r.under = Vector3(0, y - 0.05, -0.4)
	r.mag_style = "cell"


## Capacitor cans lying along Z under a mount point, with glowing charge bands.
static func _cells(r: Rig, top: Vector3, count: int, radius: float, length: float, m: Material) -> void:
	for i in count:
		var x := (i - (count - 1) / 2.0) * radius * 2.1
		var pos := top + Vector3(x, -radius, 0)
		_rod(r.root, radius, radius, length, pos, m, 8)
		_rod(r.root, radius * 1.05, radius * 1.05, 0.012, pos + Vector3(0, 0, -length * 0.25), mat("panel", BLACK, ZAP), 8)
		_rod(r.root, radius * 0.5, radius * 0.5, 0.01, pos + Vector3(0, 0, length / 2.0 + 0.004), mat("panel", STEEL), 6)
	_box(r.root, Vector3(radius * 2.2 * count, 0.008, 0.02), top + Vector3(0, -0.002, 0), mat("panel", DARK))


static func _duck_launcher(r: Rig) -> void:
	var y := 0.08
	var pvc := mat("panel", Color(0.8, 0.85, 0.9))
	_grip(r, Vector3(0, 0.04, 0.02), mat("panel", BLACK), Vector3(0.032, 0.1, 0.042), -14.0)
	# Drainpipe with a flared mouth.
	_lathe_z(r.root, [Vector2(0.06, -0.34), Vector2(0.06, -0.31), Vector2(0.046, -0.3), Vector2(0.046, 0.12),
			Vector2(0.03, 0.125), Vector2(0.0, 0.126)], Vector3(0, y, 0), pvc, 10)
	_lathe_z(r.root, [Vector2(0.0, -0.315), Vector2(0.044, -0.314), Vector2(0.044, -0.2)], Vector3(0, y, 0), mat("panel", BLACK), 10)
	for z: float in [-0.22, 0.0]:
		_rod(r.root, 0.049, 0.049, 0.03, Vector3(0, y, z), mat("panel", YELLOW), 10)
		_rod(r.root, 0.05, 0.05, 0.01, Vector3(0, y, z), mat("panel", BLACK), 10)
	# The next duck peeking out of the mouth.
	_duck(r.root, Vector3(0, y - 0.012, -0.335), 1.0)
	# Bicycle horn bolted on the side: squeeze to quack.
	_ball(r.root, 0.018, Vector3(0.06, y + 0.01, 0.06), mat("panel", RED), Vector3(1, 1, 1.3))
	_rod(r.root, 0.018, 0.005, 0.05, Vector3(0.06, y + 0.01, 0.02), mat("brass"), 8)
	_box(r.root, Vector3(0.026, 0.07, 0.03), Vector3(0, y - 0.075, -0.16), mat("panel", BLACK), Vector3(-10, 0, 0), 0.006)
	_trigger(r, 0.035, 0.0)
	r.muzzle = Vector3(0, y, -0.34)
	r.top = Vector3(0, y + 0.046, 0.0)
	r.mag = Vector3(-0.046, y, -0.07)
	r.stock = Vector3(0, y - 0.01, 0.125)
	r.gadget = Vector3(0, y - 0.046, 0.08)
	r.side = Vector3(0.046, y, -0.1)
	r.under = Vector3(0, y - 0.05, -0.26)
	r.mag_style = "hopper"


## A rubber duck facing -Z (the duck launcher's round).
static func _duck(p: Node3D, pos: Vector3, s: float) -> void:
	var yellow := mat("panel", Color(1.5, 1.25, 0.15))
	_ball(p, 0.03 * s, pos + Vector3(0, 0, 0.012) * s, yellow, Vector3(1, 0.75, 1.2))
	_ball(p, 0.02 * s, pos + Vector3(0, 0.03, -0.012) * s, yellow)
	_box(p, Vector3(0.02, 0.006, 0.016) * s, pos + Vector3(0, 0.026, -0.034) * s, mat("panel", ORANGE), Vector3.ZERO, 0.002)
	for sx: float in [-1.0, 1.0]:
		_box(p, Vector3(0.005, 0.005, 0.003) * s, pos + Vector3(sx * 0.009, 0.036, -0.03) * s, mat("panel", BLACK), Vector3.ZERO, 0.0)
	_box(p, Vector3(0.012, 0.012, 0.012) * s, pos + Vector3(0, 0.012, 0.045) * s, yellow, Vector3(30, 0, 0), 0.002)


static func _saw_launcher(r: Rig) -> void:
	var y := 0.07
	var body := mat("panel", Color(1.2, 0.25, 0.2))
	_grip(r, Vector3(0, 0.035, 0.022), mat("panel", BLACK), Vector3(0.034, 0.1, 0.044), -12.0)
	_box(r.root, Vector3(0.05, 0.065, 0.19), Vector3(0, y - 0.005, -0.02), body, Vector3.ZERO, 0.012)
	_rod(r.root, 0.034, 0.034, 0.06, Vector3(0, y + 0.005, 0.1), mat("panel", BLACK), 10)
	_disc_x(r.root, 0.022, 0.07, Vector3(0, y + 0.005, 0.1), mat("grate", Color(1.4, 1.4, 1.4)), 8)
	# Launch deck: the loaded blade sits flat on top, half under a guard.
	_box(r.root, Vector3(0.09, 0.008, 0.12), Vector3(0, y + 0.03, -0.14), mat("panel", DARK), Vector3.ZERO, 0.002)
	_blade(r.root, Vector3(0, y + 0.042, -0.15), 0.072)
	# A yellow guard round the back half of the blade, bolted to the body.
	var arc := []
	for i in 9:
		var a := PI * i / 8.0
		arc.append(Vector3(cos(a) * 0.074, y + 0.046, -0.15 + sin(a) * 0.074))
	_tube(r.root, arc, 0.007, mat("panel", YELLOW), 4)
	_box(r.root, Vector3(0.06, 0.022, 0.03), Vector3(0, y + 0.04, -0.07), mat("panel", YELLOW), Vector3.ZERO, 0.006)
	_box(r.root, Vector3(0.012, 0.026, 0.012), Vector3(0, y + 0.05, -0.15), mat("panel", DARK))
	# Spring arms that fling it.
	for sx: float in [-1.0, 1.0]:
		_rod_between(r.root, Vector3(sx * 0.04, y + 0.035, -0.06), Vector3(sx * 0.055, y + 0.035, -0.2), 0.004, mat("panel", STEEL))
	_trigger(r, 0.035, 0.0)
	if not r.parts.has("magazine"):
		_blade_stack(r, Vector3(0, y - 0.04, -0.08), 3)
	r.muzzle = Vector3(0, y + 0.04, -0.22)
	r.top = Vector3(0, y + 0.028, 0.04)
	r.mag = Vector3(0, y - 0.04, -0.08)
	r.stock = Vector3(0, y - 0.005, 0.13)
	r.gadget = Vector3(0, y - 0.04, 0.05)
	r.side = Vector3(0.026, y - 0.01, 0.0)
	r.under = Vector3(0, y - 0.045, -0.15)
	r.mag_style = "blades"


## A flat circular saw blade (teeth out) at `pos`, lying in the XZ plane.
static func _blade(p: Node3D, pos: Vector3, radius: float) -> void:
	var outline := PackedVector2Array()
	var teeth := 14
	for i in teeth:
		var a := TAU * i / teeth
		var b := TAU * (i + 0.6) / teeth
		outline.append(Vector2(cos(a), sin(a)) * radius * 0.82)
		outline.append(Vector2(cos(b), sin(b)) * radius)
	# Tipped up a little at the front so it reads from the side too.
	_put(p, LowPoly.extrude(outline, 0.005), pos, mat("panel", Color(1.3, 1.32, 1.38)), Vector3(80, 0, 0))
	_put(p, LowPoly.prism(8, radius * 0.25, radius * 0.25, 0.009), pos, mat("panel", RED), Vector3(-10, 0, 0))


## Spare blades stacked in a little cage under the body.
static func _blade_stack(r: Rig, top: Vector3, count: int) -> void:
	for i in count:
		_put(r.root, LowPoly.prism(12, 0.045, 0.045, 0.004), top + Vector3(0, -0.006 - i * 0.008, 0), mat("panel", STEEL))
	for sx: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.004, 0.012 + count * 0.008, 0.004), top + Vector3(sx * 0.05, -count * 0.004, 0), mat("panel", DARK))
	_box(r.root, Vector3(0.1, 0.004, 0.02), top + Vector3(0, -0.01 - count * 0.008, 0), mat("panel", DARK))


static func _bubble_gun(r: Rig) -> void:
	var y := 0.07
	var pink := mat("panel", PINK)
	var teal := mat("panel", TEAL)
	_grip(r, Vector3(0, 0.04, 0.015), teal, Vector3(0.032, 0.09, 0.04), -12.0)
	_box(r.root, Vector3(0.05, 0.06, 0.14), Vector3(0, y, -0.02), pink, Vector3.ZERO, 0.018)
	_rod(r.root, 0.018, 0.026, 0.06, Vector3(0, y, -0.12), teal, 8)
	# Bubble wand ring at the muzzle, a few bubbles drifting off it.
	_tube(r.root, _ring(Vector3(0, y, -0.158), 0.026, 10), 0.004, mat("panel", YELLOW), 4)
	var bubble := mat("panel", Color(0.35, 0.5, 0.6), Color(0.2, 0.45, 0.55))
	_ball(r.root, 0.012, Vector3(0.03, y + 0.03, -0.19), bubble)
	_ball(r.root, 0.008, Vector3(-0.025, y + 0.045, -0.17), bubble)
	_ball(r.root, 0.006, Vector3(0.01, y + 0.06, -0.21), bubble)
	# The soap bottle, upside down on top.
	_lathe_z(r.root, [Vector2(0.0, -0.03), Vector2(0.022, -0.028), Vector2(0.024, 0.02), Vector2(0.01, 0.03), Vector2(0.006, 0.04),
			Vector2(0.0, 0.04)], Vector3.ZERO, mat("panel", Color(0.6, 0.35, 1.2), Color(0.12, 0.05, 0.2)), 8).transform = \
			LowPoly.at(Vector3(0, y + 0.07, 0.01), Vector3(180, 0, 0))
	_box(r.root, Vector3(0.012, 0.012, 0.012), Vector3(0, y + 0.034, 0.01), teal)
	_trigger(r, 0.04, 0.0)
	r.muzzle = Vector3(0, y, -0.16)
	r.mag = Vector3(0, y - 0.03, -0.06)
	r.gadget = Vector3(0, y - 0.03, 0.03)
	r.side = Vector3(0.025, y, -0.04)
	r.top = Vector3(0, y + 0.03, -0.06)
	r.stock = Vector3(0, y, 0.05)
	r.under = Vector3(0, y - 0.03, -0.12)
	r.mag_style = "cell"


static func _ring(centre: Vector3, radius: float, segments: int) -> Array:
	var points := []
	for i in segments + 1:
		var a := TAU * i / segments
		points.append(centre + Vector3(cos(a), sin(a), 0) * radius)
	return points


# --- Parts ----------------------------------------------------------------------------

static func _attach_parts(r: Rig) -> void:
	var p: Dictionary = r.parts.duplicate()
	# Organs are grown on, not bolted: each slot's organ is the monster's model, small.
	for slot in Arsenal.SLOTS:
		if p.has(slot) and Arsenal.is_organ(p[slot]):
			_organ_on_gun(r, slot, p[slot])
			p.erase(slot)
	if p.get("barrel", "") == "coil_barrel":
		_coil_barrel(r)
	if p.has("muzzle"):
		_muzzle(r, p.muzzle)
	if p.has("sight"):
		_sight(r, p.sight)
	if p.has("magazine"):
		_magazine(r, p.magazine)
	if p.has("stock"):
		_stock(r, p.stock)
	if p.has("underbarrel"):
		_underbarrel(r, p.underbarrel)
	if p.has("ammo"):
		_ammo(r, p.ammo)
	if p.has("gadget"):
		_gadget(r, p.gadget)


static func _coil_barrel(r: Rig) -> void:
	var copper := mat("brass", COPPER)
	var length := 0.1
	var start := r.muzzle
	_rod(r.root, 0.008, 0.008, length + 0.01, start + Vector3(0, 0, -length / 2.0), mat("panel", BLACK, ZAP), 6)
	for i in 6:
		_rod(r.root, r.barrel_r * 0.55 + 0.012, r.barrel_r * 0.55 + 0.012, 0.009, start + Vector3(0, 0, -0.008 - i * 0.017), copper, 8)
	_rod(r.root, 0.006, 0.006, length, start + Vector3(0.0, r.barrel_r * 0.55 + 0.014, -length / 2.0), mat("panel", DARK), 4)
	r.muzzle = start + Vector3(0, 0, -length)


static func _muzzle(r: Rig, id: String) -> void:
	var m := r.muzzle
	var br := maxf(r.barrel_r, 0.009)
	match id:
		"suppressor":
			# An oil filter on a pipe adapter, hose-clamped on.
			_rod(r.root, br * 1.3, br * 1.3, 0.02, m + Vector3(0, 0, -0.01), mat("panel", DARK), 6)
			var rad := maxf(br * 2.2, 0.022)
			_rod(r.root, rad, rad, 0.13, m + Vector3(0, 0, -0.085), mat("panel", Color(0.25, 0.32, 0.6)), 10)
			_rod(r.root, rad * 1.05, rad * 1.05, 0.03, m + Vector3(0, 0, -0.085), mat("panel", BONE), 10)
			_rod(r.root, rad * 0.8, rad * 0.8, 0.008, m + Vector3(0, 0, -0.152), mat("panel", BLACK), 10)
			r.muzzle = m + Vector3(0, 0, -0.155)
		"compensator":
			var size := maxf(br * 2.6, 0.024)
			_box(r.root, Vector3(size, size, 0.045), m + Vector3(0, 0, -0.022), mat("panel", DARK), Vector3.ZERO, 0.004)
			for i in 3:
				_box(r.root, Vector3(size * 0.7, 0.006, 0.006), m + Vector3(0, size / 2.0, -0.01 - i * 0.012), mat("panel", BLACK, FIRE * 0.25), Vector3.ZERO, 0.0)
			r.muzzle = m + Vector3(0, 0, -0.045)
		"choke":
			_rod(r.root, br * 0.9, br * 1.35, 0.055, m + Vector3(0, 0, -0.027), mat("brass"), 8)
			r.muzzle = m + Vector3(0, 0, -0.055)
		"wide_nozzle":
			_lathe_z(r.root, [Vector2(0.0, -0.075), Vector2(0.05, -0.074), Vector2(0.05, -0.068), Vector2(0.022, -0.02), Vector2(0.018, 0.0),
					Vector2(0.0, 0.002)], m, mat("brass", COPPER), 10)
			r.muzzle = m + Vector3(0, 0, -0.075)


static func _sight(r: Rig, id: String) -> void:
	var t := r.top
	var dark := mat("panel", BLACK)
	_box(r.root, Vector3(0.018, 0.008, 0.07), t + Vector3(0, 0.004, 0), mat("panel", DARK), Vector3.ZERO, 0.002)
	match id:
		"red_dot":
			_box(r.root, Vector3(0.03, 0.012, 0.045), t + Vector3(0, 0.014, 0), dark, Vector3.ZERO, 0.004)
			_box(r.root, Vector3(0.03, 0.03, 0.006), t + Vector3(0, 0.032, -0.016), dark, Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.022, 0.022, 0.002), t + Vector3(0, 0.032, -0.02), mat("panel", Color(0.3, 0.1, 0.1), Color(0.35, 0.02, 0.02)), Vector3.ZERO, 0.0)
			_ball(r.root, 0.0035, t + Vector3(0, 0.032, -0.022), mat("panel", BLACK, Color(1.0, 0.1, 0.05)))
			_box(r.root, Vector3(0.008, 0.008, 0.012), t + Vector3(0.018, 0.02, 0.005), mat("panel", RED))
		"scope":
			var c := t + Vector3(0, 0.03, 0.0)
			for z: float in [-0.025, 0.025]:
				_box(r.root, Vector3(0.012, 0.024, 0.012), t + Vector3(0, 0.016, z), mat("panel", DARK))
			_rod(r.root, 0.012, 0.012, 0.1, c, dark, 8)
			_rod(r.root, 0.021, 0.013, 0.045, c + Vector3(0, 0, -0.07), dark, 8)
			_rod(r.root, 0.016, 0.012, 0.03, c + Vector3(0, 0, 0.06), dark, 8)
			_rod(r.root, 0.019, 0.019, 0.003, c + Vector3(0, 0, -0.093), mat("panel", Color(0.2, 0.3, 0.4), Color(0.1, 0.25, 0.4)), 8)
			_rod(r.root, 0.007, 0.007, 0.012, c + Vector3(0, 0.016, 0), mat("panel", DARK), 6, Vector3.ZERO)
			_disc_x(r.root, 0.007, 0.012, c + Vector3(0.016, 0, 0), mat("panel", DARK), 6)
			# A strip of tape where the scope was taped on a bit crooked.
			_box(r.root, Vector3(0.03, 0.03, 0.012), c + Vector3(0, -0.005, 0.03), mat("panel", TAPE), Vector3(0, 0, 8), 0.004)
		"thermal":
			var c := t + Vector3(0, 0.03, 0.0)
			_box(r.root, Vector3(0.042, 0.044, 0.09), c, mat("panel", Color(0.42, 0.48, 0.38)), Vector3.ZERO, 0.008)
			_rod(r.root, 0.02, 0.02, 0.02, c + Vector3(0, 0, -0.055), dark, 8)
			_rod(r.root, 0.016, 0.016, 0.003, c + Vector3(0, 0, -0.066), mat("panel", Color(0.3, 0.1, 0.05), Color(0.6, 0.15, 0.02)), 8)
			_box(r.root, Vector3(0.032, 0.026, 0.003), c + Vector3(0, 0.002, 0.046), mat("panel", BLACK, Color(1.0, 0.45, 0.05)), Vector3.ZERO, 0.0)
			_box(r.root, Vector3(0.01, 0.006, 0.01), c + Vector3(0.016, 0.025, 0.02), mat("panel", RED, Color(0.6, 0.0, 0.0)), Vector3.ZERO, 0.0)
			_tube(r.root, [c + Vector3(-0.021, -0.01, 0.03), c + Vector3(-0.03, -0.03, 0.05), r.side * Vector3(-1, 1, 1) + Vector3(0, 0, 0.06)],
					0.003, mat("panel", BLACK), 4)


static func _magazine(r: Rig, id: String) -> void:
	var t := r.mag
	match r.mag_style:
		"tank":
			if id == "big_tank":
				_tank(r, t + Vector3(0, -0.012, 0.0), 0.06, 0.26, mat("panel", RED))
				_box(r.root, Vector3(0.13, 0.012, 0.016), t + Vector3(0, -0.012, -0.06), mat("panel", BLACK), Vector3.ZERO, 0.002)
			return
		"cell":
			if id == "capacitor":
				_cells(r, t, 3 if r.frame != "bubble_gun" else 2, 0.016, 0.11, mat("panel", Color(0.95, 0.75, 0.2)))
			return
		"hopper":
			var size := 0.09 if id == "extended_mag" else 0.06
			_box(r.root, Vector3(0.05, size, 0.08), t + Vector3(-0.022, size * 0.15, 0), mat("panel", YELLOW), Vector3.ZERO, 0.006)
			for i in (3 if id == "extended_mag" else 2):
				_duck(r.root, t + Vector3(-0.022, size * 0.65, -0.02 + i * 0.03), 0.45)
			if id == "quick_mag":
				_tube(r.root, [t + Vector3(-0.05, 0.0, 0.03), t + Vector3(-0.07, -0.02, 0.04), t + Vector3(-0.05, -0.03, 0.03)], 0.004, mat("panel", RED), 4)
			return
		"blades":
			_blade_stack(r, t, 6 if id == "extended_mag" else 3)
			if id == "quick_mag":
				_tube(r.root, [t + Vector3(0.05, -0.02, 0.0), t + Vector3(0.07, -0.04, 0.0), t + Vector3(0.05, -0.05, 0.0)], 0.004, mat("panel", RED), 4)
			return
	var steel := mat("panel", DARK)
	var scale := 1.0
	match r.frame:
		"revolver": scale = 0.7
		"shotgun": scale = 0.9
	match id:
		"extended_mag":
			_box_mag(r, t, 0.19 * scale, steel)
			_box(r.root, Vector3(0.026, 0.03, 0.036), t + Vector3(0, -0.1 * scale, -0.012), mat("panel", TAPE), Vector3(8, 0, 0), 0.003)
		"drum_mag":
			_box(r.root, Vector3(0.026, 0.03, 0.03), t + Vector3(0, -0.012, 0), steel)
			var c := t + Vector3(0, -0.075 * scale, 0.0)
			_disc_x(r.root, 0.062 * scale, 0.05, c, steel, 12)
			_disc_x(r.root, 0.05 * scale, 0.054, c, mat("panel", Color(0.5, 0.52, 0.56)), 12)
			_disc_x(r.root, 0.012, 0.058, c, mat("panel", RED), 6)
			_round(r, _rod(r.root, 0.006, 0.006, 0.028, t + Vector3(0, 0.004, -0.004), mat("brass"), 5))
		"quick_mag":
			# Two mags taped together, with a pull loop.
			_box_mag(r, t, 0.12 * scale, steel)
			_box(r.root, Vector3(0.022, 0.12 * scale, 0.034), t + Vector3(0.024, -0.075 * scale, -0.008), steel, Vector3(8, 0, 0))
			_box(r.root, Vector3(0.05, 0.022, 0.04), t + Vector3(0.012, -0.065 * scale, -0.008), mat("panel", TAPE), Vector3(8, 0, 0), 0.003)
			_tube(r.root, [t + Vector3(0, -0.12 * scale, 0.0), t + Vector3(0, -0.14 * scale, 0.01), t + Vector3(0, -0.13 * scale, -0.02)], 0.004, mat("panel", ORANGE), 4)


static func _stock(r: Rig, id: String) -> void:
	var s := r.stock
	match id:
		"heavy_stock":
			_profile(r.root, [Vector2(0.0, 0.016), Vector2(-0.22, 0.022), Vector2(-0.235, -0.085), Vector2(-0.2, -0.092),
					Vector2(-0.06, -0.035), Vector2(0.0, -0.025)], 0.036, s, mat("wood", WOOD))
			_box(r.root, Vector3(0.04, 0.112, 0.016), s + Vector3(0, -0.033, 0.232), mat("panel", BLACK), Vector3(-4, 0, 0), 0.004)
			_box(r.root, Vector3(0.04, 0.03, 0.03), s + Vector3(0, 0.0, 0.01), mat("panel", DARK), Vector3.ZERO, 0.004)
		"light_stock":
			var steel := mat("panel", STEEL)
			_tube(r.root, [s, s + Vector3(0, 0.002, 0.2)], 0.005, steel, 5)
			_tube(r.root, [s + Vector3(0, -0.03, 0.0), s + Vector3(0, -0.07, 0.19)], 0.005, steel, 5)
			_tube(r.root, [s + Vector3(0, 0.012, 0.2), s + Vector3(0, -0.085, 0.2)], 0.006, steel, 5)
			_box(r.root, Vector3(0.03, 0.014, 0.05), s + Vector3(0, 0.004, 0.13), mat("panel", TAPE), Vector3.ZERO, 0.004)
			_box(r.root, Vector3(0.026, 0.1, 0.012), s + Vector3(0, -0.036, 0.205), mat("panel", BLACK), Vector3.ZERO, 0.004)


static func _underbarrel(r: Rig, id: String) -> void:
	var u := r.under
	match id:
		"flashlight":
			_box(r.root, Vector3(0.012, 0.016, 0.02), u + Vector3(0, 0.01, 0), mat("panel", DARK))
			_rod(r.root, 0.012, 0.012, 0.08, u + Vector3(0, -0.006, 0.01), mat("panel", Color(0.75, 0.6, 0.2)), 8)
			_rod(r.root, 0.017, 0.013, 0.025, u + Vector3(0, -0.006, -0.04), mat("panel", BLACK), 8)
			_rod(r.root, 0.014, 0.014, 0.003, u + Vector3(0, -0.006, -0.053), mat("panel", BONE, Color(1.0, 0.95, 0.7)), 8)
			_box(r.root, Vector3(0.03, 0.01, 0.016), u + Vector3(0, 0.002, 0.03), mat("panel", TAPE), Vector3.ZERO, 0.003)
		"laser":
			_box(r.root, Vector3(0.012, 0.014, 0.014), u + Vector3(0, 0.01, 0), mat("panel", DARK))
			_box(r.root, Vector3(0.018, 0.018, 0.05), u + Vector3(0, -0.004, 0), mat("panel", Color(0.5, 0.15, 0.15)), Vector3.ZERO, 0.004)
			_rod(r.root, 0.005, 0.005, 0.004, u + Vector3(0, -0.004, -0.026), mat("panel", BLACK, Color(1.0, 0.05, 0.05)), 6)
		"bayonet":
			var mount := Vector3(u.x, u.y, r.barrel_start.z - (r.barrel_start.z - u.z) * 0.6)
			_box(r.root, Vector3(0.012, 0.02, 0.04), mount, mat("panel", DARK))
			var blade_start := mount + Vector3(0, -0.006, -0.02)
			var reach := maxf(0.1, blade_start.z - r.muzzle.z + 0.08)
			_profile(r.root, [Vector2(0.0, 0.006), Vector2(reach * 0.85, 0.006), Vector2(reach, 0.0), Vector2(reach * 0.8, -0.012),
					Vector2(0.0, -0.01)], 0.004, blade_start, mat("panel", Color(0.9, 0.93, 0.98)))


static func _ammo(r: Rig, id: String) -> void:
	var look: Array = AMMO_LOOK.get(id, [Color.WHITE, Color.BLACK])
	var m := mat("panel", look[0], look[1])
	for node in r.rounds:
		node.material_override = m
	# A little holder on the side with spares, so the ammo reads from any angle.
	var s := r.side
	var out := signf(s.x) if s.x != 0.0 else 1.0
	var bolt := r.frame in ["crossbow", "harpoon"]
	_box(r.root, Vector3(0.004, 0.022, 0.06), s + Vector3(out * 0.003, 0, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
	for i in 3 if bolt else 4:
		var z := (i - 1.5) * 0.015
		if bolt:
			_rod(r.root, 0.003, 0.003, 0.08, s + Vector3(out * 0.009, 0.006 - i * 0.008, z * 0.4), mat("wood", BONE), 4)
			_rod(r.root, 0.0, 0.006, 0.02, s + Vector3(out * 0.009, 0.006 - i * 0.008, z * 0.4 - 0.05), m, 4)
		else:
			_rod(r.root, 0.005, 0.005, 0.03, s + Vector3(out * 0.009, 0.002, z), m, 5, Vector3.ZERO)
			_rod(r.root, 0.0055, 0.0055, 0.008, s + Vector3(out * 0.009, -0.014, z), mat("brass"), 5, Vector3.ZERO)


static func _gadget(r: Rig, id: String) -> void:
	if id == "spring_bolt":
		# A fat spring bolted along the left of the receiver.
		var s := Vector3(-absf(r.side.x) - 0.008, r.side.y + 0.012, r.side.z + 0.02)
		var points := []
		for i in 25:
			var a := TAU * i / 6.0
			points.append(s + Vector3(cos(a) * 0.008, sin(a) * 0.008, -0.05 + i * 0.004))
		_tube(r.root, points, 0.0022, mat("panel", STEEL), 3)
		for z: float in [-0.054, 0.05]:
			_box(r.root, Vector3(0.008, 0.02, 0.006), s + Vector3(0.004, 0, z), mat("panel", DARK))
		return
	# Everything else is a charm on a short chain.
	var g := r.gadget
	var hang := g + Vector3(0.004, -0.04, 0.012)
	_tube(r.root, [g, g + Vector3(0.002, -0.014, 0.004), g + Vector3(0.0, -0.028, 0.01), hang], 0.0018, mat("brass"), 3)
	var c := hang + Vector3(0, -0.012, 0)
	match id:
		"vampire_charm":
			var fur := mat("panel", Color(0.35, 0.2, 0.4))
			_ball(r.root, 0.009, c, fur, Vector3(1, 1.2, 0.9))
			for sx: float in [-1.0, 1.0]:
				_put(r.root, LowPoly.extrude(PackedVector2Array([Vector2(0, 0.004), Vector2(sx * 0.028, 0.012), Vector2(sx * 0.022, 0.0),
						Vector2(sx * 0.016, -0.004), Vector2(sx * 0.01, -0.002), Vector2(0, -0.004)]), 0.002), c, fur)
				_box(r.root, Vector3(0.003, 0.003, 0.002), c + Vector3(sx * 0.003, 0.004, -0.008), mat("panel", BLACK, Color(1, 0.05, 0.05)), Vector3.ZERO, 0.0)
				_box(r.root, Vector3(0.003, 0.006, 0.003), c + Vector3(sx * 0.004, 0.012, 0), fur, Vector3(0, 0, sx * -15.0), 0.0)
		"ghost_chamber":
			var ghost := mat("panel", Color(0.8, 0.95, 0.9), Color(0.25, 0.5, 0.4))
			_ball(r.root, 0.011, c + Vector3(0, -0.002, 0), ghost)
			_rod(r.root, 0.011, 0.0, 0.016, c + Vector3(0, -0.014, 0), ghost, 6, Vector3(180, 0, 0))
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.003, 0.005, 0.002), c + Vector3(sx * 0.004, 0.0, -0.01), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"lucky_cat":
			var white := mat("panel", BONE)
			_ball(r.root, 0.012, c + Vector3(0, -0.006, 0), white, Vector3(1, 1.1, 0.9))
			_ball(r.root, 0.01, c + Vector3(0, 0.01, 0), white)
			for sx: float in [-1.0, 1.0]:
				_rod(r.root, 0.0, 0.004, 0.008, c + Vector3(sx * 0.006, 0.02, 0), white, 4, Vector3.ZERO)
			_box(r.root, Vector3(0.004, 0.012, 0.004), c + Vector3(0.012, 0.006, 0), white, Vector3(0, 0, -20), 0.001)
			_rod(r.root, 0.0085, 0.0085, 0.003, c + Vector3(0, 0.002, 0), mat("panel", RED), 8, Vector3.ZERO)
			_disc_x(r.root, 0.006, 0.002, c + Vector3(0, -0.006, -0.011), mat("brass", Color(1.3, 1.1, 0.5)), 8).rotation_degrees = Vector3(90, 0, 0)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.003, 0.0015, 0.002), c + Vector3(sx * 0.004, 0.012, -0.009), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"echo_bell":
			_lathe_z(r.root, [Vector2(0.0, -0.014), Vector2(0.004, -0.013), Vector2(0.007, -0.006), Vector2(0.008, 0.004),
					Vector2(0.012, 0.01), Vector2(0.0, 0.01)], Vector3.ZERO, mat("brass", Color(1.3, 1.1, 0.6)), 8).transform = \
					LowPoly.at(c + Vector3(0, -0.002, 0), Vector3(180, 0, 0))
			_ball(r.root, 0.003, c + Vector3(0, -0.014, 0), mat("panel", DARK))



# --- Organs ---------------------------------------------------------------------------
# Every monster's organ is its own gory low-poly lump. Each is drawn in "unit" space (about
# a metre long, front toward -Z), then fitted to the size asked for: the floor loot is
# 0.3-1 m, the same model grown onto a gun is a few centimetres.

const FLESH := Color(1.3, 0.66, 0.58)
const MEAT := Color(1.15, 0.26, 0.22)
const GORE := Color(0.6, 0.05, 0.05)
const BILE := Color(0.55, 1.25, 0.25)
const PALE := Color(1.3, 1.25, 1.18)
const CHITIN := Color(0.4, 0.33, 0.3)
const SINEW := Color(1.2, 0.85, 0.7)

## Texture density for the organ being built (keeps texels about the same size at any scale).
static var _od := 7.0


## A finished model of an organ part, centred on the origin, `length` metres on its longest side.
static func organ(id: String, length := 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Organ_" + id
	var body := Node3D.new()
	root.add_child(body)
	_od = clampf(7.0 * length, 1.2, 7.0)
	match id:
		"colossus_heart": _o_colossus_heart(body)
		"watcher_eye": _o_watcher_eye(body)
		"centipede_segment": _o_centipede_segment(body)
		"mother_musicbox": _o_mother_musicbox(body)
		"burrower_drill": _o_burrower_drill(body)
		"knight_door": _o_knight_door(body)
		"mannequin_arm": _o_mannequin_arm(body)
		"mimic_shell": _o_mimic_shell(body)
		"greeter_smile": _o_greeter_smile(body)
		"collector_sack": _o_collector_sack(body)
		"rat_spring": _o_rat_spring(body)
		"fog_lung": _o_fog_lung(body)
		"tuner_cords": _o_tuner_cords(body)
		"child_marble": _o_child_marble(body)
		"spitter_sac": _o_spitter_sac(body)
		"splitter_core": _o_splitter_core(body)
		"dropper_arm": _o_dropper_arm(body)
		"screamer_mask": _o_screamer_mask(body)
		"hound_fang": _o_hound_fang(body)
		"weaver_gland": _o_weaver_gland(body)
		"stalker_shadow": _o_stalker_shadow(body)
		"eye_lens": _o_eye_lens(body)
		_: _ball(body, 0.4, Vector3.ZERO, _om("concrete", MEAT), Vector3.ONE, 0.2)
	var box := AABB()
	var first := true
	for child in body.get_children():
		if child is MeshInstance3D:
			var mesh_box: AABB = child.transform * (child as MeshInstance3D).get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := length / maxf(longest, 0.001)
	body.scale = Vector3.ONE * s
	body.position = -box.get_center() * s
	root.set_meta("organ", id)
	return root


## An organ material at this organ's texel density.
static func _om(texture: String, tint := Color.WHITE, glow := Color.BLACK) -> ShaderMaterial:
	return mat(texture, tint, glow, _od)


## A tube that tapers from r0 at the first point to r1 at the last.
static func _taper(p: Node3D, points: Array, r0: float, r1: float, m: Material, sides := 5) -> MeshInstance3D:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in points.size():
		path.append(points[i])
		radii.append(lerpf(r0, r1, float(i) / maxf(points.size() - 1, 1)))
	return _put(p, LowPoly.tube(path, radii, sides), Vector3.ZERO, m)


## Wet red veins wandering over a ball of radius r at c.
static func _veins(p: Node3D, c: Vector3, r: float, count: int, seed: int, m: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var a := rng.randf_range(0.0, TAU)
		var b := rng.randf_range(-0.9, 0.9)
		var points := []
		for k in 4:
			var aa := a + k * 0.35
			var bb := b + rng.randf_range(-0.25, 0.25)
			points.append(c + Vector3(cos(aa) * cos(bb), sin(bb), sin(aa) * cos(bb)) * r * 1.02)
		_taper(p, points, r * 0.06, r * 0.02, m, 4)


static func _organ_on_gun(r: Rig, slot: String, id: String) -> void:
	var size := 0.08
	var at := Vector3.ZERO
	match slot:
		"muzzle":
			size = 0.085
			at = r.muzzle + Vector3(0, 0, -size * 0.45)
			_rod(r.root, maxf(r.barrel_r, 0.009) * 1.3, maxf(r.barrel_r, 0.009) * 1.3, 0.02, r.muzzle + Vector3(0, 0, -0.008), mat("panel", DARK), 6)
			r.muzzle = r.muzzle + Vector3(0, 0, -size * 0.9)
		"barrel":
			size = maxf(0.1, r.barrel_start.distance_to(r.muzzle) * 0.6)
			at = r.barrel_start.lerp(r.muzzle, 0.55)
		"sight":
			size = 0.09
			at = r.top + Vector3(0, 0.04, 0)
			_box(r.root, Vector3(0.018, 0.008, 0.06), r.top + Vector3(0, 0.004, 0), mat("panel", DARK), Vector3.ZERO, 0.002)
		"magazine":
			size = 0.11
			at = r.mag + Vector3(0, -0.05, 0)
		"stock":
			size = 0.19
			at = r.stock + Vector3(0, -0.025, 0.1)
		"underbarrel":
			size = 0.12
			at = r.under + Vector3(0, -0.018, 0)
		"ammo":
			size = 0.055
			at = r.side + Vector3(signf(r.side.x if r.side.x != 0.0 else 1.0) * 0.03, 0, 0)
			var m := mat("panel", MEAT, GORE * 0.4)
			for node in r.rounds:
				node.material_override = m
		"gadget":
			size = 0.045
			var g := r.gadget
			var hang := g + Vector3(0.004, -0.04, 0.012)
			_tube(r.root, [g, g + Vector3(0.002, -0.014, 0.004), g + Vector3(0.0, -0.028, 0.01), hang], 0.0018, mat("brass"), 3)
			at = hang + Vector3(0, -0.026, 0)
	var model := organ(id, size)
	model.position = at
	# A twist of sinew holds it on: it's grown into the gun.
	r.root.add_child(model)


static func _o_colossus_heart(p: Node3D) -> void:
	var meat := _om("concrete", MEAT)
	var dark := _om("concrete", GORE)
	_ball(p, 0.4, Vector3.ZERO, meat, Vector3(1.0, 1.15, 0.95), 0.16)
	_ball(p, 0.28, Vector3(0.14, -0.3, 0.05), dark, Vector3(1.0, 1.1, 1.0), 0.22)
	_ball(p, 0.17, Vector3(0.12, 0.02, -0.33), _om("panel", FIRE, FIRE * 0.9), Vector3(1.0, 1.4, 0.6), 0.2)
	_ball(p, 0.1, Vector3(-0.3, -0.12, -0.18), _om("panel", FIRE, FIRE * 0.7), Vector3.ONE, 0.25)
	var brass := _om("brass", COPPER)
	_taper(p, [Vector3(-0.12, 0.3, 0.0), Vector3(-0.16, 0.52, 0.02), Vector3(-0.08, 0.66, 0.05)], 0.09, 0.07, brass, 7)
	_taper(p, [Vector3(0.16, 0.28, 0.08), Vector3(0.24, 0.5, 0.12), Vector3(0.36, 0.58, 0.1)], 0.07, 0.06, brass, 7)
	_rod(p, 0.11, 0.11, 0.04, Vector3(-0.08, 0.68, 0.05), _om("rust_metal", RUST), 8, Vector3.ZERO)
	_disc_x(p, 0.07, 0.03, Vector3(0.38, 0.58, 0.1), _om("panel", RED), 8)
	for i in 7:
		var a := TAU * i / 7.0
		_box(p, Vector3(0.05, 0.05, 0.05), Vector3(cos(a) * 0.38, 0.12 + sin(a * 2.0) * 0.08, sin(a) * 0.36), _om("rust_metal", DARK), Vector3(0, rad_to_deg(a), 0), 0.01)
	_veins(p, Vector3.ZERO, 0.4, 6, 3, dark)


static func _o_watcher_eye(p: Node3D) -> void:
	_ball(p, 0.36, Vector3.ZERO, _om("panel", PALE), Vector3.ONE, 0.05)
	_rod(p, 0.19, 0.19, 0.05, Vector3(0, 0, -0.34), _om("panel", Color(1.1, 0.95, 0.25), Color(0.25, 0.2, 0.0)), 12)
	_rod(p, 0.085, 0.085, 0.06, Vector3(0, 0, -0.355), _om("panel", BLACK), 10)
	_ball(p, 0.03, Vector3(0.05, 0.05, -0.39), _om("panel", BONE, Color(0.6, 0.6, 0.6)))
	_veins(p, Vector3.ZERO, 0.36, 9, 11, _om("panel", RED))
	var nerve := _om("concrete", MEAT)
	_taper(p, [Vector3(0, -0.02, 0.3), Vector3(0.06, -0.1, 0.5), Vector3(0.02, -0.22, 0.66), Vector3(-0.06, -0.26, 0.8)], 0.14, 0.08, nerve, 6)
	_ball(p, 0.09, Vector3(-0.06, -0.26, 0.82), _om("concrete", GORE), Vector3(1, 1, 0.6), 0.3)


static func _o_centipede_segment(p: Node3D) -> void:
	var shell := _om("rust_metal", CHITIN)
	_rod(p, 0.3, 0.3, 0.6, Vector3.ZERO, shell, 8)
	for z: float in [-0.24, 0.0, 0.24]:
		_rod(p, 0.34, 0.33, 0.1, Vector3(0, 0.02, z), _om("rust_metal", Color(0.55, 0.45, 0.38)), 8)
	_rod(p, 0.27, 0.27, 0.03, Vector3(0, 0, -0.31), _om("concrete", MEAT), 8)
	_rod(p, 0.27, 0.27, 0.03, Vector3(0, 0, 0.31), _om("concrete", GORE), 8)
	_ball(p, 0.1, Vector3(0.05, 0.02, -0.32), _om("panel", BONE), Vector3(1, 1, 0.5))
	var leg := _om("panel", Color(0.3, 0.24, 0.22))
	for sx: float in [-1.0, 1.0]:
		for z: float in [-0.2, 0.0, 0.2]:
			_taper(p, [Vector3(sx * 0.26, -0.12, z), Vector3(sx * 0.48, -0.16, z - 0.03), Vector3(sx * 0.56, -0.38, z - 0.06)], 0.045, 0.015, leg, 4)
	for i in 4:
		_box(p, Vector3(0.05, 0.04, 0.05), Vector3(0.1 - i * 0.07, 0.32, -0.1 + i * 0.07), _om("panel", YELLOW, Color(0.3, 0.25, 0.0)), Vector3.ZERO, 0.01)


static func _o_mother_musicbox(p: Node3D) -> void:
	var wood := _om("wood", WOOD)
	_box(p, Vector3(0.7, 0.32, 0.5), Vector3(0, -0.06, 0), wood, Vector3.ZERO, 0.03)
	_box(p, Vector3(0.74, 0.04, 0.54), Vector3(0, -0.22, 0), _om("wood", Color(0.8, 0.55, 0.4)), Vector3.ZERO, 0.01)
	_box(p, Vector3(0.7, 0.05, 0.5), Vector3(0, 0.34, 0.19), wood, Vector3(70, 0, 0), 0.02)
	_box(p, Vector3(0.6, 0.02, 0.4), Vector3(0, 0.33, 0.17), _om("panel", Color(1.3, 0.6, 0.8)), Vector3(70, 0, 0), 0.0)
	_ball(p, 0.2, Vector3(0, 0.14, -0.02), _om("concrete", FLESH), Vector3(1.3, 0.8, 1.0), 0.25)
	_ball(p, 0.12, Vector3(0.12, 0.2, 0.04), _om("concrete", MEAT), Vector3.ONE, 0.25)
	for i in 6:
		_box(p, Vector3(0.025, 0.06, 0.02), Vector3(-0.18 + i * 0.03, 0.12, -0.18), _om("panel", BONE), Vector3.ZERO, 0.0)
	var brass := _om("brass", Color(1.3, 1.1, 0.6))
	_rod(p, 0.02, 0.02, 0.12, Vector3(0.41, -0.04, 0), brass, 6, Vector3(0, 0, 90))
	for sz: float in [-1.0, 1.0]:
		_tube(p, _ring(Vector3.ZERO, 0.05, 8).map(func(v: Vector3) -> Vector3: return Vector3(0.48, -0.04 + v.y, sz * 0.05 + v.x)), 0.015, brass, 4)
	_box(p, Vector3(0.08, 0.2, 0.01), Vector3(-0.15, -0.1, -0.255), _om("panel", GORE), Vector3(0, 0, 8), 0.0)
	_box(p, Vector3(0.04, 0.12, 0.01), Vector3(0.1, -0.12, -0.255), _om("panel", GORE), Vector3(0, 0, -5), 0.0)


static func _o_burrower_drill(p: Node3D) -> void:
	_ball(p, 0.26, Vector3(0, 0, 0.3), _om("concrete", FLESH), Vector3(1.1, 0.9, 1.0), 0.2)
	_ball(p, 0.16, Vector3(0, -0.04, 0.5), _om("concrete", GORE), Vector3(1, 1, 0.5), 0.3)
	var plate := _om("rust_metal", Color(0.5, 0.48, 0.5))
	for i in 3:
		_box(p, Vector3(0.5 - i * 0.06, 0.06, 0.2), Vector3(0, 0.2 - i * 0.02, 0.42 - i * 0.14), plate, Vector3(-18, 0, 0), 0.02)
	var claw := _om("rust_metal", Color(0.75, 0.72, 0.7))
	for sx: float in [-1.0, 0.0, 1.0]:
		_taper(p, [Vector3(sx * 0.14, 0.0, 0.2), Vector3(sx * 0.17, -0.02, -0.1), Vector3(sx * 0.15, -0.1, -0.38), Vector3(sx * 0.1, -0.24, -0.52)],
				0.08, 0.005, claw, 5)
	_bone_bits(p, Vector3(0, -0.12, 0.3), 3, 7)


static func _o_knight_door(p: Node3D) -> void:
	var iron := _om("rust_metal", RUST)
	_box(p, Vector3(0.68, 1.0, 0.07), Vector3.ZERO, iron, Vector3.ZERO, 0.02)
	for y: float in [-0.25, 0.25]:
		_box(p, Vector3(0.52, 0.38, 0.02), Vector3(0, y, -0.04), _om("rust_metal", Color(0.9, 0.75, 0.65)), Vector3.ZERO, 0.01)
	_rod(p, 0.03, 0.03, 0.12, Vector3(0.24, 0.0, -0.08), _om("panel", DARK), 6, Vector3(0, 0, 90))
	for i in 5:
		_ball(p, 0.04, Vector3(-0.2 + i * 0.1, 0.3 - (i % 2) * 0.45, -0.05), _om("panel", BLACK), Vector3(1, 1, 0.3))
	_box(p, Vector3(0.14, 0.16, 0.01), Vector3(-0.12, 0.05, -0.052), _om("panel", GORE), Vector3(0, 0, 15), 0.0)
	for i in 4:
		_box(p, Vector3(0.025, 0.08, 0.01), Vector3(-0.17 + i * 0.03, 0.15, -0.052), _om("panel", GORE), Vector3(0, 0, 10 - i * 6), 0.0)
	var strap := _om("panel", Color(0.45, 0.3, 0.2))
	for y: float in [-0.2, 0.2]:
		_box(p, Vector3(0.6, 0.06, 0.03), Vector3(0, y, 0.05), strap, Vector3.ZERO, 0.005)
	_taper(p, [Vector3(0, -0.15, 0.08), Vector3(0.0, 0.05, 0.16), Vector3(0.05, 0.25, 0.14)], 0.09, 0.07, _om("concrete", FLESH), 6)
	_ball(p, 0.1, Vector3(0.05, 0.27, 0.14), _om("concrete", GORE), Vector3(1, 0.7, 1), 0.3)
	_rod(p, 0.025, 0.025, 0.06, Vector3(0.05, 0.33, 0.14), _om("panel", BONE), 6, Vector3.ZERO)


static func _o_mannequin_arm(p: Node3D) -> void:
	var plastic := _om("panel", Color(1.25, 1.12, 1.0))
	_taper(p, [Vector3(0, 0, 0.45), Vector3(0, 0, 0.06)], 0.075, 0.065, plastic, 7)
	_ball(p, 0.08, Vector3(0, 0, 0.0), _om("panel", Color(0.9, 0.85, 0.8)))
	_taper(p, [Vector3(0, 0, -0.05), Vector3(0, -0.03, -0.36)], 0.06, 0.045, plastic, 7)
	_ball(p, 0.05, Vector3(0, -0.035, -0.39), _om("panel", Color(0.9, 0.85, 0.8)))
	_box(p, Vector3(0.13, 0.04, 0.13), Vector3(0, -0.04, -0.48), plastic, Vector3(0, 0, 0), 0.015)
	for i in 4:
		_taper(p, [Vector3(-0.045 + i * 0.03, -0.04, -0.54), Vector3(-0.05 + i * 0.033, -0.05, -0.62), Vector3(-0.05 + i * 0.034, -0.09, -0.66)], 0.014, 0.01, plastic, 4)
	_taper(p, [Vector3(0.07, -0.04, -0.47), Vector3(0.11, -0.05, -0.53)], 0.016, 0.012, plastic, 4)
	_ball(p, 0.085, Vector3(0, 0, 0.48), _om("concrete", GORE), Vector3(1, 1, 0.5), 0.35)
	_taper(p, [Vector3(0.02, 0.02, 0.5), Vector3(0.06, 0.05, 0.6), Vector3(0.1, -0.02, 0.66)], 0.012, 0.008, _om("panel", RED), 4)
	_taper(p, [Vector3(-0.03, 0.0, 0.5), Vector3(-0.07, -0.04, 0.58), Vector3(-0.05, -0.1, 0.64)], 0.01, 0.008, _om("panel", YELLOW), 4)
	_box(p, Vector3(0.02, 0.16, 0.002), Vector3(0.0, 0.0, 0.3), _om("panel", BLACK), Vector3(0, 90, 0), 0.0)


static func _o_mimic_shell(p: Node3D) -> void:
	_ball(p, 0.4, Vector3.ZERO, _om("panel", Color(0.36, 0.26, 0.4)), Vector3(0.85, 0.42, 1.1), 0.1)
	for i in 5:
		_box(p, Vector3(0.62 - absf(i - 2) * 0.08, 0.02, 0.025), Vector3(0, 0.16 - absf(i - 2) * 0.025, -0.3 + i * 0.15), _om("panel", Color(0.2, 0.15, 0.22)), Vector3.ZERO, 0.0)
	_ball(p, 0.07, Vector3(0.05, 0.17, 0.0), _om("panel", TEAL, Color(0.1, 0.5, 0.45)), Vector3(1, 0.7, 1.2))
	_ball(p, 0.04, Vector3(-0.12, 0.15, 0.15), _om("brass", Color(1.3, 1.1, 0.4)), Vector3(1, 0.6, 1))
	var leg := _om("panel", Color(0.25, 0.18, 0.2))
	for sx: float in [-1.0, 1.0]:
		for z: float in [-0.2, 0.0, 0.2]:
			_taper(p, [Vector3(sx * 0.25, -0.08, z), Vector3(sx * 0.38, -0.12, z + 0.04), Vector3(sx * 0.3, -0.18, z + 0.1)], 0.03, 0.01, leg, 4)
	_ball(p, 0.1, Vector3(0, -0.05, -0.42), _om("concrete", GORE), Vector3(1.2, 0.5, 0.5))
	for i in 5:
		_rod(p, 0.0, 0.012, 0.04, Vector3(-0.06 + i * 0.03, -0.03, -0.46), _om("panel", BONE), 4, Vector3(180, 0, 0))


static func _o_greeter_smile(p: Node3D) -> void:
	_ball(p, 0.42, Vector3.ZERO, _om("panel", PALE), Vector3(1.1, 0.9, 0.35), 0.04)
	_ball(p, 0.3, Vector3(0, -0.1, -0.08), _om("panel", GORE), Vector3(1.05, 0.38, 0.3))
	for i in 9:
		var x := -0.24 + i * 0.06
		var lift := absf(x) * 0.25
		_box(p, Vector3(0.05, 0.06, 0.03), Vector3(x, -0.03 + lift, -0.15 + absf(x) * 0.1), _om("panel", BONE), Vector3.ZERO, 0.008)
		_box(p, Vector3(0.05, 0.05, 0.03), Vector3(x, -0.17 + lift * 0.6, -0.15 + absf(x) * 0.1), _om("panel", BONE), Vector3.ZERO, 0.008)
	for sx: float in [-1.0, 1.0]:
		_box(p, Vector3(0.14, 0.022, 0.02), Vector3(sx * 0.17, 0.17, -0.13), _om("panel", BLACK), Vector3(0, 0, sx * -18.0), 0.0)
		_ball(p, 0.07, Vector3(sx * 0.27, 0.02, -0.11), _om("panel", Color(1.4, 0.6, 0.65)), Vector3(1, 0.7, 0.3))
	for i in 7:
		var a := PI * 0.2 + i * PI * 0.1
		_ball(p, 0.06, Vector3(cos(a) * 0.4, -sin(a) * 0.3, 0.08), _om("concrete", GORE), Vector3(1, 1, 0.6), 0.3)


static func _o_collector_sack(p: Node3D) -> void:
	_ball(p, 0.36, Vector3(0, -0.04, 0), _om("wood", Color(0.95, 0.8, 0.55)), Vector3(1.0, 1.05, 0.95), 0.22)
	_rod(p, 0.09, 0.12, 0.08, Vector3(0, 0.33, 0), _om("wood", Color(0.8, 0.65, 0.45)), 7, Vector3.ZERO)
	_rod(p, 0.1, 0.1, 0.03, Vector3(0, 0.3, 0), _om("panel", Color(0.45, 0.3, 0.2)), 7, Vector3.ZERO)
	_taper(p, [Vector3(0.05, 0.36, 0.02), Vector3(0.1, 0.5, -0.02)], 0.03, 0.02, _om("panel", BONE), 5)
	_ball(p, 0.04, Vector3(0.1, 0.52, -0.02), _om("panel", BONE))
	_taper(p, [Vector3(-0.2, 0.15, -0.2), Vector3(-0.32, 0.28, -0.3)], 0.025, 0.02, _om("panel", BONE), 5)
	_disc_x(p, 0.13, 0.05, Vector3(0.36, -0.22, 0.05), _om("panel", DARK), 10)
	_disc_x(p, 0.06, 0.07, Vector3(0.36, -0.22, 0.05), _om("rust_metal", RUST), 6)
	_ball(p, 0.3, Vector3(-0.05, -0.33, -0.05), _om("concrete", GORE), Vector3(1.0, 0.2, 0.9), 0.3)
	_box(p, Vector3(0.12, 0.1, 0.01), Vector3(-0.1, 0.0, -0.34), _om("panel", Color(0.9, 0.9, 0.85)), Vector3(0, 0, 12), 0.0)


static func _o_rat_spring(p: Node3D) -> void:
	_ball(p, 0.2, Vector3(0, 0, 0), _om("concrete", MEAT), Vector3(1, 1.2, 0.9), 0.2)
	_veins(p, Vector3.ZERO, 0.2, 5, 5, _om("concrete", GORE))
	var brass := _om("brass", Color(1.3, 1.1, 0.6))
	var points := []
	for i in 36:
		var a := TAU * i / 9.0
		points.append(Vector3(cos(a) * 0.26, -0.18 + i * 0.01, sin(a) * 0.26))
	_tube(p, points, 0.018, _om("panel", STEEL), 4)
	_rod(p, 0.025, 0.025, 0.25, Vector3(0, 0, 0.3), brass, 6)
	for sx: float in [-1.0, 1.0]:
		_tube(p, _ring(Vector3.ZERO, 0.07, 8).map(func(v: Vector3) -> Vector3: return Vector3(sx * 0.07 + v.x, v.y, 0.47)), 0.02, brass, 4)
	_disc_x(p, 0.1, 0.03, Vector3(0.22, 0.05, 0.0), brass, 10)
	_taper(p, [Vector3(0, -0.1, -0.15), Vector3(0.05, -0.15, -0.3), Vector3(-0.03, -0.18, -0.45), Vector3(0.04, -0.17, -0.58)], 0.02, 0.006, _om("panel", Color(1.3, 0.75, 0.75)), 4)


static func _o_fog_lung(p: Node3D) -> void:
	var lung := _om("concrete", Color(0.8, 0.86, 1.0), Color(0.08, 0.12, 0.18))
	for sx: float in [-1.0, 1.0]:
		_ball(p, 0.24, Vector3(sx * 0.22, -0.05, 0), lung, Vector3(0.8, 1.25, 0.7), 0.15)
		_taper(p, [Vector3(0, 0.2, 0), Vector3(sx * 0.12, 0.16, 0), Vector3(sx * 0.2, 0.08, 0)], 0.04, 0.03, _om("panel", SINEW), 5)
	_taper(p, [Vector3(0, 0.2, 0), Vector3(0, 0.42, 0.02)], 0.05, 0.05, _om("panel", SINEW), 7)
	for i in 4:
		_rod(p, 0.058, 0.058, 0.02, Vector3(0, 0.24 + i * 0.05, 0.01), _om("panel", Color(1.3, 1.25, 1.1)), 7, Vector3.ZERO)
	_ball(p, 0.06, Vector3(0, 0.44, 0.02), _om("concrete", GORE), Vector3(1, 0.5, 1))
	_veins(p, Vector3(0.22, -0.05, 0), 0.22, 3, 2, _om("panel", Color(0.5, 0.55, 0.85)))
	_veins(p, Vector3(-0.22, -0.05, 0), 0.22, 3, 4, _om("panel", Color(0.5, 0.55, 0.85)))


static func _o_tuner_cords(p: Node3D) -> void:
	var bone := _om("panel", BONE)
	_taper(p, [Vector3(0, -0.5, 0), Vector3(0, -0.15, 0)], 0.04, 0.035, bone, 6)
	_tube(p, [Vector3(-0.12, 0.45, 0), Vector3(-0.12, 0.0, 0), Vector3(-0.08, -0.12, 0), Vector3(0, -0.15, 0),
			Vector3(0.08, -0.12, 0), Vector3(0.12, 0.0, 0), Vector3(0.12, 0.45, 0)], 0.035, bone, 6)
	for i in 3:
		var y := 0.05 + i * 0.14
		_taper(p, [Vector3(-0.1, y, 0), Vector3(0, y - 0.03, -0.01), Vector3(0.1, y + 0.02, 0)], 0.016, 0.012, _om("concrete", MEAT, GORE * 0.3), 4)
	_ball(p, 0.08, Vector3(0, -0.16, 0), _om("concrete", MEAT), Vector3(1.4, 0.8, 1.0), 0.3)
	_ball(p, 0.05, Vector3(0, -0.52, 0), _om("concrete", GORE), Vector3(1, 0.6, 1), 0.3)


static func _o_child_marble(p: Node3D) -> void:
	_ball(p, 0.25, Vector3(0, 0.02, 0), _om("panel", Color(0.5, 1.1, 1.0), Color(0.05, 0.3, 0.3)), Vector3.ONE, 0.0)
	_rod(p, 0.11, 0.11, 0.04, Vector3(0, 0.04, -0.23), _om("panel", Color(1.2, 0.85, 0.3)), 10)
	_rod(p, 0.05, 0.05, 0.05, Vector3(0, 0.04, -0.245), _om("panel", BLACK), 8)
	_ball(p, 0.11, Vector3(0.3, -0.12, 0.1), _om("panel", Color(1.3, 0.3, 0.3), Color(0.2, 0.0, 0.0)))
	_ball(p, 0.09, Vector3(-0.28, -0.14, 0.05), _om("panel", Color(1.3, 1.2, 0.3), Color(0.2, 0.15, 0.0)))
	_ball(p, 0.08, Vector3(-0.05, -0.16, 0.3), _om("panel", Color(0.6, 0.5, 1.3), Color(0.05, 0.0, 0.2)))
	_taper(p, [Vector3(0.3, -0.12, 0.1), Vector3(0.1, -0.2, 0.25), Vector3(-0.15, -0.2, 0.2), Vector3(-0.28, -0.14, 0.05)], 0.012, 0.012, _om("panel", RED), 4)
	_ball(p, 0.12, Vector3(0.05, -0.22, -0.05), _om("concrete", GORE), Vector3(1.6, 0.2, 1.3), 0.3)


static func _o_spitter_sac(p: Node3D) -> void:
	_ball(p, 0.36, Vector3.ZERO, _om("concrete", BILE, Color(0.2, 0.55, 0.05)), Vector3(1.0, 0.9, 1.0), 0.15)
	_veins(p, Vector3.ZERO, 0.36, 8, 9, _om("concrete", Color(0.3, 0.35, 0.1)))
	var throat := _om("concrete", FLESH)
	_taper(p, [Vector3(0, 0.28, 0.05), Vector3(0.03, 0.42, 0.1), Vector3(0.0, 0.5, 0.18)], 0.12, 0.09, throat, 6)
	_taper(p, [Vector3(0, -0.28, -0.05), Vector3(-0.03, -0.42, -0.08)], 0.1, 0.08, throat, 6)
	_ball(p, 0.08, Vector3(0, 0.52, 0.2), _om("concrete", GORE), Vector3(1, 0.6, 1), 0.3)
	_ball(p, 0.07, Vector3(-0.03, -0.44, -0.08), _om("concrete", GORE), Vector3(1, 0.6, 1), 0.3)
	_ball(p, 0.07, Vector3(0.2, 0.1, -0.3), _om("panel", BILE, Color(0.4, 0.9, 0.1)), Vector3(1, 1, 0.5))


static func _o_splitter_core(p: Node3D) -> void:
	var meat := _om("concrete", MEAT)
	var flesh := _om("concrete", FLESH)
	_ball(p, 0.26, Vector3(-0.2, 0, 0.1), meat, Vector3.ONE, 0.22)
	_ball(p, 0.24, Vector3(0.2, 0.02, 0.12), flesh, Vector3.ONE, 0.22)
	_ball(p, 0.22, Vector3(0, 0.05, -0.2), meat, Vector3.ONE, 0.25)
	_ball(p, 0.18, Vector3(0, 0.25, 0.0), flesh, Vector3.ONE, 0.25)
	_veins(p, Vector3(0, 0.05, 0), 0.32, 7, 13, _om("concrete", GORE))
	_bone_bits(p, Vector3(0, 0.0, 0.0), 6, 21)
	_ball(p, 0.06, Vector3(0.08, 0.12, -0.4), _om("panel", BLACK, Color(0.2, 0.0, 0.0)))


static func _o_dropper_arm(p: Node3D) -> void:
	var skin := _om("concrete", Color(0.62, 0.6, 0.62))
	_taper(p, [Vector3(0, 0, 0.5), Vector3(0, 0.02, 0.1), Vector3(0, -0.02, -0.1)], 0.05, 0.04, skin, 6)
	_ball(p, 0.05, Vector3(0, -0.02, -0.12), skin)
	_taper(p, [Vector3(0, -0.02, -0.12), Vector3(0, -0.04, -0.38)], 0.04, 0.035, skin, 6)
	_box(p, Vector3(0.1, 0.03, 0.1), Vector3(0, -0.04, -0.43), skin, Vector3.ZERO, 0.012)
	for i in 3:
		var x := -0.035 + i * 0.035
		_taper(p, [Vector3(x, -0.04, -0.48), Vector3(x * 1.3, -0.03, -0.6), Vector3(x * 1.4, -0.08, -0.7), Vector3(x * 1.3, -0.16, -0.7)],
				0.016, 0.004, skin, 4)
		_rod(p, 0.0, 0.008, 0.03, Vector3(x * 1.3, -0.17, -0.69), _om("panel", BLACK), 4, Vector3(180, 0, 0))
	_ball(p, 0.07, Vector3(0, 0, 0.52), _om("concrete", GORE), Vector3(1, 1, 0.5), 0.35)
	_rod(p, 0.02, 0.02, 0.06, Vector3(0, 0, 0.56), _om("panel", BONE), 5)


static func _o_screamer_mask(p: Node3D) -> void:
	var porcelain := _om("panel", Color(1.35, 1.32, 1.28))
	_ball(p, 0.34, Vector3(0, 0.05, 0), porcelain, Vector3(0.82, 1.12, 0.3), 0.02)
	var black := _om("panel", BLACK)
	for sx: float in [-1.0, 1.0]:
		_ball(p, 0.06, Vector3(sx * 0.11, 0.15, -0.08), black, Vector3(1.0, 0.75, 0.4))
		_box(p, Vector3(0.018, 0.16, 0.01), Vector3(sx * 0.11, 0.04, -0.1), _om("panel", GORE), Vector3(0, 0, sx * 4.0), 0.0)
	_ball(p, 0.09, Vector3(0, -0.13, -0.08), black, Vector3(0.75, 1.0, 0.4))
	_box(p, Vector3(0.012, 0.22, 0.01), Vector3(0.08, 0.26, -0.085), black, Vector3(0, 0, -25), 0.0)
	_box(p, Vector3(0.01, 0.12, 0.01), Vector3(0.14, 0.33, -0.08), black, Vector3(0, 0, 30), 0.0)
	var rag := _om("carpet", Color(0.55, 0.5, 0.45))
	for i in 5:
		_box(p, Vector3(0.09, 0.28 + (i % 3) * 0.06, 0.012), Vector3(-0.2 + i * 0.1, -0.42, 0.04), rag, Vector3(0, 0, -10 + i * 5), 0.0)


static func _o_hound_fang(p: Node3D) -> void:
	var bone := _om("panel", BONE)
	var u := [Vector3(-0.32, 0, 0.32), Vector3(-0.3, 0, 0.0), Vector3(-0.2, 0, -0.25), Vector3(0, 0, -0.33),
		Vector3(0.2, 0, -0.25), Vector3(0.3, 0, 0.0), Vector3(0.32, 0, 0.32)]
	_tube(p, u, 0.06, bone, 6)
	_tube(p, u.map(func(v: Vector3) -> Vector3: return v * 0.97 + Vector3(0, 0.05, 0)), 0.04, _om("concrete", MEAT), 5)
	for i in range(1, u.size() - 1):
		for t: float in [0.0, 0.5]:
			var at: Vector3 = (u[i] as Vector3).lerp(u[i + 1], t) if i + 1 < u.size() else u[i]
			var tall := 0.13 if i == 2 or i == 4 else 0.07
			_rod(p, 0.0, 0.025, tall, at + Vector3(0, 0.06 + tall * 0.5, 0), bone, 4, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		_ball(p, 0.1, Vector3(sx * 0.32, 0.02, 0.36), _om("concrete", GORE), Vector3(1, 1, 0.8), 0.35)
		_ball(p, 0.07, Vector3(sx * 0.3, 0.07, 0.3), _om("concrete", MEAT), Vector3.ONE, 0.3)


static func _o_weaver_gland(p: Node3D) -> void:
	_ball(p, 0.3, Vector3(0, 0, 0.1), _om("panel", Color(1.15, 1.08, 0.95), Color(0.08, 0.08, 0.06)), Vector3(0.9, 0.85, 1.2), 0.12)
	for i in 6:
		var a := TAU * i / 6.0
		_box(p, Vector3(0.02, 0.08, 0.02), Vector3(cos(a) * 0.25, sin(a) * 0.22 + 0.02, 0.15), _om("panel", Color(0.3, 0.22, 0.18)), Vector3(0, 0, rad_to_deg(a)), 0.0)
	var silk := _om("panel", Color(1.4, 1.4, 1.35), Color(0.25, 0.25, 0.25))
	for i in 3:
		var x := -0.06 + i * 0.06
		_rod(p, 0.035, 0.05, 0.08, Vector3(x, -0.04, -0.27), _om("concrete", FLESH), 5)
		_taper(p, [Vector3(x, -0.04, -0.31), Vector3(x * 2.0, -0.08, -0.45), Vector3(x * 3.0, -0.2, -0.55), Vector3(x * 3.5, -0.32, -0.58)], 0.008, 0.005, silk, 3)
	_taper(p, [Vector3(0.1, 0.1, 0.3), Vector3(0.3, 0.2, 0.45), Vector3(0.5, 0.05, 0.5)], 0.006, 0.004, silk, 3)
	_ball(p, 0.08, Vector3(0, 0, 0.44), _om("concrete", GORE), Vector3(1, 1, 0.5), 0.35)


static func _o_stalker_shadow(p: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for layer in 3:
		var outline := PackedVector2Array()
		var spikes := 11
		for i in spikes * 2:
			var a := TAU * i / (spikes * 2)
			var r := (0.48 if i % 2 == 0 else 0.22) * rng.randf_range(0.7, 1.1) * (1.0 - layer * 0.2)
			outline.append(Vector2(cos(a) * r * 0.8, sin(a) * r * 1.2))
		var tint := Color(0.08, 0.06, 0.12) if layer != 1 else Color(0.18, 0.08, 0.3)
		var glow := Color(0.0, 0.0, 0.0) if layer != 1 else Color(0.1, 0.0, 0.18)
		_put(p, LowPoly.extrude(outline, 0.03), Vector3(0, layer * 0.04, 0), _om("panel", tint, glow), Vector3(90, layer * 23.0, 0))
	for sx: float in [-1.0, 1.0]:
		_ball(p, 0.035, Vector3(sx * 0.06, 0.13, -0.18), _om("panel", BONE, Color(0.8, 0.8, 0.8)))
	_taper(p, [Vector3(0, 0.05, 0.2), Vector3(0.1, 0.15, 0.35), Vector3(-0.05, 0.25, 0.45)], 0.05, 0.005, _om("panel", Color(0.1, 0.06, 0.14)), 4)


static func _o_eye_lens(p: Node3D) -> void:
	_ball(p, 0.18, Vector3.ZERO, _om("panel", PALE), Vector3.ONE, 0.04)
	_rod(p, 0.1, 0.1, 0.03, Vector3(0, 0, -0.17), _om("panel", Color(1.2, 0.2, 0.15), Color(0.3, 0.0, 0.0)), 10)
	_rod(p, 0.045, 0.045, 0.04, Vector3(0, 0, -0.18), _om("panel", BLACK), 8)
	_veins(p, Vector3.ZERO, 0.18, 6, 31, _om("panel", RED))
	var wing := _om("panel", Color(0.35, 0.2, 0.32))
	for sx: float in [-1.0, 1.0]:
		var outline := PackedVector2Array([Vector2(0, 0.05), Vector2(sx * 0.2, 0.18), Vector2(sx * 0.45, 0.12), Vector2(sx * 0.5, -0.05),
			Vector2(sx * 0.4, 0.0), Vector2(sx * 0.32, -0.08), Vector2(sx * 0.22, -0.02), Vector2(sx * 0.12, -0.07), Vector2(0, -0.03)])
		_put(p, LowPoly.extrude(outline, 0.012), Vector3(sx * 0.12, 0.02, 0.05), wing, Vector3(0, sx * 20.0, 0))
		_taper(p, [Vector3(sx * 0.12, 0.07, 0.05), Vector3(sx * 0.32, 0.2, 0.0), Vector3(sx * 0.58, 0.14, -0.05)], 0.012, 0.006, _om("panel", BONE), 4)
	_ball(p, 0.05, Vector3(0, -0.02, 0.17), _om("concrete", GORE), Vector3(1, 1, 0.6), 0.3)


## A few broken bone splinters poking out around c.
static func _bone_bits(p: Node3D, c: Vector3, count: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		_taper(p, [c + dir * 0.18, c + dir * 0.34], 0.025, 0.008, _om("panel", BONE), 4)
