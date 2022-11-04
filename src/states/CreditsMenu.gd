extends Control


func back_to_menu() -> void:
	var error := get_tree().change_scene("res://src/states/Menu.tscn")
	assert(not error)
