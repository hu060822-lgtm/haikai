class_name GunModels
## Low-poly PS1 models of Arsenal builds: every frame is its own cobbled-together
## scavenger contraption, and every part bolts on where it belongs on the slot tree:
## a quick-detach can over the flash hider, a handguard that brings its own rails, lights
## and lasers on the side rails, a grip or bipod under the handguard, an offset dot at 45°,
## the sight on top, the magazine in its well, the stock and its butt pad at the back. Ammo
## tints the rounds you can see, internal parts (triggers, bolts, gas) show as small cues,
## gadgets dangle as charms, and organs are grown on.
##
##   var model := GunModels.build(build)   # Node3D, points -Z, grip at the origin
##   model.get_node("Muzzle")             # Marker3D at the end of the barrel (moves with the gun)
##   GunModels.muzzle_point(build)        # the same point as a Vector3 in model space
##   model.get_meta("slots")              # {slot: Vector3} where each slot's part sits (every Arsenal slot)
##
## Sizes are real-ish metres (roughly the frame's "length" stat): pistols ~0.2-0.3 m, long
## guns 0.7-1.1 m, the anti-materiel rifle ~1.4 m. Textures are projected in each mesh's own
## space (not world space), so they don't swim on a held gun. A part id with no model of
## its own gets a small taped-on lump at its slot, so nothing a save names can crash this.

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
const POLY := Color(0.24, 0.25, 0.27)
const TAN := Color(1.0, 0.8, 0.55)
const OD := Color(0.46, 0.53, 0.33)
const PLUM := Color(0.62, 0.3, 0.3)
const BAKELITE := Color(1.05, 0.45, 0.22)
const NICKEL := Color(1.4, 1.42, 1.5)
const SMOKE := Color(0.36, 0.38, 0.35)
const BLUE := Color(0.3, 0.45, 1.1)
const GLASS := Color(0.2, 0.3, 0.4)

## Colour of the rounds each ammo part shows, and whether they glow.
const AMMO_LOOK := {
	"fmj": [Color(1.3, 0.75, 0.45), Color.BLACK],
	"hollow_point": [Color(1.2, 0.62, 0.38), Color.BLACK],
	"ap_rounds": [Color(0.25, 0.32, 0.22), Color(0.1, 0.35, 0.05)],
	"subsonic": [Color(0.35, 0.3, 0.55), Color(0.04, 0.02, 0.1)],
	"plus_p": [Color(1.25, 0.4, 0.3), Color(0.25, 0.04, 0.0)],
	"tracer": [Color(1.3, 0.35, 0.2), Color(1.0, 0.25, 0.05)],
	"match_ammo": [Color(1.45, 1.35, 0.9), Color(0.08, 0.07, 0.0)],
	"incendiary": [Color(1.2, 0.3, 0.1), Color(0.75, 0.22, 0.0)],
	"api_rounds": [Color(0.9, 0.95, 1.05), Color(0.5, 0.08, 0.0)],
	"shock_rounds": [Color(0.4, 0.9, 1.1), Color(0.1, 0.45, 0.7)],
	"handload": [Color(0.85, 0.7, 0.45), Color.BLACK],
	"buckshot_mag": [Color(0.35, 0.9, 0.35), Color(0.0, 0.12, 0.0)],
	"slug": [Color(0.6, 0.62, 0.66), Color.BLACK],
	"birdshot": [Color(1.4, 1.25, 0.25), Color(0.1, 0.08, 0.0)],
	"flechette": [Color(1.2, 1.25, 1.35), Color(0.1, 0.12, 0.16)],
	"dragon_breath": [Color(1.4, 0.55, 0.1), Color(1.0, 0.35, 0.0)],
	"rock_salt": [Color(1.4, 1.4, 1.35), Color(0.12, 0.12, 0.12)],
	"beanbag": [Color(1.1, 0.95, 0.65), Color.BLACK],
	"explosive_bolt": [Color(1.3, 0.15, 0.1), Color(0.5, 0.05, 0.0)],
	"net_bolt": [Color(0.5, 1.2, 0.35), Color(0.05, 0.2, 0.0)],
	"broadhead": [Color(1.3, 1.3, 1.35), Color(0.3, 0.0, 0.0)],
	"rusty_nails": [Color(1.0, 0.5, 0.3), Color.BLACK],
}

## Vertex snapping grid height of new materials (the PS1 wobble). Tools raise it for crisp shots.
static var snap := 180.0
static var _shader: Shader
static var _mats := {}


## A finished model of `build` (any Arsenal build; it is cleaned first).
static func build(build: Dictionary) -> Node3D:
	return _assemble(Arsenal.clean(build))


## Builds the model of an already-cleaned build. Ids it has no model for (and frames it
## doesn't know) still give a gun: tests feed it raw builds to prove that.
static func _assemble(build: Dictionary) -> Node3D:
	var r := Rig.new()
	r.root = Node3D.new()
	r.root.name = "Gun_" + str(build.get("frame", ""))
	r.frame = str(build.get("frame", "revolver"))
	r.parts = build.get("parts", {})
	r.tune = build.get("tune", {})
	match r.frame:
		"revolver": _revolver(r)
		"service_pistol": _service_pistol(r)
		"heavy_pistol": _heavy_pistol(r)
		"machine_pistol": _machine_pistol(r)
		"smg": _smg(r)
		"pdw": _pdw(r)
		"carbine": _carbine(r)
		"ak": _ak(r)
		"bullpup": _bullpup(r)
		"battle_rifle": _battle_rifle(r)
		"dmr": _dmr(r)
		"rifle": _rifle(r)
		"lever_action": _lever_action(r)
		"lmg": _lmg(r)
		"anti_materiel": _anti_materiel(r)
		"shotgun": _shotgun(r)
		"double_barrel": _double_barrel(r)
		"auto_shotgun": _auto_shotgun(r)
		"sawed_off": _sawed_off(r)
		"nail_gun": _nail_gun(r)
		"crossbow": _crossbow(r)
		"flamethrower": _flamethrower(r)
		"tesla": _tesla(r)
		"harpoon": _harpoon(r)
		"railgun": _railgun(r)
		"duck_launcher": _duck_launcher(r)
		"saw_launcher": _saw_launcher(r)
		"bubble_gun": _bubble_gun(r)
		_: _revolver(r)
	_settle_anchors(r)
	var bare_muzzle := r.muzzle
	r.barrel_end = r.muzzle
	_attach_parts(r)
	r.root.set_meta("slots", _slot_points(r, bare_muzzle))
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = r.muzzle
	r.root.add_child(marker)
	r.root.set_meta("muzzle", r.muzzle)
	r.root.set_meta("frame", r.frame)
	return r.root


## Where the shot leaves the gun (after any muzzle device, silencer or barrel), in model space.
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
## Anchors left at Vector3.INF are worked out from the others (_settle_anchors).
class Rig:
	var root: Node3D
	var frame := ""
	var parts := {}
	var tune := {}
	var done := {}                         # slots the frame already drew the part of itself
	var muzzle := Vector3(0, 0.07, -0.3)   # end of the bare barrel
	var barrel_start := Vector3(0, 0.07, -0.1)
	var barrel_r := 0.012
	var twin := 0.0                        # side-by-side barrels: x offset of each (devices doubled)
	var top := Vector3(0, 0.1, 0.0)        # top of the rail, sights sit on it
	var mag := Vector3(0, 0.04, -0.06)     # bottom of the magwell, mags hang from it
	var stock := Vector3(0, 0.07, 0.08)    # back of the receiver, stocks go +Z from it
	var under := Vector3(0, 0.04, -0.25)   # under the barrel
	var gadget := Vector3(0, 0.03, 0.05)   # charms hang from here
	var side := Vector3(0.03, 0.07, -0.05) # right side of the receiver (ammo holder)
	var mag_style := "box"                 # how magazine parts look on this frame
	var rounds: Array[MeshInstance3D] = [] # visible rounds that ammo parts recolour
	# The default magazine's shape (parts scale from it).
	var mag_len := 0.12
	var mag_w := 0.022
	var mag_d := 0.034
	var mag_tilt := 8.0
	var mag_curve := 0.0
	# Where the pistol grip is (grip parts replace the frame's own).
	var grip_top := Vector3.INF
	var grip_size := Vector3(0.032, 0.105, 0.042)
	var grip_rake := -16.0
	var trig := Vector3(0, 0.018, -0.027)  # the trigger blade
	var body_w := 0.016                    # half width of the receiver (side cues sit on it)
	# Handguard span (z of its back and front end), height and radius. 0 = from the barrel.
	var hg_start := 0.0
	var hg_end := 0.0
	var hg_y := 0.0
	var hg_r := 0.0
	var rail_l := Vector3.INF              # left / right rail (x = 0: a rail under, things hang down)
	var rail_r := Vector3.INF
	var foregrip := Vector3.INF            # under the handguard, grips hang from it
	var mount := Vector3.INF               # offset / backup sight spot on the top rail
	var gas := Vector3.INF                 # gas block on the barrel
	var recv := Vector3.INF                # middle of the receiver / upper
	var bolt := Vector3.INF                # ejection port, or the bolt handle's knob
	var charging := Vector3.INF            # charging handle
	var butt := Vector3.INF                # back face of the stock (butt pads)
	var butt_h := 0.09                     # how tall that face is
	var comb := Vector3.INF                # top of the stock where a cheek rests
	var tube_end := Vector3.INF            # front of a tube magazine (extensions)
	var tube_r := 0.011
	var device_start := Vector3.INF        # where the muzzle device starts (a can slides over it)
	var device_len := 0.0
	var has_buffer := false
	var barrel_end := Vector3.ZERO         # the bare muzzle, before devices and cans                # an AR buffer tube is already there for stocks



# --- Shape helpers ----------------------------------------------------------------

static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO,
		bevel := 0.004) -> MeshInstance3D:
	return _put(p, LowPoly.chamfer_box(size, minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.45)), pos, m, rot)


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


## A pistol grip whose top is at `top` (raked back), with a strip of tape round it. The rig
## remembers where it is; with a grip part fitted the part is drawn there instead.
static func _grip(r: Rig, top: Vector3, m: Material, size := Vector3(0.032, 0.105, 0.042), rake := -16.0) -> void:
	r.grip_top = top
	r.grip_size = size
	r.grip_rake = rake
	if r.parts.has("grip"):
		return
	_grip_shape(r, top, m, size, rake)


static func _grip_shape(r: Rig, top: Vector3, m: Material, size: Vector3, rake: float, tape := true) -> void:
	var down := _grip_down(rake)
	_box(r.root, size, top + down * size.y * 0.5, m, Vector3(rake, 0, 0), 0.008)
	if tape:
		_box(r.root, Vector3(size.x + 0.004, 0.018, size.z + 0.004), top + down * size.y * 0.62,
				mat("panel", TAPE), Vector3(rake, 0, 0), 0.002)


static func _grip_down(rake: float) -> Vector3:
	return Vector3(0, -cos(deg_to_rad(rake)), -sin(deg_to_rad(rake)))


## The bottom of the pistol grip (where a pistol's magazine comes out).
static func _grip_bottom(r: Rig) -> Vector3:
	return r.grip_top + _grip_down(r.grip_rake) * r.grip_size.y


## A trigger and a bent-wire guard in front of a grip at the origin.
static func _trigger(r: Rig, y := 0.03, z := -0.015, guard := true) -> void:
	r.trig = Vector3(0, y - 0.012, z - 0.012)
	_box(r.root, Vector3(0.006, 0.022, 0.008), r.trig, mat("panel", BLACK), Vector3(-15, 0, 0))
	if guard:
		_tube(r.root, [Vector3(0, y, z - 0.045), Vector3(0, y - 0.035, z - 0.04), Vector3(0, y - 0.04, z - 0.005),
				Vector3(0, y - 0.03, z + 0.02)], 0.003, mat("panel", DARK), 4)


## A picatinny rail: a flat bar with cross slots, `centre` on its base, along Z. `roll`
## turns it round Z (90 faces left, -90 right, 180 down).
static func _pic(r: Rig, centre: Vector3, length: float, roll := 0.0, width := 0.02, m: Material = null) -> void:
	var up := Vector3(0, 1, 0).rotated(Vector3(0, 0, 1), deg_to_rad(roll))
	var bar := m if m != null else mat("panel", BLACK)
	_box(r.root, Vector3(width, 0.007, length), centre + up * 0.0035, bar, Vector3(0, 0, roll), 0.0015)
	var count := int(length / 0.016)
	for i in count:
		var z := -length / 2.0 + (i + 0.5) * length / count
		_box(r.root, Vector3(width + 0.002, 0.004, 0.005), centre + up * 0.0062 + Vector3(0, 0, z), bar, Vector3(0, 0, roll), 0.0008)


## A box magazine (optionally curved like a banana) hanging from `top`; returns its bottom.
static func _mag_body(r: Rig, top: Vector3, length: float, w: float, d: float, tilt: float, curve: float,
		m: Material, plate := true) -> Vector3:
	var segs := 1 if absf(curve) < 1.0 else 3
	var p := top
	var seg_len := length / segs
	var a := tilt
	for i in segs:
		a = tilt + curve * (i + 0.5) / segs
		var down := Vector3(0, -cos(deg_to_rad(a)), -sin(deg_to_rad(a)))
		_box(r.root, Vector3(w, seg_len + (0.004 if segs > 1 else 0.0), d), p + down * seg_len * 0.5, m, Vector3(a, 0, 0), 0.003)
		p += down * seg_len
	if plate:
		_box(r.root, Vector3(w + 0.004, 0.01, d + 0.006), p, mat("panel", BLACK), Vector3(a, 0, 0), 0.002)
	return p


## The frame's own magazine, in its usual shape, with the top round showing.
static func _std_mag(r: Rig, m: Material, length_scale := 1.0) -> Vector3:
	_box(r.root, Vector3(r.mag_w + 0.008, 0.014, r.mag_d + 0.008), r.mag + Vector3(0, -0.004, 0), mat("panel", DARK))
	_round(r, _rod(r.root, 0.0055, 0.0055, minf(r.mag_d * 0.8, 0.06), r.mag + Vector3(0, 0.004, -0.002), mat("brass"), 5))
	return _mag_body(r, r.mag, r.mag_len * length_scale, r.mag_w, r.mag_d, r.mag_tilt, r.mag_curve, m)


## A small taped-on lump for a part with no model of its own: something shows where it went.
static func _generic(r: Rig, at: Vector3, id: String) -> void:
	var h := absi(hash(id))
	var tint := Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.85)
	_box(r.root, Vector3(0.022, 0.016, 0.03), at, mat("panel", tint), Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.026, 0.02, 0.008), at, mat("panel", TAPE), Vector3.ZERO, 0.002)


## How much the barrel part stretches or cuts this frame's barrel.
static func _barrel_scale(r: Rig) -> float:
	match r.parts.get("barrel", ""):
		"long_barrel", "nail_guide": return 1.5
		"short_barrel": return 0.6
		"bbl_338": return 1.25
	return 1.0


## A plain barrel from `start` forward; sets the rig's muzzle and barrel anchors. Every
## barrel part shows here: longer, shorter, fatter, fluted, threaded, a can built round it.
static func _barrel(r: Rig, start: Vector3, length: float, radius: float, m: Material, sight := true) -> float:
	var id: String = r.parts.get("barrel", "")
	var len := length * _barrel_scale(r)
	var rad := radius
	match id:
		"heavy_barrel": rad = radius * 1.5
		"bbl_338": rad = radius * 1.3
	_rod(r.root, rad, rad, len, start + Vector3(0, 0, -len / 2.0), m, 6)
	var end := start + Vector3(0, 0, -len)
	match id:
		"long_barrel":
			# The extension is a second pipe welded on, with a hose clamp over the joint.
			var joint := start + Vector3(0, 0, -length * 0.95)
			_rod(r.root, rad * 1.6, rad * 1.6, 0.02, joint, mat("panel", TAPE), 8)
			_rod(r.root, rad * 1.15, rad * 1.15, len - length, joint + Vector3(0, 0, -(len - length) / 2.0),
					mat("rust_metal", RUST), 6)
		"short_barrel":
			_rod(r.root, rad * 1.4, rad * 1.4, 0.012, start + Vector3(0, 0, -len + 0.006), mat("brass", COPPER), 6)
		"heavy_barrel":
			_rod(r.root, rad * 1.12, rad * 1.12, 0.012, end + Vector3(0, 0, 0.012), mat("panel", BLACK), 8)
		"fluted_barrel":
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				_box(r.root, Vector3(0.0035, 0.0035, len * 0.55), start + Vector3(cos(a) * rad, sin(a) * rad, -len * 0.5),
						mat("panel", BLACK), Vector3(0, 0, rad_to_deg(a)), 0.0)
		"match_barrel":
			_rod(r.root, rad * 1.08, rad * 1.08, len * 0.4, start + Vector3(0, 0, -len * 0.75), mat("panel", NICKEL), 8)
			_rod(r.root, rad * 1.2, rad * 1.2, 0.006, end + Vector3(0, 0, 0.003), mat("brass"), 8)
		"polygonal_barrel":
			_rod(r.root, rad * 1.1, rad * 1.1, 0.008, start + Vector3(0, 0, -len * 0.3), mat("brass", COPPER), 6)
			_rod(r.root, rad * 1.1, rad * 1.1, 0.008, start + Vector3(0, 0, -len * 0.35), mat("brass", COPPER), 6)
		"threaded_barrel":
			# Threads cut on the end: a short brass-bright stub past the old muzzle.
			_rod(r.root, rad * 0.85, rad * 0.85, 0.03, end + Vector3(0, 0, -0.015), mat("brass", Color(1.1, 1.0, 0.8)), 8)
			for i in 4:
				_rod(r.root, rad * 0.95, rad * 0.95, 0.002, end + Vector3(0, 0, -0.005 - i * 0.007), mat("panel", DARK), 8)
			end += Vector3(0, 0, -0.03)
		"integral_suppressor":
			# A fat can welded round the front half of the barrel, a strip of tape on it.
			var can_r := maxf(rad * 2.4, 0.017)
			var back := start + Vector3(0, 0, -len * 0.35)
			var can_len := len * 0.65 + 0.12
			_rod(r.root, can_r, can_r, can_len, back + Vector3(0, 0, -can_len / 2.0), mat("panel", Color(0.28, 0.3, 0.28)), 10)
			_rod(r.root, can_r * 1.04, can_r * 1.04, 0.03, back + Vector3(0, 0, -can_len * 0.3), mat("panel", TAPE), 10)
			_rod(r.root, can_r * 0.75, can_r, 0.012, back + Vector3(0, 0, -can_len - 0.006), mat("panel", BLACK), 10)
			end = back + Vector3(0, 0, -can_len - 0.012)
			sight = false
		"bbl_338":
			_rod(r.root, rad * 1.2, rad * 1.2, 0.02, start + Vector3(0, 0, -0.03), mat("panel", BLACK), 8)
			_rod(r.root, rad * 1.15, rad * 1.15, 0.008, start + Vector3(0, 0, -0.06), mat("panel", YELLOW), 8)
			for i in 3:
				var a := TAU * i / 3.0
				_box(r.root, Vector3(0.003, 0.003, len * 0.4), start + Vector3(cos(a) * rad, sin(a) * rad, -len * 0.55),
						mat("panel", BLACK), Vector3(0, 0, rad_to_deg(a)), 0.0)
		"rifled_slug_barrel":
			# A cantilever rail over the chamber and rifle sights: a ramp and an orange blade.
			_box(r.root, Vector3(0.008, 0.012, 0.03), end + Vector3(0, rad + 0.006, 0.02), mat("panel", DARK), Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.003, 0.008, 0.006), end + Vector3(0, rad + 0.016, 0.02), mat("panel", ORANGE, FIRE * 0.6), Vector3.ZERO, 0.0)
			_rod(r.root, rad * 1.1, rad * 1.1, 0.01, start + Vector3(0, 0, -len * 0.5), mat("panel", OLIVE), 8)
			sight = false
		"nail_guide":
			_rod(r.root, rad * 1.3, rad * 1.3, 0.02, end + Vector3(0, 0, 0.01), mat("panel", YELLOW), 6)
			_rod(r.root, rad * 1.6, rad * 1.3, 0.012, end + Vector3(0, 0, -0.004), mat("panel", BLACK), 6)
	if sight:
		_box(r.root, Vector3(0.004, 0.014, 0.008), start + Vector3(0, rad + 0.006, -len + 0.012), mat("panel", DARK))
	if id != "" and not Arsenal.is_organ(id):
		r.done["barrel"] = true
		if not id in ["long_barrel", "short_barrel", "heavy_barrel", "fluted_barrel", "match_barrel", "polygonal_barrel",
				"threaded_barrel", "integral_suppressor", "bbl_338", "rifled_slug_barrel", "nail_guide"]:
			_generic(r, start + Vector3(0, rad + 0.006, -len * 0.5), id)
	r.barrel_start = start
	r.barrel_r = rad
	r.muzzle = end
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
	# Cylinder with six chamber mouths showing the rounds (eight in the big one; the .45
	# conversion holds them in black moon clips).
	var recv: String = r.parts.get("receiver", "")
	var chambers := 8 if recv == "cylinder_8" else 6
	var cyl_r := 0.029 if recv == "cylinder_8" else 0.025
	if recv in ["cylinder_8", "cylinder_45"]:
		r.done["receiver"] = true
	_rod(r.root, cyl_r, cyl_r, 0.05, Vector3(0, y - 0.006, -0.04), mat("panel", NICKEL if recv == "cylinder_8" else STEEL), chambers + 2)
	if recv == "cylinder_45":
		_rod(r.root, cyl_r * 0.95, cyl_r * 0.95, 0.004, Vector3(0, y - 0.006, -0.013), mat("panel", BLACK), 8)
	for i in chambers:
		var a := TAU * i / chambers + PI / chambers
		var pos := Vector3(cos(a) * (cyl_r - 0.01), y - 0.006 + sin(a) * (cyl_r - 0.01), -0.04)
		_round(r, _rod(r.root, 0.0055 if recv != "cylinder_45" else 0.0065, 0.0055, 0.052, pos, mat("brass"), 5))
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
	r.rail_l = Vector3(-0.009, y - 0.017, -0.13)
	r.recv = Vector3(0, y - 0.006, -0.04)
	r.body_w = 0.014
	r.mount = r.top + Vector3(0, 0, -0.05)
	r.bolt = Vector3(0, y + 0.024, 0.03)
	r.mag = Vector3(0, 0.03, -0.05)


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
	r.under = Vector3(0, y - 0.025, start.z - 0.08)
	r.gadget = Vector3(0, y - 0.03, 0.07)
	r.side = Vector3(0.028, y, -0.13)
	r.rail_l = Vector3(-0.021, y, -0.23)
	r.rail_r = Vector3(0.021, y, -0.23)
	r.foregrip = Vector3(0, y - 0.02, -0.21)
	r.hg_start = -0.18
	r.hg_end = -0.28
	r.hg_y = y
	r.hg_r = 0.02
	r.charging = Vector3(0.052, y + 0.012, -0.1)
	r.bolt = Vector3(0.028, y + 0.01, -0.03)
	r.recv = Vector3(0, y, -0.04)
	r.body_w = 0.028
	r.mount = Vector3(0, y + 0.028, -0.12)


static func _shotgun(r: Rig) -> void:
	var y := 0.08
	var wood := mat("wood", WOOD)
	_grip(r, Vector3(0, 0.05, 0.02), wood, Vector3(0.034, 0.1, 0.045), -20.0)
	_box(r.root, Vector3(0.042, 0.066, 0.17), Vector3(0, y - 0.004, -0.04), mat("panel", DARK), Vector3.ZERO, 0.008)
	_box(r.root, Vector3(0.044, 0.02, 0.06), Vector3(0, y - 0.0, -0.03), mat("grate", Color(1.5, 1.5, 1.5)))
	var len := _barrel(r, Vector3(0, y + 0.012, -0.125), 0.34, 0.013, mat("panel", STEEL))
	# Tube magazine under the barrel, and the pump on it (a handguard part replaces the pump).
	var tube := minf(len - 0.03, 0.27)
	_rod(r.root, 0.011, 0.011, tube, Vector3(0, y - 0.016, -0.125 - tube / 2.0), mat("panel", DARK), 6)
	r.tube_end = Vector3(0, y - 0.016, -0.125 - tube)
	r.tube_r = 0.011
	_rod(r.root, 0.0125, 0.0125, 0.01, r.tube_end, mat("panel", BLACK), 6)
	if not r.parts.has("handguard"):
		_box(r.root, Vector3(0.042, 0.036, 0.12), Vector3(0, y - 0.016, -0.22), wood, Vector3.ZERO, 0.01)
		for i in 4:
			_box(r.root, Vector3(0.044, 0.004, 0.006), Vector3(0, y - 0.006, -0.18 - i * 0.025), mat("panel", BLACK), Vector3.ZERO, 0.001)
	# Duct tape holding barrel and tube together.
	_box(r.root, Vector3(0.032, 0.05, 0.022), Vector3(0, y - 0.002, -0.125 - tube + 0.02), mat("panel", TAPE), Vector3.ZERO, 0.006)
	# A red shell sitting in the ejection port.
	_box(r.root, Vector3(0.003, 0.022, 0.05), Vector3(0.021, y + 0.004, -0.05), mat("panel", BLACK), Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.009, 0.009, 0.034, Vector3(0.018, y + 0.004, -0.05), mat("panel", RED), 6))
	_trigger(r, 0.045, 0.0)
	r.stock = Vector3(0, y - 0.01, 0.045)
	if not r.parts.has("stock"):
		# A plain wooden butt, split and wired back together.
		_profile(r.root, [Vector2(-0.04, 0.02), Vector2(-0.35, 0.008), Vector2(-0.36, -0.1), Vector2(-0.33, -0.105),
				Vector2(-0.09, -0.04), Vector2(-0.04, -0.035)], 0.036, Vector3(0, y - 0.01, 0), wood)
		_box(r.root, Vector3(0.038, 0.112, 0.012), Vector3(0, y - 0.056, 0.362), mat("panel", BLACK), Vector3.ZERO, 0.003)
		_rod(r.root, 0.0215, 0.0215, 0.006, Vector3(0, y - 0.03, 0.2), mat("panel", STEEL), 6, Vector3(90, 0, 0))
		r.butt = Vector3(0, y - 0.056, 0.368)
		r.butt_h = 0.112
		r.comb = Vector3(0, y + 0.004, 0.25)
	r.mag = Vector3(0, y - 0.036, -0.07)
	r.mag_style = "tube"
	r.mag_w = 0.03
	r.mag_d = 0.06
	r.mag_len = 0.1
	r.mag_tilt = 4.0
	r.hg_start = -0.16
	r.hg_end = -0.28
	r.hg_y = y - 0.012
	r.hg_r = 0.021
	r.recv = Vector3(0, y - 0.004, -0.04)
	r.body_w = 0.021
	r.mount = Vector3(0, y + 0.03, -0.1)
	r.bolt = Vector3(0.021, y + 0.004, -0.05)
	r.top = Vector3(0, y + 0.03, -0.05)
	r.stock = Vector3(0, y - 0.01, 0.045)
	r.under = Vector3(0, y - 0.04, -0.33 if tube > 0.2 else r.muzzle.z + 0.05)
	r.gadget = Vector3(0, y - 0.035, 0.04)
	r.side = Vector3(0.022, y, -0.06)


static func _rifle(r: Rig) -> void:
	var y := 0.08
	var wood := mat("wood", WOOD)
	var chassis: bool = r.parts.get("receiver", "") == "precision_chassis"
	if chassis:
		# An aluminium chassis instead of the plank: a slab fore-end with rails, a skeleton
		# grip and (with no stock part) a folding skeleton butt.
		r.done["receiver"] = true
		var alu := mat("panel", Color(0.34, 0.36, 0.4))
		_box(r.root, Vector3(0.036, 0.04, 0.4), Vector3(0, 0.05, -0.16), alu, Vector3.ZERO, 0.004)
		_pic(r, Vector3(0, 0.03, -0.24), 0.22, 180.0)
		for sx: float in [-1.0, 1.0]:
			_pic(r, Vector3(sx * 0.018, 0.05, -0.26), 0.1, -sx * 90.0, 0.016)
			for i in 4:
				_box(r.root, Vector3(0.003, 0.012, 0.03), Vector3(sx * 0.018, 0.05, -0.08 - i * 0.07), mat("panel", BLACK), Vector3.ZERO, 0.0)
		_grip(r, Vector3(0, 0.04, 0.03), mat("panel", BLACK), Vector3(0.03, 0.095, 0.045), -18.0)
		_box(r.root, Vector3(0.03, 0.03, 0.06), Vector3(0, 0.05, 0.05), alu, Vector3.ZERO, 0.004)
		r.stock = Vector3(0, y - 0.012, 0.075)
		if not r.parts.has("stock"):
			_tube(r.root, [Vector3(0, 0.07, 0.08), Vector3(0, 0.07, 0.33), Vector3(0, -0.02, 0.33), Vector3(0, 0.03, 0.09)], 0.007, alu, 5)
			_box(r.root, Vector3(0.036, 0.1, 0.014), Vector3(0, 0.025, 0.335), mat("panel", BLACK), Vector3.ZERO, 0.003)
			_box(r.root, Vector3(0.028, 0.016, 0.1), Vector3(0, 0.08, 0.24), mat("panel", BLACK), Vector3.ZERO, 0.004)
			r.butt = Vector3(0, 0.025, 0.342)
			r.butt_h = 0.1
			r.comb = Vector3(0, 0.088, 0.24)
		r.rail_r = Vector3(0.026, 0.05, -0.26)
		r.rail_l = Vector3(-0.026, 0.05, -0.26)
		r.foregrip = Vector3(0, 0.023, -0.2)
	else:
		# Fore-end and wrist carved from one plank.
		_profile(r.root, [Vector2(-0.06, 0.03), Vector2(0.06, 0.0), Vector2(0.36, 0.0), Vector2(0.37, 0.03),
				Vector2(0.36, 0.055), Vector2(-0.06, 0.06), Vector2(-0.08, 0.04)], 0.036, Vector3(0, 0.02, 0), wood)
		_grip(r, Vector3(0, 0.04, 0.03), wood, Vector3(0.034, 0.09, 0.05), -28.0)
		r.stock = Vector3(0, y - 0.012, 0.075)
		if not r.parts.has("stock"):
			# The rest of the plank: a long butt, cracked and taped.
			_profile(r.root, [Vector2(-0.07, 0.06), Vector2(-0.35, 0.05), Vector2(-0.36, -0.04), Vector2(-0.33, -0.045),
					Vector2(-0.07, 0.02)], 0.034, Vector3(0, 0.02, 0), wood)
			_box(r.root, Vector3(0.036, 0.1, 0.012), Vector3(0, 0.025, 0.362), mat("panel", DARK), Vector3.ZERO, 0.003)
			_box(r.root, Vector3(0.036, 0.024, 0.03), Vector3(0, 0.06, 0.16), mat("panel", TAPE), Vector3(-4, 0, 0), 0.003)
			r.butt = Vector3(0, 0.025, 0.368)
			r.butt_h = 0.1
			r.comb = Vector3(0, 0.07, 0.25)
		r.rail_l = Vector3(-0.0185, 0.05, -0.24)
		r.rail_r = Vector3(0.0185, 0.05, -0.24)
		r.foregrip = Vector3(0, 0.02, -0.22)
	_rod(r.root, 0.016, 0.016, 0.16, Vector3(0, y + 0.002, -0.02), mat("panel", DARK), 8)
	# Bolt handle with a knob, sticking out to the right.
	r.bolt = Vector3(0.052, y - 0.014, 0.042)
	_rod_between(r.root, Vector3(0.012, y + 0.004, 0.03), Vector3(0.05, y - 0.012, 0.04), 0.004, mat("panel", STEEL))
	if r.parts.get("bolt", "") != "bolt_knob":
		_ball(r.root, 0.01, r.bolt, mat("panel", STEEL))
	_barrel(r, Vector3(0, y + 0.002, -0.1), 0.42, 0.009, mat("panel", STEEL))
	if not chassis:
		for z: float in [-0.2, -0.34]:
			_rod(r.root, 0.022, 0.022, 0.012, Vector3(0, y - 0.01, z), mat("brass"), 6)
	_trigger(r, 0.04, 0.0)
	r.mag = Vector3(0, 0.025 if not chassis else 0.03, -0.05)
	r.mag_len = 0.035
	r.mag_w = 0.02
	r.mag_d = 0.05
	r.mag_tilt = 0.0
	if not r.parts.has("magazine"):
		_box_mag(r, r.mag, 0.035, mat("panel", DARK), 0.02, 0.05, 0.0)
	r.top = Vector3(0, y + 0.018, -0.02)
	r.mount = Vector3(0, y + 0.018, -0.075)
	r.under = Vector3(0, 0.035, -0.4)
	r.gadget = Vector3(0, 0.022, 0.06)
	r.side = Vector3(0.019, 0.05, -0.18) if not chassis else Vector3(0.019, 0.06, 0.05)
	r.hg_start = -0.1
	r.hg_end = -0.37
	r.hg_y = 0.05
	r.hg_r = 0.02
	r.recv = Vector3(0, y + 0.002, -0.02)
	r.body_w = 0.016


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
	r.rail_l = Vector3(-0.028, 0.07, -0.06)
	r.rail_r = Vector3(0.028, 0.07, -0.06)
	r.recv = Vector3(0, 0.075, -0.03)
	r.body_w = 0.027
	r.mount = Vector3(0, 0.115, -0.08)
	r.bolt = Vector3(0.028, 0.08, 0.0)
	r.mag_style = "coil"


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
	r.rail_l = Vector3(-0.018, 0.06, -0.15)
	r.rail_r = Vector3(0.018, 0.06, -0.15)
	r.foregrip = Vector3(0, 0.041, -0.17)
	r.mount = Vector3(0, 0.089, 0.0)
	r.recv = Vector3(0, 0.06, -0.05)
	r.body_w = 0.017
	r.hg_start = -0.05
	r.hg_end = -0.25
	r.hg_y = 0.06
	r.hg_r = 0.019


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
	r.rail_l = Vector3(-0.015, 0.06, -0.24)
	r.rail_r = Vector3(0.015, 0.06, -0.24)
	r.recv = Vector3(0, 0.06, -0.02)
	r.body_w = 0.014
	r.hg_start = -0.1
	r.hg_end = -0.3
	r.hg_y = 0.06
	r.hg_r = 0.014


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
	r.rail_l = Vector3(-0.026, 0.075, -0.03)
	r.recv = Vector3(0, 0.075, -0.02)
	r.body_w = 0.025


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
	r.rail_l = Vector3(-0.022, 0.07, -0.25)
	r.mount = Vector3(0, 0.092, -0.12)
	r.recv = Vector3(0, 0.07, -0.05)
	r.body_w = 0.021


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
	r.foregrip = Vector3(0, 0.049, -0.36)
	r.mount = Vector3(0, 0.125, -0.08)
	r.recv = Vector3(0, 0.08, 0.0)
	r.body_w = 0.035


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
	r.rail_l = Vector3(-0.047, 0.08, -0.2)
	r.mount = Vector3(0, 0.126, -0.12)
	r.recv = Vector3(0, 0.08, 0.0)
	r.body_w = 0.046


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
	r.rail_l = Vector3(-0.026, 0.065, -0.03)
	r.recv = Vector3(0, 0.065, -0.02)
	r.body_w = 0.025


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
	r.rail_l = Vector3(-0.026, 0.07, -0.04)
	r.recv = Vector3(0, 0.07, -0.02)
	r.body_w = 0.025


static func _ring(centre: Vector3, radius: float, segments: int) -> Array:
	var points := []
	for i in segments + 1:
		var a := TAU * i / segments
		points.append(centre + Vector3(cos(a), sin(a), 0) * radius)
	return points



# --- Handguns (gunsmith v2) --------------------------------------------------------

## A pistol slide from z `back` to `front`: serrations at the back, an ejection port on the
## right with a round showing in it, and a pair of sights.
static func _pistol_slide(r: Rig, back: float, front: float, y: float, w: float, h: float, m: Material) -> void:
	_box(r.root, Vector3(w, h, back - front), Vector3(0, y, (back + front) / 2.0), m, Vector3.ZERO, 0.004)
	for i in 4:
		_box(r.root, Vector3(w + 0.002, h * 0.6, 0.0025), Vector3(0, y - h * 0.08, back - 0.008 - i * 0.006),
				mat("panel", BLACK), Vector3.ZERO, 0.0)
	var port := Vector3(w / 2.0, y + h * 0.15, back - 0.07)
	_box(r.root, Vector3(0.004, h * 0.4, 0.028), port, mat("panel", BLACK), Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.0042, 0.0042, 0.018, port + Vector3(-0.002, 0, 0), mat("brass"), 5))
	_box(r.root, Vector3(0.004, 0.006, 0.006), Vector3(0, y + h / 2.0 + 0.003, front + 0.008), mat("panel", BLACK))
	_box(r.root, Vector3(w * 0.8, 0.006, 0.006), Vector3(0, y + h / 2.0 + 0.003, back - 0.008), mat("panel", BLACK))
	_box(r.root, Vector3(0.0025, 0.003, 0.003), Vector3(0, y + h / 2.0 + 0.007, front + 0.008), mat("panel", BONE, Color(0.4, 0.45, 0.1)), Vector3.ZERO, 0.0)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y, (back + front) / 2.0)
	r.top = Vector3(0, y + h / 2.0, back - 0.03)
	r.mount = Vector3(0, y + h / 2.0, front + 0.03)
	r.body_w = w / 2.0


## A pistol's magazine lives in its grip: by default only the base plate shows; parts that
## stick out come down along the grip.
static func _pistol_mag(r: Rig, stick := 0.0, m: Material = null) -> void:
	r.mag = _grip_bottom(r)
	r.mag_style = "pistol"
	r.mag_tilt = r.grip_rake
	r.mag_w = r.grip_size.x - 0.008
	r.mag_d = r.grip_size.z - 0.012
	r.mag_len = maxf(stick, 0.03)
	r.gadget = r.mag + Vector3(0, -0.004, 0.02)
	if r.parts.has("magazine"):
		return
	if stick > 0.0:
		_mag_body(r, r.mag, stick, r.mag_w, r.mag_d, r.mag_tilt, 0.0, m if m != null else mat("panel", DARK))
	else:
		_box(r.root, Vector3(r.grip_size.x + 0.003, 0.009, r.grip_size.z + 0.005), r.mag, mat("panel", BLACK),
				Vector3(r.grip_rake, 0, 0), 0.002)


static func _service_pistol(r: Rig) -> void:
	var y := 0.075
	var frame := mat("panel", TAN)
	_pistol_slide(r, 0.035, -0.155, y, 0.028, 0.03, mat("panel", BLACK))
	# Polymer frame under the slide; the dust cover has a short rail under its nose.
	_box(r.root, Vector3(0.025, 0.022, 0.18), Vector3(0, 0.051, -0.06), frame, Vector3.ZERO, 0.005)
	for i in 3:
		_box(r.root, Vector3(0.02, 0.004, 0.005), Vector3(0, 0.0385, -0.105 - i * 0.014), mat("panel", BLACK), Vector3.ZERO, 0.0)
	_grip(r, Vector3(0, 0.046, 0.024), frame, Vector3(0.028, 0.094, 0.044), -18.0)
	_box(r.root, Vector3(0.024, 0.01, 0.026), Vector3(0, 0.05, 0.046), frame, Vector3(-25, 0, 0), 0.004)
	_trigger(r, 0.04, 0.0)
	_barrel(r, Vector3(0, y + 0.003, -0.12), 0.042, 0.0075, mat("panel", STEEL), false)
	_pistol_mag(r)
	# A strip of red tape where somebody marked it as theirs.
	_box(r.root, Vector3(0.027, 0.006, 0.03), Vector3(0, 0.051, -0.02), mat("panel", RED), Vector3.ZERO, 0.001)
	r.rail_l = Vector3(0, 0.038, -0.12)
	r.stock = Vector3(0, 0.055, 0.04)
	r.side = Vector3(0.0135, 0.051, -0.07)
	r.charging = Vector3(0, y + 0.008, 0.035)


static func _heavy_pistol(r: Rig) -> void:
	var y := 0.077
	var steel := mat("panel", STEEL)
	_pistol_slide(r, 0.035, -0.17, y, 0.025, 0.028, steel)
	_box(r.root, Vector3(0.0255, 0.012, 0.05), Vector3(0.0, y - 0.002, -0.08), mat("rust_metal", RUST), Vector3.ZERO, 0.002)
	_box(r.root, Vector3(0.024, 0.02, 0.17), Vector3(0, 0.054, -0.06), mat("panel", DARK), Vector3.ZERO, 0.004)
	# Barrel bushing at the nose, a hammer and a beavertail at the back.
	_rod(r.root, 0.009, 0.009, 0.006, Vector3(0, y + 0.002, -0.171), mat("panel", DARK), 8)
	_box(r.root, Vector3(0.008, 0.02, 0.01), Vector3(0, y + 0.012, 0.041), mat("panel", DARK), Vector3(30, 0, 0), 0.002)
	_box(r.root, Vector3(0.022, 0.008, 0.03), Vector3(0, 0.058, 0.045), steel, Vector3(-15, 0, 0), 0.003)
	_box(r.root, Vector3(0.004, 0.008, 0.02), Vector3(-0.0135, 0.066, 0.015), mat("panel", DARK), Vector3.ZERO, 0.001)
	# Walnut panels over a steel grip frame.
	_grip(r, Vector3(0, 0.048, 0.026), mat("wood", WOOD), Vector3(0.03, 0.096, 0.042), -14.0)
	if not r.parts.has("grip"):
		_box(r.root, Vector3(0.022, 0.096, 0.008), r.grip_top + _grip_down(-14.0) * 0.048 + Vector3(0, 0, 0.021), steel,
				Vector3(-14, 0, 0), 0.002)
	_trigger(r, 0.043, 0.0)
	_barrel(r, Vector3(0, y + 0.002, -0.13), 0.044, 0.0085, mat("panel", STEEL), false)
	_pistol_mag(r)
	r.rail_l = Vector3(0, 0.044, -0.125)
	r.stock = Vector3(0, 0.058, 0.045)
	r.side = Vector3(0.0125, 0.054, -0.07)


static func _machine_pistol(r: Rig) -> void:
	var y := 0.076
	var black := mat("panel", BLACK)
	_pistol_slide(r, 0.035, -0.165, y, 0.028, 0.03, mat("panel", DARK))
	# Ports cut in the slide's nose (it climbs), and a red fire selector at the back.
	for i in 3:
		_box(r.root, Vector3(0.012, 0.004, 0.008), Vector3(0, y + 0.0145, -0.135 + i * 0.012), black, Vector3.ZERO, 0.0)
	_box(r.root, Vector3(0.006, 0.01, 0.012), Vector3(-0.016, y - 0.004, 0.02), mat("panel", RED), Vector3.ZERO, 0.002)
	_box(r.root, Vector3(0.025, 0.022, 0.19), Vector3(0, 0.052, -0.065), mat("panel", POLY), Vector3.ZERO, 0.005)
	_grip(r, Vector3(0, 0.047, 0.024), mat("panel", POLY), Vector3(0.029, 0.094, 0.044), -18.0)
	_trigger(r, 0.041, 0.0)
	# The fold-down front grip under the nose, wrapped in olive tape.
	_box(r.root, Vector3(0.012, 0.012, 0.024), Vector3(0, 0.038, -0.12), black, Vector3.ZERO, 0.002)
	_box(r.root, Vector3(0.016, 0.055, 0.018), Vector3(0, 0.008, -0.126), black, Vector3(-12, 0, 0), 0.004)
	_box(r.root, Vector3(0.019, 0.016, 0.021), Vector3(0, 0.0, -0.127), mat("panel", OD), Vector3(-12, 0, 0), 0.002)
	_barrel(r, Vector3(0, y + 0.003, -0.13), 0.05, 0.0075, mat("panel", STEEL), false)
	_pistol_mag(r, 0.075, mat("panel", DARK))
	r.rail_l = Vector3(0, 0.04, -0.1)
	r.stock = Vector3(0, 0.056, 0.04)
	r.side = Vector3(0.0135, 0.052, -0.06)


# --- PDW -----------------------------------------------------------------------------

static func _pdw(r: Rig) -> void:
	var body := mat("panel", Color(0.36, 0.38, 0.32))
	var black := mat("panel", BLACK)
	# One moulded body: butt, thumbhole grip, finger loop and the nose, in one silhouette.
	_profile(r.root, [Vector2(-0.215, 0.065), Vector2(0.17, 0.065), Vector2(0.25, 0.052), Vector2(0.262, 0.03),
			Vector2(0.24, 0.012), Vector2(0.125, 0.012), Vector2(0.1, -0.03), Vector2(0.088, -0.066), Vector2(0.05, -0.07),
			Vector2(0.046, -0.03), Vector2(0.042, 0.004), Vector2(0.008, 0.004), Vector2(-0.008, -0.075),
			Vector2(-0.055, -0.08), Vector2(-0.06, -0.035), Vector2(-0.2, -0.05), Vector2(-0.218, -0.04)], 0.05,
			Vector3(0, 0.035, 0), body)
	# Black rubber butt plate and a band of tape round the middle.
	_box(r.root, Vector3(0.052, 0.11, 0.012), Vector3(0, 0.044, 0.216), black, Vector3.ZERO, 0.003)
	_box(r.root, Vector3(0.053, 0.06, 0.03), Vector3(0, 0.07, 0.08), mat("panel", TAPE), Vector3.ZERO, 0.002)
	# The 50-round magazine lies along the top; its rounds show through the smoke window.
	r.mag = Vector3(0, 0.1, 0.0)
	r.mag_style = "top"
	r.mag_len = 0.3
	if not r.parts.has("magazine"):
		_top_mag(r, 0.3, mat("panel", SMOKE))
	# A rail bridge over the magazine for the sight.
	for z: float in [0.13, -0.14]:
		_box(r.root, Vector3(0.012, 0.035, 0.014), Vector3(0, 0.118, z), black, Vector3.ZERO, 0.002)
	_pic(r, Vector3(0, 0.136, -0.005), 0.29)
	# Barrel out of the nose, cocking knobs on both sides.
	_barrel(r, Vector3(0, 0.062, -0.25), 0.045, 0.0075, mat("panel", STEEL), false)
	for sx: float in [-1.0, 1.0]:
		_ball(r.root, 0.006, Vector3(sx * 0.028, 0.075, -0.2), black)
	_box(r.root, Vector3(0.006, 0.022, 0.008), Vector3(0, 0.03, -0.03), black, Vector3(-15, 0, 0))
	r.trig = Vector3(0, 0.03, -0.03)
	r.grip_top = Vector3(0, 0.04, 0.03)
	r.grip_rake = -12.0
	r.top = Vector3(0, 0.143, 0.03)
	r.mount = Vector3(0, 0.143, -0.1)
	r.rail_l = Vector3(-0.026, 0.06, -0.19)
	r.rail_r = Vector3(0.026, 0.06, -0.19)
	r.foregrip = Vector3(0, 0.047, -0.2)
	r.hg_start = -0.13
	r.hg_end = -0.245
	r.hg_y = 0.06
	r.hg_r = 0.025
	r.stock = Vector3(0, 0.07, 0.215)
	r.butt = Vector3(0, 0.044, 0.222)
	r.gadget = Vector3(0, -0.012, 0.15)
	r.side = Vector3(0.026, 0.06, 0.12)
	r.bolt = Vector3(0.026, 0.07, -0.08)
	r.body_w = 0.025
	r.recv = Vector3(0, 0.07, 0.0)


## A magazine lying on top of the gun along Z, with a window of rounds down its side.
static func _top_mag(r: Rig, length: float, m: Material, width := 0.044) -> void:
	_box(r.root, Vector3(width, 0.026, length), r.mag + Vector3(0, 0.013, 0), m, Vector3.ZERO, 0.006)
	for sx: float in [-1.0, 1.0]:
		_round(r, _box(r.root, Vector3(0.003, 0.01, length * 0.8), r.mag + Vector3(sx * width * 0.5, 0.012, 0.0), mat("brass"), Vector3.ZERO, 0.001))


# --- Rifles ------------------------------------------------------------------------

## An AR receiver: lower with its magwell, upper with a flat-top rail, a charging handle
## and a forward assist. `s` scales it (the DMR is bigger). Uppers change it here.
static func _ar_receiver(r: Rig, y: float, s: float, upper_m: Material, lower_m: Material) -> void:
	var recv: String = r.parts.get("receiver", "")
	var upper := upper_m
	match recv:
		"upper_billet": upper = mat("panel", Color(0.95, 0.5, 0.3))
		"upper_light": upper = mat("panel", DARK)
	if recv in ["upper_300", "upper_pcc", "upper_light", "upper_billet"]:
		r.done["receiver"] = true
	_profile(r.root, [Vector2(-0.07, -0.01) * s, Vector2(0.125, -0.01) * s, Vector2(0.13, -0.03) * s, Vector2(0.12, -0.065) * s,
			Vector2(0.04, -0.065) * s, Vector2(0.035, -0.04) * s, Vector2(-0.03, -0.04) * s, Vector2(-0.075, -0.025) * s],
			0.03 * s, Vector3(0, y, 0), lower_m)
	var bevel := 0.001 if recv == "upper_billet" else 0.004
	var up_size := Vector3(0.032, 0.03, 0.2) * s
	if recv == "upper_billet":
		up_size += Vector3(0.004, 0.004, 0.0)
	_box(r.root, up_size, Vector3(0, y + 0.005 * s, -0.02 * s), upper, Vector3.ZERO, bevel)
	_pic(r, Vector3(0, y + 0.005 * s + up_size.y / 2.0, -0.02 * s), 0.2 * s)
	match recv:
		"upper_light":
			for sx: float in [-1.0, 1.0]:
				for i in 3:
					_box(r.root, Vector3(0.002, 0.012, 0.022), Vector3(sx * up_size.x / 2.0, y + 0.006, -0.08 + i * 0.03) * Vector3(1, 1, s),
							mat("panel", BLACK), Vector3.ZERO, 0.0)
		"upper_billet":
			# Squared-off billet: an oversized bolt release and a flared magwell lip.
			_box(r.root, Vector3(0.006, 0.014, 0.02), Vector3(-0.018 * s, y - 0.025 * s, -0.01 * s), mat("panel", Color(0.95, 0.5, 0.3)), Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.036 * s, 0.01, 0.075 * s), Vector3(0, y - 0.06 * s, -0.08 * s), mat("panel", Color(0.95, 0.5, 0.3)), Vector3.ZERO, 0.002)
		"upper_300":
			# Painted red band on the magwell: this one eats .300 Blackout.
			_box(r.root, Vector3(0.031 * s, 0.008, 0.07 * s), Vector3(0, y - 0.05 * s, -0.08 * s), mat("panel", RED), Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.033, 0.005, 0.03), Vector3(0, y + 0.005, 0.03), mat("panel", BONE), Vector3.ZERO, 0.001)
	# Ejection port with a round in it, forward assist, charging handle.
	var port := Vector3(up_size.x / 2.0, y + 0.004 * s, -0.02 * s)
	_box(r.root, Vector3(0.003, 0.012, 0.034) * s, port, mat("panel", BLACK), Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.0045, 0.0045, 0.02, port + Vector3(-0.002, 0, 0), mat("brass"), 5))
	_rod(r.root, 0.006, 0.006, 0.02, Vector3(up_size.x / 2.0 + 0.002, y + 0.008 * s, 0.05 * s), mat("panel", DARK), 6)
	r.charging = Vector3(0, y + 0.014 * s, 0.083 * s)
	if not r.parts.has("charging"):
		_box(r.root, Vector3(0.028, 0.008, 0.016) * s, r.charging, mat("panel", DARK), Vector3.ZERO, 0.002)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y + 0.005 * s, -0.02 * s)
	r.body_w = up_size.x / 2.0
	r.top = Vector3(0, y + 0.005 * s + up_size.y / 2.0 + 0.007, -0.01 * s)
	r.mount = Vector3(0, r.top.y, -0.095 * s)
	r.mag = Vector3(0, y - 0.065 * s, -0.08 * s)
	r.mag_len = 0.13 * s
	r.mag_w = 0.022 * s
	r.mag_d = 0.055 * s
	r.mag_tilt = 4.0
	r.mag_curve = 10.0
	if recv == "upper_pcc":
		# A magwell block: a skinny 9mm stick in the big rifle well.
		_box(r.root, Vector3(0.026, 0.016, 0.05) * s, r.mag + Vector3(0, -0.004, 0), mat("panel", ORANGE), Vector3.ZERO, 0.002)
		r.mag_d = 0.03
		r.mag_len = 0.15
		r.mag_curve = 0.0
		r.mag_tilt = 2.0


## The AR buffer tube behind the receiver, and (with no stock part) a crude fixed stock.
static func _ar_buffer(r: Rig, y: float, s: float, default_stock := true) -> void:
	r.stock = Vector3(0, y, 0.075 * s)
	r.has_buffer = true
	_rod(r.root, 0.014 * s, 0.014 * s, 0.2 * s, Vector3(0, y, 0.175 * s), mat("panel", BLACK), 8)
	_rod(r.root, 0.018 * s, 0.018 * s, 0.01, Vector3(0, y, 0.08 * s), mat("panel", DARK), 8)
	if r.parts.has("stock") or not default_stock:
		return
	_profile(r.root, [Vector2(-0.15, 0.016), Vector2(-0.31, 0.014), Vector2(-0.315, -0.07), Vector2(-0.29, -0.075),
			Vector2(-0.15, -0.018)], 0.034, Vector3(0, y, 0), mat("panel", TAN))
	_box(r.root, Vector3(0.036, 0.09, 0.012), Vector3(0, y - 0.028, 0.316), mat("panel", BLACK), Vector3.ZERO, 0.003)
	_box(r.root, Vector3(0.036, 0.02, 0.04), Vector3(0, y - 0.01, 0.2), mat("panel", TAPE), Vector3(-8, 0, 0), 0.003)
	r.butt = Vector3(0, y - 0.028, 0.322)
	r.butt_h = 0.09
	r.comb = Vector3(0, y + 0.015, 0.25)


static func _carbine(r: Rig) -> void:
	var y := 0.085
	_ar_receiver(r, y, 1.0, mat("panel", BLACK), mat("panel", DARK))
	_grip(r, Vector3(0, 0.05, 0.03), mat("panel", BLACK), Vector3(0.03, 0.095, 0.04), -20.0)
	_trigger(r, 0.05, 0.0)
	_barrel(r, Vector3(0, y, -0.12), 0.4, 0.0085, mat("panel", STEEL), false)
	r.hg_start = -0.125
	r.hg_end = -0.3
	r.hg_y = y
	r.hg_r = 0.021
	r.gas = Vector3(0, y, -0.32)
	if not r.parts.has("handguard"):
		# Round ribbed M4 handguard (olive, from another gun), a delta ring behind it.
		_rod(r.root, 0.021, 0.021, 0.175, Vector3(0, y, -0.2125), mat("panel", OD), 8)
		for i in 5:
			_rod(r.root, 0.0218, 0.0218, 0.006, Vector3(0, y, -0.145 - i * 0.033), mat("panel", BLACK), 8)
		_rod(r.root, 0.025, 0.025, 0.012, Vector3(0, y, -0.124), mat("panel", DARK), 8)
		_rod(r.root, 0.0225, 0.0225, 0.025, Vector3(0, y, -0.25), mat("panel", TAPE), 8)
	if not r.parts.has("gas"):
		if r.parts.has("handguard"):
			_rod(r.root, 0.012, 0.012, 0.02, r.gas, mat("panel", DARK), 6)
		else:
			# The A-frame front sight on the gas block.
			_rod(r.root, 0.013, 0.013, 0.026, r.gas, mat("panel", DARK), 6)
			_profile(r.root, [Vector2(0.305, 0.0), Vector2(0.335, 0.0), Vector2(0.325, 0.046), Vector2(0.315, 0.046)], 0.01,
					Vector3(0, y, 0), mat("panel", DARK))
			_box(r.root, Vector3(0.003, 0.012, 0.003), Vector3(0, y + 0.05, -0.32), mat("panel", BLACK), Vector3.ZERO, 0.0)
	_ar_buffer(r, y, 1.0)
	if not r.parts.has("magazine"):
		_std_mag(r, mat("panel", DARK))
	r.under = Vector3(0, y - 0.021, -0.28)
	r.gadget = Vector3(0, y - 0.016, 0.1)
	r.side = Vector3(0.019, y - 0.02, 0.2)


static func _dmr(r: Rig) -> void:
	var y := 0.09
	var s := 1.12
	_ar_receiver(r, y, s, mat("panel", TAN), mat("panel", BLACK))
	_grip(r, Vector3(0, 0.05, 0.032), mat("panel", BLACK), Vector3(0.032, 0.1, 0.044), -18.0)
	_trigger(r, 0.05, 0.0)
	_barrel(r, Vector3(0, y, -0.135), 0.52, 0.0105, mat("panel", DARK), false)
	r.hg_start = -0.14
	r.hg_end = -0.4
	r.hg_y = y
	r.hg_r = 0.025
	r.gas = Vector3(0, y, -0.36)
	if not r.parts.has("handguard"):
		# A long free-float tube with slots and a strip of rail on top, mismatched black.
		_rod(r.root, 0.025, 0.025, 0.26, Vector3(0, y, -0.27), mat("panel", DARK), 8)
		_pic(r, Vector3(0, y + 0.025, -0.27), 0.26)
		for sx: float in [-1.0, 1.0]:
			for i in 5:
				_box(r.root, Vector3(0.003, 0.008, 0.024), Vector3(sx * 0.024, y, -0.17 - i * 0.05), mat("panel", BLACK), Vector3.ZERO, 0.0)
		_rod(r.root, 0.0255, 0.0255, 0.03, Vector3(0, y, -0.36), mat("panel", TAPE), 8)
	if not r.parts.has("gas"):
		_rod(r.root, 0.013, 0.013, 0.02, r.gas, mat("panel", DARK), 6)
	_ar_buffer(r, y, s, false)
	if not r.parts.has("stock"):
		# A fixed rifle stock with a cheek comb (the buffer tube runs inside).
		_profile(r.root, [Vector2(-0.08, 0.02), Vector2(-0.2, 0.024), Vector2(-0.43, 0.02), Vector2(-0.44, -0.08),
				Vector2(-0.41, -0.088), Vector2(-0.2, -0.04), Vector2(-0.08, -0.025)], 0.038, Vector3(0, y, 0), mat("panel", BLACK))
		_box(r.root, Vector3(0.04, 0.1, 0.014), Vector3(0, y - 0.03, 0.442), mat("panel", DARK), Vector3.ZERO, 0.004)
		_box(r.root, Vector3(0.04, 0.03, 0.05), Vector3(0, y - 0.01, 0.15), mat("panel", OD), Vector3.ZERO, 0.004)
		r.butt = Vector3(0, y - 0.03, 0.45)
		r.butt_h = 0.1
		r.comb = Vector3(0, y + 0.024, 0.3)
	r.mag_len = 0.075
	r.mag_d = 0.065
	r.mag_w = 0.026
	r.mag_tilt = 2.0
	r.mag_curve = 0.0
	if not r.parts.has("magazine"):
		_std_mag(r, mat("panel", DARK))
	r.top = Vector3(0, r.top.y, -0.03)
	r.under = Vector3(0, y - 0.025, -0.38)
	r.gadget = Vector3(0, y - 0.035, 0.12)
	r.side = Vector3(0.02, y - 0.02, 0.32)


static func _ak(r: Rig) -> void:
	var y := 0.08
	var wood := mat("wood", WOOD)
	var recv: String = r.parts.get("receiver", "")
	var modern := recv == "ak_modern"
	if recv in ["ak_cover", "ak_modern"]:
		r.done["receiver"] = true
	# Stamped receiver, a ribbed dust cover on top and the rear sight block in front of it.
	_box(r.root, Vector3(0.032, 0.05, 0.24), Vector3(0, y - 0.01, -0.02), mat("panel", DARK), Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.029, 0.012, 0.21), Vector3(0, y + 0.02, 0.0), mat("panel", Color(0.36, 0.37, 0.4)), Vector3.ZERO, 0.004)
	for i in 3:
		_box(r.root, Vector3(0.03, 0.003, 0.004), Vector3(0, y + 0.026, 0.06 - i * 0.03), mat("panel", BLACK), Vector3.ZERO, 0.0)
	_box(r.root, Vector3(0.028, 0.02, 0.04), Vector3(0, y + 0.016, -0.13), mat("panel", DARK), Vector3.ZERO, 0.003)
	r.top = Vector3(0, y + 0.026, 0.0)
	if recv in ["ak_cover", "ak_modern"]:
		_pic(r, Vector3(0, y + 0.026, 0.0), 0.19, 0.0, 0.02, mat("panel", TAN if modern else BLACK))
		r.top = Vector3(0, y + 0.033, 0.0)
	r.mount = Vector3(0, r.top.y, -0.07)
	# Charging handle on the right, the big selector lever under it.
	r.charging = Vector3(0.034, y + 0.0, -0.09)
	_rod_between(r.root, Vector3(0.016, y, -0.09), r.charging, 0.004, mat("panel", STEEL))
	_ball(r.root, 0.0085 if modern else 0.0065, r.charging, mat("panel", BLACK if modern else STEEL))
	_box(r.root, Vector3(0.003, 0.012, 0.07), Vector3(0.0175, y - 0.002, 0.02), mat("panel", STEEL), Vector3(-6, 0, 0), 0.001)
	if modern:
		_box(r.root, Vector3(0.005, 0.016, 0.02), Vector3(0.0185, y - 0.012, -0.02), mat("panel", ORANGE), Vector3.ZERO, 0.002)
	_round(r, _rod(r.root, 0.0045, 0.0045, 0.02, Vector3(0.0145, y + 0.006, -0.06), mat("brass"), 5))
	_grip(r, Vector3(0, 0.05, 0.03), mat("panel", PLUM), Vector3(0.03, 0.095, 0.04), -20.0)
	_trigger(r, 0.05, 0.0)
	_barrel(r, Vector3(0, y, -0.14), 0.4, 0.0085, mat("panel", STEEL), false)
	# Gas tube over the barrel, the gas block and the hooded front sight near the muzzle.
	_rod(r.root, 0.01, 0.01, 0.2, Vector3(0, y + 0.024, -0.24), mat("panel", DARK), 6)
	r.gas = Vector3(0, y + 0.014, -0.35)
	if not r.parts.has("gas"):
		_box(r.root, Vector3(0.02, 0.04, 0.03), r.gas, mat("panel", DARK), Vector3.ZERO, 0.004)
	var fs := r.muzzle + Vector3(0, 0, 0.03)
	_box(r.root, Vector3(0.018, 0.022, 0.03), fs + Vector3(0, 0.008, 0), mat("panel", DARK), Vector3.ZERO, 0.003)
	_tube(r.root, [fs + Vector3(-0.008, 0.016, 0.0), fs + Vector3(-0.008, 0.032, 0.0), fs + Vector3(0.008, 0.032, 0.0),
			fs + Vector3(0.008, 0.016, 0.0)], 0.0025, mat("panel", DARK), 4)
	r.hg_start = -0.145
	r.hg_end = -0.315
	r.hg_y = y + 0.006
	r.hg_r = 0.022
	if not r.parts.has("handguard"):
		_box(r.root, Vector3(0.038, 0.036, 0.17), Vector3(0, y - 0.006, -0.23), wood, Vector3.ZERO, 0.01)
		_box(r.root, Vector3(0.03, 0.02, 0.13), Vector3(0, y + 0.026, -0.22), wood, Vector3.ZERO, 0.008)
		_box(r.root, Vector3(0.04, 0.012, 0.014), Vector3(0, y - 0.004, -0.31), mat("panel", DARK), Vector3.ZERO, 0.002)
	r.stock = Vector3(0, y, 0.1)
	if not r.parts.has("stock"):
		# The slab of wood that drops away from the bore line.
		_profile(r.root, [Vector2(-0.098, 0.012), Vector2(-0.34, -0.004), Vector2(-0.345, -0.088), Vector2(-0.32, -0.09),
				Vector2(-0.098, -0.03)], 0.034, Vector3(0, y, 0), wood)
		_box(r.root, Vector3(0.036, 0.09, 0.008), Vector3(0, y - 0.046, 0.347), mat("panel", DARK), Vector3(-4, 0, 0), 0.002)
		_box(r.root, Vector3(0.036, 0.02, 0.05), Vector3(0, y - 0.018, 0.2), mat("panel", TAPE), Vector3(-5, 0, 0), 0.003)
		r.butt = Vector3(0, y - 0.046, 0.352)
		r.butt_h = 0.09
		r.comb = Vector3(0, y + 0.005, 0.24)
	# The banana magazine in orange bakelite.
	r.mag = Vector3(0, y - 0.035, -0.085)
	r.mag_len = 0.19
	r.mag_w = 0.024
	r.mag_d = 0.05
	r.mag_tilt = 8.0
	r.mag_curve = 32.0
	if not r.parts.has("magazine"):
		_std_mag(r, mat("panel", BAKELITE))
	r.bolt = Vector3(0.0165, y + 0.006, -0.06)
	r.recv = Vector3(0, y - 0.01, -0.02)
	r.body_w = 0.016
	r.under = Vector3(0, y - 0.025, -0.36)
	r.gadget = Vector3(0, y - 0.03, 0.12)
	r.side = Vector3(0.018, y - 0.02, 0.24)


static func _bullpup(r: Rig) -> void:
	var y := 0.085
	var body := mat("panel", OD)
	# The whole action sits behind the grip: one long body from the butt to the nose.
	_profile(r.root, [Vector2(-0.3, 0.115), Vector2(-0.3, 0.025), Vector2(-0.16, 0.032), Vector2(-0.155, 0.04),
			Vector2(-0.085, 0.04), Vector2(-0.075, 0.05), Vector2(0.03, 0.054), Vector2(0.11, 0.058), Vector2(0.175, 0.066),
			Vector2(0.18, 0.1), Vector2(0.12, 0.112), Vector2(-0.24, 0.118)], 0.054, Vector3.ZERO, body)
	_box(r.root, Vector3(0.056, 0.09, 0.012), Vector3(0, 0.07, 0.3), mat("panel", BLACK), Vector3.ZERO, 0.003)
	_box(r.root, Vector3(0.056, 0.05, 0.04), Vector3(0, 0.09, 0.2), mat("panel", TAPE), Vector3.ZERO, 0.003)
	_pic(r, Vector3(0, 0.118, -0.02), 0.22)
	_grip(r, Vector3(0, 0.055, 0.02), mat("panel", BLACK), Vector3(0.03, 0.095, 0.042), -16.0)
	_trigger(r, 0.05, 0.0, false)
	# A guard big enough for a gloved fist.
	_tube(r.root, [Vector3(0, 0.054, -0.075), Vector3(0, -0.04, -0.07), Vector3(0, -0.058, -0.04), Vector3(0, -0.05, 0.02)],
			0.005, mat("panel", BLACK), 5)
	_barrel(r, Vector3(0, y, -0.175), 0.23, 0.0085, mat("panel", STEEL))
	_rod(r.root, 0.013, 0.013, 0.012, Vector3(0, y, -0.182), mat("panel", DARK), 6)
	r.gas = Vector3(0, y, -0.2)
	# Charging knob on the left of the nose, ejection port up by the cheek.
	r.charging = Vector3(-0.034, 0.1, -0.06)
	if not r.parts.has("charging"):
		_rod_between(r.root, Vector3(-0.026, 0.1, -0.06), r.charging, 0.004, mat("panel", DARK))
		_ball(r.root, 0.007, r.charging, mat("panel", BLACK))
	var port := Vector3(0.0275, 0.095, 0.16)
	_box(r.root, Vector3(0.003, 0.014, 0.04), port, mat("panel", BLACK), Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.0045, 0.0045, 0.022, port + Vector3(-0.002, 0, 0), mat("brass"), 5))
	r.bolt = port + Vector3(0.002, 0, 0)
	r.mag = Vector3(0, 0.035, 0.12)
	r.mag_len = 0.11
	r.mag_w = 0.022
	r.mag_d = 0.055
	r.mag_tilt = -4.0
	r.mag_curve = 10.0
	if not r.parts.has("magazine"):
		_std_mag(r, mat("panel", SMOKE))
	r.top = Vector3(0, 0.125, 0.0)
	r.mount = Vector3(0, 0.125, -0.1)
	r.hg_start = -0.05
	r.hg_end = -0.175
	r.hg_y = 0.085
	r.hg_r = 0.027
	r.rail_l = Vector3(-0.028, 0.085, -0.13)
	r.rail_r = Vector3(0.028, 0.085, -0.13)
	r.foregrip = Vector3(0, 0.06, -0.135)
	r.under = Vector3(0, y - 0.012, -0.26)
	r.stock = Vector3(0, 0.085, 0.3)
	r.butt = Vector3(0, 0.07, 0.306)
	r.gadget = Vector3(0, 0.028, 0.24)
	r.side = Vector3(0.028, 0.06, 0.24)
	r.recv = Vector3(0, 0.085, 0.12)
	r.body_w = 0.027


static func _battle_rifle(r: Rig) -> void:
	var y := 0.085
	var steel := mat("panel", DARK)
	_box(r.root, Vector3(0.034, 0.06, 0.25), Vector3(0, y - 0.01, -0.02), steel, Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.03, 0.014, 0.2), Vector3(0, y + 0.026, 0.0), mat("panel", Color(0.4, 0.4, 0.42)), Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.035, 0.02, 0.06), Vector3(0, y - 0.01, 0.04), mat("rust_metal", RUST), Vector3.ZERO, 0.002)
	# Folded carry handle on the left, cocking handle on the left too.
	_tube(r.root, [Vector3(-0.017, y + 0.0, -0.1), Vector3(-0.03, y + 0.006, -0.09), Vector3(-0.03, y + 0.006, -0.03),
			Vector3(-0.017, y, -0.02)], 0.004, mat("panel", BLACK), 4)
	r.charging = Vector3(-0.032, y + 0.012, -0.125)
	if not r.parts.has("charging"):
		_rod_between(r.root, Vector3(-0.017, y + 0.012, -0.125), r.charging, 0.004, mat("panel", STEEL))
		_box(r.root, Vector3(0.006, 0.01, 0.016), r.charging, mat("panel", STEEL), Vector3.ZERO, 0.002)
	# Rear aperture sight at the back of the top cover.
	_box(r.root, Vector3(0.016, 0.018, 0.012), Vector3(0, y + 0.038, 0.08), steel, Vector3.ZERO, 0.002)
	var port := Vector3(0.0175, y + 0.004, -0.03)
	_box(r.root, Vector3(0.003, 0.012, 0.035), port, mat("panel", BLACK), Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.0048, 0.0048, 0.022, port + Vector3(-0.002, 0, 0), mat("brass"), 5))
	_grip(r, Vector3(0, 0.05, 0.03), mat("panel", BLACK), Vector3(0.03, 0.1, 0.042), -20.0)
	_trigger(r, 0.05, 0.0)
	_barrel(r, Vector3(0, y, -0.15), 0.48, 0.0095, mat("panel", STEEL), true)
	r.hg_start = -0.15
	r.hg_end = -0.35
	r.hg_y = y - 0.002
	r.hg_r = 0.023
	if not r.parts.has("handguard"):
		# Ventilated steel handguard.
		_box(r.root, Vector3(0.042, 0.046, 0.2), Vector3(0, y - 0.004, -0.25), mat("grate", Color(0.6, 0.6, 0.62)), Vector3.ZERO, 0.008)
		_box(r.root, Vector3(0.044, 0.014, 0.2), Vector3(0, y - 0.024, -0.25), steel, Vector3.ZERO, 0.004)
	r.gas = Vector3(0, y + 0.02, -0.37)
	_rod(r.root, 0.007, 0.007, 0.21, Vector3(0, y + 0.02, -0.26), mat("panel", DARK), 6)
	if not r.parts.has("gas"):
		_box(r.root, Vector3(0.024, 0.045, 0.04), r.gas + Vector3(0, -0.012, 0), steel, Vector3.ZERO, 0.004)
		_rod(r.root, 0.006, 0.006, 0.02, r.gas + Vector3(0, 0.0, -0.025), mat("brass"), 6)
	r.stock = Vector3(0, y, 0.105)
	if not r.parts.has("stock"):
		_profile(r.root, [Vector2(-0.103, 0.02), Vector2(-0.41, 0.014), Vector2(-0.42, -0.09), Vector2(-0.395, -0.095),
				Vector2(-0.15, -0.05), Vector2(-0.103, -0.04)], 0.036, Vector3(0, y, 0), mat("wood", Color(0.8, 0.6, 0.45)))
		_box(r.root, Vector3(0.038, 0.105, 0.012), Vector3(0, y - 0.038, 0.422), mat("panel", BLACK), Vector3.ZERO, 0.003)
		r.butt = Vector3(0, y - 0.038, 0.428)
		r.butt_h = 0.105
		r.comb = Vector3(0, y + 0.017, 0.3)
	r.mag = Vector3(0, y - 0.04, -0.085)
	r.mag_len = 0.11
	r.mag_w = 0.027
	r.mag_d = 0.07
	r.mag_tilt = 6.0
	r.mag_curve = 4.0
	if not r.parts.has("magazine"):
		_std_mag(r, mat("panel", DARK))
		_box(r.root, Vector3(0.029, 0.02, 0.072), r.mag + Vector3(0, -0.055, -0.006), mat("panel", TAPE), Vector3(6, 0, 0), 0.002)
	r.top = Vector3(0, y + 0.033, 0.0)
	r.mount = Vector3(0, y + 0.033, -0.08)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y - 0.01, -0.02)
	r.body_w = 0.017
	r.under = Vector3(0, y - 0.03, -0.42)
	r.gadget = Vector3(0, y - 0.04, 0.16)
	r.side = Vector3(0.019, y - 0.025, 0.3)


static func _lever_action(r: Rig) -> void:
	var y := 0.08
	var wood := mat("wood", WOOD)
	# Brass receiver with a loading gate (a round showing in it), hammer at the back.
	_box(r.root, Vector3(0.03, 0.052, 0.13), Vector3(0, 0.064, -0.04), mat("brass", Color(1.25, 1.05, 0.55)), Vector3.ZERO, 0.006)
	_box(r.root, Vector3(0.003, 0.016, 0.03), Vector3(0.0155, 0.054, -0.06), mat("panel", DARK), Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.0055, 0.0055, 0.02, Vector3(0.0145, 0.052, -0.06), mat("brass"), 5))
	_box(r.root, Vector3(0.008, 0.024, 0.012), Vector3(0, 0.095, 0.03), mat("panel", DARK), Vector3(25, 0, 0), 0.002)
	# The straight wrist and stock: no pistol grip, the hand sits in the lever loop.
	r.stock = Vector3(0, 0.07, 0.025)
	if not r.parts.has("stock"):
		_profile(r.root, [Vector2(-0.02, 0.09), Vector2(-0.1, 0.078), Vector2(-0.37, 0.07), Vector2(-0.38, -0.045),
				Vector2(-0.355, -0.05), Vector2(-0.1, 0.03), Vector2(-0.02, 0.04)], 0.034, Vector3.ZERO, wood)
		_box(r.root, Vector3(0.036, 0.12, 0.01), Vector3(0, 0.012, 0.382), mat("panel", DARK), Vector3(-3, 0, 0), 0.002)
		_box(r.root, Vector3(0.036, 0.018, 0.04), Vector3(0, 0.058, 0.09), mat("panel", TAPE), Vector3(-6, 0, 0), 0.003)
		r.butt = Vector3(0, 0.012, 0.387)
		r.butt_h = 0.12
		r.comb = Vector3(0, 0.074, 0.25)
	# The lever loop under the wrist (a big loop part replaces it).
	if r.parts.get("bolt", "") != "lever_loop":
		_lever(r, 1.0)
	_box(r.root, Vector3(0.005, 0.02, 0.006), Vector3(0, 0.03, -0.012), mat("panel", BLACK), Vector3(-10, 0, 0))
	r.trig = Vector3(0, 0.03, -0.012)
	r.grip_top = Vector3(0, 0.045, 0.04)
	r.grip_rake = -5.0
	_barrel(r, Vector3(0, y + 0.006, -0.105), 0.48, 0.0105, mat("panel", DARK))
	# Buckhorn rear sight; the half-length tube magazine under the barrel and its band.
	_box(r.root, Vector3(0.014, 0.01, 0.005), Vector3(0, y + 0.02, -0.17), mat("panel", DARK), Vector3.ZERO, 0.001)
	r.tube_r = 0.0085
	var tube_len := 0.3
	r.tube_end = Vector3(0, 0.063, -0.105 - tube_len)
	_rod(r.root, r.tube_r, r.tube_r, tube_len, Vector3(0, 0.063, -0.105 - tube_len / 2.0), mat("panel", DARK), 6)
	_rod(r.root, r.tube_r * 1.15, r.tube_r * 1.15, 0.008, r.tube_end, mat("brass"), 6)
	_box(r.root, Vector3(0.024, 0.034, 0.01), Vector3(0, 0.074, r.tube_end.z + 0.012), mat("panel", DARK), Vector3.ZERO, 0.002)
	# Wooden forend round the barrel and tube.
	_box(r.root, Vector3(0.03, 0.03, 0.19), Vector3(0, 0.068, -0.2), wood, Vector3.ZERO, 0.009)
	r.mag = Vector3(0, 0.038, -0.07)
	r.mag_style = "tube"
	r.top = Vector3(0, 0.091, -0.04)
	r.mount = Vector3(0, 0.091, -0.08)
	r.rail_l = Vector3(-0.0155, 0.068, -0.2)
	r.under = Vector3(0, 0.054, -0.44)
	r.gadget = Vector3(-0.0155, 0.06, 0.0)
	r.side = Vector3(0.018, 0.04, 0.25)
	r.bolt = Vector3(0, -0.03, 0.02)
	r.recv = Vector3(0, 0.064, -0.04)
	r.body_w = 0.015
	r.hg_start = -0.105
	r.hg_end = -0.29
	r.hg_y = 0.07
	r.hg_r = 0.018


## The lever loop under a lever action's wrist; `s` makes the big-loop part.
static func _lever(r: Rig, s: float) -> void:
	var m := mat("panel", STEEL if s > 1.0 else DARK)
	var o := Vector3(0, 0.038, -0.02)
	_tube(r.root, [o, o + Vector3(0, -0.04, -0.004) * Vector3(1, s, 1), o + Vector3(0, -0.06, 0.02) * Vector3(1, s, s),
			o + Vector3(0, -0.055, 0.075) * Vector3(1, s, s), o + Vector3(0, -0.02, 0.095) * Vector3(1, s, s),
			o + Vector3(0, -0.004, 0.08)], 0.0042 * minf(s, 1.3), m, 5)


static func _lmg(r: Rig) -> void:
	var y := 0.09
	var body := mat("panel", DARK)
	_box(r.root, Vector3(0.05, 0.075, 0.26), Vector3(0, y - 0.015, -0.03), body, Vector3.ZERO, 0.006)
	# Feed tray cover with its latch, a rail on it, and the belt feeding in from the left.
	_box(r.root, Vector3(0.052, 0.018, 0.16), Vector3(0, y + 0.03, -0.02), mat("panel", Color(0.4, 0.42, 0.38)), Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.02, 0.01, 0.02), Vector3(0, y + 0.04, 0.065), mat("panel", BLACK), Vector3.ZERO, 0.002)
	_pic(r, Vector3(0, y + 0.039, -0.02), 0.13)
	_box(r.root, Vector3(0.006, 0.04, 0.05), Vector3(-0.027, y + 0.005, -0.05), mat("panel", BLACK), Vector3.ZERO, 0.002)
	r.charging = Vector3(0.034, y - 0.0, -0.11)
	if not r.parts.has("charging"):
		_rod_between(r.root, Vector3(0.025, y, -0.11), r.charging, 0.004, mat("panel", STEEL))
		_box(r.root, Vector3(0.006, 0.014, 0.012), r.charging, mat("panel", BLACK), Vector3.ZERO, 0.002)
	_grip(r, Vector3(0, 0.045, 0.04), mat("panel", BLACK), Vector3(0.032, 0.1, 0.044), -18.0)
	_trigger(r, 0.045, 0.01)
	_barrel(r, Vector3(0, y, -0.16), 0.48, 0.0105, mat("panel", DARK))
	# Carry handle over the barrel; gas cylinder under it.
	_tube(r.root, [Vector3(0, y + 0.012, -0.19), Vector3(0, y + 0.05, -0.2), Vector3(0, y + 0.05, -0.27), Vector3(0, y + 0.012, -0.28)],
			0.005, mat("panel", BLACK), 5)
	_rod(r.root, 0.009, 0.009, 0.25, Vector3(0, y - 0.024, -0.285), mat("panel", DARK), 6)
	r.gas = Vector3(0, y - 0.018, -0.42)
	if not r.parts.has("gas"):
		_box(r.root, Vector3(0.022, 0.04, 0.03), r.gas, mat("panel", DARK), Vector3.ZERO, 0.004)
	r.hg_start = -0.16
	r.hg_end = -0.32
	r.hg_y = y - 0.01
	r.hg_r = 0.028
	if not r.parts.has("handguard"):
		_box(r.root, Vector3(0.05, 0.036, 0.16), Vector3(0, y - 0.03, -0.24), mat("panel", BLACK), Vector3.ZERO, 0.008)
		_box(r.root, Vector3(0.03, 0.012, 0.13), Vector3(0, y + 0.016, -0.235), mat("grate", Color(1.3, 1.3, 1.3)), Vector3.ZERO, 0.002)
	r.stock = Vector3(0, y - 0.005, 0.1)
	if not r.parts.has("stock"):
		_profile(r.root, [Vector2(-0.098, 0.03), Vector2(-0.38, 0.02), Vector2(-0.4, -0.08), Vector2(-0.37, -0.085),
				Vector2(-0.098, -0.04)], 0.04, Vector3(0, y, 0), mat("panel", Color(0.26, 0.27, 0.25)))
		_box(r.root, Vector3(0.042, 0.1, 0.014), Vector3(0, y - 0.025, 0.402), mat("panel", BLACK), Vector3.ZERO, 0.004)
		r.butt = Vector3(0, y - 0.025, 0.41)
		r.butt_h = 0.1
		r.comb = Vector3(0, y + 0.028, 0.28)
	r.mag = Vector3(-0.005, y - 0.0525, -0.06)
	r.mag_style = "belt"
	if not r.parts.has("magazine"):
		_belt_box(r, Vector3(0.05, 0.075, 0.1), mat("panel", OD))
	r.top = Vector3(0, y + 0.046, -0.01)
	r.mount = Vector3(0, y + 0.046, -0.07)
	r.bolt = Vector3(0.026, y - 0.02, 0.01)
	r.recv = Vector3(0, y - 0.015, -0.03)
	r.body_w = 0.025
	r.under = Vector3(0, y - 0.04, -0.4)
	r.gadget = Vector3(0, y - 0.045, 0.16)
	r.side = Vector3(0.022, y - 0.02, 0.3)


## An ammo box hanging under the gun with the belt of rounds running up into its left side.
static func _belt_box(r: Rig, size: Vector3, m: Material) -> void:
	var c := r.mag + Vector3(0, -size.y / 2.0 - 0.004, 0)
	_box(r.root, Vector3(0.03, 0.01, 0.04), r.mag + Vector3(0, -0.002, 0), mat("panel", BLACK), Vector3.ZERO, 0.002)
	_box(r.root, size, c, m, Vector3.ZERO, 0.006)
	_box(r.root, Vector3(size.x + 0.003, 0.012, size.z * 0.6), c + Vector3(0, size.y * 0.15, 0), mat("panel", TAPE), Vector3.ZERO, 0.002)
	_box(r.root, Vector3(size.x * 0.4, 0.006, 0.02), c + Vector3(0, -size.y / 2.0 - 0.002, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
	# Belt: links of rounds climbing from the box lid to the feed port on the left.
	var from := c + Vector3(-size.x * 0.3, size.y / 2.0, 0)
	var to := Vector3(-0.03, r.mag.y + 0.06, -0.05)
	for i in 6:
		var t := i / 5.0
		var p := from.lerp(to, t) + Vector3(-sin(t * PI) * 0.016, 0, 0)
		_round(r, _rod(r.root, 0.0045, 0.0045, 0.026, p, mat("brass"), 5))
		_box(r.root, Vector3(0.011, 0.006, 0.006), p + Vector3(0, 0, 0.006), mat("panel", BLACK), Vector3.ZERO, 0.001)


static func _anti_materiel(r: Rig) -> void:
	var y := 0.1
	var sand := mat("panel", TAN)
	var black := mat("panel", BLACK)
	# A long slab of a receiver, sand-painted, with a long rail on top.
	_box(r.root, Vector3(0.06, 0.05, 0.5), Vector3(0, y + 0.012, -0.05), sand, Vector3.ZERO, 0.006)
	_box(r.root, Vector3(0.056, 0.04, 0.42), Vector3(0, y - 0.03, -0.01), mat("panel", DARK), Vector3.ZERO, 0.006)
	_box(r.root, Vector3(0.061, 0.03, 0.08), Vector3(0, y + 0.012, -0.22), mat("rust_metal", RUST), Vector3.ZERO, 0.004)
	_pic(r, Vector3(0, y + 0.037, -0.06), 0.42, 0.0, 0.024)
	_grip(r, Vector3(0, 0.05, 0.035), black, Vector3(0.036, 0.11, 0.05), -18.0)
	_trigger(r, 0.05, 0.0)
	# A huge bolt handle on the right.
	r.bolt = Vector3(0.068, y - 0.004, 0.13)
	_rod_between(r.root, Vector3(0.03, y + 0.012, 0.11), r.bolt, 0.006, mat("panel", STEEL))
	if r.parts.get("bolt", "") != "bolt_knob":
		_ball(r.root, 0.014, r.bolt, black)
	# Fat fluted barrel.
	_barrel(r, Vector3(0, y + 0.004, -0.3), 0.58, 0.016, mat("panel", DARK), false)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_box(r.root, Vector3(0.004, 0.004, 0.3), Vector3(0, y + 0.004, -0.5) + Vector3(cos(a), sin(a), 0) * 0.016,
				black, Vector3(0, 0, rad_to_deg(a)), 0.0)
	if not r.parts.has("muzzle"):
		# The double-chamber brake: two chunky baffles with ports, a pointed nose.
		var m := r.muzzle
		for i in 2:
			var z := m.z - 0.018 - i * 0.034
			_box(r.root, Vector3(0.07, 0.045, 0.026), Vector3(0, m.y, z), mat("panel", BLACK), Vector3.ZERO, 0.006)
			_box(r.root, Vector3(0.072, 0.028, 0.012), Vector3(0, m.y, z - 0.004), mat("panel", BLACK, FIRE * 0.15), Vector3.ZERO, 0.0)
		_rod(r.root, 0.02, 0.022, 0.016, m + Vector3(0, 0, -0.078), black, 8)
		r.muzzle = m + Vector3(0, 0, -0.086)
	# The bipod yoke clamped round the barrel at the front of the receiver.
	_box(r.root, Vector3(0.05, 0.05, 0.04), Vector3(0, y - 0.004, -0.33), black, Vector3.ZERO, 0.006)
	r.foregrip = Vector3(0, y - 0.03, -0.335)
	# The stock is part of the gun: a long box, a fat recoil pad and a monopod under it.
	r.stock = Vector3(0, y, 0.2)
	if not r.parts.has("stock"):
		_box(r.root, Vector3(0.05, 0.075, 0.25), Vector3(0, y - 0.01, 0.325), sand, Vector3.ZERO, 0.008)
		_box(r.root, Vector3(0.04, 0.03, 0.12), Vector3(0, y + 0.04, 0.33), black, Vector3.ZERO, 0.006)
		_box(r.root, Vector3(0.054, 0.11, 0.025), Vector3(0, y - 0.01, 0.462), black, Vector3.ZERO, 0.006)
		_rod_between(r.root, Vector3(0, y - 0.05, 0.4), Vector3(0, y - 0.13, 0.405), 0.006, mat("panel", STEEL))
		_box(r.root, Vector3(0.03, 0.006, 0.03), Vector3(0, y - 0.133, 0.405), black, Vector3.ZERO, 0.002)
		r.butt = Vector3(0, y - 0.01, 0.475)
		r.butt_h = 0.11
		r.comb = Vector3(0, y + 0.055, 0.33)
	r.mag = Vector3(0, y - 0.05, -0.02)
	r.mag_len = 0.08
	r.mag_w = 0.042
	r.mag_d = 0.13
	r.mag_tilt = 0.0
	r.mag_curve = 0.0
	if not r.parts.has("magazine"):
		_std_mag(r, mat("panel", DARK))
	r.top = Vector3(0, y + 0.044, 0.02)
	r.mount = Vector3(0, y + 0.044, -0.2)
	r.rail_l = Vector3(-0.03, y + 0.012, -0.25)
	r.hg_start = -0.3
	r.hg_end = -0.33
	r.hg_y = y
	r.hg_r = 0.03
	r.recv = Vector3(0, y, -0.05)
	r.body_w = 0.03
	r.gadget = Vector3(0, y - 0.05, 0.22)
	r.side = Vector3(0.026, y - 0.01, 0.33)


# --- Shotguns ----------------------------------------------------------------------

## Two barrels side by side from `start` (the centre between them): returns the length.
static func _twin_barrels(r: Rig, start: Vector3, length: float, radius: float, m: Material) -> float:
	var gap := radius + 0.0012
	_barrel(r, start + Vector3(gap, 0, 0), length, radius, m, false)
	var len := _barrel(r, start + Vector3(-gap, 0, 0), length, radius, m, false)
	r.twin = gap
	r.barrel_start = start
	r.muzzle = Vector3(0, start.y, r.muzzle.z)
	# The rib between them with a brass bead at the end.
	_box(r.root, Vector3(0.008, 0.004, len), start + Vector3(0, radius + 0.002, -len / 2.0), mat("panel", DARK), Vector3.ZERO, 0.001)
	_ball(r.root, 0.0025, Vector3(0, start.y + radius + 0.006, r.muzzle.z + 0.006), mat("brass"))
	return len


static func _double_barrel(r: Rig) -> void:
	var y := 0.085
	var wood := mat("wood", WOOD)
	_box(r.root, Vector3(0.05, 0.05, 0.09), Vector3(0, 0.07, -0.04), mat("panel", STEEL), Vector3.ZERO, 0.008)
	_box(r.root, Vector3(0.052, 0.02, 0.05), Vector3(0, 0.06, -0.04), mat("brass", Color(1.0, 0.85, 0.6)), Vector3.ZERO, 0.004)
	# Two hammers and two triggers.
	for sx: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.006, 0.024, 0.01), Vector3(sx * 0.012, 0.1, 0.005), mat("panel", DARK), Vector3(25, 0, 0), 0.002)
	_box(r.root, Vector3(0.005, 0.02, 0.006), Vector3(0, 0.03, -0.028), mat("panel", BLACK), Vector3(-10, 0, 0))
	_trigger(r, 0.045, 0.0)
	r.trig = Vector3(0, 0.032, -0.012)
	r.grip_top = Vector3(0, 0.045, 0.035)
	r.grip_rake = -5.0
	r.stock = Vector3(0, 0.072, 0.005)
	if not r.parts.has("stock"):
		_profile(r.root, [Vector2(-0.0, 0.092), Vector2(-0.1, 0.08), Vector2(-0.37, 0.075), Vector2(-0.38, -0.045),
				Vector2(-0.355, -0.05), Vector2(-0.1, 0.03), Vector2(0.0, 0.045)], 0.036, Vector3.ZERO, wood)
		_box(r.root, Vector3(0.038, 0.125, 0.01), Vector3(0, 0.015, 0.382), mat("panel", BLACK), Vector3(-2, 0, 0), 0.002)
		# Shells in a leather cuff on the left of the stock.
		_box(r.root, Vector3(0.004, 0.04, 0.07), Vector3(-0.02, 0.05, 0.22), mat("panel", Color(0.6, 0.4, 0.25)), Vector3(-6, 0, 0), 0.001)
		for i in 3:
			_round(r, _rod(r.root, 0.0075, 0.0075, 0.04, Vector3(-0.026, 0.05, 0.2 + i * 0.02), mat("panel", RED), 6, Vector3(-6, 0, 0)))
		r.butt = Vector3(0, 0.015, 0.388)
		r.butt_h = 0.125
		r.comb = Vector3(0, 0.08, 0.25)
	_twin_barrels(r, Vector3(0, y, -0.085), 0.56, 0.0125, mat("panel", STEEL))
	_box(r.root, Vector3(0.04, 0.024, 0.16), Vector3(0, y - 0.019, -0.17), wood, Vector3.ZERO, 0.008)
	if r.rounds.is_empty():
		_round(r, _rod(r.root, 0.008, 0.008, 0.004, Vector3(0.0137, y, -0.083), mat("brass"), 8))
	r.top = Vector3(0, y + 0.017, -0.06)
	r.mount = Vector3(0, y + 0.017, -0.12)
	r.rail_l = Vector3(-0.021, y - 0.019, -0.17)
	r.mag_style = "none"
	r.recv = Vector3(0, 0.07, -0.04)
	r.body_w = 0.025
	r.gadget = Vector3(0, 0.045, 0.1)
	r.side = Vector3(0.019, 0.05, 0.24)
	r.under = Vector3(0, y - 0.03, -0.4)
	r.bolt = Vector3(0.025, 0.07, -0.04)


static func _auto_shotgun(r: Rig) -> void:
	var y := 0.085
	var black := mat("panel", BLACK)
	_box(r.root, Vector3(0.042, 0.06, 0.2), Vector3(0, y - 0.01, -0.03), mat("panel", POLY), Vector3.ZERO, 0.006)
	_pic(r, Vector3(0, y + 0.02, -0.02), 0.17)
	# Ghost-ring rear sight on the rail, a big charging handle, a shell in the port.
	_tube(r.root, _ring(Vector3(0, y + 0.044, 0.055), 0.008, 8), 0.0025, black, 4)
	_box(r.root, Vector3(0.006, 0.02, 0.01), Vector3(0, y + 0.032, 0.055), black, Vector3.ZERO, 0.001)
	r.charging = Vector3(0.036, y - 0.004, -0.07)
	if not r.parts.has("charging"):
		_rod_between(r.root, Vector3(0.02, y - 0.004, -0.07), r.charging, 0.005, mat("panel", STEEL))
		_box(r.root, Vector3(0.01, 0.014, 0.012), r.charging, mat("panel", STEEL), Vector3.ZERO, 0.002)
	var port := Vector3(0.0215, y + 0.0, -0.02)
	_box(r.root, Vector3(0.003, 0.02, 0.05), port, black, Vector3.ZERO, 0.0)
	_round(r, _rod(r.root, 0.009, 0.009, 0.03, port + Vector3(-0.003, 0, 0), mat("panel", RED), 6))
	_grip(r, Vector3(0, 0.05, 0.03), black, Vector3(0.032, 0.1, 0.044), -18.0)
	_trigger(r, 0.05, 0.0)
	_barrel(r, Vector3(0, y + 0.01, -0.13), 0.42, 0.012, mat("panel", DARK), true)
	# Tube magazine and the twin gas pistons beside it.
	r.tube_r = 0.012
	var tube := minf(0.32, r.barrel_start.distance_to(r.muzzle) - 0.05)
	r.tube_end = Vector3(0, y - 0.018, -0.13 - tube)
	_rod(r.root, r.tube_r, r.tube_r, tube, Vector3(0, y - 0.018, -0.13 - tube / 2.0), mat("panel", DARK), 6)
	_rod(r.root, r.tube_r * 1.1, r.tube_r * 1.1, 0.014, r.tube_end, black, 6)
	r.gas = Vector3(0, y - 0.004, -0.315)
	if not r.parts.has("gas"):
		for sx: float in [-1.0, 1.0]:
			_rod(r.root, 0.005, 0.005, 0.05, r.gas + Vector3(sx * 0.016, 0, 0.02), mat("panel", STEEL), 6)
	r.hg_start = -0.13
	r.hg_end = -0.29
	r.hg_y = y - 0.004
	r.hg_r = 0.024
	if not r.parts.has("handguard"):
		_box(r.root, Vector3(0.046, 0.042, 0.16), Vector3(0, y - 0.01, -0.21), mat("panel", POLY), Vector3.ZERO, 0.01)
		for i in 5:
			_box(r.root, Vector3(0.048, 0.006, 0.006), Vector3(0, y - 0.024, -0.15 - i * 0.025), black, Vector3.ZERO, 0.001)
	r.stock = Vector3(0, y - 0.005, 0.07)
	if not r.parts.has("stock"):
		_profile(r.root, [Vector2(-0.068, 0.02), Vector2(-0.39, 0.012), Vector2(-0.4, -0.085), Vector2(-0.375, -0.09),
				Vector2(-0.12, -0.04), Vector2(-0.068, -0.04)], 0.038, Vector3(0, y, 0), mat("panel", OD))
		_box(r.root, Vector3(0.04, 0.1, 0.014), Vector3(0, y - 0.035, 0.402), black, Vector3.ZERO, 0.004)
		r.butt = Vector3(0, y - 0.035, 0.41)
		r.butt_h = 0.1
		r.comb = Vector3(0, y + 0.016, 0.26)
	r.mag = Vector3(0, y - 0.04, -0.07)
	r.mag_style = "tube"
	r.mag_len = 0.1
	r.mag_w = 0.03
	r.mag_d = 0.06
	r.mag_tilt = 4.0
	r.top = Vector3(0, y + 0.027, -0.02)
	r.mount = Vector3(0, y + 0.027, -0.08)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y - 0.01, -0.03)
	r.body_w = 0.021
	r.under = Vector3(0, y - 0.034, -0.36)
	r.gadget = Vector3(0, y - 0.04, 0.12)
	r.side = Vector3(0.02, y - 0.02, 0.28)


static func _sawed_off(r: Rig) -> void:
	var y := 0.085
	_box(r.root, Vector3(0.05, 0.05, 0.085), Vector3(0, 0.072, -0.035), mat("panel", DARK), Vector3.ZERO, 0.008)
	for sx: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.006, 0.024, 0.01), Vector3(sx * 0.012, 0.1, 0.008), mat("panel", DARK), Vector3(25, 0, 0), 0.002)
	# What is left of the stock: a hacked-off wooden grip, the raw cut showing.
	_grip(r, Vector3(0, 0.06, 0.03), mat("wood", WOOD), Vector3(0.034, 0.095, 0.05), -32.0)
	if not r.parts.has("grip"):
		var cut := r.grip_top + _grip_down(-32.0) * 0.095
		_box(r.root, Vector3(0.036, 0.008, 0.052), cut, mat("wood", Color(1.5, 1.25, 0.95)), Vector3(-32, 0, 0), 0.002)
	_box(r.root, Vector3(0.036, 0.04, 0.05), Vector3(0, 0.06, 0.03), mat("wood", WOOD), Vector3(-10, 0, 0), 0.008)
	_trigger(r, 0.048, 0.0)
	_twin_barrels(r, Vector3(0, y, -0.078), 0.25, 0.0125, mat("panel", STEEL))
	# Hacksaw-bright cut at the end, and tape where the forend used to be.
	for sx: float in [-1.0, 1.0]:
		_rod(r.root, 0.0128, 0.0128, 0.006, Vector3(sx * r.twin, y, r.muzzle.z + 0.003), mat("panel", NICKEL), 6)
	_box(r.root, Vector3(0.056, 0.032, 0.05), Vector3(0, y - 0.004, -0.15), mat("panel", TAPE), Vector3.ZERO, 0.006)
	# Two spare shells taped on the left side.
	for i in 2:
		_round(r, _rod(r.root, 0.0075, 0.0075, 0.04, Vector3(-0.027, 0.07, -0.05 + i * 0.016), mat("panel", RED), 6, Vector3.ZERO))
	_box(r.root, Vector3(0.006, 0.012, 0.04), Vector3(-0.026, 0.07, -0.042), mat("panel", TAPE), Vector3.ZERO, 0.002)
	r.top = Vector3(0, y + 0.017, -0.06)
	r.mount = Vector3(0, y + 0.017, -0.12)
	r.rail_l = Vector3(-0.026, y - 0.004, -0.2)
	r.mag_style = "none"
	r.stock = Vector3(0, 0.07, 0.05)
	r.recv = Vector3(0, 0.072, -0.035)
	r.body_w = 0.025
	r.gadget = _grip_bottom(r) + Vector3(0, 0, 0.02)
	r.side = Vector3(0.026, 0.07, -0.04)
	r.bolt = Vector3(0.025, 0.072, -0.035)
	r.under = Vector3(0, y - 0.03, -0.25)



# --- Anchors ----------------------------------------------------------------------

## Works out every anchor the frame left open from the ones it set.
static func _settle_anchors(r: Rig) -> void:
	if r.hg_end == 0.0 and r.hg_start == 0.0:
		r.hg_start = r.barrel_start.z
		r.hg_end = lerpf(r.barrel_start.z, r.muzzle.z, 0.6)
		r.hg_y = r.barrel_start.y
		r.hg_r = maxf(r.barrel_r * 1.8, 0.016)
	var mid := (r.hg_start + r.hg_end) / 2.0
	if r.rail_l == Vector3.INF:
		r.rail_l = Vector3(-(r.hg_r + 0.002), r.hg_y, mid)
	if r.rail_r == Vector3.INF:
		r.rail_r = Vector3(absf(r.rail_l.x) if r.rail_l.x != 0.0 else r.hg_r + 0.002, r.rail_l.y, r.rail_l.z)
	if r.foregrip == Vector3.INF:
		r.foregrip = Vector3(0, r.hg_y - r.hg_r, lerpf(r.hg_start, r.hg_end, 0.4))
	if r.mount == Vector3.INF:
		r.mount = r.top + Vector3(0, 0, -0.045)
	if r.gas == Vector3.INF:
		r.gas = r.barrel_start.lerp(r.muzzle, 0.45)
	if r.recv == Vector3.INF:
		r.recv = Vector3(0, r.top.y - 0.025, (r.stock.z + r.barrel_start.z) / 2.0)
	if r.bolt == Vector3.INF:
		r.bolt = r.side + Vector3(0, 0.012, 0.02)
	if r.charging == Vector3.INF:
		r.charging = Vector3(0, r.top.y - 0.006, r.stock.z - 0.012)
	if r.grip_top == Vector3.INF:
		r.grip_top = Vector3(0, 0.04, 0.02)
	if r.tube_end == Vector3.INF:
		r.tube_end = Vector3(0, r.under.y + 0.01, r.under.z)


## Where each slot's part sits, for menus to point at (every Arsenal slot).
static func _slot_points(r: Rig, bare_muzzle: Vector3) -> Dictionary:
	var butt := r.butt if r.butt != Vector3.INF else r.stock + Vector3(0, -0.02, 0.1)
	var comb := r.comb if r.comb != Vector3.INF else r.stock + Vector3(0, 0.0, 0.1)
	var can := r.muzzle.lerp(r.device_start if r.device_start != Vector3.INF else bare_muzzle, 0.5)
	return {
		"receiver": r.recv, "barrel": r.barrel_start.lerp(bare_muzzle, 0.5), "muzzle": r.muzzle.lerp(bare_muzzle, 0.5),
		"silencer": can, "gas": r.gas, "handguard": Vector3(0, r.hg_y, (r.hg_start + r.hg_end) / 2.0),
		"rail_l": r.rail_l, "rail_r": r.rail_r, "foregrip": r.foregrip + Vector3(0, -0.03, 0), "underbarrel": r.under,
		"mount": r.mount + Vector3(0.012, 0.012, 0), "sight": r.top + Vector3(0, 0.02, 0),
		"grip": r.grip_top + _grip_down(r.grip_rake) * r.grip_size.y * 0.5, "trigger": r.trig, "bolt": r.bolt,
		"charging": r.charging, "magazine": r.mag + Vector3(0, -0.03, 0), "ammo": r.side,
		"stock": r.stock + Vector3(0, -0.02, 0.08), "buttpad": butt.lerp(comb, 0.15), "gadget": r.gadget + Vector3(0, -0.04, 0.01),
	}


# --- Parts ----------------------------------------------------------------------------

static func _attach_parts(r: Rig) -> void:
	var p: Dictionary = r.parts.duplicate()
	for slot: String in r.done:
		p.erase(slot)
	# Organs are grown on, not bolted: each slot's organ is the monster's model, small.
	for slot in Arsenal.SLOTS:
		if p.has(slot) and Arsenal.is_organ(p[slot]):
			_organ_on_gun(r, slot, p[slot])
			p.erase(slot)
	# The handguard first: it decides where rails, grips, gas cues and underbarrel things go.
	if p.has("handguard"):
		_handguard(r, p.handguard)
	for slot in Arsenal.SLOTS:
		if not p.has(slot) or slot in ["handguard", "ammo"]:
			continue
		var id: String = p[slot]
		match slot:
			"receiver": _receiver(r, id)
			"barrel": _barrel_part(r, id)
			"muzzle": _muzzle(r, id)
			"silencer": _silencer(r, id)
			"gas": _gas(r, id)
			"rail_l", "rail_r": _rail_part(r, slot, id)
			"foregrip": _foregrip(r, id)
			"underbarrel": _underbarrel(r, id)
			"mount": _mount(r, id)
			"sight": _sight(r, id)
			"grip": _grip_part(r, id)
			"trigger": _trigger_part(r, id)
			"bolt": _bolt_part(r, id)
			"charging": _charging(r, id)
			"magazine": _magazine(r, id)
			"stock": _stock(r, id)
			"buttpad": _buttpad(r, id)
			"gadget": _gadget(r, id)
			_: _generic(r, r.recv, id)
	# Ammo last, so every visible round (even ones a part added) takes its colour.
	if p.has("ammo"):
		_ammo(r, p.ammo)


## Receivers the frame didn't draw itself (unknown ones): a painted band on the receiver.
static func _receiver(r: Rig, id: String) -> void:
	match id:
		"cylinder_8", "cylinder_45", "upper_300", "upper_pcc", "upper_light", "upper_billet", "ak_cover", "ak_modern", "precision_chassis":
			# Drawn by a frame that takes it; anywhere else it is just a marked-up receiver.
			_box(r.root, Vector3(r.body_w * 2.0 + 0.003, 0.008, 0.04), r.recv, mat("panel", ORANGE), Vector3.ZERO, 0.001)
		_:
			_generic(r, r.recv + Vector3(0, 0, 0.02), id)


## Barrel parts on frames whose barrel isn't a plain tube (energy coils).
static func _barrel_part(r: Rig, id: String) -> void:
	match id:
		"coil_barrel":
			_coil_barrel(r)
		"cooling_coil":
			# Coolant hoses wound round the front, a little blue tank of it.
			var start := r.muzzle
			var points := []
			for i in 25:
				var a := TAU * i / 7.0
				points.append(start + Vector3(cos(a) * (r.barrel_r * 0.6 + 0.012), sin(a) * (r.barrel_r * 0.6 + 0.012), -0.004 - i * 0.004))
			_tube(r.root, points, 0.003, mat("panel", BLUE, Color(0.0, 0.08, 0.25)), 4)
			_rod(r.root, 0.012, 0.012, 0.05, start + Vector3(0, r.barrel_r * 0.6 + 0.024, -0.05), mat("panel", BLUE, Color(0.05, 0.15, 0.4)), 8)
			_rod(r.root, 0.007, 0.007, 0.104, start + Vector3(0, 0, -0.052), mat("panel", BLACK, ZAP * 0.5), 6)
			r.muzzle = start + Vector3(0, 0, -0.104)
		_:
			_generic(r, r.barrel_start.lerp(r.muzzle, 0.5) + Vector3(0, r.barrel_r + 0.008, 0), id)


static func _coil_barrel(r: Rig) -> void:
	var copper := mat("brass", COPPER)
	var length := 0.1
	var start := r.muzzle
	_rod(r.root, 0.008, 0.008, length + 0.01, start + Vector3(0, 0, -length / 2.0), mat("panel", BLACK, ZAP), 6)
	for i in 6:
		_rod(r.root, r.barrel_r * 0.55 + 0.012, r.barrel_r * 0.55 + 0.012, 0.009, start + Vector3(0, 0, -0.008 - i * 0.017), copper, 8)
	_rod(r.root, 0.006, 0.006, length, start + Vector3(0.0, r.barrel_r * 0.55 + 0.014, -length / 2.0), mat("panel", DARK), 4)
	r.muzzle = start + Vector3(0, 0, -length)


## A muzzle part's length in metres (its "length" mod, or a default).
static func _part_len(id: String, fallback: float) -> float:
	var add: Dictionary = Arsenal.part(id).get("+", {})
	return float(add.get("length", fallback * 100.0)) / 100.0


static func _muzzle(r: Rig, id: String) -> void:
	var m := r.muzzle
	var br := maxf(r.barrel_r, 0.008)
	r.device_start = m
	var len := 0.0
	if r.twin > 0.0:
		for sx: float in [-1.0, 1.0]:
			len = _muzzle_device(r, id, m + Vector3(sx * r.twin, 0, 0), br)
	else:
		len = _muzzle_device(r, id, m, br)
	r.device_len = len
	r.muzzle = m + Vector3(0, 0, -len)


## Draws one muzzle device starting at `m` on a barrel of radius `br`; returns its length.
static func _muzzle_device(r: Rig, id: String, m: Vector3, br: float) -> float:
	match id:
		"suppressor":
			# An oil filter on a pipe adapter, hose-clamped on.
			_rod(r.root, br * 1.3, br * 1.3, 0.02, m + Vector3(0, 0, -0.01), mat("panel", DARK), 6)
			var rad := maxf(br * 2.2, 0.018)
			_rod(r.root, rad, rad, 0.13, m + Vector3(0, 0, -0.085), mat("panel", Color(0.25, 0.32, 0.6)), 10)
			_rod(r.root, rad * 1.05, rad * 1.05, 0.03, m + Vector3(0, 0, -0.085), mat("panel", BONE), 10)
			_rod(r.root, rad * 0.8, rad * 0.8, 0.008, m + Vector3(0, 0, -0.152), mat("panel", BLACK), 10)
			return 0.155
		"compensator":
			var size := maxf(br * 2.6, 0.024)
			_box(r.root, Vector3(size, size, 0.045), m + Vector3(0, 0, -0.022), mat("panel", DARK), Vector3.ZERO, 0.004)
			for i in 3:
				_box(r.root, Vector3(size * 0.7, 0.006, 0.006), m + Vector3(0, size / 2.0, -0.01 - i * 0.012), mat("panel", BLACK, FIRE * 0.25), Vector3.ZERO, 0.0)
			return 0.045
		"muzzle_brake":
			# A chunky brake with big side ports.
			var w := maxf(br * 3.4, 0.03)
			_box(r.root, Vector3(w, br * 2.4, 0.06), m + Vector3(0, 0, -0.03), mat("panel", BLACK), Vector3.ZERO, 0.004)
			for i in 3:
				_box(r.root, Vector3(w + 0.002, br * 1.3, 0.008), m + Vector3(0, 0, -0.012 - i * 0.017), mat("panel", DARK, FIRE * 0.12), Vector3.ZERO, 0.0)
			return 0.06
		"flash_hider":
			# A birdcage: a lathed sleeve with open slots.
			_lathe_z(r.root, [Vector2(br * 1.25, -0.05), Vector2(br * 1.55, -0.046), Vector2(br * 1.55, -0.01), Vector2(br * 1.2, 0.0)],
					m, mat("panel", DARK), 6)
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				_box(r.root, Vector3(0.003, 0.003, 0.028), m + Vector3(cos(a) * br * 1.56, sin(a) * br * 1.56, -0.03), mat("panel", BLACK, FIRE * 0.1),
						Vector3(0, 0, rad_to_deg(a)), 0.0)
			return 0.05
		"thread_adapter":
			_rod(r.root, br * 1.25, br * 1.25, 0.02, m + Vector3(0, 0, -0.01), mat("brass"), 8)
			_rod(r.root, br * 1.35, br * 1.35, 0.004, m + Vector3(0, 0, -0.004), mat("panel", DARK), 8)
			return 0.02
		"linear_comp":
			_rod(r.root, br * 2.0, br * 1.6, 0.05, m + Vector3(0, 0, -0.025), mat("panel", DARK), 8)
			_rod(r.root, br * 1.8, br * 1.8, 0.004, m + Vector3(0, 0, -0.05), mat("panel", BLACK, FIRE * 0.1), 8)
			for i in 4:
				var a := TAU * i / 4.0
				_box(r.root, Vector3(0.004, 0.004, 0.006), m + Vector3(cos(a) * br * 1.9, sin(a) * br * 1.9, -0.038), mat("panel", BLACK), Vector3.ZERO, 0.0)
			return 0.05
		"solvent_trap":
			# A torch tube full of freeze plugs, ribbed, gaffer-taped at the joint.
			var rad := maxf(br * 2.0, 0.019)
			_rod(r.root, br * 1.3, br * 1.3, 0.02, m + Vector3(0, 0, -0.01), mat("brass"), 6)
			_rod(r.root, rad, rad, 0.16, m + Vector3(0, 0, -0.1), mat("panel", Color(0.75, 0.78, 0.8)), 8)
			for i in 6:
				_rod(r.root, rad * 1.06, rad * 1.06, 0.004, m + Vector3(0, 0, -0.035 - i * 0.025), mat("panel", DARK), 8)
			_rod(r.root, rad * 1.08, rad * 1.08, 0.02, m + Vector3(0, 0, -0.03), mat("panel", BLACK), 8)
			return 0.18
		"bottle_can":
			# A soda bottle taped over the muzzle, neck first.
			var rad := maxf(br * 2.8, 0.03)
			_lathe_z(r.root, [Vector2(0.0, -0.22), Vector2(rad * 0.8, -0.218), Vector2(rad, -0.2), Vector2(rad, -0.06),
					Vector2(rad * 0.4, -0.02), Vector2(br * 1.4, 0.0), Vector2(0.0, 0.002)], m, mat("panel", Color(0.45, 0.85, 0.55), Color(0.03, 0.1, 0.05)), 8)
			_rod(r.root, rad * 1.04, rad * 1.04, 0.06, m + Vector3(0, 0, -0.13), mat("panel", RED), 8)
			_rod(r.root, br * 1.6, br * 1.6, 0.03, m + Vector3(0, 0, -0.01), mat("panel", TAPE), 6)
			return 0.22
		"choke":
			_rod(r.root, br * 0.9, br * 1.35, 0.055, m + Vector3(0, 0, -0.027), mat("brass"), 8)
			return 0.055
		"duckbill":
			# Flattened into a wide horizontal slot.
			_put(r.root, LowPoly.chamfer_box(Vector3(br * 4.0, br * 0.9, 0.05), 0.002), m + Vector3(0, 0, -0.03), mat("panel", DARK))
			_rod(r.root, br * 1.2, br * 1.2, 0.015, m + Vector3(0, 0, -0.006), mat("panel", DARK), 6)
			return 0.055
		"breacher":
			_rod(r.root, br * 1.5, br * 1.5, 0.03, m + Vector3(0, 0, -0.015), mat("panel", DARK), 8)
			for i in 6:
				var a := TAU * i / 6.0
				_rod(r.root, 0.0, 0.004, 0.016, m + Vector3(cos(a) * br * 1.3, sin(a) * br * 1.3, -0.036), mat("panel", STEEL), 4)
			return 0.044
		"wide_nozzle":
			_lathe_z(r.root, [Vector2(0.0, -0.075), Vector2(0.05, -0.074), Vector2(0.05, -0.068), Vector2(0.022, -0.02), Vector2(0.018, 0.0),
					Vector2(0.0, 0.002)], m, mat("brass", COPPER), 10)
			return 0.075
		"long_nozzle":
			_rod(r.root, 0.012, 0.016, 0.18, m + Vector3(0, 0, -0.09), mat("pipe", Color(1.1, 1.0, 0.95)), 6)
			_rod(r.root, 0.02, 0.014, 0.025, m + Vector3(0, 0, -0.19), mat("brass", COPPER), 8)
			_rod(r.root, 0.017, 0.017, 0.01, m + Vector3(0, 0, -0.07), mat("panel", YELLOW), 6)
			return 0.2
	_generic(r, m + Vector3(0, 0, -0.015), id)
	return 0.03


## A quick-detach can slid over the muzzle device (flash hider, brake, adapter): its back
## collar locks behind the device and it reaches well past it. The Muzzle moves to its end.
static func _silencer(r: Rig, id: String) -> void:
	var back: Vector3 = r.device_start if r.device_start != Vector3.INF else r.muzzle
	var br := maxf(r.barrel_r, 0.008)
	var length := maxf(_part_len(id, 0.14), r.device_len + 0.04)
	var rad := maxf(br * 2.3, 0.02)
	var body := mat("panel", BLACK)
	var cap := mat("panel", DARK)
	match id:
		"can_light":
			body = mat("panel", Color(0.22, 0.22, 0.24))
		"can_heavy":
			rad = maxf(br * 2.8, 0.025)
			body = mat("panel", OD)
		"can_titanium":
			rad = maxf(br * 2.1, 0.018)
			body = mat("panel", Color(0.55, 0.6, 0.75))
		"can_wet":
			body = mat("panel", Color(0.3, 0.34, 0.4))
		_:
			body = mat("panel", Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.3, 0.5))
	if r.twin > 0.0:
		rad = minf(rad, r.twin * 0.98)
	var xs: Array = [0.0] if r.twin <= 0.0 else [-r.twin, r.twin]
	for x: float in xs:
		var b := back + Vector3(x, 0, 0)
		_rod(r.root, rad, rad, length, b + Vector3(0, 0, -length / 2.0), body, 10)
		_rod(r.root, rad * 1.08, rad * 1.08, 0.016, b + Vector3(0, 0, -0.008), cap, 10)
		_rod(r.root, rad * 0.75, rad, 0.008, b + Vector3(0, 0, -length - 0.004), cap, 10)
		match id:
			"can_light":
				_box(r.root, Vector3(0.006, 0.008, 0.012), b + Vector3(rad, 0, -0.01), mat("panel", STEEL), Vector3.ZERO, 0.001)
			"can_heavy":
				_rod(r.root, rad * 1.03, rad * 1.03, 0.04, b + Vector3(0, 0, -length * 0.55), mat("panel", TAPE), 10)
				_box(r.root, Vector3(0.008, 0.01, 0.014), b + Vector3(rad, 0, -0.01), mat("panel", BLACK), Vector3.ZERO, 0.001)
			"can_titanium":
				for i in 3:
					_rod(r.root, rad * 1.02, rad * 1.02, 0.003, b + Vector3(0, 0, -0.03 - i * 0.015), mat("panel", BLUE), 10)
			"can_wet":
				_rod(r.root, 0.005, 0.005, 0.012, b + Vector3(0, rad + 0.004, -length * 0.5), mat("panel", BLUE), 6, Vector3.ZERO)
				_ball(r.root, 0.004, b + Vector3(0, -rad - 0.003, -length + 0.02), mat("panel", BLUE, Color(0.05, 0.12, 0.3)), Vector3(1, 1.5, 1))
	r.muzzle = Vector3(0, back.y, back.z - length - 0.008)


## Gas parts: a cue on the gas block. Under a handguard the knob or rod sticks out the side.
static func _gas(r: Rig, id: String) -> void:
	var g := r.gas
	var br := maxf(r.barrel_r, 0.008)
	var out := r.hg_r + 0.006
	match id:
		"adjustable_gas":
			_rod(r.root, br * 1.9, br * 1.9, 0.026, g, mat("panel", DARK), 6)
			_rod_between(r.root, g, g + Vector3(-out, 0, 0), 0.004, mat("panel", STEEL))
			var knob := _disc_x(r.root, 0.009, 0.006, g + Vector3(-out, 0, 0), mat("panel", RED), 6)
			knob.rotation_degrees.x = float(r.tune.get("gas", 0.0)) * 60.0
			_box(r.root, Vector3(0.007, 0.002, 0.012), g + Vector3(-out - 0.0035, 0, 0), mat("panel", BONE), Vector3(float(r.tune.get("gas", 0.0)) * 60.0, 0, 0), 0.0)
		"low_profile_gas":
			_rod(r.root, br * 1.5, br * 1.5, 0.018, g, mat("panel", BLACK), 6)
			_box(r.root, Vector3(0.005, 0.004, 0.006), g + Vector3(0, -br * 1.5, 0), mat("panel", STEEL), Vector3.ZERO, 0.0)
		"piston_kit":
			_box(r.root, Vector3(br * 2.6, br * 3.4, 0.032), g + Vector3(0, br * 0.6, 0), mat("panel", STEEL), Vector3.ZERO, 0.003)
			_rod(r.root, br * 0.9, br * 0.9, 0.02, g + Vector3(0, br * 1.5, -0.02), mat("panel", NICKEL), 6)
			_box(r.root, Vector3(0.006, 0.008, 0.05), g + Vector3(out - 0.002, 0, 0.03), mat("panel", NICKEL), Vector3.ZERO, 0.001)
		_:
			_generic(r, g, id)


## A handguard round the barrel from hg_start, bringing its own rail, grip and underbarrel spots.
static func _handguard(r: Rig, id: String) -> void:
	var a := r.hg_start
	var b := r.hg_end
	var y := r.hg_y
	var hr := r.hg_r
	var black := mat("panel", BLACK)
	var outer := hr
	match id:
		"short_handguard":
			b = lerpf(a, b, 0.62)
			_rod(r.root, hr, hr, absf(b - a), Vector3(0, y, (a + b) / 2.0), mat("panel", DARK), 8)
			_mlok(r, a, b, y, hr)
			_pic(r, Vector3(0, y + hr * 0.92, (a + b) / 2.0), absf(b - a) - 0.01)
		"long_handguard":
			b = minf(b, lerpf(a, r.muzzle.z, 0.82))
			_rod(r.root, hr + 0.002, hr + 0.002, absf(b - a), Vector3(0, y, (a + b) / 2.0), mat("panel", TAN), 8)
			_mlok(r, a, b, y, hr + 0.002)
			_pic(r, Vector3(0, y + hr * 0.94, (a + b) / 2.0), absf(b - a) - 0.01)
			outer = hr + 0.002
		"quad_rail":
			var len := absf(b - a)
			_box(r.root, Vector3(hr * 1.8, hr * 1.8, len), Vector3(0, y, (a + b) / 2.0), mat("panel", DARK), Vector3(0, 0, 0), 0.006)
			for roll: float in [0.0, 90.0, -90.0, 180.0]:
				var dir := Vector3(0, 1, 0).rotated(Vector3(0, 0, 1), deg_to_rad(roll))
				_pic(r, Vector3(0, y, (a + b) / 2.0) + dir * hr * 0.9, len - 0.006, roll, 0.019)
			_box(r.root, Vector3(hr * 1.9, hr * 1.9, 0.012), Vector3(0, y, a - 0.006), black, Vector3.ZERO, 0.002)
			outer = hr * 0.9 + 0.007
		"wood_handguard":
			_rod(r.root, hr + 0.003, hr + 0.003, absf(b - a), Vector3(0, y, (a + b) / 2.0), mat("wood", WOOD), 8)
			for z: float in [a - 0.006, b + 0.006]:
				_rod(r.root, hr + 0.004, hr + 0.004, 0.008, Vector3(0, y, z), mat("brass", COPPER), 8)
			for i in 4:
				_box(r.root, Vector3(0.003, 0.012, 0.014), Vector3(-(hr + 0.003), y, lerpf(a, b, 0.2 + i * 0.2)), black, Vector3.ZERO, 0.0)
			outer = hr + 0.003
		"heatshield":
			_rod(r.root, hr + 0.002, hr + 0.002, absf(b - a), Vector3(0, y, (a + b) / 2.0), mat("grate", Color(1.4, 1.4, 1.45)), 10)
			for z: float in [a, b, (a + b) / 2.0]:
				_rod(r.root, hr + 0.004, hr + 0.004, 0.008, Vector3(0, y, z), mat("panel", DARK), 10)
			_pic(r, Vector3(0, y + hr * 0.95, lerpf(a, b, 0.25)), absf(b - a) * 0.4)
			outer = hr + 0.002
		"pump_rail":
			# A pump with a short rail down the left and a grip spot underneath.
			var len := absf(b - a)
			_box(r.root, Vector3(hr * 2.1, hr * 2.0, len), Vector3(0, y, (a + b) / 2.0), black, Vector3.ZERO, 0.006)
			for i in 5:
				_box(r.root, Vector3(hr * 2.15, 0.004, 0.006), Vector3(0, y - hr * 0.5, a - 0.015 - i * len / 6.0), mat("panel", DARK), Vector3.ZERO, 0.0)
			_pic(r, Vector3(-hr * 1.05, y, (a + b) / 2.0), len - 0.02, 90.0, 0.018)
			_pic(r, Vector3(0, y - hr, (a + b) / 2.0), len - 0.02, 180.0, 0.018)
			outer = hr * 1.05 + 0.007
		_:
			_rod(r.root, hr + 0.002, hr + 0.002, absf(b - a), Vector3(0, y, (a + b) / 2.0), mat("panel", Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.3, 0.6)), 8)
			_rod(r.root, hr + 0.004, hr + 0.004, 0.03, Vector3(0, y, lerpf(a, b, 0.5)), mat("panel", TAPE), 8)
	r.hg_end = b
	r.rail_l = Vector3(-(outer + 0.001), y, lerpf(a, b, 0.62))
	r.rail_r = Vector3(outer + 0.001, y, lerpf(a, b, 0.62))
	r.foregrip = Vector3(0, y - outer, lerpf(a, b, 0.42))
	r.under = Vector3(0, y - outer, lerpf(a, b, 0.92))


## M-LOK slots down both sides and the bottom of a handguard tube.
static func _mlok(r: Rig, a: float, b: float, y: float, hr: float) -> void:
	var count := int(absf(b - a) / 0.045)
	for i in count:
		var z := lerpf(a, b, (i + 0.5) / count)
		for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, -1, 0)]:
			var size := Vector3(0.003, 0.007, 0.022) if d.y == 0.0 else Vector3(0.007, 0.003, 0.022)
			_box(r.root, size, Vector3(0, y, z) + d * hr * 0.97, mat("panel", BLACK), Vector3.ZERO, 0.0)


## Rail accessories: they clamp to the left or right rail and stick out sideways (or hang
## under a pistol's dust cover).
static func _rail_part(r: Rig, slot: String, id: String) -> void:
	var a: Vector3 = r.rail_l if slot == "rail_l" else r.rail_r
	if slot == "rail_r" and r.rail_r.x == 0.0 and r.rail_l.x == 0.0:
		a += Vector3(0, -0.02, 0)
	var side := absf(a.x) > 0.001
	var dir := Vector3(signf(a.x), 0, 0) if side else Vector3(0, -1, 0)
	var clamp_size := Vector3(0.008, 0.016, 0.022) if side else Vector3(0.016, 0.008, 0.022)
	_box(r.root, clamp_size, a + dir * 0.004, mat("panel", DARK), Vector3.ZERO, 0.002)
	var c := a + dir * 0.017
	match id:
		"flashlight":
			_rod(r.root, 0.011, 0.011, 0.07, c + Vector3(0, 0, 0.008), mat("panel", Color(0.75, 0.6, 0.2)), 8)
			_rod(r.root, 0.015, 0.012, 0.024, c + Vector3(0, 0, -0.038), mat("panel", BLACK), 8)
			_rod(r.root, 0.013, 0.013, 0.003, c + Vector3(0, 0, -0.051), mat("panel", BONE, Color(1.0, 0.95, 0.7)), 8)
			_rod(r.root, 0.0115, 0.0115, 0.015, c + Vector3(0, 0, 0.02), mat("panel", TAPE), 8)
		"laser":
			_box(r.root, Vector3(0.02, 0.018, 0.05), c, mat("panel", Color(0.55, 0.15, 0.15)), Vector3.ZERO, 0.004)
			_rod(r.root, 0.005, 0.005, 0.004, c + Vector3(0, 0, -0.026), mat("panel", BLACK, Color(1.0, 0.05, 0.05)), 6)
		"laser_ir":
			_box(r.root, Vector3(0.022, 0.02, 0.055), c, mat("panel", OD), Vector3.ZERO, 0.004)
			_rod(r.root, 0.007, 0.007, 0.006, c + Vector3(0, 0, -0.03), mat("panel", BLACK, Color(0.18, 0.0, 0.08)), 6)
			_box(r.root, Vector3(0.008, 0.006, 0.01), c + Vector3(0, 0.012, 0.012), mat("panel", BLACK), Vector3.ZERO, 0.001)
		"combo_light":
			_box(r.root, Vector3(0.026, 0.026, 0.065), c + dir * 0.003, mat("panel", TAN), Vector3.ZERO, 0.005)
			_rod(r.root, 0.009, 0.009, 0.003, c + dir * 0.003 + Vector3(0, 0.004, -0.033), mat("panel", BONE, Color(1.0, 0.95, 0.7)), 8)
			_rod(r.root, 0.003, 0.003, 0.003, c + dir * 0.003 + Vector3(0, -0.008, -0.033), mat("panel", BLACK, Color(1.0, 0.05, 0.05)), 6)
		"strobe_light":
			_rod(r.root, 0.012, 0.012, 0.075, c + Vector3(0, 0, 0.006), mat("panel", BLACK), 8)
			_rod(r.root, 0.017, 0.013, 0.026, c + Vector3(0, 0, -0.042), mat("panel", DARK), 8)
			_rod(r.root, 0.015, 0.015, 0.003, c + Vector3(0, 0, -0.056), mat("panel", BONE, Color(0.85, 0.9, 1.2)), 8)
			_rod(r.root, 0.0125, 0.0125, 0.008, c + Vector3(0, 0, 0.0), mat("panel", BLUE, Color(0.05, 0.1, 0.5)), 8)
			for i in 4:
				var ang := TAU * i / 4.0
				_box(r.root, Vector3(0.004, 0.004, 0.006), c + Vector3(cos(ang), sin(ang), 0) * 0.016 + Vector3(0, 0, -0.056), mat("panel", DARK), Vector3.ZERO, 0.0)
		"rail_counter":
			_box(r.root, Vector3(0.016, 0.018, 0.03), c - dir * 0.005, mat("panel", BLACK), Vector3.ZERO, 0.003)
			_box(r.root, Vector3(0.012, 0.004, 0.02), c - dir * 0.005 + Vector3(0, 0.009, 0.002), mat("panel", BLACK, Color(0.2, 0.9, 0.3)), Vector3.ZERO, 0.0)
		_:
			_generic(r, c, id)


## Foregrips and bipods hang from the bottom of the handguard.
static func _foregrip(r: Rig, id: String) -> void:
	var f := r.foregrip
	var black := mat("panel", BLACK)
	_box(r.root, Vector3(0.016, 0.006, 0.024), f + Vector3(0, -0.003, 0), mat("panel", DARK), Vector3.ZERO, 0.001)
	match id:
		"vertical_grip":
			_rod(r.root, 0.011, 0.013, 0.08, f + Vector3(0, -0.045, 0), black, 8, Vector3.ZERO)
			for i in 3:
				_rod(r.root, 0.0135, 0.0135, 0.004, f + Vector3(0, -0.025 - i * 0.02, 0), mat("panel", DARK), 8, Vector3.ZERO)
			_rod(r.root, 0.012, 0.012, 0.006, f + Vector3(0, -0.087, 0), mat("panel", TAN), 8, Vector3.ZERO)
		"angled_grip":
			_profile(r.root, [Vector2(0.035, 0.0), Vector2(-0.06, 0.0), Vector2(-0.045, -0.012), Vector2(0.02, -0.042),
					Vector2(0.036, -0.036)], 0.022, f + Vector3(0, -0.006, 0), mat("panel", TAN))
		"stubby_grip":
			_rod(r.root, 0.011, 0.012, 0.04, f + Vector3(0, -0.025, 0), black, 8, Vector3.ZERO)
		"handstop":
			_profile(r.root, [Vector2(0.014, 0.0), Vector2(-0.014, 0.0), Vector2(0.006, -0.022), Vector2(0.016, -0.02)], 0.018,
					f + Vector3(0, -0.006, 0), black)
		"bipod", "grip_pod":
			var big := float(Arsenal.frame(r.frame).get("length", 80.0)) / 100.0
			var leg := clampf(big * 0.2, 0.1, 0.3)
			if id == "grip_pod":
				_rod(r.root, 0.012, 0.013, 0.085, f + Vector3(0, -0.048, 0), black, 8, Vector3.ZERO)
				leg = 0.035
				f += Vector3(0, -0.085, 0)
			else:
				_box(r.root, Vector3(0.03, 0.016, 0.024), f + Vector3(0, -0.012, 0), black, Vector3.ZERO, 0.003)
				f += Vector3(0, -0.016, 0)
			# Two legs splayed out and forward, with feet.
			for sx: float in [-1.0, 1.0]:
				var foot := f + Vector3(sx * leg * 0.45, -leg * 0.85, -leg * 0.3)
				_rod_between(r.root, f + Vector3(sx * 0.008, 0, 0), foot, 0.004 if id == "grip_pod" else 0.0055, mat("panel", DARK))
				_rod_between(r.root, (f + Vector3(sx * 0.008, 0, 0)).lerp(foot, 0.55), foot, 0.0042, mat("panel", STEEL))
				_box(r.root, Vector3(0.01, 0.006, 0.012), foot, black, Vector3.ZERO, 0.002)
		_:
			_generic(r, f + Vector3(0, -0.015, 0), id)


static func _underbarrel(r: Rig, id: String) -> void:
	var u := r.under
	match id:
		"bayonet", "spike_bayonet":
			# The lug clamps round the barrel just behind the bare muzzle (or at the handguard tip).
			var mount := Vector3(u.x, u.y, minf(u.z, r.barrel_end.z + 0.07))
			var lug_h := maxf(r.barrel_end.y - mount.y, 0.0) + 0.016
			_box(r.root, Vector3(0.012, lug_h, 0.03), Vector3(0, mount.y + lug_h / 2.0 - 0.01, mount.z), mat("panel", DARK))
			var blade_start := mount + Vector3(0, -0.006, -0.02)
			var reach := clampf(blade_start.z - r.barrel_end.z + 0.09, 0.1, 0.2)
			if id == "bayonet":
				_profile(r.root, [Vector2(0.0, 0.006), Vector2(reach * 0.85, 0.006), Vector2(reach, 0.0), Vector2(reach * 0.8, -0.012),
						Vector2(0.0, -0.01)], 0.004, blade_start, mat("panel", Color(0.9, 0.93, 0.98)))
			else:
				reach = clampf(blade_start.z - r.barrel_end.z + 0.2, 0.2, 0.32)
				_rod(r.root, 0.0, 0.006, reach, blade_start + Vector3(0, 0, -reach / 2.0), mat("panel", Color(0.8, 0.84, 0.9)), 3)
				_rod(r.root, 0.008, 0.008, 0.012, blade_start + Vector3(0, 0, -0.004), mat("panel", BLACK), 6)
		"chainsaw_bayonet":
			# A little two-stroke motor under the barrel with its bar and chain sticking forward.
			var body := u + Vector3(0, -0.028, 0.05)
			_box(r.root, Vector3(0.032, 0.04, 0.07), body, mat("panel", ORANGE), Vector3.ZERO, 0.006)
			_box(r.root, Vector3(0.02, 0.012, 0.04), body + Vector3(0, 0.026, 0), mat("panel", DARK), Vector3.ZERO, 0.002)
			_rod(r.root, 0.006, 0.006, 0.04, body + Vector3(0.019, 0, 0), mat("grate", Color(1.3, 1.3, 1.3)), 6)
			var bar_len := clampf(body.z - r.barrel_end.z - 0.02, 0.14, 0.24)
			var bar := body + Vector3(0, -0.004, -0.035 - bar_len / 2.0)
			_box(r.root, Vector3(0.006, 0.026, bar_len), bar, mat("panel", STEEL), Vector3.ZERO, 0.004)
			var teeth := int(bar_len / 0.012)
			for i in teeth:
				for sy: float in [-1.0, 1.0]:
					_box(r.root, Vector3(0.008, 0.005, 0.006), bar + Vector3(0, sy * 0.015, -bar_len / 2.0 + (i + 0.5) * bar_len / teeth),
							mat("panel", DARK), Vector3.ZERO, 0.0)
		"riot_shield":
			# A small plate hung under the barrel, with a slot to see through.
			var c := u + Vector3(0, -0.08, 0.0)
			_box(r.root, Vector3(0.2, 0.16, 0.01), c, mat("panel", Color(0.3, 0.32, 0.36)), Vector3(-6, 0, 0), 0.004)
			_box(r.root, Vector3(0.21, 0.02, 0.012), c + Vector3(0, 0.06, 0), mat("panel", YELLOW), Vector3(-6, 0, 0), 0.002)
			_box(r.root, Vector3(0.21, 0.012, 0.013), c + Vector3(0, 0.06, 0), mat("panel", BLACK), Vector3(-6, 0, 0), 0.0)
			_box(r.root, Vector3(0.012, 0.03, 0.03), u + Vector3(0, -0.008, 0.012), mat("panel", DARK), Vector3.ZERO, 0.002)
		_:
			_generic(r, u + Vector3(0, -0.012, 0), id)


## Offset and backup sights on the top rail; risers and cantilevers move the main sight.
static func _mount(r: Rig, id: String) -> void:
	var m := r.mount
	var dark := mat("panel", DARK)
	match id:
		"canted_dot":
			# A mini dot rolled 45° to the right, on its own little arm.
			_box(r.root, Vector3(0.022, 0.008, 0.024), m + Vector3(0, 0.004, 0), dark, Vector3.ZERO, 0.001)
			var arm := m + Vector3(0.014, 0.012, 0)
			_box(r.root, Vector3(0.024, 0.006, 0.02), arm, dark, Vector3(0, 0, -45), 0.001)
			var c := m + Vector3(0.026, 0.024, 0)
			_box(r.root, Vector3(0.02, 0.012, 0.028), c, mat("panel", BLACK), Vector3(0, 0, -45), 0.003)
			_box(r.root, Vector3(0.018, 0.016, 0.004), c + Vector3(0.006, 0.006, -0.01), mat("panel", BLACK), Vector3(0, 0, -45), 0.001)
			_box(r.root, Vector3(0.013, 0.011, 0.002), c + Vector3(0.006, 0.006, -0.013), mat("panel", GLASS, Color(0.3, 0.05, 0.05)), Vector3(0, 0, -45), 0.0)
		"backup_irons":
			# Two little flip-ups folded flat, one at each end of the rail.
			for z: float in [0.0, 1.0]:
				var at := m if z == 0.0 else r.top + Vector3(0, 0, 0.05)
				_box(r.root, Vector3(0.02, 0.008, 0.024), at + Vector3(0, 0.004, 0), dark, Vector3.ZERO, 0.001)
				_box(r.root, Vector3(0.016, 0.004, 0.022), at + Vector3(0, 0.011, 0.004 if z == 0.0 else -0.004), mat("panel", BLACK),
						Vector3(-8.0 if z == 0.0 else 8.0, 0, 0), 0.0)
				_box(r.root, Vector3(0.004, 0.004, 0.004), at + Vector3(0, 0.014, 0.0), mat("panel", BONE), Vector3.ZERO, 0.0)
		"cantilever":
			_box(r.root, Vector3(0.026, 0.01, 0.05), r.top + Vector3(0, 0.005, 0.01), dark, Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.022, 0.008, 0.07), r.top + Vector3(0, 0.014, -0.025), dark, Vector3.ZERO, 0.002)
			r.top += Vector3(0, 0.012, -0.04)
		"riser":
			_box(r.root, Vector3(0.024, 0.02, 0.06), r.top + Vector3(0, 0.01, 0), dark, Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.026, 0.005, 0.03), r.top + Vector3(0, 0.012, 0), mat("panel", ORANGE), Vector3.ZERO, 0.001)
			r.top += Vector3(0, 0.02, 0)
		_:
			_generic(r, m + Vector3(0.015, 0.01, 0), id)


static func _sight(r: Rig, id: String) -> void:
	var t := r.top
	var dark := mat("panel", BLACK)
	var lens := mat("panel", GLASS, Color(0.1, 0.25, 0.4))
	if id != "pistol_dot":
		_box(r.root, Vector3(0.018, 0.008, 0.07), t + Vector3(0, 0.004, 0), mat("panel", DARK), Vector3.ZERO, 0.002)
	match id:
		"red_dot":
			_box(r.root, Vector3(0.03, 0.012, 0.045), t + Vector3(0, 0.014, 0), dark, Vector3.ZERO, 0.004)
			_box(r.root, Vector3(0.03, 0.03, 0.006), t + Vector3(0, 0.032, -0.016), dark, Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.022, 0.022, 0.002), t + Vector3(0, 0.032, -0.02), mat("panel", Color(0.3, 0.1, 0.1), Color(0.35, 0.02, 0.02)), Vector3.ZERO, 0.0)
			_ball(r.root, 0.0035, t + Vector3(0, 0.032, -0.022), mat("panel", BLACK, Color(1.0, 0.1, 0.05)))
			_box(r.root, Vector3(0.008, 0.008, 0.012), t + Vector3(0.018, 0.02, 0.005), mat("panel", RED))
		"peep_sight":
			_box(r.root, Vector3(0.008, 0.024, 0.012), t + Vector3(0, 0.018, 0.02), mat("panel", DARK), Vector3.ZERO, 0.002)
			_tube(r.root, _ring(t + Vector3(0, 0.034, 0.02), 0.008, 8), 0.0028, mat("panel", DARK), 4)
		"pistol_dot":
			# A mini dot screwed straight to the slide: a sloped hood round a small window.
			_box(r.root, Vector3(0.022, 0.008, 0.032), t + Vector3(0, 0.004, 0), dark, Vector3.ZERO, 0.002)
			_profile(r.root, [Vector2(0.012, 0.0), Vector2(0.016, 0.0), Vector2(0.012, 0.02), Vector2(0.008, 0.02)], 0.022,
					t + Vector3(0, 0.006, 0), dark)
			_box(r.root, Vector3(0.016, 0.014, 0.002), t + Vector3(0, 0.017, -0.009), mat("panel", Color(0.3, 0.1, 0.1), Color(0.3, 0.02, 0.02)), Vector3.ZERO, 0.0)
			_ball(r.root, 0.0025, t + Vector3(0, 0.017, -0.01), mat("panel", BLACK, Color(1.0, 0.1, 0.05)))
		"holo":
			# A box with a big window under a hood, buttons at the back.
			_box(r.root, Vector3(0.036, 0.016, 0.07), t + Vector3(0, 0.016, 0.002), mat("panel", DARK), Vector3.ZERO, 0.004)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.004, 0.034, 0.04), t + Vector3(sx * 0.016, 0.04, -0.012), dark, Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.036, 0.004, 0.044), t + Vector3(0, 0.058, -0.012), dark, Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.028, 0.03, 0.002), t + Vector3(0, 0.04, -0.03), mat("panel", Color(0.3, 0.25, 0.15), Color(0.25, 0.08, 0.02)), Vector3.ZERO, 0.0)
			_tube(r.root, _ring(t + Vector3(0, 0.04, -0.032), 0.007, 8), 0.0012, mat("panel", BLACK, Color(1.0, 0.15, 0.05)), 3)
			for i in 2:
				_box(r.root, Vector3(0.006, 0.004, 0.006), t + Vector3(-0.006 + i * 0.012, 0.025, 0.03), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"acog":
			# A short fat prism scope with a glowing fibre on top.
			var c := t + Vector3(0, 0.032, 0.0)
			_box(r.root, Vector3(0.024, 0.02, 0.05), t + Vector3(0, 0.016, 0.0), mat("panel", DARK), Vector3.ZERO, 0.003)
			_lathe_z(r.root, [Vector2(0.0, -0.05), Vector2(0.02, -0.05), Vector2(0.021, -0.03), Vector2(0.015, -0.01),
					Vector2(0.015, 0.03), Vector2(0.013, 0.045), Vector2(0.0, 0.046)], c, mat("panel", TAN), 8)
			_rod(r.root, 0.018, 0.018, 0.003, c + Vector3(0, 0, -0.05), lens, 8)
			_rod(r.root, 0.003, 0.003, 0.04, c + Vector3(0, 0.018, 0.0), mat("panel", OLIVE, Color(0.25, 0.6, 0.1)), 4)
		"scope":
			var c := t + Vector3(0, 0.03, 0.0)
			for z: float in [-0.025, 0.025]:
				_box(r.root, Vector3(0.012, 0.024, 0.012), t + Vector3(0, 0.016, z), mat("panel", DARK))
			_rod(r.root, 0.012, 0.012, 0.1, c, dark, 8)
			_rod(r.root, 0.021, 0.013, 0.045, c + Vector3(0, 0, -0.07), dark, 8)
			_rod(r.root, 0.016, 0.012, 0.03, c + Vector3(0, 0, 0.06), dark, 8)
			_rod(r.root, 0.019, 0.019, 0.003, c + Vector3(0, 0, -0.093), lens, 8)
			_rod(r.root, 0.007, 0.007, 0.012, c + Vector3(0, 0.016, 0), mat("panel", DARK), 6, Vector3.ZERO)
			_disc_x(r.root, 0.007, 0.012, c + Vector3(0.016, 0, 0), mat("panel", DARK), 6)
			# A strip of tape where the scope was taped on a bit crooked.
			_box(r.root, Vector3(0.03, 0.03, 0.012), c + Vector3(0, -0.005, 0.03), mat("panel", TAPE), Vector3(0, 0, 8), 0.004)
		"variable_scope":
			# A long LPVO: big objective, turrets, a magnification ring and its throw lever.
			var c := t + Vector3(0, 0.032, 0.0)
			for z: float in [-0.03, 0.03]:
				_box(r.root, Vector3(0.026, 0.026, 0.014), t + Vector3(0, 0.017, z), mat("panel", DARK), Vector3.ZERO, 0.003)
			_rod(r.root, 0.0125, 0.0125, 0.12, c, dark, 10)
			_rod(r.root, 0.02, 0.013, 0.04, c + Vector3(0, 0, -0.078), dark, 10)
			_rod(r.root, 0.017, 0.017, 0.004, c + Vector3(0, 0, -0.099), lens, 10)
			_rod(r.root, 0.016, 0.013, 0.035, c + Vector3(0, 0, 0.074), dark, 10)
			_rod(r.root, 0.0165, 0.0165, 0.01, c + Vector3(0, 0, 0.065), mat("panel", ORANGE), 10)
			var zoom := float(r.tune.get("sight", 0.0))
			var lever := Vector3(0.02, 0.0, 0).rotated(Vector3(0, 0, 1), deg_to_rad(20.0 + zoom * 60.0))
			_rod_between(r.root, c + Vector3(0, 0, 0.065), c + lever + Vector3(0, 0, 0.065), 0.0025, mat("panel", BLACK))
			_rod(r.root, 0.007, 0.007, 0.014, c + Vector3(0, 0.017, -0.005), mat("panel", DARK), 8, Vector3.ZERO)
			_disc_x(r.root, 0.007, 0.014, c + Vector3(0.017, 0, -0.005), mat("panel", DARK), 8)
		"thermal":
			var c := t + Vector3(0, 0.03, 0.0)
			_box(r.root, Vector3(0.042, 0.044, 0.09), c, mat("panel", Color(0.42, 0.48, 0.38)), Vector3.ZERO, 0.008)
			_rod(r.root, 0.02, 0.02, 0.02, c + Vector3(0, 0, -0.055), dark, 8)
			_rod(r.root, 0.016, 0.016, 0.003, c + Vector3(0, 0, -0.066), mat("panel", Color(0.3, 0.1, 0.05), Color(0.6, 0.15, 0.02)), 8)
			_box(r.root, Vector3(0.032, 0.026, 0.003), c + Vector3(0, 0.002, 0.046), mat("panel", BLACK, Color(1.0, 0.45, 0.05)), Vector3.ZERO, 0.0)
			_box(r.root, Vector3(0.01, 0.006, 0.01), c + Vector3(0.016, 0.025, 0.02), mat("panel", RED, Color(0.6, 0.0, 0.0)), Vector3.ZERO, 0.0)
			_tube(r.root, [c + Vector3(-0.021, -0.01, 0.03), c + Vector3(-0.03, -0.03, 0.05), r.side * Vector3(-1, 1, 1) + Vector3(0, 0, 0.06)],
					0.003, mat("panel", BLACK), 4)
		"night_vision":
			# An olive tube with an IR torch on the side and the eyepiece glowing green.
			var c := t + Vector3(0, 0.032, 0.0)
			_box(r.root, Vector3(0.024, 0.024, 0.06), t + Vector3(0, 0.016, 0), mat("panel", DARK), Vector3.ZERO, 0.003)
			_rod(r.root, 0.02, 0.02, 0.1, c, mat("panel", OD), 8)
			_rod(r.root, 0.024, 0.02, 0.025, c + Vector3(0, 0, -0.06), mat("panel", OD), 8)
			_rod(r.root, 0.021, 0.021, 0.003, c + Vector3(0, 0, -0.073), lens, 8)
			_rod(r.root, 0.014, 0.014, 0.003, c + Vector3(0, 0, 0.051), mat("panel", BLACK, Color(0.2, 0.9, 0.2)), 8)
			_rod(r.root, 0.008, 0.008, 0.05, c + Vector3(-0.028, -0.004, -0.02), mat("panel", BLACK), 6)
			_rod(r.root, 0.007, 0.007, 0.003, c + Vector3(-0.028, -0.004, -0.046), mat("panel", BLACK, Color(0.25, 0.0, 0.05)), 6)
			_box(r.root, Vector3(0.012, 0.006, 0.01), c + Vector3(-0.018, -0.004, -0.02), mat("panel", DARK), Vector3.ZERO, 0.0)
		_:
			_generic(r, t + Vector3(0, 0.02, 0), id)


## A grip part where the frame's pistol grip was.
static func _grip_part(r: Rig, id: String) -> void:
	var top := r.grip_top
	var size := r.grip_size
	var rake := r.grip_rake
	var down := _grip_down(rake)
	var fwd := Vector3(0, 0, -1).rotated(Vector3(1, 0, 0), deg_to_rad(rake))
	match id:
		"rubber_grip":
			_grip_shape(r, top, mat("panel", BLACK), size, rake, false)
			for i in 3:
				_ball(r.root, size.x * 0.42, top + down * size.y * (0.25 + i * 0.25) + fwd * size.z * 0.48, mat("panel", BLACK), Vector3(1.05, 0.7, 0.6))
		"skeleton_grip":
			var a := top + fwd * size.z * 0.4
			var b := top - fwd * size.z * 0.4
			var m := mat("panel", DARK)
			_tube(r.root, [a, a + down * size.y, b + down * size.y, b], 0.005, m, 5)
			_box(r.root, Vector3(size.x, 0.012, size.z), top + down * 0.006, m, Vector3(rake, 0, 0), 0.002)
			_rod_between(r.root, a + down * size.y * 0.5, b + down * size.y * 0.5, 0.004, m)
		"wood_grip":
			_grip_shape(r, top, mat("wood", WOOD), size + Vector3(0.002, 0.0, 0.002), rake, false)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.002, size.y * 0.55, size.z * 0.55), top + down * size.y * 0.5 + Vector3(sx * (size.x * 0.5 + 0.001), 0, 0),
						mat("wood", Color(0.75, 0.55, 0.4)), Vector3(rake, 0, 0), 0.0)
		"tape_grip":
			_grip_shape(r, top, mat("panel", DARK), size, rake, false)
			var colours := [TAPE, RED, TAPE, YELLOW, TAPE]
			for i in colours.size():
				_box(r.root, Vector3(size.x + 0.004, size.y / 6.0, size.z + 0.004), top + down * size.y * (0.12 + i * 0.18),
						mat("panel", colours[i]), Vector3(rake + (i % 2) * 6.0 - 3.0, 0, 0), 0.002)
		"stippled_grip":
			_grip_shape(r, top, mat("concrete", Color(0.42, 0.4, 0.38)), size, rake, false)
		_:
			_grip_shape(r, top, mat("panel", Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.35, 0.55)), size, rake, true)


## Trigger groups: a different blade in the guard and a cue on the selector.
static func _trigger_part(r: Rig, id: String) -> void:
	var t := r.trig
	var side := Vector3(r.body_w + 0.002, 0.03, 0.015) + Vector3(0, t.y, t.z)
	match id:
		"match_trigger":
			_box(r.root, Vector3(0.008, 0.02, 0.006), t + Vector3(0, 0, -0.002), mat("panel", RED), Vector3(-5, 0, 0), 0.001)
			_rod(r.root, 0.002, 0.002, 0.008, t + Vector3(0, 0.012, 0.004), mat("panel", NICKEL), 4, Vector3(float(r.tune.get("trigger", 0.0)) * 30.0, 0, 0))
		"auto_sear":
			_box(r.root, Vector3(0.004, 0.012, 0.012), side, mat("panel", NICKEL), Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.003, 0.006, 0.02), side + Vector3(0.002, -0.012, 0.0), mat("panel", ORANGE), Vector3(25, 0, 0), 0.0)
		"burst_group":
			_box(r.root, Vector3(0.003, 0.006, 0.02), side + Vector3(0.002, -0.012, 0.0), mat("panel", YELLOW), Vector3(-25, 0, 0), 0.0)
			for i in 3:
				_box(r.root, Vector3(0.003, 0.003, 0.003), side + Vector3(0.002, -0.002, -0.01 + i * 0.006), mat("panel", YELLOW), Vector3.ZERO, 0.0)
		"binary_trigger":
			_box(r.root, Vector3(0.008, 0.022, 0.007), t + Vector3(0, 0, -0.001), mat("panel", BLUE), Vector3(-15, 0, 0), 0.001)
		"hair_trigger":
			_box(r.root, Vector3(0.004, 0.024, 0.004), t + Vector3(0, -0.002, -0.004), mat("panel", NICKEL), Vector3(-25, 0, 0), 0.0)
			_rod(r.root, 0.002, 0.002, 0.01, t + Vector3(0, 0.012, 0.006), mat("panel", YELLOW), 4, Vector3.ZERO)
		"double_set":
			_box(r.root, Vector3(0.006, 0.02, 0.006), t + Vector3(0, 0.0, 0.012), mat("brass"), Vector3(-10, 0, 0), 0.001)
			_box(r.root, Vector3(0.0065, 0.022, 0.007), t, mat("brass"), Vector3(-15, 0, 0), 0.001)
		_:
			_box(r.root, Vector3(0.008, 0.022, 0.008), t, mat("panel", Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.5, 0.9)), Vector3(-15, 0, 0), 0.001)


## Bolt parts: what shows through the ejection port, a buffer band, or a bigger handle.
static func _bolt_part(r: Rig, id: String) -> void:
	var b := r.bolt
	var out := Vector3(signf(b.x) if b.x != 0.0 else 1.0, 0, 0)
	match id:
		"heavy_buffer", "light_spring", "heavy_spring":
			var colour: Color = {"heavy_buffer": RED, "light_spring": YELLOW, "heavy_spring": BLUE}[id]
			var rad := 0.016 if r.has_buffer else maxf(r.body_w, 0.012) + 0.002
			_rod(r.root, rad, rad, 0.008, r.stock + Vector3(0, 0, 0.02), mat("panel", colour), 8)
			if id != "heavy_buffer":
				var points := []
				for i in 13:
					var a := TAU * i / 4.0
					points.append(b + out * 0.001 + Vector3(0, cos(a) * 0.004, sin(a) * 0.004 - 0.012 + i * 0.002))
				_tube(r.root, points, 0.0012, mat("panel", colour), 3)
		"light_bolt":
			_box(r.root, Vector3(0.003, 0.01, 0.026), b + out * 0.0005, mat("panel", Color(0.9, 0.55, 0.3)), Vector3.ZERO, 0.0)
			for i in 3:
				_box(r.root, Vector3(0.004, 0.004, 0.004), b + out * 0.001 + Vector3(0, 0, -0.008 + i * 0.008), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"nickel_bolt":
			_box(r.root, Vector3(0.003, 0.011, 0.028), b + out * 0.0005, mat("panel", NICKEL), Vector3.ZERO, 0.0)
		"bolt_knob":
			if r.frame == "lever_action":
				_ball(r.root, 0.009, Vector3(0, -0.022, 0.03), mat("panel", BLACK))
			else:
				_ball(r.root, 0.017 if r.frame == "anti_materiel" else 0.013, b, mat("panel", BLACK), Vector3(1, 1, 1.2))
				_ball(r.root, 0.009, b + out * 0.006, mat("panel", RED))
		"lever_loop":
			if r.frame == "lever_action":
				_lever(r, 1.45)
				_box(r.root, Vector3(0.012, 0.006, 0.03), Vector3(0, -0.038, 0.06), mat("panel", TAPE), Vector3(-20, 0, 0), 0.002)
			else:
				_generic(r, b, id)
		_:
			_generic(r, b + out * 0.008, id)


static func _charging(r: Rig, id: String) -> void:
	var c := r.charging
	var dark := mat("panel", DARK)
	var on_side := absf(c.x) > 0.01
	match id:
		"ambi_charging":
			if on_side:
				for sx: float in [-1.0, 1.0]:
					_rod_between(r.root, Vector3(sx * r.body_w, c.y, c.z), Vector3(sx * absf(c.x), c.y, c.z), 0.0045, dark)
					_box(r.root, Vector3(0.008, 0.014, 0.014), Vector3(sx * absf(c.x), c.y, c.z), mat("panel", BLACK), Vector3.ZERO, 0.002)
			else:
				_box(r.root, Vector3(0.05, 0.008, 0.018), c, mat("panel", BLACK), Vector3.ZERO, 0.002)
				for sx: float in [-1.0, 1.0]:
					_box(r.root, Vector3(0.01, 0.009, 0.014), c + Vector3(sx * 0.026, 0, 0.002), mat("panel", RED), Vector3.ZERO, 0.002)
		"extended_latch":
			if on_side:
				_rod_between(r.root, Vector3(signf(c.x) * r.body_w, c.y, c.z), c, 0.004, dark)
				_box(r.root, Vector3(0.012, 0.02, 0.016), c, mat("panel", ORANGE), Vector3.ZERO, 0.002)
			else:
				_box(r.root, Vector3(0.03, 0.008, 0.016), c, dark, Vector3.ZERO, 0.002)
				_box(r.root, Vector3(0.022, 0.008, 0.012), c + Vector3(-0.024, 0, 0.002), mat("panel", ORANGE), Vector3(0, -15, 0), 0.002)
		"side_charging":
			var at := Vector3(-r.body_w, r.recv.y + 0.004, r.recv.z - 0.04)
			_box(r.root, Vector3(0.004, 0.008, 0.06), at + Vector3(-0.002, 0, 0.0), mat("panel", BLACK), Vector3.ZERO, 0.0)
			_rod_between(r.root, at + Vector3(0, 0, -0.025), at + Vector3(-0.026, 0, -0.025), 0.004, dark)
			_box(r.root, Vector3(0.01, 0.014, 0.016), at + Vector3(-0.028, 0, -0.025), mat("panel", BLACK), Vector3.ZERO, 0.002)
			if not on_side:
				_box(r.root, Vector3(0.02, 0.006, 0.012), c, dark, Vector3.ZERO, 0.001)
		_:
			_generic(r, c, id)


static func _magazine(r: Rig, id: String) -> void:
	var t := r.mag
	match r.mag_style:
		"tank":
			if id == "big_tank":
				_tank(r, t + Vector3(0, -0.012, 0.0), 0.06, 0.26, mat("panel", RED))
				_box(r.root, Vector3(0.13, 0.012, 0.016), t + Vector3(0, -0.012, -0.06), mat("panel", BLACK), Vector3.ZERO, 0.002)
			else:
				_tank(r, t, 0.045, 0.2, mat("panel", OLIVE))
				_generic(r, t + Vector3(0, -0.05, 0), id)
			return
		"cell":
			if id == "capacitor":
				_cells(r, t, 3 if r.frame != "bubble_gun" else 2, 0.016, 0.11, mat("panel", Color(0.95, 0.75, 0.2)))
			else:
				_cells(r, t, 2, 0.016, 0.1, mat("panel", Color(0.5, 0.55, 0.6)))
				_generic(r, t + Vector3(0, -0.035, 0.0), id)
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
		"coil":
			_nail_coil(r, t, 0.058 if id == "nail_coil" else 0.04, id == "nail_coil")
			if id != "nail_coil":
				_generic(r, t + Vector3(0, -0.04, 0.0), id)
			return
		"top":
			match id:
				"extended_mag": _top_mag(r, r.mag_len * 1.25, mat("panel", SMOKE))
				"drum_mag", "casket_mag": _top_mag(r, r.mag_len, mat("panel", SMOKE), 0.06)
				"polymer_mag": _top_mag(r, r.mag_len, mat("panel", TAN))
				"coupled_mag":
					_top_mag(r, r.mag_len, mat("panel", SMOKE))
					_box(r.root, Vector3(0.05, 0.03, r.mag_len * 0.6), r.mag + Vector3(-0.045, 0.012, 0.0), mat("panel", SMOKE), Vector3.ZERO, 0.006)
					_box(r.root, Vector3(0.1, 0.02, 0.03), r.mag + Vector3(-0.022, 0.012, 0.0), mat("panel", TAPE), Vector3.ZERO, 0.003)
				"quick_mag":
					_top_mag(r, r.mag_len, mat("panel", SMOKE))
					_tube(r.root, [r.mag + Vector3(0, 0.026, 0.15), r.mag + Vector3(0, 0.04, 0.17), r.mag + Vector3(0, 0.026, 0.18)], 0.004, mat("panel", ORANGE), 4)
				_:
					_top_mag(r, r.mag_len, mat("panel", SMOKE))
					_generic(r, r.mag + Vector3(0.03, 0.012, 0.1), id)
			return
		"tube":
			if id in ["tube_extension", "extended_mag"]:
				_tube_extension(r, 0.1 if id == "tube_extension" else 0.07)
				return
			if id == "side_saddle":
				_side_saddle(r)
				return
			if id == "box_mag_conv":
				_shell_box_mag(r)
				return
		"belt":
			if id == "belt_box":
				_belt_box(r, Vector3(0.07, 0.11, 0.14), mat("panel", Color(0.4, 0.45, 0.3)))
				_box(r.root, Vector3(0.072, 0.03, 0.01), r.mag + Vector3(0, -0.05, -0.071), mat("panel", YELLOW), Vector3.ZERO, 0.002)
				return
	if id == "speedloader":
		# Hung under the grip on a cord: six rounds in a ring.
		var at := _grip_bottom(r) + Vector3(0, -0.04, 0.0)
		_tube(r.root, [_grip_bottom(r), _grip_bottom(r) + Vector3(0, -0.014, 0.004), at + Vector3(0, 0.012, 0)], 0.0015, mat("panel", RED), 3)
		_rod(r.root, 0.017, 0.017, 0.012, at, mat("panel", BLACK), 8, Vector3.ZERO)
		for i in 6:
			var a := TAU * i / 6.0
			_round(r, _rod(r.root, 0.005, 0.005, 0.03, at + Vector3(cos(a) * 0.012, -0.018, sin(a) * 0.012), mat("brass"), 5, Vector3.ZERO))
		return
	if r.mag_style == "none":
		_generic(r, t, id)
		return
	_box_magazine(r, id)


## Box-magazine parts in the frame's own magazine shape (or a pistol's, out of the grip).
static func _box_magazine(r: Rig, id: String) -> void:
	var t := r.mag
	var steel := mat("panel", DARK)
	var pistol := r.mag_style == "pistol"
	var base := 0.0 if pistol else r.mag_len
	var w := r.mag_w
	var d := r.mag_d
	if not pistol:
		_box(r.root, Vector3(w + 0.008, 0.014, d + 0.008), t + Vector3(0, -0.004, 0), mat("panel", DARK))
		_round(r, _rod(r.root, 0.0055, 0.0055, minf(d * 0.8, 0.06), t + Vector3(0, 0.004, -0.002), mat("brass"), 5))
	match id:
		"extended_mag":
			var bottom := _mag_body(r, t, maxf(base * 1.55, 0.06), w, d, r.mag_tilt, r.mag_curve * 1.3, steel)
			_box(r.root, Vector3(w + 0.004, 0.026, d + 0.004), t.lerp(bottom, 0.55), mat("panel", TAPE), Vector3(r.mag_tilt + r.mag_curve * 0.6, 0, 0), 0.003)
		"drum_mag":
			var neck := _mag_body(r, t, maxf(base * 0.3, 0.02), w, d, r.mag_tilt, 0.0, steel, false)
			var rad := clampf(base * 0.45, 0.04, 0.07) if not pistol else 0.045
			var c := neck + Vector3(0, -rad * 0.85, 0)
			_disc_x(r.root, rad, w + 0.03, c, steel, 12)
			_disc_x(r.root, rad * 0.8, w + 0.034, c, mat("panel", Color(0.5, 0.52, 0.56)), 12)
			_disc_x(r.root, 0.012, w + 0.038, c, mat("panel", RED), 6)
		"twin_drum":
			var neck := _mag_body(r, t, maxf(base * 0.35, 0.025), w, d, r.mag_tilt, 0.0, steel, false)
			var rad := clampf(base * 0.42, 0.04, 0.06)
			for sx: float in [-1.0, 1.0]:
				var c := neck + Vector3(sx * (rad * 0.62 + 0.004), -rad * 0.5, 0)
				_put(r.root, LowPoly.prism(12, rad, rad, 0.036), c, steel, Vector3(90, 0, 0))
				_put(r.root, LowPoly.prism(12, rad * 0.75, rad * 0.75, 0.04), c, mat("panel", Color(0.55, 0.57, 0.6)), Vector3(90, 0, 0))
			_box(r.root, Vector3(0.02, 0.012, 0.02), neck + Vector3(0, -0.004, 0), mat("panel", RED), Vector3.ZERO, 0.002)
		"quick_mag":
			var bottom := _mag_body(r, t, maxf(base, 0.012), w, d, r.mag_tilt, r.mag_curve, steel)
			_tube(r.root, [bottom + Vector3(0, 0, -d * 0.3), bottom + Vector3(0, -0.022, -d * 0.1), bottom + Vector3(0, -0.022, d * 0.2),
					bottom + Vector3(0, 0, d * 0.35)], 0.0035, mat("panel", ORANGE), 4)
		"coupled_mag":
			var bottom := _mag_body(r, t, maxf(base, 0.04), w, d, r.mag_tilt, r.mag_curve, steel)
			# A second mag taped alongside, upside down so it's ready.
			var length := maxf(base, 0.04)
			var off := Vector3(w + 0.004, 0, 0)
			_mag_body(r, t + off + Vector3(0, -0.01, 0), length, w, d, r.mag_tilt, r.mag_curve, mat("panel", Color(0.36, 0.38, 0.4)), true)
			_box(r.root, Vector3(w * 2.0 + 0.012, 0.024, d + 0.006), t.lerp(bottom, 0.5) + off * 0.5, mat("panel", TAPE), Vector3(r.mag_tilt + r.mag_curve * 0.5, 0, 0), 0.003)
		"polymer_mag":
			var bottom := _mag_body(r, t, maxf(base, 0.012), w, d, r.mag_tilt, r.mag_curve, mat("panel", TAN))
			if not pistol:
				_box(r.root, Vector3(w + 0.002, base * 0.5, 0.006), t.lerp(bottom, 0.45) + Vector3(0, 0, d * 0.25), mat("panel", SMOKE), Vector3(r.mag_tilt + r.mag_curve * 0.5, 0, 0), 0.0)
		"casket_mag":
			_mag_body(r, t, maxf(base, 0.03), w * 1.9, d, r.mag_tilt, r.mag_curve * 0.6, mat("panel", Color(0.4, 0.42, 0.46)))
		"tube_extension", "side_saddle", "box_mag_conv", "belt_box":
			# Only fits frames whose own style draws it; anywhere else, a plain magazine.
			_mag_body(r, t, maxf(base, 0.012), w, d, r.mag_tilt, r.mag_curve, steel)
		_:
			var bottom := _mag_body(r, t, maxf(base, 0.04), w, d, r.mag_tilt, r.mag_curve, steel)
			_generic(r, bottom, id)


## A tube magazine extension: more tube clamped on past the old cap.
static func _tube_extension(r: Rig, length: float) -> void:
	var e := r.tube_end
	_rod(r.root, r.tube_r, r.tube_r, length, e + Vector3(0, 0, -length / 2.0), mat("panel", STEEL), 6)
	_rod(r.root, r.tube_r * 1.25, r.tube_r * 1.25, 0.012, e + Vector3(0, 0, -length - 0.004), mat("panel", BLACK), 6)
	var clamp_at := e + Vector3(0, 0, -length * 0.6)
	_box(r.root, Vector3(0.018, (r.barrel_start.y - e.y) + 0.026, 0.012), Vector3(0, (r.barrel_start.y + e.y) / 2.0, clamp_at.z),
			mat("panel", DARK), Vector3.ZERO, 0.002)
	r.tube_end = e + Vector3(0, 0, -length)


## A side saddle of spare shells on the left of the receiver.
static func _side_saddle(r: Rig) -> void:
	var at := Vector3(-(r.body_w + 0.004), r.recv.y, r.recv.z)
	_box(r.root, Vector3(0.006, 0.05, 0.08), at, mat("panel", BLACK), Vector3.ZERO, 0.002)
	for i in 5:
		var z := at.z - 0.032 + i * 0.016
		_round(r, _rod(r.root, 0.0072, 0.0072, 0.04, Vector3(at.x - 0.009, at.y + 0.004, z), mat("panel", RED), 6, Vector3.ZERO))
		_rod(r.root, 0.0078, 0.0078, 0.01, Vector3(at.x - 0.009, at.y - 0.02, z), mat("brass"), 6, Vector3.ZERO)


## A shotgun box magazine: fat, with the top shell showing.
static func _shell_box_mag(r: Rig) -> void:
	var t := r.mag
	_box(r.root, Vector3(0.038, 0.014, 0.07), t + Vector3(0, -0.004, 0), mat("panel", DARK))
	_round(r, _rod(r.root, 0.009, 0.009, 0.055, t + Vector3(0, 0.006, 0), mat("panel", RED), 6))
	var bottom := _mag_body(r, t, 0.11, 0.034, 0.07, 4.0, 0.0, mat("panel", BLACK))
	_box(r.root, Vector3(0.036, 0.03, 0.072), t.lerp(bottom, 0.4), mat("panel", OD), Vector3(4, 0, 0), 0.002)


## A nail gun's coil canister of nails.
static func _nail_coil(r: Rig, at: Vector3, radius: float, big: bool) -> void:
	var c := at + Vector3(0, -radius + 0.008, 0)
	_disc_x(r.root, radius, 0.034 + (0.01 if big else 0.0), c, mat("panel", RED if big else DARK), 10)
	_round(r, _disc_x(r.root, radius * 0.76, 0.036 + (0.01 if big else 0.0), c, mat("panel", STEEL), 10))
	_box(r.root, Vector3(0.02, 0.035, 0.02), at + Vector3(0, 0.008, -0.01), mat("panel", DARK))


static func _stock(r: Rig, id: String) -> void:
	var s := r.stock
	var black := mat("panel", BLACK)
	# Folding, wire and tube stocks leave nothing solid behind the receiver for the side
	# anchor (spare ammo, gadgets): move it onto the receiver wall.
	if id in ["folding_stock", "wire_stock", "light_stock", "pistol_brace"] and r.side.z > s.z - 0.01:
		var at := r.recv if r.recv != Vector3.INF else s + Vector3(0, -0.01, -0.06)
		# The folded stock lies along the right, so its spares go on the left.
		var sx := -1.0 if id == "folding_stock" else (signf(r.side.x) if r.side.x != 0.0 else 1.0)
		r.side = Vector3(sx * (r.body_w + 0.002), at.y, at.z + 0.03)
	match id:
		"heavy_stock":
			_profile(r.root, [Vector2(0.0, 0.016), Vector2(-0.22, 0.022), Vector2(-0.235, -0.085), Vector2(-0.2, -0.092),
					Vector2(-0.06, -0.035), Vector2(0.0, -0.025)], 0.036, s, mat("wood", WOOD))
			_box(r.root, Vector3(0.04, 0.112, 0.016), s + Vector3(0, -0.033, 0.232), black, Vector3(-4, 0, 0), 0.004)
			_box(r.root, Vector3(0.04, 0.03, 0.03), s + Vector3(0, 0.0, 0.01), mat("panel", DARK), Vector3.ZERO, 0.004)
			_stock_ends(r, s + Vector3(0, -0.033, 0.24), 0.11, s + Vector3(0, 0.02, 0.14))
		"light_stock":
			var steel := mat("panel", STEEL)
			_tube(r.root, [s, s + Vector3(0, 0.002, 0.2)], 0.005, steel, 5)
			_tube(r.root, [s + Vector3(0, -0.03, 0.0), s + Vector3(0, -0.07, 0.19)], 0.005, steel, 5)
			_tube(r.root, [s + Vector3(0, 0.012, 0.2), s + Vector3(0, -0.085, 0.2)], 0.006, steel, 5)
			_box(r.root, Vector3(0.03, 0.014, 0.05), s + Vector3(0, 0.004, 0.13), mat("panel", TAPE), Vector3.ZERO, 0.004)
			_box(r.root, Vector3(0.026, 0.1, 0.012), s + Vector3(0, -0.036, 0.205), black, Vector3.ZERO, 0.004)
			_stock_ends(r, s + Vector3(0, -0.036, 0.211), 0.1, s + Vector3(0, 0.008, 0.13))
		"folding_stock":
			# Folded flat along the right of the receiver, butt forward.
			var hinge := s + Vector3(r.body_w + 0.008, 0, 0)
			var m := mat("panel", DARK)
			_box(r.root, Vector3(0.012, 0.022, 0.016), hinge + Vector3(-0.004, 0, -0.004), black, Vector3.ZERO, 0.002)
			var tip := hinge + Vector3(0.004, -0.004, -0.2)
			_tube(r.root, [hinge, tip], 0.006, m, 5)
			_tube(r.root, [hinge + Vector3(0, -0.022, 0), tip + Vector3(0, -0.05, 0.01)], 0.005, m, 5)
			_box(r.root, Vector3(0.012, 0.08, 0.02), tip + Vector3(0.002, -0.03, 0.004), black, Vector3.ZERO, 0.003)
			_box(r.root, Vector3(0.014, 0.016, 0.03), hinge + Vector3(0.002, -0.006, -0.1), mat("panel", TAPE), Vector3.ZERO, 0.002)
		"adjustable_stock":
			# A collapsible stock on a buffer tube; its tune slides it in and out.
			var t := float(r.tune.get("stock", 0.0))
			var off := 0.1 * t if t < 0.0 else 0.06 * t
			if not r.has_buffer:
				_box(r.root, Vector3(0.03, 0.03, 0.024), s + Vector3(0, 0, 0.01), mat("panel", DARK), Vector3.ZERO, 0.004)
				_rod(r.root, 0.014, 0.014, 0.22, s + Vector3(0, 0, 0.11), black, 8)
			var front := s.z + 0.12 + off
			_profile(r.root, [Vector2(-front, 0.018), Vector2(-front - 0.14, 0.018), Vector2(-front - 0.145, -0.075),
					Vector2(-front - 0.12, -0.08), Vector2(-front, -0.02)], 0.036, Vector3(0, s.y, 0), mat("panel", TAN))
			_box(r.root, Vector3(0.038, 0.098, 0.014), Vector3(0, s.y - 0.03, front + 0.147), black, Vector3.ZERO, 0.004)
			_box(r.root, Vector3(0.006, 0.014, 0.03), Vector3(0, s.y - 0.02, front + 0.01), black, Vector3.ZERO, 0.001)
			_stock_ends(r, Vector3(0, s.y - 0.03, front + 0.154), 0.098, Vector3(0, s.y + 0.018, front + 0.08))
		"precision_stock":
			var m := mat("panel", Color(0.32, 0.33, 0.35))
			_box(r.root, Vector3(0.03, 0.03, 0.03), s + Vector3(0, 0, 0.012), mat("panel", DARK), Vector3.ZERO, 0.004)
			_profile(r.root, [Vector2(-0.02, 0.005), Vector2(-0.27, 0.005), Vector2(-0.275, -0.085), Vector2(-0.24, -0.09),
					Vector2(-0.15, -0.05), Vector2(-0.08, -0.05), Vector2(-0.02, -0.03)], 0.036, s, m)
			# Adjustable cheek piece on two posts, spacers in the butt and a monopod knob.
			for z: float in [0.12, 0.21]:
				_rod(r.root, 0.003, 0.003, 0.016, s + Vector3(0, 0.012, z), mat("panel", NICKEL), 4, Vector3.ZERO)
			_box(r.root, Vector3(0.03, 0.012, 0.12), s + Vector3(0, 0.024, 0.165), black, Vector3.ZERO, 0.004)
			for i in 3:
				_box(r.root, Vector3(0.038, 0.1, 0.005), s + Vector3(0, -0.04, 0.275 + i * 0.006), mat("panel", BLACK if i % 2 == 0 else DARK), Vector3.ZERO, 0.001)
			_rod(r.root, 0.008, 0.008, 0.03, s + Vector3(0, -0.075, 0.23), mat("panel", DARK), 6, Vector3.ZERO)
			_stock_ends(r, s + Vector3(0, -0.04, 0.29), 0.1, s + Vector3(0, 0.03, 0.165))
			r.comb = s + Vector3(0, 0.03, 0.2)
		"wire_stock":
			var m := mat("panel", STEEL)
			_tube(r.root, [s + Vector3(0.012, 0.01, 0.0), s + Vector3(0.012, 0.008, 0.22), s + Vector3(0.012, -0.085, 0.22),
					s + Vector3(0.012, -0.03, 0.0)], 0.0035, m, 4)
			_tube(r.root, [s + Vector3(-0.012, 0.01, 0.0), s + Vector3(-0.012, 0.008, 0.22), s + Vector3(-0.012, -0.085, 0.22),
					s + Vector3(-0.012, -0.03, 0.0)], 0.0035, m, 4)
			_rod_between(r.root, s + Vector3(-0.012, -0.04, 0.22), s + Vector3(0.012, -0.04, 0.22), 0.004, m)
			_box(r.root, Vector3(0.03, 0.02, 0.02), s + Vector3(0, -0.01, 0.005), mat("panel", DARK), Vector3.ZERO, 0.003)
			_box(r.root, Vector3(0.03, 0.012, 0.03), s + Vector3(0, 0.008, 0.15), mat("panel", TAPE), Vector3.ZERO, 0.002)
			_stock_ends(r, s + Vector3(0, -0.04, 0.224), 0.1, s + Vector3(0, 0.01, 0.15))
		"pistol_brace":
			# A tube off the back of the pistol, a finned arm brace and its velcro strap.
			_box(r.root, Vector3(0.022, 0.024, 0.03), s + Vector3(0, 0, 0.01), black, Vector3.ZERO, 0.004)
			_rod(r.root, 0.011, 0.011, 0.12, s + Vector3(0, 0.0, 0.08), black, 8)
			_box(r.root, Vector3(0.034, 0.05, 0.11), s + Vector3(0, -0.012, 0.12), mat("panel", POLY), Vector3.ZERO, 0.008)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.006, 0.06, 0.08), s + Vector3(sx * 0.02, -0.03, 0.13), mat("panel", POLY), Vector3(0, 0, sx * 12.0), 0.003)
			_box(r.root, Vector3(0.05, 0.016, 0.022), s + Vector3(0, -0.055, 0.15), mat("panel", OD), Vector3.ZERO, 0.002)
			_stock_ends(r, s + Vector3(0, -0.012, 0.18), 0.05, s + Vector3(0, 0.013, 0.12))
		"hydraulic_stock":
			var m := mat("panel", Color(0.3, 0.33, 0.3))
			_box(r.root, Vector3(0.03, 0.03, 0.03), s + Vector3(0, 0, 0.012), mat("panel", DARK), Vector3.ZERO, 0.004)
			_profile(r.root, [Vector2(-0.04, 0.0), Vector2(-0.25, 0.0), Vector2(-0.255, -0.09), Vector2(-0.22, -0.095),
					Vector2(-0.04, -0.04)], 0.036, s, m)
			# The oil cylinder and its chrome rod along the top.
			_rod(r.root, 0.012, 0.012, 0.1, s + Vector3(0, 0.012, 0.1), mat("panel", YELLOW), 8)
			_rod(r.root, 0.005, 0.005, 0.08, s + Vector3(0, 0.012, 0.19), mat("panel", NICKEL), 6)
			_rod(r.root, 0.013, 0.013, 0.01, s + Vector3(0, 0.012, 0.05), mat("panel", BLACK), 8)
			_box(r.root, Vector3(0.04, 0.11, 0.02), s + Vector3(0, -0.04, 0.255), black, Vector3.ZERO, 0.004)
			_stock_ends(r, s + Vector3(0, -0.04, 0.265), 0.11, s + Vector3(0, 0.002, 0.15))
		"bump_stock":
			# A bulky slide-fire shell over a buffer, its finger rest reaching for the trigger.
			_box(r.root, Vector3(0.04, 0.05, 0.2), s + Vector3(0, -0.01, 0.11), black, Vector3.ZERO, 0.01)
			_box(r.root, Vector3(0.042, 0.09, 0.03), s + Vector3(0, -0.035, 0.2), black, Vector3.ZERO, 0.008)
			_box(r.root, Vector3(0.036, 0.016, 0.05), s + Vector3(0, 0.022, 0.12), mat("panel", ORANGE), Vector3.ZERO, 0.004)
			var rest := r.grip_top + Vector3(0, -0.004, -0.01)
			_box(r.root, Vector3(0.034, 0.012, absf(s.z - rest.z) + 0.02), Vector3(0, rest.y, (s.z + rest.z) / 2.0 + 0.01), black, Vector3.ZERO, 0.003)
			_box(r.root, Vector3(0.008, 0.016, 0.008), Vector3(0.016, rest.y - 0.01, rest.z), mat("panel", ORANGE), Vector3.ZERO, 0.002)
			_stock_ends(r, s + Vector3(0, -0.035, 0.215), 0.09, s + Vector3(0, 0.022, 0.12))
		_:
			_box(r.root, Vector3(0.034, 0.05, 0.2), s + Vector3(0, -0.02, 0.1), mat("panel", Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.3, 0.5)), Vector3.ZERO, 0.006)
			_generic(r, s + Vector3(0, 0.0, 0.1), id)
			_stock_ends(r, s + Vector3(0, -0.02, 0.2), 0.05, s + Vector3(0, 0.005, 0.1))


static func _stock_ends(r: Rig, butt: Vector3, height: float, comb: Vector3) -> void:
	r.butt = butt
	r.butt_h = height
	r.comb = comb


static func _buttpad(r: Rig, id: String) -> void:
	var b := r.butt if r.butt != Vector3.INF else r.stock + Vector3(0, -0.02, 0.02)
	var c := r.comb if r.comb != Vector3.INF else b + Vector3(0, r.butt_h * 0.5, -0.08)
	var h := r.butt_h
	match id:
		"rubber_pad":
			_box(r.root, Vector3(0.042, h + 0.004, 0.02), b + Vector3(0, 0, 0.01), mat("panel", BLACK), Vector3.ZERO, 0.006)
			for i in 3:
				_box(r.root, Vector3(0.044, 0.003, 0.004), b + Vector3(0, -h * 0.3 + i * h * 0.3, 0.016), mat("panel", DARK), Vector3.ZERO, 0.0)
		"gel_pad":
			_box(r.root, Vector3(0.044, h + 0.006, 0.026), b + Vector3(0, 0, 0.013), mat("grate", Color(1.3, 0.35, 0.25), Color(0.15, 0.02, 0.0)), Vector3.ZERO, 0.008)
		"cheek_riser":
			_box(r.root, Vector3(0.032, 0.022, 0.09), c + Vector3(0, 0.011, 0), mat("panel", TAN), Vector3.ZERO, 0.006)
			for z: float in [-0.025, 0.025]:
				_box(r.root, Vector3(0.04, 0.03, 0.012), c + Vector3(0, -0.002, z), mat("panel", OD), Vector3.ZERO, 0.002)
		"ammo_sleeve":
			# A nylon sleeve round the stock with a row of spare rounds on its right.
			var at := c + Vector3(0, -0.026, 0.0)
			_box(r.root, Vector3(0.046, 0.05, 0.08), at, mat("panel", OD), Vector3.ZERO, 0.006)
			for i in 5:
				_round(r, _rod(r.root, 0.0045, 0.0045, 0.03, at + Vector3(0.025, 0.0, -0.028 + i * 0.014), mat("brass"), 5, Vector3.ZERO))
			_box(r.root, Vector3(0.006, 0.012, 0.075), at + Vector3(0.025, -0.012, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
		_:
			_generic(r, b + Vector3(0, 0, 0.012), id)


static func _ammo(r: Rig, id: String) -> void:
	var look: Array = AMMO_LOOK.get(id, [Color(0.9, 0.85, 0.7), Color.BLACK])
	var m := mat("panel", look[0], look[1])
	for node in r.rounds:
		node.material_override = m
	# A little holder on the side with spares, so the ammo reads from any angle.
	var s := r.side
	var out := signf(s.x) if s.x != 0.0 else 1.0
	var bolt := r.frame in ["crossbow", "harpoon"]
	var shell: bool = Arsenal.frame(r.frame).get("cal", "") == "12g"
	_box(r.root, Vector3(0.004, 0.022, 0.06), s + Vector3(out * 0.003, 0, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
	for i in 3 if bolt else 4:
		var z := (i - 1.5) * 0.015
		if bolt:
			_rod(r.root, 0.003, 0.003, 0.08, s + Vector3(out * 0.009, 0.006 - i * 0.008, z * 0.4), mat("wood", BONE), 4)
			_rod(r.root, 0.0, 0.006, 0.02, s + Vector3(out * 0.009, 0.006 - i * 0.008, z * 0.4 - 0.05), m, 4)
		elif shell:
			_rod(r.root, 0.0065, 0.0065, 0.034, s + Vector3(out * 0.01, 0.002, z), m, 6, Vector3.ZERO)
			_rod(r.root, 0.007, 0.007, 0.008, s + Vector3(out * 0.01, -0.018, z), mat("brass"), 6, Vector3.ZERO)
		else:
			_rod(r.root, 0.005, 0.005, 0.03, s + Vector3(out * 0.009, 0.002, z), m, 5, Vector3.ZERO)
			_rod(r.root, 0.0055, 0.0055, 0.008, s + Vector3(out * 0.009, -0.014, z), mat("brass"), 5, Vector3.ZERO)
	if not AMMO_LOOK.has(id):
		_generic(r, s + Vector3(out * 0.012, 0.02, 0), id)


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
	if id == "heatsink_fins":
		# A computer heatsink clipped to the top of the barrel with a zip tie.
		var at := r.barrel_start.lerp(r.muzzle, 0.35) + Vector3(0, r.barrel_r + 0.004, 0)
		if r.parts.has("handguard"):
			at = Vector3(0, r.hg_y + r.hg_r + 0.008, lerpf(r.hg_start, r.hg_end, 0.3))
		_box(r.root, Vector3(0.026, 0.004, 0.05), at, mat("panel", DARK), Vector3.ZERO, 0.0)
		for i in 6:
			_box(r.root, Vector3(0.028, 0.016, 0.0025), at + Vector3(0, 0.009, -0.022 + i * 0.0088), mat("panel", NICKEL), Vector3.ZERO, 0.0)
		_box(r.root, Vector3(0.004, 0.03, 0.006), at + Vector3(0, -0.008, 0.0), mat("panel", BLACK), Vector3.ZERO, 0.0)
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
		"oil_can":
			# A little oiler: a squat can with a long spout.
			_rod(r.root, 0.011, 0.011, 0.014, c + Vector3(0, -0.006, 0), mat("panel", RED), 8, Vector3.ZERO)
			_rod(r.root, 0.003, 0.011, 0.012, c + Vector3(0, 0.007, 0), mat("panel", RED), 8, Vector3.ZERO)
			_rod_between(r.root, c + Vector3(0, 0.012, 0), c + Vector3(0, 0.02, -0.022), 0.0016, mat("brass"), 4)
			_ball(r.root, 0.003, c + Vector3(0, -0.006, 0.012), mat("panel", BLACK, Color(0.2, 0.15, 0.0)))
		"rabbit_foot":
			var fur := mat("panel", Color(1.2, 1.1, 0.95))
			_ball(r.root, 0.009, c + Vector3(0, -0.01, 0), fur, Vector3(1, 1.8, 1), 0.25)
			_ball(r.root, 0.007, c + Vector3(0, -0.026, -0.004), mat("panel", Color(0.8, 0.6, 0.45)), Vector3(1, 1, 1.3), 0.3)
			_rod(r.root, 0.006, 0.006, 0.006, c + Vector3(0, 0.002, 0), mat("brass"), 6, Vector3.ZERO)
		_:
			_generic(r, c + Vector3(0, -0.006, 0), id)


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
