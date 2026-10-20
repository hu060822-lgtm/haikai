extends Node
## Root of the game. Renders the 3D world into a low-res SubViewport (PS1 look),
## layers the post effect on it, and draws the HUD at full resolution on top.

const LOW_RES_HEIGHT := 240
const POST_SHADER := preload("res://shaders/ps1_post.gdshader")
const RESTART_DELAY := 5.0

## Reload the level after a successful extraction. Tests turn this off.
var auto_restart := true
var player: Player
var level: BoilerFactoryTest
var hud: HUD
var extraction_count := 0
var last_extract_value := 0

var _container: SubViewportContainer
var _viewport: SubViewport


func _ready() -> void:
	InputSetup.ensure()

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
	get_viewport().size_changed.connect(_update_resolution)

	level = BoilerFactoryTest.new()
	_viewport.add_child(level)

	player = Player.new()
	_viewport.add_child(player)
	player.global_position = level.player_spawn
	player.rotation.y = level.player_spawn_yaw

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
	hud.show_message("找到值錢的東西，然後到綠燈的升降梯撤離", 6.0)
	level.extraction_zone.progress_changed.connect(hud.set_extract_progress)
	level.extraction_zone.extracted.connect(_on_extracted)

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	if player.global_position.y < -20.0:
		player.global_position = level.player_spawn
		player.velocity = Vector3.ZERO


func _update_resolution() -> void:
	var height := get_viewport().get_visible_rect().size.y
	_container.stretch_shrink = maxi(1, roundi(height / LOW_RES_HEIGHT))


func _on_extracted(extracted_player: Player) -> void:
	var taken := extracted_player.take_all_items()
	var total := 0
	for item in taken:
		total += item.value
	extraction_count += 1
	last_extract_value = total
	extracted_player.input_enabled = false
	hud.set_extract_progress(0.0)
	hud.show_message("撤離成功！帶出 %d 件物品，價值 $%d" % [taken.size(), total], RESTART_DELAY)
	if auto_restart:
		await get_tree().create_timer(RESTART_DELAY).timeout
		get_tree().reload_current_scene()
