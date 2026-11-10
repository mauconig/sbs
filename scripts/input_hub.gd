extends RefCounted
## Per-player input source. device < 0 means keyboard + mouse.

const DEADZONE := 0.18
const STICK_GAIN := 1.35

var device := -1


func _axis(negative_keys: Array, positive_keys: Array) -> float:
	var value := 0.0
	for keycode in positive_keys:
		if Input.is_key_pressed(keycode):
			value += 1.0
	for keycode in negative_keys:
		if Input.is_key_pressed(keycode):
			value -= 1.0
	return value


func move_vector() -> Vector2:
	var value := Vector2.ZERO
	if device >= 0:
		value = Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			-Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		) * STICK_GAIN
		if value.length() > 1.0:
			value = value.normalized()
	else:
		value.x = _axis([KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT])
		value.y = _axis([KEY_S, KEY_DOWN], [KEY_W, KEY_UP])
	if value.length() < DEADZONE:
		return Vector2.ZERO
	return value.limit_length(1.0)


func look_vector() -> Vector2:
	if device < 0:
		return Vector2.ZERO
	var value := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
	if value.length() < DEADZONE:
		return Vector2.ZERO
	return value


func sprint_held() -> bool:
	if device < 0:
		return Input.is_key_pressed(KEY_SHIFT)
	return Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER) \
		or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.4


func kick_held() -> bool:
	if device < 0:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return Input.is_joy_button_pressed(device, JOY_BUTTON_X)


func tackle_held() -> bool:
	if device < 0:
		return Input.is_key_pressed(KEY_CTRL)
	return Input.is_joy_button_pressed(device, JOY_BUTTON_B)


func jump_held() -> bool:
	if device < 0:
		return Input.is_key_pressed(KEY_SPACE)
	return Input.is_joy_button_pressed(device, JOY_BUTTON_A)


func item_held() -> bool:
	if device < 0:
		return Input.is_key_pressed(KEY_E)
	return Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
