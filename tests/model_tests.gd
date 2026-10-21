extends RefCounted
## Cheap checks of GunModels: every frame and every part builds a model, muzzles are in
## front of the grip, cans move the muzzle forward, unknown ids never crash.
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/model_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("gun models")
	_test_frames()
	_test_parts()
	_test_silencers()
	_test_tune_and_unknown()
	return failures


func _test_frames() -> void:
	var ok := true
	for frame_id: String in Arsenal.FRAMES:
		var model := GunModels.build({"frame": frame_id, "parts": {}})
		var marker := model.get_node_or_null("Muzzle") as Marker3D
		var spots: Dictionary = model.get_meta("slots", {})
		var grip: Vector3 = spots.get("grip", Vector3.ZERO)
		if model.get_child_count() < 8 or marker == null or marker.position.z > grip.z - 0.12:
			ok = false
			print("    bad bare model: ", frame_id, " muzzle ", marker.position if marker != null else Vector3.INF, " grip ", grip)
		for slot in Arsenal.SLOTS:
			if not spots.has(slot):
				ok = false
				print("    ", frame_id, " has no point for slot ", slot)
		model.free()
	_check(ok, "every bare frame builds, its Muzzle ahead of its grip, a point for every slot")


## Every part goes on some frame where it fits (opening its slot first if a parent part is
## needed) and changes the model.
func _test_parts() -> void:
	var ok := true
	var tried := 0
	for part_id: String in Arsenal.PARTS:
		var build := _build_with(part_id)
		if build.is_empty():
			ok = false
			print("    no frame takes ", part_id)
			continue
		var without := build.duplicate(true)
		var slot := ""
		for s: String in build.parts:
			if build.parts[s] == part_id:
				slot = s
		without.parts.erase(slot)
		var model := GunModels.build(build)
		var plain := GunModels.build(without)
		tried += 1
		if model == null or model.get_node_or_null("Muzzle") == null:
			ok = false
			print("    ", part_id, " broke the model")
		elif _signature(model) == _signature(plain):
			ok = false
			print("    ", part_id, " on ", build.frame, " changes nothing you can see")
		if model != null:
			model.free()
		plain.free()
	_check(ok, "every part (%d) builds on a frame it fits and shows on the model" % tried)


func _test_silencers() -> void:
	var ok := true
	for host: Array in [["carbine", "flash_hider"], ["ak", "muzzle_brake"], ["rifle", "thread_adapter"],
			["double_barrel", "flash_hider"], ["service_pistol", "flash_hider"]]:
		var parts := {"muzzle": host[1]}
		if host[0] == "service_pistol":
			parts.barrel = "threaded_barrel"
		var bare := GunModels.muzzle_point({"frame": host[0], "parts": parts})
		for can: String in ["can_light", "can_heavy", "can_titanium", "can_wet"]:
			var with_can: Dictionary = parts.duplicate()
			with_can.silencer = can
			if not Arsenal.clean({"frame": host[0], "parts": with_can}).parts.has("silencer"):
				ok = false
				print("    ", can, " doesn't go on ", host)
				continue
			var model := GunModels.build({"frame": host[0], "parts": with_can})
			var muzzle: Vector3 = model.get_meta("muzzle")
			if muzzle.z > bare.z - 0.03 or (model.get_node("Muzzle") as Marker3D).position != muzzle:
				ok = false
				print("    ", can, " on ", host, ": muzzle ", muzzle, " vs ", bare)
			model.free()
	_check(ok, "a quick-detach can moves the Muzzle forward past its muzzle device")
	var plain := GunModels.muzzle_point({"frame": "carbine", "parts": {}})
	var device := GunModels.muzzle_point({"frame": "carbine", "parts": {"muzzle": "suppressor"}})
	var integral := GunModels.muzzle_point({"frame": "carbine", "parts": {"barrel": "integral_suppressor"}})
	_check(device.z < plain.z - 0.1 and integral.z < plain.z - 0.05, "suppressors and integral cans put the Muzzle at their ends")


func _test_tune_and_unknown() -> void:
	var short := GunModels.build({"frame": "carbine", "parts": {"stock": "adjustable_stock"}, "tune": {"stock": -1.0}})
	var long := GunModels.build({"frame": "carbine", "parts": {"stock": "adjustable_stock"}, "tune": {"stock": 1.0}})
	var gap: float = (long.get_meta("slots").buttpad as Vector3).z - (short.get_meta("slots").buttpad as Vector3).z
	_check(gap > 0.12, "the adjustable stock's tune slides it in and out (%.2f m)" % gap)
	short.free()
	long.free()
	# Ids nothing knows (an old save, a part added without a model) get a stand-in, never a crash.
	var junk := {}
	for slot in Arsenal.SLOTS:
		junk[slot] = "no_such_" + slot
	var ok := true
	for frame_id: String in ["carbine", "service_pistol", "shotgun", "lever_action", "flamethrower", "nowhere"]:
		var model := GunModels._assemble({"frame": frame_id, "parts": junk.duplicate(), "tune": {}})
		if model == null or model.get_node_or_null("Muzzle") == null or model.get_child_count() < 20:
			ok = false
			print("    unknown parts broke ", frame_id)
		if model != null:
			model.free()
	_check(ok, "unknown part ids fall back to a small stand-in shape")


## A build of a frame the part fits, with whatever parent parts it needs to open its slot.
func _build_with(part_id: String) -> Dictionary:
	var p := Arsenal.part(part_id)
	var slots: Array[String] = []
	for slot in Arsenal.SLOTS:
		if Arsenal.slot_type(slot) == p.slot:
			slots.append(slot)
	for frame_id: String in Arsenal.FRAMES:
		if not Arsenal.fits(frame_id, part_id):
			continue
		for slot in slots:
			var build := {"frame": frame_id, "parts": {}}
			if _open(build, slot, 2) and Arsenal.fits_in(build, slot, part_id):
				build.parts[slot] = part_id
				if Arsenal.clean(build).parts.get(slot, "") == part_id:
					return build
		# Calibre-locked parts: try the frame's calibre conversions first.
		for conv: String in Arsenal.PARTS:
			var c := Arsenal.part(conv)
			if not c.has("set_cal"):
				continue
			for slot in slots:
				var build := {"frame": frame_id, "parts": {c.slot: conv}}
				if Arsenal.clean(build).parts.has(c.slot) and _open(build, slot, 2) and Arsenal.fits_in(build, slot, part_id):
					build.parts[slot] = part_id
					if Arsenal.clean(build).parts.get(slot, "") == part_id:
						return build
	return {}


## Opens `slot` on the build by adding parent parts (up to `depth` deep). True if it is open.
func _open(build: Dictionary, slot: String, depth: int) -> bool:
	if slot in Arsenal.open_slots(build):
		return true
	if depth <= 0:
		return false
	for id: String in Arsenal.PARTS:
		var q := Arsenal.part(id)
		if not slot in q.get("adds", []) or Arsenal.is_organ(id):
			continue
		for parent in Arsenal.SLOTS:
			if Arsenal.slot_type(parent) != q.slot or build.parts.has(parent):
				continue
			if not _open(build, parent, depth - 1):
				continue
			if Arsenal.fits_in(build, parent, id):
				build.parts[parent] = id
				if slot in Arsenal.open_slots(build):
					return true
				build.parts.erase(parent)
	return false


## A rough fingerprint of a model: every mesh's position, mesh and material.
func _signature(model: Node3D) -> String:
	var parts := PackedStringArray()
	for child in model.get_children():
		if child is MeshInstance3D:
			var m := child as MeshInstance3D
			parts.append("%s|%s|%s" % [m.position.snapped(Vector3.ONE * 0.001), m.mesh.get_rid().get_id(), m.material_override.get_rid().get_id()])
		elif child is Node3D and child.get_child_count() > 0:
			parts.append("node|%s|%d" % [(child as Node3D).position.snapped(Vector3.ONE * 0.001), child.get_child_count()])
	return "\n".join(parts)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)
