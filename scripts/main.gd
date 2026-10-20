extends Node
## Root of the game: stash -> (lobby) -> run -> result -> stash or lobby.
## A run renders the 3D world into a low-res SubViewport (PS1 look), layers the
## post effect on it, and draws the HUD at full resolution on top.
## The world always lives at Main/RunView/Viewport/World so every peer's nodes line up.

const LOW_RES_HEIGHT := 240
const POST_SHADER := preload("res://shaders/ps1_post.gdshader")
const WARNING_TIME := 120.0

## Tests start runs directly and skip the menus.
var show_menus := true
var session: Session
var run: Run
var hud: HUD
var run_active := false
var last_result := {}
var last_summary := {}
var guardian_view: GuardianView

var player: Player:
	get: return run.local_player if run != null else null
var level: GameMap:
	get: return run.level if run != null else null
var colossus: BoilerColossus:
	get: return run.colossus if run != null else null
var time_left: float:
	get: return run.time_left if run != null else 0.0
	set(value):
		if run != null:
			run.time_left = value

var _container: SubViewportContainer
var _viewport: SubViewport
var _menu: Control
var _pending_loadout = null
var _warned := false
var _spectating: Player = null
var _spectate_label: Label
var _voice: VoiceChat
var _post: ShaderMaterial


func _ready() -> void:
	InputSetup.ensure()
	GameState.load_game()
	session = Session.new()
	session.name = "Session"
	add_child(session)
	session.run_requested.connect(_on_run_requested)
	session.run_ended.connect(_on_run_ended)
	session.connection_failed.connect(func(reason: String) -> void: show_loadout(reason))
	session.disconnected.connect(func(reason: String) -> void: show_loadout(reason))
	get_viewport().size_changed.connect(_update_resolution)
	if show_menus:
		show_loadout()


# --- Menus ----------------------------------------------------------------------------

func show_loadout(status := "") -> void:
	_clear_run()
	if session.is_online():
		session.leave()
	var screen := LoadoutScreen.new()
	screen.solo_requested.connect(func() -> void: start_run(GameState.consume_equipped()))
	screen.host_requested.connect(_host)
	screen.join_requested.connect(_join)
	_set_menu(screen)
	if status != "":
		screen.show_status(status)


func show_lobby() -> void:
	_clear_run()
	var screen := LobbyScreen.new()
	screen.start_requested.connect(session.begin_run)
	screen.leave_requested.connect(func() -> void: show_loadout())
	_set_menu(screen)


func _host() -> void:
	var err := session.host()
	if err != OK:
		(_menu as LoadoutScreen).show_status("開不了房間（埠 %d 被占用？）" % Session.PORT)
		return
	show_lobby()


func _join(address: String) -> void:
	if address == "":
		(_menu as LoadoutScreen).show_status("先輸入主機的 IP")
		return
	var err := session.join(address)
	if err != OK:
		(_menu as LoadoutScreen).show_status("連不上 %s" % address)
		return
	show_lobby()


## Single player: an offline session with just you in it.
func start_run(loadout: Dictionary) -> void:
	_pending_loadout = loadout
	session.start_offline()
	session.begin_run()


# --- Run ------------------------------------------------------------------------------

func _on_run_requested(seed: int, roster: Dictionary) -> void:
	_set_menu(null)
	_clear_run()
	_warned = false

	_container = SubViewportContainer.new()
	_container.name = "RunView"
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.audio_listener_enable_3d = true
	_container.add_child(_viewport)
	_update_resolution()

	hud = HUD.new()
	add_child(hud)

	run = Run.new()
	run.name = "World"
	run.seed = seed
	run.roster = roster
	var guardian: bool = roster.get(session.local_id(), {}).get("role", "") == "guardian"
	# The guardian doesn't go in, so its gear stays in the stash.
	if guardian:
		run.loadout = {}
	else:
		run.loadout = _pending_loadout if _pending_loadout != null else GameState.consume_equipped()
	_pending_loadout = null
	run.local_player_spawned.connect(_on_local_player_spawned)
	run.local_finished.connect(_on_local_finished)
	_viewport.add_child(run)

	run.level.objective_done.connect(func() -> void:
		hud.show_message(run.level.objective_message, 5.0)
		hud.set_objective(run.level.exit_text))
	var zone := run.level.extraction_zone
	zone.progress_changed.connect(hud.set_extract_progress)
	zone.extracted.connect(func(_who: Player) -> void: run.local_extracted())
	zone.blocked.connect(func() -> void: hud.show_message(run.level.blocked_message))

	var post_layer := CanvasLayer.new()
	var post_rect := ColorRect.new()
	var post_material := ShaderMaterial.new()
	post_material.shader = POST_SHADER
	post_rect.material = post_material
	_post = post_material
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(post_rect)
	_viewport.add_child(post_layer)
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	run.power_changed.connect(func(on: bool) -> void:
		if not run.is_guardian:
			hud.show_message("燈全亮回來了。" if on else "全場斷電了！出口也停了…", 4.0))

	if guardian:
		hud.visible = false
		guardian_view = GuardianView.new()
		guardian_view.run = run
		guardian_view.pixel_scale = _container.stretch_shrink
		add_child(guardian_view)
		run_active = true
		return
	hud.set_objective(run.level.objective_text)
	run_active = true
	_capture_mouse(true)


func _on_local_player_spawned(local: Player) -> void:
	hud.bind_player(local)
	var others := session.scavenger_ids().size() - 1
	var intro := "【%s】%s" % [run.level.map_name, run.level.intro]
	if others > 0:
		intro = "這次有 %d 個隊友。%s" % [others, intro]
	var guardian := session.guardian_id()
	if guardian != 0:
		intro += "\n守墓者「%s」正在機房裡看著你們。" % session.roster[guardian].name
	hud.show_message(intro, 6.0)
	if session.is_online() and DisplayServer.get_name() != "headless":
		_voice = VoiceChat.new()
		_voice.player = local
		_voice.speaking_changed.connect(func(_speaking: bool) -> void: _refresh_voice())
		run.add_child(_voice)
		_refresh_voice()


func _refresh_voice() -> void:
	if hud == null:
		return
	if _voice == null or not is_instance_valid(_voice) or not run_active:
		hud.set_voice("")
	elif VoiceChat.muted:
		hud.set_voice("muted")
	else:
		hud.set_voice("speaking" if _voice.speaking else "on")


func _process(_delta: float) -> void:
	if run == null:
		return
	hud.set_time_left(run.time_left)
	hud.set_status(run.level.status_text())
	_update_post()
	if run_active and not _warned and run.time_left <= WARNING_TIME:
		_warned = true
		hud.show_message(run.level.warning_message, 5.0)
	if _spectating != null and not is_instance_valid(_spectating):
		_spectating = null
		_spectate_next()


## Screen effects from the local player's state: dreaminess, colour, night vision.
func _update_post() -> void:
	if _post == null:
		return
	var local := player
	var dream := 0.0
	var saturation := 1.0
	var gain := 1.0
	if local != null and is_instance_valid(local):
		dream = local.dream
		saturation = local.view_saturation()
		gain = local.view_gain()
	_post.set_shader_parameter("dream", dream)
	_post.set_shader_parameter("saturation", saturation)
	_post.set_shader_parameter("gain", gain)
	_post.set_shader_parameter("night_vision", gain > 1.01)


func _physics_process(_delta: float) -> void:
	var local := player
	if run_active and local != null and local.global_position.y < -20.0:
		local.global_position = level.player_spawn
		local.velocity = Vector3.ZERO


func _input(event: InputEvent) -> void:
	if run == null or guardian_view != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if run_active and player != null:
			player.look(event.relative)
	elif event.is_action_pressed("ui_cancel"):
		_capture_mouse(false)
	elif event.is_action_pressed("toggle_mic"):
		VoiceChat.muted = not VoiceChat.muted
		_refresh_voice()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse(true)
			get_viewport().set_input_as_handled()
		elif _spectate_label != null and event.button_index == MOUSE_BUTTON_LEFT:
			_spectate_next()


func _on_local_finished(result: Dictionary) -> void:
	run_active = false
	last_result = result
	hud.set_extract_progress(0.0)
	_refresh_voice()
	if not show_menus or not session.is_online():
		return
	# Others are still inside: wait a moment, then watch them.
	await get_tree().create_timer(2.5 if result.survived else 3.5).timeout
	if run == null or _menu != null:
		return
	_spectate_label = UiKit.label("", 22)
	_spectate_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_spectate_label.position.y -= 90.0
	_spectate_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_spectate_label)
	_spectate_next()


## Cycles the camera through teammates who are still in the run.
func _spectate_next() -> void:
	if run == null or _spectate_label == null:
		return
	var candidates: Array[Player] = []
	for other in run.all_players():
		if other != run.local_player and other.is_active():
			candidates.append(other)
	if _spectating != null and is_instance_valid(_spectating):
		_spectating.set_viewed(false)
	if candidates.is_empty():
		_spectating = null
		_spectate_label.text = "等待隊友…"
		return
	var index := candidates.find(_spectating)
	_spectating = candidates[(index + 1) % candidates.size()]
	_spectating.set_viewed(true)
	_spectate_label.text = "等待隊友…　正在看：%s（左鍵切換）" % _spectating.display_name


func _on_run_ended(summary: Dictionary) -> void:
	if run == null:
		return
	run_active = false
	last_summary = summary
	var was_guardian := guardian_view != null
	if was_guardian:
		GameState.record_guardian(summary.get("guardian_won", false))
	if not show_menus:
		return
	var result := last_result
	if not session.is_online():
		await get_tree().create_timer(2.5 if result.get("survived", false) else 3.5).timeout
	if run == null:
		return
	_capture_mouse(false)
	hud.visible = false
	if guardian_view != null:
		guardian_view.visible = false
	var screen := ResultScreen.new()
	screen.summary = summary
	screen.as_guardian = was_guardian
	screen.survived = result.get("survived", false)
	screen.cause = result.get("cause", "")
	screen.items = result.get("items", [])
	screen.payout = result.get("payout", {})
	screen.lost_gear = result.get("lost_gear", [])
	screen.continue_requested.connect(func() -> void:
		if session.is_online():
			show_lobby()
		else:
			show_loadout())
	_set_menu(screen)


# --- Helpers --------------------------------------------------------------------------

func _update_resolution() -> void:
	if _container == null:
		return
	var height := get_viewport().get_visible_rect().size.y
	_container.stretch_shrink = maxi(1, roundi(height / LOW_RES_HEIGHT))


func _set_menu(menu: Control) -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = menu
	if menu != null:
		add_child(menu)
		_capture_mouse(false)


func _clear_run() -> void:
	run_active = false
	# Free immediately so the next run can reuse the same node names.
	if _container != null and is_instance_valid(_container):
		remove_child(_container)
		_container.queue_free()
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	if guardian_view != null and is_instance_valid(guardian_view):
		guardian_view.queue_free()
	hud = null
	guardian_view = null
	_container = null
	_viewport = null
	run = null
	_spectating = null
	_spectate_label = null
	_voice = null


func _capture_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
