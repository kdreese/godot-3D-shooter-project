extends Node


onready var pause_menu := $"%PauseMenu" as Control

var target_transforms = []

func _ready() -> void:
	randomize()
	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	var spawn_point := curr_level.get_node("PlayerSpawnPoint") as Position3D
	var player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	add_child(player)
	store_target_data()
	spawn_targets()
	player.translation = spawn_point.translation
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open_menu()


func on_target_destroy() -> void:
	var targets = get_tree().get_nodes_in_group("Targets")
	var num_targets = len(targets)
	if num_targets <= 1:
		# This is the last target that was hit (will be freed during this frame).
		spawn_targets()


func store_target_data() -> void:
	var targets = get_tree().get_nodes_in_group("Targets")
	for target in targets:
		# Copy the target's position and then queue it for deletion.
		target_transforms.append(target.transform)
		target.queue_free()


# Spawn a few targets spread throughout the level.
func spawn_targets() -> void:
	# Generate a list of indices into the transform list corresponding to targets to spawn.
	var num_targets = randi() % 3 + 2 # Random integer in [2, 5]
	var indices = []
	for i in range(num_targets):
		var index = randi() % len(target_transforms)
		# If we get a duplicate, try again
		while index in indices:
			index = randi() % len(target_transforms)
		indices.append(index)
	# Now that we have the list, start spawning targets
	for index in indices:
		var target := preload("res://src/objects/Target.tscn").instance() as Area
		target.transform = target_transforms[index]
		target.connect("target_destroyed", self, "on_target_destroy")
		get_node("Level/Targets").add_child(target)
