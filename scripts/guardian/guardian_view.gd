class_name GuardianView
extends CanvasLayer
## 機房視角: the guardian's screen. A top-down camera over the map (built in the run's
## viewport), with an energy bar, the three powers, gate buttons on the map and noise
## pings where scavengers give themselves away. Scavengers themselves are hidden: the
## guardian only knows where they are by what they let it hear.

const TEXT := Color(0.92, 0.86, 0.72)
const PING_LIFE := 2.5

var run: Run
## Low-res viewport pixels -> screen pixels (the run view's stretch_shrink).
var pixel_scale := 1.0

var camera: Camera3D
var energy := FieldControl.START_ENERGY
var cooldowns := {"gate": 0.0, "power": 0.0, "monster": 0.0}
var extracted := 0
var selected := ""  # "monster" while choosing where to release
var release_kind := "moth"

var _overlay: Control
var _energy_bar: ProgressBar
var _energy_label: Label
var _status: Label
var _timer: Label
var _hint: Label
var _buttons := {}
var _pings: Array[Dictionary] = []


func _ready() -> void:
	layer = 10
	_build_camera()
	_light_the_map()
	_build_ui()
	run.guardian_state.connect(func(new_energy: float, new_cooldowns: Dictionary, new_extracted: int) -> void:
		energy = new_energy
		cooldowns = new_cooldowns
		extracted = new_extracted)
	run.guardian_ping.connect(func(pos: Vector3, radius: float) -> void:
		_pings.append({"pos": pos, "radius": radius, "age": 0.0}))


func _process(delta: float) -> void:
	for ping in _pings:
		ping.age += delta
	_pings = _pings.filter(func(ping: Dictionary) -> bool: return ping.age < PING_LIFE)
	# Scavengers are invisible from the machine room.
	for player in run.all_players():
		player.visible = false
	_energy_bar.value = energy
	_energy_label.text = "能量 %d / %d" % [int(energy), int(FieldControl.MAX_ENERGY)]
	var s := maxi(int(ceil(run.time_left)), 0)
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	var threshold: int = Session.THRESHOLD_PER_SCAVENGER * maxi(Session.instance.scavenger_ids().size(), 1)
	var inside := run.all_players().filter(func(player: Player) -> bool: return player.is_active()).size()
	_status.text = "場上搜刮者 %d 人　已撤出 $%d / 門檻 $%d" % [inside, extracted, threshold]
	for ability in _buttons:
		var info: Dictionary = FieldControl.ABILITIES[ability]
		var wait: float = cooldowns.get(ability, 0.0)
		var label: String = "%s（%d）" % [info.name, int(info.cost)]
		if ability == "monster":
			label = "%s：%s（%d）" % [info.name, MonsterRoster.MONSTERS[release_kind].name, int(info.cost)]
		if wait > 0.0:
			label += "　%ds" % int(ceil(wait))
		_buttons[ability].text = label
		_buttons[ability].disabled = wait > 0.0 or energy < info.cost
	_overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_hint.text = FieldControl.ABILITIES.gate.desc
			KEY_2:
				run.request_ability("power")
			KEY_3:
				_select_monster()
			KEY_TAB:
				_cycle_kind()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			selected = ""
			_hint.text = ""
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position)


func _click(screen: Vector2) -> void:
	# A gate under the cursor?
	for i in run.level.gates.size():
		if _to_screen(run.level.gates[i].global_position).distance_to(screen) < 22.0:
			run.request_ability("gate", [i])
			return
	if selected == "monster":
		var spot := _pick_ground(screen)
		if spot != Vector3.INF:
			run.request_ability("monster", [release_kind, spot])
			selected = ""
			_hint.text = ""


func _select_monster() -> void:
	selected = "monster"
	_hint.text = "點地圖選位置放出%s（Tab 換怪物，右鍵取消）。不能離搜刮者太近。" % MonsterRoster.MONSTERS[release_kind].name


func _cycle_kind() -> void:
	var index := FieldControl.RELEASABLE.find(release_kind)
	release_kind = FieldControl.RELEASABLE[(index + 1) % FieldControl.RELEASABLE.size()]
	if selected == "monster":
		_select_monster()


## World point under a screen position (catwalks and pipes count), or INF.
func _pick_ground(screen: Vector2) -> Vector3:
	var local := screen / pixel_scale
	var from := camera.project_ray_origin(local)
	var to := from + camera.project_ray_normal(local) * 30.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = Layers.WORLD | Layers.WALKWAY
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position + Vector3.UP * 0.1 if not hit.is_empty() else Vector3.INF


func _to_screen(world: Vector3) -> Vector2:
	return camera.unproject_position(world) * pixel_scale


func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	for gate in run.level.gates:
		var at := _to_screen(gate.global_position)
		var color := Color(1.0, 0.35, 0.25) if gate.closed else Color(1.0, 0.8, 0.3)
		_overlay.draw_rect(Rect2(at - Vector2(14, 14), Vector2(28, 28)), color, false, 3.0)
		_overlay.draw_string(font, at + Vector2(-14, -20), "閘" if not gate.closed else "關", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	var extraction := _to_screen(run.level.extraction_zone.global_position)
	_overlay.draw_circle(extraction, 18.0, Color(0.4, 1.0, 0.6, 0.25) if run.level.extraction_zone.powered else Color(1, 0.3, 0.2, 0.2))
	_overlay.draw_string(font, extraction + Vector2(-16, 34), run.level.exit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	for monster in run.monsters_root.get_children():
		if monster is Node3D and monster.visible:
			var at := _to_screen(monster.global_position)
			_overlay.draw_circle(at, 5.0, Color(0.9, 0.2, 0.9))
	for ping in _pings:
		var at := _to_screen(ping.pos)
		var t: float = ping.age / PING_LIFE
		var radius: float = lerpf(6.0, 10.0 + ping.radius * 2.0, t)
		_overlay.draw_arc(at, radius, 0.0, TAU, 24, Color(1.0, 0.9, 0.5, 1.0 - t), 2.0)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var bounds := run.level.bounds
	var center := bounds.get_center()
	camera.size = maxf(bounds.size.z, bounds.size.x * 0.56) + 3.0
	camera.near = 0.05
	camera.cull_mask &= ~GameMap.ROOF_RENDER_LAYER
	camera.far = run.level.overview_height + 2.0
	camera.position = Vector3(center.x, run.level.overview_height, center.z)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	run.add_child(camera)
	camera.current = true


## Only on the guardian's machine: lights up the map from above and clears the fog.
func _light_the_map() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-PI / 2.0 + 0.3, 0.4, 0.0)
	sun.light_energy = 0.6
	sun.light_color = Color(0.7, 0.8, 1.0)
	run.add_child(sun)
	for node in run.level.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = node.environment.duplicate()
		env.fog_enabled = false
		env.ambient_light_energy = 0.8
		node.environment = env


func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)

	var title := UiKit.label("守墓者・機房", 22, UiKit.ACCENT)
	add_child(title)
	title.position = Vector2(20, 12)
	_timer = UiKit.label("", 26)
	add_child(_timer)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer.position.y += 12
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status = UiKit.label("", 18)
	add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.position += Vector2(-20, 14)
	_status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position += Vector2(16, -290)
	panel.custom_minimum_size = Vector2(350, 0)
	_energy_label = UiKit.label("", 18, Color(0.6, 0.85, 1.0))
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(_energy_label)
	_energy_bar = ProgressBar.new()
	_energy_bar.max_value = FieldControl.MAX_ENERGY
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(350, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.7, 1.0)
	_energy_bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(_energy_bar)
	_buttons.gate = UiKit.button("", func() -> void: _hint.text = FieldControl.ABILITIES.gate.desc)
	_buttons.power = UiKit.button("", func() -> void: run.request_ability("power"))
	_buttons.monster = UiKit.button("", _select_monster)
	for key in ["gate", "power", "monster"]:
		_buttons[key].focus_mode = Control.FOCUS_NONE
		panel.add_child(_buttons[key])
	_hint = UiKit.label("搜刮者越吵，你的能量越多。他們撤出的錢低於門檻，你就贏了。", 16, UiKit.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.custom_minimum_size = Vector2(350, 0)
	panel.add_child(_hint)
	var keys := UiKit.label("1 閘門（點地圖上的「閘」）　2 斷電　3 放怪物　Tab 換怪物　右鍵 取消", 14, UiKit.DIM)
	add_child(keys)
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.position.y -= 26
	keys.grow_horizontal = Control.GROW_DIRECTION_BOTH
