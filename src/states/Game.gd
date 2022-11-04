extends Node


onready var pause_menu := $"%PauseMenu" as Control

var target_transforms = []

func _ready() -> void:
	randomize()
	var selfPeerID = get_tree().get_network_unique_id()
	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	var spawn_point := curr_level.get_node("PlayerSpawnPoint") as Position3D
	var my_player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	my_player.set_name(str(selfPeerID))
	my_player.set_network_master(selfPeerID)
	my_player.get_node("Camera").current = true
	get_node("/root/Game/Players").add_child(my_player)
	my_player.translation = spawn_point.translation
	store_target_data()
	spawn_targets()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.hide()

	for p in MultiplayerInfo.player_info.keys():
		spawn_peer_player(p)


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
	for _i in range(num_targets):
		var index = randi() % len(target_transforms)
		# If we get a duplicate, try again
		while index in indices:
			index = randi() % len(target_transforms)
		indices.append(index)
	# Now that we have the list, start spawning targets
	for index in indices:
		var target := preload("res://src/objects/Target.tscn").instance() as Area
		target.transform = target_transforms[index]
		var error = target.connect("target_destroyed", self, "on_target_destroy")
		assert(not error)
		get_node("Level/Targets").add_child(target)


remote func spawn_peer_player(p) -> void:
	var player = preload("res://src/objects/Player.tscn").instance() as KinematicBody
	player.set_name(str(p))
	player.set_network_master(p)
	get_node("/root/Game/Players").add_child(player)
