extends Control


func _on_PlayButton_pressed() -> void:
	var error = get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


func _on_QuitButton_pressed() -> void:
	get_tree().notification(NOTIFICATION_WM_QUIT_REQUEST)
