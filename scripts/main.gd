extends Node
## Root of the game: loadout screen -> run -> result screen -> loadout screen.
## A run renders the 3D world into a low-res SubViewport (PS1 look), layers the
## post effect on it, and draws the HUD at full resolution on top.

const LOW_RES_HEIGHT := 240
const POST_SHADER := preload("res://shaders/ps1_post.gdshader")
const MATCH_TIME := 720.0
const WARNING_TIME := 120.0

## Tests start runs directly and skip the menus.
var show_menus := true
var player: Player
var level: BoilerFactory
var colossus: BoilerColossus
var hud: HUD
var time_left := 0.0
var run_active := false
var last_result := {}

var _container: SubViewportContainer
var _viewport: SubViewport
var _menu: Control
var _loadout := {}
var _warned := false


func _ready() -> void:
	InputSetup.ensure()
	GameState.load_game()
	get_viewport().size_changed.connect(_update_resolution)
	if show_menus:
		show_loadout()


func show_loadout() -> void:
	_clear_run()
	var screen := LoadoutScreen.new()
	screen.start_requested.connect(start_run)
	_set_menu(screen)


func start_run(loadout: Dictionary) -> void:
	_set_menu(null)
	_clear_run()
	_loadout = loadout
	_warned = false
	time_left = MATCH_TIME

	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_viewport = SubViewport.new()
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.audio_listener_enable_3d = true
	_container.add_child(_viewport)
	_update_resolution()

	level = BoilerFactory.new()
	_viewport.add_child(level)

	player = Player.new()
	_viewport.add_child(player)
	player.global_position = level.player_spawn
	player.rotation.y = level.player_spawn_yaw
	player.equip(loadout)
	player.died.connect(_on_player_died)

	colossus = BoilerColossus.new()
	colossus.rng.seed = level.rng.randi()
	for point in BoilerFactory.PATROL_POINTS:
		colossus.patrol_points.append(point)
	_viewport.add_child(colossus)
	colossus.global_position = level.monster_spawn
	level.boiler_restarted.connect(func() -> void:
		colossus.enrage(level.lever.global_position)
		hud.show_message("主鍋爐重啟了。升降梯有電了…整座工廠也醒了。", 5.0)
		hud.set_objective("到升降梯撤離"))

	var post_layer := CanvasLayer.new()
	var post_rect := ColorRect.new()
	var post_material := ShaderMaterial.new()
	post_material.shader = POST_SHADER
	post_rect.material = post_material
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(post_rect)
	_viewport.add_child(post_layer)
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hud = HUD.new()
	add_child(hud)
	hud.bind_player(player)
	hud.show_message("找值錢的東西。升降梯要先重啟主鍋爐才會動。", 6.0)
	hud.set_objective("重啟主鍋爐（北邊）")
	level.extraction_zone.progress_changed.connect(hud.set_extract_progress)
	level.extraction_zone.extracted.connect(_on_extracted)
	level.extraction_zone.blocked.connect(func() -> void: hud.show_message("升降梯沒電。先去重啟主鍋爐。"))

	run_active = true
	_capture_mouse(true)


func _process(delta: float) -> void:
	if not run_active:
		return
	time_left -= delta
	hud.set_time_left(time_left)
	if not _warned and time_left <= WARNING_TIME:
		_warned = true
		hud.show_message("鍋爐壓力過高！兩分鐘後爆炸！", 5.0)
	if time_left <= 0.0:
		player.die("鍋爐爆炸了，你沒來得及出去")


func _input(event: InputEvent) -> void:
	if not run_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
	elif event.is_action_pressed("ui_cancel"):
		_capture_mouse(false)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse(true)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if run_active and player.global_position.y < -20.0:
		player.global_position = level.player_spawn
		player.velocity = Vector3.ZERO


func _update_resolution() -> void:
	if _container == null:
		return
	var height := get_viewport().get_visible_rect().size.y
	_container.stretch_shrink = maxi(1, roundi(height / LOW_RES_HEIGHT))


func _on_extracted(extracted_player: Player) -> void:
	var taken := extracted_player.take_all_items()
	var payout := LootTable.payout(taken)
	var gear := extracted_player.remaining_gear()
	GameState.record_extraction(payout.total, gear)
	extracted_player.input_enabled = false
	_finish_run({"survived": true, "items": taken, "payout": payout, "cause": "", "lost_gear": []})


func _on_player_died(cause: String) -> void:
	if not run_active:
		return
	GameState.record_death()
	_finish_run({"survived": false, "items": player.items.duplicate(), "payout": {},
		"cause": cause, "lost_gear": player.remaining_gear()})


func _finish_run(result: Dictionary) -> void:
	run_active = false
	last_result = result
	hud.set_extract_progress(0.0)
	if not show_menus:
		return
	await get_tree().create_timer(2.5 if result.survived else 3.5).timeout
	_capture_mouse(false)
	hud.visible = false
	var screen := ResultScreen.new()
	screen.survived = result.survived
	screen.cause = result.cause
	screen.items = result.items
	screen.payout = result.payout
	screen.lost_gear = result.lost_gear
	screen.continue_requested.connect(show_loadout)
	_set_menu(screen)


func _set_menu(menu: Control) -> void:
	if _menu != null:
		_menu.queue_free()
	_menu = menu
	if menu != null:
		add_child(menu)
		_capture_mouse(false)


func _clear_run() -> void:
	run_active = false
	for node in [hud, _container]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	hud = null
	_container = null
	player = null
	level = null
	colossus = null


func _capture_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
