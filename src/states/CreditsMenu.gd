extends Control

signal change_menu

func back_to_menu() -> void:
	emit_signal("change_menu", "main_menu")
