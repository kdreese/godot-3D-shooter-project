extends Control


func play() -> void:
	var error = get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


func quit_game() -> void:
	get_tree().notification(NOTIFICATION_WM_QUIT_REQUEST)
