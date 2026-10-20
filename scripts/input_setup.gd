class_name InputSetup
## Registers the game's input actions at startup so they live in code, not in project.godot.

const BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"lantern": [KEY_F],
	"drop": [KEY_G],
	"use_boost": [KEY_Q],
	"use_item": [KEY_X],
	"reload": [KEY_R],
	"melee": [KEY_V],
	"toggle_mic": [KEY_M],
}

const MOUSE_BINDINGS := {
	"use_weapon": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],
}


static func ensure() -> void:
	for action in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in MOUSE_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button in MOUSE_BINDINGS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
