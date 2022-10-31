extends Node


onready var pause_menu := $"%PauseMenu" as Control


func _ready() -> void:
	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	var spawn_point := curr_level.get_node("PlayerSpawnPoint") as Position3D
	var player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	add_child(player)
	player.translation = spawn_point.translation
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open_menu()
