extends ColorRect


func open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func resume_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()


func disconnect_from_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene("res://src/states/Menu.tscn")
	assert(not error)
