extends Node


func _ready() -> void:
	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	var spawn_point := curr_level.get_node("PlayerSpawnPoint") as Position3D
	var player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	add_child(player)
	player.translation = spawn_point.translation
