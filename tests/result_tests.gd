extends RefCounted
## Smoke tests for the end of a run: when you are the last one out, the run ends the
## moment you extract, and the result it ends with must already be yours (it once said
## 「你死了」 after a clean extraction).
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/result_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("run results")
	await _test_ending(true)
	await _test_ending(false)
	return failures


func _test_ending(extract: bool) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	tree.root.add_child(main)
	main.start_run({})
	for i in 40:
		await tree.physics_frame
	var seen := {}
	main.session.run_ended.connect(func(_summary: Dictionary) -> void:
		seen["result"] = main.last_result.duplicate(), CONNECT_ONE_SHOT)
	if extract:
		main.run.local_extracted()
	else:
		main.player.take_damage(1000.0, "測試")
	for i in 5:
		await tree.physics_frame
	var result: Dictionary = seen.get("result", {})
	if extract:
		_check(result.get("survived", false), "extracting alone ends the run as 撤離成功, not 你死了")
	else:
		_check(result.has("survived") and not result.survived, "dying alone ends the run as 你死了")
	main.queue_free()
	for i in 5:
		await tree.physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)
