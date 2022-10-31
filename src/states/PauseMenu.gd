extends ColorRect


func open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()


func disconnect_from_server() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# TODO - put in disconnect code here. Probably we'll emit a signal which tells the Game scene to disconnect
	var error := get_tree().change_scene("res://src/states/Menu.tscn")
	assert(not error)
